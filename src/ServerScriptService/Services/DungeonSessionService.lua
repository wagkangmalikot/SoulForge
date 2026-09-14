-- src/ServerScriptService/Services/DungeonSessionService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local BossAIService = require(script.Parent.BossAIService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local DungeonSessionService = {}

local EXP_REWARD_ON_VICTORY = 50 -- flat value for this slice; real EXP formulas are a later plan

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
		bankRewardsAndReturnToHub(result)
	end

	bossHandle = BossAIService.SpawnBoss("Rockhide", CFrame.new(0, 5, 0), function()
		endSession("victory")
	end)

	-- Simplified wipe handling for this slice (full downed/revive loop is
	-- Task 7): if every connected player's Humanoid health hits 0, it's a wipe.
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
