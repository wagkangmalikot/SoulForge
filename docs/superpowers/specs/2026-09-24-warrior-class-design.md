# Warrior Class & Tank Rework: Splitting Offense Out of Tank

**Date:** 2026-09-24
**Status:** Approved

This adds a fourth playable class, Warrior — melee DPS, distinct from Tank — by relocating Tank's existing offense-flavored `Juggernaut` branch to it, and gives Tank a new pure-defense branch to replace what it lost. This is the split the project's own original design doc called for from the start — commit `94548aa` ("Add starting class roster: Tank, Healer, Mage, Warrior", 2026-09-14, section 2a) specced a four-class roster, with Warrior explicitly described as "melee DPS, distinct from Tank" — but the actual implementation only ever shipped Tank and Mage, with Tank absorbing what should have been Warrior's offensive identity. (That original spec file no longer exists in the current tree — it's only recoverable via `git show 94548aa:docs/superpowers/specs/2026-09-14-roblox-coop-dungeon-design.md` — so it's cited here by commit rather than linked.) Healer has since been built on its own branch (`feature/healer-class`, not yet merged into `main`); this spec is independent of that work and targets current `main` directly.

## Problem

`Classes.Tank` has two branches: `Bulwark` (defense: GuardStance, IronWill, FortressAura) and `Juggernaut` (offense: ProvokingStrike, ShieldBash, Earthshaker — heavy strikes and AoE crowd control with no defensive identity at all). A player who wants a pure damage-dealing melee fighter has to pick "Tank" and spec into Juggernaut, which is confusing (the class is named for a role its own skill tree half-contradicts) and leaves no separate niche for a class that's *only* about offense. Every class/gear-visual/UI touchpoint in this codebase is currently a binary Tank-vs-Mage check (`isMage` booleans throughout `HUDController.lua`, `CharacterCreationController.lua`, `WeaponService.lua`, etc.) — the same shape of gap the Healer spec already worked through for a caster-style third class, but Warrior is the *non-caster* case: it shares Tank's gear, weapon visuals, and normal-attack behavior almost entirely, needing far less new plumbing than Healer did.

## Design

### 1. `Classes.lua`: Warrior added, Tank's `Juggernaut` replaced

`Juggernaut` moves from `Tank.branches` to a new `Warrior` class entry, unchanged in content and skill numbers except one field (see §3). Tank gains a new `Sentinel` branch in its place:

```lua
Tank = {
	name = "Tank",
	baseHealth = 150,
	startingSkills = {"Taunt"},
	branches = {
		Bulwark = { ... unchanged ... },
		Sentinel = {
			name = "Sentinel",
			description = "Pure threat and mitigation -- single-target and AoE taunts backed by a defender's strike, not a damage dealer's.",
			skills = {"ShieldSlam", "AegisSlam", "GuardiansWrath"},
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
```

`baseHealth = 120` sits between Mage's 90 and Tank's 150 — melee-adjacent durability without Tank's frontline tankiness.

### 2. New skills (all reuse existing, already-working `effectType`s — no `CombatService` dispatch changes needed)

| Skill | Class/Branch | Tier | Prereq | Cooldown | Range | Damage | `effectType` | Notes |
|---|---|---|---|---|---|---|---|---|
| Cleave | Warrior/Base | 0 | — | 4s | 12 | 12 | `damage` | Starter — plain strike, no gimmick |
| ShieldSlam | Tank/Sentinel | 1 | — | 5s | 14 | 10 | `damage` | `tauntsOnHit = true` — replaces the single-target threat tool Tank loses when ProvokingStrike leaves |
| AegisSlam | Tank/Sentinel | 2 | ShieldSlam | 12s | 16 | 14 | `aoeDamage` | Replaces the AoE threat tool Tank loses when Earthshaker leaves |
| GuardiansWrath | Tank/Sentinel | 3 | AegisSlam | 18s | 20 | 22 | `damage` | `tauntsOnHit = true` — capstone single-target burst+taunt |
| ReapingSlash | Warrior/Bloodlust | 1 | — | 4s | 12 | 16 | `damage` | |
| RagingCleave | Warrior/Bloodlust | 2 | ReapingSlash | 9s | 14 | 20 | `aoeDamage` | |
| Bloodbath | Warrior/Bloodlust | 3 | RagingCleave | 16s | 16 | 18 | `aoeDotDamage` | `dotTickDamage=5, dotTicks=3, dotInterval=1.5` — bleed |

Sentinel's numbers are deliberately modest (threat tools, not a damage kit) — Tank isn't meant to compete with Warrior's Bloodlust or Mage's Pyromancy on output. `ProvokingStrike`/`ShieldBash`/`Earthshaker` move to `Warrior` with every field unchanged **except** `ProvokingStrike.tauntsOnHit`, which is removed — Warrior is DPS, not a threat-holder, and generating bonus threat would actively work against a party (pulling aggro off the real Tank).

### 3. Gear: Warrior shares Tank's `Standard`/`Rockhide` sets, no shield

Warrior does not get its own item data. In [Equipment.lua](../../../src/ReplicatedStorage/Shared/Data/Equipment.lua), `Sets.Standard.classId` and `Sets.Rockhide.classId` change from the single string `"Tank"` to a list `{"Tank", "Warrior"}`. This is the only schema change needed:

- `Equipment.GetItemClass(itemId)` already just returns `setData.classId` — it becomes a `{string}` or `string`, so its one caller (`WeaponService`'s `RequestEquipEquipment` handler, which does `itemClass ~= playerClass`) needs to handle both shapes: `table.find(itemClass, playerClass)` when it's a table, direct comparison when it's a string. No other file reads `classId` off a `Sets` entry.
- `CharacterCreationService.setupInitialEquipment`'s `Warrior` branch is byte-identical to its existing `Tank`/`else` branch (same items: StandardSword, StandardHelm, StandardChest, StandardArms, StandardFeet, plus RockhideFang/RockhideHelm/RockhideChest/RockhideArms/RockhideFeet pre-stashed).
- **No shield for Warrior.** `WeaponService`'s shield-equip gate (currently `not isMage` — Mage is the only class that skips a shield today) becomes `classId ~= "Mage" and classId ~= "Warrior"`. `createShieldModel`'s own dispatch is untouched; it's simply never called for Warrior's `EquipWeapons` pass. Nothing else about the gear (icons, world-model weapon/armor visuals) needs a Warrior-specific case, since `ItemIconHelper` and `WeaponService`'s procedural model builders key off item/set id, not class id, and Warrior uses Tank's exact ids.

### 4. Cross-cutting `isMage`-style generalization (the same pattern as the Healer spec, smaller scope)

Every one of these already treats "not Mage" as "Tank-shaped" — for Warrior, that fallback is *already correct* for weapon/attack-animation purposes (non-caster, melee, `Slash` normal attack) and only needs a genuinely Warrior-specific branch where the class's own identity (title, card copy, skill-tree colors) is on screen:

- **`HUDController.lua`**: `updateClassVisuals`'s `isMage` boolean becomes a 3-way lookup (`Tank`/`Mage`/`Warrior`), each with its own `attackIcon`/`badgeIcon`/`title`. **Tank's title changes from `"WARRIOR TANK"` to `"SHIELD GUARDIAN"`** — keeping it as `"WARRIOR TANK"` once a real Warrior class exists would be actively confusing. Warrior's title: `"BATTLE WARRIOR"`, icon `⚔️` (Tank keeps `🛡️`, so the two don't share an icon). Same rename applies to the hardcoded `"WARRIOR TANK"` fallback string elsewhere in this file (the `playerNameLabel` default before any class data has loaded).
- **`CharacterCreationController.lua`**: `CLASS_CARD_INFO` gains a `Warrior` entry; the class-picker row becomes 3 cards (same layout-math change the Healer spec already made once — `xScale`/`widthScale` at ~0.315 each with small gaps). Tank's own card copy updates too: description drops "juggernaut" framing, `traits` becomes `Trees: Bulwark & Sentinel` instead of `Juggernaut & Bulwark`. `updateHeroChoiceCard`'s `isMage` binary becomes a 3-way `HERO_CHOICE_INFO` table (Tank's entry also updated to match its new kit: `chip2` becomes `🛡️ Shield Slam` / `Threat Tool` instead of `🛡️ Taunt` / `Threat Lock`, since Taunt is still the starter but the card's "signature skill" slot should reflect the new branch).
- **`SkillTreeUIController.lua`**: `BRANCH_ORDER_BY_CLASS` gains `Warrior = {"Juggernaut", "Bloodlust"}` and updates `Tank = {"Bulwark", "Sentinel"}` (was `{"Bulwark", "Juggernaut"}`); `CLASS_TITLE_INFO` gains `Warrior`; `BRANCH_COLORS` gains `Sentinel` and `Bloodlust` entries (new colors, distinct from the existing Bulwark/Juggernaut/Pyromancy/Frostweave/ArcaneMastery palette) — `Juggernaut`'s existing color entry is kept as-is and now renders under Warrior instead of Tank, which is correct since the branch itself didn't change, only its owner.
- **`WeaponService.lua`**: the existing `isMage`-driven default-equipment/shield-gate logic (§3) becomes 3-way; `CombatService.lua`'s own `isMage`-driven normal-attack dispatch (`local isMage = (charData.ClassId == "Mage")`, deciding `ArcaneBolt` vs `Slash` animation) needs **no change** — Warrior already falls into the `Slash` branch correctly since it isn't Mage and isn't a staff weapon.

### 5. `Equipment.GetItemClass` return-type change ripples

The one behavioral change from §3's `classId` list: `GetItemClass` can now return a table. Grep for every call site (currently just the one in `WeaponService.Start()`'s equip handler, and `CharacterCreationController.lua`'s badge logic does NOT call this — it only reads `profile.Data.Character.ClassId`, unrelated) and confirm each handles both shapes correctly before considering this done.

## Constraints

- No migration for existing characters who had `Juggernaut` skills unlocked while `ClassId == "Tank"` — this is Studio-only dev data (ProfileService running in mock/local mode, no live players), same accepted-limitation shape as the Healer spec's equivalent note.
- Does not touch the pre-existing `GuardStance`/`FortressAura` no-op buff behavior (`buffSelf`/`buffParty` are still unhandled in `CombatService`) — out of scope, unrelated to this split.
- Independent of the not-yet-merged `feature/healer-class` branch. This spec targets `main` as it stands today (Tank + Mage only); reconciling this work with Healer happens whenever that branch is merged, not here.
- No new bespoke visuals — Warrior renders with Tank's exact existing sword/armor procedural models, per §3.

## Out of scope

- Warrior-specific gear (a future phase, same shape as Healer's eventual bespoke-visuals phase, if ever wanted).
- Any balance pass reconciling Sentinel/Bloodlust's numbers against Mage's recently-buffed Pyromancy/Frostweave/ArcaneMastery curve — every number here is chosen to be internally consistent with the *pre-buff* Juggernaut numbers it's derived from, not the current top-of-curve Mage kit.
- Fixing `GuardStance`/`FortressAura`.
- Reconciling with the unmerged Healer branch.
