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

	TeleportService:TeleportAsync(game.PlaceId, Players:GetPlayers())
end

function DungeonSessionService.Start(dungeonId: string)
	if dungeonId ~= "Rockhide" then
		return
	end

	BossAIService.SpawnBoss("Rockhide", CFrame.new(0, 5, 0), function()
		bankRewardsAndReturnToHub("victory")
	end)

	-- Simplified wipe handling for this slice (full downed/revive loop is
	-- Task 7): if every connected player's Humanoid health hits 0, it's a wipe.
	task.spawn(function()
		while true do
			task.wait(1)
			local anyAlive = false
			for _, player in Players:GetPlayers() do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					anyAlive = true
					break
				end
			end
			if not anyAlive and #Players:GetPlayers() > 0 then
				bankRewardsAndReturnToHub("wipe")
				break
			end
		end
	end)
end

return DungeonSessionService
