# Warrior Class & Tank Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split Tank's offense-flavored `Juggernaut` branch out into a new Warrior class (pure melee DPS), give Tank a new pure-defense `Sentinel` branch in its place, and generalize every remaining Tank/Mage-only UI/gear check to be 3-way aware.

**Architecture:** Warrior reuses every existing combat `effectType` (`damage`, `aoeDamage`, `aoeDotDamage`, `tauntAoe`) and Tank's exact existing gear (`Standard`/`Rockhide` item ids) — no new combat mechanics, no new items. The only structural change to `Equipment.lua` is widening two `Sets` entries' `classId` from a single string to a list of allowed classes, which ripples into exactly one equip-eligibility check in `WeaponService.lua`. Everywhere else (`CharacterCreationService.lua`'s gear defaults, `CombatService.lua`'s normal-attack animation dispatch), the existing "if not Mage" fallback is *already* correct for Warrior, since Warrior is non-caster and melee like Tank.

**Tech Stack:** Roblox Luau, Rojo-synced project, no automated test framework — verification is via Roblox Studio (`execute_luau` for data/logic, live playtests for anything requiring a running game), same as every other plan in this project.

**Testing note:** As with every prior plan in this project, there is no TestEZ or any other test framework. Each "test" step below is either an exact `execute_luau` snippet run against Studio's `Edit`/`Server`/`Client` datamodel, or an exact live-playtest procedure with a concrete expected result.

**Design reference:** [docs/superpowers/specs/2026-09-24-warrior-class-design.md](../specs/2026-09-24-warrior-class-design.md)

---

## Task 1: `Classes.lua` — add Warrior, replace Tank's Juggernaut with Sentinel

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Classes.lua`

- [ ] **Step 1: Replace Tank's `Juggernaut` branch with `Sentinel`, and add the `Warrior` class**

The file currently reads:

```lua
-- src/ReplicatedStorage/Shared/Data/Classes.lua
return {
	Tank = {
		name = "Tank",
		baseHealth = 150,
		startingSkills = {"Taunt"},
		branches = {
			Juggernaut = {
				name = "Juggernaut",
				description = "Offensive powerhouse focusing on high-threat strikes, shield impacts, and earthshaking AoE crowd control.",
				skills = {"ProvokingStrike", "ShieldBash", "Earthshaker"},
			},
			Bulwark = {
				name = "Bulwark",
				description = "Stalwart guardian specializing in damage mitigation, instant self-recovery, and defensive party auras.",
				skills = {"GuardStance", "IronWill", "FortressAura"},
			},
		},
	},

	Mage = {
		name = "Mage",
		baseHealth = 90,
		startingSkills = {"ArcaneBolt"},
		branches = {
			Pyromancy = {
				name = "Pyromancy",
				description = "Explosive single-target and area fire damage with burning DoTs — high risk, devastating reward.",
				skills = {"Firebolt", "Fireball", "Meteor"},
			},
			Frostweave = {
				name = "Frostweave",
				description = "Sustained frost damage that slows and shreds enemy armour, lingering long after the initial strike.",
				skills = {"Frostbolt", "IceLance", "Blizzard"},
			},
			ArcaneMastery = {
				name = "Arcane Mastery",
				description = "Defensive barriers, arcane burst damage, and reality-warping AoE control — the scholar's ultimate toolkit.",
				skills = {"ArcaneBarrier", "ArcaneSurge", "ArcaneNova"},
			},
		},
	},
}
```

Replace the whole file with:

```lua
-- src/ReplicatedStorage/Shared/Data/Classes.lua
return {
	Tank = {
		name = "Tank",
		baseHealth = 150,
		startingSkills = {"Taunt"},
		branches = {
			Bulwark = {
				name = "Bulwark",
				description = "Stalwart guardian specializing in damage mitigation, instant self-recovery, and defensive party auras.",
				skills = {"GuardStance", "IronWill", "FortressAura"},
			},
			Sentinel = {
				name = "Sentinel",
				description = "Pure threat and mitigation -- single-target and AoE taunts backed by a defender's strike, not a damage dealer's.",
				skills = {"ShieldSlam", "AegisSlam", "GuardiansWrath"},
			},
		},
	},

	Mage = {
		name = "Mage",
		baseHealth = 90,
		startingSkills = {"ArcaneBolt"},
		branches = {
			Pyromancy = {
				name = "Pyromancy",
				description = "Explosive single-target and area fire damage with burning DoTs — high risk, devastating reward.",
				skills = {"Firebolt", "Fireball", "Meteor"},
			},
			Frostweave = {
				name = "Frostweave",
				description = "Sustained frost damage that slows and shreds enemy armour, lingering long after the initial strike.",
				skills = {"Frostbolt", "IceLance", "Blizzard"},
			},
			ArcaneMastery = {
				name = "Arcane Mastery",
				description = "Defensive barriers, arcane burst damage, and reality-warping AoE control — the scholar's ultimate toolkit.",
				skills = {"ArcaneBarrier", "ArcaneSurge", "ArcaneNova"},
			},
		},
	},

	Warrior = {
		name = "Warrior",
		baseHealth = 120,
		startingSkills = {"Cleave"},
		branches = {
			Juggernaut = {
				name = "Juggernaut",
				description = "Offensive powerhouse focusing on heavy strikes, shield impacts, and earthshaking AoE crowd control.",
				skills = {"ProvokingStrike", "ShieldBash", "Earthshaker"},
			},
			Bloodlust = {
				name = "Bloodlust",
				description = "Escalating melee damage that opens wounds and lets them bleed -- pure DPS, no threat tools at all.",
				skills = {"ReapingSlash", "RagingCleave", "Bloodbath"},
			},
		},
	},
}
```

- [ ] **Step 2: Verify the shape**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local Classes = require(game.ReplicatedStorage.Shared.Data.Classes)

assert(Classes.Tank.branches.Sentinel, "Tank.branches.Sentinel missing")
assert(not Classes.Tank.branches.Juggernaut, "Tank.branches.Juggernaut should be gone")
assert(#Classes.Tank.branches.Sentinel.skills == 3, "Sentinel should have 3 skills")
assert(#Classes.Tank.branches.Bulwark.skills == 3, "Bulwark should still have 3 skills")

local w = Classes.Warrior
assert(w, "Classes.Warrior missing")
assert(w.baseHealth == 120, "Warrior baseHealth wrong")
assert(w.startingSkills[1] == "Cleave", "Warrior startingSkills wrong")
assert(w.branches.Juggernaut and #w.branches.Juggernaut.skills == 3, "Warrior.Juggernaut wrong")
assert(w.branches.Juggernaut.skills[1] == "ProvokingStrike", "Juggernaut skill order wrong")
assert(w.branches.Bloodlust and #w.branches.Bloodlust.skills == 3, "Warrior.Bloodlust wrong")

return "OK"
```

