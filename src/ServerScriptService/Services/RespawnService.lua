-- src/ServerScriptService/Services/RespawnService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local RespawnService = {}

local BLEED_OUT_SECONDS = 10
local REVIVE_CHANNEL_SECONDS = 5
local REVIVE_RANGE = 8
local REVIVE_MOVE_TOLERANCE = 2

-- userId -> {bled: boolean, channeling: boolean?, channelingReviverUserId: number?, cancelChannel: (() -> ())?, revivePrompt: ProximityPrompt?}
local downedState = {}

-- Forward-declared so OnPlayerDowned (defined above tryChannelRevive in this file)
-- can wire a ProximityPrompt's Triggered event straight to the same internal
-- revive-attempt logic the RequestChannelRevive remote handler uses.
local tryChannelRevive

local entrancePosition = Vector3.new(0, 5, 0) -- set by DungeonSessionService.Start

function RespawnService.SetEntrancePosition(position: Vector3)
	entrancePosition = position
end

local function respawnAtEntrance(player: Player)
	local state = downedState[player.UserId]
	if state and state.revivePrompt then
		state.revivePrompt:Destroy()
	end
	downedState[player.UserId] = nil
	player:LoadCharacter()
	task.defer(function()
		local character = player.Character or player.CharacterAdded:Wait()
		local rootPart = character:WaitForChild("HumanoidRootPart")
		rootPart.CFrame = CFrame.new(entrancePosition)
	end)
end

function RespawnService.OnPlayerDowned(player: Player)
	if downedState[player.UserId] then
		return
	end
	local state = { bled = false }
	downedState[player.UserId] = state

	-- Real player-facing revive trigger: a ProximityPrompt on the downed character
	-- that any other nearby player can activate, calling straight into the same
	-- tryChannelRevive logic the RequestChannelRevive remote uses. Without this,
	-- the only way to fire a revive attempt was the remote itself (e.g. from a
	-- console command), which is not reachable through any real player action.
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.Name
		-- HoldDuration is 0 on purpose: the actual 5-second channel timing (and its
		-- move/damage/cancel interrupts) is already implemented by tryChannelRevive's
		-- own loop below. A nonzero HoldDuration here would just be a second,
		-- redundant hold on top of that.
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = REVIVE_RANGE
		prompt.RequiresLineOfSight = false
		prompt.Parent = rootPart
		prompt.Triggered:Connect(function(triggeringPlayer: Player)
			tryChannelRevive(triggeringPlayer, player.UserId)
		end)
		state.revivePrompt = prompt
	end

	Net.Get("PlayerDowned"):FireAllClients(player.UserId)

	task.delay(BLEED_OUT_SECONDS, function()
		local state = downedState[player.UserId]
		if state and not state.bled then
			state.bled = true
			respawnAtEntrance(player)
		end
	end)
end

