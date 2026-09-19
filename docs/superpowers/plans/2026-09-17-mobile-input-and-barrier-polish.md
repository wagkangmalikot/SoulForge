# Mobile Input Cleanup & Boss Gate Barrier Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove PC-only keyboard shortcut UI and handling from the client (the game targets mobile as well as PC), and improve the boss gate's `RunicBarrier` visual so it reads as a shimmering ward instead of a flat wall hiding the sculpted boss doors behind it.

**Architecture:** Part A is pure deletion/text-edits across three `StarterPlayerScripts` controller files — every keyboard-triggered action already has an independent tap/click path, so nothing needs to be added, only removed. Part B tunes three properties/additions (`Transparency`, a looping `Tween`, a `ParticleEmitter`) on one existing `Part` in `DungeonMapService.lua`.

**Tech Stack:** Roblox Studio (Luau), Rojo-synced `src/` tree, Roblox Studio MCP tools (`execute_luau`, `start_stop_play`, `screen_capture`, `get_console_output`) for live verification.

**Spec:** [docs/superpowers/specs/2026-09-17-mobile-input-and-barrier-polish-design.md](../specs/2026-09-17-mobile-input-and-barrier-polish-design.md)

**Studio target:** `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8` ("Soul Forge", placeId 125354010947424). Re-resolve with `list_roblox_studios` if this id is no longer connected when execution starts.

---

### Task 1: Remove keyboard shortcuts and hints from `HUDController.lua`

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua`

- [ ] **Step 1: Remove the `KEYBINDS` table**

Find (current lines 34-39):
```lua
local KEYBINDS = {
	[Enum.KeyCode.One]   = 1,
	[Enum.KeyCode.Two]   = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four]  = 4,
}

```
Delete this entire block (including the trailing blank line).

- [ ] **Step 2: Remove the `[F]` hotkey pill badge under the attack button**

Find (this exact block, currently around lines 968-998, immediately after `attackLabel.Parent = attackFrame` and before the `-- Cooldown Label on Attack Button` comment):
```lua
	-- Hotkey Pill Badge [F]
	local hotkeyBadge = Instance.new("Frame")
	hotkeyBadge.Name = "HotkeyBadge"
	hotkeyBadge.Size = UDim2.new(0, 36, 0, 18)
	hotkeyBadge.Position = UDim2.new(0.5, -18, 0.72, 0)
	hotkeyBadge.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	hotkeyBadge.BackgroundTransparency = 0.25
	hotkeyBadge.BorderSizePixel = 0
	hotkeyBadge.ZIndex = 2
	hotkeyBadge.Parent = attackFrame

	local hotkeyCorner = Instance.new("UICorner")
	hotkeyCorner.CornerRadius = UDim.new(0, 4)
	hotkeyCorner.Parent = hotkeyBadge

	local hotkeyStroke = Instance.new("UIStroke")
	hotkeyStroke.Color = Color3.fromRGB(220, 180, 75)
	hotkeyStroke.Thickness = 1.2
	hotkeyStroke.Parent = hotkeyBadge

	local hotkeyLabel = Instance.new("TextLabel")
	hotkeyLabel.Name = "HotkeyLabel"
	hotkeyLabel.Size = UDim2.new(1, 0, 1, 0)
	hotkeyLabel.BackgroundTransparency = 1
	hotkeyLabel.Font = Enum.Font.GothamBold
	hotkeyLabel.TextColor3 = Color3.fromRGB(255, 225, 120)
	hotkeyLabel.TextSize = 11
	hotkeyLabel.Text = "[F]"
	hotkeyLabel.ZIndex = 3
	hotkeyLabel.Parent = hotkeyBadge

```
Delete this entire block (including the trailing blank line). Do not touch `attackLabel` above it or the `-- Cooldown Label on Attack Button` section below it.

- [ ] **Step 3: Change the skills menu button text**

Find:
```lua
	skillsMenuBtn.Text = "📜 SKILLS [K]"
```
Replace with:
```lua
	skillsMenuBtn.Text = "📜 SKILLS"
