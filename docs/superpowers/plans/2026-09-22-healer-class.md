# Healer Class (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third playable class, Healer (pure support, no damage skills), fully playable end-to-end: class data, 7 skills, a new ally-targeting system, two new combat effect types (`healTarget`, `aoeHeal`), two full gear sets (starter + Rockhide tier), and every class-picker/skill-tree/equipment UI generalized from a Tank/Mage binary to a real 3-way switch.

**Architecture:** Follows the exact shape the Tank/Mage classes already use in [Classes.lua](../../src/ReplicatedStorage/Shared/Data/Classes.lua) and [Skills.lua](../../src/ReplicatedStorage/Shared/Data/Skills.lua) (data-driven, `effectType`-dispatched combat). New player-targeting reuses the existing `CastSkill` remote and click-to-target pattern in `HUDController.lua`, distinguishing a player target from an enemy target by a `"player:<userId>"` string prefix instead of a bare id. Healer gear renders with the *existing* staff/robe/hood/bracers/boots procedural models (Phase 2, a separate future plan, adds bespoke visuals) — see the design spec's stated scope cut.

**Tech Stack:** Roblox Luau, Rojo-synced project, no client/server automated test framework — verification is via Roblox Studio (`execute_luau` for data/logic, live playtests via the Roblox Studio MCP tools for anything requiring a running game).

**Testing note:** This codebase has no TestEZ or any other test framework (confirmed: no `*.spec.lua`/`*.test.lua` files anywhere, no `wally.toml`). Every "test" step below is either (a) an exact `execute_luau` snippet run against Studio's `Edit` or `Server` datamodel that asserts something and returns a pass/fail-shaped result, or (b) an exact live-playtest procedure (Studio `start_stop_play` + specific clicks/keys + an exact expected console/state result). Both are concrete and runnable — this is the same verification style already used successfully elsewhere in this project (e.g. the dungeon-entry ProximityPrompt fix), just not a literal xUnit-style "run this test file" step.

**Design reference:** [docs/superpowers/specs/2026-09-22-healer-class-design.md](../specs/2026-09-22-healer-class-design.md)

---

