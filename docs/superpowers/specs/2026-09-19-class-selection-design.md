# Class Selection: Character Creation & Class-Driven Skill Tree

**Date:** 2026-09-19
**Status:** Approved

This is sub-project 2a of adding a second playable class (see [2026-09-18-mage-class-design.md](2026-09-18-mage-class-design.md) for sub-project 1, which added the Mage's data and combat-side effect dispatch but explicitly left class selection out of scope). This spec makes the Mage actually reachable through play: a real class picker in character creation, plus every hardcoded `Classes.Tank` site generalized to use the player's actual class. Mage-specific weapon/spell visuals remain a separate, later sub-project.

## Problem

`ClassId` is set to `"Tank"` unconditionally in three places server-side (first-time creation, Studio auto-load, and reforge-after-delete) and is never sent to the client at all. `SkillTreeUIController` hardcodes `local tankData = Classes.Tank` at two call sites, plus a hardcoded `BRANCH_ORDER = {"Bulwark", "Juggernaut"}` list and a mobile-view default of `activeMobileBranch = "Bulwark"`, because the client currently has no way of knowing the player's actual class. `DungeonSessionService`'s spawn-health lookup does the same (`local classData = Classes.Tank`). The character-creation screen shows one fixed "Tank Archetype" card, and its EMBARK button fires `SubmitCharacterCreation()` with no arguments — there is no in-game path to becoming a Mage; it's reachable only via a manual dev override on a test profile.

## Design

### 1. Network: `ClassId` reaches the client

- `CharacterDataChanged` gains a third parameter: `(Level, UnspentEXP, ClassId)`. The single existing fire site, `fireCharacterDataChanged` in `CharacterCreationService.lua`, sends it — no new event needed.
- `SubmitCharacterCreation:FireServer()` becomes `SubmitCharacterCreation:FireServer(classId: string)`.
- `RequestCreateNewCharacter:FireServer()` becomes `RequestCreateNewCharacter:FireServer(classId: string)`.
- Server-side validation: `onSubmitCharacterCreation` and `onRequestCreateNewCharacter` both look up `Classes[classId]`; if it's `nil` (unrecognized or tampered client), fall back to `"Tank"` rather than rejecting the request outright. This matches the codebase's existing "clamp to a safe default" style (e.g. skill-unlock validation in `CombatService`) instead of adding a new rejection/error path for a case the real UI can never actually produce.

### 2. Character-creation UI: two selectable class cards

- The existing single "Tank Archetype Showcase Card" is replaced by two cards shown side by side (Tank, Mage), each rendering that class's name/description/traits pulled from `Classes.lua`. Mage's three trait lines mirror Tank's existing three (`createTraitItem` calls): standard attack, starting skill (Arcane Bolt), and its two branches (Pyromancy/Frostweave) in place of Tank's Juggernaut/Bulwark line.
- Clicking a card selects it — gold-stroke highlight on the selected card, unselected card dims to its resting style. This reuses the same selected/unselected visual language `SkillTreeUIController`'s branch tabs already use elsewhere in this codebase. Default selection on screen open: Tank, so a player who clicks straight through without touching the picker gets exactly today's behavior.
- EMBARK fires `SubmitCharacterCreation:FireServer(selectedClassId)`.
- The "REFORGE HERO?" warning modal's confirm button no longer fires `RequestCreateNewCharacter` directly. Instead, confirming the warning shows this same two-card picker screen; a state flag records that this screen was reached via reforge, so its EMBARK button fires `RequestCreateNewCharacter:FireServer(selectedClassId)` instead of `SubmitCharacterCreation`. One picker screen, two possible outbound remotes depending on which flow navigated to it.

### 3. Server-side class lookups generalized

- `DungeonSessionService.lua`: `local classData = Classes.Tank` becomes `local classData = Classes[profile.Data.Character.ClassId] or Classes.Tank`.
- `CharacterCreationService.lua`'s two real handlers (`onSubmitCharacterCreation`, `onRequestCreateNewCharacter`) use the validated `classId` argument from section 1 instead of the literal `"Tank"`.
- The Studio-auto-load path (`RunService:IsStudio()` shortcut, which skips all UI) keeps `ClassId = "Tank"` as a literal — it has no picker to source a class from and is a dev-only convenience, not part of the real flow.
- `PlayerDataService.lua`'s `DEFAULT_DATA.Character.ClassId = "Tank"` is unchanged: it's only ever read before `HasCreatedCharacter` is set, and every real path through creation now overwrites it with a validated class before that flag flips.

### 4. `SkillTreeUIController.lua` becomes class-driven

- The two `local tankData = Classes.Tank` sites become `Classes[classId]`, where `classId` is read from the `ClassId` now delivered by `CharacterDataChanged` (cached the same way `Level`/`UnspentEXP` already are).
- `BRANCH_ORDER` (currently the single hardcoded `{"Bulwark", "Juggernaut"}`) becomes a per-class lookup table, since Lua doesn't guarantee key order for iterating `Classes[classId].branches` directly:
  ```lua
  local BRANCH_ORDER_BY_CLASS = {
      Tank = {"Bulwark", "Juggernaut"},
      Mage = {"Pyromancy", "Frostweave"},
  }
  ```
- `BRANCH_COLORS` gains `Pyromancy` and `Frostweave` entries, same shape as the existing `Bulwark`/`Juggernaut` entries (fire-orange and ice-blue respectively, matching the existing style's primary/secondary/bg/cardBg/border/accent/name/displayName/tagline fields).
- `activeMobileBranch`'s hardcoded default (`"Bulwark"`) becomes derived from the player's actual class's first branch (`BRANCH_ORDER_BY_CLASS[classId][1]`) once `ClassId` is known, instead of a literal that would silently mismatch for a Mage (whose branches are Pyromancy/Frostweave, not Bulwark).

## Constraints

- No new visual/weapon identity for the Mage in this spec — still out of scope, tracked as its own future sub-project (spell VFX/animations for the 7 Mage skills, analogous to the Tank VFX pass already done).
- This spec does not touch `GuardStance`/`FortressAura`'s already-broken no-op buff behavior, or any balance tuning.
- No classes beyond Tank/Mage are introduced or planned for here.

## Out of scope

- Mage-specific weapon/spell visuals and animations (separate sub-project).
- Fixing `GuardStance`/`FortressAura`.
- Any additional playable classes.
- Balance tuning of Mage's flat placeholder numbers (per sub-project 1's own stated scope).
