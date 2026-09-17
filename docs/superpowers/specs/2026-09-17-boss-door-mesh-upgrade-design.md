# Boss Chamber Door Upgrade: Sculpted Vault Doors

**Date:** 2026-09-17
**Status:** Approved

## Problem

The boss chamber gate (`BossArenaGate` in [DungeonMapService.lua](../../../src/ServerScriptService/Services/DungeonMapService.lua)) currently uses two flat, plain-colored metal slab `Part`s (`Door_Left`, `Door_Right`, dark gray `Enum.Material.Metal`) as its double doors. This is visually flat compared to the sculpted `TrashMobTemplate`/hub-landmark meshes elsewhere in the game, and doesn't reflect Rockhide (the boss behind it — a stone/earth golem, per [Rockhide.lua](../../../src/ReplicatedStorage/Shared/Data/Bosses/Rockhide.lua)) thematically.

## Constraint

`DungeonMapService.OpenBossGate()` ([DungeonMapService.lua:625-630](../../../src/ServerScriptService/Services/DungeonMapService.lua)) animates the door swing with:
```lua
local t1 = TweenService:Create(doorLeft, TweenInfo.new(2.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	CFrame = openLeftCFrame
})
```
`TweenService` can only tween properties that exist on the target instance. A `Model` has no `CFrame` property (only `BasePart`s do), so `doorLeft` and `doorRight` **must remain single `BasePart`s** — not `Model`s — or this tween throws/no-ops and the boss gate never opens. This is the binding constraint on the whole design: whatever visual upgrade goes in must still be assignable directly to `doorLeft`/`doorRight` as a `BasePart`.

`generate_mesh` normally returns a `Model` wrapping a nested `body` `Model` wrapping a `body_geom` `MeshPart` (confirmed pattern from the hub mesh upgrade work). So the sculpted result cannot be used directly as `doorLeft`/`doorRight` — the raw `MeshPart` must be extracted from the wrapper first.

## Design

1. Generate two sculpted stone door-leaf meshes via `generate_mesh`: a left half and a right half of one continuous heavy carved vault door — rock-hewn stone slab, carved fissure/earth-vein relief, dark iron reinforcement bands, sized to the current door footprint (12.5 × 18 × 2.5 studs each, matching `Vector3.new(12.5, WALL_HEIGHT - 4, 2.5)` where `WALL_HEIGHT = 22`). Two separate generations rather than one mesh mirrored via negative-scale, to avoid inverted-normal/backface-culling artifacts from runtime mirroring.
2. Extract the raw `MeshPart` from each generated `Model` (discard the `body`/wrapper `Model`), rename to `BossVaultDoor_Left` / `BossVaultDoor_Right`, and store under `ReplicatedStorage.Assets` — standalone `BasePart`s, alongside the existing hub/monster assets.
3. In `DungeonMapService.lua`'s dungeon-build function, replace the two `makePart(gateModel, "Door_Left", ...)` / `"Door_Right"` calls with clones of these `MeshPart` templates: same name (`Door_Left`/`Door_Right`), same `Size`/`CFrame`/`Anchored`/`CanCollide` semantics as today, assigned to the same `doorLeft`/`doorRight` module-level variables.
4. No other code changes. `OpenBossGate()`'s hinge-swing tween math, `SealBossGate`/`UnsealBossGate`, the `RunicBarrier`, gate posts/arch/trim, and the status billboard are all untouched.

## Out of scope

- The stone archway, gate posts, arch beam, and gold trim around the doorway (per your "door leaves only" answer).
- Any change to `OpenBossGate()`'s animation logic, timing, or easing.
- Any other dungeon geometry in `DungeonMapService.lua`.
