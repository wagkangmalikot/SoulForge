# Mobile Input Cleanup & Boss Gate Barrier Polish

**Date:** 2026-09-17
**Status:** Approved

This spec covers two small, independent changes requested together in the same conversation: removing PC-only keyboard shortcut UI/handling (the game targets mobile, not just PC), and improving the boss gate's sealed-barrier visual (found while testing the boss door mesh upgrade — the barrier now obscures the newly-sculpted doors). They touch different files and ship as two clearly separated parts of one plan.

## Part A: Remove keyboard-specific shortcuts and hints

### Problem

Three UI elements show PC keyboard key hints (`[F]`, `[K]`, `1`-`4` badges) and three input handlers respond to specific keyboard keys, even though the game is played on mobile as well as PC. Every one of these interactions already has an independent tap/click path that keeps working without the keyboard layer — the keyboard handling is pure PC-only addition, and the hint badges are actively confusing on a touchscreen where there's no physical key to press. There is no custom keyboard *movement* code anywhere in the codebase — character movement already goes through Roblox's built-in cross-platform control scheme (touch joystick / WASD / gamepad), so movement needs no changes.

### Changes

**[HUDController.lua](../../../src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua)**
- Remove the `KEYBINDS` table (`Enum.KeyCode.One`-`Four` → slot index, lines 34-39) — its only consumer is removed below
- In the `InputBegan` handler (~line 1255): remove the "Number keys for skills" branch (~1256-1266) and the "'F' key triggers Attack Button" branch (~1268-1272). The mouse-click/touch-tap 3D target-selection branch in the same handler is untouched — it is not a keyboard feature
- Update the handler's header comment (currently "Unified Input Handling (Desktop Keys, LMB, and Mobile Touch)") to reflect that it's now pointer-only
- Remove the `[F]` hotkey pill badge (`HotkeyBadge` frame + its `UICorner`/`UIStroke`/`TextLabel`, ~lines 968-997) under the attack button. The attack button's own `Activated` tap/click handler (`attackButton.Activated:Connect(triggerAttackButtonPress)`) is untouched
- Remove the `[1]`/`[2]`/`[3]`/`[4]` `KeyBadge` pill (frame + `UICorner`/`UIStroke`/`TextLabel`, ~lines 1118-1146) built per skill slot. Each slot's own `HitArea` `TextButton.Activated` tap/click handler is untouched
- Change `skillsMenuBtn.Text` from `"📜 SKILLS [K]"` to `"📜 SKILLS"` (the button itself, and its own click handler, stay)

**[SkillTreeUIController.lua](../../../src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua)**
- Remove the `'K'` hotkey `InputBegan` listener (~lines 585-593) in its entirety. The skills menu remains reachable via the `SKILLS` button in the HUD
- Remove the now-unused `local UserInputService = game:GetService("UserInputService")` import (its only use was the listener above)

**[CharacterCreationController.lua](../../../src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua)**
- On the intro splash screen's `InputBegan` handler (~lines 976-993): remove the `if input.UserInputType == Enum.UserInputType.Keyboard then ... end` branch entirely (this also drops the now-unneeded `UserInputService:GetFocusedTextBox()` call). Restructure the remaining `elseif` (mouse/touch/gamepad dismissal) into the handler's only `if` branch. `introHitbox.Activated` (fullscreen tap/click catcher) is untouched and already covers PC clicks, mobile taps, and gamepad independently
- Update the header comment above that block (currently "Also listen to all UserInputService inputs (any keyboard key, mouse click, touch, or gamepad)") to drop the keyboard mention
- Change `promptLabel.Text` from `"TAP OR PRESS ANY KEY TO ENTER"` to `"TAP TO ENTER"`

### Out of scope

- No changes to character movement (already cross-platform via Roblox's built-in control scheme)
- No changes to any server-side script — this is entirely client-side `StarterPlayerScripts` UI/input code
- `UserInputService` imports in `HUDController.lua` stay (still used for mouse/touch target-selection)

## Part B: Boss gate RunicBarrier visual polish

### Problem

`RunicBarrier` in [DungeonMapService.lua](../../../src/ServerScriptService/Services/DungeonMapService.lua) (~lines 434-445) is a single flat `Neon` `Part` (`Size = Vector3.new(25, WALL_HEIGHT - 4, 3.5)`, `Color = BARRIER_COLOR` i.e. `Color3.fromRGB(240, 110, 30)`, `Transparency = 0.4`) sitting directly in front of the boss chamber doors. At close range (confirmed via an in-game screenshot) it reads as a solid orange wall filling most of the screen, and now also hides the sculpted `BossVaultDoor_Left`/`_Right` meshes added in the prior door-upgrade work.

### Changes

All changes are to the `barrier` `Part`'s construction block (~lines 434-445) and its immediate surroundings in `DungeonMapService.BuildDungeon()`:

1. Raise `barrier.Transparency` from `0.4` to `0.65` so the sculpted doors are visible through it as a magical veil rather than hidden behind a solid wall.
2. Add a looping "breathing" tween on `barrier.Transparency`, oscillating between `0.55` and `0.78` (e.g. a `TweenService:Create` with `TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)`, played once at construction time) for a shimmering ward feel. `-1` repeat count loops indefinitely; `true` reverses direction each cycle so it breathes in and out smoothly.
3. Add a `ParticleEmitter` on the barrier part: upward-drifting rune/spark particles (`Color` matching `BARRIER_COLOR`, small `Size`, slow `Speed`, sparse `Rate`) for extra "magic seal" polish, following the same pattern already used for the hub portal's particle vortex in `HubMapService.lua`.

### Constraints

- `OpenBossGate()`'s existing barrier-destroy sequence (~lines 621-631: `CanCollide = false`, a `Transparency = 1` fade-out tween, then `:Destroy()` after 0.4s) is untouched and must still work correctly against a barrier that already has an active looping breathing tween running — the fade-out tween will simply override/take priority when it plays (`TweenService` replaces any prior tween on the same property when a new one targeting that property is created and played on the same instance). The looping breathing tween does not need to be explicitly cancelled; the part is destroyed shortly after the fade-out plays, which stops all active tweens on it.
- The particle emitter must be a child of the `barrier` `Part` so it's automatically destroyed alongside it in `OpenBossGate()`'s existing `gateBarrierPart:Destroy()` call — no separate cleanup needed.

### Out of scope

- No changes to `OpenBossGate()`, `SealBossGate()`, or `UnsealBossGate()` logic/timing
- No changes to the gate posts, arch, trim, doors, status billboard, or `GatePromptPart`/`ProximityPrompt`
- No new AI-generated mesh assets — this is a lighting/material/particle/tween tuning pass on the existing `Part`