## Task 1: `Classes.lua` — add the Healer class

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Classes.lua`

- [ ] **Step 1: Add the `Healer` entry**

Open `src/ReplicatedStorage/Shared/Data/Classes.lua`. It currently ends with:

```lua
	Mage = {
		name = "Mage",
		baseHealth = 80,
		startingSkills = {"ArcaneBolt"},
		branches = {
			Pyromancy = {
				name = "Pyromancy",
				description = "Explosive single-target and area fire damage, high risk-reward burst.",
				skills = {"Firebolt", "Fireball", "Meteor"},
			},
			Frostweave = {
				name = "Frostweave",
				description = "Sustained frost damage that lingers on enemies after the initial strike.",
				skills = {"Frostbolt", "IceLance", "Blizzard"},
			},
		},
	},
}
```

Replace the closing `}` with a new `Healer` entry, so the file ends:

```lua
	Mage = {
		name = "Mage",
		baseHealth = 80,
		startingSkills = {"ArcaneBolt"},
		branches = {
			Pyromancy = {
				name = "Pyromancy",
				description = "Explosive single-target and area fire damage, high risk-reward burst.",
				skills = {"Firebolt", "Fireball", "Meteor"},
			},
			Frostweave = {
				name = "Frostweave",
				description = "Sustained frost damage that lingers on enemies after the initial strike.",
				skills = {"Frostbolt", "IceLance", "Blizzard"},
			},
		},
	},

	Healer = {
		name = "Healer",
		baseHealth = 90,
		startingSkills = {"Mend"},
		branches = {
			Mending = {
				name = "Mending",
				description = "Focused single-target healing that scales from a quick touch to a powerful restoration.",
				skills = {"SoothingLight", "RadiantMend", "DivineRestoration"},
			},
			Sanctuary = {
				name = "Sanctuary",
				description = "Area healing that keeps the whole party topped up, building to a party-wide burst.",
				skills = {"SacredCircle", "HealingRain", "Sanctuary"},
			},
		},
	},
}
```

- [ ] **Step 2: Verify it loads and has the right shape**

Run this in Studio, `execute_luau` with `datamodel_type: "Edit"`:

```lua
local Classes = require(game.ReplicatedStorage.Shared.Data.Classes)
local h = Classes.Healer
assert(h, "Classes.Healer missing")
assert(h.baseHealth == 90, "baseHealth wrong")
assert(h.startingSkills[1] == "Mend", "startingSkills wrong")
assert(h.branches.Mending and h.branches.Sanctuary, "branches missing")
assert(#h.branches.Mending.skills == 3 and #h.branches.Sanctuary.skills == 3, "branch skill count wrong")
return "OK"
```

Expected: returns `"OK"` with no error. (`Classes.lua` has no `Skills.lua` cross-check at require time — this only validates `Classes.lua`'s own shape. Skill ids referenced here are validated in Task 2.)

- [ ] **Step 3: Commit**

```bash
git add src/ReplicatedStorage/Shared/Data/Classes.lua
git commit -m "feat: add Healer class data"
```

---

## Task 2: `Skills.lua` — add the 7 Healer skills

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Skills.lua`

- [ ] **Step 1: Add the Healer skills**

Open `src/ReplicatedStorage/Shared/Data/Skills.lua`. Append this block right before the file's final `}` (after the `Blizzard` entry), and update the file's top comment line (`-- Definitive skills registry for all classes (Tank: Juggernaut/Bulwark; Mage: Pyromancy/Frostweave).`) to read `-- Definitive skills registry for all classes (Tank: Juggernaut/Bulwark; Mage: Pyromancy/Frostweave; Healer: Mending/Sanctuary).`. Also extend the header comment's `effectType` list (right below that line) with two new entries:

```
--   healTarget    - instant heal on a targeted ally or self (Mend, SoothingLight, RadiantMend, DivineRestoration)
--   aoeHeal       - instant heal to every party member within range, or self alone if not in a party (SacredCircle, HealingRain, Sanctuary)
```

Then add the skills themselves, right after `Blizzard`'s closing `},` and before the file's final `}`:

```lua

	-- ── BASE STARTING SKILL (Healer) ─────────────────────────────────────────
	Mend = {
		id = "Mend",
		displayName = "Mend",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/mend_icon.png",
		cooldown = 4,
		range = 30,
		healAmount = 18,
		effectType = "healTarget",
		description = "A basic restorative touch, healing yourself or a targeted party member for 18 Health.",
	},

	-- ── MENDING BRANCH (Single-Target Healing, Escalating Power) ─────────────
	SoothingLight = {
		id = "SoothingLight",
		displayName = "Soothing Light",
		branch = "Mending",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/soothing_light_icon.png",
		cooldown = 5,
		range = 30,
		healAmount = 22,
		effectType = "healTarget",
		description = "A focused beam of restorative light, healing yourself or a targeted party member for 22 Health.",
	},

	RadiantMend = {
		id = "RadiantMend",
		displayName = "Radiant Mend",
		branch = "Mending",
		tier = 2,
		prerequisite = "SoothingLight",
		icon = "rbxasset://textures/Soulforge/radiant_mend_icon.png",
		cooldown = 9,
		range = 30,
		healAmount = 34,
		effectType = "healTarget",
		description = "A surge of radiant energy, healing yourself or a targeted party member for 34 Health.",
	},

	DivineRestoration = {
		id = "DivineRestoration",
		displayName = "Divine Restoration",
		branch = "Mending",
		tier = 3,
		prerequisite = "RadiantMend",
		icon = "rbxasset://textures/Soulforge/divine_restoration_icon.png",
		cooldown = 16,
		range = 30,
		healAmount = 55,
		effectType = "healTarget",
		description = "A powerful outpouring of divine energy, healing yourself or a targeted party member for 55 Health.",
	},

	-- ── SANCTUARY BRANCH (Area Healing, Escalating Power) ────────────────────
	SacredCircle = {
		id = "SacredCircle",
		displayName = "Sacred Circle",
		branch = "Sanctuary",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/sacred_circle_icon.png",
		cooldown = 8,
		range = 16,
		healAmount = 14,
		effectType = "aoeHeal",
		description = "Summon a circle of restorative light, healing all nearby party members for 14 Health.",
	},

	HealingRain = {
		id = "HealingRain",
		displayName = "Healing Rain",
		branch = "Sanctuary",
		tier = 2,
		prerequisite = "SacredCircle",
		icon = "rbxasset://textures/Soulforge/healing_rain_icon.png",
		cooldown = 14,
		range = 18,
		healAmount = 20,
		effectType = "aoeHeal",
		description = "Call down a gentle rain of restorative energy, healing all nearby party members for 20 Health.",
	},

	Sanctuary = {
		id = "Sanctuary",
		displayName = "Sanctuary",
		branch = "Sanctuary",
		tier = 3,
		prerequisite = "HealingRain",
		icon = "rbxasset://textures/Soulforge/sanctuary_icon.png",
		cooldown = 24,
		range = 20,
		healAmount = 32,
		effectType = "aoeHeal",
		description = "Consecrate the ground beneath you, healing all nearby party members for 32 Health.",
	},
}
```

- [ ] **Step 2: Verify all 7 skills exist with the right shape and cross-reference `Classes.lua`**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local Skills = require(game.ReplicatedStorage.Shared.Data.Skills)
local Classes = require(game.ReplicatedStorage.Shared.Data.Classes)

local expectedIds = {"Mend", "SoothingLight", "RadiantMend", "DivineRestoration", "SacredCircle", "HealingRain", "Sanctuary"}
for _, id in expectedIds do
	local s = Skills[id]
	assert(s, id .. " missing from Skills")
	assert(s.effectType == "healTarget" or s.effectType == "aoeHeal", id .. " has wrong effectType: " .. tostring(s.effectType))
	assert(type(s.healAmount) == "number" and s.healAmount > 0, id .. " missing healAmount")
end

-- Every skill Classes.Healer references must exist in Skills, and vice versa for this class's skills
local allHealerSkillIds = {Classes.Healer.startingSkills[1]}
for _, branch in Classes.Healer.branches do
	for _, id in branch.skills do
		table.insert(allHealerSkillIds, id)
	end
end
assert(#allHealerSkillIds == 7, "expected 7 total Healer skill ids, got " .. #allHealerSkillIds)
for _, id in allHealerSkillIds do
	assert(Skills[id], "Classes.Healer references missing skill " .. id)
end
return "OK"
```

Expected: returns `"OK"` with no error.

- [ ] **Step 3: Commit**

```bash
git add src/ReplicatedStorage/Shared/Data/Skills.lua
git commit -m "feat: add Healer skills (Mend, Mending branch, Sanctuary branch)"
```

---

## Task 3: `Equipment.lua` — add the Sanctum and RockhideHealer gear sets

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Equipment.lua`

- [ ] **Step 1: Add the 5 Sanctum items**

In `src/ReplicatedStorage/Shared/Data/Equipment.lua`, inside the `Items` table, right after the `ApprenticeBoots` entry closes (`},` right before the `-- ── Rockhide (Tier 2 — Boss Fragment Gear, craftable) ──` comment), insert:

```lua

		-- ── Sanctum (Tier 1 — Healer Starter, not craftable) ───────────────
		BlessedScepter = {
			id = "BlessedScepter",
			setId = "Sanctum",
			displayName = "Blessed Scepter",
			slot = "Weapon",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/blessed_scepter_icon.png",
			description = "A simple scepter of pale oak, its crystal head glowing with faint restorative light.",
			stats = {
				magicDamage    = 11,
				attackSpeed    = 1.0,
				criticalChance = 0.05,
				attackRange    = 35,
			},
		},
		SanctumHood = {
			id = "SanctumHood",
			setId = "Sanctum",
			displayName = "Sanctum Hood",
			slot = "Head",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/sanctum_hood_icon.png",
			description = "A pale linen hood worn by acolytes of the Sanctum, warded against harm.",
			stats = { armor = 2, magicResist = 5, maxHPBonus = 8 },
		},
		SanctumRobe = {
			id = "SanctumRobe",
			setId = "Sanctum",
			displayName = "Sanctum Robe",
			slot = "Body",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/sanctum_robe_icon.png",
			description = "Flowing white-and-gold vestments inscribed with softly glowing wards of protection.",
			stats = { armor = 4, magicResist = 8, maxHPBonus = 15 },
		},
		SanctumBracers = {
			id = "SanctumBracers",
			setId = "Sanctum",
			displayName = "Sanctum Bracers",
			slot = "Arms",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/sanctum_bracers_icon.png",
			description = "Soft wool wrist wraps stitched with runes that steady the flow of restorative magic.",
			stats = { armor = 2, magicResist = 4, spellAmp = 0.05 },
		},
		SanctumBoots = {
			id = "SanctumBoots",
			setId = "Sanctum",
			displayName = "Sanctum Boots",
			slot = "Feet",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/sanctum_boots_icon.png",
			description = "Quiet-soled boots favored by healers who must move unseen between the wounded.",
			stats = { armor = 2, magicResist = 3, movementSpeed = 0 },
		},
```

- [ ] **Step 2: Add the 5 RockhideHealer items**

Right after the `RockhideStriders` entry closes (`},` right before the `-- ── STASHED: Sunforged (Tier 3 — Legendary, future content) ────────` comment), insert:

```lua

		-- ── Rockhide Sanctum (Tier 2 Healer — Boss Fragment Gear, craftable) ──
		RockhideStaffOfMercy = {
			id = "RockhideStaffOfMercy",
			setId = "RockhideHealer",
			displayName = "Rockhide Staff of Mercy",
			slot = "Weapon",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_staff_of_mercy_icon.png",
			description = "A petrified sanctum staff bound with warm volcanic basalt, its crystal core pulsing in rhythm with the wounded.",
			stats = {
				magicDamage           = 22,
				attackSpeed           = 0.95,
				criticalChance        = 0.10,
				attackRange           = 35,
				bonusHealingUnder50Pct = 0.20,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 5.0,
				materials     = {
					RockhideFragment = 8,
					OakTimber        = 4,
					LeatherStrap     = 2,
				},
			},
		},
		RockhideSanctumCowl = {
			id = "RockhideSanctumCowl",
			setId = "RockhideHealer",
			displayName = "Rockhide Sanctum Cowl",
			slot = "Head",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_sanctum_cowl_icon.png",
			description = "A heavy hood interwoven with stone-hide mesh, worn by healers who tend the wounded at the front lines.",
			stats = { armor = 5, magicResist = 12, maxHPBonus = 18 },
			crafting = {
				levelRequired = 2,
				craftTime     = 4.0,
				materials     = {
					RockhideFragment = 4,
					LeatherStrap     = 3,
					OakTimber        = 2,
				},
			},
		},
		RockhideSanctumVestments = {
			id = "RockhideSanctumVestments",
			setId = "RockhideHealer",
			displayName = "Rockhide Sanctum Vestments",
			slot = "Body",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_sanctum_vestments_icon.png",
			description = "Heavy volcanic-leather vestments draped with a basalt mantle, blessed for those who heal amid tremors.",
			stats = { armor = 9, magicResist = 18, maxHPBonus = 30 },
			crafting = {
				levelRequired = 2,
				craftTime     = 6.0,
				materials     = {
					RockhideFragment = 10,
					LeatherStrap     = 5,
					IronIngot        = 2,
				},
			},
		},
		RockhideMercyWraps = {
			id = "RockhideMercyWraps",
			setId = "RockhideHealer",
			displayName = "Rockhide Mercy Wraps",
			slot = "Arms",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_mercy_wraps_icon.png",
			description = "Drake-hide wraps embedded with polished rock shards that steady even the most desperate restoration.",
			stats = { armor = 4, magicResist = 8, spellAmp = 0.10 },
			crafting = {
				levelRequired = 2,
				craftTime     = 3.5,
				materials     = {
					RockhideFragment = 3,
					LeatherStrap     = 3,
					IronIngot        = 1,
				},
			},
		},
		RockhideSanctumTreads = {
			id = "RockhideSanctumTreads",
			setId = "RockhideHealer",
			displayName = "Rockhide Sanctum Treads",
			slot = "Feet",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_sanctum_treads_icon.png",
			description = "Sturdy basalt-soled boots lined with insulating dragon-hide, letting a healer move swiftly between allies.",
			stats = { armor = 5, magicResist = 7, movementSpeed = 1 },
			crafting = {
				levelRequired = 2,
				craftTime     = 3.5,
				materials     = {
					RockhideFragment = 3,
					LeatherStrap     = 4,
					OakTimber        = 1,
				},
			},
		},
```

- [ ] **Step 3: Add the `Sanctum` and `RockhideHealer` set entries**

In the `Sets` table, right after `RockhideMage`'s entry closes (`},` right before `-- STASHED: Sunforged kept for future release`), insert:

```lua
		Sanctum = {
			id          = "Sanctum",
			displayName = "Sanctum Acolyte Set",
			classId     = "Healer",
			tier        = 1,
			bossOrigin  = nil,
			stashed     = false,
			pieces      = { "BlessedScepter", "SanctumHood", "SanctumRobe", "SanctumBracers", "SanctumBoots" },
			setBonus    = nil, -- no set bonus for starter gear
		},
		RockhideHealer = {
			id          = "RockhideHealer",
			displayName = "Rockhide Sanctum Set",
			classId     = "Healer",
			tier        = 2,
			rarity      = "Rare",
			bossOrigin  = "Rockhide",
			stashed     = false,
			pieces      = { "RockhideStaffOfMercy", "RockhideSanctumCowl", "RockhideSanctumVestments", "RockhideMercyWraps", "RockhideSanctumTreads" },
			setBonus    = "Earthen Blessing",
			setBonusDesc = "+20% healing output on a target below 50% HP.",
		},
```

- [ ] **Step 4: Verify the new items/sets load and are structurally consistent**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local Equipment = require(game.ReplicatedStorage.Shared.Data.Equipment)

local sanctumItems = {"BlessedScepter", "SanctumHood", "SanctumRobe", "SanctumBracers", "SanctumBoots"}
local rockhideHealerItems = {"RockhideStaffOfMercy", "RockhideSanctumCowl", "RockhideSanctumVestments", "RockhideMercyWraps", "RockhideSanctumTreads"}

for _, id in sanctumItems do
	local item = Equipment.Items[id]
	assert(item, id .. " missing")
	assert(item.setId == "Sanctum", id .. " has wrong setId")
end
for _, id in rockhideHealerItems do
	local item = Equipment.Items[id]
	assert(item, id .. " missing")
	assert(item.setId == "RockhideHealer", id .. " has wrong setId")
	assert(item.crafting, id .. " missing crafting recipe")
end

assert(Equipment.Sets.Sanctum.classId == "Healer", "Sanctum set classId wrong")
assert(Equipment.Sets.RockhideHealer.classId == "Healer", "RockhideHealer set classId wrong")
assert(Equipment.GetItemClass("BlessedScepter") == "Healer", "GetItemClass wrong for BlessedScepter")
assert(Equipment.GetItemClass("RockhideStaffOfMercy") == "Healer", "GetItemClass wrong for RockhideStaffOfMercy")

-- IsSetBonusActive sanity check: full RockhideHealer loadout should activate the bonus
local fullLoadout = { Weapon = "RockhideStaffOfMercy", Head = "RockhideSanctumCowl", Body = "RockhideSanctumVestments", Arms = "RockhideMercyWraps", Feet = "RockhideSanctumTreads" }
assert(Equipment.IsSetBonusActive("RockhideHealer", fullLoadout) == true, "IsSetBonusActive should be true for full loadout")
local partialLoadout = { Weapon = "RockhideStaffOfMercy", Head = "SanctumHood", Body = "RockhideSanctumVestments", Arms = "RockhideMercyWraps", Feet = "RockhideSanctumTreads" }
assert(Equipment.IsSetBonusActive("RockhideHealer", partialLoadout) == false, "IsSetBonusActive should be false for partial loadout")

return "OK"
```

Expected: returns `"OK"` with no error.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Data/Equipment.lua
git commit -m "feat: add Sanctum and RockhideHealer gear sets"
```

---

## Task 4: `CombatService.lua` — `healTarget`/`aoeHeal` dispatch and ally targeting resolution

**Files:**
- Modify: `src/ServerScriptService/Services/CombatService.lua`

- [ ] **Step 1: Require `PartyService`**

At the top of `src/ServerScriptService/Services/CombatService.lua`, the requires currently read:

```lua
local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RespawnService = require(script.Parent.RespawnService)
local EquipmentData = require(ReplicatedStorage.Shared.Data.Equipment)
```

Add `PartyService` to this list:

```lua
local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RespawnService = require(script.Parent.RespawnService)
local EquipmentData = require(ReplicatedStorage.Shared.Data.Equipment)
local PartyService = require(script.Parent.PartyService)
```

- [ ] **Step 2: Add `resolvePlayerTarget` and `getHealMultiplier`/`getPlayerHealAmount` helpers**

Right after the existing `getPlayerSkillDamage` function (which ends just before the `applyDotTicks` comment block), add:

```lua

-- A `targetId` sent by the client is either a bare enemy id (looked up in the `enemies`
-- table above) or "player:<userId>" for an ally/self heal target (see HUDController's
-- click-targeting, which produces this format for a clicked player character). This
-- resolves the latter; returns nil for anything else (including a bare enemy id).
local function resolvePlayerTarget(targetId: string?): Player?
	if not targetId or not targetId:match("^player:") then
		return nil
	end
	local userId = tonumber(targetId:match("^player:(%d+)$"))
	return userId and Players:GetPlayerByUserId(userId) or nil
end

-- Rockhide Sanctum set's "Earthen Blessing" bonus: +20% healing when the TARGET
-- (not the caster) is below 50% HP -- mirrors getDamageMultiplier's shape but keys
-- off the person being healed, since that's who the bonus should matter for.
local function getHealMultiplier(caster: Player, targetHumanoid: Humanoid): number
	local profile = PlayerDataService.GetProfile(caster)
	local charData = profile and profile.Data.Character
	if charData and charData.EquippedEquipment and EquipmentData.IsSetBonusActive("RockhideHealer", charData.EquippedEquipment) then
		if targetHumanoid.Health / math.max(targetHumanoid.MaxHealth, 1) <= 0.5 then
			return 1.20
		end
	end
	return 1.0
end

local function getPlayerHealAmount(caster: Player, targetHumanoid: Humanoid, baseHeal: number): number
	local mult = getHealMultiplier(caster, targetHumanoid)
	return math.floor(baseHeal * mult)
end
```

- [ ] **Step 3: Skip the enemy-based range gate for `healTarget`/`aoeHeal`**

Find this block in `onCastSkill` (it currently reads):

```lua
	local isAoeOrSelf = (skill.effectType == "tauntAoe" or skill.effectType == "aoeDamage" or skill.effectType == "aoeDotDamage"
		or skill.effectType == "selfHeal" or skill.effectType == "buffSelf" or skill.effectType == "buffParty")
	local enemy = targetId and enemies[targetId]
	if skill.range > 0 and not isAoeOrSelf then
```

Replace it with (renamed for accuracy, since `healTarget` isn't AoE or self but still needs to skip this *enemy*-table-based gate — its own range check happens inside its dispatch branch in Step 4, against a `Player`'s position instead):

```lua
	-- Skills that don't need this block's enemy-based range gate: AoE/self skills need no
	-- target at all, and healTarget's target is a Player (range-checked separately, inside
	-- its own dispatch branch below) rather than an entry in the `enemies` table.
	local bypassesEnemyRangeGate = (skill.effectType == "tauntAoe" or skill.effectType == "aoeDamage" or skill.effectType == "aoeDotDamage"
		or skill.effectType == "selfHeal" or skill.effectType == "buffSelf" or skill.effectType == "buffParty"
		or skill.effectType == "healTarget" or skill.effectType == "aoeHeal")
	local enemy = targetId and enemies[targetId]
	if skill.range > 0 and not bypassesEnemyRangeGate then
```

- [ ] **Step 4: Add the `healTarget`/`aoeHeal` dispatch branches**

Find the end of the `elseif skill.effectType == "damage" or skill.effectType == "dotDamage" then` branch, which currently reads:

```lua
	elseif skill.effectType == "damage" or skill.effectType == "dotDamage" then
		if enemy then
			if skill.tauntsOnHit and enemy.onTaunted then
				enemy.onTaunted(player)
			end
			if skill.damage > 0 then
				enemy.onDamaged(getPlayerSkillDamage(player, skill.damage), player)
			end
			if skill.effectType == "dotDamage" and skill.dotTicks then
				applyDotTicks(enemy, player, skill.dotTickDamage, skill.dotTicks, skill.dotInterval)
			end
		end
	end
	-- Any other effectType (buffSelf, buffParty) is intentionally unhandled here --
```

Insert two new `elseif` branches between the `damage`/`dotDamage` branch and the closing `end`:

```lua
	elseif skill.effectType == "damage" or skill.effectType == "dotDamage" then
		if enemy then
			if skill.tauntsOnHit and enemy.onTaunted then
				enemy.onTaunted(player)
			end
			if skill.damage > 0 then
				enemy.onDamaged(getPlayerSkillDamage(player, skill.damage), player)
			end
			if skill.effectType == "dotDamage" and skill.dotTicks then
				applyDotTicks(enemy, player, skill.dotTickDamage, skill.dotTicks, skill.dotInterval)
			end
		end
	elseif skill.effectType == "healTarget" then
		local targetPlayer = resolvePlayerTarget(targetId)
		if targetPlayer then
			local isSelf = (targetPlayer == player)
			local isPartyMember = false
			local party = PartyService.GetParty(player)
			if party then
				for _, memberUserId in party.members do
					if memberUserId == targetPlayer.UserId then
						isPartyMember = true
						break
					end
				end
			end
			if isSelf or isPartyMember then
				local targetCharacter = targetPlayer.Character
				local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
				local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
				if targetHumanoid and targetRoot then
					local distance = (targetRoot.Position - rootPart.Position).Magnitude
					if distance <= skill.range then
						local heal = getPlayerHealAmount(player, targetHumanoid, skill.healAmount or 0)
						targetHumanoid.Health = math.min(targetHumanoid.MaxHealth, targetHumanoid.Health + heal)
						Net.Get("HealthChanged"):FireAllClients(targetPlayer.UserId, targetHumanoid.Health, targetHumanoid.MaxHealth)
					end
				end
			end
		end
	elseif skill.effectType == "aoeHeal" then
		local party = PartyService.GetParty(player)
		local memberUserIds = party and party.members or {player.UserId}
		local aoeRadius = skill.range > 0 and skill.range or 16
		for _, memberUserId in memberUserIds do
			local member = Players:GetPlayerByUserId(memberUserId)
			local memberCharacter = member and member.Character
			local memberHumanoid = memberCharacter and memberCharacter:FindFirstChildOfClass("Humanoid")
			local memberRoot = memberCharacter and memberCharacter:FindFirstChild("HumanoidRootPart")
			if memberHumanoid and memberRoot then
				local dist = (memberRoot.Position - rootPart.Position).Magnitude
				if dist <= aoeRadius then
					local heal = getPlayerHealAmount(player, memberHumanoid, skill.healAmount or 0)
					memberHumanoid.Health = math.min(memberHumanoid.MaxHealth, memberHumanoid.Health + heal)
					Net.Get("HealthChanged"):FireAllClients(member.UserId, memberHumanoid.Health, memberHumanoid.MaxHealth)
				end
			end
		end
	end
	-- Any other effectType (buffSelf, buffParty) is intentionally unhandled here --
```

- [ ] **Step 5: Verify `resolvePlayerTarget` parsing logic in isolation**

This is pure string/lookup logic that doesn't need a live player to validate its parsing half. Run in Studio, `execute_luau`, `datamodel_type: "Server"` (needs `Players` service, available server-side; this only checks the id-parsing shape, not an actual resolved Player, since no player is in this Edit-mode-adjacent check — run this while a Play session is active so `Players:GetPlayerByUserId` has a real player to resolve):

```lua
local Players = game:GetService("Players")
local testPlayer = Players:GetPlayers()[1]
assert(testPlayer, "Run this during an active Play session with at least one player")

-- Simulate resolvePlayerTarget's own logic inline (it's a local function, not exported)
local function resolvePlayerTarget(targetId)
	if not targetId or not targetId:match("^player:") then return nil end
	local userId = tonumber(targetId:match("^player:(%d+)$"))
	return userId and Players:GetPlayerByUserId(userId) or nil
end

assert(resolvePlayerTarget("player:" .. tostring(testPlayer.UserId)) == testPlayer, "valid player: id should resolve")
assert(resolvePlayerTarget("SomeEnemyId123") == nil, "bare enemy id should not resolve")
assert(resolvePlayerTarget("player:999999999") == nil, "nonexistent userId should not resolve")
assert(resolvePlayerTarget(nil) == nil, "nil targetId should not resolve")
return "OK"
```

Expected: returns `"OK"` with no error. (Full `onCastSkill` behavior — the actual heal math, party checks, and range checks — is verified end-to-end in Task 12, since it needs a real cast through the skill-unlock/cooldown gates earlier in that function.)

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Services/CombatService.lua
git commit -m "feat: add healTarget/aoeHeal combat dispatch and player-target resolution"
```

---

## Task 5: `HUDController.lua` — ally targeting (click a party member, or click your own portrait to self-target)

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua`

- [ ] **Step 1: Add `findPlayerCharacterAncestor`**

Right after the existing `findTaggedEnemyAncestor` function (which ends at the `return nil end` closing it, right before `local function getNearestEnemy`), add:

```lua

-- Walks up from a raycast-hit instance to find a Player's character Model, if any.
-- Unlike findTaggedEnemyAncestor's CollectionService tag lookup, any other player's
-- character can be a heal target -- no tagging needed, Players:GetPlayerFromCharacter
-- already tells us definitively. (The LOCAL player's own character is excluded from
-- this raycast already -- see the RaycastParams FilterDescendantsInstances below --
-- so self-targeting goes through a separate path: clicking your own PlayerUnitFrame.)
local function findPlayerCharacterAncestor(instance: Instance): (Model?, Player?)
	local current: Instance? = instance
	while current do
		if current:IsA("Model") then
			local hitPlayer = Players:GetPlayerFromCharacter(current)
			if hitPlayer then
				return current, hitPlayer
			end
		end
		current = current.Parent
	end
	return nil, nil
end
```

- [ ] **Step 2: Recognize a clicked player character in the click handler**

Find this block inside the `UserInputService.InputBegan` handler:

```lua
				local hitEnemy = result and findTaggedEnemyAncestor(result.Instance)
				if hitEnemy and hitEnemy.Name ~= selectedTargetId then
					selectTarget(hitEnemy, hitEnemy.Name)
				end
```

Replace it with:

```lua
				local hitEnemy = result and findTaggedEnemyAncestor(result.Instance)
				if hitEnemy and hitEnemy.Name ~= selectedTargetId then
					selectTarget(hitEnemy, hitEnemy.Name)
				elseif result then
					local hitCharacter, hitPlayer = findPlayerCharacterAncestor(result.Instance)
					if hitCharacter and hitPlayer then
						local targetId = "player:" .. tostring(hitPlayer.UserId)
						if targetId ~= selectedTargetId then
							selectTarget(hitCharacter, targetId)
						end
					end
				end
```

- [ ] **Step 3: Add self-targeting by clicking your own `PlayerUnitFrame`**

Find where `playerFrame` (the `PlayerUnitFrame`) is created and parented — it ends with:

```lua
	local playerFrameGradient = Instance.new("UIGradient")
	playerFrameGradient.Rotation = 45
	playerFrameGradient.Color = ColorSequence.new(Color3.fromRGB(24, 28, 38), Color3.fromRGB(14, 16, 22))
	playerFrameGradient.Parent = playerFrame
```

Right after that block, add:

```lua

	-- Clicking your own unit frame self-targets (heals aimed at yourself). The 3D-world
	-- click-to-target raycast above excludes the local player's own character
	-- (RaycastParams.FilterDescendantsInstances), so this is the only way to target self.
	playerFrame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local localPlayer = Players.LocalPlayer
		local character = localPlayer and localPlayer.Character
		if character then
			local targetId = "player:" .. tostring(localPlayer.UserId)
			if targetId ~= selectedTargetId then
				selectTarget(character, targetId)
			end
		end
	end)
```

- [ ] **Step 4: Live playtest verification**

This needs a running game (client-side UI + a real character). Using the Roblox Studio MCP tools:

1. `start_stop_play` with `is_start: true`.
2. `execute_luau`, `datamodel_type: "Client"`:
   ```lua
   local player = game.Players.LocalPlayer
   if not player.Character then player.CharacterAdded:Wait() end
   return "ready"
   ```
3. Click the player's own `PlayerUnitFrame` (find its exact screen position via `read_page`-equivalent or a screenshot, then `user_mouse_input` with `mouseButtonClick` at that position, or by `instance_path` targeting `LocalPlayer.PlayerGui.HUD.TopLeftContainer.PlayerUnitFrame` if that resolves — the exact PlayerGui path was confirmed working for the Inventory button earlier in this project via `game.Players.<name>.PlayerGui.HUD.TopRightContainer.InventoryMenuButton`, so use the equivalent `game.Players.<name>.PlayerGui.HUD.TopLeftContainer.PlayerUnitFrame`).
4. `execute_luau`, `datamodel_type: "Client"` — HUDController's `selectedTargetId` is a local variable, not exported, so read it indirectly via the `Highlight` instance it creates on click, which *is* inspectable:
   ```lua
   local player = game.Players.LocalPlayer
   local highlight = player.Character:FindFirstChildOfClass("Highlight")
   return highlight ~= nil
   ```
   Expected: `true` (a `Highlight` was added to your own character, confirming `selectTarget` ran).

- [ ] **Step 5: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
git commit -m "feat: add ally/self targeting (click a party member, or your own unit frame)"
```

---

## Task 6: `HUDController.lua` — class-aware badge/title (3-way, not just Mage/Tank)

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua`

- [ ] **Step 1: Replace the `isMage` boolean with a per-class lookup table**

Find:

```lua
local function updateClassVisuals()
	local isMage = (currentClassId == "Mage")
	if attackIconLabel then
		attackIconLabel.Text = isMage and "🔮" or "⚔️"
	end
	if classBadgeIcon then
		classBadgeIcon.Text = isMage and "🔮" or "🛡️"
	end
	if playerNameLabel then
		local classTitle = isMage and "ARCANE MAGE" or "WARRIOR TANK"
		local player = Players.LocalPlayer
		local dName = (player and player.DisplayName) or "Hero"
		playerNameLabel.Text = dName .. "  •  [" .. classTitle .. "]"
	end
end
```

Replace with:

```lua
local HUD_CLASS_VISUALS = {
	Tank = { attackIcon = "⚔️", badgeIcon = "🛡️", title = "WARRIOR TANK" },
	Mage = { attackIcon = "🔮", badgeIcon = "🔮", title = "ARCANE MAGE" },
	Healer = { attackIcon = "✨", badgeIcon = "✨", title = "SANCTUM HEALER" },
}

local function updateClassVisuals()
	local visuals = HUD_CLASS_VISUALS[currentClassId] or HUD_CLASS_VISUALS.Tank
	if attackIconLabel then
		attackIconLabel.Text = visuals.attackIcon
	end
	if classBadgeIcon then
		classBadgeIcon.Text = visuals.badgeIcon
	end
	if playerNameLabel then
		local player = Players.LocalPlayer
		local dName = (player and player.DisplayName) or "Hero"
		playerNameLabel.Text = dName .. "  •  [" .. visuals.title .. "]"
	end
end
```

- [ ] **Step 2: Verify the table covers all 3 classes**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"` (reads the source file's table directly by pattern, since this is a `local` inside a LocalScript module the Edit datamodel can't `require`):

```lua
local source = game.StarterPlayer.StarterPlayerScripts.Controllers.HUDController.Source
assert(source:find("Healer = { attackIcon"), "HUD_CLASS_VISUALS.Healer entry missing")
assert(source:find("HUD_CLASS_VISUALS%[currentClassId%]"), "updateClassVisuals not using the lookup table")
return "OK"
```

Expected: returns `"OK"`. (Full behavioral verification — that a Healer character actually shows the ✨ badge — happens in Task 12's end-to-end playtest.)

- [ ] **Step 3: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
git commit -m "feat: generalize HUD class badge/title to 3-way lookup"
```

---

## Task 7: `CharacterCreationService.lua` — Healer starting equipment

**Files:**
- Modify: `src/ServerScriptService/Services/CharacterCreationService.lua`

- [ ] **Step 1: Add the Healer branch to `setupInitialEquipment`**

Find (this is the function fixed for the forward-reference bug earlier in this project, so it's already positioned before `handlePlayer`):

```lua
local function setupInitialEquipment(profile, classId: string)
	local char = profile.Data.Character
	if classId == "Mage" then
		char.EquippedEquipment = {
			Weapon = "ApprenticeStaff",
			Head = "ApprenticeHood",
			Body = "ApprenticeRobe",
			Arms = "ApprenticeBracers",
			Feet = "ApprenticeBoots",
		}
		char.EquippedWeapon = "ApprenticeStaff"
		char.StoredEquipment = {
			"ApprenticeStaff",
			"ApprenticeHood",
			"ApprenticeRobe",
			"ApprenticeBracers",
			"ApprenticeBoots",
			"RockhideStaff",
			"RockhideCowl",
			"RockhideRobes",
			"RockhideWraps",
			"RockhideStriders",
		}
	else
		char.EquippedEquipment = {
			Weapon = "StandardSword",
			Head = "StandardHelm",
			Body = "StandardChest",
			Arms = "StandardArms",
			Feet = "StandardFeet",
		}
		char.EquippedWeapon = "StandardSword"
		char.StoredEquipment = {
			"StandardSword",
			"StandardHelm",
			"StandardChest",
			"StandardArms",
			"StandardFeet",
			"RockhideFang",
			"RockhideHelm",
			"RockhideChest",
			"RockhideArms",
			"RockhideFeet",
		}
	end
end
```

Replace with (Healer as its own `elseif`, Tank remains the fallback `else` exactly as before — unchanged behavior for Tank):

```lua
local function setupInitialEquipment(profile, classId: string)
	local char = profile.Data.Character
	if classId == "Mage" then
		char.EquippedEquipment = {
			Weapon = "ApprenticeStaff",
			Head = "ApprenticeHood",
			Body = "ApprenticeRobe",
			Arms = "ApprenticeBracers",
			Feet = "ApprenticeBoots",
		}
		char.EquippedWeapon = "ApprenticeStaff"
		char.StoredEquipment = {
			"ApprenticeStaff",
			"ApprenticeHood",
			"ApprenticeRobe",
			"ApprenticeBracers",
			"ApprenticeBoots",
			"RockhideStaff",
			"RockhideCowl",
			"RockhideRobes",
			"RockhideWraps",
			"RockhideStriders",
		}
	elseif classId == "Healer" then
		char.EquippedEquipment = {
			Weapon = "BlessedScepter",
			Head = "SanctumHood",
			Body = "SanctumRobe",
			Arms = "SanctumBracers",
			Feet = "SanctumBoots",
		}
		char.EquippedWeapon = "BlessedScepter"
		char.StoredEquipment = {
			"BlessedScepter",
			"SanctumHood",
			"SanctumRobe",
			"SanctumBracers",
			"SanctumBoots",
			"RockhideStaffOfMercy",
			"RockhideSanctumCowl",
			"RockhideSanctumVestments",
			"RockhideMercyWraps",
			"RockhideSanctumTreads",
		}
	else
		char.EquippedEquipment = {
			Weapon = "StandardSword",
			Head = "StandardHelm",
			Body = "StandardChest",
			Arms = "StandardArms",
			Feet = "StandardFeet",
		}
		char.EquippedWeapon = "StandardSword"
		char.StoredEquipment = {
			"StandardSword",
			"StandardHelm",
			"StandardChest",
			"StandardArms",
			"StandardFeet",
			"RockhideFang",
			"RockhideHelm",
			"RockhideChest",
			"RockhideArms",
			"RockhideFeet",
		}
	end
end
```

Note: `validateClassId` (right above this function) already reads `Classes[classId]` generically — it needs **no change**, `"Healer"` is automatically accepted now that Task 1 added it to `Classes.lua`.

- [ ] **Step 2: Verify via a synthetic profile table (no live player needed)**

`setupInitialEquipment` only touches the `profile` table it's given — no Roblox services involved — so this can be tested with a plain fake profile. Run in Studio, `execute_luau`, `datamodel_type: "Server"` (server-side so `script.Parent` resolves inside `ServerScriptService.Services`):

```lua
local CharacterCreationService = require(game.ServerScriptService.Services.CharacterCreationService)
-- setupInitialEquipment is local (not exported), so this test instead exercises it
-- indirectly via onRequestCreateNewCharacter's observable effect isn't possible without
-- a live profile/player. Verify structurally instead: read the source for the new branch.
local source = game.ServerScriptService.Services.CharacterCreationService.Source
assert(source:find('elseif classId == "Healer" then'), "Healer branch missing from setupInitialEquipment")
assert(source:find('"BlessedScepter"'), "BlessedScepter not referenced")
assert(source:find('"RockhideStaffOfMercy"'), "RockhideStaffOfMercy not referenced")
return "OK"
```

Expected: returns `"OK"`. (Full behavior — that a new Healer character actually spawns with this gear equipped — is verified in Task 12's end-to-end playtest, since `setupInitialEquipment` is only reachable through the full character-creation flow.)

- [ ] **Step 3: Commit**

```bash
git add src/ServerScriptService/Services/CharacterCreationService.lua
git commit -m "feat: grant Healer starting equipment on character creation"
```

---

## Task 8: `WeaponService.lua` — class-aware equipment defaults, sanitization, and staff-style weapon dispatch

**Files:**
- Modify: `src/ServerScriptService/Services/WeaponService.lua`

- [ ] **Step 1: Add `STAFF_STYLE_WEAPONS` and extend `createWeaponModel`/`createShieldModel`**

Find:

```lua
local function createWeaponModel(weaponId: string?): (Model, BasePart, Trail)
	if weaponId == "ApprenticeStaff" then
		return createApprenticeStaffModel()
	elseif weaponId == "RockhideStaff" then
		return createRockhideStaffModel()
	elseif weaponId == "RockhideFang" or weaponId == "Rockhide" then
		return createRockhideSwordModel()
	else
		return createStandardSwordModel()
	end
end

local createSwordModel = createWeaponModel -- compatibility alias

local function createShieldModel(armsId: string?, weaponId: string?): (Model?, BasePart?)
	-- Mages and staff wielders do not carry heavy shields
	if weaponId == "ApprenticeStaff" or weaponId == "RockhideStaff" then
		return nil, nil
	end
```

Replace with:

```lua
-- Weapon ids that render as a staff-style model (caster/support classes) rather than a
-- sword. Phase 1 of the Healer class deliberately reuses the Mage's staff visuals (see
-- docs/superpowers/specs/2026-09-22-healer-class-design.md) -- bespoke Healer weapon
-- geometry is a separate future phase. Also used below to skip staff wielders' shield.
local STAFF_STYLE_WEAPONS = {
	ApprenticeStaff = true,
	RockhideStaff = true,
	BlessedScepter = true,
	RockhideStaffOfMercy = true,
}

local function createWeaponModel(weaponId: string?): (Model, BasePart, Trail)
	if weaponId == "ApprenticeStaff" or weaponId == "BlessedScepter" then
		return createApprenticeStaffModel()
	elseif weaponId == "RockhideStaff" or weaponId == "RockhideStaffOfMercy" then
		return createRockhideStaffModel()
	elseif weaponId == "RockhideFang" or weaponId == "Rockhide" then
		return createRockhideSwordModel()
	else
		return createStandardSwordModel()
	end
end

local createSwordModel = createWeaponModel -- compatibility alias

local function createShieldModel(armsId: string?, weaponId: string?): (Model?, BasePart?)
	-- Mages, Healers, and other staff wielders do not carry heavy shields
	if STAFF_STYLE_WEAPONS[weaponId] then
		return nil, nil
	end
```

- [ ] **Step 2: Add `DEFAULT_EQUIPMENT_BY_CLASS` and use it in `EquipWeapons`'s default resolution**

Find, near the top of `EquipWeapons`:

```lua
	local classId = (charData and charData.ClassId) or "Mage"
	local isMage = (classId == "Mage")

	local equipped = charData and charData.EquippedEquipment or {}
	local targetWeapon = weaponSetId or equipped.Weapon or (charData and charData.EquippedWeapon) or (isMage and "ApprenticeStaff" or "StandardSword")
	local targetArms = shieldSetId or equipped.Arms or (isMage and "ApprenticeBracers" or "StandardArms")
	local targetHead = equipped.Head or (isMage and "ApprenticeHood" or "StandardHelm")
	local targetBody = equipped.Body or (isMage and "ApprenticeRobe" or "StandardChest")
	local targetFeet = equipped.Feet or (isMage and "ApprenticeBoots" or "StandardFeet")
```

Replace with:

```lua
	local classId = (charData and charData.ClassId) or "Mage"
	local defaults = DEFAULT_EQUIPMENT_BY_CLASS[classId] or DEFAULT_EQUIPMENT_BY_CLASS.Mage

	local equipped = charData and charData.EquippedEquipment or {}
	local targetWeapon = weaponSetId or equipped.Weapon or (charData and charData.EquippedWeapon) or defaults.Weapon
	local targetArms = shieldSetId or equipped.Arms or defaults.Arms
	local targetHead = equipped.Head or defaults.Head
	local targetBody = equipped.Body or defaults.Body
	local targetFeet = equipped.Feet or defaults.Feet
```

Add the `DEFAULT_EQUIPMENT_BY_CLASS` table just above `function WeaponService.EquipWeapons`:

```lua
local DEFAULT_EQUIPMENT_BY_CLASS = {
	Tank = { Weapon = "StandardSword", Head = "StandardHelm", Body = "StandardChest", Arms = "StandardArms", Feet = "StandardFeet" },
	Mage = { Weapon = "ApprenticeStaff", Head = "ApprenticeHood", Body = "ApprenticeRobe", Arms = "ApprenticeBracers", Feet = "ApprenticeBoots" },
	Healer = { Weapon = "BlessedScepter", Head = "SanctumHood", Body = "SanctumRobe", Arms = "SanctumBracers", Feet = "SanctumBoots" },
}

function WeaponService.EquipWeapons(character: Model, weaponSetId: string?, shieldSetId: string?)
```

(This replaces the original `function WeaponService.EquipWeapons(character: Model, weaponSetId: string?, shieldSetId: string?)` line — don't duplicate it.)

- [ ] **Step 3: Replace the Mage-only sanitize block with a Mage/Healer pair, and drop the now-unused `isMage`**

Find:

```lua
	-- If character is Mage, sanitize any Tank gear to Mage equivalents
	if isMage then
		if targetWeapon == "StandardSword" or targetWeapon == "Standard" then
			targetWeapon = "ApprenticeStaff"
		elseif targetWeapon == "RockhideFang" or targetWeapon == "Rockhide" then
			targetWeapon = "RockhideStaff"
		end

		if targetHead == "StandardHelm" then
			targetHead = "ApprenticeHood"
		elseif targetHead == "RockhideHelm" then
			targetHead = "RockhideCowl"
		end

		if targetBody == "StandardChest" then
			targetBody = "ApprenticeRobe"
		elseif targetBody == "RockhideChest" then
			targetBody = "RockhideRobes"
		end

		if targetArms == "StandardArms" then
			targetArms = "ApprenticeBracers"
		elseif targetArms == "RockhideArms" then
			targetArms = "RockhideWraps"
		end

		if targetFeet == "StandardFeet" then
			targetFeet = "ApprenticeBoots"
		elseif targetFeet == "RockhideFeet" then
			targetFeet = "RockhideStriders"
		end

		-- Keep profile data in sync
		if charData and charData.EquippedEquipment then
			charData.EquippedEquipment.Weapon = targetWeapon
			charData.EquippedEquipment.Head = targetHead
			charData.EquippedEquipment.Body = targetBody
			charData.EquippedEquipment.Arms = targetArms
			charData.EquippedEquipment.Feet = targetFeet
			charData.EquippedWeapon = targetWeapon
		end
	end
```

Replace with:

```lua
	-- If character is Mage or Healer, sanitize any foreign-class gear to this class's
	-- equivalents (e.g. a stale item from before a reforge). Tank gets no sanitization,
	-- same as before this class existed -- it's always been the unconditional default.
	if classId == "Mage" then
		if targetWeapon == "StandardSword" or targetWeapon == "Standard" then
			targetWeapon = "ApprenticeStaff"
		elseif targetWeapon == "RockhideFang" or targetWeapon == "Rockhide" then
			targetWeapon = "RockhideStaff"
		end

		if targetHead == "StandardHelm" then
			targetHead = "ApprenticeHood"
		elseif targetHead == "RockhideHelm" then
			targetHead = "RockhideCowl"
		end

		if targetBody == "StandardChest" then
			targetBody = "ApprenticeRobe"
		elseif targetBody == "RockhideChest" then
			targetBody = "RockhideRobes"
		end

		if targetArms == "StandardArms" then
			targetArms = "ApprenticeBracers"
		elseif targetArms == "RockhideArms" then
			targetArms = "RockhideWraps"
		end

		if targetFeet == "StandardFeet" then
			targetFeet = "ApprenticeBoots"
		elseif targetFeet == "RockhideFeet" then
			targetFeet = "RockhideStriders"
		end

		-- Keep profile data in sync
		if charData and charData.EquippedEquipment then
			charData.EquippedEquipment.Weapon = targetWeapon
			charData.EquippedEquipment.Head = targetHead
			charData.EquippedEquipment.Body = targetBody
			charData.EquippedEquipment.Arms = targetArms
			charData.EquippedEquipment.Feet = targetFeet
			charData.EquippedWeapon = targetWeapon
		end
	elseif classId == "Healer" then
		if targetWeapon == "StandardSword" or targetWeapon == "Standard" or targetWeapon == "ApprenticeStaff" then
			targetWeapon = "BlessedScepter"
		elseif targetWeapon == "RockhideFang" or targetWeapon == "Rockhide" or targetWeapon == "RockhideStaff" then
			targetWeapon = "RockhideStaffOfMercy"
		end

		if targetHead == "StandardHelm" or targetHead == "ApprenticeHood" then
			targetHead = "SanctumHood"
		elseif targetHead == "RockhideHelm" or targetHead == "RockhideCowl" then
			targetHead = "RockhideSanctumCowl"
		end

		if targetBody == "StandardChest" or targetBody == "ApprenticeRobe" then
			targetBody = "SanctumRobe"
		elseif targetBody == "RockhideChest" or targetBody == "RockhideRobes" then
			targetBody = "RockhideSanctumVestments"
		end

		if targetArms == "StandardArms" or targetArms == "ApprenticeBracers" then
			targetArms = "SanctumBracers"
		elseif targetArms == "RockhideArms" or targetArms == "RockhideWraps" then
			targetArms = "RockhideMercyWraps"
		end

		if targetFeet == "StandardFeet" or targetFeet == "ApprenticeBoots" then
			targetFeet = "SanctumBoots"
		elseif targetFeet == "RockhideFeet" or targetFeet == "RockhideStriders" then
			targetFeet = "RockhideSanctumTreads"
		end

		if charData and charData.EquippedEquipment then
			charData.EquippedEquipment.Weapon = targetWeapon
			charData.EquippedEquipment.Head = targetHead
			charData.EquippedEquipment.Body = targetBody
			charData.EquippedEquipment.Arms = targetArms
			charData.EquippedEquipment.Feet = targetFeet
			charData.EquippedWeapon = targetWeapon
		end
	end
```

- [ ] **Step 4: Replace the remaining `isMage`/staff-id checks (grip angle, shield-equip gate, sync fallback)**

Find:

```lua
	if targetWeapon == "ApprenticeStaff" or targetWeapon == "RockhideStaff" then
		weaponGrip.C0 = CFrame.new(0, -0.35, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)
	else
		weaponGrip.C0 = CFrame.new(0, -0.4, -0.2) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0))
	end
	weaponGrip.Parent = rightHand
	weaponModel.Parent = character

	-- 2. Equip Shield (Tank only; Mages do not carry shields)
	if not isMage and targetWeapon ~= "ApprenticeStaff" and targetWeapon ~= "RockhideStaff" then
