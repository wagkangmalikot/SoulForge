# Class Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Mage class actually reachable through play — a real two-card class picker in character creation (used by both first-time creation and reforge), plus every hardcoded `Classes.Tank` site generalized to the player's actual `ClassId`.

**Architecture:** `ClassId` starts flowing to the client for the first time via a new third argument on the existing `CharacterDataChanged` remote. Two remotes (`SubmitCharacterCreation`, `RequestCreateNewCharacter`) gain a `classId` argument, validated server-side against `Classes` with a `"Tank"` fallback. The character-creation screen's single Tank card becomes two selectable cards; the "reforge" flow is rewired to go through that same picker instead of resetting straight to Tank. `SkillTreeUIController` caches the incoming `ClassId` and uses it everywhere it currently hardcodes `Classes.Tank`, `BRANCH_ORDER`, or a Tank-specific icon/branch-name check.

**Tech Stack:** Roblox Luau (server: ServerScriptService/Services, client: StarterPlayer/StarterPlayerScripts/Controllers), Rojo-synced to Roblox Studio. This project has no automated test framework (no TestEZ or equivalent) — "testing" in this plan means live verification through a connected Roblox Studio session (the `mcp__Roblox_Studio__*` tools: `script_grep` to confirm Rojo sync, `execute_luau` to run assertions against the live game state, `get_console_output` to check for errors), the same way prior work in this session was verified. Each task's verification step gives the exact Luau snippet and expected result instead of a test-runner command.

**Spec:** `docs/superpowers/specs/2026-09-19-class-selection-design.md`

---

### Task 1: Update `Net.lua` remote-argument comments

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Net.lua:26,29,31`

These are documentation-only comments (Net.lua declares remote names, not typed schemas), but they're actively misleading once later tasks change what these remotes carry — fixing them now avoids describing the old behavior while the rest of the plan is in flight.

- [ ] **Step 1: Edit the three comment lines**

Change:
```lua
	"SubmitCharacterCreation",   -- client -> server: no args -- name comes from player.DisplayName, class is always Tank
	"ShowCharacterChoice",       -- server -> client: {level} -- tells this client to show the Load/Create New choice (returning player)
	"RequestLoadCharacter",      -- client -> server: no args -- spawn as the existing character
	"RequestCreateNewCharacter", -- client -> server: no args -- reset Character to defaults (keeping DisplayName/HasCreatedCharacter) and spawn
```
to:
```lua
	"SubmitCharacterCreation",   -- client -> server: {classId} -- name comes from player.DisplayName
	"ShowCharacterChoice",       -- server -> client: {level} -- tells this client to show the Load/Create New choice (returning player)
	"RequestLoadCharacter",      -- client -> server: no args -- spawn as the existing character
	"RequestCreateNewCharacter", -- client -> server: {classId} -- reset Character to defaults (keeping DisplayName/HasCreatedCharacter) and spawn
```
And change:
```lua
	"CharacterDataChanged",    -- server -> client: {level, unspentEXP} -- fires on spawn and after each level-up
```
to:
```lua
	"CharacterDataChanged",    -- server -> client: {level, unspentEXP, classId} -- fires on spawn and after each level-up
```

- [ ] **Step 2: Verify sync**

Run in Bash: `grep -n "classId" "src/ReplicatedStorage/Shared/Net.lua"` — expect 3 matching lines.

- [ ] **Step 3: Commit**

```bash
git add src/ReplicatedStorage/Shared/Net.lua
git commit -m "docs: update Net.lua comments for classId-carrying remotes"
```

---

### Task 2: Server accepts and validates `classId` on character creation

**Files:**
- Modify: `src/ServerScriptService/Services/CharacterCreationService.lua`

- [ ] **Step 1: Require `Classes` and add a validation helper**

Add near the top, alongside the existing requires (after `local HubMapService = require(script.Parent.HubMapService)`):
```lua
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
```

Add this helper right after `fireCharacterDataChanged` (which stays where it is for this step; its body changes in Step 2):
```lua
-- Rejects an unrecognized/tampered classId from the client rather than trusting it
-- outright -- "Tank" is always a safe fallback since it's the original, always-valid class.
local function validateClassId(classId: any): string
	if type(classId) == "string" and Classes[classId] then
		return classId
	end
	return "Tank"
end
```

- [ ] **Step 2: Send `ClassId` on every `CharacterDataChanged` fire**

Change:
```lua
local function fireCharacterDataChanged(player: Player, profile)
	Net.Get("CharacterDataChanged"):FireClient(
		player,
		profile.Data.Character.Level,
		profile.Data.Character.UnspentEXP
	)
end
```
to:
```lua
local function fireCharacterDataChanged(player: Player, profile)
	Net.Get("CharacterDataChanged"):FireClient(
		player,
		profile.Data.Character.Level,
		profile.Data.Character.UnspentEXP,
		profile.Data.Character.ClassId
	)
