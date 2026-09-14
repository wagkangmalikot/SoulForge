-- src/ServerScriptService/Services/RespawnService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local RespawnService = {}

local BLEED_OUT_SECONDS = 10
local REVIVE_CHANNEL_SECONDS = 5
local REVIVE_RANGE = 8

-- userId -> {bled: boolean, channeling: boolean?, channelingReviverUserId: number?, cancelChannel: (() -> ())?}
local downedState = {}

local entrancePosition = Vector3.new(0, 5, 0) -- set by DungeonSessionService.Start

function RespawnService.SetEntrancePosition(position: Vector3)
	entrancePosition = position
end

local function respawnAtEntrance(player: Player)
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
	downedState[player.UserId] = { bled = false }
	Net.Get("PlayerDowned"):FireAllClients(player.UserId)

	task.delay(BLEED_OUT_SECONDS, function()
		local state = downedState[player.UserId]
		if state and not state.bled then
			state.bled = true
			respawnAtEntrance(player)
		end
	end)
end

local function tryChannelRevive(reviver: Player, downedUserId: number)
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

	state.channeling = true
	state.channelingReviverUserId = reviver.UserId
	local startPosition = reviverRoot.Position
	local startHealth = reviver.Character:FindFirstChildOfClass("Humanoid").Health
	local elapsed = 0
	local cancelled = false

	state.cancelChannel = function()
		cancelled = true
	end

	task.spawn(function()
		while elapsed < REVIVE_CHANNEL_SECONDS do
			task.wait(0.25)
			elapsed += 0.25

			if cancelled or state.bled then
				state.channeling = false
				state.channelingReviverUserId = nil
				Net.Get("ReviveProgress"):FireAllClients(reviver.UserId, downedUserId, 0)
				return
			end

			local currentRoot = reviver.Character and reviver.Character:FindFirstChild("HumanoidRootPart")
			local currentHumanoid = reviver.Character and reviver.Character:FindFirstChildOfClass("Humanoid")
			if not currentRoot or not currentHumanoid
				or (currentRoot.Position - startPosition).Magnitude > 2
				or currentHumanoid.Health < startHealth
			then
				state.channeling = false
				state.channelingReviverUserId = nil
				Net.Get("ReviveProgress"):FireAllClients(reviver.UserId, downedUserId, 0)
				return
			end

			Net.Get("ReviveProgress"):FireAllClients(reviver.UserId, downedUserId, elapsed / REVIVE_CHANNEL_SECONDS)
		end

		state.channeling = false
		state.channelingReviverUserId = nil
		state.bled = true
		downedState[downedUserId] = nil
		Net.Get("PlayerRevived"):FireAllClients(downedUserId)

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
	-- call player:LoadCharacter() on a Player instance that already left.
	Players.PlayerRemoving:Connect(function(player)
		downedState[player.UserId] = nil
	end)
end

return RespawnService
