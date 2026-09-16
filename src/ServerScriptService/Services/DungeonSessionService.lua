-- src/ServerScriptService/Services/DungeonSessionService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local BossAIService = require(script.Parent.BossAIService)
local MonsterAIService = require(script.Parent.MonsterAIService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RespawnService = require(script.Parent.RespawnService)

local DungeonSessionService = {}

local EXP_REWARD_ON_VICTORY = 50 -- flat value for this slice; real EXP formulas are a later plan

local BOSS_SPAWN_CFRAME = CFrame.new(0, 5, 0)
-- Moved to the far end of the lengthened entrance corridor (Studio-side
-- geometry change, done directly in the published place -- see this plan's
-- Studio Content section) so players have to walk past the trash mobs
-- below to reach the boss, instead of spawning already at the chamber
-- threshold.
local ENTRANCE_POSITION = Vector3.new(0, 5, -105)

-- Trash mob placements (spec 10a): 3 clusters of 2, spaced along the
-- corridor between the entrance and the boss chamber. Corridor is 10 studs
-- wide (x = -5 to 5), so +-2.5 keeps each pair comfortably clear of the walls.
local MOB_EXP_REWARD = 5
local MOB_POSITIONS = {
	Vector3.new(-2.5, 2, -90), Vector3.new(2.5, 2, -90),
	Vector3.new(-2.5, 2, -60), Vector3.new(2.5, 2, -60),
	Vector3.new(-2.5, 2, -30), Vector3.new(2.5, 2, -30),
}

-- Hub and dungeon servers are the same published place with one shared
-- Workspace, so the only SpawnLocation Part in it is the hub's -- Roblox's
-- default spawn-point selection (used by both the engine's own auto-spawn and
-- a bare LoadCharacter() call) would otherwise place every dungeon entrant at
-- the hub's spawn coordinates instead of ENTRANCE_POSITION, landing them right
-- next to the boss instead of a safe distance away. Mirrors the exact
-- technique RespawnService.respawnAtEntrance already uses for repositioning
-- after a respawn -- this is the same fix, just for the very first spawn.
local function moveCharacterToEntrance(character: Model)
	task.defer(function()
		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if rootPart then
			rootPart.CFrame = CFrame.new(ENTRANCE_POSITION)
		end
	end)
end

-- userId -> accumulated EXP from trash mob kills this run. Banked alongside
-- EXP_REWARD_ON_VICTORY below, following the SAME (currently victory-only,
-- nothing-on-wipe) behavior the boss reward already has. Not persisted to the
-- profile until bankRewardsAndReturnToHub runs, matching the profile's own
-- anti-dupe ordering rule (must be in memory before any teleport away).
local pendingMobEXP = {}

local function awardMobKillEXP(player: Player)
	pendingMobEXP[player.UserId] = (pendingMobEXP[player.UserId] or 0) + MOB_EXP_REWARD
end

local function bankRewardsAndReturnToHub(result: "victory" | "wipe")
	-- Bank BEFORE teleporting away, per spec section 1a's anti-dupe/anti-loss
	-- ordering rule: the mutation must be in memory before the player leaves
	-- this server, even if they disconnect the instant they land in the hub.
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.GetProfile(player)
		local totalEXP = 0
		if result == "victory" then
			totalEXP = EXP_REWARD_ON_VICTORY + (pendingMobEXP[player.UserId] or 0)
		end
		if profile and totalEXP > 0 then
			profile.Data.Character.UnspentEXP += totalEXP
		end
		Net.Get("DungeonResult"):FireClient(player, result, totalEXP)
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

	-- Roblox's default BreakJointsOnDeath ragdolls (breaks the joints of) a character
	-- the instant Died fires. RespawnService's revive logic only restores Health
	-- afterward, which does NOT undo an already-broken ragdoll -- so this must be set
	-- here, at spawn time, before the character can ever die. It's checked at the
	-- moment Died fires, not read live from the revive path.
	humanoid.BreakJointsOnDeath = false

	-- This vertical slice has exactly one class (Tank; see
	-- ReplicatedStorage/Shared/Data/Classes.lua), so hardcoding it here matches the
	-- existing Tank-only scoping used elsewhere (e.g. PlayerDataService's
	-- DEFAULT_DATA.Character.ClassId = "Tank"). Without this, spawned Humanoids sit
	-- at Roblox's default 100 HP instead of the class's intended baseHealth.
	local classData = Classes.Tank
	humanoid.MaxHealth = classData.baseHealth
	humanoid.Health = classData.baseHealth

	humanoid.Died:Connect(function()
		RespawnService.OnPlayerDowned(player)
	end)
end

function DungeonSessionService.Start(dungeonId: string)
	if dungeonId ~= "Rockhide" then
		return
	end

	-- Hub-only scenery cleanup (RockhidePortal/LevelUpShrine/SpawnLocation)
	-- happens in Main.server.lua, at the same branch point that decided this
	-- is a dungeon server -- see the comment there for why that's the one
	-- place this belongs, not scattered across each server-type's own Start().

	local ended = false
	local bossHandle
	local stopMobs: (() -> ())? = nil

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
		if stopMobs then
			stopMobs()
		end
		bankRewardsAndReturnToHub(result)
	end

	-- Set up RespawnService before spawning the boss so death hooks are in place.
	RespawnService.SetEntrancePosition(ENTRANCE_POSITION)
	RespawnService.Start()

	stopMobs = MonsterAIService.SpawnMobs(MOB_POSITIONS, awardMobKillEXP)

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
				-- Already has a character (e.g. the first player, if the engine's
				-- own auto-spawn already completed before this ran) -- hook it
				-- directly, since CharacterAdded already fired for it in the past
				-- and won't fire again for the same character.
				hookPlayerDeath(player, player.Character)
				-- The engine would have placed them at whatever SpawnLocation
				-- exists in this shared Workspace (the hub's), not
				-- ENTRANCE_POSITION -- reposition explicitly.
				moveCharacterToEntrance(player.Character)
			else
				-- No character yet, and CharacterAutoLoads is now off, so the
				-- engine won't spawn one on its own -- spawn it explicitly.
				-- Same SpawnLocation problem applies: LoadCharacter() places
				-- them via the default spawn point, not ENTRANCE_POSITION.
				player:LoadCharacter()
				if player.Character then
					moveCharacterToEntrance(player.Character)
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
	Players.PlayerAdded:Connect(spawnAndHook)
	for _, player in Players:GetPlayers() do
		spawnAndHook(player)
	end

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