```

Replace with:

```lua
	if STAFF_STYLE_WEAPONS[targetWeapon] then
		weaponGrip.C0 = CFrame.new(0, -0.35, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)
	else
		weaponGrip.C0 = CFrame.new(0, -0.4, -0.2) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0))
	end
	weaponGrip.Parent = rightHand
	weaponModel.Parent = character

	-- 2. Equip Shield (Tank only; Mages/Healers/other staff wielders do not carry shields)
	if not STAFF_STYLE_WEAPONS[targetWeapon] then
```

Then find the sync-fallback block:

```lua
	if player and charData then
		Net.Get("EquipmentDataChanged"):FireClient(
			player,
			charData.EquippedEquipment or {
				Weapon = isMage and "ApprenticeStaff" or "StandardSword",
				Head = isMage and "ApprenticeHood" or "StandardHelm",
				Body = isMage and "ApprenticeRobe" or "StandardChest",
				Arms = isMage and "ApprenticeBracers" or "StandardArms",
				Feet = isMage and "ApprenticeBoots" or "StandardFeet",
			},
			charData.StoredEquipment or {},
			charData.CraftingMaterials or {}
		)
	end
```

Replace with:

```lua
	if player and charData then
		Net.Get("EquipmentDataChanged"):FireClient(
			player,
			charData.EquippedEquipment or defaults,
			charData.StoredEquipment or {},
			charData.CraftingMaterials or {}
		)
	end
