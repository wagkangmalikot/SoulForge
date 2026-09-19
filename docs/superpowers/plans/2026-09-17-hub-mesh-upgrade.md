# Hub Mesh Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Soulforge hub sculpted, AI-generated `MeshPart` landmarks and props (matching the fidelity of `TrashMobTemplate` monster meshes) in place of/alongside its current all-primitive-part construction, without touching any gameplay-referenced part names.

**Architecture:** Generate 13 mesh templates via Roblox Studio's `generate_mesh` MCP tool, store them under `ReplicatedStorage.Assets` (same convention as `TrashMobTemplate`), then extend `HubMapService.lua` with a `cloneAsset` helper that clones/positions these templates when `BuildHub()` runs — replacing some primitive stand-ins and adding new decorative dressing.

**Tech Stack:** Roblox Studio (Luau), Rojo-synced `src/` tree, Roblox Studio MCP tools (`generate_mesh`, `execute_luau`, `inspect_instance`, `screen_capture`).

**Spec:** [docs/superpowers/specs/2026-09-17-hub-mesh-upgrade-design.md](../specs/2026-09-17-hub-mesh-upgrade-design.md)

**Studio target:** `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8` ("Soul Forge", placeId 125354010947424). Re-resolve with `list_roblox_studios` if this id is no longer connected when execution starts.

**Important — generated assets are Studio state, not source-controlled files.** Tasks 1–13 modify the live Studio DataModel (via MCP tool calls) and are verified with `inspect_instance`/`screen_capture`, not git. There is nothing to `git commit` after those tasks. Only Task 14 touches a tracked file (`HubMapService.lua`) and gets a git commit.

---

### Task 0: Ensure Studio is in Edit mode

Mesh-generation and hierarchy edits made while a playtest is running (`Play` mode) apply to a temporary simulated game and vanish the moment the playtest stops. Every asset generated in this plan must be created while Studio is in **Edit** mode.

**Files:** none (Studio state only)

- [ ] **Step 1: Check current mode**

Call `mcp__Roblox_Studio__get_studio_state` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`.

Expected: a `Current Studio Mode` field. If it already says `Edit`, skip to Task 1.

- [ ] **Step 2: Stop play if running**

If the mode is `Play`, call `mcp__Roblox_Studio__start_stop_play` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8` to stop it.

- [ ] **Step 3: Re-check mode**

Call `mcp__Roblox_Studio__get_studio_state` again.

Expected: `Current Studio Mode: Edit`.

---

### Task 1: Generate `FountainDragonStatue`