```

- [ ] **Step 4: Remove the `[1]`-`[4]` key-badge pill from each skill slot**

Find (this exact block, currently around lines 1118-1147, between `slotStrokes[i] = stroke` and the `-- Icon Label` comment):
```lua
		-- Keybind Indicator Pill [1-4]
		local keyBadge = Instance.new("Frame")
		keyBadge.Name = "KeyBadge"
		keyBadge.Size = UDim2.new(0, 18, 0, 15)
		keyBadge.Position = UDim2.new(0, 3, 0, 3)
		keyBadge.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
		keyBadge.BackgroundTransparency = 0.15
		keyBadge.BorderSizePixel = 0
		keyBadge.ZIndex = 2
		keyBadge.Parent = frame

		local keyCorner = Instance.new("UICorner")
		keyCorner.CornerRadius = UDim.new(0, 4)
		keyCorner.Parent = keyBadge

		local keyStroke = Instance.new("UIStroke")
		keyStroke.Color = Color3.fromRGB(180, 140, 50)
		keyStroke.Thickness = 1
		keyStroke.Parent = keyBadge

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(1, 0, 1, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 10
		keyLabel.Text = tostring(i)
		keyLabel.ZIndex = 3
		keyLabel.Parent = keyBadge

```
Delete this entire block (including the trailing blank line). Do not touch `slotStrokes[i] = stroke` above it or the `-- Icon Label` section below it.

- [ ] **Step 5: Remove the keyboard branches from the `InputBegan` handler, keep the pointer-targeting branch**

Find (this exact block):
```lua
	-- ── Unified Input Handling (Desktop Keys, LMB, and Mobile Touch) ───────────
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Number keys for skills
		local index = KEYBINDS[input.KeyCode]
		if index and not gameProcessed then
			local skillId = equippedSkills[index]
			if skillId then
				fireSkill(skillId)
			else
				SkillTreeUIController.Toggle()
			end
			return
		end

		-- 'F' key triggers Attack Button on desktop
		if input.KeyCode == Enum.KeyCode.F and not gameProcessed then
			triggerAttackButtonPress()
			return
		end

		-- Mouse Click or Mobile Touch Tap: selecting targets in 3D world only (NO attack)
```
Replace with:
```lua
	-- ── Pointer Input Handling (Mouse Click and Mobile Touch) ───────────────────
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Mouse Click or Mobile Touch Tap: selecting targets in 3D world only (NO attack)
```

- [ ] **Step 6: Confirm no leftover references**

Run:
```bash
grep -n "KEYBINDS\|KeyCode\|HotkeyBadge\|KeyBadge" "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua"
```
Expected: no output (zero matches). If anything still matches, you missed a reference — go back and remove it.

---

### Task 2: Remove the `'K'` hotkey listener from `SkillTreeUIController.lua`

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua`

- [ ] **Step 1: Remove the `'K'` hotkey listener**

Find (this exact block):
```lua
	-- Input Listener for 'K' hotkey
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			SkillTreeUIController.Toggle()
		end
	end)

```
Delete this entire block (including the trailing blank line).

- [ ] **Step 2: Remove the now-unused `UserInputService` import**

Find:
```lua
local UserInputService = game:GetService("UserInputService")
```
Delete this line. It's on its own line near the top of the file among other `game:GetService(...)` locals — remove only this one line, leave the others untouched.

- [ ] **Step 3: Confirm no leftover references**

Run:
```bash
grep -n "UserInputService\|KeyCode" "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua"
```
Expected: no output (zero matches).

---

### Task 3: Remove the keyboard-dismiss branch from `CharacterCreationController.lua`

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua`

- [ ] **Step 1: Update the intro prompt text**

Find:
```lua
	promptLabel.Text = "TAP OR PRESS ANY KEY TO ENTER"
```
Replace with:
```lua
	promptLabel.Text = "TAP TO ENTER"
```

- [ ] **Step 2: Remove the keyboard branch from the intro's `InputBegan` handler**

Find (this exact block):
```lua
	-- Also listen to all UserInputService inputs (any keyboard key, mouse click, touch, or gamepad)
	inputConnection = UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if introDismissed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if UserInputService:GetFocusedTextBox() == nil then
				dismissIntro()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.Gamepad1 then
			dismissIntro()
		end
	end)