function tryChannelRevive(reviver: Player, downedUserId: number)
	-- Reject self-revive up front: a downed player's own character still exists (at
	-- 0 HP) until bleed-out/respawn fires, so without this check firing
	-- RequestChannelRevive with your own UserId would pass the range check (distance
	-- 0 from yourself) and, formerly, the health-interrupt check too.
	if reviver.UserId == downedUserId then
		return
	end

	local state = downedState[downedUserId]
	if not state or state.channeling then
		return
	end

	local downedPlayer = Players:GetPlayerByUserId(downedUserId)
	if not downedPlayer then
		return
	end

	local reviverRoot = reviver.Character and reviver.Character:FindFirstChild("HumanoidRootPart")
	local downedRoot = downedPlayer.Character and downedPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not reviverRoot or not downedRoot then
		return
	end
	if (reviverRoot.Position - downedRoot.Position).Magnitude > REVIVE_RANGE then
		return
	end

	-- The reviver must be alive to revive someone else. This is also validated here
	-- (rather than after state.channeling is set) so a missing/dead reviver Humanoid
	-- can never leave state.channeling stuck true with no cancelChannel yet installed
	-- to reset it.
	local reviverHumanoid = reviver.Character and reviver.Character:FindFirstChildOfClass("Humanoid")
	if not reviverHumanoid or reviverHumanoid.Health <= 0 then
		return
	end

	-- Every precondition (range, reviver-not-self, reviver-alive) is validated above;
	-- state.channeling is the last thing set before starting the channel loop so no
	-- early return after this point can leave it stuck true.
	state.channeling = true
	state.channelingReviverUserId = reviver.UserId
	local startPosition = reviverRoot.Position
	local startHealth = reviverHumanoid.Health
	local elapsed = 0
	local cancelled = false

	state.cancelChannel = function()
		cancelled = true
	end

	local function abortChannel()
		state.channeling = false
		state.channelingReviverUserId = nil
		Net.Get("ReviveProgress"):FireAllClients(reviver.UserId, downedUserId, 0)
	end

	task.spawn(function()
		-- Invariant: there is no yield point between the `state.bled` check just below
		-- and this loop's post-loop completion code further down. That's what makes
		-- "bleed-out wins" (OnPlayerDowned's task.delay sets state.bled and respawns
		-- the player) and "channel wins" (the loop reaches REVIVE_CHANNEL_SECONDS and
		-- revives them) mutually exclusive outcomes safe to reason about independently.
		while elapsed < REVIVE_CHANNEL_SECONDS do
			task.wait(0.25)
			elapsed += 0.25

			if cancelled or state.bled then
				abortChannel()
				return
			end

			local currentRoot = reviver.Character and reviver.Character:FindFirstChild("HumanoidRootPart")
			local currentHumanoid = reviver.Character and reviver.Character:FindFirstChildOfClass("Humanoid")
			-- Assumes health is monotonically non-increasing during a channel (no
			-- healing exists yet in this slice) -- a future Healer class would need
			-- this revisited, since healing the reviver mid-channel would incorrectly
			-- read as damage and abort the channel.
			if not currentRoot or not currentHumanoid
				or (currentRoot.Position - startPosition).Magnitude > REVIVE_MOVE_TOLERANCE
				or currentHumanoid.Health < startHealth
			then
				abortChannel()
				return
			end

			Net.Get("ReviveProgress"):FireAllClients(reviver.UserId, downedUserId, elapsed / REVIVE_CHANNEL_SECONDS)
		end

		state.channeling = false
		state.channelingReviverUserId = nil
		state.bled = true
		downedState[downedUserId] = nil
		Net.Get("PlayerRevived"):FireAllClients(downedUserId)

		if state.revivePrompt then
			state.revivePrompt:Destroy()
		end

		local humanoid = downedPlayer.Character and downedPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth * 0.5 -- revived at half health
		end
	end)
end

function RespawnService.Start()
	Net.Get("RequestChannelRevive").OnServerEvent:Connect(function(player, downedUserId)
		if typeof(downedUserId) ~= "number" then
			return
		end
		tryChannelRevive(player, downedUserId)
	end)

	Net.Get("CancelChannelRevive").OnServerEvent:Connect(function(player)
		-- Only cancel the channel THIS player is the reviver on. downedState can hold
		-- one entry per downed party member (parties are up to 4 players, see
		-- PartyService.MAX_PARTY_SIZE), each possibly mid-revive by a different
		-- reviver at the same time -- cancelling every active channel here would let
		-- one player's cancel interrupt someone else's unrelated revive-in-progress.
		for _, state in downedState do
			if state.cancelChannel and state.channelingReviverUserId == player.UserId then
				state.cancelChannel()
			end
		end
	end)

	-- A player who disconnects while downed would otherwise leave a stale
	-- downedState entry behind, and the pending bleed-out task.delay would later
	-- call player:LoadCharacter() on a Player instance that already left. Their
	-- character also no longer ragdolls on death (BreakJointsOnDeath = false), so
	-- without explicitly destroying revivePrompt here, a disconnecting downed
	-- player's corpse and its live, interactable "Revive" prompt would otherwise
	-- be left behind for the rest of the session.
	Players.PlayerRemoving:Connect(function(player)
		local state = downedState[player.UserId]
		if state and state.revivePrompt then
			state.revivePrompt:Destroy()
		end
		downedState[player.UserId] = nil
	end)
end

-- Call when the dungeon session ends so any in-flight bleed-out task.delay or
-- revive-channel task.spawn loop stops mattering. Those closures all read from
-- downedState (OnPlayerDowned's bleed-out check, tryChannelRevive, and the
-- channel loop itself), so clearing it here makes their guards naturally no-op:
-- `if state and not state.bled then` and `downedState[downedUserId]` lookups will
-- all see the entry as gone and return/no-op instead of acting after session end.
function RespawnService.Stop()
	for _, state in downedState do
		if state.cancelChannel then
			state.cancelChannel()
		end
	end
	table.clear(downedState)
end

return RespawnService