```

- [ ] **Step 5: Replace the last `isMage` in `WeaponService.Start()`'s equip-request handler**

Find:

```lua
		if hasOwned then
			if not charData.EquippedEquipment then
				local isMage = (playerClass == "Mage")
				charData.EquippedEquipment = {
					Weapon = isMage and "ApprenticeStaff" or "StandardSword",
					Head = isMage and "ApprenticeHood" or "StandardHelm",
					Body = isMage and "ApprenticeRobe" or "StandardChest",
					Arms = isMage and "ApprenticeBracers" or "StandardArms",
					Feet = isMage and "ApprenticeBoots" or "StandardFeet",
				}
			end
```

Replace with:

```lua
		if hasOwned then
			if not charData.EquippedEquipment then
				charData.EquippedEquipment = DEFAULT_EQUIPMENT_BY_CLASS[playerClass] or DEFAULT_EQUIPMENT_BY_CLASS.Mage
			end
```

- [ ] **Step 6: Verify no stray `isMage` references remain and the class-eligibility check already works for Healer**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local source = game.ServerScriptService.Services.WeaponService.Source
assert(not source:find("local isMage"), "a stray 'local isMage' declaration still exists -- Step 3/5 should have removed all of them")
assert(source:find("STAFF_STYLE_WEAPONS"), "STAFF_STYLE_WEAPONS table missing")
assert(source:find("DEFAULT_EQUIPMENT_BY_CLASS"), "DEFAULT_EQUIPMENT_BY_CLASS table missing")
assert(source:find("BlessedScepter"), "BlessedScepter not referenced")

-- WeaponService.Start's class-eligibility check (EquipmentData.GetItemClass vs charData.ClassId)
-- already works for any class generically -- confirm Healer's own set resolves correctly.
local Equipment = require(game.ReplicatedStorage.Shared.Data.Equipment)
assert(Equipment.GetItemClass("SanctumHood") == "Healer", "GetItemClass wrong for SanctumHood")
return "OK"
```

