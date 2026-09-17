# Dungeon Raid Rewards: Fragments and Gold

**Date:** 2026-09-17
**Status:** Approved

## Problem

`DungeonSessionService.bankRewardsAndReturnToHub()` currently banks a flat EXP reward on victory only (`EXP_REWARD_ON_VICTORY = 50`, plus `MOB_EXP_REWARD = 5` per trash mob killed via `pendingMobEXP`) — a wipe banks zero EXP. There is no currency system at all (`PlayerDataService`'s `DEFAULT_DATA` has no `Gold` field), and no way to earn `Equipment.lua`'s crafting materials from actual gameplay — `CraftingMaterials` is only ever set to a fixed starting stock at profile creation.

The request: raids should award boss-specific crafting fragments and gold at the end of a run, with a failed raid (wipe) giving much less than a successful one (victory), matching and extending the reward pattern EXP already has.

## Design

### Reward amounts

All three reward types (EXP, fragments, gold) follow the same three-part structure: a victory base, a (smaller) wipe base, and a per-trash-mob-kill bonus that's credited **regardless of outcome** — killing a mob is real progress the player keeps even if the run ultimately wipes; only the flat completion bonus is contingent on victory.

| | Victory base | Wipe base | Per mob kill |
|---|---|---|---|
| EXP | 50 (unchanged) | 10 (new) | 5 (unchanged) |
| Fragments | 5 (new) | 1 (new) | 1 (new) |
| Gold | 25 (new) | 5 (new) | 5 (new) |

The wipe base is 20% of the victory base for all three (matches the fragment/gold ratio given: 1/5 = 5/25 = 20%; applied to EXP's existing 50 for consistency: 10).

This is a flat-value slice, matching `EXP_REWARD_ON_VICTORY`'s own existing comment ("flat value for this slice; real EXP formulas are a later plan") — no scaling by dungeon tier, player level, or party size. `MOB_POSITIONS` currently has exactly one trash mob spawn point, so in practice the per-mob bonus is small in absolute terms right now; the constants are still defined generally so they keep working if more mobs are added later.

### New data: `RockhideFragment` material

Added to [Equipment.lua](../../../src/ReplicatedStorage/Shared/Data/Equipment.lua)'s `Materials` table:
```lua
RockhideFragment = {
	id = "RockhideFragment",
	displayName = "Rockhide Fragment",
	tier = 3,
	rarity = "Rare",
	description = "A jagged shard of Rockhide's stone hide, still warm with residual seismic energy. Earned only by braving the boss chamber.",
	maxStack = 99,
},
```
Tier/rarity matches `SunstoneCore` (also tier 3 Rare) since it's tied to the current end-game boss. Unlike the tier-1 starter materials (`IronIngot`, `OakTimber`, `LeatherStrap`) and the pre-seeded tier-3 materials (`SunstoneCore`, `AncientRune`), `RockhideFragment` is **not** added to `PlayerDataService`'s starting `CraftingMaterials` — it's meant to be earned, so new profiles start at 0 (implicitly absent from the table; reward banking creates the key on first award).

### New data: `Character.Gold`

Added to `PlayerDataService`'s `DEFAULT_DATA.Character`:
```lua
Gold = 0,
```
With the same reconcile-fallback pattern already used for `CraftingMaterials`/`StoredEquipment`/etc. in `onPlayerAdded` (`if not charData.Gold then charData.Gold = 0 end` — note `Gold` needs a `nil`-check, not a truthiness-on-table-length check like the array fields, since `0` is a valid already-set value that must not be overwritten).

### Reward banking

`DungeonSessionService.lua` changes:
- New constants alongside the existing `EXP_REWARD_ON_VICTORY`/`MOB_EXP_REWARD`: `FRAGMENT_REWARD_ON_VICTORY = 5`, `FRAGMENT_REWARD_ON_WIPE = 1`, `MOB_FRAGMENT_REWARD = 1`, `GOLD_REWARD_ON_VICTORY = 25`, `GOLD_REWARD_ON_WIPE = 5`, `MOB_GOLD_REWARD = 5`, and `EXP_REWARD_ON_WIPE = 10` (the existing `EXP_REWARD_ON_VICTORY` stays as-is).
- `pendingMobEXP` (userId -> accumulated EXP from kills this run) gets two siblings following the exact same accumulation pattern: `pendingMobFragments` and `pendingMobGold`, both incremented in the same place `awardMobKillEXP` already runs (that function is renamed/expanded to award all three per kill, since it's the single callback `MonsterAIService.SpawnMobs` invokes on every trash mob kill — see `stopMobs = MonsterAIService.SpawnMobs(MOB_POSITIONS, awardMobKillEXP, ...)`).
- `bankRewardsAndReturnToHub(result)` changes from EXP-only, victory-only banking to: compute each of the three totals as `(result == "victory" and X_REWARD_ON_VICTORY or X_REWARD_ON_WIPE) + pendingMobX[player.UserId]`, for all three reward types, every run (both victory and wipe now bank something, matching the new wipe-gives-a-reduced-reward design). Fragments bank into `profile.Data.Character.CraftingMaterials.RockhideFragment` (increment, defaulting missing/nil to 0 first). Gold banks into `profile.Data.Character.Gold` (increment).

### Client display

`Net.lua`'s `DungeonResult` remote's payload comment and actual `FireClient` call both change from `(result, expEarned)` to `(result, expEarned, fragmentsEarned, goldEarned)`.

`DownedUIController.lua`'s `DungeonResult` handler (`resultLabel.Text = ...`) updates to show all three, e.g.:
```
VICTORY! +50 EXP, +5 Fragments, +25 Gold — returning to hub…
```
```
WIPED — +10 EXP, +1 Fragments, +5 Gold — returning to hub…
```
(Exact numbers shown are whatever `bankRewardsAndReturnToHub` actually computed and sent that run, including mob-kill bonuses — not the flat constants.)

## Out of scope

- No crafting UI or logic that spends `RockhideFragment`/`Gold`/other materials into actual equipment — `Equipment.lua`'s `crafting.materials` recipes are pre-existing data with no consuming system yet, and this spec doesn't add one.
- No persistent Gold or Fragment count display anywhere in the HUD outside the existing end-of-raid result screen (e.g. no gold counter in the corner of the main HUD).
- No scaling by dungeon tier, player level, or party size — flat values only, matching the existing EXP pattern's own stated scope.
- No changes to `SealBossGate`/`UnsealBossGate`/`OpenBossGate` or any other boss-gate/combat logic — this only touches the end-of-session reward banking path.
