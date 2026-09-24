-- src/ServerScriptService/Services/DungeonSessionService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local BossAIService = require(script.Parent.BossAIService)
local MonsterAIService = require(script.Parent.MonsterAIService)
local DungeonMapService = require(script.Parent.DungeonMapService)
local SunforgedCitadelMapService = require(script.Parent.SunforgedCitadelMapService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RespawnService = require(script.Parent.RespawnService)
local WeaponService = require(script.Parent.WeaponService)
local SkillTreeService = require(script.Parent.SkillTreeService)

local DungeonSessionService = {}
local currentDungeonId = "Rockhide"

-- Flat values for this slice; real formulas (dungeon tier, player level, party
-- size, etc.) are a later plan. Wipe rewards are 20% of the victory reward for
-- all three types, and the per-mob-kill bonus is banked regardless of outcome
-- (see bankRewardsAndReturnToHub below).
local EXP_REWARD_ON_VICTORY = 50
local EXP_REWARD_ON_WIPE = 10
local MOB_EXP_REWARD = 5

local FRAGMENT_REWARD_ON_VICTORY = 5
local FRAGMENT_REWARD_ON_WIPE = 1
local MOB_FRAGMENT_REWARD = 1

local GOLD_REWARD_ON_VICTORY = 25
local GOLD_REWARD_ON_WIPE = 5
local MOB_GOLD_REWARD = 5

-- Grand Colosseum Center (deep inside the boss arena, facing toward the gate at Z = -25)
local BOSS_SPAWN_CFRAME = CFrame.new(0, 1, 45) * CFrame.Angles(0, math.pi, 0)

-- Staging Antechamber safe entrance platform (Z = -285)
local ENTRANCE_POSITION = Vector3.new(0, 5, -285)
local SUNFORGED_ENTRANCE_POSITION = Vector3.new(0, 5.5, -1300)
local SUNFORGED_BOSS_SPAWN_CFRAME = CFrame.new(0, 50, 40) * CFrame.Angles(0, math.pi, 0)

local SUNFORGED_ZONE_MOB_COORDINATES = {
	-- Zone 1: Maze Entry Corridor (X = 26)
	{ Vector3.new(24, 3, -1170), Vector3.new(28, 3, -1170), Vector3.new(24, 3, -1180), Vector3.new(28, 3, -1180) },
	-- Zone 2: Dead End Alcove A (West Ambush)
	{ Vector3.new(-34, 3, -1070), Vector3.new(-30, 3, -1070), Vector3.new(-34, 3, -1060), Vector3.new(-30, 3, -1060) },
	-- Zone 3: Sunken Crypts - North Chicane
	{ Vector3.new(-14, 3, -1000), Vector3.new(-6, 3, -1000), Vector3.new(-10, 3, -1010), Vector3.new(-2, 3, -1010) },
	-- Zone 4: Sunken Crypts - South Chicane
	{ Vector3.new(6, 3, -940), Vector3.new(14, 3, -940), Vector3.new(10, 3, -950), Vector3.new(18, 3, -950) },
	-- Zone 5: East Transept Corridor
	{ Vector3.new(24, 3, -870), Vector3.new(28, 3, -870), Vector3.new(24, 3, -860), Vector3.new(28, 3, -860) },
	-- Zone 6: Dead End Alcove B (East Ambush)
	{ Vector3.new(40, 3, -800), Vector3.new(44, 3, -800), Vector3.new(40, 3, -790), Vector3.new(44, 3, -790) },
	-- Zone 7: Grand Archives - Rotunda
	{ Vector3.new(-12, 3, -670), Vector3.new(12, 3, -670), Vector3.new(-6, 3, -680), Vector3.new(6, 3, -680) },
	-- Zone 8: Grand Solar Cathedral Nave
	{ Vector3.new(-14, 3, -440), Vector3.new(14, 3, -440), Vector3.new(-8, 3, -450), Vector3.new(8, 3, -450) },
	-- Zone 9: Grand Stepped Colonnade Ascent
	{ Vector3.new(-8, 25, -190), Vector3.new(8, 25, -190), Vector3.new(-4, 26, -185), Vector3.new(4, 26, -185) },
	-- Zone 10: Solar Sanctum Gate Praetorians
	{ Vector3.new(-12, 50, -75), Vector3.new(12, 50, -75), Vector3.new(-6, 50, -70), Vector3.new(6, 50, -70) },
}

-- Trash mob placement definitions: 10 strategic zones across the dungeon
-- Scales dynamically to (20 * partyMemberCount) monsters total.
-- For a party of N members, each zone spawns (2 * N) monsters:
-- 1 player = 20 monsters | 2 players = 40 monsters | 3 players = 60 monsters | 4 players = 80 monsters.
local ZONE_MOB_COORDINATES = {
	-- Zone 1: Colonnade - Entry Corridor Sentinels
	{
		Vector3.new(-3, 3, -242), Vector3.new(3, 3, -242),
		Vector3.new(-4, 3, -248), Vector3.new(4, 3, -248),
		Vector3.new(-2.5, 3, -236), Vector3.new(2.5, 3, -236),
		Vector3.new(-5, 3, -252), Vector3.new(5, 3, -252),
	},
	-- Zone 2: Colonnade - Upper Avenue Vanguard
	{
		Vector3.new(-4, 3, -202), Vector3.new(4, 3, -202),
		Vector3.new(-5, 3, -208), Vector3.new(5, 3, -208),
		Vector3.new(-3, 3, -196), Vector3.new(3, 3, -196),
		Vector3.new(-5.5, 3, -200), Vector3.new(5.5, 3, -200),
	},
	-- Zone 3: Colonnade - Mid Avenue Watchers
	{
		Vector3.new(-4, 3, -102), Vector3.new(4, 3, -102),
		Vector3.new(-5, 3, -108), Vector3.new(5, 3, -108),
		Vector3.new(-3, 3, -96), Vector3.new(3, 3, -96),
		Vector3.new(-5.5, 3, -100), Vector3.new(5.5, 3, -100),
	},
	-- Zone 4: Colonnade - Boss Gate Praetorians
	{
		Vector3.new(-5, 3, -38), Vector3.new(5, 3, -38),
		Vector3.new(-3, 3, -42), Vector3.new(3, 3, -42),
		Vector3.new(-5, 3, -34), Vector3.new(5, 3, -34),
		Vector3.new(-2, 3, -36), Vector3.new(2, 3, -36),
	},
	-- Zone 5: West Wing (Crypt of Whispers) - Chamber of Whispers
	{
		Vector3.new(-60, 3, -172), Vector3.new(-50, 3, -172),
		Vector3.new(-66, 3, -170), Vector3.new(-44, 3, -170),
		Vector3.new(-58, 3, -166), Vector3.new(-52, 3, -166),
		Vector3.new(-64, 3, -176), Vector3.new(-46, 3, -176),
	},
	-- Zone 6: West Wing (Crypt of Whispers) - Hall of Shadows
	{
		Vector3.new(-57, 3, -152), Vector3.new(-51, 3, -152),
		Vector3.new(-59, 3, -155), Vector3.new(-49, 3, -155),
		Vector3.new(-57, 3, -149), Vector3.new(-51, 3, -149),
		Vector3.new(-61, 3, -152), Vector3.new(-47, 3, -152),
	},
	-- Zone 7: West Wing (Crypt of Whispers) - Alcove of the Undying
	{
		Vector3.new(-56, 3, -126), Vector3.new(-44, 3, -126),
		Vector3.new(-62, 3, -124), Vector3.new(-38, 3, -124),
		Vector3.new(-54, 3, -120), Vector3.new(-46, 3, -120),
		Vector3.new(-60, 3, -135), Vector3.new(-40, 3, -135),
	},
	-- Zone 8: East Wing (Sunken Catacombs) - Vault of Torment
	{
		Vector3.new(50, 3, -172), Vector3.new(60, 3, -172),
		Vector3.new(44, 3, -170), Vector3.new(66, 3, -170),
		Vector3.new(52, 3, -166), Vector3.new(58, 3, -166),
		Vector3.new(46, 3, -176), Vector3.new(64, 3, -176),
	},
	-- Zone 9: East Wing (Sunken Catacombs) - Catacomb Pass
	{
		Vector3.new(51, 3, -152), Vector3.new(57, 3, -152),
		Vector3.new(49, 3, -155), Vector3.new(59, 3, -155),
		Vector3.new(51, 3, -149), Vector3.new(57, 3, -149),
		Vector3.new(47, 3, -152), Vector3.new(61, 3, -152),
	},
	-- Zone 10: East Wing (Sunken Catacombs) - Bone Sanctuary
	{
		Vector3.new(44, 3, -126), Vector3.new(56, 3, -126),
		Vector3.new(38, 3, -124), Vector3.new(62, 3, -124),
		Vector3.new(46, 3, -120), Vector3.new(54, 3, -120),
		Vector3.new(40, 3, -135), Vector3.new(60, 3, -135),
	},
}

local function buildScaledMobList(partySize: number, dungeon: string?)
	local coordsList = (dungeon == "Sunforged") and SUNFORGED_ZONE_MOB_COORDINATES or ZONE_MOB_COORDINATES
	local validSize = math.clamp(math.floor(partySize), 1, 4)
	local mobsPerZone = 2 * validSize
	local list = {}

	for zoneIndex, coords in ipairs(coordsList) do
		for i = 1, mobsPerZone do
			local pos = coords[i]
			if not pos then
				local base = coords[1] or Vector3.new(0, 3, 0)
				local angle = (i / mobsPerZone) * 2 * math.pi
				pos = base + Vector3.new(math.cos(angle) * 3.5, 0, math.sin(angle) * 3.5)
			end
			table.insert(list, {
				position = pos,
				packIndex = zoneIndex,
				isSunforged = (dungeon == "Sunforged"),
			})
		end
	end

	return list
end

-- Hub and dungeon servers are the same published place with one shared
-- Workspace, so the only SpawnLocation Part in it is the hub's -- Roblox's
-- default spawn-point selection (used by both the engine's own auto-spawn and
-- a bare LoadCharacter() call) would otherwise place every dungeon entrant at
-- the hub's spawn coordinates instead of ENTRANCE_POSITION, landing them right
-- next to the boss instead of a safe distance away. Mirrors the exact
-- technique RespawnService.respawnAtEntrance already uses for repositioning
-- after a respawn -- this is the same fix, just for the very first spawn.
local function moveCharacterToEntrance(character: Model)
	local targetPos = (currentDungeonId == "Sunforged") and SUNFORGED_ENTRANCE_POSITION or ENTRANCE_POSITION
	local targetCF = CFrame.new(targetPos)

	local function doReposition()
		if not character or not character.Parent then return end
		character:PivotTo(targetCF)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			pcall(function()
				Net.Get("TeleportClient"):FireClient(player, targetCF)
			end)
		end
	end

	doReposition()
	task.defer(doReposition)
	task.delay(0.12, function()
		if character and character.Parent then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - targetPos).Magnitude > 30 then
				doReposition()
			end
		end
	end)
