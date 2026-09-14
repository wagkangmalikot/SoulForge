-- src/ServerScriptService/Main.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local CombatService = require(ServerScriptService.Services.CombatService)
local PartyService = require(ServerScriptService.Services.PartyService)
local DungeonEntryService = require(ServerScriptService.Services.DungeonEntryService)
local DungeonSessionService = require(ServerScriptService.Services.DungeonSessionService)
local CharacterCreationService = require(ServerScriptService.Services.CharacterCreationService)
local LevelUpService = require(ServerScriptService.Services.LevelUpService)

PlayerDataService.Start()
CombatService.Start()

-- Server scripts start before any player has necessarily connected, so we
-- wait for the first one to check their TeleportData. Never use
-- game.PrivateServerId here -- it does not reliably report for servers
-- reached via TeleportService:ReserveServer (only for purchased VIP/Private
-- Servers), a bug the sibling DBD-Roblox project already hit and documented
-- in its own Main.server.lua.
local function determineServerTypeAndStart(player: Player)
	local teleportData = player:GetJoinData().TeleportData

	if teleportData and teleportData.isDungeon then
		DungeonSessionService.Start(teleportData.dungeonId)
	else
		PartyService.Start()
		DungeonEntryService.Start()
		CharacterCreationService.Start()
		LevelUpService.Start()
	end
end

if #Players:GetPlayers() > 0 then
	determineServerTypeAndStart(Players:GetPlayers()[1])
else
	Players.PlayerAdded:Once(determineServerTypeAndStart)
end

print("Soulforge server started. Net remotes ready:", Net.Get("CastSkill").Name)
