# Boss Chamber Door Mesh Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the boss chamber's flat metal slab doors (`Door_Left`, `Door_Right`) with sculpted stone vault-door `MeshPart`s matching Rockhide's stone/earth theme, without breaking the existing `TweenService` CFrame swing-open animation.

**Architecture:** Generate two sculpted door-leaf meshes via Roblox Studio's AI `generate_mesh` tool, extract the raw `MeshPart` from each (discarding the `Model` wrapper `generate_mesh` normally produces), store them as standalone `BasePart` templates under `ReplicatedStorage.Assets`, then clone them in `DungeonMapService.lua` in place of the current `makePart(...)` door calls — keeping `doorLeft`/`doorRight` as plain `BasePart`s so `OpenBossGate()`'s existing tween code needs zero changes.

**Tech Stack:** Roblox Studio (Luau), Rojo-synced `src/` tree, Roblox Studio MCP tools (`generate_mesh`, `execute_luau`, `inspect_instance`, `screen_capture`).

**Spec:** [docs/superpowers/specs/2026-09-17-boss-door-mesh-upgrade-design.md](../specs/2026-09-17-boss-door-mesh-upgrade-design.md)

**Studio target:** `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8` ("Soul Forge", placeId 125354010947424). Re-resolve with `list_roblox_studios` if this id is no longer connected when execution starts. Confirm Edit mode with `get_studio_state` before Task 1 — if it says `Play`, call `start_stop_play` with `is_start: false` first (mesh generation and hierarchy edits made during Play are discarded when Play stops).

**Important — Task 1 is Studio state, not a tracked file.** It modifies the live Studio DataModel via MCP tool calls and is verified with `inspect_instance`, not git. There is nothing to `git commit` after Task 1. Only Task 2 touches a tracked file (`DungeonMapService.lua`) and gets a git commit (in Task 3).

---

### Task 1: Generate and extract the two door-leaf meshes

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the left door-leaf mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "The left half of a massive ancient stone vault door, rock-hewn slab with carved fissure and earth-vein relief patterns, dark iron reinforcement bands and rivets, heavy boss dungeon gate, asymmetric carving that continues into a matching right half"
size: { x: 12.5, y: 18, z: 2.5 }
segmentation: "none"
```

- [ ] **Step 2: Generate the right door-leaf mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "The right half of a massive ancient stone vault door, rock-hewn slab with carved fissure and earth-vein relief patterns, dark iron reinforcement bands and rivets, heavy boss dungeon gate, mirrors and continues the carving from a matching left half"
size: { x: 12.5, y: 18, z: 2.5 }
segmentation: "none"
```

- [ ] **Step 3: Locate both generated instances**

Call `mcp__Roblox_Studio__search_game_tree` with `datamodel_type: "Edit"`, `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`, `path: "Workspace"`, `keywords: "vault door"`, `max_depth: 1`.

Expected: two new `Model`s in `Workspace`, one per generation (names will be the full prompt text, truncated — this is normal, matches what happened during the hub mesh generation work).

- [ ] **Step 4: Extract the raw MeshPart from each and store under ReplicatedStorage.Assets**

`generate_mesh` with `segmentation: "none"` produces `Model > body (Model) > body_geom (MeshPart)`. The door must end up as a standalone `MeshPart` directly under `ReplicatedStorage.Assets` (not wrapped in a `Model`) — `DungeonMapService`'s `doorLeft`/`doorRight` variables need a `BasePart` they can clone directly and assign into a `TweenService:Create(doorLeft, ..., {CFrame = ...})` call, which only works on `BasePart`s.