Replaces the plain `FountainSpire` box at the plaza's central fountain.

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A weathered stone dragon statue coiling upward around a central spire, mouth open skyward as a water spout, dark fantasy carved-stone style, cracked and mossy"
size: { x: 6, y: 12, z: 6 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Call `mcp__Roblox_Studio__search_game_tree` with `datamodel_type: "Edit"`, `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`, `keywords: "dragon"` (or whatever name the tool assigned) to find where it landed (usually `Workspace`).

Expected: one new `Model` or `MeshPart` in `Workspace`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Call `mcp__Roblox_Studio__execute_luau` with `datamodel_type: "Edit"`, `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`:
```lua
local generated = workspace:FindFirstChild("<NAME_FROM_STEP_2>")
assert(generated, "generated mesh not found in Workspace")
generated.Name = "FountainDragonStatue"
generated.Parent = game:GetService("ReplicatedStorage").Assets
return "moved: " .. generated:GetFullName()
```
Replace `<NAME_FROM_STEP_2>` with the actual instance name found in Step 2.

Expected return: `"moved: ReplicatedStorage.Assets.FountainDragonStatue"`.

---

### Task 2: Generate `PortalGuardianStatue`

Flanks the dungeon portal pillars (cloned twice at placement time — only generate once).

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A stone guardian golem statue standing at attention, weathered gray stone with glowing blue rune engravings down its armor, dark fantasy, dungeon gatekeeper"
size: { x: 5, y: 14, z: 5 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern as Task 1 Step 2, `keywords: "guardian"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern as Task 1 Step 3, target name `PortalGuardianStatue`.

---

### Task 3: Generate `PortalArchCapstone`

Replaces `PortalArchTrim`, tops the dungeon portal's stone arch.

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "An ornate gothic archway capstone, carved stone with glowing blue rune inscriptions across its face, dungeon gateway keystone, dark fantasy"
size: { x: 26, y: 5, z: 6 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern as Task 1 Step 2, `keywords: "capstone"` or `"arch"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern as Task 1 Step 3, target name `PortalArchCapstone`.

---

### Task 4: Generate `ShrineSeraphIdol`

Floats above the `LevelUpShrine` crystal on the altar (additive — the crystal itself is untouched).

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A carved celestial seraphim idol, wings spread wide, golden stone with glowing gold filigree, floating shrine statue, ascension theme"
size: { x: 6, y: 8, z: 4 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "seraph"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `ShrineSeraphIdol`.

---

### Task 5: Generate `TavernHangingSign`

Replaces `TavernSign` + `TavernSignPost` + their `BillboardGui`.

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A carved wooden tavern hanging sign with an iron wall bracket, mug-and-crossed-sword emblem painted on the board, weathered fantasy inn signage"
size: { x: 4, y: 6, z: 1.5 }
segmentation: "explicit"
partNames: "sign board, iron bracket"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "sign"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `TavernHangingSign`.

---

### Task 6: Generate `ForgeAnvilHammer`

Replaces `AnvilBase` + `AnvilTop`.

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A sculpted iron blacksmith anvil on a scorched wooden stump base, war-hammer resting against it, forge workshop prop, dark fantasy"
size: { x: 4, y: 3, z: 2 }
segmentation: "explicit"
partNames: "anvil, hammer"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "anvil"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `ForgeAnvilHammer`.

---

### Task 7: Generate `ForgeDisplayShield`

Replaces `DisplayShield` + `DisplayShieldTrim`.

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "An ornate battle-worn iron kite shield with a gold emblem, hung on display, dark fantasy blacksmith forge prop"
size: { x: 2.5, y: 3.5, z: 0.6 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "shield"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `ForgeDisplayShield`.

---

### Task 8: Generate `WatchtowerBanner`

Hangs on the gate watchtowers (cloned twice at placement time — only generate once).

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A long hanging cloth gonfalon banner with weathered fantasy heraldry, torn edges, deep blue and gold, castle watchtower decoration"
size: { x: 3, y: 8, z: 0.3 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "banner"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `WatchtowerBanner`.

---

### Task 9: Generate `PlazaTree1` and `PlazaTree2`

Two tree varieties for plaza greenery (each cloned twice at placement time).

**Files:** none (Studio state only)

- [ ] **Step 1: Generate `PlazaTree1`**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A stylized fantasy tree with a twisted gnarled trunk and full autumn-orange canopy, low-poly game asset"
size: { x: 8, y: 14, z: 8 }
segmentation: "none"
```
Verify (`keywords: "tree"`) and move/rename into `ReplicatedStorage.Assets.PlazaTree1`, same pattern as Task 1 Steps 2–3.

- [ ] **Step 2: Generate `PlazaTree2`**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A stylized fantasy pine tree, dark green needle canopy, tall narrow silhouette, low-poly game asset"
size: { x: 6, y: 16, z: 6 }
segmentation: "none"
```
Verify (`keywords: "pine"`) and move/rename into `ReplicatedStorage.Assets.PlazaTree2`, same pattern as Task 1 Steps 2–3.

---

### Task 10: Generate `PlazaShrub`

Low greenery lining the plaza's cross paths (cloned 6x at placement time).

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A low rounded fantasy shrub bush, dense green foliage, simple stylized game asset"
size: { x: 3, y: 2, z: 3 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "shrub"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `PlazaShrub`.

---

### Task 11: Generate `SupplyCrate`

Clutter prop near tavern/forge (cloned 4x at placement time).

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A weathered wooden supply crate with rope bindings and iron corner brackets, fantasy village prop"
size: { x: 2.5, y: 2.5, z: 2.5 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "crate"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `SupplyCrate`.

---

### Task 12: Generate `SupplyBarrel`

Clutter prop near tavern/forge (cloned 4x at placement time).

**Files:** none (Studio state only)

- [ ] **Step 1: Generate the mesh**

Call `mcp__Roblox_Studio__generate_mesh`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
textPrompt: "A weathered wooden barrel with iron hoop bands, fantasy village prop, slightly askew"
size: { x: 2, y: 3, z: 2 }
segmentation: "none"
```

- [ ] **Step 2: Verify the result**

Same pattern, `keywords: "barrel"`.

- [ ] **Step 3: Move it into the Assets folder and rename it**

Same pattern, target name `SupplyBarrel`.

---

### Task 13: Wire the 13 templates into `HubMapService.lua`

**Files:**
- Modify: `src/ServerScriptService/Services/HubMapService.lua`

- [ ] **Step 1: Add `ReplicatedStorage` service and a `cloneAsset` helper**

In `HubMapService.lua`, change the top of the file (currently lines 6–10):
```lua
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatService = require(script.Parent.CombatService)
```
to:
```lua
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = require(script.Parent.CombatService)

local Assets = ReplicatedStorage:WaitForChild("Assets")
```

Then add this helper directly below the existing `makeBrazier` function (after line 95, before the `-- BUILD TRAINING DUMMIES` section):
```lua
-- Clones a pre-generated mesh template from ReplicatedStorage.Assets, anchors it,
-- and positions it at the given CFrame. Returns nil (with a warning) if the
-- template is missing so a bad asset name never throws during hub construction.
local function cloneAsset(parent: Instance, assetName: string, cframe: CFrame): Instance?
	local template = Assets:FindFirstChild(assetName)
	if not template then
		warn("HubMapService: missing asset ReplicatedStorage.Assets." .. assetName)
		return nil
	end

	local clone = template:Clone()
	if clone:IsA("Model") then
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		clone:PivotTo(cframe)
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
		clone.Anchored = true
	end

	clone.Parent = parent
	return clone
end
```

- [ ] **Step 2: Replace `FountainSpire` with `FountainDragonStatue`**

Find (current lines 271–273):
```lua
	-- Central Spire
	local spire = makePart(hub, "FountainSpire", Vector3.new(2.5, 9, 2.5), CFrame.new(0, FLOOR_Y + 6.5, 0), GOLD_TRIM, Enum.Material.Metal)
	spire.CanCollide = false
```
Replace with:
```lua
	-- Central Spire — sculpted dragon statue
	cloneAsset(hub, "FountainDragonStatue", CFrame.new(0, FLOOR_Y + 2.8, 0))
```

- [ ] **Step 3: Replace `PortalArchTrim` with `PortalArchCapstone` and add guardian statues**

Find (current lines 302–304):
```lua
	-- Arch beam across the top
	local portalArch = makePart(hub, "PortalArch", Vector3.new(24, 4, 4), CFrame.new(portalPos + Vector3.new(0, 23, 0)), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "PortalArchTrim", Vector3.new(25, 1, 5), CFrame.new(portalPos + Vector3.new(0, 25, 0)), GOLD_TRIM, Enum.Material.Metal)
```
Replace with:
```lua
	-- Arch beam across the top, topped with a sculpted rune capstone
	local portalArch = makePart(hub, "PortalArch", Vector3.new(24, 4, 4), CFrame.new(portalPos + Vector3.new(0, 23, 0)), DARK_STONE, Enum.Material.Slate)
	cloneAsset(hub, "PortalArchCapstone", CFrame.new(portalPos + Vector3.new(0, 25.5, 0)))
```

Then find the brazier lines that close out the portal section (current lines 385–386):
```lua
	-- Flanking Braziers with blue mystic flames
	makeBrazier(hub, portalPos + Vector3.new(-15, 2, 4), Color3.fromRGB(80, 150, 255))
	makeBrazier(hub, portalPos + Vector3.new(15, 2, 4), Color3.fromRGB(80, 150, 255))
```
Replace with:
```lua
	-- Flanking Braziers with blue mystic flames
	makeBrazier(hub, portalPos + Vector3.new(-15, 2, 4), Color3.fromRGB(80, 150, 255))
	makeBrazier(hub, portalPos + Vector3.new(15, 2, 4), Color3.fromRGB(80, 150, 255))

	-- Flanking stone guardian statues
	cloneAsset(hub, "PortalGuardianStatue", CFrame.new(portalPos + Vector3.new(-10, 2, -6)))
	cloneAsset(hub, "PortalGuardianStatue", CFrame.new(portalPos + Vector3.new(10, 2, -6)) * CFrame.Angles(0, math.pi, 0))
```

- [ ] **Step 4: Add the shrine seraph idol**

Find the shrine sparkles block (current lines 442–445):
```lua
	-- Shrine Sparkles
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 240, 140)
	sparkles.Parent = shrineCrystal
```
Replace with:
```lua
	-- Shrine Sparkles
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 240, 140)
	sparkles.Parent = shrineCrystal

	-- Carved seraph idol floating above the crystal
	cloneAsset(hub, "ShrineSeraphIdol", CFrame.new(shrinePos + Vector3.new(0, 12, 0)))
```

- [ ] **Step 5: Replace the tavern sign with `TavernHangingSign`**

Find (current lines 529–543):
```lua
	-- Tavern Hanging Sign
	local signPost = makePart(hub, "TavernSignPost", Vector3.new(0.6, 6, 0.6), CFrame.new(tavernPos + Vector3.new(tavernW/2 + 2, 4, -tavernL/2 + 4)), DARK_WOOD, Enum.Material.Wood)
	local signBoard = makePart(hub, "TavernSign", Vector3.new(4, 2.5, 0.4), CFrame.new(tavernPos + Vector3.new(tavernW/2 + 2, 5.5, -tavernL/2 + 4)), Color3.fromRGB(75, 45, 25), Enum.Material.Wood)

	local signBb = Instance.new("BillboardGui")
	signBb.Size = UDim2.new(0, 140, 0, 40)
	signBb.AlwaysOnTop = false
	signBb.Parent = signBoard
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.TextColor3 = Color3.fromRGB(255, 220, 140)
	signText.Font = Enum.Font.GothamBold
	signText.TextScaled = true
	signText.Text = "SOULFORGE INN"
	signText.Parent = signBb
```
Replace with:
```lua
	-- Sculpted hanging tavern sign
	cloneAsset(hub, "TavernHangingSign", CFrame.new(tavernPos + Vector3.new(tavernW/2 + 2, 5.5, -tavernL/2 + 4)))
```

- [ ] **Step 6: Replace the anvil and display shield with sculpted meshes**

Find (current lines 580–581):
```lua
	-- Iron Anvil
	local anvilBase = makePart(hub, "AnvilBase", Vector3.new(2, 2, 2), CFrame.new(forgePos + Vector3.new(-2, 2, 2)), DARK_WOOD, Enum.Material.Wood)
	local anvilTop = makePart(hub, "AnvilTop", Vector3.new(3.2, 1.2, 1.4), CFrame.new(forgePos + Vector3.new(-2, 3.5, 2)), Color3.fromRGB(60, 62, 68), Enum.Material.Metal)

	-- Display Weapon & Shield
	local displayShield = makePart(hub, "DisplayShield", Vector3.new(2.2, 3.2, 0.4), CFrame.new(forgePos + Vector3.new(-10, 4, 10)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(50, 55, 65), Enum.Material.Metal)
	makePart(hub, "DisplayShieldTrim", Vector3.new(2.4, 3.4, 0.3), displayShield.CFrame, GOLD_TRIM, Enum.Material.Metal)
```
Replace with:
```lua
	-- Sculpted anvil and hammer
	cloneAsset(hub, "ForgeAnvilHammer", CFrame.new(forgePos + Vector3.new(-2, 2, 2)))

	-- Sculpted display shield
	cloneAsset(hub, "ForgeDisplayShield", CFrame.new(forgePos + Vector3.new(-10, 4, 10)) * CFrame.Angles(0, math.rad(45), 0))
```

- [ ] **Step 7: Add watchtower banners**

Find (current lines 599–601):
```lua
	-- Wall Braziers on the towers
	makeBrazier(hub, gatePos + Vector3.new(-14, 27, 0), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, gatePos + Vector3.new(14, 27, 0), Color3.fromRGB(255, 140, 30))
```
Replace with:
```lua
	-- Wall Braziers on the towers
	makeBrazier(hub, gatePos + Vector3.new(-14, 27, 0), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, gatePos + Vector3.new(14, 27, 0), Color3.fromRGB(255, 140, 30))

	-- Heraldry banners hanging from the tower battlements
	cloneAsset(hub, "WatchtowerBanner", CFrame.new(gatePos + Vector3.new(-14, 19, 4)))
	cloneAsset(hub, "WatchtowerBanner", CFrame.new(gatePos + Vector3.new(14, 19, 4)))
```

- [ ] **Step 8: Add plaza trees, shrubs, crates, and barrels**

Find the street lamps block that closes out `BuildHub()` (current lines 603–609):
```lua
	-- ── 9. STREET LAMPS AROUND THE PLAZA ───────────────────────────────────────
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(-50, FLOOR_Y, -30))
	makeStreetLamp(hub, Vector3.new(50, FLOOR_Y, -30))

	hub.Parent = workspace
	return hub
```
Replace with:
```lua
	-- ── 9. STREET LAMPS AROUND THE PLAZA ───────────────────────────────────────
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(-50, FLOOR_Y, -30))
	makeStreetLamp(hub, Vector3.new(50, FLOOR_Y, -30))

	-- ── 10. PLAZA GREENERY & CLUTTER ────────────────────────────────────────────
	-- Trees in the open plaza corners, away from building footprints
	cloneAsset(hub, "PlazaTree1", CFrame.new(-70, FLOOR_Y, -35))
	cloneAsset(hub, "PlazaTree1", CFrame.new(70, FLOOR_Y, -35) * CFrame.Angles(0, math.pi, 0))
	cloneAsset(hub, "PlazaTree2", CFrame.new(-30, FLOOR_Y, 68))
	cloneAsset(hub, "PlazaTree2", CFrame.new(30, FLOOR_Y, 68) * CFrame.Angles(0, math.pi, 0))

	-- Shrubs lining the cross paths
	cloneAsset(hub, "PlazaShrub", CFrame.new(11, FLOOR_Y, -40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(-11, FLOOR_Y, -40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(11, FLOOR_Y, 40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(-11, FLOOR_Y, 40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(40, FLOOR_Y, 11))
	cloneAsset(hub, "PlazaShrub", CFrame.new(-40, FLOOR_Y, 11))

	-- Crates and barrels clustered near the tavern and forge
	cloneAsset(hub, "SupplyCrate", CFrame.new(tavernPos + Vector3.new(-16, 0, 12)))
	cloneAsset(hub, "SupplyCrate", CFrame.new(tavernPos + Vector3.new(-14, 0, 14)) * CFrame.Angles(0, math.rad(20), 0))
	cloneAsset(hub, "SupplyCrate", CFrame.new(forgePos + Vector3.new(14, 0, -10)))
	cloneAsset(hub, "SupplyCrate", CFrame.new(forgePos + Vector3.new(12, 0, -12)) * CFrame.Angles(0, math.rad(-15), 0))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(tavernPos + Vector3.new(-17, 0, 15)))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(tavernPos + Vector3.new(-13, 0, 16)))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(forgePos + Vector3.new(15, 0, -13)))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(forgePos + Vector3.new(11, 0, -15)))

	hub.Parent = workspace
	return hub
```

- [ ] **Step 9: Sync the file to Studio and rebuild the hub**

Rojo should already be syncing `src/` into the running Studio session (per this project's normal workflow). Confirm the sync landed, then rebuild:

Call `mcp__Roblox_Studio__execute_luau` with `datamodel_type: "Edit"`, `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`:
```lua
local HubMapService = require(game:GetService("ServerScriptService").Services.HubMapService)
HubMapService.BuildHub()
return "hub rebuilt"
```

Expected return: `"hub rebuilt"`, with no `warn(...)` output about missing assets (check via `mcp__Roblox_Studio__get_console_output`). If any `warn("HubMapService: missing asset ...")` appears, the corresponding Task 1–12 asset wasn't renamed/moved correctly — go back and fix it before continuing.

---

### Task 14: Visual verification and commit

**Files:**
- (verifies) `src/ServerScriptService/Services/HubMapService.lua`

- [ ] **Step 1: Screenshot the fountain and portal**

Call `mcp__Roblox_Studio__screen_capture`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
capture_id: "hub_fountain_portal"
camera_position: [0, 25, 40]
look_at_position: [0, 8, -58]
```
Expected: the fountain shows the dragon statue instead of a plain gold spire; the portal shows the rune capstone and two flanking guardian statues instead of a plain slate trim bar.

- [ ] **Step 2: Screenshot the shrine and training grounds**

Call `mcp__Roblox_Studio__screen_capture`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
capture_id: "hub_shrine"
camera_position: [80, 20, 20]
look_at_position: [58, 8, 0]
```
Expected: the seraph idol floats above the level-up crystal.

- [ ] **Step 3: Screenshot the tavern and forge**

Call `mcp__Roblox_Studio__screen_capture` twice, once per building:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
capture_id: "hub_tavern"
camera_position: [-70, 15, 30]
look_at_position: [-45, 6, 45]
```
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
capture_id: "hub_forge"
camera_position: [70, 15, 30]
look_at_position: [45, 6, 45]
```
Expected: sculpted hanging sign on the tavern; sculpted anvil/hammer and shield on the forge; crates/barrels visible nearby.

- [ ] **Step 4: Screenshot the wide plaza to confirm greenery placement doesn't block paths or overlap buildings**

Call `mcp__Roblox_Studio__screen_capture`:
```
studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8
capture_id: "hub_wide"
camera_position: [0, 90, 100]
look_at_position: [0, 0, 0]
```
Expected: trees/shrubs sit in open plaza space, no visible clipping into the plaza buildings, fence, or paths. If a tree/shrub/crate overlaps something, nudge its `CFrame` in Task 13 Step 8 and re-run Task 13 Step 9.

- [ ] **Step 5: Confirm gameplay is unaffected**

Call `mcp__Roblox_Studio__inspect_instance` for each of `workspace.RockhidePortal`, `workspace.LevelUpShrine`, `workspace.SpawnLocation` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`.

Expected: all three still exist, unchanged `ClassName`/`Name`, still direct children of `Workspace` (not reparented under the new mesh models). This confirms `DungeonEntryService`'s `HUB_ONLY_SCENERY` cleanup and the portal/shrine `ProximityPrompt`s still resolve correctly.

- [ ] **Step 6: Commit the code change**

```bash
git add "Soulforge/src/ServerScriptService/Services/HubMapService.lua"
git commit -m "$(cat <<'EOF'
Add sculpted mesh landmarks and props to the hub

Replaces plain primitive-part stand-ins (fountain spire, portal trim,
tavern sign, forge anvil/shield) with AI-generated sculpted meshes to
match the visual fidelity of the TrashMobTemplate monster meshes, and
adds new mesh dressing (guardian statues, seraph idol, banners, trees,
shrubs, crates, barrels). Gameplay-referenced parts (RockhidePortal,
LevelUpShrine, SpawnLocation, training dummies) are untouched.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Notes for whoever executes this plan

- If `generate_mesh` returns a different default name/location than expected in any "Verify the result" step, adapt the `keywords` search and the `<NAME_FROM_STEP_2>` substitution accordingly — the exact instance name Studio assigns isn't predictable ahead of time, only the final renamed-and-moved location (`ReplicatedStorage.Assets.<TemplateName>`) is fixed.
- Task 13's exact `CFrame` offsets for the additive dressing (guardians, banners, trees, shrubs, crates, barrels) are a reasonable first pass computed from the existing area anchors (`portalPos`, `shrinePos`, `tavernPos`, `forgePos`, `gatePos`). Task 14's screenshots are the check for whether any of them need nudging — treat visible clipping/overlap as a bug to fix before the final commit, not as out of scope.
- Tasks 1–12 can be parallelized (multiple `generate_mesh` calls queued via `async: true`, polled with `wait_job_finished`) if the executor wants to speed this up — they don't depend on each other. Task 13 depends on all of Tasks 1–12 being complete (every template renamed into `ReplicatedStorage.Assets`).
