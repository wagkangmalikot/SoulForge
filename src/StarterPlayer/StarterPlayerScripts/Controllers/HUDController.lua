-- src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
-- Renders player HP bar, boss HP bar, telegraph ground indicators,
-- on-screen skill buttons (mobile + desktop), and click-to-target +
-- normal-attack combat controls.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)

local HUDController = {}

-- ── On-screen skill buttons (mobile & desktop) ─────────────────────────────
-- Four buttons, right-aligned above the bottom edge, one per Tank skill.
-- Each dims + shows a countdown while on cooldown, or a "Lv. X" label while
-- locked (spec section 2b) -- see the Heartbeat loop below for how the two
-- states are told apart.
-- Keyboard bindings (1-4) are also wired for desktop players.

local TANK_CLASS = Classes.Tank
local SKILL_ORDER = TANK_CLASS.skills  -- {"Taunt","ShieldBash","GuardStance","ProvokingStrike"}

local BUTTON_SIZE = 72      -- px, square
local BUTTON_GAP  = 10      -- px between buttons
local BOTTOM_MARGIN = 70    -- px above the bottom edge (clears the HP bar)
local RIGHT_MARGIN  = 16    -- px from the right edge

local KEYBINDS = {
	[Enum.KeyCode.One]   = 1,
	[Enum.KeyCode.Two]   = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four]  = 4,
}

-- cooldownEnds[skillId] = os.clock() when the cooldown expires (or nil if ready)
local cooldownEnds: {[string]: number} = {}

-- buttonFrames[skillId] = the outer Frame (so we can dim it)
local buttonFrames: {[string]: Frame} = {}
-- cooldownLabels[skillId] = the TextLabel showing remaining seconds (or "Lv. X" while locked)
local cooldownLabels: {[string]: TextLabel} = {}

-- Updated by CharacterDataChanged; defaults to 1 to match a fresh character's
-- starting level before the first sync arrives.
local currentLevel = 1

local totalButtons = #SKILL_ORDER

-- ── Click-to-target (spec 2c) ──────────────────────────────────────────────
-- Clicking a model tagged "Enemy" (BossAIService/MonsterAIService both tag
-- their spawned models) both selects it -- shown with a Highlight -- and
-- immediately fires the normal attack at it. There's no separate
-- select-then-attack step. Skills (below) act on whatever is currently
-- selected here, independent of the normal attack's own click.
local selectedTargetId: string? = nil
local selectedHighlight: Highlight? = nil

local function clearSelection()
	selectedTargetId = nil
	if selectedHighlight then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end
end

local function selectTarget(model: Model, targetId: string)
	if selectedHighlight then
		selectedHighlight:Destroy()
	end

	selectedTargetId = targetId

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 0.9, 0.2)
	highlight.OutlineTransparency = 0
	highlight.Parent = model
	selectedHighlight = highlight

	-- Clear the selection automatically if the target dies/despawns, so a
	-- stale highlight -- and a targetId the server would just reject as
	-- unknown anyway -- doesn't linger after a kill.
	model.Destroying:Connect(function()
		if selectedTargetId == targetId then
			clearSelection()
		end
	end)
end

local function fireSkill(skillId: string)
	-- The client's own cooldown tracking is DISPLAY ONLY (dimming the button,
	-- showing a countdown). It must never gate the remote itself: the server
	-- is the sole authority on whether a cast is actually allowed (cooldown,
	-- character alive, in range, etc. — see CombatService.onCastSkill). If we
	-- blocked the FireServer call here, a client-side guess that's wrong (e.g.
	-- a prior cast was rejected server-side because the target was out of
	-- range) would lock the player out of a skill the server would happily
	-- accept.
	Net.Get("CastSkill"):FireServer(skillId, selectedTargetId)

	-- Optimistically start showing the cooldown the moment the button is pressed;
	-- the server will silently reject duplicate fires within the window anyway.
	local skill = Skills[skillId]
	if skill then
		cooldownEnds[skillId] = os.clock() + skill.cooldown
	end
end

local function fireNormalAttack()
	if not selectedTargetId then
		return -- nothing selected -- nothing to attack
	end
	Net.Get("CastNormalAttack"):FireServer(selectedTargetId)
end