Expected: returns `"OK"`.

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Services/WeaponService.lua
git commit -m "feat: generalize WeaponService equipment defaults/sanitization to 3 classes"
```

---

## Task 9: `ItemIconHelper.lua` — Healer gear renders with the caster-style icon graphics

**Files:**
- Modify: `src/ReplicatedStorage/Shared/UI/ItemIconHelper.lua`

- [ ] **Step 1: Extend the `isRockhide`/`isMage` flags**

Find, inside `ItemIconHelper.CreateItemIcon`:

```lua
	local isRockhide = (item and (item.setId == "Rockhide" or item.setId == "RockhideMage"))
	local isMage = (item and (item.setId == "Apprentice" or item.setId == "RockhideMage"))
```

Replace with:

```lua
	local isRockhide = (item and (item.setId == "Rockhide" or item.setId == "RockhideMage" or item.setId == "RockhideHealer"))
	-- "Caster-style" gear renders with the staff/hood/robe/bracer/boot graphics -- covers
	-- Mage and (Phase 1 of) Healer, which deliberately reuses these same shapes for now.
	local isMage = (item and (item.setId == "Apprentice" or item.setId == "RockhideMage" or item.setId == "Sanctum" or item.setId == "RockhideHealer"))
```

(Kept the variable name `isMage` rather than renaming it — it's used 5 more times immediately below this in the same function, and this change is intentionally minimal/low-risk per the design spec's "reuse existing visuals" scope; a rename would touch those 5 sites for no behavioral benefit.)

- [ ] **Step 2: Verify via the exported function's actual output shape**

`ItemIconHelper.CreateItemIcon` builds real `Instance`s, so this can run for real (no live player needed — it just needs a throwaway parent to build into). Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local ItemIconHelper = require(game.ReplicatedStorage.Shared.UI.ItemIconHelper)
local scratchParent = Instance.new("Folder")

local tile1 = ItemIconHelper.CreateItemIcon(scratchParent, "BlessedScepter", UDim2.new(0, 42, 0, 42), false)
assert(tile1, "CreateItemIcon returned nil for BlessedScepter")
assert(tile1:FindFirstChild("StaffGraphic") or #tile1:GetChildren() > 0, "BlessedScepter icon has no graphic children")

local tile2 = ItemIconHelper.CreateItemIcon(scratchParent, "RockhideStaffOfMercy", UDim2.new(0, 42, 0, 42), false)
assert(tile2, "CreateItemIcon returned nil for RockhideStaffOfMercy")

scratchParent:Destroy()
return "OK"
```

