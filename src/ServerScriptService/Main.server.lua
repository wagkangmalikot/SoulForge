-- src/ServerScriptService/Main.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Critical: Disable CharacterAutoLoads immediately before any player can trigger
-- premature native spawning before the Hub map and services are initialized.
Players.CharacterAutoLoads = false

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local CombatService = require(ServerScriptService.Services.CombatService)
local PartyService = require(ServerScriptService.Services.PartyService)
local DungeonEntryService = require(ServerScriptService.Services.DungeonEntryService)
local DungeonSessionService = require(ServerScriptService.Services.DungeonSessionService)
local CharacterCreationService = require(ServerScriptService.Services.CharacterCreationService)
local LevelUpService = require(ServerScriptService.Services.LevelUpService)
local WeaponService = require(ServerScriptService.Services.WeaponService)
local HubMapService = require(ServerScriptService.Services.HubMapService)
local SkillTreeService = require(ServerScriptService.Services.SkillTreeService)
local CraftingService = require(ServerScriptService.Services.CraftingService)

PlayerDataService.Start()
CombatService.Start()
WeaponService.Start()
SkillTreeService.Start()

-- Hub and dungeon servers are the same published place sharing one
-- Workspace -- there's no separate scene per server type, only this runtime
-- branch. Scenery authored directly in the place (not Rojo-managed source;
-- see CharacterCreationController's comment for why) ends up present on
-- every server instance regardless of which branch below actually runs, so
-- each branch destroys whatever belongs to the OTHER one before starting its
-- own services. This is the single place that decision gets made -- don't
-- duplicate this cleanup inside DungeonSessionService or the hub services
-- themselves.
local HUB_ONLY_SCENERY = {"RockhidePortal", "SunforgedPortal", "LevelUpShrine", "SpawnLocation", "SoulforgeHub"}
local DUNGEON_ONLY_SCENERY = {"RockhideArena", "SunforgedCitadel"}

local function destroyScenery(names: {string})
	for _, desc in workspace:GetDescendants() do
		for _, name in names do
			if desc.Name == name then
				desc:Destroy()
				break
			end
		end
	end
end

-- Server scripts start before any player has necessarily connected, so we
-- wait for the first one to check their TeleportData. Never use
-- game.PrivateServerId here -- it does not reliably report for servers
-- reached via TeleportService:ReserveServer (only for purchased VIP/Private
-- Servers), a bug the sibling DBD-Roblox project already hit and documented
-- in its own Main.server.lua.
local RunService = game:GetService("RunService")

-- In Studio Play Solo, set to true to bypass the Hub and jump straight into a dungeon on load for testing.
local STUDIO_DIRECT_DUNGEON = true
local STUDIO_DIRECT_DUNGEON_ID = "Sunforged" -- "Sunforged" or "Rockhide"

if RunService:IsStudio() and STUDIO_DIRECT_DUNGEON then
	ReplicatedStorage:SetAttribute("IsDungeon", true)
end

local function determineServerTypeAndStart(player: Player)
	local teleportData = player:GetJoinData().TeleportData
	local isDungeonServer = (teleportData and teleportData.isDungeon)
		or (RunService:IsStudio() and STUDIO_DIRECT_DUNGEON)

	if isDungeonServer then
		ReplicatedStorage:SetAttribute("IsDungeon", true)
		destroyScenery(HUB_ONLY_SCENERY)
		local dungeonId = (teleportData and teleportData.dungeonId)
			or (RunService:IsStudio() and STUDIO_DIRECT_DUNGEON_ID)
			or "Sunforged"
		local partyUserIds = teleportData and teleportData.partyMemberUserIds

		-- Enable level-up and crafting services so developer test commands (/lvl, /sunforged, /exp) work in dungeon testing
		LevelUpService.Start()
		CraftingService.Start()

		DungeonSessionService.Start(dungeonId, partyUserIds)
	else
		destroyScenery(DUNGEON_ONLY_SCENERY)
		for _, desc in workspace:GetDescendants() do
			if desc:IsA("SpawnLocation") then
				desc:Destroy()
			end
		end
		local ok, err = pcall(function()
			HubMapService.BuildHub()
		end)
		if not ok then
			warn("[Main] Error building Hub map:", err)
		end
		PartyService.Start()
		DungeonEntryService.Start()
		CharacterCreationService.Start()
		LevelUpService.Start()
		CraftingService.Start()
	end
end

if #Players:GetPlayers() > 0 then
	determineServerTypeAndStart(Players:GetPlayers()[1])
else
	Players.PlayerAdded:Once(determineServerTypeAndStart)
end

print("Soulforge server started. Net remotes ready:", Net.Get("CastSkill").Name)

-- Diagnostic dump of Assets and TrashMobTemplate
task.defer(function()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		print("DIAG: No ReplicatedStorage.Assets folder found!")
		return
	end
	print("DIAG: ReplicatedStorage.Assets found:")
	for _, item in assets:GetChildren() do
		print(("DIAG: Asset: %s (%s)"):format(item.Name, item.ClassName))
		if item:IsA("Model") then
			print(("DIAG:   PrimaryPart = %s"):format(tostring(item.PrimaryPart and item.PrimaryPart.Name)))
			for _, child in item:GetChildren() do
				print(("DIAG:   - %s (%s)"):format(child.Name, child.ClassName))
				for _, sub in child:GetChildren() do
					print(("DIAG:       -- %s (%s)"):format(sub.Name, sub.ClassName))
				end
			end
		end
	end
end)