end

-- userId -> accumulated EXP/fragments/gold from trash mob kills this run.
-- Banked alongside the victory/wipe base rewards below, in bankRewardsAndReturnToHub,
-- REGARDLESS of outcome (unlike the victory/wipe base rewards, which do differ by
-- outcome) -- a kill is a kill, whether or not the run ultimately wipes. Not
-- persisted to the profile until bankRewardsAndReturnToHub runs, matching the
-- profile's own anti-dupe ordering rule (must be in memory before any teleport away).
local pendingMobEXP = {}
local pendingMobFragments = {}
local pendingMobGold = {}

local function awardMobKillRewards(player: Player)
	local isSunforged = (currentDungeonId == "Sunforged")
	local expGain = isSunforged and 18 or MOB_EXP_REWARD
	local fragGain = isSunforged and 0 or MOB_FRAGMENT_REWARD
	local goldGain = isSunforged and 15 or MOB_GOLD_REWARD

	pendingMobEXP[player.UserId] = (pendingMobEXP[player.UserId] or 0) + expGain
	pendingMobFragments[player.UserId] = (pendingMobFragments[player.UserId] or 0) + fragGain
	pendingMobGold[player.UserId] = (pendingMobGold[player.UserId] or 0) + goldGain
end

local function bankRewardsAndReturnToHub(result: "victory" | "wipe")
	local isSunforged = (currentDungeonId == "Sunforged")
	local expBase = 0
	local fragmentBase = 0
	local goldBase = 0

	if isSunforged then
		expBase = (result == "victory") and 350 or 60
		goldBase = (result == "victory") and 200 or 40
		fragmentBase = (result == "victory") and 3 or 1 -- AncientRunes
	else
		expBase = (result == "victory") and EXP_REWARD_ON_VICTORY or EXP_REWARD_ON_WIPE
		fragmentBase = (result == "victory") and FRAGMENT_REWARD_ON_VICTORY or FRAGMENT_REWARD_ON_WIPE
		goldBase = (result == "victory") and GOLD_REWARD_ON_VICTORY or GOLD_REWARD_ON_WIPE
	end

	-- Bank BEFORE teleporting away, per spec section 1a's anti-dupe/anti-loss
	-- ordering rule: the mutation must be in memory before the player leaves
	-- this server, even if they disconnect the instant they land in the hub.
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.GetProfile(player)

		local totalEXP = expBase + (pendingMobEXP[player.UserId] or 0)
		local totalFragments = fragmentBase + (pendingMobFragments[player.UserId] or 0)
		local totalGold = goldBase + (pendingMobGold[player.UserId] or 0)

		if profile then
			local charData = profile.Data.Character
			charData.UnspentEXP += totalEXP
			charData.Gold += totalGold
			if isSunforged then
				charData.CraftingMaterials.AncientRune = (charData.CraftingMaterials.AncientRune or 0) + totalFragments
				if result == "victory" then
					charData.CraftingMaterials.SunstoneCore = (charData.CraftingMaterials.SunstoneCore or 0) + 1
				end
			else
				charData.CraftingMaterials.RockhideFragment = (charData.CraftingMaterials.RockhideFragment or 0) + totalFragments
			end
		end

		Net.Get("DungeonResult"):FireClient(player, result, totalEXP, totalFragments, totalGold)
	end

	task.wait(5.0) -- Give players 5 seconds to enjoy the cinematic victory celebration and view rewards before teleport

	local teleportOk, teleportErr = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, Players:GetPlayers())
	end)
	if not teleportOk then
		warn("DungeonSessionService: TeleportAsync back to hub failed:", teleportErr)
		-- Fallback so player is never stranded without a character or camera
		Players.CharacterAutoLoads = true
		for _, player in Players:GetPlayers() do
			if not player.Character or not player.Character.Parent then
				player:LoadCharacter()
			end
			task.defer(function()
				local root = player.Character and player.Character:WaitForChild("HumanoidRootPart", 5)
				if root then
					root.CFrame = CFrame.new(ENTRANCE_POSITION)
				end
			end)
		end
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

	-- Roblox's default BreakJointsOnDeath ragdolls (breaks the joints of) a character
	-- the instant Died fires. RespawnService's revive logic only restores Health
	-- afterward, which does NOT undo an already-broken ragdoll -- so this must be set
	-- here, at spawn time, before the character can ever die. It's checked at the
	-- moment Died fires, not read live from the revive path.
	humanoid.BreakJointsOnDeath = false

	-- Without this, spawned Humanoids sit at Roblox's default 100 HP instead of
	-- the player's class's intended baseHealth. Uses WaitForProfile (not
	-- GetProfile) because this can run during a player's very first spawn on a
	-- fresh dungeon server, while PlayerDataService's own async load (or a
	-- session-lock handoff from the hub server) may still be in flight --
	-- GetProfile would return nil in that window and silently fall back to
	-- Tank's baseHealth, reintroducing the exact bug this function's caller was
	-- fixed for. Yielding here is safe: hookPlayerDeath is only ever called
	-- from within spawnAndHook below, which already yields on
	-- player:LoadCharacter() and is explicitly designed (see its comments) to
	-- tolerate a yield at this point in the flow. Falls back to Tank if the
	-- profile load fails/the player disconnects while waiting, or the profile
	-- carries an unrecognized ClassId.
	local profile = PlayerDataService.WaitForProfile(player)
	local classId = (profile and profile.Data.Character.ClassId) or "Tank"
	local classData = Classes[classId] or Classes.Tank
	humanoid.MaxHealth = classData.baseHealth
	humanoid.Health = classData.baseHealth

	humanoid.Died:Connect(function()
		RespawnService.OnPlayerDowned(player)
	end)

	WeaponService.EquipWeapons(character)
	SkillTreeService.SyncSkills(player)
	if profile and profile.Data and profile.Data.Character then
		local char = profile.Data.Character
		Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP, char.ClassId)
	end