Expected: returns `"OK"` with no error. (This doesn't assert the exact visual — `buildStaffGraphic`'s internal child naming isn't part of this task's contract — just that the call succeeds and produces *some* content, which confirms the `isMage`/`isRockhide` flags resolved to a real branch instead of silently falling through to nothing.)

- [ ] **Step 3: Commit**

```bash
git add src/ReplicatedStorage/Shared/UI/ItemIconHelper.lua
git commit -m "feat: render Healer gear with the existing caster-style icon graphics"
```

---

## Task 10: `CharacterCreationController.lua` — third class-picker card and 3-way hero-choice display

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua`

- [ ] **Step 1: Add `Healer` to `CLASS_CARD_INFO`**

Find:

```lua
local CLASS_CARD_INFO = {
	Tank = {
		icon = "🛡️",
		title = "TANK ARCHETYPE",
		description = "Steadfast frontline juggernaut armed with sword and heavy shield. Masters crowd control and holds boss aggro with Taunt.",
		traits = {
			{ "⚔️", "Attack: Heavy Sword Cleave" },
			{ "🛡️", "Starter Skill: Taunt" },
			{ "🌳", "Trees: Juggernaut & Bulwark" },
		},
	},
	Mage = {
		icon = "🔮",
		title = "MAGE ARCHETYPE",
		description = "Fragile spellcaster who strikes from range with arcane bolts, then specializes into explosive fire or lingering frost damage.",
		traits = {
			{ "🔥", "Attack: Arcane Bolt (Ranged)" },
			{ "❤️", "Base Health: 80 (Fragile)" },
			{ "🌳", "Trees: Pyromancy & Frostweave" },
		},
	},
}
```

Replace with:

```lua
local CLASS_CARD_INFO = {
	Tank = {
		icon = "🛡️",
		title = "TANK ARCHETYPE",
		description = "Steadfast frontline juggernaut armed with sword and heavy shield. Masters crowd control and holds boss aggro with Taunt.",
		traits = {
			{ "⚔️", "Attack: Heavy Sword Cleave" },
			{ "🛡️", "Starter Skill: Taunt" },
			{ "🌳", "Trees: Juggernaut & Bulwark" },
		},
	},
	Mage = {
		icon = "🔮",
		title = "MAGE ARCHETYPE",
		description = "Fragile spellcaster who strikes from range with arcane bolts, then specializes into explosive fire or lingering frost damage.",
		traits = {
			{ "🔥", "Attack: Arcane Bolt (Ranged)" },
			{ "❤️", "Base Health: 80 (Fragile)" },
			{ "🌳", "Trees: Pyromancy & Frostweave" },
		},
	},
	Healer = {
		icon = "✨",
		title = "HEALER ARCHETYPE",
		description = "Pure support caster who mends allies from a distance -- no damage skills, just keeping the party alive.",
		traits = {
			{ "✨", "Starter Skill: Mend" },
			{ "❤️", "Base Health: 90" },
			{ "🌳", "Trees: Mending & Sanctuary" },
		},
	},
}
```

- [ ] **Step 2: Add the third card and 3-way selection wiring**

Find:

```lua
	local tankCard, tankCardStroke, tankCardHitbox = createClassCard(classCardsRow, "Tank", 0, 0.485)
	local mageCard, mageCardStroke, mageCardHitbox = createClassCard(classCardsRow, "Mage", 0.515, 0.485)

	local selectedClassId = "Mage"

	local function refreshClassCardSelection()
		tankCardStroke.Color = (selectedClassId == "Tank") and COLORS.goldPrimary or COLORS.slateBorder
		tankCardStroke.Thickness = (selectedClassId == "Tank") and 2.4 or 1.6
		mageCardStroke.Color = (selectedClassId == "Mage") and COLORS.goldPrimary or COLORS.slateBorder
		mageCardStroke.Thickness = (selectedClassId == "Mage") and 2.4 or 1.6
	end
	refreshClassCardSelection()

	tankCardHitbox.Activated:Connect(function()
		selectedClassId = "Tank"
		refreshClassCardSelection()
	end)
	mageCardHitbox.Activated:Connect(function()
		selectedClassId = "Mage"
		refreshClassCardSelection()
	end)
