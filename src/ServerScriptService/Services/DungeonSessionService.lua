-- src/ServerScriptService/Services/DungeonSessionService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local BossAIService = require(script.Parent.BossAIService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RespawnService = require(script.Parent.RespawnService)

local DungeonSessionService = {}

local EXP_REWARD_ON_VICTORY = 50 -- flat value for this slice; real EXP formulas are a later plan

local BOSS_SPAWN_CFRAME = CFrame.new(0, 5, 0)
local ENTRANCE_POSITION = Vector3.new(0, 5, -20) -- near spawn, away from the boss

local function bankRewardsAndReturnToHub(result: "victory" | "wipe")
	-- Bank BEFORE teleporting away, per spec section 1a's anti-dupe/anti-loss
	-- ordering rule: the mutation must be in memory before the player leaves
	-- this server, even if they disconnect the instant they land in the hub.
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.GetProfile(player)
		if profile and result == "victory" then
			profile.Data.Character.UnspentEXP += EXP_REWARD_ON_VICTORY
		end
		Net.Get("DungeonResult"):FireClient(player, result, result == "victory" and EXP_REWARD_ON_VICTORY or 0)
	end

	task.wait(2) -- let the client show the result briefly before the teleport cuts the screen

	local teleportOk, teleportErr = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, Players:GetPlayers())
	end)
	if not teleportOk then
		-- EXP is already banked above (in-memory, per the anti-dupe ordering rule), so a
		-- failed teleport here just strands players rather than losing/duping rewards.
		-- A retry or player-facing message is a reasonable follow-up but out of scope
		-- for this vertical slice; at minimum this must not fail silently.
		warn("DungeonSessionService: TeleportAsync back to hub failed", teleportErr)
	end
end

-- Hooks the downed/revive system for a single player.  Called once for every
-- player whose character has already spawned by the time DungeonSessionService
-- starts, and also from a CharacterAdded connection so late-spawners are covered.
local function hookPlayerDeath(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		warn(("DungeonSessionService: no Humanoid found for %s's character within 5s -- death hook not installed"):format(player.Name))
		return
	end
	humanoid.Died:Connect(function()
		RespawnService.OnPlayerDowned(player)
	end)
end

function DungeonSessionService.Start(dungeonId: string)
	if dungeonId ~= "Rockhide" then
		return
	end

	local ended = false
	local bossHandle

	-- Both trigger paths (victory via the boss's onDeath callback, and wipe via the
	-- polling loop below) run independently and could otherwise both fire in the
	-- window between a boss death and the wipe loop's next tick (e.g. players die in
	-- the same moment as the killing blow, or during TeleportAsync's player-drain).
	-- Guarding with `ended` makes ending the session idempotent so only the first
	-- result wins and DungeonResult never fires twice with contradicting results.
	local function endSession(result: "victory" | "wipe")
		if ended then
			return
		end
		ended = true
		RespawnService.Stop()
		bankRewardsAndReturnToHub(result)
	end

	-- Set up RespawnService before spawning the boss so death hooks are in place.
	RespawnService.SetEntrancePosition(ENTRANCE_POSITION)
	RespawnService.Start()

	-- Hook existing players' current characters; also hook future character spawns.
	for _, player in Players:GetPlayers() do
		if player.Character then
			hookPlayerDeath(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			hookPlayerDeath(player, character)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			hookPlayerDeath(player, character)
		end)
	end)

	-- Disable the engine's own auto-respawn AFTER the initial hookup loop above, so
	-- each player's very first spawn on teleport-in (already underway/complete by
	-- now) is unaffected. From this point on, every respawn must go exclusively
	-- through RespawnService's own player:LoadCharacter() call in respawnAtEntrance --
	-- otherwise the engine would silently respawn a downed Humanoid ~5s after death
	-- (CharacterAutoLoads default) at the default SpawnLocation instead of
	-- ENTRANCE_POSITION, mid-bleed-out or mid-revive-channel, and RespawnService's own
	-- pending bleed-out timer would later fire too and yank the player a second time.
	-- Players is a per-server service instance, so this only affects this dungeon
	-- server; the hub server keeps normal auto-respawn.
	Players.CharacterAutoLoads = false

	bossHandle = BossAIService.SpawnBoss("Rockhide", BOSS_SPAWN_CFRAME, function()
		endSession("victory")
	end)

	-- Wipe detection: if every connected player's Humanoid health is 0 (and
	-- RespawnService's bleed-out timer hasn't respawned them yet), call a wipe.
	-- The downed/revive loop (RespawnService) lets players recover before the
	-- bleed-out expires, so this check won't fire as long as someone is being revived.
	task.spawn(function()
		while not ended do
			task.wait(1)
			if ended then
				break
			end
			local anyAlive = false
			for _, player in Players:GetPlayers() do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					anyAlive = true
					break
				end
			end
			if not anyAlive and #Players:GetPlayers() > 0 then
				-- Call endSession first so it wins the race even though ForceKill
				-- triggers the boss's own onDeath("victory") attempt -- by then
				-- `ended` is already true, so that attempt is a no-op.
				endSession("wipe")
				BossAIService.ForceKill(bossHandle)
				break
			end
		end
	end)
end

return DungeonSessionService