end
```

- [ ] **Step 3: Accept `classId` in `onSubmitCharacterCreation`**

Change:
```lua
local function onSubmitCharacterCreation(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or already created: reject a resubmission
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	profile.Data.Character.Name = player.DisplayName
	profile.Data.Character.ClassId = "Tank" -- the only implemented class (spec section 2a)
	profile.Data.Character.HasCreatedCharacter = true

	loadCharacterAndNotify(player, profile, "after submission")
end
```
to:
```lua
local function onSubmitCharacterCreation(player: Player, classId: any)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or already created: reject a resubmission
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	profile.Data.Character.Name = player.DisplayName
	profile.Data.Character.ClassId = validateClassId(classId)
	profile.Data.Character.HasCreatedCharacter = true

	loadCharacterAndNotify(player, profile, "after submission")
end
```

- [ ] **Step 4: Accept `classId` in `onRequestCreateNewCharacter`**

Change:
```lua
local function onRequestCreateNewCharacter(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or not profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or nothing to overwrite
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	-- Resets progress (spec 2b) but keeps HasCreatedCharacter true -- this is
	-- an overwrite of an existing character, not a return to the first-timer
	-- state. If anything below throws, the profile must not end up looking
	-- like a fresh, uncreated one, or a rejoin would incorrectly show the
	-- first-timer creation screen instead of the choice screen. Setting
	-- HasCreatedCharacter is not part of this reset, so that risk doesn't
	-- apply here.
	profile.Data.Character.Level = 1
	profile.Data.Character.UnspentEXP = 999999
	profile.Data.Character.SkillPoints = 50
	profile.Data.Character.ClassId = "Tank"
	profile.Data.Character.Name = player.DisplayName

	loadCharacterAndNotify(player, profile, "after create-new")
end
```
to:
```lua
local function onRequestCreateNewCharacter(player: Player, classId: any)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or not profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or nothing to overwrite
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	-- Resets progress (spec 2b) but keeps HasCreatedCharacter true -- this is
	-- an overwrite of an existing character, not a return to the first-timer
	-- state. If anything below throws, the profile must not end up looking
	-- like a fresh, uncreated one, or a rejoin would incorrectly show the
	-- first-timer creation screen instead of the choice screen. Setting
	-- HasCreatedCharacter is not part of this reset, so that risk doesn't
	-- apply here.
	profile.Data.Character.Level = 1
	profile.Data.Character.UnspentEXP = 999999
	profile.Data.Character.SkillPoints = 50
	profile.Data.Character.ClassId = validateClassId(classId)
	profile.Data.Character.Name = player.DisplayName

	loadCharacterAndNotify(player, profile, "after create-new")
end
```

- [ ] **Step 5: No change needed for the `OnServerEvent` connections**

`CharacterCreationService.Start()` wires both handlers as plain direct references:
```lua
	Net.Get("SubmitCharacterCreation").OnServerEvent:Connect(onSubmitCharacterCreation)
	Net.Get("RequestLoadCharacter").OnServerEvent:Connect(onRequestLoadCharacter)
	Net.Get("RequestCreateNewCharacter").OnServerEvent:Connect(onRequestCreateNewCharacter)
```
Neither is wrapped in an intermediate closure that would drop extra arguments, so once Steps 3-4 change the handlers' own signatures to `(player: Player, classId: any)`, the client's `classId` argument reaches them automatically. Nothing to edit here — this step is a confirmation, not a code change.

- [ ] **Step 6: Update the now-stale comment in `Classes.lua`**

The Mage entry's comment currently says class selection isn't implemented yet. Change:
```lua
	-- Not yet reachable through character creation or the skill tree UI (both still
	-- hardcode Tank) -- see docs/superpowers/specs/2026-09-18-mage-class-design.md's
	-- "sub-project 2" for that follow-up work. Playable today only via a manual
	-- ClassId/UnlockedSkills override on a test profile.
	Mage = {
```
to:
```lua
	Mage = {
```
(Delete the now-false comment entirely rather than editing it in place — nothing about the Mage entry itself needs explaining that its own fields don't already say.)

**File:** `src/ReplicatedStorage/Shared/Data/Classes.lua:21-25` (comment + `Mage = {` line)

- [ ] **Step 7: Verify sync**

Run in Bash: `grep -n "validateClassId\|classId" "src/ServerScriptService/Services/CharacterCreationService.lua"` — expect matches at the helper definition and both handler signatures/bodies (at least 5 lines).

- [ ] **Step 8: Commit**

```bash
git add src/ServerScriptService/Services/CharacterCreationService.lua src/ReplicatedStorage/Shared/Data/Classes.lua
git commit -m "feat: accept and validate classId on character creation/reforge"
```

---

### Task 3: Carry `ClassId` through `LevelUpService`'s `CharacterDataChanged` fires

**Files:**
- Modify: `src/ServerScriptService/Services/LevelUpService.lua:34,65`

`CharacterDataChanged` now has a 3rd parameter (`classId`). `LevelUpService` fires this same event twice (on a successful level-up, and from the `/exp`-style dev chat commands) without a 3rd argument — a client listener would receive `classId == nil` on those fires. Since a character's class never changes on level-up, the fix is simply to always send it, not to make listeners tolerate a missing one.

- [ ] **Step 1: Update `tryLevelUp`'s fire**

Change:
```lua
	Net.Get("CharacterDataChanged"):FireClient(player, character.Level, character.UnspentEXP)
```
(the one inside `local function tryLevelUp(player: Player)`) to:
```lua
	Net.Get("CharacterDataChanged"):FireClient(player, character.Level, character.UnspentEXP, character.ClassId)
```

- [ ] **Step 2: Update the dev chat-command fire**

Change the second occurrence (inside `hookChat`'s `player.Chatted` handler, using `char` not `character`):
```lua
					Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP)
```
to:
```lua
					Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP, char.ClassId)
```

- [ ] **Step 3: Verify sync**

Run in Bash: `grep -n "CharacterDataChanged" "src/ServerScriptService/Services/LevelUpService.lua"` — expect both lines to now include `.ClassId` (or `char.ClassId`).

- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/Services/LevelUpService.lua
git commit -m "fix: include ClassId in LevelUpService's CharacterDataChanged fires"
```

---

### Task 4: `DungeonSessionService` spawns with the player's actual class health

**Files:**
- Modify: `src/ServerScriptService/Services/DungeonSessionService.lua:238-245`

- [ ] **Step 1: Replace the hardcoded lookup**

Change:
```lua
	-- This vertical slice has exactly one class (Tank; see
	-- ReplicatedStorage/Shared/Data/Classes.lua), so hardcoding it here matches the
	-- existing Tank-only scoping used elsewhere (e.g. PlayerDataService's
	-- DEFAULT_DATA.Character.ClassId = "Tank"). Without this, spawned Humanoids sit
	-- at Roblox's default 100 HP instead of the class's intended baseHealth.
	local classData = Classes.Tank
	humanoid.MaxHealth = classData.baseHealth
	humanoid.Health = classData.baseHealth
```
to:
```lua
	-- Without this, spawned Humanoids sit at Roblox's default 100 HP instead of
	-- the player's class's intended baseHealth. Falls back to Tank if the profile
	-- somehow isn't available yet or carries an unrecognized ClassId.
	local profile = PlayerDataService.GetProfile(player)
	local classId = (profile and profile.Data.Character.ClassId) or "Tank"
	local classData = Classes[classId] or Classes.Tank
	humanoid.MaxHealth = classData.baseHealth
	humanoid.Health = classData.baseHealth
```

This is inside `hookPlayerDeath(player: Player, character: Model)`, which already has `player` in scope, and the file already requires `PlayerDataService` (used elsewhere in this same file) and `Classes` (already required at the top, per its existing `Classes.Tank` usage) — no new `require` needed.

- [ ] **Step 2: Verify sync**

Run in Bash: `grep -n "Classes\[classId\]" "src/ServerScriptService/Services/DungeonSessionService.lua"` — expect 1 match.

- [ ] **Step 3: Commit**

```bash
git add src/ServerScriptService/Services/DungeonSessionService.lua
git commit -m "fix: spawn dungeon characters with their actual class's baseHealth"
```

---

### Task 5: Character-creation screen — two selectable class cards

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua`

This replaces the single hardcoded "Tank Archetype Showcase Card" (the block building `tankShowcase` and its children) with two side-by-side selectable cards built from one shared helper, and tracks which one is currently selected.

- [ ] **Step 1: Add class-card data and the shared card-builder function**

Add this near the top of the file, right after the `COLORS` table definition (before `applyCorner`):
```lua
-- Per-class content for the character-creation picker cards. Keys must match
-- ReplicatedStorage.Shared.Data.Classes's own keys ("Tank", "Mage").
local CLASS_CARD_INFO = {
	Tank = {
		icon = "🛡️",
		title = "TANK ARCHETYPE",
		description = "Steadfast frontline juggernaut armed with sword and heavy shield. Masters crowd control and holds boss aggro with Taunt.",
		traits = {
			{ "⚔️", "Attack: Heavy Sword Cleave" },
			{ "🛡️", "Starter Skill: Taunt" },
			{ "🌳", "Trees: Juggernaut & Bulwark" },
		},
	},
	Mage = {
		icon = "🔮",
		title = "MAGE ARCHETYPE",
		description = "Fragile spellcaster who strikes from range with arcane bolts, then specializes into explosive fire or lingering frost damage.",
		traits = {
			{ "🔥", "Attack: Arcane Bolt (Ranged)" },
			{ "❤️", "Base Health: 80 (Fragile)" },
			{ "🌳", "Trees: Pyromancy & Frostweave" },
		},
	},
}
```

Add this function after `applyStroke` (before `loadAvatarThumbnail`) — it depends on both:
```lua
-- Builds one selectable class-picker card. Returns the card frame, its border
-- UIStroke (for the caller to re-color on selection), and a transparent
-- full-card hitbox button (for the caller to wire click handling on).
local function createClassCard(parent: Instance, classId: string, xScale: number, widthScale: number): (Frame, UIStroke, TextButton)
	local info = CLASS_CARD_INFO[classId]

	local card = Instance.new("Frame")
	card.Name = "ClassCard_" .. classId
	card.Size = UDim2.new(widthScale, 0, 1, 0)
	card.Position = UDim2.new(xScale, 0, 0, 0)
	card.BackgroundColor3 = COLORS.bgCardInner
	card.BorderSizePixel = 0
	card.Parent = parent

	applyCorner(card, 12)
	local cardStroke = applyStroke(card, COLORS.slateBorder, 1.6)

	local banner = Instance.new("Frame")
	banner.Size = UDim2.new(1, 0, 0, 40)
	banner.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	banner.BorderSizePixel = 0
	banner.Parent = card
	applyCorner(banner, 12)

	local classTitle = Instance.new("TextLabel")
	classTitle.Size = UDim2.new(1, -16, 1, 0)
	classTitle.Position = UDim2.new(0, 10, 0, 0)
	classTitle.BackgroundTransparency = 1
	classTitle.Font = Enum.Font.GothamBlack
	classTitle.Text = info.icon .. " " .. info.title
	classTitle.TextColor3 = COLORS.goldLight
	classTitle.TextSize = 12
	classTitle.TextXAlignment = Enum.TextXAlignment.Left
	classTitle.Parent = banner

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 54)
	desc.Position = UDim2.new(0, 10, 0, 46)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.GothamMedium
	desc.Text = info.description
	desc.TextColor3 = COLORS.slateLight
	desc.TextSize = 9.5
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = card

	local traitsFrame = Instance.new("Frame")
	traitsFrame.Size = UDim2.new(1, -20, 0, 96)
	traitsFrame.Position = UDim2.new(0, 10, 0, 104)
	traitsFrame.BackgroundTransparency = 1
	traitsFrame.Parent = card

	local traitsLayout = Instance.new("UIListLayout")
	traitsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	traitsLayout.Padding = UDim.new(0, 6)
	traitsLayout.Parent = traitsFrame

	for _, trait in info.traits do
		local tLabel = Instance.new("TextLabel")
		tLabel.Size = UDim2.new(1, 0, 0, 28)
		tLabel.BackgroundTransparency = 1
		tLabel.Font = Enum.Font.GothamBold
		tLabel.Text = trait[1] .. "  " .. trait[2]
		tLabel.TextColor3 = COLORS.textWhite
		tLabel.TextSize = 10
		tLabel.TextWrapped = true
		tLabel.TextXAlignment = Enum.TextXAlignment.Left
		tLabel.TextYAlignment = Enum.TextYAlignment.Top
		tLabel.Parent = traitsFrame
	end

	local hitbox = Instance.new("TextButton")
	hitbox.Name = "SelectHitbox"
	hitbox.Size = UDim2.new(1, 0, 1, 0)
	hitbox.BackgroundTransparency = 1
	hitbox.Text = ""
	hitbox.AutoButtonColor = false
	hitbox.ZIndex = 5
	hitbox.Parent = card

	return card, cardStroke, hitbox
end
```

- [ ] **Step 2: Replace the "Tank Archetype Showcase Card" block with the two-card row**

Find and delete this entire block (from the `-- Tank Archetype Showcase Card` comment through the end of `createTraitItem`'s three calls, i.e. everything from `local tankShowcase = Instance.new("Frame")` down to and including `createTraitItem("🌳", "Ascension: Unlock Juggernaut & Bulwark Trees")`):
```lua
	-- Tank Archetype Showcase Card
	local tankShowcase = Instance.new("Frame")
	tankShowcase.Size = UDim2.new(1, 0, 0, 210)
	tankShowcase.Position = UDim2.new(0, 0, 0, 58)
	tankShowcase.BackgroundColor3 = COLORS.bgCardInner
	tankShowcase.BorderSizePixel = 0
	tankShowcase.Parent = createCard

	applyCorner(tankShowcase, 12)
	applyStroke(tankShowcase, COLORS.goldPrimary, 1.6)

	local tankBanner = Instance.new("Frame")
	tankBanner.Size = UDim2.new(1, 0, 0, 44)
	tankBanner.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	tankBanner.BorderSizePixel = 0
	tankBanner.Parent = tankShowcase
	applyCorner(tankBanner, 12)

	local tankClassTitle = Instance.new("TextLabel")
	tankClassTitle.Size = UDim2.new(1, -24, 1, 0)
	tankClassTitle.Position = UDim2.new(0, 16, 0, 0)
	tankClassTitle.BackgroundTransparency = 1
	tankClassTitle.Font = Enum.Font.GothamBlack
	tankClassTitle.Text = "🛡️ TANK ARCHETYPE"
	tankClassTitle.TextColor3 = COLORS.goldLight
	tankClassTitle.TextSize = 15
	tankClassTitle.TextXAlignment = Enum.TextXAlignment.Left
	tankClassTitle.Parent = tankBanner

	local tankDesc = Instance.new("TextLabel")
	tankDesc.Size = UDim2.new(1, -32, 0, 42)
	tankDesc.Position = UDim2.new(0, 16, 0, 50)
	tankDesc.BackgroundTransparency = 1
	tankDesc.Font = Enum.Font.GothamMedium
	tankDesc.Text = "Steadfast frontline juggernaut armed with sword and heavy shield. Masters crowd control and holds boss aggro with Taunt."
	tankDesc.TextColor3 = COLORS.slateLight
	tankDesc.TextSize = 11
	tankDesc.TextWrapped = true
	tankDesc.TextXAlignment = Enum.TextXAlignment.Left
	tankDesc.Parent = tankShowcase

	-- Traits Row
	local traitsFrame = Instance.new("Frame")
	traitsFrame.Size = UDim2.new(1, -32, 0, 96)
	traitsFrame.Position = UDim2.new(0, 16, 0, 98)
	traitsFrame.BackgroundTransparency = 1
	traitsFrame.Parent = tankShowcase

	local traitsLayout = Instance.new("UIListLayout")
	traitsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	traitsLayout.Padding = UDim.new(0, 6)
	traitsLayout.Parent = traitsFrame

	local function createTraitItem(icon: string, text: string)
		local tLabel = Instance.new("TextLabel")
		tLabel.Size = UDim2.new(1, 0, 0, 22)
		tLabel.BackgroundTransparency = 1
		tLabel.Font = Enum.Font.GothamBold
		tLabel.Text = icon .. "   " .. text
		tLabel.TextColor3 = COLORS.textWhite
		tLabel.TextSize = 11
		tLabel.TextXAlignment = Enum.TextXAlignment.Left
		tLabel.Parent = traitsFrame
	end

	createTraitItem("⚔️", "Standard Attack: Heavy Sword Cleave")
	createTraitItem("🛡️", "Starter Skill: Taunt (Forces Target Aggro)")
	createTraitItem("🌳", "Ascension: Unlock Juggernaut & Bulwark Trees")
```

Replace it with:
```lua
	-- Class Picker: two selectable cards
	local classCardsRow = Instance.new("Frame")
	classCardsRow.Size = UDim2.new(1, 0, 0, 210)
	classCardsRow.Position = UDim2.new(0, 0, 0, 58)
	classCardsRow.BackgroundTransparency = 1
	classCardsRow.Parent = createCard

	local tankCard, tankCardStroke, tankCardHitbox = createClassCard(classCardsRow, "Tank", 0, 0.485)
	local mageCard, mageCardStroke, mageCardHitbox = createClassCard(classCardsRow, "Mage", 0.515, 0.485)

	local selectedClassId = "Tank"

	local function refreshClassCardSelection()
		tankCardStroke.Color = (selectedClassId == "Tank") and COLORS.goldPrimary or COLORS.slateBorder
		tankCardStroke.Thickness = (selectedClassId == "Tank") and 2.4 or 1.6
		mageCardStroke.Color = (selectedClassId == "Mage") and COLORS.goldPrimary or COLORS.slateBorder
		mageCardStroke.Thickness = (selectedClassId == "Mage") and 2.4 or 1.6
	end
	refreshClassCardSelection()

	tankCardHitbox.Activated:Connect(function()
		selectedClassId = "Tank"
		refreshClassCardSelection()
	end)
	mageCardHitbox.Activated:Connect(function()
		selectedClassId = "Mage"
		refreshClassCardSelection()
	end)
```

- [ ] **Step 3: Send the selected class on submit**

Find (inside the `beginBtn = createStyledButton({ ... onClick = function() ... end })` call):
```lua
		onClick = function()
			beginBtn.Active = false
			beginBtn.Text = "FORGING HERO..."
			Net.Get("SubmitCharacterCreation"):FireServer()
		end,
```
Change to:
```lua
		onClick = function()
			beginBtn.Active = false
			beginBtn.Text = "FORGING HERO..."
			Net.Get("SubmitCharacterCreation"):FireServer(selectedClassId)
		end,
```
(Task 6 changes this again to branch on `creationFlowMode` — this step alone is enough to make first-time creation pass the selected class.)

- [ ] **Step 4: Verify sync**

Run in Bash: `grep -n "classCardsRow\|selectedClassId\|CLASS_CARD_INFO" "src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua"` — expect multiple matches across the new data table, the card-builder function, and the row/selection code.

- [ ] **Step 5: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
git commit -m "feat: two selectable class cards in character creation"
```

---

### Task 6: Route the reforge flow through the class picker

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua`

Currently "REFORGE HERO?" → "DELETE & RESTART" fires `RequestCreateNewCharacter` immediately with no class choice. This routes it through the same two-card picker screen instead, and makes the picker's EMBARK button fire the correct remote depending on which flow reached it.

- [ ] **Step 1: Add flow-mode state**

Add near the top of `CharacterCreationController.Start()`, right after `local player = Players.LocalPlayer`:
```lua
	-- Which remote the class-picker's EMBARK button should fire: "create" for a
	-- first-timer, "reforge" when reached via the "REFORGE HERO?" confirmation.
	local creationFlowMode: "create" | "reforge" = "create"
```

- [ ] **Step 2: Branch EMBARK's remote call on flow mode**

Change the `beginBtn` `onClick` from Task 5's Step 3:
```lua
		onClick = function()
			beginBtn.Active = false
			beginBtn.Text = "FORGING HERO..."
			Net.Get("SubmitCharacterCreation"):FireServer(selectedClassId)
		end,
```
to:
```lua
		onClick = function()
			beginBtn.Active = false
			beginBtn.Text = "FORGING HERO..."
			if creationFlowMode == "reforge" then
				Net.Get("RequestCreateNewCharacter"):FireServer(selectedClassId)
			else
				Net.Get("SubmitCharacterCreation"):FireServer(selectedClassId)
			end
		end,
```

- [ ] **Step 3: Make "DELETE & RESTART" open the picker instead of firing directly**

Change:
```lua
	deleteBtn = createStyledButton({
		parent = confirmBtns,
		text = "💥   DELETE & RESTART",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.new(0, 0, 0, 52),
		primaryColor = COLORS.crimsonDark,
		gradientTop = COLORS.crimsonPrimary,
		gradientBottom = COLORS.crimsonDark,
		strokeColor = COLORS.crimsonLight,
		textColor = Color3.fromRGB(255, 220, 220),
		textSize = 13,
		font = Enum.Font.GothamBlack,
		onClick = function()
			cancelBtn.Active = false
			deleteBtn.Active = false
			deleteBtn.Text = "DELETING..."
			Net.Get("RequestCreateNewCharacter"):FireServer()
		end,
	})
```
to:
```lua
	deleteBtn = createStyledButton({
		parent = confirmBtns,
		text = "💥   DELETE & RESTART",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.new(0, 0, 0, 52),
		primaryColor = COLORS.crimsonDark,
		gradientTop = COLORS.crimsonPrimary,
		gradientBottom = COLORS.crimsonDark,
		strokeColor = COLORS.crimsonLight,
		textColor = Color3.fromRGB(255, 220, 220),
		textSize = 13,
		font = Enum.Font.GothamBlack,
		onClick = function()
			creationFlowMode = "reforge"
			confirmFrame.Visible = false
			createFrame.Visible = true
		end,
	})
```

Note this button's `Active`/`Text` fields (`cancelBtn.Active = false`, `deleteBtn.Active = false`, `"DELETING..."`) are dropped here since the button no longer performs the final action itself — it now just navigates. `beginBtn` (on the picker screen it navigates to) is the button that ends up disabled/relabeled when the reforge is actually submitted, via Step 2's existing `beginBtn.Active = false` line.

- [ ] **Step 4: Verify sync**

Run in Bash: `grep -n "creationFlowMode" "src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua"` — expect 3 matches (declaration + 2 usages).

- [ ] **Step 5: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
git commit -m "feat: route reforge through the class picker instead of resetting to Tank"
```

---

### Task 7: `SkillTreeUIController` becomes class-driven

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua`

- [ ] **Step 1: Replace `BRANCH_ORDER` with a per-class table, add a `currentClassId` cache, and add `icon` to every `BRANCH_COLORS` entry**

Change:
```lua
local activeMobileBranch: string = "Bulwark"

local BRANCH_ORDER = {"Bulwark", "Juggernaut"}

local BRANCH_COLORS = {
	Bulwark = {
		primary = Color3.fromRGB(45, 140, 240),
		secondary = Color3.fromRGB(24, 75, 145),
		bg = Color3.fromRGB(18, 24, 34),
		cardBg = Color3.fromRGB(25, 34, 48),
		border = Color3.fromRGB(45, 110, 190),
		accent = Color3.fromRGB(110, 190, 255),
		name = "BULWARK",
		displayName = "BULWARK SPECIALIZATION",
		tagline = "Damage mitigation, sustain & party barriers",
	},
	Juggernaut = {
		primary = Color3.fromRGB(225, 65, 50),
		secondary = Color3.fromRGB(140, 35, 25),
		bg = Color3.fromRGB(32, 20, 20),
		cardBg = Color3.fromRGB(44, 26, 26),
		border = Color3.fromRGB(180, 50, 40),
		accent = Color3.fromRGB(255, 120, 100),
		name = "JUGGERNAUT",
		displayName = "JUGGERNAUT SPECIALIZATION",
		tagline = "Offense, heavy threat generation & stagger",
	},
}
```
to:
```lua
local currentClassId: string = "Tank"

local BRANCH_ORDER_BY_CLASS = {
	Tank = {"Bulwark", "Juggernaut"},
	Mage = {"Pyromancy", "Frostweave"},
}

local activeMobileBranch: string = BRANCH_ORDER_BY_CLASS.Tank[1]

local BRANCH_COLORS = {
	Bulwark = {
		primary = Color3.fromRGB(45, 140, 240),
		secondary = Color3.fromRGB(24, 75, 145),
		bg = Color3.fromRGB(18, 24, 34),
		cardBg = Color3.fromRGB(25, 34, 48),
		border = Color3.fromRGB(45, 110, 190),
		accent = Color3.fromRGB(110, 190, 255),
		icon = "🛡️",
		name = "BULWARK",
		displayName = "BULWARK SPECIALIZATION",
		tagline = "Damage mitigation, sustain & party barriers",
	},
	Juggernaut = {
		primary = Color3.fromRGB(225, 65, 50),
		secondary = Color3.fromRGB(140, 35, 25),
		bg = Color3.fromRGB(32, 20, 20),
		cardBg = Color3.fromRGB(44, 26, 26),
		border = Color3.fromRGB(180, 50, 40),
		accent = Color3.fromRGB(255, 120, 100),
		icon = "⚔️",
		name = "JUGGERNAUT",
		displayName = "JUGGERNAUT SPECIALIZATION",
		tagline = "Offense, heavy threat generation & stagger",
	},
	Pyromancy = {
		primary = Color3.fromRGB(230, 90, 30),
		secondary = Color3.fromRGB(150, 50, 15),
		bg = Color3.fromRGB(34, 20, 16),
		cardBg = Color3.fromRGB(46, 28, 20),
		border = Color3.fromRGB(200, 80, 30),
		accent = Color3.fromRGB(255, 150, 70),
		icon = "🔥",
		name = "PYROMANCY",
		displayName = "PYROMANCY SPECIALIZATION",
		tagline = "Explosive single-target and area fire damage",
	},
	Frostweave = {
		primary = Color3.fromRGB(60, 170, 230),
		secondary = Color3.fromRGB(25, 90, 130),
		bg = Color3.fromRGB(16, 26, 34),
		cardBg = Color3.fromRGB(22, 36, 46),
		border = Color3.fromRGB(50, 150, 200),
		accent = Color3.fromRGB(140, 220, 255),
		icon = "❄️",
		name = "FROSTWEAVE",
		displayName = "FROSTWEAVE SPECIALIZATION",
		tagline = "Sustained frost damage that lingers on enemies",
	},
}
```

- [ ] **Step 2: Fix the two `BRANCH_ORDER` usage sites**

Change:
```lua
			local tankData = Classes.Tank
			for _, branchName in ipairs(BRANCH_ORDER) do
```
(in the mobile branch-tabs loop) to:
```lua
			local classData = Classes[currentClassId] or Classes.Tank
			for _, branchName in ipairs(BRANCH_ORDER_BY_CLASS[currentClassId] or BRANCH_ORDER_BY_CLASS.Tank) do
```
And its next line:
```lua
				local branchInfo = tankData and tankData.branches and tankData.branches[branchName]
```
to:
```lua
				local branchInfo = classData and classData.branches and classData.branches[branchName]
```

Change:
```lua
		local tankData = Classes.Tank
		if tankData and tankData.branches then
			local branchesToShow = isMobile and {activeMobileBranch} or BRANCH_ORDER
```
(in the desktop/branch-column render) to:
```lua
		local classData = Classes[currentClassId] or Classes.Tank
		if classData and classData.branches then
			local branchesToShow = isMobile and {activeMobileBranch} or (BRANCH_ORDER_BY_CLASS[currentClassId] or BRANCH_ORDER_BY_CLASS.Tank)
```
And its later line:
```lua
				local branchInfo = tankData.branches[branchName]
```
to:
```lua
				local branchInfo = classData.branches[branchName]
```

- [ ] **Step 3: Fix the hardcoded Tank-only icon check in the mobile tab loop**

Change:
```lua
				local iconPrefix = branchName == "Bulwark" and "🛡️ " or "⚔️ "
				tabBtn.Text = ("%s%s (%d/%d)"):format(iconPrefix, colStyle.name, unlockedCount, totalCount)
```
to:
```lua
				tabBtn.Text = ("%s %s (%d/%d)"):format(colStyle.icon, colStyle.name, unlockedCount, totalCount)
```
(`colStyle` here is already `BRANCH_COLORS[branchName]`, which now has an `icon` field from Step 1 for all four branches — this replaces the old two-branch-only ternary with data that's correct for every branch of every class.)

- [ ] **Step 4: Cache `ClassId` from `CharacterDataChanged` and reset the mobile branch default on an actual class change**

Add this connection in `SkillTreeUIController.Start()`, right before the existing `Net.Get("SkillDataChanged")` connection:
```lua
	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(_level, _unspentEXP, classId)
		if classId and Classes[classId] and classId ~= currentClassId then
			currentClassId = classId
			activeMobileBranch = (BRANCH_ORDER_BY_CLASS[currentClassId] or BRANCH_ORDER_BY_CLASS.Tank)[1]
			if screenGui and screenGui.Enabled then
				refreshUI()
			end
		end
	end)
```
(Guarded on `classId ~= currentClassId` so a level-up's `CharacterDataChanged` fire — same class, just a new Level/EXP — doesn't reset whichever mobile tab the player currently has open.)

- [ ] **Step 5: Verify sync**

Run in Bash: `grep -n "currentClassId\|BRANCH_ORDER_BY_CLASS" "src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua"` — expect matches at the declaration, both former `tankData` sites (now `classData`), the mobile-tab loop, and the new `CharacterDataChanged` connection (7+ matches total).

- [ ] **Step 6: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua
git commit -m "feat: make SkillTreeUIController render the player's actual class"
```

---

### Task 8: Initialize `UnlockedSkills`/`EquippedSkills` to the chosen class's starting skill

**Files:**
- Modify: `src/ServerScriptService/Services/CharacterCreationService.lua`

**Why this task exists:** caught during Task 2's code quality review, not part of the original spec write-up. `PlayerDataService.lua`'s `DEFAULT_DATA.Character.UnlockedSkills`/`EquippedSkills` are hardcoded to `{"Taunt"}` (Tank's starter skill) for every new profile, and neither `onSubmitCharacterCreation` nor `onRequestCreateNewCharacter` ever resets them to match whichever class was actually chosen. Without this task, a new Mage character would spawn with Tank's "Taunt" as its only unlocked/equipped skill (not even a skill Mage's own skill tree contains) and zero copies of `Classes.Mage.startingSkills` (`{"ArcaneBolt"}`) — the class picker would let you *label* a character "Mage" without it actually having any Mage skill to cast. This must be fixed for the feature to do what it's for.

- [ ] **Step 1: Set both fields in `onSubmitCharacterCreation`**

Change (current code, already updated by Task 2):
```lua
	profile.Data.Character.Name = player.DisplayName
	profile.Data.Character.ClassId = validateClassId(classId)
	profile.Data.Character.HasCreatedCharacter = true
```
to:
```lua
	local validatedClassId = validateClassId(classId)
	profile.Data.Character.Name = player.DisplayName
	profile.Data.Character.ClassId = validatedClassId
	-- table.clone, not a direct reference -- Classes[validatedClassId].startingSkills must
	-- stay the same shared table for every player; SkillTreeService later mutates a
	-- character's own UnlockedSkills/EquippedSkills in place (table.insert), which would
	-- corrupt that shared class-data table for everyone if it weren't cloned here.
	profile.Data.Character.UnlockedSkills = table.clone(Classes[validatedClassId].startingSkills)
	profile.Data.Character.EquippedSkills = table.clone(Classes[validatedClassId].startingSkills)
	profile.Data.Character.HasCreatedCharacter = true
```

- [ ] **Step 2: Set both fields in `onRequestCreateNewCharacter`**

Change (current code, already updated by Task 2):
```lua
	profile.Data.Character.Level = 1
	profile.Data.Character.UnspentEXP = 999999
	profile.Data.Character.SkillPoints = 50
	profile.Data.Character.ClassId = validateClassId(classId)
	profile.Data.Character.Name = player.DisplayName
```
to:
```lua
	local validatedClassId = validateClassId(classId)
	profile.Data.Character.Level = 1
	profile.Data.Character.UnspentEXP = 999999
	profile.Data.Character.SkillPoints = 50
	profile.Data.Character.ClassId = validatedClassId
	profile.Data.Character.UnlockedSkills = table.clone(Classes[validatedClassId].startingSkills)
	profile.Data.Character.EquippedSkills = table.clone(Classes[validatedClassId].startingSkills)
	profile.Data.Character.Name = player.DisplayName
```
(A reforge is an explicit full reset — per the existing comment above this block, it already resets Level/UnspentEXP/SkillPoints, so resetting the skill loadout to match whatever class was just picked is consistent with that, not an expansion of what reforge already does. Without this, reforging from Tank to Mage would keep every previously-unlocked Tank skill.)

- [ ] **Step 3: Verify sync**

Run in Bash: `grep -n "validatedClassId\|UnlockedSkills\|EquippedSkills" "src/ServerScriptService/Services/CharacterCreationService.lua"` — expect `validatedClassId` declared and used 3 times in each handler (6 total), and `UnlockedSkills`/`EquippedSkills` each assigned twice (once per handler).

- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/Services/CharacterCreationService.lua
git commit -m "fix: initialize UnlockedSkills/EquippedSkills to the chosen class's starting skill"
```

---

### Task 9: Live verification in Roblox Studio

**No files modified.** This task confirms the previous 8 tasks actually work together in the running game, using the same Roblox Studio MCP connection already used earlier in this project (tool calls: `mcp__Roblox_Studio__list_roblox_studios`, `get_studio_state`, `script_grep`, `start_stop_play`, `execute_luau`, `get_console_output`).

- [ ] **Step 1: Confirm Rojo sync reached Studio**

```
mcp__Roblox_Studio__script_grep(query: "CLASS_CARD_INFO", studio_id: <id>)
```
Expected: a match in `StarterPlayer.StarterPlayerScripts.Controllers.CharacterCreationController`. If there's no match, Rojo's live sync has stalled (this happened once already earlier in this project) — tell the user to reconnect it in Studio before continuing; don't try to work around it.

- [ ] **Step 2: Start Play and drop straight into a fresh creation screen**

```
mcp__Roblox_Studio__start_stop_play(is_start: true, studio_id: <id>)
```
A brand-new Studio test profile already has `HasCreatedCharacter = false`, so the very first Play session already shows the creation screen with no setup needed. (If this has already been played through once in this Studio session, reset it first — `Server` datamodel — before restarting Play:
```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local PlayerDataService = require(game.ServerScriptService.Services.PlayerDataService)
local profile = PlayerDataService.GetProfile(player)
profile.Data.Character.HasCreatedCharacter = false
return "reset"
```
then stop and restart Play so `CharacterCreationService.handlePlayer` re-runs from that fresh state.)

- [ ] **Step 3: Load the input tools, then click through to Mage**

```
ToolSearch(query: "select:mcp__Roblox_Studio__user_mouse_input,mcp__Roblox_Studio__user_keyboard_input", max_results: 5)
```
Take a screenshot (`mcp__Roblox_Studio__screen_capture`) to see the rendered creation screen and locate the Mage card (right-hand card, per Task 5's `xScale = 0.515`) and the EMBARK button. Use `user_mouse_input` to click inside the Mage card's hitbox, then screenshot again — expect the Mage card's border to now be gold (`COLORS.goldPrimary`) and the Tank card's border to have dimmed back to `COLORS.slateBorder`, confirming `refreshClassCardSelection` ran. Then click EMBARK.

- [ ] **Step 4: Verify the Mage pick actually lands as the profile's ClassId, and starts with Mage's own skill**

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local PlayerDataService = require(game.ServerScriptService.Services.PlayerDataService)
local profile = PlayerDataService.GetProfile(player)
return profile.Data.Character.ClassId .. " | Unlocked: " .. table.concat(profile.Data.Character.UnlockedSkills, ",") .. " | Equipped: " .. table.concat(profile.Data.Character.EquippedSkills, ",")
```
(`datamodel_type: "Server"`). Expected: `"Mage | Unlocked: ArcaneBolt | Equipped: ArcaneBolt"`. This proves both the client→server class-selection path (card selection → `SubmitCharacterCreation:FireServer(selectedClassId)` → `validateClassId` → profile write) and Task 8's starting-skill fix worked, independent of anything client-side.

- [ ] **Step 5: Verify the client actually received `ClassId` and the skill tree renders Mage's branches**

Open the Skill Tree UI directly by calling the already-running controller's own toggle, rather than hunting for the HUD button's screen position:
```lua
local Players = game:GetService("Players")
local SkillTreeUIController = require(Players.LocalPlayer.PlayerScripts.Controllers.SkillTreeUIController)
SkillTreeUIController.Toggle()
return "toggled"
```
(`datamodel_type: "Client"`). Then screenshot:
```
mcp__Roblox_Studio__screen_capture(capture_id: "skilltree_mage_check", studio_id: <id>)
```
Expected: the branch tabs/columns show "PYROMANCY" and "FROSTWEAVE" (with 🔥/❄️ icons from Task 7), not "JUGGERNAUT"/"BULWARK".

- [ ] **Step 6: Check for errors**

```
mcp__Roblox_Studio__get_console_output(studio_id: <id>)
```
Expected: no new errors/warnings referencing `CharacterCreationController`, `SkillTreeUIController`, `CharacterCreationService`, `DungeonSessionService`, or `LevelUpService`.

- [ ] **Step 7: Stop play**

```
mcp__Roblox_Studio__start_stop_play(is_start: false, studio_id: <id>)
```

- [ ] **Step 8: Repeat Steps 2-6 once more, this time clicking EMBARK without touching either card**, to confirm the "click straight through without touching the picker" path (the one every existing player will take on their very next reforge, and the one the spec explicitly calls out) still spawns as Tank with Tank's skill tree, unchanged from before this plan. (`profile.Data.Character.ClassId` expected `"Tank"`, `UnlockedSkills`/`EquippedSkills` expected `{"Taunt"}`; skill tree expected to show "JUGGERNAUT"/"BULWARK".)

- [ ] **Step 9: Report results to the user**

Summarize what was verified (Mage path, default-Tank path, console cleanliness) and flag anything that didn't match expectations rather than silently proceeding.
