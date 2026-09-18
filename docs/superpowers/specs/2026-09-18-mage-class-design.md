# Mage Class: Kit + Generalized Skill-Effect Resolution

**Date:** 2026-09-18
**Status:** Approved

This is sub-project 1 of adding a second playable class. It covers the Mage's data (class + skills) and the combat-side generalization needed to resolve its effects. Sub-project 2 (class selection at character creation, and making `SkillTreeUIController` render whichever class the player actually has instead of hardcoding `Classes.Tank`) is out of scope here — this spec's Mage is reachable only via a dev shortcut (directly setting a test profile's `ClassId`), not through any in-game UI yet.

## Problem

`CombatService.onCastSkill` resolves what a skill actually *does* through a hardcoded if/elseif chain keyed on the exact skill name (`"Taunt"`, `"Earthshaker"`, `"IronWill"`, else a generic single-target-damage fallback). This means every new skill effect requires adding another named special case to that function — it doesn't generalize. `GuardStance` and `FortressAura` (Tank's own damage-reduction buffs) are already unhandled by any branch, so casting them currently does nothing.

Adding a Mage class needs two new kinds of effect this chain doesn't support at all: AoE damage that isn't specifically `"Earthshaker"`, and damage-over-time (a follow-up damage tick some time after the initial cast). Bolting these on as more named special cases would make the function worse in the same way it already is for Tank.

## Design

### 1. Data-driven effect dispatch in `CombatService`

Add an `effectType` field to every entry in [Skills.lua](../../../src/ReplicatedStorage/Shared/Data/Skills.lua), and have `onCastSkill` dispatch on `skill.effectType` instead of `skillId`. Existing Tank skills get relabeled with **no behavior change**:

| Skill | `effectType` |
|---|---|
| Taunt | `tauntAoe` (existing AoE-taunt behavior) |
| ProvokingStrike, ShieldBash | `damage` (existing single-target damage, with `ProvokingStrike`'s taunt-on-hit special case preserved — it's the only skill besides `Taunt` that taunts) |
| Earthshaker | `aoeDamage` (existing AoE-damage behavior, generalized from being Earthshaker-specific) |
| IronWill | `selfHeal` (existing self-heal behavior) |
| GuardStance, FortressAura | `buffSelf` / `buffParty` respectively — **no dispatch handler is added for these in this spec**; casting them remains a no-op, identical to today. Explicitly out of scope (see below) — labeling them honestly is a side effect of the refactor, not a fix. |

Two new `effectType`s get real handlers, used by the Mage kit below:
- `aoeDamage` (already needed for Earthshaker's generalization, reused by Mage's `Meteor`): damages every registered enemy within `skill.range` of the caster, same radius/iteration pattern `onCastSkill`'s existing Earthshaker branch already uses.
- `dotDamage` / `aoeDotDamage`: applies `skill.damage` (or AoE damage to all enemies in range, for the `aoe` variant) immediately, exactly like `damage`/`aoeDamage`, and additionally schedules `skill.dotTicks` follow-up hits of `skill.dotTickDamage` each, `skill.dotInterval` seconds apart, via a small helper (`task.delay`-based, one delay per tick — no new tracking table needed). Each tick calls the same `enemy.onDamaged(amount, player)` path a normal hit uses; if the target is already dead by the time a tick fires, `onDamaged`'s existing `if not alive then return end` guard (already present in both `MonsterAIService` and `BossAIService`) makes it a safe no-op. Multiple DoTs on the same target run independently — no stacking/refresh logic, ticks from different casts just both fire on their own schedules. This is a deliberate simplification for this slice, not an oversight.

### 2. `Classes.Mage`

Added to [Classes.lua](../../../src/ReplicatedStorage/Shared/Data/Classes.lua), same shape as `Classes.Tank`:
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
```

### 3. Mage skills

Added to `Skills.lua`, matching the existing schema (`id`, `displayName`, `branch`, `tier`, `prerequisite`, `icon`, `cooldown`, `range`, `damage`, `description`, plus the new `effectType` and, for DoT skills, `dotTickDamage`/`dotTicks`/`dotInterval`):

| Skill | Branch | Tier | Prereq | Cooldown | Range | Damage | `effectType` | DoT |
|---|---|---|---|---|---|---|---|---|
| ArcaneBolt | Base | 0 | — | 3s | 30 | 10 | `damage` | — |
| Firebolt | Pyromancy | 1 | — | 5s | 25 | 18 | `damage` | — |
| Fireball | Pyromancy | 2 | Firebolt | 9s | 25 | 26 | `damage` | — |
| Meteor | Pyromancy | 3 | Fireball | 16s | 20 | 30 | `aoeDamage` | — |
| Frostbolt | Frostweave | 1 | — | 5s | 25 | 10 | `dotDamage` | 3 ticks × 3 dmg, 1.5s apart |
| IceLance | Frostweave | 2 | Frostbolt | 9s | 25 | 14 | `dotDamage` | 3 ticks × 4 dmg, 1.5s apart |
| Blizzard | Frostweave | 3 | IceLance | 16s | 20 | 16 | `aoeDotDamage` | 3 ticks × 4 dmg, 1.5s apart |

`icon` fields follow the existing convention (`rbxasset://textures/Soulforge/<skill_name>_icon.png`) even though, per the existing codebase's own pattern, no actual icon asset needs to exist yet for the skill tree UI to function (it just shows blank/fallback).

### Constraints

- `DungeonSessionService.lua`'s `hookPlayerDeath` currently hardcodes `local classData = Classes.Tank` to set spawn health — this spec does **not** change that (it's part of sub-project 2's "make things actually class-driven" work). A Mage test character, spawned via the dev shortcut, will still get Tank's 150 health until that lookup is generalized. Noted here so it isn't mistaken for a bug in this spec's own scope.
- No new visual/weapon identity for the Mage (staff, spell VFX, etc.) — `WeaponService` still equips the Tank's sword+shield regardless of class. Out of scope.

## Out of scope

- Class selection UI, and generalizing the 5 hardcoded `"Tank"` sites (`PlayerDataService` default, `CharacterCreationService`'s three assignment sites, `DungeonSessionService`'s health lookup) — sub-project 2.
- `SkillTreeUIController` rendering the player's actual class instead of hardcoded `Classes.Tank` / a `BRANCH_COLORS` table keyed only to Juggernaut/Bulwark — sub-project 2.
- Fixing `GuardStance`/`FortressAura`'s already-broken buff behavior.
- Any real slow/freeze crowd control (Frostweave is damage-over-time only, per your answer).
- Mage-specific weapon/visual identity.
- Any balance tuning beyond the flat placeholder numbers above — matches the existing codebase's own stated "flat value for this slice" philosophy.