function HUDController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	screenGui.ResetOnSpawn = false
	-- Ignore the safe-area inset so bars + buttons reach the screen edges on mobile.
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- ── HP bars ────────────────────────────────────────────────────────────────

	local function makeBar(name: string, position: UDim2, color: Color3): (Frame, Frame)
		local background = Instance.new("Frame")
		background.Name = name
		background.Size = UDim2.new(0, 300, 0, 24)
		background.Position = position
		background.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
		background.Parent = screenGui

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BackgroundColor3 = color
		fill.Parent = background

		return background, fill
	end

	-- Player bar: bottom-left; boss bar: top-center.
	local _, playerHealthFill = makeBar("PlayerHealth", UDim2.new(0, 20, 1, -60), Color3.new(0.2, 0.9, 0.2))
	local _, bossHealthFill   = makeBar("BossHealth",   UDim2.new(0.5, -150, 0, 46), Color3.new(0.9, 0.2, 0.2))

	Net.Get("HealthChanged").OnClientEvent:Connect(function(userId, current, max)
		if userId == player.UserId then
			playerHealthFill.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0)
		end
	end)

	Net.Get("BossStateChanged").OnClientEvent:Connect(function(_bossId, _phaseIndex, current, max)
		bossHealthFill.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0)
	end)

	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(level, _unspentEXP)
		currentLevel = level
	end)

	-- ── Telegraph ground indicators ────────────────────────────────────────────

	Net.Get("TelegraphAttack").OnClientEvent:Connect(function(attackId, position, telegraphTime)
		local indicator = Instance.new("Part")
		indicator.Name = "TelegraphIndicator_" .. attackId
		indicator.Shape = Enum.PartType.Cylinder
		indicator.Size = Vector3.new(0.2, 16, 16)
		indicator.Orientation = Vector3.new(0, 0, 90)
		indicator.Position = position
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Color = Color3.new(1, 0.6, 0)
		indicator.Transparency = 0.5
		indicator.Parent = workspace

		task.delay(telegraphTime, function()
			indicator:Destroy()
		end)
	end)

	for i, skillId in SKILL_ORDER do
		local xOffset = RIGHT_MARGIN + (totalButtons - i) * (BUTTON_SIZE + BUTTON_GAP)

		local frame = Instance.new("Frame")
		frame.Name = "Skill_" .. skillId
		frame.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
		-- Anchor to bottom-right corner.
		frame.Position = UDim2.new(1, -xOffset - BUTTON_SIZE, 1, -BOTTOM_MARGIN - BUTTON_SIZE)
		frame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
		frame.BorderSizePixel = 2
		frame.Parent = screenGui
		buttonFrames[skillId] = frame

		-- Rounded corners via UICorner.
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
		nameLabel.Position = UDim2.new(0, 0, 0.1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextScaled = true
		nameLabel.Text = skillId
		nameLabel.Parent = frame

		local cdLabel = Instance.new("TextLabel")
		cdLabel.Name = "CooldownLabel"
		cdLabel.Size = UDim2.new(1, 0, 0.35, 0)
		cdLabel.Position = UDim2.new(0, 0, 0.65, 0)
		cdLabel.BackgroundTransparency = 1
		cdLabel.TextColor3 = Color3.new(1, 0.8, 0.3)
		cdLabel.TextScaled = true
		cdLabel.Text = ""
		cdLabel.Parent = frame
		cooldownLabels[skillId] = cdLabel

		-- Overlay that dims the button during cooldown or while locked.
		local dimOverlay = Instance.new("Frame")
		dimOverlay.Name = "DimOverlay"
		dimOverlay.Size = UDim2.new(1, 0, 1, 0)
		dimOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
		dimOverlay.BackgroundTransparency = 1  -- fully transparent when ready
		dimOverlay.ZIndex = 2
		dimOverlay.Parent = frame

		local dimCorner = Instance.new("UICorner")
		dimCorner.CornerRadius = UDim.new(0, 8)
		dimCorner.Parent = dimOverlay

		-- Tappable button sits on top (ZIndex 3 so it catches input above the overlay).
		local button = Instance.new("TextButton")
		button.Name = "HitArea"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 3
		button.Parent = frame

		local capturedSkillId = skillId  -- capture for the closure
		button.Activated:Connect(function()
			fireSkill(capturedSkillId)
		end)
	end

	-- Keyboard bindings for desktop (1-4 keys).
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		local index = KEYBINDS[input.KeyCode]
		if index then
			local skillId = SKILL_ORDER[index]
			if skillId then
				fireSkill(skillId)
			end
		end
	end)

	-- Click-to-target + normal attack: left-click raycasts from the camera
	-- through the mouse position; if it hits a model tagged "Enemy" (boss or
	-- trash mob), that model is selected and immediately attacked. Clicking
	-- anything else (terrain, a wall, empty space) does nothing -- no
	-- selection change, no attack, and the previous selection (if any) is
	-- left alone rather than cleared, so missing a click doesn't lose your
	-- current target.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local mouseLocation = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = player.Character and { player.Character } or {}
		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
		if not result then
			return
		end

		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		if not hitModel or not CollectionService:HasTag(hitModel, "Enemy") then
			return
		end

		selectTarget(hitModel, hitModel.Name)
		fireNormalAttack()
	end)

	-- Per-frame cooldown/lock display update.
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		for _, skillId in SKILL_ORDER do
			local frame  = buttonFrames[skillId]
			local cdLabel = cooldownLabels[skillId]
			local dimOverlay = frame:FindFirstChild("DimOverlay")
			local skill = Skills[skillId]
			local unlockLevel = skill and skill.unlockLevel or 1

			if currentLevel < unlockLevel then
				-- Locked: show the level requirement instead of a cooldown timer.
				cdLabel.Text = ("Lv. %d"):format(unlockLevel)
				if dimOverlay then
					dimOverlay.BackgroundTransparency = 0.55
				end
			else
				local expires = cooldownEnds[skillId]
				if expires and now < expires then
					local remaining = expires - now
					cdLabel.Text = ("%.1f"):format(remaining)
					if dimOverlay then
						dimOverlay.BackgroundTransparency = 0.55
					end
				else
					cdLabel.Text = ""
					if dimOverlay then
						dimOverlay.BackgroundTransparency = 1
					end
				end
			end
		end
	end)
end

return HUDController
