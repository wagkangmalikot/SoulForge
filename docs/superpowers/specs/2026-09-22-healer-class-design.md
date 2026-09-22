# Healer Class: Kit, Ally Targeting & Heal Dispatch (Phase 1)

**Date:** 2026-09-22
**Status:** Approved

This is Phase 1 of adding a third playable class, Healer — a pure-support class with no damage skills. It covers the Healer's data (class + skills), the two new combat `effectType`s needed to heal allies instead of only self/enemies, a new ally-targeting system (nothing today lets a player target another player at all), and both of the Healer's gear sets (starter + Rockhide tier) as real items with stats and a set bonus.

Phase 2 (a separate future spec) covers bespoke 3D visuals for the Healer's weapon and armor — this phase renders Healer gear with the existing staff/robe/hood/bracers/boots procedural models (the same ones `ApprenticeStaff`/`RockhideStaff` and the rest of the Apprentice/RockhideMage sets already use), the same way `RockhideStaff` reuses staff geometry today. This is a deliberate scope cut, not an oversight — see [Constraints](#constraints).

## Problem

`CombatService.onCastSkill` can only ever affect the caster (`selfHeal`) or an enemy (`damage`, `dotDamage`, `aoeDamage`, `aoeDotDamage`, `tauntAoe`) — there is no code path anywhere that resolves a *player* as a skill's target. Client-side, `HUDController`'s click-to-target system (`selectTarget`/`findTaggedEnemyAncestor`) only recognizes models tagged `"Enemy"` via `CollectionService`; it has no notion of selecting another player's character at all.

