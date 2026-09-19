# Mage Class Kit + Generalized Skill Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a data-driven `effectType` field to every skill so `CombatService` stops hardcoding behavior by exact skill name, and add the Mage class (`Classes.Mage`, Pyromancy/Frostweave branches) using that new system — reachable only via a temporary test-only unlock for this sub-project, no class-selection UI yet.

**Architecture:** `Skills.lua` gains an `effectType` field per skill (`tauntAoe`, `damage`, `aoeDamage`, `selfHeal`, `dotDamage`, `aoeDotDamage`) plus a `tauntsOnHit` flag where needed; `CombatService.onCastSkill` dispatches on `effectType` instead of `skillId`, with a new small helper for scheduling damage-over-time ticks. `Classes.lua` gains a `Mage` entry with the same shape as the existing `Tank` entry.

**Tech Stack:** Roblox Studio (Luau), Rojo-synced `src/` tree, Roblox Studio MCP tools (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`) for live verification.

**Spec:** [docs/superpowers/specs/2026-09-18-mage-class-design.md](../specs/2026-09-18-mage-class-design.md)

**Studio target:** `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8` ("Soul Forge", placeId 125354010947424). Re-resolve with `list_roblox_studios` if this id is no longer connected when execution starts.

---

### Task 1: Add `effectType` to existing Tank skills and the 7 new Mage skills in `Skills.lua`

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Skills.lua`

- [ ] **Step 1: Add `effectType` (and `tauntsOnHit` for `ProvokingStrike`) to the existing Tank skills**

Find (the entire current file, 100 lines):
```lua
-- src/ReplicatedStorage/Shared/Data/Skills.lua
-- Definitive skills registry for Tank specializations (Juggernaut & Bulwark branches).
return {
	-- ── BASE STARTING SKILL ──────────────────────────────────────────────────
	Taunt = {
		id = "Taunt",
		displayName = "Taunt",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/taunt_icon.png", -- Realistic dark-fantasy warcry icon (or rbxassetid://<id>)
		cooldown = 12,
		range = 30,
		damage = 0,
		description = "Unleash an enraged battle cry, taunting all enemies within 30 studs and forcing their aggro onto you.",
	},

	-- ── JUGGERNAUT BRANCH (Offense, Heavy Threat, & Crowd Control) ───────────
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
		description = "A vicious heavy slash that inflicts 14 damage and generates 3x bonus threat.",
	},

	ShieldBash = {
		id = "ShieldBash",
		displayName = "Shield Bash",
		branch = "Juggernaut",
		tier = 2,
		prerequisite = "ProvokingStrike",
		icon = "rbxasset://textures/Soulforge/shield_bash_icon.png",
		cooldown = 8,
		range = 14,
		damage = 16,
		description = "Drive your shield into the enemy with crushing force, dealing 16 damage and staggering them.",
	},

	Earthshaker = {
		id = "Earthshaker",
		displayName = "Earthshaker",
		branch = "Juggernaut",
		tier = 3,
		prerequisite = "ShieldBash",
		icon = "rbxasset://textures/Soulforge/earthshaker_icon.png",
		cooldown = 14,
		range = 16,
		damage = 24,
		description = "Leap into the air and smash your weapon into the earth, sending a shockwave that deals 24 AoE damage to all nearby enemies.",
	},

	-- ── BULWARK BRANCH (Defense, Sustain, & Party Protection) ─────────────────
	GuardStance = {
		id = "GuardStance",
		displayName = "Guard Stance",
		branch = "Bulwark",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/guard_stance_icon.png",
		cooldown = 18,
		range = 0,
		damage = 0,
		duration = 6,
		description = "Lock into a stalwart defensive posture, reducing all incoming damage by 50% for 6 seconds.",
	},

	IronWill = {
		id = "IronWill",
		displayName = "Iron Will",
		branch = "Bulwark",
		tier = 2,
		prerequisite = "GuardStance",
		icon = "rbxasset://textures/Soulforge/iron_will_icon.png",
		cooldown = 22,
		range = 0,
		damage = 0,
		healAmount = 40,
		description = "Channel unbreakable resolve to immediately restore 40 Health and cleanse negative effects.",
	},

	FortressAura = {
		id = "FortressAura",
		displayName = "Fortress Aura",
		branch = "Bulwark",
		tier = 3,
		prerequisite = "IronWill",
		icon = "rbxasset://textures/Soulforge/fortress_aura_icon.png",
		cooldown = 28,
		range = 0,
		damage = 0,
		duration = 8,
		description = "Project an impenetrable defensive barrier, granting yourself and all nearby party members 30% damage reduction for 8 seconds.",
	},
}
```
Replace with:
```lua
-- src/ReplicatedStorage/Shared/Data/Skills.lua
-- Definitive skills registry for all classes (Tank: Juggernaut/Bulwark; Mage: Pyromancy/Frostweave).
--
-- effectType drives how CombatService.onCastSkill resolves what a skill actually does:
--   tauntAoe      - taunts every enemy within range (Taunt)
--   damage        - single-target instant damage (ProvokingStrike, ShieldBash, ArcaneBolt, Firebolt, Fireball)
--   aoeDamage     - instant damage to every enemy within range (Earthshaker, Meteor)
--   selfHeal      - restores the caster's own health (IronWill)
--   dotDamage     - single-target instant damage + follow-up damage-over-time ticks (Frostbolt, IceLance)
--   aoeDotDamage  - aoeDamage + follow-up damage-over-time ticks on every enemy hit (Blizzard)
-- GuardStance/FortressAura are buffSelf/buffParty -- intentionally unhandled by any dispatch
-- branch in CombatService (see that file's comment); they were already no-ops before this
-- effectType field existed, this just labels the gap instead of hiding it in a name check.
--
-- tauntsOnHit = true marks a single-target damage skill that also taunts on hit (ProvokingStrike).
return {
	-- ── BASE STARTING SKILL (Tank) ───────────────────────────────────────────
	Taunt = {
		id = "Taunt",
		displayName = "Taunt",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/taunt_icon.png", -- Realistic dark-fantasy warcry icon (or rbxassetid://<id>)
		cooldown = 12,
		range = 30,
		damage = 0,
		effectType = "tauntAoe",
		description = "Unleash an enraged battle cry, taunting all enemies within 30 studs and forcing their aggro onto you.",
	},

	-- ── JUGGERNAUT BRANCH (Offense, Heavy Threat, & Crowd Control) ───────────
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

	ShieldBash = {
		id = "ShieldBash",
		displayName = "Shield Bash",
		branch = "Juggernaut",
		tier = 2,
		prerequisite = "ProvokingStrike",
		icon = "rbxasset://textures/Soulforge/shield_bash_icon.png",
		cooldown = 8,
		range = 14,
		damage = 16,
		effectType = "damage",
		description = "Drive your shield into the enemy with crushing force, dealing 16 damage and staggering them.",
	},

	Earthshaker = {
		id = "Earthshaker",
		displayName = "Earthshaker",
		branch = "Juggernaut",
		tier = 3,
		prerequisite = "ShieldBash",
		icon = "rbxasset://textures/Soulforge/earthshaker_icon.png",
		cooldown = 14,
		range = 16,
		damage = 24,
		effectType = "aoeDamage",
		description = "Leap into the air and smash your weapon into the earth, sending a shockwave that deals 24 AoE damage to all nearby enemies.",
	},

	-- ── BULWARK BRANCH (Defense, Sustain, & Party Protection) ─────────────────
	GuardStance = {
		id = "GuardStance",
		displayName = "Guard Stance",
		branch = "Bulwark",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/guard_stance_icon.png",
		cooldown = 18,
		range = 0,
		damage = 0,
		duration = 6,
		effectType = "buffSelf",
		description = "Lock into a stalwart defensive posture, reducing all incoming damage by 50% for 6 seconds.",
	},

	IronWill = {
		id = "IronWill",
		displayName = "Iron Will",
		branch = "Bulwark",
		tier = 2,
		prerequisite = "GuardStance",
		icon = "rbxasset://textures/Soulforge/iron_will_icon.png",
		cooldown = 22,
		range = 0,
		damage = 0,
		healAmount = 40,
		effectType = "selfHeal",
		description = "Channel unbreakable resolve to immediately restore 40 Health and cleanse negative effects.",
	},

	FortressAura = {
		id = "FortressAura",
		displayName = "Fortress Aura",
		branch = "Bulwark",
		tier = 3,
		prerequisite = "IronWill",
		icon = "rbxasset://textures/Soulforge/fortress_aura_icon.png",
		cooldown = 28,
		range = 0,
		damage = 0,
		duration = 8,
		effectType = "buffParty",
		description = "Project an impenetrable defensive barrier, granting yourself and all nearby party members 30% damage reduction for 8 seconds.",
	},

	-- ── BASE STARTING SKILL (Mage) ───────────────────────────────────────────
	ArcaneBolt = {
		id = "ArcaneBolt",
		displayName = "Arcane Bolt",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/arcane_bolt_icon.png",
		cooldown = 3,
		range = 30,
		damage = 10,
		effectType = "damage",
		description = "A basic bolt of raw arcane energy, dealing 10 damage.",
	},

	-- ── PYROMANCY BRANCH (Explosive Single-Target & Area Fire Damage) ────────
	Firebolt = {
		id = "Firebolt",
		displayName = "Firebolt",
		branch = "Pyromancy",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/firebolt_icon.png",
		cooldown = 5,
		range = 25,
		damage = 18,
		effectType = "damage",
		description = "Hurl a searing bolt of flame, dealing 18 burst damage.",
	},

	Fireball = {
		id = "Fireball",
		displayName = "Fireball",
		branch = "Pyromancy",
		tier = 2,
		prerequisite = "Firebolt",
		icon = "rbxasset://textures/Soulforge/fireball_icon.png",
		cooldown = 9,
		range = 25,
		damage = 26,
		effectType = "damage",
		description = "Launch a roaring ball of fire, dealing 26 burst damage.",
	},

	Meteor = {
		id = "Meteor",
		displayName = "Meteor",
		branch = "Pyromancy",
		tier = 3,
		prerequisite = "Fireball",
		icon = "rbxasset://textures/Soulforge/meteor_icon.png",
		cooldown = 16,
		range = 20,
		damage = 30,
		effectType = "aoeDamage",
		description = "Call down a blazing meteor, dealing 30 AoE damage to all nearby enemies.",
	},

	-- ── FROSTWEAVE BRANCH (Sustained Frost Damage-Over-Time) ─────────────────
	Frostbolt = {
		id = "Frostbolt",
		displayName = "Frostbolt",
		branch = "Frostweave",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/frostbolt_icon.png",
		cooldown = 5,
		range = 25,
		damage = 10,
		effectType = "dotDamage",
		dotTickDamage = 3,
		dotTicks = 3,
		dotInterval = 1.5,
		description = "A shard of ice that deals 10 damage on impact, then 3 damage per tick over the next 3 ticks (4.5s).",
	},

	IceLance = {
		id = "IceLance",
		displayName = "Ice Lance",
		branch = "Frostweave",
		tier = 2,
		prerequisite = "Frostbolt",
		icon = "rbxasset://textures/Soulforge/ice_lance_icon.png",
		cooldown = 9,
		range = 25,
		damage = 14,
		effectType = "dotDamage",
		dotTickDamage = 4,
		dotTicks = 3,
		dotInterval = 1.5,
		description = "A piercing lance of ice that deals 14 damage on impact, then 4 damage per tick over the next 3 ticks (4.5s).",
	},

	Blizzard = {
		id = "Blizzard",
		displayName = "Blizzard",
		branch = "Frostweave",
		tier = 3,
		prerequisite = "IceLance",
		icon = "rbxasset://textures/Soulforge/blizzard_icon.png",
		cooldown = 16,
		range = 20,
		damage = 16,
		effectType = "aoeDotDamage",
		dotTickDamage = 4,
		dotTicks = 3,
		dotInterval = 1.5,
		description = "Summon a raging blizzard, dealing 16 AoE damage to all nearby enemies, then 4 damage per tick over the next 3 ticks (4.5s) to each.",
	},
}
```

- [ ] **Step 2: Verify**

Run:
```bash
grep -n "effectType = \"" "Soulforge/src/ReplicatedStorage/Shared/Data/Skills.lua" | wc -l
```
Expected: `14` (one `effectType` per skill: 7 Tank skills — Taunt, ProvokingStrike, ShieldBash, Earthshaker, GuardStance, IronWill, FortressAura — plus 7 Mage skills — ArcaneBolt, Firebolt, Fireball, Meteor, Frostbolt, IceLance, Blizzard).

Run:
```bash
grep -c "^\t[A-Za-z]* = {$" "Soulforge/src/ReplicatedStorage/Shared/Data/Skills.lua"
```
Expected: `14` (14 top-level skill entries total).

---

### Task 2: Add `Classes.Mage` to `Classes.lua`

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Data/Classes.lua`

- [ ] **Step 1: Add the Mage class entry**

Find (the entire current file, 20 lines):
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
}
```
Replace with:
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

	-- Not yet reachable through character creation or the skill tree UI (both still
	-- hardcode Tank) -- see docs/superpowers/specs/2026-09-18-mage-class-design.md's
	-- "sub-project 2" for that follow-up work. Playable today only via a manual
	-- ClassId/UnlockedSkills override on a test profile.
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

- [ ] **Step 2: Verify**

Run:
```bash
grep -n "Mage = {\|baseHealth = 80\|Pyromancy = {\|Frostweave = {" "Soulforge/src/ReplicatedStorage/Shared/Data/Classes.lua"
```
Expected: four matches, one per pattern.

---

### Task 3: Generalize `CombatService.onCastSkill` to dispatch on `effectType`

**Files:**
- Modify: `src/ServerScriptService/Services/CombatService.lua`

- [ ] **Step 1: Add the `applyDotTicks` helper**

Find (this exact block, currently around lines 72-76, right after `getPlayerSkillDamage`):
```lua
local function getPlayerSkillDamage(player: Player, baseDamage: number): number
	local mult = getDamageMultiplier(player)
	return math.floor(baseDamage * mult)
end

```
Replace with:
```lua
local function getPlayerSkillDamage(player: Player, baseDamage: number): number
	local mult = getDamageMultiplier(player)
	return math.floor(baseDamage * mult)
end

-- Schedules tickCount follow-up hits of tickDamage against enemy, interval seconds
-- apart, for dotDamage/aoeDotDamage skills. Each tick re-resolves the damage
-- multiplier at fire time (not once upfront) so a mid-DoT health-threshold change
-- (e.g. the Rockhide set bonus) is reflected correctly, matching how an instant hit
-- always computes its multiplier fresh. If the enemy is already dead/despawned by
-- the time a given tick fires, enemy.onDamaged's own "if not alive" guard (already
-- present in both MonsterAIService and BossAIService) makes that tick a safe no-op --
-- no cancellation/cleanup bookkeeping needed here.
local function applyDotTicks(enemy, player: Player, tickDamage: number, tickCount: number, interval: number)
	for i = 1, tickCount do
		task.delay(interval * i, function()
			if enemy and enemy.model and enemy.model.Parent then
				enemy.onDamaged(getPlayerSkillDamage(player, tickDamage), player)
			end
		end)
	end
end

```

- [ ] **Step 2: Generalize the AoE/self range-check bypass**

Find:
```lua
	local isAoeOrSelf = (skillId == "Taunt" or skillId == "Earthshaker" or skillId == "IronWill" or skillId == "FortressAura")
```
Replace with:
```lua
	local isAoeOrSelf = (skill.effectType == "tauntAoe" or skill.effectType == "aoeDamage" or skill.effectType == "aoeDotDamage"
		or skill.effectType == "selfHeal" or skill.effectType == "buffSelf" or skill.effectType == "buffParty")
```

- [ ] **Step 3: Replace the skillId-name dispatch with effectType dispatch**

Find (this exact block):
```lua
	if skillId == "Taunt" then
		-- AoE Warcry: Taunts all enemies within skill.range (30 studs)
		local tauntRadius = skill.range > 0 and skill.range or 30
		for _, e in pairs(enemies) do
			if e and e.model and e.model.Parent then
				local part = e.model.PrimaryPart or e.model:FindFirstChildWhichIsA("BasePart")
				if part then
					local dist = (part.Position - rootPart.Position).Magnitude
					if dist <= tauntRadius then
						if e.onTaunted then
							e.onTaunted(player)
						end
						Net.Get("TargetTaunted"):FireAllClients(e.model)
					end
				end
			end
		end
	elseif skillId == "Earthshaker" then
		-- AoE slam: damage all registered enemies within range
		local aoeRadius = skill.range > 0 and skill.range or 16
		for _, e in pairs(enemies) do
			if e and e.model and e.model.PrimaryPart and e.model.Parent then
				local dist = (e.model.PrimaryPart.Position - rootPart.Position).Magnitude
				if dist <= aoeRadius then
					e.onDamaged(getPlayerSkillDamage(player, skill.damage), player)
				end
			end
		end
	elseif skillId == "IronWill" then
		-- Self sustain: restore 40 health
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local heal = skill.healAmount or 40
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
			Net.Get("HealthChanged"):FireAllClients(player.UserId, humanoid.Health, humanoid.MaxHealth)
		end
	else
		if enemy then
			if (skillId == "Taunt" or skillId == "ProvokingStrike") and enemy.onTaunted then
				enemy.onTaunted(player)
			end
			if skill.damage > 0 then
				enemy.onDamaged(getPlayerSkillDamage(player, skill.damage), player)
			end
		end
	end
end
```
Replace with:
```lua
	if skill.effectType == "tauntAoe" then
		-- AoE Warcry: Taunts all enemies within skill.range (30 studs)
		local tauntRadius = skill.range > 0 and skill.range or 30
		for _, e in pairs(enemies) do
			if e and e.model and e.model.Parent then
				local part = e.model.PrimaryPart or e.model:FindFirstChildWhichIsA("BasePart")
				if part then
					local dist = (part.Position - rootPart.Position).Magnitude
					if dist <= tauntRadius then
						if e.onTaunted then
							e.onTaunted(player)
						end
						Net.Get("TargetTaunted"):FireAllClients(e.model)
					end
				end
			end
		end
	elseif skill.effectType == "aoeDamage" or skill.effectType == "aoeDotDamage" then
		-- AoE slam: damage all registered enemies within range, plus follow-up DoT ticks if this skill has them
		local aoeRadius = skill.range > 0 and skill.range or 16
		for _, e in pairs(enemies) do
			if e and e.model and e.model.PrimaryPart and e.model.Parent then
				local dist = (e.model.PrimaryPart.Position - rootPart.Position).Magnitude
				if dist <= aoeRadius then
					e.onDamaged(getPlayerSkillDamage(player, skill.damage), player)
					if skill.effectType == "aoeDotDamage" and skill.dotTicks then
						applyDotTicks(e, player, skill.dotTickDamage, skill.dotTicks, skill.dotInterval)
					end
				end
			end
		end
	elseif skill.effectType == "selfHeal" then
		-- Self sustain: restore health
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local heal = skill.healAmount or 40
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
			Net.Get("HealthChanged"):FireAllClients(player.UserId, humanoid.Health, humanoid.MaxHealth)
		end
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
	-- GuardStance/FortressAura already did nothing when cast before this refactor;
	-- this keeps that exact (pre-existing, out of scope) behavior while making the
	-- gap explicit and labeled instead of hidden inside a name check.
end
```

- [ ] **Step 4: Verify no leftover `skillId ==` effect checks remain**

Run:
```bash
grep -n "skillId == \"Taunt\"\|skillId == \"Earthshaker\"\|skillId == \"IronWill\"\|skillId == \"FortressAura\"\|skillId == \"ProvokingStrike\"" "Soulforge/src/ServerScriptService/Services/CombatService.lua"
```
Expected: no output (zero matches) — all of these were name-based checks now replaced by `effectType`/`tauntsOnHit` checks.

---

### Task 4: Live verification and commit

**Files:**
- (verifies) `src/ReplicatedStorage/Shared/Data/Skills.lua`
- (verifies) `src/ReplicatedStorage/Shared/Data/Classes.lua`
- (verifies) `src/ServerScriptService/Services/CombatService.lua`

This sub-project has no class-selection UI yet, so verification uses a **temporary** edit to `PlayerDataService.lua`'s `DEFAULT_DATA` to pre-unlock/equip one skill per new/changed dispatch branch on a fresh test character, exercising the real cast path end-to-end. This mirrors the same temporary-constant-then-revert technique used earlier this session for `BLEED_OUT_SECONDS`/`STUDIO_DIRECT_DUNGEON`.

- [ ] **Step 1: Temporarily broaden the test character's starting skills**

Read `src/ServerScriptService/Services/PlayerDataService.lua` and find its `DEFAULT_DATA.Character` block. Temporarily change:
```lua
		UnlockedSkills = {"Taunt"},
		EquippedSkills = {"Taunt"},
```
to:
```lua
		UnlockedSkills = {"Taunt", "ProvokingStrike", "Earthshaker", "Frostbolt"},
		EquippedSkills = {"Taunt", "ProvokingStrike", "Earthshaker", "Frostbolt"},
```
This covers all four of the branches that changed or are new in Task 3 with a single live cast each: `tauntAoe` (Taunt), `damage` + `tauntsOnHit` (ProvokingStrike), `aoeDamage` (Earthshaker), `dotDamage` (Frostbolt). `selfHeal` (IronWill) is not included in this live pass — its dispatch body is an unmodified copy (only the `elseif` condition changed from a name check to an effectType check), a mechanical rename with minimal regression risk, already covered by Task 3 Step 4's grep and this task's code re-read in Step 2 below.

- [ ] **Step 2: Re-read the three modified files and confirm they match what Tasks 1-3 specified**

Read `Skills.lua`, `Classes.lua`, and `CombatService.lua` in full. Confirm:
- All 14 skills in `Skills.lua` have an `effectType`, `ProvokingStrike` has `tauntsOnHit = true`.
- `Classes.lua` has both `Tank` and `Mage`, `Mage.baseHealth == 80`.
- `CombatService.lua`'s `onCastSkill` has no remaining `skillId == "..."` effect checks (besides the unrelated unlock/cooldown logic earlier in the function, which never used skillId to select behavior).

If anything doesn't match, STOP and fix it now — do not proceed to live testing against an incorrect implementation.

- [ ] **Step 3: Confirm Studio is in Edit mode, then start Play**

Call `mcp__Roblox_Studio__get_studio_state` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`. If `Play`, call `start_stop_play` with `is_start: false` first. Then call `start_stop_play` with `is_start: true`.

- [ ] **Step 4: Check console for errors**

Call `mcp__Roblox_Studio__get_console_output`.

Expected: no Luau errors referencing `CombatService`, `Skills`, or `Classes` (pre-existing unrelated noise like the animation-load warnings is expected).

- [ ] **Step 5: Get a fresh character with the test loadout**

The existing test player's profile already has `UnlockedSkills`/`EquippedSkills` saved from earlier sessions and won't pick up the new `DEFAULT_DATA` automatically (`Reconcile()` only fills in fields that don't exist at all). Use the in-game "Reforge Hero (Start Anew)" option (seen on the hero-selection screen earlier this session) to reset `Character` data to the new defaults — this is a real, already-existing game feature (`RequestCreateNewCharacter`), not a script workaround.

Click through the intro/hero-selection screen (query the button's live `AbsolutePosition` via `execute_luau` on the `Client` datamodel first — this session's testing has repeatedly found the viewport/button coordinates drift between sessions, don't assume prior coordinates still apply) and select "Reforge Hero (Start Anew)" instead of "Enter Realm".

- [ ] **Step 6: Confirm the test loadout took effect**

Call `execute_luau` with `datamodel_type: "Client"`:
```lua
local player = game:GetService("Players").LocalPlayer
local hud = player.PlayerGui:WaitForChild("HUD")
local names = {}
for i = 1, 4 do
	local frame = hud:FindFirstChild("SkillSlot_" .. i, true)
	local nameLabel = frame and frame:FindFirstChild("NamePlate", true)
	nameLabel = nameLabel and nameLabel:FindFirstChildWhichIsA("TextLabel")
	table.insert(names, nameLabel and nameLabel.Text or "?")
end
return table.concat(names, " | ")
```
Expected: four non-empty skill names corresponding to Taunt, ProvokingStrike, Earthshaker, Frostbolt (exact display text/order may vary slightly — just confirm none are blank/"EQUIP").

- [ ] **Step 7: Position near a live enemy and test each skill**

Find the trash mob (`search_game_tree`, `datamodel_type: "Server"`, `keywords: "Minion"` or check `Workspace` for a mob model) and its `HpFill` bar path (same technique used in this session's earlier verification passes: `Workspace.<MobName>.Body.MobHP.HpContainer.HpFill`, `Size.X.Scale`). Teleport the player's `HumanoidRootPart` within ~10 studs of it via `execute_luau` (`datamodel_type: "Server"`).

For each of the four skills, query the `HpFill.Size.X.Scale` before, trigger the skill (click its hotbar slot — query its `AbsolutePosition` fresh each time, same drift caveat as Step 5), wait ~1s, and query `HpFill.Size.X.Scale` after:
- **Taunt**: won't change HP (it's a taunt, not damage) — instead confirm via `get_console_output`/no errors, and optionally check the mob's `onTaunted` visual (a floating "[Taunted!]" label, per `MonsterAIService`) if visible in a screenshot.
- **ProvokingStrike**: HP should drop immediately (18 damage's worth of `Size.X.Scale`, scaled to `MOB_MAX_HEALTH`).
- **Earthshaker**: HP should drop immediately (AoE hit).
- **Frostbolt**: HP should drop immediately on cast, **and then drop further roughly 1.5s, 3s, and 4.5s later** without any additional cast — this is the part that specifically proves the new `dotDamage` tick scheduling works, not just the instant-hit portion. Poll `HpFill.Size.X.Scale` a few times over that ~5s window.

If the mob dies partway through this sequence (likely, given four skills' worth of damage against `MOB_MAX_HEALTH = 20`), that's fine — a `Destroy()`'d mob mid-sequence still proves each skill that landed before death dealt damage; note in your report which skills got a live hit before the mob died and don't force a respawn just to test the remaining ones if the ones tested already cover the intended dispatch branches.

- [ ] **Step 8: Stop Play and revert the temporary `PlayerDataService.lua` change**

Call `start_stop_play` with `is_start: false`. Revert `DEFAULT_DATA.Character`'s `UnlockedSkills`/`EquippedSkills` back to:
```lua
		UnlockedSkills = {"Taunt"},
		EquippedSkills = {"Taunt"},
```
Run:
```bash
git diff "Soulforge/src/ServerScriptService/Services/PlayerDataService.lua"
```
Expected: no output, or only pre-existing unrelated changes if that file already had uncommitted changes before this task started (check `git status` first) — confirm the `UnlockedSkills`/`EquippedSkills` lines specifically show no net change.

- [ ] **Step 9: Commit**

```bash
git add "Soulforge/src/ReplicatedStorage/Shared/Data/Skills.lua" "Soulforge/src/ReplicatedStorage/Shared/Data/Classes.lua" "Soulforge/src/ServerScriptService/Services/CombatService.lua"
git commit -m "$(cat <<'EOF'
Add Mage class kit and generalize skill-effect dispatch

CombatService.onCastSkill resolved every skill's behavior through a
hardcoded if/elseif chain keyed on exact skill name. Adds an
effectType field to every skill in Skills.lua (tauntAoe, damage,
aoeDamage, selfHeal, dotDamage, aoeDotDamage) and dispatches on that
instead -- Tank's existing skills are relabeled with no behavior
change, and two new effect types (dotDamage/aoeDotDamage, with a small
task.delay-based tick scheduler) back the new Mage kit: Classes.Mage
(80 HP, Pyromancy burst damage / Frostweave damage-over-time). Not yet
reachable through character creation or the skill tree UI, both of
which still hardcode Tank -- that's sub-project 2.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Notes for whoever executes this plan

- Tasks 1 and 2 (`Skills.lua`, `Classes.lua`) are pure data and independent of each other. Task 3 (`CombatService.lua`) references skill data by `effectType`/`tauntsOnHit`/`dotTicks`/etc. field names, which only need to exist conceptually (Lua doesn't require the referencing code to land after the data) — but Task 4's live verification needs all three done first.
- If Step 7's mob-teleport-and-click testing proves too slow/flaky (this session's history shows viewport coordinates and click timing can be inconsistent), the most important single check is Frostbolt's delayed ticks — that's the only genuinely new runtime mechanic (everything else is a relabeled copy of previously-working code). Prioritize getting that one clean observation if time is short.