Call `mcp__Roblox_Studio__execute_luau` with `datamodel_type: "Edit"`, `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`:
```lua
local Assets = game:GetService("ReplicatedStorage").Assets

local function extractMeshPart(generatedModelName: string, targetName: string): BasePart
	local generatedModel = workspace:FindFirstChild(generatedModelName)
	assert(generatedModel, "generated model not found in Workspace: " .. generatedModelName)

	local bodyWrapper = generatedModel:FindFirstChild("body")
	assert(bodyWrapper, "expected nested 'body' Model inside " .. generatedModelName)

	local meshPart = bodyWrapper:FindFirstChild("body_geom")
	assert(meshPart and meshPart:IsA("MeshPart"), "expected 'body_geom' MeshPart inside 'body'")

	meshPart.Name = targetName
	meshPart.Parent = Assets
	generatedModel:Destroy()

	return meshPart
end

local left = extractMeshPart("<LEFT_NAME_FROM_STEP_3>", "BossVaultDoor_Left")
local right = extractMeshPart("<RIGHT_NAME_FROM_STEP_3>", "BossVaultDoor_Right")

return "extracted: " .. left:GetFullName() .. " and " .. right:GetFullName()
```
Replace `<LEFT_NAME_FROM_STEP_3>` and `<RIGHT_NAME_FROM_STEP_3>` with the actual instance names found in Step 3.

Expected return: `"extracted: ReplicatedStorage.Assets.BossVaultDoor_Left and ReplicatedStorage.Assets.BossVaultDoor_Right"`.

- [ ] **Step 5: Verify both templates**

Call `mcp__Roblox_Studio__inspect_instance` for `ReplicatedStorage.Assets.BossVaultDoor_Left` and `ReplicatedStorage.Assets.BossVaultDoor_Right` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`.

Expected: both exist, `className: "MeshPart"`, directly under `ReplicatedStorage.Assets` (not nested in a leftover `Model`).

---

### Task 2: Wire the door templates into `DungeonMapService.lua`

**Files:**
- Modify: `src/ServerScriptService/Services/DungeonMapService.lua`

- [ ] **Step 1: Add `ReplicatedStorage` service, `Assets` lookup, and a `cloneDoorAsset` helper**

Find (current lines 6-9):
```lua
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DungeonMapService = {}
```
Replace with:
```lua
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DungeonMapService = {}

local Assets = ReplicatedStorage:WaitForChild("Assets")
```

- [ ] **Step 2: Fix the `doorLeft`/`doorRight` type annotations**

The templates are `MeshPart`s, not `Part`s — both are `BasePart` subclasses, but the existing `Part?` annotation is too narrow for what gets assigned once Step 4 lands.

Find (current lines 14-15):
```lua
local doorLeft: Part? = nil
local doorRight: Part? = nil
```
Replace with:
```lua
local doorLeft: BasePart? = nil
local doorRight: BasePart? = nil
```

- [ ] **Step 3: Add the `cloneDoorAsset` helper**

Add this directly below the existing `makePart` function (after its closing `end` at current line 52, before `makeFloor`):
```lua
-- Clones a pre-generated door-leaf mesh template from ReplicatedStorage.Assets, forces
-- it to the given size, and positions it at the given CFrame. Returns nil (with a
-- warning) if the template is missing so a bad asset name never throws during dungeon
-- construction. Matches the CanCollide/Anchored defaults the old makePart(...) slab
-- doors used, so OpenBossGate's existing CanCollide-toggle-then-CFrame-tween logic
-- keeps working unmodified.
--
-- The explicit `size` override matters here: generate_mesh does not reliably hit its
-- requested bounding box (confirmed during this asset's own generation -- the two
-- door-leaf meshes came back at noticeably different, undersized dimensions from each
-- other and from the requested 12.5 x 18 x 2.5). Without forcing both to the same
-- Size, the two leaves of a door meant to meet edge-to-edge in the middle would be
-- visibly mismatched.
local function cloneDoorAsset(parent: Instance, assetName: string, doorName: string, size: Vector3, cframe: CFrame): BasePart?
	local template = Assets:FindFirstChild(assetName)
	if not template or not template:IsA("BasePart") then
		warn("DungeonMapService: missing or invalid door asset ReplicatedStorage.Assets." .. assetName)
		return nil
	end

	local clone = template:Clone()
	clone.Name = doorName
	clone.Size = size
	clone.CFrame = cframe
	clone.Anchored = true
	clone.CanCollide = true
	clone.Parent = parent
	return clone