end

function DungeonSessionService.Start(dungeonId: string, partyUserIds: {number}?)
	if dungeonId ~= "Rockhide" and dungeonId ~= "Sunforged" then
		return
	end
	currentDungeonId = dungeonId

	-- Hub-only scenery cleanup (RockhidePortal/LevelUpShrine/SpawnLocation)
	-- happens in Main.server.lua, at the same branch point that decided this
	-- is a dungeon server -- see the comment there for why that's the one
	-- place this belongs, not scattered across each server-type's own Start().

	local ended = false
	local bossHandle
	local stopMobs: (() -> ())? = nil

	-- Dynamically scale monster count: 20 monsters * party member count
	local partySize = 1
	if partyUserIds and #partyUserIds > 0 then
		partySize = #partyUserIds
	else
		local testSize = ReplicatedStorage:GetAttribute("TestPartySize")
		if type(testSize) == "number" and testSize >= 1 then
			partySize = testSize
		else
			partySize = math.max(1, #Players:GetPlayers())
		end
	end
	partySize = math.clamp(math.floor(partySize), 1, 4)

	local isSunforged = (currentDungeonId == "Sunforged")
	local mapService = isSunforged and SunforgedCitadelMapService or DungeonMapService
	local entrancePos = isSunforged and SUNFORGED_ENTRANCE_POSITION or ENTRANCE_POSITION
	local bossCFrame = isSunforged and SUNFORGED_BOSS_SPAWN_CFRAME or BOSS_SPAWN_CFRAME
	local bossName = isSunforged and "Solarius" or "Rockhide"

	local mobSpawns = buildScaledMobList(partySize, currentDungeonId)
	local totalMobs = #mobSpawns
	local mobsRemaining = totalMobs
	local isGateUnlocked = false
	local isGateOpen = false

	local function syncObjective(player: Player?)
		local objText = isSunforged and "Slay Citadel Sentinels" or "Slay Dungeon Guardians"
		if isGateOpen then
			objText = isSunforged and "Defeat Solarius, Sun of the Colosseum" or "Defeat Rockhide the Earthbreaker"
		elseif isGateUnlocked then
			objText = isSunforged and "Open Solar Chamber Gate" or "Open Boss Chamber Gate"
		end
		local kills = totalMobs - mobsRemaining
		if player then
			Net.Get("DungeonObjectiveChanged"):FireClient(player, objText, kills, totalMobs, isGateUnlocked, isGateOpen)
		else
			Net.Get("DungeonObjectiveChanged"):FireAllClients(objText, kills, totalMobs, isGateUnlocked, isGateOpen)
		end
	end

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
		mapService.UnsealBossGate()
		RespawnService.Stop()
		if stopMobs then
			stopMobs()
		end
		bankRewardsAndReturnToHub(result)
	end

	local function handleOpenGate()
		if not isGateUnlocked or isGateOpen or ended then
			return
		end
		isGateOpen = true

		mapService.OpenBossGate(function()
			-- Awaken Boss in the arena!
			if not bossHandle and not ended then
				bossHandle = BossAIService.SpawnBoss(bossName, bossCFrame, function()
					endSession("victory")
				end)
			end
			syncObjective()
		end)
	end

	DungeonSessionService.OpenBossGateForTesting = function()
		isGateUnlocked = true
		handleOpenGate()
	end

	-- Build the grand MMO dungeon environment (antechamber, labyrinth, boss colosseum)
	mapService.BuildDungeon()
	mapService.UpdateGateStatus(mobsRemaining, totalMobs)
	mapService.SetOnGateOpenRequested(handleOpenGate)

	Net.Get("RequestOpenBossGate").OnServerEvent:Connect(function(player)
		handleOpenGate()
	end)

	-- Set up RespawnService before spawning the boss so death hooks are in place.
	RespawnService.SetEntrancePosition(entrancePos)
	RespawnService.Start()

	stopMobs = MonsterAIService.SpawnMobs(mobSpawns, awardMobKillRewards, function(remaining, total)
		mobsRemaining = remaining
		mapService.UpdateGateStatus(mobsRemaining, totalMobs)
		if mobsRemaining == 0 and not isGateUnlocked then
			isGateUnlocked = true
		end
		syncObjective()
	end)

	-- Disable the engine's own auto-respawn up front. A party of 2-4 players
	-- teleported together via one TeleportAsync call do NOT all land on this
	-- server in the same tick -- each client connects independently, staggered
	-- by hundreds of ms to seconds -- so we can't rely on "whoever's already
	-- connected already has a character" and let CharacterAutoLoads handle
	-- everyone else: any party member who connects after this line would then
	-- never get an automatic spawn and be stuck characterless for the whole
	-- dungeon. Instead, spawnAndHook below makes spawning explicit and uniform
	-- for every player, whether already connected or joining later. From this
	-- point on, every respawn-after-death also goes exclusively through
	-- RespawnService's own player:LoadCharacter() call in respawnAtEntrance --
	-- otherwise the engine would silently respawn a downed Humanoid ~5s after
	-- death (CharacterAutoLoads default) at the default SpawnLocation instead
	-- of ENTRANCE_POSITION, mid-bleed-out or mid-revive-channel, and
	-- RespawnService's own pending bleed-out timer would later fire too and
	-- yank the player a second time. Players is a per-server service instance,
	-- so this only affects this dungeon server; the hub server keeps normal
	-- auto-respawn.
	Players.CharacterAutoLoads = false

	-- Spawns (or hooks) exactly one character per player, whether they already
	-- had one when this ran or join/spawn later. CharacterAdded is connected
	-- FIRST, before checking/calling LoadCharacter(), so the character created
	-- by the LoadCharacter() call below can never be missed: LoadCharacter()
	-- yields until the character is loaded as part of firing CharacterAdded,
	-- so connecting only after the call returns would race (and could lose)
	-- that event.
	--
	-- hookedPlayers guards against processing the same player twice. This
	-- matters because player:LoadCharacter() below yields the calling
	-- coroutine until the character loads -- if that happens inside the
	-- initial GetPlayers() loop further down, any other party member whose
	-- PlayerAdded fires during that yield must still be caught, which is why
	-- PlayerAdded is connected BEFORE the loop runs. That ordering creates a
	-- narrow window (between the :Connect call and :GetPlayers() being read)
	-- where a joining player could be picked up by both the connection and
	-- the loop's snapshot; without this guard that would mean a duplicate
	-- LoadCharacter() call and two CharacterAdded connections stacked on the
	-- same player.
	local hookedPlayers = {}

	local function spawnAndHook(player: Player)
		if hookedPlayers[player.UserId] then
			return
		end
		-- Set BEFORE the pcall below, not after: a failed attempt (e.g. the
		-- Player instance has already gone stale because they disconnected
		-- while this loop was yielded on an earlier player's LoadCharacter())
		-- must not be silently retried or double-processed later.
		hookedPlayers[player.UserId] = true

		-- A player in the initial GetPlayers() snapshot can disconnect while
		-- this function is yielded inside an earlier player's LoadCharacter()
		-- call (plausible during a multi-second dungeon teleport where party
		-- members land staggered). Operating on that now-stale Player instance
		-- could throw; without this pcall, an uncaught error here would abort
		-- the rest of this for loop AND everything after it in Start() --
		-- BossAIService.SpawnBoss and the wipe-detection loop would never run --
		-- leaving every subsequent player in the snapshot unhooked. Catching it
		-- here means one player's failure can't take the rest of the party (or
		-- the boss/wipe setup) down with it.
		local ok, err = pcall(function()
			player.CharacterAdded:Connect(function(character)
				hookPlayerDeath(player, character)
			end)
			if player.Character then
				-- Reposition immediately to entrance platform before any async yields
				moveCharacterToEntrance(player.Character)
				hookPlayerDeath(player, player.Character)
			else
				-- No character yet, and CharacterAutoLoads is now off, so the
				-- engine won't spawn one on its own -- spawn it explicitly.
				player:LoadCharacter()
				if player.Character then
					moveCharacterToEntrance(player.Character)
					hookPlayerDeath(player, player.Character)
				end
			end
		end)
		if not ok then
			warn(("DungeonSessionService: spawnAndHook failed for %s: %s"):format(player.Name, tostring(err)))
		end
	end

	-- Connect PlayerAdded BEFORE looping over the initial snapshot: spawnAndHook's
	-- player:LoadCharacter() call yields, so if the loop below is parked waiting
	-- for one player's character to load, any other party member's PlayerAdded
	-- must already have somewhere to go -- otherwise, with CharacterAutoLoads off
	-- and Main.server.lua's dispatch listener already consumed (:Once), that
	-- player would get no character for the whole dungeon.
	Players.PlayerAdded:Connect(function(player)
		spawnAndHook(player)
		syncObjective(player)
	end)
	for _, player in Players:GetPlayers() do
		spawnAndHook(player)
		syncObjective(player)
	end

	-- Re-sync objectives on brief delays to ensure asynchronous client controllers receive it
	task.delay(1.0, function()
		if not ended then
			syncObjective()
		end
	end)
	task.delay(2.5, function()
		if not ended then
			syncObjective()
		end
	end)

	-- Wipe detection:
	-- 1. Wait a 10s grace period on dungeon start so players connecting/loading character models don't trigger a false wipe.
	-- 2. Do NOT declare a wipe if any player is alive (Health > 0) OR if any player is currently downed and in their bleedout/revive window.
	-- 3. Require 3 consecutive checks (3 seconds) of no alive and no downed players before declaring a wipe, preventing respawn transition races.
	task.spawn(function()
		task.wait(10)
		local consecutiveWipeTicks = 0
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

			local isAnyoneDowned = RespawnService.IsAnyoneDowned()

			if not anyAlive and not isAnyoneDowned and #Players:GetPlayers() > 0 then
				consecutiveWipeTicks += 1
				if consecutiveWipeTicks >= 3 then
					-- Call endSession first so it wins the race even though ForceKill
					-- triggers the boss's own onDeath("victory") attempt -- by then
					-- `ended` is already true, so that attempt is a no-op.
					endSession("wipe")
					if bossHandle then
						BossAIService.ForceKill(bossHandle)
					end
					break
				end
			else
				consecutiveWipeTicks = 0
			end
		end
	end)

end

return DungeonSessionService