```
Replace with:
```lua
	-- Also listen to all UserInputService pointer inputs (mouse click, touch, or gamepad)
	inputConnection = UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if introDismissed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.Gamepad1 then
			dismissIntro()
		end
	end)
```

- [ ] **Step 3: Confirm no leftover references and that `introHitbox` is untouched**

Run:
```bash
grep -n "UserInputType.Keyboard\|GetFocusedTextBox\|PRESS ANY KEY\|introHitbox" "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua"
```
Expected: no match for `UserInputType.Keyboard`, `GetFocusedTextBox`, or `PRESS ANY KEY`. The `introHitbox` matches (its declaration and its `Activated:Connect(function() dismissIntro() end)` from ~line 972) should still be present and unchanged — confirm by eye that those two lines are still there verbatim.

---

### Task 4: Polish the boss gate `RunicBarrier` visual

**Files:**
- Modify: `src/ServerScriptService/Services/DungeonMapService.lua`

- [ ] **Step 1: Raise the barrier's base transparency and add the breathing tween and particle emitter**

Find (this exact block, currently lines 434-445):
```lua
	-- Glowing Runic Barrier Part (blocks passage until guardians are defeated)
	local barrier = Instance.new("Part")
	barrier.Name = "RunicBarrier"
	barrier.Size = Vector3.new(25, WALL_HEIGHT - 4, 3.5)
	barrier.CFrame = CFrame.new(0, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ)
	barrier.Color = BARRIER_COLOR
	barrier.Material = Enum.Material.Neon
	barrier.Transparency = 0.4
	barrier.CanCollide = true
	barrier.Anchored = true
	barrier.Parent = gateModel
	gateBarrierPart = barrier
```
Replace with:
```lua
	-- Glowing Runic Barrier Part (blocks passage until guardians are defeated).
	-- Transparency is high enough, and pulses further, so the sculpted vault
	-- doors behind it stay visible as a shimmering ward rather than a flat wall.
	local barrier = Instance.new("Part")
	barrier.Name = "RunicBarrier"
	barrier.Size = Vector3.new(25, WALL_HEIGHT - 4, 3.5)
	barrier.CFrame = CFrame.new(0, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ)
	barrier.Color = BARRIER_COLOR
	barrier.Material = Enum.Material.Neon
	barrier.Transparency = 0.65
	barrier.CanCollide = true
	barrier.Anchored = true
	barrier.Parent = gateModel
	gateBarrierPart = barrier

	-- Looping breathing pulse: OpenBossGate()'s fade-out tween (created later,
	-- when the gate unlocks) targets the same Transparency property and takes
	-- over cleanly when it plays; this loop doesn't need to be cancelled
	-- explicitly because the barrier is destroyed shortly after that fade-out.
	local barrierPulse = TweenService:Create(
		barrier,
		TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.78 }
	)
	barrierPulse:Play()

	local barrierSparkles = Instance.new("ParticleEmitter")
	barrierSparkles.Color = ColorSequence.new(BARRIER_COLOR)
	barrierSparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	barrierSparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	barrierSparkles.Lifetime = NumberRange.new(1.5, 2.5)
	barrierSparkles.Rate = 12
	barrierSparkles.Speed = NumberRange.new(1, 2)
	barrierSparkles.SpreadAngle = Vector2.new(15, 15)
	barrierSparkles.Parent = barrier