end
```

- [ ] **Step 4: Replace the door creation calls**

Find (current lines 393-400):
```lua
	-- Left and Right heavy stone doors
	local doorLeftPart = makePart(gateModel, "Door_Left", Vector3.new(12.5, WALL_HEIGHT - 4, 2.5),
		CFrame.new(-6.25, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ), Color3.fromRGB(60, 62, 68), Enum.Material.Metal)
	doorLeft = doorLeftPart

	local doorRightPart = makePart(gateModel, "Door_Right", Vector3.new(12.5, WALL_HEIGHT - 4, 2.5),
		CFrame.new(6.25, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ), Color3.fromRGB(60, 62, 68), Enum.Material.Metal)
	doorRight = doorRightPart
```
Replace with:
```lua
	-- Left and Right sculpted stone vault doors
	doorLeft = cloneDoorAsset(gateModel, "BossVaultDoor_Left", "Door_Left",
		Vector3.new(12.5, WALL_HEIGHT - 4, 2.5), CFrame.new(-6.25, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ))

	doorRight = cloneDoorAsset(gateModel, "BossVaultDoor_Right", "Door_Right",
		Vector3.new(12.5, WALL_HEIGHT - 4, 2.5), CFrame.new(6.25, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ))
```

- [ ] **Step 5: Confirm `OpenBossGate()` needs no changes**

Read `DungeonMapService.OpenBossGate()` (current lines 570-640) and confirm it still only references `doorLeft`/`doorRight` as `BasePart`s (`.CanCollide`, `.CFrame` via `TweenService:Create`) — it should require zero edits. If it does need an edit to compile/type-check, STOP and report BLOCKED rather than guessing a fix; the whole point of Task 1/Step 4's MeshPart extraction was to make this file's only change the two call sites in Step 4 above.

---

### Task 3: Verify and commit

**Files:**
- (verifies) `src/ServerScriptService/Services/DungeonMapService.lua`

- [ ] **Step 1: Sync and rebuild**

Rojo should already be syncing `src/` into the running Studio session. The dungeon is normally built by `Main.server.lua` when a player joins a dungeon-type server. The fastest way to see the boss gate without walking the whole dungeon: temporarily flip `STUDIO_DIRECT_DUNGEON` in `src/ServerScriptService/Main.server.lua` to `true` if it isn't already (it boots Studio Play Solo directly into Rockhide's dungeon) — check its current value first with `mcp__Roblox_Studio__script_grep` (`query: "STUDIO_DIRECT_DUNGEON"`, `studio_id`) before changing anything, and restore it to whatever value it had before you touched it once verification is done, the same way the hub mesh upgrade work did.

Start Play (`mcp__Roblox_Studio__start_stop_play`, `is_start: true`), let the player join, then check `mcp__Roblox_Studio__get_console_output` for any `warn("DungeonMapService: missing or invalid door asset ...")` line.

Expected: no such warning.

- [ ] **Step 2: Confirm door instances are correct in the live Server datamodel**

Call `mcp__Roblox_Studio__inspect_instance` with `path: "Workspace.RockhideArena.BossArenaGate.Door_Left"` and `path: "Workspace.RockhideArena.BossArenaGate.Door_Right"` (the dungeon root Model is named `"RockhideArena"` — see `DungeonMapService.BuildDungeon()`; adjust if `search_game_tree` on `Workspace` with `keywords: "BossArenaGate"` shows a different parent path), `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`.

Expected: both exist, `className: "MeshPart"`, `Anchored: true`, `CanCollide: true`.

- [ ] **Step 3: Screenshot the closed gate**

Call `mcp__Roblox_Studio__screen_capture`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
capture_id: "boss_door_closed"
camera_position: [0, 12, 5]
look_at_position: [0, 10, -25]
```
(Adjust the camera Z if the player character isn't near the gate yet — the gate is at `gateZ = -25` in dungeon-local coordinates; confirm the dungeon's actual world offset via `search_game_tree` if the shot doesn't line up.)

Expected: two sculpted stone door leaves visible in the archway, replacing the old flat gray slabs.

- [ ] **Step 4: Trigger `OpenBossGate` and confirm the swing animation still works**

The gate only opens once `isGateUnlocked` is true (all guardians defeated), which is impractical to fully play through for a visual check. Instead, call `mcp__Roblox_Studio__execute_luau` with `datamodel_type: "Server"`, `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`:
```lua
local DungeonMapService = require(game:GetService("ServerScriptService").Services.DungeonMapService)
-- Force-unlock for a verification-only manual open; this does not persist and does not
-- get committed anywhere -- it's purely to visually confirm the tween doesn't error.
if not DungeonMapService.IsGateUnlocked() then
	-- IsGateUnlocked() has no public setter; if this is false, skip straight to reading
	-- the source instead of forcing state -- see note below.
end
return "gate unlocked state: " .. tostring(DungeonMapService.IsGateUnlocked())
```
If `IsGateUnlocked()` reports `false` and there's no public way to flip it without playing through combat, don't force internal state — instead confirm correctness by reading `OpenBossGate()`'s source once more (Task 2 Step 5 already did this) and rely on Steps 2-3 above (the doors are valid `BasePart`s with the right names) as sufficient evidence the tween will work, since `TweenService:Create(doorLeft, ..., {CFrame = ...})` only requires `doorLeft` to be a `BasePart` — which Step 2 already confirmed. Note in your report which path you took.

- [ ] **Step 5: Stop Play and restore `STUDIO_DIRECT_DUNGEON`**

Call `start_stop_play` with `is_start: false`. If Step 1 changed `STUDIO_DIRECT_DUNGEON`, edit `src/ServerScriptService/Main.server.lua` back to its original value now. Confirm with:
```bash
git diff "Soulforge/src/ServerScriptService/Main.server.lua"
```
Expected: no `STUDIO_DIRECT_DUNGEON` line in the diff (or only pre-existing unrelated changes, if that file already had uncommitted changes before this task started — check with `git status` first and only touch that one line).

- [ ] **Step 6: Commit**

```bash
git add "Soulforge/src/ServerScriptService/Services/DungeonMapService.lua"
git commit -m "$(cat <<'EOF'
Replace boss chamber slab doors with sculpted stone vault doors

Swaps the flat metal Door_Left/Door_Right parts for AI-generated
sculpted stone MeshParts matching Rockhide's earth/stone theme, storing
each door's raw MeshPart (not the Model wrapper generate_mesh produces)
under ReplicatedStorage.Assets so OpenBossGate's existing TweenService
CFrame swing-open animation keeps working unchanged -- it can only
tween a BasePart's CFrame, not a Model's.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Notes for whoever executes this plan

- If `generate_mesh` returns instance names in Step 3 of Task 1 that don't contain "vault" or "door" as substrings (unpredictable exact naming, same as the hub mesh work), broaden the `keywords` search or list all of `Workspace`'s direct children and pick the two newest/matching-size ones.
- Task 1 can run both generations with `async: true` in parallel (they're independent) if the executor wants to save time — just make sure Step 3's search correctly distinguishes which result is which before Step 4 extracts them (compare against the two distinct prompts/generation IDs via `inspect_instance` attributes if ambiguous).
- Task 1's own generation run came back with both door leaves noticeably undersized and mismatched from each other (roughly 4.4x5.3 and 6.3x11.3 studs against a requested 12.5x18) — this is why Task 2's `cloneDoorAsset` forces `clone.Size` explicitly rather than trusting the generated size. Do not skip that `Size` assignment even if a future regeneration happens to land closer to the requested box.