```

Replace with (three cards at ~31% width each with small gaps, instead of two at ~48.5%):

```lua
	local tankCard, tankCardStroke, tankCardHitbox = createClassCard(classCardsRow, "Tank", 0, 0.315)
	local mageCard, mageCardStroke, mageCardHitbox = createClassCard(classCardsRow, "Mage", 0.3425, 0.315)
	local healerCard, healerCardStroke, healerCardHitbox = createClassCard(classCardsRow, "Healer", 0.685, 0.315)

	local selectedClassId = "Mage"

	local function refreshClassCardSelection()
		tankCardStroke.Color = (selectedClassId == "Tank") and COLORS.goldPrimary or COLORS.slateBorder
		tankCardStroke.Thickness = (selectedClassId == "Tank") and 2.4 or 1.6
		mageCardStroke.Color = (selectedClassId == "Mage") and COLORS.goldPrimary or COLORS.slateBorder
		mageCardStroke.Thickness = (selectedClassId == "Mage") and 2.4 or 1.6
		healerCardStroke.Color = (selectedClassId == "Healer") and COLORS.goldPrimary or COLORS.slateBorder
		healerCardStroke.Thickness = (selectedClassId == "Healer") and 2.4 or 1.6
	end
	refreshClassCardSelection()

	tankCardHitbox.Activated:Connect(function()
		selectedClassId = "Tank"
		refreshClassCardSelection()
	end)
	mageCardHitbox.Activated:Connect(function()
		selectedClassId = "Mage"
		refreshClassCardSelection()
	end)
	healerCardHitbox.Activated:Connect(function()
		selectedClassId = "Healer"
		refreshClassCardSelection()
	end)
```

- [ ] **Step 3: Generalize `updateHeroChoiceCard`'s `isMage` binary to a 3-way lookup**

Find:

```lua
	local function updateHeroChoiceCard(classId: string, level: number)
		local levelText = ("⭐ LEVEL %d"):format(level)
		local lvlChild = levelBadge:FindFirstChildOfClass("TextLabel")
		if lvlChild then
			lvlChild.Text = levelText
		end

		local isMage = (classId == "Mage")
		local badgeLabel = classBadge:FindFirstChildOfClass("TextLabel")
		local badgeStroke = classBadge:FindFirstChildOfClass("UIStroke")
		if badgeLabel then
			badgeLabel.Text = isMage and "🔮 MAGE" or "🛡️ TANK"
			badgeLabel.TextColor3 = isMage and Color3.fromRGB(240, 210, 255) or Color3.fromRGB(150, 210, 255)
		end
		if badgeStroke then
			badgeStroke.Color = isMage and Color3.fromRGB(190, 120, 255) or Color3.fromRGB(75, 150, 255)
		end
		classBadge.BackgroundColor3 = isMage and Color3.fromRGB(60, 30, 90) or Color3.fromRGB(24, 45, 80)

		if isMage then
			chip1Title.Text = "❤️ 80 HP"
			chip1Sub.Text = "Base Health"
			chip2Title.Text = "🔮 Arcane Bolt"
			chip2Sub.Text = "Ranged Focus"
			chip3Title.Text = "🔥 Spellweaver"
			chip3Sub.Text = "Fire & Frost"
		else
			chip1Title.Text = "❤️ 150 HP"
			chip1Sub.Text = "Base Health"
			chip2Title.Text = "🛡️ Taunt"
			chip2Sub.Text = "Threat Lock"
			chip3Title.Text = "⚔️ Blade & Shield"
			chip3Sub.Text = "Melee Defender"
		end

		if warnDesc then
			warnDesc.Text = ("This will permanently delete your Level %d %s and reset all skill points, unlocked abilities, and level progression."):format(level, isMage and "Mage" or "Tank")
		end
	end
```

Replace with:

```lua
	local HERO_CHOICE_INFO = {
		Tank = {
			className = "Tank",
			badgeText = "🛡️ TANK",
			badgeTextColor = Color3.fromRGB(150, 210, 255),
			badgeStrokeColor = Color3.fromRGB(75, 150, 255),
			badgeBgColor = Color3.fromRGB(24, 45, 80),
			hpChip = { "❤️ 150 HP", "Base Health" },
			skillChip = { "🛡️ Taunt", "Threat Lock" },
			flavorChip = { "⚔️ Blade & Shield", "Melee Defender" },
		},
		Mage = {
			className = "Mage",
			badgeText = "🔮 MAGE",
			badgeTextColor = Color3.fromRGB(240, 210, 255),
			badgeStrokeColor = Color3.fromRGB(190, 120, 255),
			badgeBgColor = Color3.fromRGB(60, 30, 90),
			hpChip = { "❤️ 80 HP", "Base Health" },
			skillChip = { "🔮 Arcane Bolt", "Ranged Focus" },
			flavorChip = { "🔥 Spellweaver", "Fire & Frost" },
		},
		Healer = {
			className = "Healer",
			badgeText = "✨ HEALER",
			badgeTextColor = Color3.fromRGB(255, 240, 200),
			badgeStrokeColor = Color3.fromRGB(255, 215, 130),
			badgeBgColor = Color3.fromRGB(70, 55, 20),
			hpChip = { "❤️ 90 HP", "Base Health" },
			skillChip = { "✨ Mend", "Ally Restore" },
			flavorChip = { "🌿 Sanctuary", "Mending & Support" },
		},
	}

	local function updateHeroChoiceCard(classId: string, level: number)
		local levelText = ("⭐ LEVEL %d"):format(level)
		local lvlChild = levelBadge:FindFirstChildOfClass("TextLabel")
		if lvlChild then
			lvlChild.Text = levelText
		end

		local info = HERO_CHOICE_INFO[classId] or HERO_CHOICE_INFO.Mage
		local badgeLabel = classBadge:FindFirstChildOfClass("TextLabel")
		local badgeStroke = classBadge:FindFirstChildOfClass("UIStroke")
		if badgeLabel then
			badgeLabel.Text = info.badgeText
			badgeLabel.TextColor3 = info.badgeTextColor
		end
		if badgeStroke then
			badgeStroke.Color = info.badgeStrokeColor
		end
		classBadge.BackgroundColor3 = info.badgeBgColor

		chip1Title.Text = info.hpChip[1]
		chip1Sub.Text = info.hpChip[2]
		chip2Title.Text = info.skillChip[1]
		chip2Sub.Text = info.skillChip[2]
		chip3Title.Text = info.flavorChip[1]
		chip3Sub.Text = info.flavorChip[2]

		if warnDesc then
			warnDesc.Text = ("This will permanently delete your Level %d %s and reset all skill points, unlocked abilities, and level progression."):format(level, info.className)
		end
	end
```

- [ ] **Step 4: Verify structurally**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local source = game.StarterPlayer.StarterPlayerScripts.Controllers.CharacterCreationController.Source
assert(source:find('Healer = {%s*\n%s*icon = "✨"'), "CLASS_CARD_INFO.Healer missing")
assert(source:find('createClassCard%(classCardsRow, "Healer"'), "third createClassCard call missing")
assert(source:find("healerCardHitbox%.Activated:Connect"), "Healer card click handler missing")
assert(source:find("HERO_CHOICE_INFO"), "HERO_CHOICE_INFO table missing")
return "OK"
```

Expected: returns `"OK"`. (Full visual/interactive verification happens in Task 12.)

- [ ] **Step 5: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
git commit -m "feat: add Healer to the character-creation class picker"
```

---

## Task 11: `SkillTreeUIController.lua` — Healer branch order, class title, and branch colors

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua`

- [ ] **Step 1: Add `Healer` to `BRANCH_ORDER_BY_CLASS` and `CLASS_TITLE_INFO`**

Find:

```lua
local BRANCH_ORDER_BY_CLASS = {
	Tank = {"Bulwark", "Juggernaut"},
	Mage = {"Pyromancy", "Frostweave"},
}

local activeMobileBranch: string = BRANCH_ORDER_BY_CLASS.Tank[1]

-- Icon + display name shown in the modal's title bar, keyed by ReplicatedStorage.Shared.Data.Classes's own keys.
local CLASS_TITLE_INFO = {
	Tank = { icon = "🛡️", name = "TANK" },
	Mage = { icon = "🔮", name = "MAGE" },
}
```

Replace with:

```lua
local BRANCH_ORDER_BY_CLASS = {
	Tank = {"Bulwark", "Juggernaut"},
	Mage = {"Pyromancy", "Frostweave"},
	Healer = {"Mending", "Sanctuary"},
}

local activeMobileBranch: string = BRANCH_ORDER_BY_CLASS.Tank[1]

-- Icon + display name shown in the modal's title bar, keyed by ReplicatedStorage.Shared.Data.Classes's own keys.
local CLASS_TITLE_INFO = {
	Tank = { icon = "🛡️", name = "TANK" },
	Mage = { icon = "🔮", name = "MAGE" },
	Healer = { icon = "✨", name = "HEALER" },
}
```

- [ ] **Step 2: Add `Mending` and `Sanctuary` to `BRANCH_COLORS`**