Expected: returns `"OK"` with no error.

- [ ] **Step 3: Commit**

```bash
git add src/ReplicatedStorage/Shared/Data/Classes.lua
git commit -m "feat: add Warrior class, replace Tank's Juggernaut branch with Sentinel"
```

---

## Task 2: `Skills.lua` — add the 7 new skills, strip `tauntsOnHit` from ProvokingStrike

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Skills.lua`

- [ ] **Step 1: Remove `tauntsOnHit` from `ProvokingStrike`**

Find:

```lua
	ProvokingStrike = {
		id = "ProvokingStrike",
		displayName = "Provoking Strike",
		branch = "Juggernaut",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/provoking_strike_icon.png",
		cooldown = 4,
		range = 14,
		damage = 14,
		effectType = "damage",
		tauntsOnHit = true,
		description = "A vicious heavy slash that inflicts 14 damage and generates 3x bonus threat.",
	},
```

Replace with (the `tauntsOnHit` line removed, and the description updated since Warrior's version of this skill doesn't generate threat):

```lua
	ProvokingStrike = {
		id = "ProvokingStrike",
		displayName = "Provoking Strike",
		branch = "Juggernaut",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/provoking_strike_icon.png",
		cooldown = 4,
		range = 14,
		damage = 14,
		effectType = "damage",
		description = "A vicious heavy slash that inflicts 14 damage.",
	},