Every "which class is this" branch point in the codebase is currently a binary `isMage` boolean (`WeaponService.EquipWeapons`/`.Start`, `CharacterCreationService.setupInitialEquipment`, `HUDController.updateClassVisuals`, `ItemIconHelper.CreateItemIcon`, `CharacterCreationController`'s two-card picker), which doesn't extend to a third class without becoming three-way `classId`-driven.

## Design

### 1. `Classes.Healer`

Added to [Classes.lua](../../../src/ReplicatedStorage/Shared/Data/Classes.lua), same shape as `Tank`/`Mage`:

```lua
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
```

`baseHealth = 90` sits between Mage's 80 and Tank's 150 — a squishy support that relies on staying out of melee range and healing itself/others rather than tanking hits.

### 2. Two new `effectType`s: `healTarget` and `aoeHeal`

Added to `CombatService.onCastSkill`'s dispatch (alongside the existing `damage`/`aoeDamage`/`selfHeal`/etc. branches), both added to the existing `isAoeOrSelf` set (`aoeHeal` needs no target; `healTarget` does, like `damage`):

- **`healTarget`**: resolves `targetId` to a `Player` (see §3), verifies the target is the caster themself or a member of the caster's party (`PartyService.GetParty(caster)`, checked against `party.members`), then restores `skill.healAmount` to that player's `Humanoid.Health` (clamped to `MaxHealth`) and fires `Net.Get("HealthChanged")` for that player, exactly like `selfHeal` does for the caster today. If the caster isn't in a party, only self-targeting resolves — no behavior for a lone player pointing this at a stranger.
- **`aoeHeal`**: heals every party member (caster included) within `skill.range` of the caster by `skill.healAmount`, same iteration shape `aoeDamage` already uses over the `enemies` table but iterating `party.members` (resolved to `Player` instances via `Players:GetPlayerByUserId`) instead. If the caster isn't in a party, this heals only the caster (degrades to a self-heal, not a no-op) — consistent with `healTarget`'s solo behavior above.

No heal-over-time ticks in this phase — every Healer skill is an instant heal. Adding a "HoT on a player" tick system analogous to `applyDotTicks` (which only knows how to tick an `enemy` handle, not a `Player`) is real but bounded work, deliberately deferred (see Constraints).

### 3. Ally targeting (new)

Client (`HUDController.lua`): the existing click-raycast (`TARGET_RAYCAST_DISTANCE`) that currently only walks up to a `CollectionService`-tagged `"Enemy"` ancestor via `findTaggedEnemyAncestor` gains a second check — if the clicked model isn't a tagged enemy, check `Players:GetPlayerFromCharacter(model)`. If that resolves to a player, select them the same way `selectTarget` already selects an enemy (same `Highlight` outline, same `selectedTargetId`), just using a distinguishable target id so the server can tell "this is a player" from "this is an enemy" without a lookup: player targets are sent as `"player:" .. tostring(player.UserId)`, enemy targets keep their existing bare ids. Casting a skill (`Net.Get("CastSkill"):FireServer(skillId, selectedTargetId)`) is otherwise unchanged.

Server (`CombatService.lua`): a small helper resolves a `targetId` to either an enemy handle or a `Player`:

```lua
local function resolvePlayerTarget(targetId: string?): Player?
	if not targetId or not targetId:match("^player:") then return nil end
	local userId = tonumber(targetId:match("^player:(%d+)$"))
	return userId and Players:GetPlayerByUserId(userId) or nil
end
```

`onCastSkill`'s existing range/enemy-resolution block only applies to non-AoE, non-self skills; `healTarget` follows the same shape but resolves via `resolvePlayerTarget` instead of the `enemies` table, and range-checks against the target player's `HumanoidRootPart` instead of an enemy model's.

Self-targeting (healing yourself with `healTarget`) works by clicking your own character, same as any other party member — no special-cased "no target selected" fallback in this phase.

### 4. Skills

Added to [Skills.lua](../../../src/ReplicatedStorage/Shared/Data/Skills.lua), matching the existing schema (`healAmount` is the heal-equivalent of `damage`, already an established field name from `IronWill`):

| Skill | Branch | Tier | Prereq | Cooldown | Range | Heal | `effectType` |
|---|---|---|---|---|---|---|---|
| Mend | Base | 0 | — | 4s | 30 | 18 | `healTarget` |
| SoothingLight | Mending | 1 | — | 5s | 30 | 22 | `healTarget` |
| RadiantMend | Mending | 2 | SoothingLight | 9s | 30 | 34 | `healTarget` |
| DivineRestoration | Mending | 3 | RadiantMend | 16s | 30 | 55 | `healTarget` |
| SacredCircle | Sanctuary | 1 | — | 8s | 16 | 14 | `aoeHeal` |
| HealingRain | Sanctuary | 2 | SacredCircle | 14s | 18 | 20 | `aoeHeal` |
| Sanctuary | Sanctuary | 3 | HealingRain | 24s | 20 | 32 | `aoeHeal` |

`icon` fields follow the existing `rbxasset://textures/Soulforge/<skill_name>_icon.png` convention (no actual icon asset needs to exist for the skill tree UI to function, matching the Mage spec's own note on this).

### 5. Gear: `Sanctum` (starter) and `RockhideHealer` (tier 2) sets

Added to [Equipment.lua](../../../src/ReplicatedStorage/Shared/Data/Equipment.lua), same shape as `Apprentice`/`RockhideMage`. Both sets are visually the existing staff/hood/robe/bracers/boots procedural models (Phase 2 gives them their own silhouette) — see §6 for the dispatch-flag changes that make that render correctly.

**Sanctum** (tier 1, starter, not craftable, no set bonus — matches `Standard`/`Apprentice`'s own "no bonus for starter gear" pattern):

| Item | Slot | Stats |
|---|---|---|
| BlessedScepter | Weapon | `magicDamage = 11, attackSpeed = 1.0, criticalChance = 0.05, attackRange = 35` |
| SanctumHood | Head | `armor = 2, magicResist = 5, maxHPBonus = 8` |
| SanctumRobe | Body | `armor = 4, magicResist = 8, maxHPBonus = 15` |
| SanctumBracers | Arms | `armor = 2, magicResist = 4, spellAmp = 0.05` |
| SanctumBoots | Feet | `armor = 2, magicResist = 3, movementSpeed = 0` |

(Weapon's `magicDamage` is intentionally lower than `ApprenticeStaff`'s 14 — the Healer's normal attack is a minor utility, not its identity; `maxHPBonus` numbers run a little above Apprentice's equivalents to partly offset the class's lower `baseHealth`.)

**RockhideHealer** (tier 2, craftable, `bossOrigin = "Rockhide"`, same `RockhideFragment`-driven material shape as `Rockhide`/`RockhideMage`):

| Item | Slot | Stats | Crafting materials |
|---|---|---|---|
| RockhideStaffOfMercy | Weapon | `magicDamage = 22, attackSpeed = 0.95, criticalChance = 0.10, attackRange = 35, bonusHealingUnder50Pct = 0.20` | `RockhideFragment 8, OakTimber 4, LeatherStrap 2` |
| RockhideSanctumCowl | Head | `armor = 5, magicResist = 12, maxHPBonus = 18` | `RockhideFragment 4, LeatherStrap 3, OakTimber 2` |
| RockhideSanctumVestments | Body | `armor = 9, magicResist = 18, maxHPBonus = 30` | `RockhideFragment 10, LeatherStrap 5, IronIngot 2` |
| RockhideMercyWraps | Arms | `armor = 4, magicResist = 8, spellAmp = 0.10` | `RockhideFragment 3, LeatherStrap 3, IronIngot 1` |
| RockhideSanctumTreads | Feet | `armor = 5, magicResist = 7, movementSpeed = 1` | `RockhideFragment 3, LeatherStrap 4, OakTimber 1` |

Set bonus **"Earthen Blessing": +20% healing output when the target's HP is below 50%** — same "+20% under a 50% HP threshold" shape as `Rockhide`'s Seismic Fury and `RockhideMage`'s Geomantic Surge, but keyed to the *heal target's* HP rather than the caster's, since a healer being low isn't when their heals should matter most — the ally they're saving is. This needs its own check in `CombatService` (a `getHealMultiplier(caster, targetPlayer)` alongside the existing `getDamageMultiplier(player)`), checked against `RockhideHealer`'s set-active state via `EquipmentData.IsSetBonusActive("RockhideHealer", ...)`, applied in the `healTarget`/`aoeHeal` branches the same way `getDamageMultiplier` is applied in the damage branches today.

### 6. Generalizing the `isMage`-style boolean checks

Each of the following becomes 3-way `classId`-aware instead of a binary Mage/not-Mage flag. None of these are redesigns — each site already reads `charData.ClassId` or an equivalent, it just branches on `== "Mage"` instead of switching on the value:

- **`WeaponService.lua`**: `createWeaponModel`/`createShieldModel`'s "is this a staff-style weapon" checks (currently `weaponId == "ApprenticeStaff" or weaponId == "RockhideStaff"`) add `BlessedScepter`/`RockhideStaffOfMercy`, rendering with the existing staff models per this phase's scope. The scattered `isMage and "ApprenticeStaff" or "StandardSword"` default-weapon fallbacks (`EquipWeapons`, `Start`) become a small `DEFAULT_WEAPON_BY_CLASS` table keyed by `classId` (`Tank = "StandardSword"`, `Mage = "ApprenticeStaff"`, `Healer = "BlessedScepter"`).
- **`CharacterCreationService.lua`**: `setupInitialEquipment(profile, classId)`'s `if classId == "Mage" then ... else ...` (the `else` branch is Tank's gear today) gains a third `elseif classId == "Healer" then` branch granting the Sanctum set + both Rockhide-tier pieces in `StoredEquipment`, matching Tank/Mage's existing pattern of starting with their own tier-1 set equipped and their own tier-2 set already in the bag.
- **`HUDController.lua`**: `updateClassVisuals`'s `isMage` boolean (driving the class badge icon/attack icon/title string) becomes a small per-class lookup table (icon, attack icon, title), same shape as `SkillTreeUIController`'s existing `CLASS_TITLE_INFO`.
- **`ItemIconHelper.lua`**: `CreateItemIcon`'s `isMage`/`isRockhide` flags (`setId == "Apprentice" or setId == "RockhideMage"`, `setId == "Rockhide" or setId == "RockhideMage"`) add `Sanctum`/`RockhideHealer` to the respective checks, so Healer gear renders with the staff/hood/robe/bracers/boots graphic and the Rockhide-tier recolor, matching §5's "reuse existing visuals" scope.
- **`CharacterCreationController.lua`**: the two `createClassCard` calls (`tankCard` at `x=0, width=0.485`, `mageCard` at `x=0.515, width=0.485`) become three cards at roughly `x=0/0.345/0.69, width=0.31` each (with proportionally smaller gaps), plus a third `healerCard`/`healerCardStroke`/`healerCardHitbox` following the exact same selection/highlight logic as the other two. `selectedClassId`'s default stays `"Mage"` (unchanged from today) — this spec doesn't change what a player sees by default, just adds the third choice.
- **`SkillTreeUIController.lua`**: `BRANCH_ORDER_BY_CLASS` gains `Healer = {"Mending", "Sanctuary"}`; `CLASS_TITLE_INFO` gains `Healer = { icon = "✨", name = "HEALER" }`; `BRANCH_COLORS` gains `Mending` and `Sanctuary` entries (new color pairs — soft gold/white for Mending, green/white for Sanctuary, following the existing primary/secondary/bg/cardBg/border/accent/icon/name/displayName/tagline shape each existing branch entry has).

## Constraints

- **No Phase 2 visuals yet** — Healer gear renders with the existing staff/hood/robe/bracers/boots procedural models, not a bespoke silhouette. Tracked as a separate future spec once this phase is proven out in play.
- **No heal-over-time** — every Healer skill is an instant heal; a HoT-on-a-player system (parallel to `applyDotTicks`, which only knows how to tick an `enemy` handle today) is out of scope for this phase.
- **No shield/absorb mechanic** — "Sanctuary" (the tier-3 Sanctuary-branch ultimate) is a big instant AoE heal, not a damage-absorb shield, despite the name evoking one. A real shield mechanic would need new Humanoid-side bookkeeping (absorbed-damage tracking) this spec doesn't add.
- Does not touch `GuardStance`/`FortressAura`'s already-broken no-op buff behavior (pre-existing, unrelated to this class).
- No balance tuning beyond the flat placeholder numbers above, matching the existing codebase's own "flat value for this slice" philosophy (per the Mage spec).

## Out of scope

- Bespoke 3D weapon/armor visuals for the Healer (Phase 2, separate spec).
- Heal-over-time skills/mechanic.
- Damage-absorb shields.
- Any damage skills for Healer — this is a pure-support kit by design, not a temporary gap.
- Fixing `GuardStance`/`FortressAura`.
- Balance tuning.
