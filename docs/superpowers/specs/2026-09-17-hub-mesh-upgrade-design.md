# Hub Design Upgrade: AI-Generated Mesh Dressing

**Date:** 2026-09-17
**Status:** Approved

## Problem

`HubMapService.lua` builds the entire Soulforge Outpost hub (fountain, dungeon portal, level-up shrine, training grounds, tavern, forge, gate towers) out of primitive `Part`s (blocks, cylinders) with flat colors and materials. By contrast, dungeon monsters use `ReplicatedStorage.Assets.TrashMobTemplate`, a sculpted `MeshPart` model produced by Roblox Studio's AI `generate_mesh` tool (segmented into `Head`/`Body`/`LeftArm`/`RightArm`/`LeftLeg`/`RightLeg`). The hub reads as visibly blockier/lower-fidelity than the monsters players fight. The hub needs sculpted mesh landmarks and props to close that visual gap.

## Constraints

- `RockhidePortal`, `LevelUpShrine`, `SpawnLocation`, and `TrainingDummy_1`/`TrainingDummy_2` are referenced **by name** elsewhere in the codebase:
  - [DungeonEntryService.lua:38](../../../src/ServerScriptService/Services/DungeonEntryService.lua) cleans up `HUB_ONLY_SCENERY = {"RockhidePortal", "LevelUpShrine", "SpawnLocation", "SoulforgeHub"}` by name on hub/dungeon transitions.
  - `CombatService.RegisterEnemy` tracks the training dummies by name/handle.
  - These parts, their `ProximityPrompt`s, and their `CanCollide`/`Anchored` gameplay behavior must not change.
- Mesh generation (`generate_mesh`) is slow and produces one asset per call — assets are generated once, stored as templates under `ReplicatedStorage.Assets`, and cloned/positioned at build time (same pattern `MonsterAIService` uses for `TrashMobTemplate`).

## Design

**Integration principle:** sculpted meshes are added **around/on top of** the existing functional parts as visual dressing — never rename or replace a part another service depends on. Where a mesh visually replaces a current primitive stand-in (e.g. the fountain spire, the tavern sign, the forge anvil), the primitive part is removed from `HubMapService.lua` and the mesh clone takes its place at the same position; the *functional* invisible/interactive parts (`RockhidePortal`, `LevelUpShrine`, `SpawnLocation`) are left completely untouched and the new meshes are positioned as companions around them.

### Asset list

All assets generated once via `generate_mesh` (async, dark-fantasy carved-stone / weathered-wood style matching the existing palette: `STONE_COLOR`/`DARK_STONE`, `GOLD_TRIM`, `PORTAL_COLOR` blue, `SHRINE_COLOR` gold), stored as template `Model`s/`MeshPart`s under `ReplicatedStorage.Assets`, cloned by `HubMapService.BuildHub()`.

| # | Template name | Prompt intent | Placement (world offset from area anchor) | Replaces |
|---|---|---|---|---|
| 1 | `FountainDragonStatue` | Rising stone dragon coiling upward, water-spout mouth | Center plaza, atop `FountainBasin`, replaces `FountainSpire` box | `FountainSpire` |
| 2 | `PortalGuardianStatue` | Stone guardian/golem statue, weathered, runic engravings | 2x, flanking `portalPos` pillars (`±10, 0, -6` from portal base) | New (additive) |
| 3 | `PortalArchCapstone` | Ornate gothic archway capstone with glowing rune carvings | Tops `PortalArch`, same CFrame, sized to span the 24-stud arch | `PortalArchTrim` |
| 4 | `ShrineSeraphIdol` | Carved seraphim/angel idol, wings spread, celestial | Floats above `LevelUpShrine` crystal (`shrinePos + (0, 11, 0)`) | New (additive, crystal untouched) |
| 5 | `TavernHangingSign` | Carved wooden tavern sign, mug-and-sword emblem, iron bracket | Replaces `TavernSign`/`TavernSignPost` boards at same position | `TavernSign` boards |
| 6 | `ForgeAnvilHammer` | Sculpted iron anvil with war-hammer resting on it | Replaces `AnvilBase`/`AnvilTop` at same position | `AnvilBase`, `AnvilTop` |
| 7 | `ForgeDisplayShield` | Ornate sculpted shield with emblem, battle-worn | Replaces `DisplayShield`/`DisplayShieldTrim` at same position | `DisplayShield`, `DisplayShieldTrim` |
| 8 | `WatchtowerBanner` | Hanging cloth gonfalon banner, weathered fantasy heraldry | 2x, on `TowerCapL`/`TowerCapR` at gate | New (additive) |
| 9 | `PlazaTree` | Stylized fantasy tree, twisted trunk | Cloned 4x around plaza corners | New (additive) |
| 10 | `PlazaShrub` | Low fantasy shrub/bush | Cloned 6x lining paths | New (additive) |
| 11 | `SupplyCrate` | Weathered wooden supply crate | Cloned 4x near tavern/forge | New (additive) |
| 12 | `SupplyBarrel` | Weathered wooden barrel | Cloned 4x near tavern/forge | New (additive) |

### Structural upgrade

Per approval, one structural element also gets sculpted treatment beyond pure props: the **portal arch** (#3 above) — its capstone becomes a sculpted mesh instead of a plain slate box, giving the dungeon entrance a less blocky silhouette. The supporting pillars (`makePillar`) stay primitive parts (load-bearing visual anchors, cheap, already read fine at that scale).

### Technical plan

1. Generate each of the 12 templates via `mcp__Roblox_Studio__generate_mesh` (async where possible to batch), store under `ReplicatedStorage.Assets.<Name>`, matching the storage convention of `TrashMobTemplate`.
2. Extend `HubMapService.lua`:
   - Add a `cloneAsset(name, cframe, scale?)` helper that clones a `ReplicatedStorage.Assets` template, anchors it, and parents it into the hub — mirroring how `MonsterAIService` consumes `TrashMobTemplate`.
   - In `BuildHub()`, replace the primitive stand-ins listed in the "Replaces" column with clones of the new templates at the same CFrames.
   - Add the new additive dressing (guardians, seraph idol, banners, trees, shrubs, crates, barrels) at the placements above.
   - Leave `RockhidePortal`, `LevelUpShrine`, `SpawnLocation`, and the training dummies' Parts/names/ProximityPrompts exactly as-is.
3. Verify in Studio: rebuild the hub (`HubMapService.BuildHub()`), screenshot the plaza, portal, shrine, tavern, and forge to confirm meshes are positioned correctly and gameplay prompts (dungeon entry, level-up, training dummy combat) still function.

## Out of scope

- Walls, floors, plaza paving, fence, and tower bodies stay primitive parts.
- No changes to `DungeonMapService.lua`, `MonsterAIService.lua`, or any gameplay logic.
- No new gameplay systems — purely visual.
