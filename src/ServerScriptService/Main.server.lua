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

-- Hub and dungeon servers are the same published place sharing one
-- Workspace -- there's no separate scene per server type, only this runtime
-- branch. Scenery authored directly in the place (not Rojo-managed source;
-- see CharacterCreationController's comment for why) ends up present on
-- every server instance regardless of which branch below actually runs, so
-- each branch destroys whatever belongs to the OTHER one before starting its
-- own services. This is the single place that decision gets made -- don't
-- duplicate this cleanup inside DungeonSessionService or the hub services
-- themselves.
local HUB_ONLY_SCENERY = {"RockhidePortal", "LevelUpShrine", "SpawnLocation"}
local DUNGEON_ONLY_SCENERY = {"RockhideArena"}

local function destroyScenery(names: {string})
	for _, name in names do
		local instance = workspace:FindFirstChild(name)
		if instance then
			instance:Destroy()
		end
	end
end

-- Server scripts start before any player has necessarily connected, so we
-- wait for the first one to check their TeleportData. Never use
-- game.PrivateServerId here -- it does not reliably report for servers
-- reached via TeleportService:ReserveServer (only for purchased VIP/Private
-- Servers), a bug the sibling DBD-Roblox project already hit and documented
-- in its own Main.server.lua.
local function determineServerTypeAndStart(player: Player)
	local teleportData = player:GetJoinData().TeleportData

	if teleportData and teleportData.isDungeon then
		destroyScenery(HUB_ONLY_SCENERY)
		DungeonSessionService.Start(teleportData.dungeonId)
	else
		destroyScenery(DUNGEON_ONLY_SCENERY)
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