Find the end of `BRANCH_COLORS` (the `Frostweave` entry's closing, right before `}`):

```lua
	Frostweave = {
		primary = Color3.fromRGB(60, 170, 230),
		secondary = Color3.fromRGB(25, 90, 130),
		bg = Color3.fromRGB(16, 26, 34),
		cardBg = Color3.fromRGB(22, 36, 46),
		border = Color3.fromRGB(50, 150, 200),
		accent = Color3.fromRGB(140, 220, 255),
		icon = "❄️",
		name = "FROSTWEAVE",
		displayName = "FROSTWEAVE SPECIALIZATION",
		tagline = "Sustained frost damage that lingers on enemies",
	},
}
```

Replace with:

```lua
	Frostweave = {
		primary = Color3.fromRGB(60, 170, 230),
		secondary = Color3.fromRGB(25, 90, 130),
		bg = Color3.fromRGB(16, 26, 34),
		cardBg = Color3.fromRGB(22, 36, 46),
		border = Color3.fromRGB(50, 150, 200),
		accent = Color3.fromRGB(140, 220, 255),
		icon = "❄️",
		name = "FROSTWEAVE",
		displayName = "FROSTWEAVE SPECIALIZATION",
		tagline = "Sustained frost damage that lingers on enemies",
	},
	Mending = {
		primary = Color3.fromRGB(255, 210, 110),
		secondary = Color3.fromRGB(160, 130, 50),
		bg = Color3.fromRGB(34, 30, 18),
		cardBg = Color3.fromRGB(46, 40, 24),
		border = Color3.fromRGB(215, 175, 80),
		accent = Color3.fromRGB(255, 235, 180),
		icon = "✨",
		name = "MENDING",
		displayName = "MENDING SPECIALIZATION",
		tagline = "Focused single-target healing that scales into a powerful restoration",
	},
	Sanctuary = {
		primary = Color3.fromRGB(110, 220, 140),
		secondary = Color3.fromRGB(45, 130, 75),
		bg = Color3.fromRGB(16, 30, 20),
		cardBg = Color3.fromRGB(22, 40, 28),
		border = Color3.fromRGB(80, 180, 110),
		accent = Color3.fromRGB(180, 255, 200),
		icon = "🌿",
		name = "SANCTUARY",
		displayName = "SANCTUARY SPECIALIZATION",
		tagline = "Area healing that keeps the whole party topped up",
	},
}
```

- [ ] **Step 3: Verify structurally**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local source = game.StarterPlayer.StarterPlayerScripts.Controllers.SkillTreeUIController.Source
assert(source:find('Healer = {"Mending", "Sanctuary"}'), "BRANCH_ORDER_BY_CLASS.Healer missing")
assert(source:find('Healer = { icon = "✨", name = "HEALER" }'), "CLASS_TITLE_INFO.Healer missing")
assert(source:find("Mending = {"), "BRANCH_COLORS.Mending missing")
assert(source:find("Sanctuary = {"), "BRANCH_COLORS.Sanctuary missing")
return "OK"
```

Expected: returns `"OK"`. (`BRANCH_COLORS[branchName] or BRANCH_COLORS.Juggernaut` fallbacks elsewhere in this file already make a missing entry merely look wrong, not error — this step confirms the entries exist so Healer's tree renders with its own colors rather than falling back to Juggernaut's red.)

- [ ] **Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua
git commit -m "feat: add Healer branch colors and class title to the skill tree UI"
```

---

## Task 12: End-to-end verification in Roblox Studio

**Files:** none (verification only)

This exercises the full Phase 1 slice together: creating a Healer, seeing the right UI everywhere, and both new heal effect types actually healing.

- [ ] **Step 1: Route through the real character-creation flow instead of the Studio auto-load shortcut**

`CharacterCreationService.handlePlayer`'s Studio auto-load path (`RunService:IsStudio() and not ReplicatedStorage:GetAttribute("TestCharacterCreation")`) always creates a Mage, bypassing the picker entirely. Set the escape hatch it already checks for, *before* starting Play:

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
game.ReplicatedStorage:SetAttribute("TestCharacterCreation", true)
return "set"
```

- [ ] **Step 2: Start Play and pick Healer**

1. `start_stop_play` with `is_start: true`.
2. `get_console_output` — confirm no errors (matches the pattern used throughout this project's earlier bug-hunting: a clean startup log with no `warn`/error lines related to `CharacterCreationController`, `HUDController`, `CombatService`, `WeaponService`, `ItemIconHelper`, or `SkillTreeUIController`).
3. Take a `screen_capture` of the character-creation screen — confirm **three** cards are visible (Tank / Mage / Healer), not two.
4. Click the Healer card's hitbox, then the EMBARK button (same interaction flow already established for Mage earlier in this project — locate the hitbox by its known name, `game.Players.<name>.PlayerGui.CharacterCreation...ClassCard_Healer.SelectHitbox`, adjust the container path via `read_page` if it differs from that guess).
5. `screen_capture` again — confirm the HUD shows `✨` icons and `SANCTUM HEALER` in the player name label (from Task 6), and `95` is *not* shown as max HP (Tank's number) — expect `90` (Healer's `baseHealth`, possibly +`maxHPBonus` from starting gear).

- [ ] **Step 3: Confirm starting equipment and skill**

`execute_luau`, `datamodel_type: "Server"`:

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local PlayerDataService = require(game.ServerScriptService.Services.PlayerDataService)
local profile = PlayerDataService.GetProfile(player)
local char = profile.Data.Character

assert(char.ClassId == "Healer", "ClassId should be Healer, got " .. tostring(char.ClassId))
assert(char.EquippedEquipment.Weapon == "BlessedScepter", "wrong starting weapon: " .. tostring(char.EquippedEquipment.Weapon))
assert(char.UnlockedSkills[1] == "Mend", "starting skill should be Mend")

local hasRockhideHealerPiece = false
for _, id in char.StoredEquipment do
	if id == "RockhideStaffOfMercy" then hasRockhideHealerPiece = true end
end
assert(hasRockhideHealerPiece, "RockhideHealer tier-2 gear should already be in StoredEquipment")

return "OK"
```

Expected: returns `"OK"`.

- [ ] **Step 4: Verify `healTarget` (self-heal via `Mend`)**

First lower the player's health so healing is observable, then cast `Mend` on self by clicking the `PlayerUnitFrame` (Task 5) and pressing the skill's hotkey (`1`, since `Mend` is the only starting skill and occupies slot 1 per `equippedSkills`).

`execute_luau`, `datamodel_type: "Server"` (lower health):

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = humanoid.MaxHealth - 30
return humanoid.Health
```

Then, via `user_mouse_input` (click own `PlayerUnitFrame`) and `user_keyboard_input` (`keyPress` `One`), cast `Mend` on self.

`execute_luau`, `datamodel_type: "Server"` (verify the heal landed):

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
return humanoid.Health -- expect MaxHealth - 30 + 18 (Mend's healAmount), clamped to MaxHealth
```

Expected: `Health` increased by `Mend`'s `healAmount` (18), clamped to `MaxHealth` if that would exceed it.

- [ ] **Step 5: Verify `aoeHeal` (solo `SacredCircle` — degrades to self-heal per the design's stated solo behavior)**

`SacredCircle` isn't unlocked yet (only `Mend` is, at character creation) — unlock and equip it first:

`execute_luau`, `datamodel_type: "Server"`:

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local PlayerDataService = require(game.ServerScriptService.Services.PlayerDataService)
local profile = PlayerDataService.GetProfile(player)
profile.Data.Character.UnlockedSkills = {"Mend", "SacredCircle"}
profile.Data.Character.EquippedSkills = {"Mend", "SacredCircle"}

local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = humanoid.MaxHealth - 30
return humanoid.Health
```

Reload the HUD's equipped-skill slots (re-fire `CharacterDataChanged`/`SkillDataChanged`, or simply cast directly via the remote as the client instead of the hotkey, to avoid needing the client HUD to re-sync mid-test):

`execute_luau`, `datamodel_type: "Client"`:

```lua
local Net = require(game.ReplicatedStorage.Shared.Net)
Net.Get("CastSkill"):FireServer("SacredCircle", nil) -- no target needed, it's AoE
return "fired"
```

`execute_luau`, `datamodel_type: "Server"` (verify):

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
return humanoid.Health -- expect MaxHealth - 30 + 14 (SacredCircle's healAmount), clamped to MaxHealth
```

Expected: `Health` increased by `SacredCircle`'s `healAmount` (14), clamped to `MaxHealth`.

- [ ] **Step 6: Note the untestable-with-current-tooling case**

Healing an *other* party member (rather than self) needs a second real client in the same server, which the available Roblox Studio MCP tooling doesn't drive (`execute_luau`'s `datamodel_type` enum is `Edit`/`Client`/`Server` — one client only, no multi-client Team Test control observed in this project's tooling so far). Steps 3-5 above exercise every server-side code path `healTarget`/`aoeHeal` have (the party-membership check, the range check, the heal math, the `HealthChanged` fire) via the "self" branch of each — the only thing not exercised end-to-end here is literally which `Player` object gets resolved when `targetPlayer ~= player`, and that resolution is already covered structurally by Task 4 Step 5's `resolvePlayerTarget` test. Record this limitation rather than claiming full multi-player verification.

- [ ] **Step 7: Verify the skill tree UI**

Press `K` (or `T`) to open the skill tree. `screen_capture` — confirm it shows **Mending** and **Sanctuary** as the two branch tabs (not Bulwark/Juggernaut or Pyromancy/Frostweave), with `Mend`, `SoothingLight`/`RadiantMend`/`DivineRestoration`, and `SacredCircle`/`HealingRain`/`Sanctuary` laid out per their `tier`.

- [ ] **Step 8: Stop Play and unset the test attribute**

`start_stop_play` with `is_start: false`.

`execute_luau`, `datamodel_type: "Edit"`:

```lua
game.ReplicatedStorage:SetAttribute("TestCharacterCreation", nil)
return "cleared"
```

(Leaving this attribute set would make every future Studio playtest in this project show the character-creation picker instead of the auto-load shortcut other work in this project relies on — clear it so Task 12 doesn't leave a footgun for unrelated future work.)

- [ ] **Step 9: Final commit**

If Steps 2-7 required any fixes to earlier tasks' code, those fixes should already be committed as part of returning to each task's own commit. This step is only needed if any stray uncommitted changes remain:

```bash
git status
```

If clean, no commit needed — Task 12 is verification-only.

---

## Self-Review Notes

**Spec coverage:** §1 (Classes.Healer) → Task 1. §2 (`healTarget`/`aoeHeal` dispatch) → Task 4. §3 (ally targeting) → Tasks 4 (server) + 5 (client). §4 (7 skills) → Task 2. §5 (Sanctum + RockhideHealer gear, set bonus) → Tasks 3 (data) + 4 (`getHealMultiplier`, the set-bonus math). §6 (`isMage`-style generalization across `WeaponService`, `CharacterCreationService`, `HUDController`, `ItemIconHelper`, `CharacterCreationController`) → Tasks 6, 7, 8, 9, 10, plus `SkillTreeUIController` (Task 11, called out in the spec's own §6 bullet list). All spec sections have a task.

**Placeholder scan:** no "TBD"/"add error handling"/"similar to Task N" in any step above — every step shows the literal code or the literal command to run.

**Type/name consistency check:** `healTarget`/`aoeHeal` (Skills.lua's `effectType`, CombatService's dispatch) match across Tasks 2 and 4. `"player:" .. tostring(...)` id format matches between Task 4's `resolvePlayerTarget` and Task 5's `selectTarget` call sites. `RockhideHealer` (setId) matches across Tasks 3, 4 (`getHealMultiplier`'s `IsSetBonusActive` call), and 9. `STAFF_STYLE_WEAPONS`/`DEFAULT_EQUIPMENT_BY_CLASS` names match between their Task 8 declaration and every later Task 8 step that reads them. Item ids (`BlessedScepter`, `SanctumHood`/`SanctumRobe`/`SanctumBracers`/`SanctumBoots`, `RockhideStaffOfMercy`/`RockhideSanctumCowl`/`RockhideSanctumVestments`/`RockhideMercyWraps`/`RockhideSanctumTreads`) are spelled identically across Tasks 3, 7, 8, and 12.