```

- [ ] **Step 2: Confirm `OpenBossGate()` and `SealBossGate()`/`UnsealBossGate()` are untouched**

Run:
```bash
grep -n "function DungeonMapService.OpenBossGate\|function DungeonMapService.SealBossGate\|function DungeonMapService.UnsealBossGate" "Soulforge/src/ServerScriptService/Services/DungeonMapService.lua"
```
Read each of those three functions and confirm none of them were edited by Step 1 (Step 1 only touches the `barrier` construction block, which sits before all three function definitions).

---

### Task 5: Live verification and commit

**Files:**
- (verifies) `src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua`
- (verifies) `src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua`
- (verifies) `src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua`
- (verifies) `src/ServerScriptService/Services/DungeonMapService.lua`

- [ ] **Step 1: Confirm Studio is in Edit mode, then start Play**

Call `mcp__Roblox_Studio__get_studio_state` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`. If `Play`, call `start_stop_play` with `is_start: false` first. Then call `start_stop_play` with `is_start: true`.

- [ ] **Step 2: Check console for errors**

Call `mcp__Roblox_Studio__get_console_output` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`.

Expected: no Luau errors referencing `HUDController`, `SkillTreeUIController`, `CharacterCreationController`, or `DungeonMapService` (pre-existing unrelated noise like the `Failed to load animation with sanitized ID rbxassetid://180426353` lines is expected and not a regression).

- [ ] **Step 3: Screenshot the intro splash screen**

Call `mcp__Roblox_Studio__screen_capture` with `studio_id: c5d8b37d-c354-423f-8ca6-424fedd19ce8`, `capture_id: "intro_no_keyboard_hint"`.

Expected: prompt reads "TAP TO ENTER" (not "TAP OR PRESS ANY KEY TO ENTER").

- [ ] **Step 4: Dismiss the intro and reach the HUD, then screenshot the action bar**

Click through hero selection the same way prior verification passes in this project did: `mcp__Roblox_Studio__user_mouse_input` with a `moveTo` + `mouseButtonClick` on the "ENTER REALM" button (screenshot first to find its current coordinates, since layout can shift), then `screen_capture` the bottom-right action bar.

Expected: the attack button has no `[F]` badge, the skill slots have no `1`/`2`/`3`/`4` badges, and the skills menu button reads "📜 SKILLS" with no "[K]".

- [ ] **Step 5: Confirm tap/click still works for the skills menu button and a skill slot**

Use `mcp__Roblox_Studio__user_mouse_input` to click the "SKILLS" button and confirm (via `screen_capture`) the skill tree UI opens. Close it, then click a skill slot's hit area and confirm (via `get_console_output` or a visible cooldown/label change) it still fires.

- [ ] **Step 6: Screenshot the boss gate barrier**

Navigate/camera to the boss gate (same approach as the boss-door verification: `gateZ = -25` in `RockhideArena`-local coordinates) and call `screen_capture`.

Expected: the barrier now visibly pulses/shimmers rather than reading as a flat solid orange wall, and the sculpted door carving is visible through it. (A single screenshot only catches one frame of the pulse — if it happens to land on a more-opaque frame, take a second screenshot a second or two later and compare.)

- [ ] **Step 7: Stop Play**

Call `start_stop_play` with `is_start: false`.

- [ ] **Step 8: Commit**

```bash
git add "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua" "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua" "Soulforge/src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua" "Soulforge/src/ServerScriptService/Services/DungeonMapService.lua"
git commit -m "$(cat <<'EOF'
Remove keyboard-only shortcuts/hints and polish boss gate barrier

The game targets mobile as well as PC, so drops the PC-only keyboard
shortcut handling (F/K/1-4 keys) and their on-screen key-hint badges
from the HUD, skill tree toggle, and intro splash screen -- every one
of these already has an independent tap/click path that keeps working
unchanged. Also raises the boss gate RunicBarrier's transparency and
adds a breathing pulse tween plus a particle emitter so it reads as a
shimmering ward instead of a flat wall hiding the sculpted vault doors
behind it.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Notes for whoever executes this plan

- Tasks 1-3 (Part A) and Task 4 (Part B) touch disjoint files and have no dependencies on each other — they can be done in any order, or in parallel by different subagents, as long as Task 5's verification waits for all four to be complete.
- If Task 5 Step 4's "ENTER REALM" button click doesn't register on the first try, retry with a second click a moment later — this project's prior verification passes (hub mesh upgrade, boss door upgrade) both hit this same UI-click flakiness and a retry always resolved it.
