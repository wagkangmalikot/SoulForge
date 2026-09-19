# Dungeon Raid Rewards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Award `RockhideFragment` crafting material and `Gold` currency at the end of a dungeon raid, alongside the existing EXP reward, with victory giving a full base amount, wipe giving 20% of it, and trash mob kills adding a small per-kill bonus banked regardless of outcome.

**Architecture:** Add the new material to the shared `Equipment.lua` data registry and a new `Gold` field to `PlayerDataService`'s profile schema, then extend `DungeonSessionService`'s existing EXP-only reward-banking path (constants, per-kill accumulation, and the final banking function) to compute and bank all three reward types the same way, and extend the `DungeonResult` net event + its one client-side listener to display all three.

**Tech Stack:** Roblox Studio (Luau), Rojo-synced `src/` tree, Roblox Studio MCP tools (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`) for live verification.

**Spec:** [docs/superpowers/specs/2026-09-17-raid-rewards-design.md](../specs/2026-09-17-raid-rewards-design.md)

**Studio target:** `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8` ("Soul Forge", placeId 125354010947424). Re-resolve with `list_roblox_studios` if this id is no longer connected when execution starts.

---

### Task 1: Add the `RockhideFragment` material to `Equipment.lua`

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Equipment.lua`

- [ ] **Step 1: Add the material entry**

Find (the end of the `Materials` table, current lines 143-150):
```lua
		AncientRune = {
			id = "AncientRune",
			displayName = "Ancient Rune",
			tier = 3,
			rarity = "Epic",
			description = "A carved stone fragment humming with forgotten runic magic. Infuses weapons with holy luminous fuller channels.",
			maxStack = 20,
		},
	},
```
Replace with:
```lua
		AncientRune = {
			id = "AncientRune",
			displayName = "Ancient Rune",
			tier = 3,
			rarity = "Epic",
			description = "A carved stone fragment humming with forgotten runic magic. Infuses weapons with holy luminous fuller channels.",
			maxStack = 20,
		},
		RockhideFragment = {
			id = "RockhideFragment",
			displayName = "Rockhide Fragment",
			tier = 3,
			rarity = "Rare",
			description = "A jagged shard of Rockhide's stone hide, still warm with residual seismic energy. Earned only by braving the boss chamber.",
			maxStack = 99,
		},
	},
```

- [ ] **Step 2: Verify**

Run:
```bash
grep -n "RockhideFragment" "Soulforge/src/ReplicatedStorage/Shared/Data/Equipment.lua"
```
Expected: one match, the new entry.

---

### Task 2: Add `Character.Gold` to `PlayerDataService.lua`

**Files:**
- Modify: `src/ServerScriptService/Services/PlayerDataService.lua`

- [ ] **Step 1: Add `Gold` to `DEFAULT_DATA`**

Find (current lines 9-30):
```lua
local DEFAULT_DATA = {
	Character = {
		Level = 1,
		ClassId = "Tank",
		UnspentEXP = 0,
		SkillPoints = 0,
		UnlockedSkills = {"Taunt"},
		EquippedSkills = {"Taunt"},
		EquippedWeapon = "Standard",
		EquippedShield = "Standard",
		StoredEquipment = {"Standard", "Sunforged"},
		CraftingMaterials = {
			IronIngot = 8,
			OakTimber = 6,
			LeatherStrap = 4,
			SunstoneCore = 1,
			AncientRune = 2,
		},
		Name = "",                    -- set at character creation (spec 2b), TextService-filtered
		HasCreatedCharacter = false,  -- gates whether the creation screen shows on join
	},
}
```
Replace with:
```lua
local DEFAULT_DATA = {
	Character = {
		Level = 1,
		ClassId = "Tank",
		UnspentEXP = 0,
		SkillPoints = 0,
		UnlockedSkills = {"Taunt"},
		EquippedSkills = {"Taunt"},
		EquippedWeapon = "Standard",
		EquippedShield = "Standard",
		StoredEquipment = {"Standard", "Sunforged"},
		CraftingMaterials = {
			IronIngot = 8,
			OakTimber = 6,
			LeatherStrap = 4,
			SunstoneCore = 1,
			AncientRune = 2,
		},
		Gold = 0,
		Name = "",                    -- set at character creation (spec 2b), TextService-filtered
		HasCreatedCharacter = false,  -- gates whether the creation screen shows on join
	},
}
```

- [ ] **Step 2: Add the reconcile fallback for existing saves**

Find (current lines 114-122):
```lua
		if not charData.CraftingMaterials then
			charData.CraftingMaterials = {
				IronIngot = 8,
				OakTimber = 6,
				LeatherStrap = 4,
				SunstoneCore = 1,
				AncientRune = 2,
			}
		end
```
Replace with:
```lua
		if not charData.CraftingMaterials then
			charData.CraftingMaterials = {
				IronIngot = 8,
				OakTimber = 6,
				LeatherStrap = 4,
				SunstoneCore = 1,
				AncientRune = 2,
			}
		end
		if charData.Gold == nil then
			-- nil-check, not a truthiness/length check like the array fields above --
			-- 0 is a valid already-set value that must not be overwritten back to 0.
			charData.Gold = 0
		end
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -n "Gold" "Soulforge/src/ServerScriptService/Services/PlayerDataService.lua"
```
Expected: two matches (the `DEFAULT_DATA` field and the reconcile check).

---

### Task 3: Extend `DungeonSessionService.lua`'s reward banking

**Files:**
- Modify: `src/ServerScriptService/Services/DungeonSessionService.lua`

- [ ] **Step 1: Add the new reward constants**

Find (current lines 17-30):
```lua
local EXP_REWARD_ON_VICTORY = 50 -- flat value for this slice; real EXP formulas are a later plan

-- Grand Colosseum Center (deep inside the boss arena, facing toward the gate at Z = -25)
local BOSS_SPAWN_CFRAME = CFrame.new(0, 1, 45) * CFrame.Angles(0, math.pi, 0)

-- Staging Antechamber safe entrance platform (Z = -285)
local ENTRANCE_POSITION = Vector3.new(0, 5, -285)

-- Trash mob placements: 1 minion for fast testing of gate opening and boss entry
local MOB_EXP_REWARD = 5
local MOB_POSITIONS = {
	-- Central Colonnade - Test Sentinel
	Vector3.new(0, 3, -100),
}
```
Replace with:
```lua
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

-- Trash mob placements: 1 minion for fast testing of gate opening and boss entry
local MOB_POSITIONS = {
	-- Central Colonnade - Test Sentinel
	Vector3.new(0, 3, -100),
}
```

- [ ] **Step 2: Track fragment and gold accumulation alongside EXP, and rename the per-kill callback**

Find (current lines 49-58):
```lua
-- userId -> accumulated EXP from trash mob kills this run. Banked alongside
-- EXP_REWARD_ON_VICTORY below, following the SAME (currently victory-only,
-- nothing-on-wipe) behavior the boss reward already has. Not persisted to the
-- profile until bankRewardsAndReturnToHub runs, matching the profile's own
-- anti-dupe ordering rule (must be in memory before any teleport away).
local pendingMobEXP = {}

local function awardMobKillEXP(player: Player)
	pendingMobEXP[player.UserId] = (pendingMobEXP[player.UserId] or 0) + MOB_EXP_REWARD
end
```
Replace with:
```lua
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
	pendingMobEXP[player.UserId] = (pendingMobEXP[player.UserId] or 0) + MOB_EXP_REWARD
	pendingMobFragments[player.UserId] = (pendingMobFragments[player.UserId] or 0) + MOB_FRAGMENT_REWARD
	pendingMobGold[player.UserId] = (pendingMobGold[player.UserId] or 0) + MOB_GOLD_REWARD
end
```

- [ ] **Step 3: Rewrite `bankRewardsAndReturnToHub` to bank all three reward types on both outcomes**

Find (current lines 60-74):
```lua
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
```
Replace with:
```lua
local function bankRewardsAndReturnToHub(result: "victory" | "wipe")
	-- Bank BEFORE teleporting away, per spec section 1a's anti-dupe/anti-loss
	-- ordering rule: the mutation must be in memory before the player leaves
	-- this server, even if they disconnect the instant they land in the hub.
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.GetProfile(player)

		local expBase = (result == "victory") and EXP_REWARD_ON_VICTORY or EXP_REWARD_ON_WIPE
		local fragmentBase = (result == "victory") and FRAGMENT_REWARD_ON_VICTORY or FRAGMENT_REWARD_ON_WIPE
		local goldBase = (result == "victory") and GOLD_REWARD_ON_VICTORY or GOLD_REWARD_ON_WIPE

		local totalEXP = expBase + (pendingMobEXP[player.UserId] or 0)
		local totalFragments = fragmentBase + (pendingMobFragments[player.UserId] or 0)
		local totalGold = goldBase + (pendingMobGold[player.UserId] or 0)

		if profile then
			local charData = profile.Data.Character
			charData.UnspentEXP += totalEXP
			charData.CraftingMaterials.RockhideFragment = (charData.CraftingMaterials.RockhideFragment or 0) + totalFragments
			charData.Gold += totalGold
		end

		Net.Get("DungeonResult"):FireClient(player, result, totalEXP, totalFragments, totalGold)
	end

	task.wait(2) -- let the client show the result briefly before the teleport cuts the screen
```

- [ ] **Step 4: Update the `SpawnMobs` call site to use the renamed callback**

Find:
```lua
	stopMobs = MonsterAIService.SpawnMobs(MOB_POSITIONS, awardMobKillEXP, function(remaining, total)
```
Replace with:
```lua
	stopMobs = MonsterAIService.SpawnMobs(MOB_POSITIONS, awardMobKillRewards, function(remaining, total)
```

- [ ] **Step 5: Verify no leftover references to the old name, and that the new constants/functions are all used**

Run:
```bash
grep -n "awardMobKillEXP\|awardMobKillRewards\|pendingMobFragments\|pendingMobGold\|FRAGMENT_REWARD\|GOLD_REWARD\|EXP_REWARD_ON_WIPE" "Soulforge/src/ServerScriptService/Services/DungeonSessionService.lua"
```
Expected: zero matches for `awardMobKillEXP` (old name); at least one match each for `awardMobKillRewards`, `pendingMobFragments`, `pendingMobGold`, `FRAGMENT_REWARD_ON_VICTORY`, `FRAGMENT_REWARD_ON_WIPE`, `MOB_FRAGMENT_REWARD`, `GOLD_REWARD_ON_VICTORY`, `GOLD_REWARD_ON_WIPE`, `MOB_GOLD_REWARD`, `EXP_REWARD_ON_WIPE`.

---

### Task 4: Update the `DungeonResult` net event and its client listener

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Net.lua`
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/DownedUIController.lua`

- [ ] **Step 1: Update the `DungeonResult` remote's documentation comment**

Find (in `Net.lua`):
```lua
	"DungeonResult",          -- server -> client: {result = "victory" | "wipe", expEarned}
```
Replace with:
```lua
	"DungeonResult",          -- server -> client: {result = "victory" | "wipe", expEarned, fragmentsEarned, goldEarned}
```

- [ ] **Step 2: Update the client handler to show all three rewards**

Find (in `DownedUIController.lua`, current lines 109-118):
```lua
	Net.Get("DungeonResult").OnClientEvent:Connect(function(result, expEarned)
		-- Hide downed overlay if it was showing when the session ended.
		downedLabel.Visible = false
		reviveBarBackground.Visible = false

		resultLabel.Text = result == "victory"
			and ("VICTORY! +" .. expEarned .. " EXP — returning to hub…")
			or "WIPED — returning to hub…"
		resultLabel.Visible = true
	end)
end
```
Replace with:
```lua
	Net.Get("DungeonResult").OnClientEvent:Connect(function(result, expEarned, fragmentsEarned, goldEarned)
		-- Hide downed overlay if it was showing when the session ended.
		downedLabel.Visible = false
		reviveBarBackground.Visible = false

		local rewardsText = ("+%d EXP, +%d Fragments, +%d Gold"):format(expEarned, fragmentsEarned, goldEarned)
		resultLabel.Text = result == "victory"
			and ("VICTORY! " .. rewardsText .. " — returning to hub…")
			or ("WIPED — " .. rewardsText .. " — returning to hub…")
		resultLabel.Visible = true
	end)
end
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -n "fragmentsEarned\|goldEarned" "Soulforge/src/ReplicatedStorage/Shared/Net.lua" "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/DownedUIController.lua"
```
Expected: matches in both files.

---

### Task 5: Live verification and commit

**Files:**
- (verifies) `src/ReplicatedStorage/Shared/Data/Equipment.lua`
- (verifies) `src/ServerScriptService/Services/PlayerDataService.lua`
- (verifies) `src/ServerScriptService/Services/DungeonSessionService.lua`
- (verifies) `src/ReplicatedStorage/Shared/Net.lua`
- (verifies) `src/StarterPlayer/StarterPlayerScripts/Controllers/DownedUIController.lua`

- [ ] **Step 1: Confirm Studio is in Edit mode, then start Play**

Call `mcp__Roblox_Studio__get_studio_state` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`. If `Play`, call `start_stop_play` with `is_start: false` first. Then call `start_stop_play` with `is_start: true`.

- [ ] **Step 2: Check console for errors**

Call `mcp__Roblox_Studio__get_console_output`.

Expected: no Luau errors referencing `DungeonSessionService`, `PlayerDataService`, `Equipment`, `Net`, or `DownedUIController` (pre-existing unrelated noise like the animation-load warnings is expected and not a regression). In particular, no error about `CraftingMaterials` being nil or `Gold` being nil when the profile loads — this would indicate the reconcile fallback in Task 2 Step 2 has a bug.

- [ ] **Step 3: Verify a fresh profile's starting state**

Call `mcp__Roblox_Studio__execute_luau` with `datamodel_type: "Server"`:
```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local PlayerDataService = require(game:GetService("ServerScriptService").Services.PlayerDataService)
local profile = PlayerDataService.GetProfile(player)
return "Gold=" .. tostring(profile.Data.Character.Gold) .. " RockhideFragment=" .. tostring(profile.Data.Character.CraftingMaterials.RockhideFragment)
```
Note: this `require` may fail with the same `Capabilities`/`LoadUnownedAsset` sandbox error seen in prior verification passes this session (`DungeonMapService`/`CombatService` hit this earlier). If so, skip straight to Step 4 and rely on the `DungeonResult` client display for verification instead — don't spend time working around the sandbox restriction.

Expected (if it works): `Gold=0 RockhideFragment=nil` for a brand new profile (the field exists as `0`/absent respectively, matching `DEFAULT_DATA`).

- [ ] **Step 4: Trigger a wipe and confirm the reward text**

The fastest path to a wipe: force the player's Humanoid to 0 HP while downed state has no one left alive (matches the technique used for the "downed players can still attack" bug fix earlier this session — see that verification pass for the exact `execute_luau` pattern to force `Health = 0` and confirm the "DOWNED" state). Since `DungeonSessionService`'s wipe-detection loop requires 3 consecutive seconds of no alive/no downed players, either let a natural wipe occur, or accept a longer wait.

Call `mcp__Roblox_Studio__screen_capture` once the `DungeonResult` fires (the result overlay appears center-screen).

Expected: the result text reads `"WIPED — +10 EXP, +1 Fragments, +5 Gold — returning to hub…"` (or higher numbers if a trash mob was killed first, e.g. `+11 EXP, +2 Fragments, +10 Gold` if the one mob in `MOB_POSITIONS` was killed before the wipe).

- [ ] **Step 5: Stop Play**

Call `start_stop_play` with `is_start: false`.

- [ ] **Step 6: Commit**

```bash
git add "Soulforge/src/ReplicatedStorage/Shared/Data/Equipment.lua" "Soulforge/src/ServerScriptService/Services/PlayerDataService.lua" "Soulforge/src/ServerScriptService/Services/DungeonSessionService.lua" "Soulforge/src/ReplicatedStorage/Shared/Net.lua" "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/DownedUIController.lua"
git commit -m "$(cat <<'EOF'
Add fragment and gold rewards to dungeon raid results

Victory banks a full base reward (50 EXP, 5 RockhideFragment, 25
Gold); a wipe now banks 20% of that (10 EXP, 1 Fragment, 5 Gold)
instead of the previous 0 EXP. Trash mob kills add a small per-kill
bonus to all three, credited regardless of outcome -- only the flat
completion bonus is contingent on victory. Adds Character.Gold to the
player profile schema and a new RockhideFragment crafting material,
both wired through the existing DungeonResult end-of-raid flow.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Notes for whoever executes this plan

- Tasks 1 and 2 (`Equipment.lua`, `PlayerDataService.lua`) are independent of each other and of Task 3, and can be done in any order or in parallel by different subagents. Task 3 (`DungeonSessionService.lua`) depends on Task 1's material existing conceptually (it references `RockhideFragment` by string key, which works even if Task 1 hasn't landed yet since Lua tables don't require pre-declared keys, but both should land before Task 5's verification). Task 4 (`Net.lua` + `DownedUIController.lua`) is independent of Tasks 1-3's implementation details but conceptually depends on the same payload shape Task 3 sends — the parameter order `(result, expEarned, fragmentsEarned, goldEarned)` must match exactly between Task 3 Step 3's `FireClient` call and Task 4 Step 2's handler.
- If a fresh profile is hard to obtain for Task 5 Step 3 (e.g. the test player already has a saved profile from earlier sessions this conversation, which would already show non-zero `Gold`/`RockhideFragment` from... actually no prior task in this conversation banked gold/fragments, so a returning profile should still show `Gold=0`/`RockhideFragment=nil` unless a wipe/victory already ran with this plan's code active) -- that's fine, just note the actual values seen rather than treating a non-zero `Gold` as a failure, since Task 5 Step 4 itself will bank a nonzero amount.