```

- [ ] **Step 2: Add the top-of-file comment mentioning Warrior**

Find:

```lua
-- Definitive skills registry for all classes (Tank: Juggernaut/Bulwark; Mage: Pyromancy/Frostweave/ArcaneMastery).
```

Replace with:

```lua
-- Definitive skills registry for all classes (Tank: Bulwark/Sentinel; Mage: Pyromancy/Frostweave/ArcaneMastery; Warrior: Juggernaut/Bloodlust).
```

- [ ] **Step 3: Add the 7 new skills**

Append this block at the very end of the file, right before the file's final closing `}` (after the `ArcaneNova` entry):

```lua

	-- ── BASE STARTING SKILL (Warrior) ────────────────────────────────────────
	Cleave = {
		id = "Cleave",
		displayName = "Cleave",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/cleave_icon.png",
		cooldown = 4,
		range = 12,
		damage = 12,
		effectType = "damage",
		description = "A basic but forceful sword strike, dealing 12 damage.",
	},

	-- ── SENTINEL BRANCH (Tank — Pure Threat & Mitigation) ────────────────────
	ShieldSlam = {
		id = "ShieldSlam",
		displayName = "Shield Slam",
		branch = "Sentinel",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/shield_slam_icon.png",
		cooldown = 5,
		range = 14,
		damage = 10,
		effectType = "damage",
		tauntsOnHit = true,
		description = "Slam your shield into a single enemy, dealing 10 damage and forcing their aggro onto you.",
	},

	AegisSlam = {
		id = "AegisSlam",
		displayName = "Aegis Slam",
		branch = "Sentinel",
		tier = 2,
		prerequisite = "ShieldSlam",
		icon = "rbxasset://textures/Soulforge/aegis_slam_icon.png",
		cooldown = 12,
		range = 16,
		damage = 14,
		effectType = "aoeDamage",
		description = "Drive your shield into the ground, dealing 14 AoE damage and forcing every nearby enemy's aggro onto you.",
	},

	GuardiansWrath = {
		id = "GuardiansWrath",
		displayName = "Guardian's Wrath",
		branch = "Sentinel",
		tier = 3,
		prerequisite = "AegisSlam",
		icon = "rbxasset://textures/Soulforge/guardians_wrath_icon.png",
		cooldown = 18,
		range = 20,
		damage = 22,
		effectType = "damage",
		tauntsOnHit = true,
		description = "Unleash a defender's full fury on a single enemy, dealing 22 damage and locking their aggro onto you.",
	},

	-- ── BLOODLUST BRANCH (Warrior — Escalating Melee DPS) ────────────────────
	ReapingSlash = {
		id = "ReapingSlash",
		displayName = "Reaping Slash",
		branch = "Bloodlust",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/reaping_slash_icon.png",
		cooldown = 4,
		range = 12,
		damage = 16,
		effectType = "damage",
		description = "A sweeping slash that opens a deep wound, dealing 16 damage.",
	},

	RagingCleave = {
		id = "RagingCleave",
		displayName = "Raging Cleave",
		branch = "Bloodlust",
		tier = 2,
		prerequisite = "ReapingSlash",
		icon = "rbxasset://textures/Soulforge/raging_cleave_icon.png",
		cooldown = 9,
		range = 14,
		damage = 20,
		effectType = "aoeDamage",
		description = "A wide, furious cleave, dealing 20 AoE damage to all nearby enemies.",
	},

	Bloodbath = {
		id = "Bloodbath",
		displayName = "Bloodbath",
		branch = "Bloodlust",
		tier = 3,
		prerequisite = "RagingCleave",
		icon = "rbxasset://textures/Soulforge/bloodbath_icon.png",
		cooldown = 16,
		range = 16,
		damage = 18,
		effectType = "aoeDotDamage",
		dotTickDamage = 5,
		dotTicks = 3,
		dotInterval = 1.5,
		description = "A frenzied whirlwind of strikes, dealing 18 AoE damage and opening bleeding wounds for 5 damage per tick over 3 ticks (4.5s).",
	},
```

- [ ] **Step 4: Verify all 7 new skills and the ProvokingStrike change**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local Skills = require(game.ReplicatedStorage.Shared.Data.Skills)
local Classes = require(game.ReplicatedStorage.Shared.Data.Classes)

assert(Skills.ProvokingStrike.tauntsOnHit == nil, "ProvokingStrike should no longer taunt")
assert(Skills.ProvokingStrike.damage == 14, "ProvokingStrike damage should be unchanged")

local expectedIds = {"Cleave", "ShieldSlam", "AegisSlam", "GuardiansWrath", "ReapingSlash", "RagingCleave", "Bloodbath"}
for _, id in expectedIds do
	local s = Skills[id]
	assert(s, id .. " missing from Skills")
	assert(s.effectType == "damage" or s.effectType == "aoeDamage" or s.effectType == "aoeDotDamage", id .. " has an unexpected effectType: " .. tostring(s.effectType))
end

-- Cross-check every skill id referenced by Tank and Warrior in Classes.lua exists in Skills.lua
for _, classId in {"Tank", "Warrior"} do
	local classDef = Classes[classId]
	local allIds = {classDef.startingSkills[1]}
	for _, branch in classDef.branches do
		for _, id in branch.skills do
			table.insert(allIds, id)
		end
	end
	assert(#allIds == 7, classId .. " should reference 7 total skill ids, got " .. #allIds)
	for _, id in allIds do
		assert(Skills[id], classId .. " references missing skill " .. id)
	end
end

return "OK"
```

Expected: returns `"OK"` with no error.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Data/Skills.lua
git commit -m "feat: add Warrior/Sentinel skills, strip threat generation from ProvokingStrike"
```

---

## Task 3: `Equipment.lua` — let Warrior equip Tank's Standard/Rockhide sets

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Equipment.lua`

- [ ] **Step 1: Widen `Standard` and `Rockhide`'s `classId` to a list**

Find:

```lua
		Standard = {
			id          = "Standard",
			displayName = "Adventurer's Standard Set",
			classId     = "Tank",
			tier        = 1,
```

Replace with:

```lua
		Standard = {
			id          = "Standard",
			displayName = "Adventurer's Standard Set",
			classId     = {"Tank", "Warrior"},
			tier        = 1,
```

Find:

```lua
		Rockhide = {
			id          = "Rockhide",
			displayName = "Rockhide Warlord Set",
			classId     = "Tank",
			tier        = 2,
```

Replace with:

```lua
		Rockhide = {
			id          = "Rockhide",
			displayName = "Rockhide Warlord Set",
			classId     = {"Tank", "Warrior"},
			tier        = 2,
```

