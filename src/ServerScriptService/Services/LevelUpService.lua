-- src/ServerScriptService/Services/LevelUpService.lua
-- Hub-only. Souls-style manual leveling (spec section 9a): a player spends
-- UnspentEXP at a fixed cost (level x 50) to increase their Level by one.
-- No automatic EXP-threshold leveling -- this is the only way Level changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LevelUpService = {}

local function expCostForLevel(level: number): number
	return level * 50
end

local function tryLevelUp(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local character = profile.Data.Character
	local cost = expCostForLevel(character.Level)
	if character.UnspentEXP < cost then
		return -- not enough EXP -- silently reject; the client's own display
		       -- already shows the real cost, this is just the server gate
	end

	character.UnspentEXP -= cost
	character.Level += 1

	Net.Get("CharacterDataChanged"):FireClient(player, character.Level, character.UnspentEXP)
end

function LevelUpService.Start()
	Net.Get("RequestLevelUp").OnServerEvent:Connect(function(player)
		tryLevelUp(player)
	end)
end

return LevelUpService