(Leave `Apprentice`, `RockhideMage`, and the stashed `Sunforged` set's `classId` fields exactly as they are — only `Standard` and `Rockhide` are shared between two classes.)

- [ ] **Step 2: Update `GetItemClass`'s doc comment and return type**

Find:

```lua
--- Returns the class required to equip an item ("Tank", "Mage"), or nil if unrestricted.
function Equipment.GetItemClass(itemId: string): string?
	local item = Equipment.Items[itemId]
	if not item then return nil end
	if item.classId then return item.classId end
	local setData = Equipment.Sets[item.setId]
	return setData and setData.classId or nil
end
```

Replace with:

```lua
--- Returns the class(es) required to equip an item -- a single classId string
--- (e.g. "Mage"), a list of classId strings when a set is shared between
--- classes (e.g. {"Tank", "Warrior"}), or nil if unrestricted.
function Equipment.GetItemClass(itemId: string): (string | {string})?
	local item = Equipment.Items[itemId]
	if not item then return nil end
	if item.classId then return item.classId end
	local setData = Equipment.Sets[item.setId]
	return setData and setData.classId or nil
end
```

(The function body is unchanged — only the type annotation and comment, since it already just returns whatever `classId` holds, string or table.)

- [ ] **Step 3: Verify**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local Equipment = require(game.ReplicatedStorage.Shared.Data.Equipment)

assert(type(Equipment.Sets.Standard.classId) == "table", "Standard.classId should now be a table")
assert(table.find(Equipment.Sets.Standard.classId, "Tank"), "Standard should allow Tank")
assert(table.find(Equipment.Sets.Standard.classId, "Warrior"), "Standard should allow Warrior")

assert(type(Equipment.Sets.Rockhide.classId) == "table", "Rockhide.classId should now be a table")
assert(table.find(Equipment.Sets.Rockhide.classId, "Tank"), "Rockhide should allow Tank")
assert(table.find(Equipment.Sets.Rockhide.classId, "Warrior"), "Rockhide should allow Warrior")

-- Unrelated sets must be untouched
assert(Equipment.Sets.Apprentice.classId == "Mage", "Apprentice.classId should be unchanged")
assert(Equipment.Sets.RockhideMage.classId == "Mage", "RockhideMage.classId should be unchanged")
assert(Equipment.Sets.Sunforged.classId == "Tank", "Sunforged.classId should be unchanged")

local itemClass = Equipment.GetItemClass("StandardSword")
assert(type(itemClass) == "table" and table.find(itemClass, "Warrior"), "GetItemClass(StandardSword) should include Warrior")

return "OK"
```

Expected: returns `"OK"` with no error.

- [ ] **Step 4: Commit**

```bash
git add src/ReplicatedStorage/Shared/Data/Equipment.lua
git commit -m "feat: let Warrior equip Tank's Standard/Rockhide gear sets"
```

---

## Task 4: `WeaponService.lua` — Warrior skips the shield, equip-eligibility handles a list `classId`

**Files:**
- Modify: `src/ServerScriptService/Services/WeaponService.lua`

- [ ] **Step 1: Exclude Warrior from the shield-equip gate**

Find (in `EquipWeapons`):

```lua
	-- 2. Equip Shield (Tank only; Mages do not carry shields)
	if not isMage and targetWeapon ~= "ApprenticeStaff" and targetWeapon ~= "RockhideStaff" then
```

Replace with:

```lua
	-- 2. Equip Shield (Tank only; Mages and Warriors do not carry shields)
	if not isMage and classId ~= "Warrior" and targetWeapon ~= "ApprenticeStaff" and targetWeapon ~= "RockhideStaff" then
```

(`classId` is already in scope here — it's assigned a few lines above this function's existing `local classId = (charData and charData.ClassId) or "Mage"`. Nothing else in `EquipWeapons` needs to change: the default-equipment ternaries and the Mage-only gear-sanitize block both already produce the correct result for Warrior, since Warrior falls through every `isMage == false` path exactly like Tank does, and Warrior uses Tank's own item ids.)

- [ ] **Step 2: Make the equip-eligibility check handle a list `classId`**

Find (in `WeaponService.Start()`'s `RequestEquipEquipment` handler):

```lua
		-- Validate class eligibility: Mages cannot equip Tank gear, Tanks cannot equip Mage gear
		local itemClass = EquipmentData.GetItemClass(itemId)
		local playerClass = charData.ClassId or "Mage"
		if itemClass and itemClass ~= playerClass then
			warn(string.format("WeaponService: %s (%s) cannot equip %s (requires %s)", player.Name, tostring(playerClass), itemId, itemClass))
			return
		end
```

Replace with:

```lua
		-- Validate class eligibility: itemClass is either a single classId string
		-- (e.g. "Mage") or a list of allowed classIds (e.g. {"Tank", "Warrior"}
		-- for gear shared between classes -- see Equipment.lua's Standard/Rockhide
		-- sets).
		local itemClass = EquipmentData.GetItemClass(itemId)
		local playerClass = charData.ClassId or "Mage"
		local classAllowed = true
		if itemClass then
			if type(itemClass) == "table" then
				classAllowed = table.find(itemClass, playerClass) ~= nil
			else
				classAllowed = itemClass == playerClass
			end
		end
		if not classAllowed then
			warn(string.format("WeaponService: %s (%s) cannot equip %s (requires %s)", player.Name, tostring(playerClass), itemId, type(itemClass) == "table" and table.concat(itemClass, "/") or tostring(itemClass)))
			return
		end
```

- [ ] **Step 3: Verify structurally**

There is no test framework in this project. Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local source = game.ServerScriptService.Services.WeaponService.Source
assert(source:find('classId ~= "Warrior" and targetWeapon'), "shield-gate Warrior exclusion missing")
assert(source:find("classAllowed"), "equip-eligibility table handling missing")
return "OK"
```

Expected: returns `"OK"`. (Full behavioral verification — a Warrior character actually spawning without a shield, and being able to equip Standard/Rockhide gear — happens in Task 8's end-to-end playtest.)

- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/Services/WeaponService.lua
git commit -m "feat: Warrior skips the shield, equip-eligibility handles shared gear sets"
```

---

## Task 5: `HUDController.lua` — 3-way class badge/title, Tank's title renamed off "WARRIOR"

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua`

- [ ] **Step 1: Replace the `isMage` binary with a 3-way lookup**

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
	Tank = { attackIcon = "⚔️", badgeIcon = "🛡️", title = "SHIELD GUARDIAN" },
	Mage = { attackIcon = "🔮", badgeIcon = "🔮", title = "ARCANE MAGE" },
	Warrior = { attackIcon = "⚔️", badgeIcon = "⚔️", title = "BATTLE WARRIOR" },
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

(Tank's title changes from `"WARRIOR TANK"` to `"SHIELD GUARDIAN"` — keeping the old text would be actively confusing once a real Warrior class exists, per the design spec.)

- [ ] **Step 2: Update the other hardcoded `"WARRIOR TANK"` default**

Find:

```lua
	playerNameLabel.Text = player.DisplayName .. "  •  [WARRIOR TANK]"
```

Replace with:

```lua
	playerNameLabel.Text = player.DisplayName .. "  •  [SHIELD GUARDIAN]"
```

(This is the initial text set before `updateClassVisuals()` is called a couple lines later on the same setup pass — it's overwritten almost immediately, but should still say something consistent rather than the now-retired name.)

- [ ] **Step 3: Verify**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local source = game.StarterPlayer.StarterPlayerScripts.Controllers.HUDController.Source
assert(source:find("HUD_CLASS_VISUALS"), "HUD_CLASS_VISUALS table missing")
assert(source:find('Warrior = { attackIcon = "⚔️"'), "Warrior entry missing")
assert(not source:find("WARRIOR TANK"), "stale 'WARRIOR TANK' text should be fully removed")
assert(source:find("SHIELD GUARDIAN"), "Tank's new title missing")
return "OK"
```

Expected: returns `"OK"`.

- [ ] **Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
git commit -m "feat: generalize HUD class badge/title to Tank/Mage/Warrior, rename Tank's title"
```

---

## Task 6: `CharacterCreationController.lua` — third class-picker card, Tank copy updated

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua`

- [ ] **Step 1: Update `CLASS_CARD_INFO.Tank` and add `Warrior`**

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
		description = "Elusive arcane scholar who commands fire, frost, and raw arcane energy from range. Specialize into explosive Pyromancy, lingering Frostweave, or defensive Arcane Mastery.",
		traits = {
			{ "🔮", "Attack: Arcane Bolt (Ranged, Slows)" },
			{ "💙", "Base Health: 90 (Moderate)" },
			{ "🌳", "Trees: Pyromancy, Frostweave & Arcane Mastery" },
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
		description = "Steadfast frontline guardian armed with sword and heavy shield. Masters crowd control and holds boss aggro with Taunt.",
		traits = {
			{ "⚔️", "Attack: Heavy Sword Cleave" },
			{ "🛡️", "Starter Skill: Taunt" },
			{ "🌳", "Trees: Bulwark & Sentinel" },
		},
	},
	Mage = {
		icon = "🔮",
		title = "MAGE ARCHETYPE",
		description = "Elusive arcane scholar who commands fire, frost, and raw arcane energy from range. Specialize into explosive Pyromancy, lingering Frostweave, or defensive Arcane Mastery.",
		traits = {
			{ "🔮", "Attack: Arcane Bolt (Ranged, Slows)" },
			{ "💙", "Base Health: 90 (Moderate)" },
			{ "🌳", "Trees: Pyromancy, Frostweave & Arcane Mastery" },
		},
	},
	Warrior = {
		icon = "⚔️",
		title = "WARRIOR ARCHETYPE",
		description = "Relentless melee striker built for pure damage output. Masters heavy strikes and earthshaking crowd control, or opens wounds that bleed enemies dry.",
		traits = {
			{ "⚔️", "Attack: Heavy Sword Cleave" },
			{ "❤️", "Base Health: 120 (Balanced)" },
			{ "🌳", "Trees: Juggernaut & Bloodlust" },
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

Replace with (three cards at ~31.5% width each with small gaps, same layout math used elsewhere in this project's history for a 3-card row):

```lua
	local tankCard, tankCardStroke, tankCardHitbox = createClassCard(classCardsRow, "Tank", 0, 0.315)
	local mageCard, mageCardStroke, mageCardHitbox = createClassCard(classCardsRow, "Mage", 0.3425, 0.315)
	local warriorCard, warriorCardStroke, warriorCardHitbox = createClassCard(classCardsRow, "Warrior", 0.685, 0.315)

	local selectedClassId = "Mage"

	local function refreshClassCardSelection()
		tankCardStroke.Color = (selectedClassId == "Tank") and COLORS.goldPrimary or COLORS.slateBorder
		tankCardStroke.Thickness = (selectedClassId == "Tank") and 2.4 or 1.6
		mageCardStroke.Color = (selectedClassId == "Mage") and COLORS.goldPrimary or COLORS.slateBorder
		mageCardStroke.Thickness = (selectedClassId == "Mage") and 2.4 or 1.6
		warriorCardStroke.Color = (selectedClassId == "Warrior") and COLORS.goldPrimary or COLORS.slateBorder
		warriorCardStroke.Thickness = (selectedClassId == "Warrior") and 2.4 or 1.6
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
	warriorCardHitbox.Activated:Connect(function()
		selectedClassId = "Warrior"
		refreshClassCardSelection()
	end)
```

- [ ] **Step 3: Add `Warrior` to `HERO_CHOICE_INFO`**

Find (the `updateHeroChoiceCard` function — note this file does NOT yet have a `HERO_CHOICE_INFO` table; it's still using the older inline-ternary shape):

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
		Warrior = {
			className = "Warrior",
			badgeText = "⚔️ WARRIOR",
			badgeTextColor = Color3.fromRGB(255, 200, 160),
			badgeStrokeColor = Color3.fromRGB(230, 120, 60),
			badgeBgColor = Color3.fromRGB(70, 35, 15),
			hpChip = { "❤️ 120 HP", "Base Health" },
			skillChip = { "⚔️ Cleave", "Melee Focus" },
			flavorChip = { "🩸 Berserker", "Pure DPS" },
		},
	}

	local function updateHeroChoiceCard(classId: string, level: number)
		local levelText = ("⭐ LEVEL %d"):format(level)
		local lvlChild = levelBadge:FindFirstChildOfClass("TextLabel")
		if lvlChild then
			lvlChild.Text = levelText
		end

		local info = HERO_CHOICE_INFO[classId] or HERO_CHOICE_INFO.Tank
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

Note the fallback is `HERO_CHOICE_INFO.Tank` (not `.Mage`) — this matches the *original* code's own behavior exactly (the old ternary's `else` branch was Tank's content, so any non-Mage `classId`, including an unrecognized one, always fell back to Tank).

- [ ] **Step 4: Verify**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local source = game.StarterPlayer.StarterPlayerScripts.Controllers.CharacterCreationController.Source
assert(source:find('Warrior = {\n\t\ticon = "⚔️"'), "CLASS_CARD_INFO.Warrior missing")
assert(source:find('createClassCard%(classCardsRow, "Warrior"'), "third createClassCard call missing")
assert(source:find("warriorCardHitbox%.Activated:Connect"), "Warrior card click handler missing")
assert(source:find("HERO_CHOICE_INFO"), "HERO_CHOICE_INFO table missing")
assert(source:find("Trees: Bulwark & Sentinel"), "Tank's traits should mention Sentinel now")
assert(not source:find("Trees: Juggernaut & Bulwark"), "Tank's traits should no longer mention Juggernaut")
return "OK"
```

Expected: returns `"OK"`.

- [ ] **Step 5: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
git commit -m "feat: add Warrior to the character-creation class picker, update Tank's copy"
```

---

## Task 7: `SkillTreeUIController.lua` — Warrior branch order/title, Sentinel/Bloodlust colors

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua`

- [ ] **Step 1: Update `BRANCH_ORDER_BY_CLASS` and `CLASS_TITLE_INFO`**

Find:

```lua
local BRANCH_ORDER_BY_CLASS = {
	Tank = {"Bulwark", "Juggernaut"},
	Mage = {"Pyromancy", "Frostweave", "ArcaneMastery"},
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
	Tank = {"Bulwark", "Sentinel"},
	Mage = {"Pyromancy", "Frostweave", "ArcaneMastery"},
	Warrior = {"Juggernaut", "Bloodlust"},
}

local activeMobileBranch: string = BRANCH_ORDER_BY_CLASS.Tank[1]

-- Icon + display name shown in the modal's title bar, keyed by ReplicatedStorage.Shared.Data.Classes's own keys.
local CLASS_TITLE_INFO = {
	Tank = { icon = "🛡️", name = "TANK" },
	Mage = { icon = "🔮", name = "MAGE" },
	Warrior = { icon = "⚔️", name = "WARRIOR" },
}
```

- [ ] **Step 2: Add `Sentinel` and `Bloodlust` to `BRANCH_COLORS`**

Find the end of `BRANCH_COLORS` (the `ArcaneMastery` entry's closing, right before `}`):

```lua
	ArcaneMastery = {
		primary = Color3.fromRGB(145, 80, 255),
		secondary = Color3.fromRGB(75, 32, 145),
		bg = Color3.fromRGB(20, 14, 36),
		cardBg = Color3.fromRGB(30, 20, 52),
		border = Color3.fromRGB(120, 65, 215),
		accent = Color3.fromRGB(210, 170, 255),
		icon = "✨",
		name = "ARCANE MASTERY",
		displayName = "ARCANE MASTERY SPECIALIZATION",
		tagline = "Barriers, burst damage & arcane control",
	},
}
```

Replace with:

```lua
	ArcaneMastery = {
		primary = Color3.fromRGB(145, 80, 255),
		secondary = Color3.fromRGB(75, 32, 145),
		bg = Color3.fromRGB(20, 14, 36),
		cardBg = Color3.fromRGB(30, 20, 52),
		border = Color3.fromRGB(120, 65, 215),
		accent = Color3.fromRGB(210, 170, 255),
		icon = "✨",
		name = "ARCANE MASTERY",
		displayName = "ARCANE MASTERY SPECIALIZATION",
		tagline = "Barriers, burst damage & arcane control",
	},
	Sentinel = {
		primary = Color3.fromRGB(160, 170, 185),
		secondary = Color3.fromRGB(90, 98, 110),
		bg = Color3.fromRGB(22, 24, 28),
		cardBg = Color3.fromRGB(30, 33, 38),
		border = Color3.fromRGB(130, 140, 155),
		accent = Color3.fromRGB(200, 210, 220),
		icon = "🔰",
		name = "SENTINEL",
		displayName = "SENTINEL SPECIALIZATION",
		tagline = "Pure threat and mitigation, no damage identity",
	},
	Bloodlust = {
		primary = Color3.fromRGB(150, 20, 35),
		secondary = Color3.fromRGB(80, 10, 20),
		bg = Color3.fromRGB(28, 14, 16),
		cardBg = Color3.fromRGB(38, 18, 20),
		border = Color3.fromRGB(120, 25, 35),
		accent = Color3.fromRGB(220, 60, 75),
		icon = "🩸",
		name = "BLOODLUST",
		displayName = "BLOODLUST SPECIALIZATION",
		tagline = "Escalating melee damage that opens wounds and bleeds",
	},
}
```

(The existing `Juggernaut` color entry is left completely untouched — it now renders under Warrior instead of Tank, which is correct, since the branch's identity didn't change, only which class owns it.)

- [ ] **Step 3: Verify**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
local source = game.StarterPlayer.StarterPlayerScripts.Controllers.SkillTreeUIController.Source
assert(source:find('Tank = {"Bulwark", "Sentinel"}'), "BRANCH_ORDER_BY_CLASS.Tank not updated")
assert(source:find('Warrior = {"Juggernaut", "Bloodlust"}'), "BRANCH_ORDER_BY_CLASS.Warrior missing")
assert(source:find('Warrior = { icon = "⚔️", name = "WARRIOR" }'), "CLASS_TITLE_INFO.Warrior missing")
assert(source:find("Sentinel = {"), "BRANCH_COLORS.Sentinel missing")
assert(source:find("Bloodlust = {"), "BRANCH_COLORS.Bloodlust missing")
assert(source:find("Juggernaut = {"), "BRANCH_COLORS.Juggernaut should still be present (reused, not removed)")
return "OK"
```

Expected: returns `"OK"`.

- [ ] **Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua
git commit -m "feat: add Warrior branch order/title and Sentinel/Bloodlust colors to the skill tree UI"
```

---

## Task 8: End-to-end verification in Roblox Studio

**Files:** none (verification only)

- [ ] **Step 1: Route through the real character-creation flow**

Run in Studio, `execute_luau`, `datamodel_type: "Edit"`:

```lua
game.ReplicatedStorage:SetAttribute("TestCharacterCreation", true)
return "set"
```

(`CharacterCreationService.handlePlayer`'s Studio auto-load shortcut always creates a Mage, bypassing the picker — this attribute routes through the real creation UI instead, same escape hatch used by every prior plan in this project.)

- [ ] **Step 2: Start Play and pick Warrior**

1. `start_stop_play` with `is_start: true`.
2. `get_console_output` — confirm no errors (particularly no Luau parse/require errors from any of the 6 files this plan touched).
3. Take a `screen_capture` of the character-creation screen — confirm **three** cards are visible (Tank / Mage / Warrior), and Tank's card no longer says anything about "Juggernaut".
4. Click the Warrior card's hitbox (locate it via `game.Players.<name>.PlayerGui.CharacterCreation...ClassCard_Warrior.SelectHitbox`, or by reading its `AbsolutePosition`/`AbsoluteSize` via `execute_luau` and clicking the computed center point — the exact instance-path click sometimes fails to resolve through repeated same-named `Frame` ancestors in this UI, in which case the coordinate-based click is the reliable fallback, per prior experience with this exact screen in this project), then click EMBARK/CREATE.
5. `screen_capture` again — confirm the HUD shows `⚔️` icons and `BATTLE WARRIOR` in the player name label, HP reads `120` (before gear bonuses) or a plausible boosted value (120 + any `maxHPBonus` from equipped Standard-tier gear), and the character does **not** have a shield model attached.

- [ ] **Step 3: Confirm starting equipment and skill via the live client**

Since `PlayerDataService`'s profile state isn't reliably readable via ad-hoc `execute_luau` calls in this environment (a fresh `require()` from an ad-hoc script gets its own isolated module instance, not the live server's), verify via the client's own UI instead: open Inventory (press `I`) and confirm the equipped loadout shows `Iron Sword` / `Iron Helm` / `Iron Chestplate` / `Iron Vambraces` / `Iron Sabatons` (Standard set), and scrolling the Gear list shows `Rockhide Fang`/`Rockhide Helm`/etc. already owned (tier 2, pre-stashed). Open Skills (press `K`) and confirm slot 1 shows `Cleave`.

- [ ] **Step 4: Verify Warrior's Cleave and a Sentinel/Bloodlust skill actually deal damage**

This needs a live target. If a trash mob or the Rockhide boss is reachable in the current Hub/dungeon state, target it (click it) and press `1` (Cleave). If no enemy is reachable from the Hub, this step can be verified structurally instead: confirm via `get_console_output` that pressing `1` doesn't produce any `onCastSkill`-related error, and rely on Task 2's Step 4 data-level verification (that `Cleave`'s `effectType = "damage"` already goes through the exact same, already-proven `CombatService.onCastSkill` dispatch branch every other `damage`-type skill in this game already uses successfully) as sufficient evidence the mechanic itself works — this plan makes zero changes to `CombatService.lua`, so there is no new dispatch logic to be wrong here.

- [ ] **Step 5: Confirm Tank's Sentinel branch and no more Juggernaut under Tank**

Reforge or create a Tank character (via the same picker flow). Open Skills (press `K`) — confirm the two branch tabs are **Bulwark** and **Sentinel** (not Juggernaut), Sentinel shows `Shield Slam` → `Aegis Slam` → `Guardian's Wrath` with the grey/steel color scheme from Task 7, and the HUD shows `🛡️` / `SHIELD GUARDIAN` (not `WARRIOR TANK`).

- [ ] **Step 6: Confirm Warrior's Juggernaut branch renders correctly**

Back on the Warrior character from Step 2, open Skills and confirm the **Juggernaut** branch tab shows `Provoking Strike` → `Shield Bash` → `Earthshaker` with its existing red color scheme (unchanged, just now under Warrior), and **Bloodlust** shows `Reaping Slash` → `Raging Cleave` → `Bloodbath` with the new dark-red/maroon color scheme.

- [ ] **Step 7: Stop Play and unset the test attribute**

`start_stop_play` with `is_start: false`.

`execute_luau`, `datamodel_type: "Edit"`:

```lua
game.ReplicatedStorage:SetAttribute("TestCharacterCreation", nil)
return "cleared"
```

- [ ] **Step 8: Final commit**

If Steps 2-6 required any fixes to earlier tasks' code, those fixes should already be committed as part of returning to each task's own commit. This step is only needed if any stray uncommitted changes remain:

```bash
git status
```

If clean, no commit needed — Task 8 is verification-only.

---

## Self-Review Notes

**Spec coverage:** §1 (`Classes.lua`) → Task 1. §2 (new skills, all reusing existing effect types) → Task 2. §3 (gear reuse, no shield) → Tasks 3 + 4. §4 (cross-cutting `isMage`-style generalization) → Tasks 5, 6, 7. §5 (`GetItemClass` return-type ripple) → Task 3 Step 2 + Task 4 Step 2. All spec sections have a task. Confirmed via direct source inspection during plan-writing that `CharacterCreationService.lua`'s `setupInitialEquipment` and `validateClassId`, and `CombatService.lua`'s normal-attack dispatch, need **zero changes** — their existing "not Mage" fallback logic is already correct for Warrior, since Warrior is non-caster/melee like Tank and uses Tank's own item ids. This is called out explicitly in the plan's Architecture section rather than silently omitted, so it isn't mistaken for a gap.

**Placeholder scan:** no "TBD"/"add error handling"/"similar to Task N" in any step above — every step shows the literal code or the literal command to run.

**Type/name consistency check:** `ShieldSlam`/`AegisSlam`/`GuardiansWrath` (Task 2's Skills.lua additions) match `Classes.Tank.branches.Sentinel.skills` exactly (Task 1). `Cleave`/`ReapingSlash`/`RagingCleave`/`Bloodbath` match `Classes.Warrior`'s `startingSkills`/`branches.Bloodlust.skills` exactly. `classAllowed`/`table.find` usage in Task 4 Step 2 matches the `classId` list shape introduced in Task 3 Step 1. `HUD_CLASS_VISUALS`/`HERO_CHOICE_INFO` naming in Tasks 5/6 matches the exact pattern this project already used for its prior Healer-class plan (same table shape, same field names), for consistency across the codebase's own history.
