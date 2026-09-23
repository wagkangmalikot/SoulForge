-- src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
-- Renders player HP bar, boss HP bar, telegraph ground indicators,
-- on-screen skill buttons (mobile + desktop), normal attack button with ⚔️ icon,
-- and click-to-target + auto-targeting combat controls.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Equipment = require(ReplicatedStorage.Shared.Data.Equipment)
local BossAttacks = require(ReplicatedStorage.Shared.Data.BossAttacks)
local WeaponController = require(script.Parent.WeaponController)
local SkillTreeUIController = require(script.Parent.SkillTreeUIController)
local CraftingUIController = require(script.Parent.CraftingUIController)
local InventoryUIController = require(script.Parent.InventoryUIController)

local HUDController = {}

-- ── Button Layout & Sizing ──────────────────────────────────────────────────
local TOTAL_SLOTS = 4
local equippedSkills: {string} = {"Taunt"}

local ATTACK_BUTTON_SIZE = 86   -- px circular primary action button
local SKILL_BUTTON_SIZE  = 58   -- px compact skill buttons in radial arc
local ATTACK_POS_X       = -148 -- px from right edge (leaves clear room for mobile jump button)
local ATTACK_POS_Y       = -80  -- px from bottom edge

-- Radial arc offsets relative to (ATTACK_POS_X, ATTACK_POS_Y)
local SKILL_SLOT_OFFSETS = {
	[1] = Vector2.new(-82, 0),     -- Slot 1 (Taunt): 9:00 (left)
	[2] = Vector2.new(-62, -62),   -- Slot 2: 10:30 (up-left)
	[3] = Vector2.new(0, -82),     -- Slot 3: 12:00 (up)
	[4] = Vector2.new(62, -62),    -- Slot 4: 1:30 (up-right)
}

local TARGET_RAYCAST_DISTANCE = 500

local cooldownEnds: {[string]: number} = {}
local slotFrames: {[number]: Frame} = {}
local slotNameLabels: {[number]: TextLabel} = {}
local slotIconLabels: {[number]: TextLabel} = {}
local slotCdLabels: {[number]: TextLabel} = {}
local slotDimOverlays: {[number]: Frame} = {}
local slotStrokes: {[number]: UIStroke} = {}

local normalAttackCooldownEnd = 0
local attackDimOverlay: Frame? = nil
local attackCdLabel: TextLabel? = nil

local currentLevel = 1
local levelBadgeText: TextLabel? = nil
local currentClassId = "Tank"
local attackIconLabel: TextLabel? = nil
local classBadgeIcon: TextLabel? = nil
local playerNameLabel: TextLabel? = nil

local HUD_CLASS_VISUALS = {
	Tank = {
		attackIcon = "⚔️",
		badgeIcon = "🛡️",
		title = "SHIELD GUARDIAN",
	},
	Mage = {
		attackIcon = "🔮",
		badgeIcon = "🔮",
		title = "ARCANE MAGE",
	},
	Warrior = {
		attackIcon = "⚔️",
		badgeIcon = "⚔️",
		title = "BATTLE WARRIOR",
	},
}

local function updateClassVisuals()
	local visuals = HUD_CLASS_VISUALS[currentClassId] or HUD_CLASS_VISUALS.Tank
	if attackIconLabel then
		attackIconLabel.Text = visuals.attackIcon
	end
	if classBadgeIcon then
		classBadgeIcon.Text = visuals.badgeIcon
	end
	if playerNameLabel then
		local player = Players.LocalPlayer
		local dName = (player and player.DisplayName) or "Hero"
		playerNameLabel.Text = dName .. "  •  [" .. visuals.title .. "]"
	end
end

local function formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

-- ── Target Selection & Auto-Targeting ───────────────────────────────────────
local selectedTargetId: string? = nil
local selectedHighlight: Highlight? = nil
local selectedDestroyingConnection: RBXScriptConnection? = nil

local function clearSelection()
	selectedTargetId = nil
	if selectedHighlight then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end
	if selectedDestroyingConnection then
		selectedDestroyingConnection:Disconnect()
		selectedDestroyingConnection = nil
	end
end

local function selectTarget(model: Model, targetId: string)
	if selectedHighlight then
		selectedHighlight:Destroy()
	end
	if selectedDestroyingConnection then
		selectedDestroyingConnection:Disconnect()
	end

	selectedTargetId = targetId

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 0.9, 0.2)
	highlight.OutlineTransparency = 0
	highlight.Parent = model
	selectedHighlight = highlight

	selectedDestroyingConnection = model.Destroying:Connect(function()
		if selectedTargetId == targetId then
			clearSelection()
		end
	end)
end

local function findTaggedEnemyAncestor(instance: Instance): Model?
	local current: Instance? = instance
	while current do
		if current:IsA("Model") and CollectionService:HasTag(current, "Enemy") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function getNearestEnemy(maxDistance: number): (Model?, string?)
	local localPlayer = Players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local nearestModel: Model? = nil
	local nearestDist = maxDistance or 60

	for _, enemy in CollectionService:GetTagged("Enemy") do
		if enemy:IsA("Model") and enemy.Parent then
			local primaryPart = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				local dist = (primaryPart.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestModel = enemy
				end
			end
		end
	end

	if nearestModel then
		return nearestModel, nearestModel.Name
	end
	return nil, nil
end

local function createSkillImageIcon(parent: Instance, imageId: string): ImageLabel
	local existing = parent:FindFirstChild("SkillImageIcon")
	if existing and existing:IsA("ImageLabel") then
		existing.Image = imageId
		existing.Size = UDim2.new(1, 0, 1, 0)
		existing.Position = UDim2.new(0.5, 0, 0.5, 0)
		existing.AnchorPoint = Vector2.new(0.5, 0.5)
		existing.ScaleType = Enum.ScaleType.Crop
		existing.BackgroundTransparency = 1
		existing.Visible = true
		local corner = existing:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 8)
		end
		local stroke = existing:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke:Destroy()
		end
		return existing
	end

	local iconImg = Instance.new("ImageLabel")
	iconImg.Name = "SkillImageIcon"
	iconImg.Size = UDim2.new(1, 0, 1, 0)
	iconImg.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImg.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	iconImg.BackgroundTransparency = 1
	iconImg.BorderSizePixel = 0
	iconImg.ScaleType = Enum.ScaleType.Crop
	iconImg.Image = imageId
	iconImg.ZIndex = 2
	iconImg.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = iconImg

	return iconImg
end

local function updateSkillButtons()
	for i = 1, TOTAL_SLOTS do
		local skillId = equippedSkills[i]
		local skill = skillId and Skills[skillId]
		local frame = slotFrames[i]
		local nameLabel = slotNameLabels[i]
		local iconLabel = slotIconLabels[i]
		local stroke = slotStrokes[i]

		if not frame or not nameLabel or not iconLabel or not stroke then
			continue
		end

		local skillImage = frame:FindFirstChild("SkillImageIcon")
		local oldDrawn = frame:FindFirstChild("DrawnTauntIcon")
		if oldDrawn then
			oldDrawn:Destroy()
		end

		if skill then
			frame.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
			stroke.Color = Color3.fromRGB(220, 180, 75)
			stroke.Thickness = 1.8
			nameLabel.Text = skill.displayName or skillId
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

			local isImage = skill.icon and (string.find(skill.icon, "rbxasset") ~= nil or string.find(skill.icon, "http") ~= nil)
			if isImage or skillId == "Taunt" then
				iconLabel.Visible = false
				local imgPath = skill.icon or "rbxasset://textures/Soulforge/taunt_icon.png"
				createSkillImageIcon(frame, imgPath)
			else
				if skillImage then
					skillImage.Visible = false
				end
				iconLabel.Visible = true
				iconLabel.Text = skill.icon or "⚔️"
			end
		else
			if skillImage then
				skillImage.Visible = false
			end
			frame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
			stroke.Color = Color3.fromRGB(55, 62, 75)
			stroke.Thickness = 1.4
			nameLabel.Text = "EQUIP"
			nameLabel.TextColor3 = Color3.fromRGB(130, 140, 160)
			iconLabel.Visible = true
			iconLabel.Text = "+"
		end
	end
end

local function fireSkill(skillId: string)
	local skill = Skills[skillId]
	if not skill then
		return
	end

	local now = os.clock()
	local expires = cooldownEnds[skillId]
	if expires and now < expires then
		return
	end

	-- Auto-target nearest only if skill is a single-target enemy skill (e.g. ProvokingStrike, ShieldBash)
	-- AoE and self buffs (Taunt, Earthshaker, IronWill, FortressAura, Meteor, Blizzard) cast freely around the player / target area
	local isAoeOrSelf = (skillId == "Taunt" or skillId == "Earthshaker" or skillId == "IronWill" or skillId == "FortressAura" or skillId == "Meteor" or skillId == "Blizzard")
	if skill.range > 0 and not isAoeOrSelf then
		if not selectedTargetId or not workspace:FindFirstChild(selectedTargetId, true) then
			local nearestModel, nearestId = getNearestEnemy(60)
			if nearestModel and nearestId then
				selectTarget(nearestModel, nearestId)
			else
				return
			end
		end
	end

	cooldownEnds[skillId] = now + (skill.cooldown or 0)

	Net.Get("CastSkill"):FireServer(skillId, selectedTargetId)

	local char = Players.LocalPlayer.Character
	if char then
		WeaponController.PlaySwing(char, skillId)
	end
end

local function fireNormalAttack()
	local now = os.clock()
	if now < normalAttackCooldownEnd then
		return
	end
	normalAttackCooldownEnd = now + 0.6

	-- 1. Always play local weapon swing immediately for responsive feedback
	local char = Players.LocalPlayer.Character
	if char then
		WeaponController.PlaySwing(char, (currentClassId == "Mage") and "ArcaneBolt" or "Slash")
	end

	-- 2. Target resolution: use selected target if valid, or auto-target closest enemy in range (40 studs)
	local targetIdToSend = selectedTargetId
	local currentModel = targetIdToSend and workspace:FindFirstChild(targetIdToSend, true)
	if not targetIdToSend or not currentModel or not currentModel.Parent then
		local nearestModel, nearestId = getNearestEnemy(40)
		if nearestModel and nearestId then
			selectTarget(nearestModel, nearestId)
			targetIdToSend = nearestId
		else
			targetIdToSend = nil
		end
	end

	-- 3. Notify server to deal damage to target (or closest in melee reach)
	Net.Get("CastNormalAttack"):FireServer(targetIdToSend)
end


function HUDController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- ── Responsive HUD Scale Containers (Scales up cleanly on Laptop & Desktop) ─
	local hudScales: {UIScale} = {}

	local topLeftContainer = Instance.new("Frame")
	topLeftContainer.Name = "TopLeftContainer"
	topLeftContainer.AnchorPoint = Vector2.new(0, 0)
	topLeftContainer.Position = UDim2.new(0, 0, 0, 0)
	topLeftContainer.Size = UDim2.new(0, 0, 0, 0)
	topLeftContainer.BackgroundTransparency = 1
	topLeftContainer.Parent = screenGui

	local scaleTL = Instance.new("UIScale")
	scaleTL.Name = "ScaleTL"
	scaleTL.Parent = topLeftContainer
	table.insert(hudScales, scaleTL)

	local topCenterContainer = Instance.new("Frame")
	topCenterContainer.Name = "TopCenterContainer"
	topCenterContainer.AnchorPoint = Vector2.new(0.5, 0)
	topCenterContainer.Position = UDim2.new(0.5, 0, 0, 0)
	topCenterContainer.Size = UDim2.new(0, 0, 0, 0)
	topCenterContainer.BackgroundTransparency = 1
	topCenterContainer.Parent = screenGui

	local scaleTC = Instance.new("UIScale")
	scaleTC.Name = "ScaleTC"
	scaleTC.Parent = topCenterContainer
	table.insert(hudScales, scaleTC)

	local topRightContainer = Instance.new("Frame")
	topRightContainer.Name = "TopRightContainer"
	topRightContainer.AnchorPoint = Vector2.new(1, 0)
	topRightContainer.Position = UDim2.new(1, 0, 0, 0)
	topRightContainer.Size = UDim2.new(0, 0, 0, 0)
	topRightContainer.BackgroundTransparency = 1
	topRightContainer.Parent = screenGui

	local scaleTR = Instance.new("UIScale")
	scaleTR.Name = "ScaleTR"
	scaleTR.Parent = topRightContainer
	table.insert(hudScales, scaleTR)

	local bottomRightContainer = Instance.new("Frame")
	bottomRightContainer.Name = "BottomRightContainer"
	bottomRightContainer.AnchorPoint = Vector2.new(1, 1)
	bottomRightContainer.Position = UDim2.new(1, 0, 1, 0)
	bottomRightContainer.Size = UDim2.new(0, 0, 0, 0)
	bottomRightContainer.BackgroundTransparency = 1
	bottomRightContainer.Parent = screenGui

	local scaleBR = Instance.new("UIScale")
	scaleBR.Name = "ScaleBR"
	scaleBR.Parent = bottomRightContainer
	table.insert(hudScales, scaleBR)

	local function updateHudScale()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vp = camera.ViewportSize
		if vp.X <= 0 or vp.Y <= 0 then return end

		-- Reference mobile height is ~420px. On larger screens (laptops, desktop monitors), scale smoothly up.
		local scaleY = vp.Y / 420
		local targetScale = 1.0 + math.pow(math.max(0, scaleY - 1.0), 0.8) * 0.55
		local clampedScale = math.clamp(targetScale, 1.0, 1.95)

		for _, s in ipairs(hudScales) do
			s.Scale = clampedScale
		end
	end

	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateHudScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCam = workspace.CurrentCamera
		if newCam then
			newCam:GetPropertyChangedSignal("ViewportSize"):Connect(updateHudScale)
			updateHudScale()
		end
	end)
	updateHudScale()

	-- ── Player Unit Frame (Top-Left: leaves bottom-left 100% free for mobile joystick) ─
	local playerFrame = Instance.new("Frame")
	playerFrame.Name = "PlayerUnitFrame"
	playerFrame.Size = UDim2.new(0, 280, 0, 58)
	playerFrame.Position = UDim2.new(0, 16, 0, 48)
	playerFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	playerFrame.BackgroundTransparency = 0.15
	playerFrame.BorderSizePixel = 0
	playerFrame.Parent = topLeftContainer

	local playerFrameCorner = Instance.new("UICorner")
	playerFrameCorner.CornerRadius = UDim.new(0, 8)
	playerFrameCorner.Parent = playerFrame

	local playerFrameStroke = Instance.new("UIStroke")
	playerFrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	playerFrameStroke.Color = Color3.fromRGB(180, 145, 60)
	playerFrameStroke.Thickness = 1.6
	playerFrameStroke.Parent = playerFrame

	local playerFrameGradient = Instance.new("UIGradient")
	playerFrameGradient.Rotation = 45
	playerFrameGradient.Color = ColorSequence.new(Color3.fromRGB(24, 28, 38), Color3.fromRGB(14, 16, 22))
	playerFrameGradient.Parent = playerFrame

	-- Level / Class Shield Badge (Left)
	local levelBadge = Instance.new("Frame")
	levelBadge.Name = "LevelBadge"
	levelBadge.Size = UDim2.new(0, 44, 0, 44)
	levelBadge.Position = UDim2.new(0, 6, 0.5, -22)
	levelBadge.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
	levelBadge.BorderSizePixel = 0
	levelBadge.Parent = playerFrame

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 7)
	badgeCorner.Parent = levelBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(220, 180, 75)
	badgeStroke.Thickness = 1.4
	badgeStroke.Parent = levelBadge

	local badgeIcon = Instance.new("TextLabel")
	badgeIcon.Name = "ClassIcon"
	badgeIcon.Size = UDim2.new(1, 0, 0.46, 0)
	badgeIcon.Position = UDim2.new(0, 0, 0.02, 0)
	badgeIcon.BackgroundTransparency = 1
	badgeIcon.Text = "🛡️"
	badgeIcon.TextScaled = true
	badgeIcon.Parent = levelBadge
	classBadgeIcon = badgeIcon

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelText"
	levelLabel.Size = UDim2.new(1, 0, 0.44, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.50, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextColor3 = Color3.fromRGB(255, 225, 120)
	levelLabel.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	levelLabel.TextStrokeTransparency = 0.2
	levelLabel.TextScaled = true
	levelLabel.Text = "Lv. " .. tostring(currentLevel)
	levelLabel.Parent = levelBadge
	levelBadgeText = levelLabel

	-- Player Name & Class Subtitle
	playerNameLabel = Instance.new("TextLabel")
	playerNameLabel.Name = "PlayerName"
	playerNameLabel.Size = UDim2.new(1, -58, 0, 20)
	playerNameLabel.Position = UDim2.new(0, 56, 0, 4)
	playerNameLabel.BackgroundTransparency = 1
	playerNameLabel.Font = Enum.Font.GothamBold
	playerNameLabel.TextSize = 15.5
	playerNameLabel.TextColor3 = Color3.fromRGB(240, 242, 248)
	playerNameLabel.TextStrokeColor3 = Color3.fromRGB(12, 14, 18)
	playerNameLabel.TextStrokeTransparency = 0.3
	playerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	playerNameLabel.Text = player.DisplayName .. "  •  [SHIELD GUARDIAN]"
	playerNameLabel.Parent = playerFrame
	updateClassVisuals()

	-- Health Bar Container
	local playerHealthBg = Instance.new("Frame")
	playerHealthBg.Name = "HealthBg"
	playerHealthBg.Size = UDim2.new(1, -58, 0, 24)
	playerHealthBg.Position = UDim2.new(0, 56, 0, 26)
	playerHealthBg.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	playerHealthBg.BorderSizePixel = 0
	playerHealthBg.ClipsDescendants = true
	playerHealthBg.Parent = playerFrame

	local playerHpCorner = Instance.new("UICorner")
	playerHpCorner.CornerRadius = UDim.new(0, 5)
	playerHpCorner.Parent = playerHealthBg

	local playerHpStroke = Instance.new("UIStroke")
	playerHpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	playerHpStroke.Color = Color3.fromRGB(55, 62, 75)
	playerHpStroke.Thickness = 1.2
	playerHpStroke.Parent = playerHealthBg

	-- Ghost Buffer Fill (Amber damage trail behind main fill)
	local playerGhostFill = Instance.new("Frame")
	playerGhostFill.Name = "GhostFill"
	playerGhostFill.Size = UDim2.new(1, 0, 1, 0)
	playerGhostFill.Position = UDim2.new(0, 0, 0, 0)
	playerGhostFill.BackgroundColor3 = Color3.fromRGB(240, 185, 70)
	playerGhostFill.BorderSizePixel = 0
	playerGhostFill.ZIndex = 1
	playerGhostFill.Parent = playerHealthBg

	local playerGhostCorner = Instance.new("UICorner")
	playerGhostCorner.CornerRadius = UDim.new(0, 5)
	playerGhostCorner.Parent = playerGhostFill

	-- Main Health Fill (Emerald to Jade gradient)
	local playerHealthFill = Instance.new("Frame")
	playerHealthFill.Name = "Fill"
	playerHealthFill.Size = UDim2.new(1, 0, 1, 0)
	playerHealthFill.Position = UDim2.new(0, 0, 0, 0)
	playerHealthFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	playerHealthFill.BorderSizePixel = 0
	playerHealthFill.ZIndex = 2
	playerHealthFill.Parent = playerHealthBg

	local playerFillCorner = Instance.new("UICorner")
	playerFillCorner.CornerRadius = UDim.new(0, 5)
	playerFillCorner.Parent = playerHealthFill

	local playerFillGrad = Instance.new("UIGradient")
	playerFillGrad.Color = ColorSequence.new(Color3.fromRGB(52, 225, 128), Color3.fromRGB(22, 155, 78))
	playerFillGrad.Parent = playerHealthFill

	-- Subtle Glass Gloss Top Strip
	local glossStrip = Instance.new("Frame")
	glossStrip.Name = "Gloss"
	glossStrip.Size = UDim2.new(1, 0, 0.42, 0)
	glossStrip.Position = UDim2.new(0, 0, 0, 0)
	glossStrip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	glossStrip.BackgroundTransparency = 0.86
	glossStrip.BorderSizePixel = 0
	glossStrip.ZIndex = 3
	glossStrip.Parent = playerHealthBg

	-- Numerical Health Readout
	local playerHealthText = Instance.new("TextLabel")
	playerHealthText.Name = "HealthText"
	playerHealthText.Size = UDim2.new(1, 0, 1, 0)
	playerHealthText.Position = UDim2.new(0, 0, 0, 0)
	playerHealthText.BackgroundTransparency = 1
	playerHealthText.Font = Enum.Font.GothamBold
	playerHealthText.TextSize = 14
	playerHealthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	playerHealthText.TextStrokeColor3 = Color3.fromRGB(12, 15, 14)
	playerHealthText.TextStrokeTransparency = 0.2
	playerHealthText.Text = "100 / 100 HP (100%)"
	playerHealthText.ZIndex = 4
	playerHealthText.Parent = playerHealthBg

	-- ── Boss Health Bar (Top-Center, compact & responsive) ───────────────────
	local bossHealthContainer = Instance.new("Frame")
	bossHealthContainer.Name = "BossHealthContainer"
	bossHealthContainer.AnchorPoint = Vector2.new(0.5, 0)
	bossHealthContainer.Size = UDim2.new(0, 380, 0, 50)
	bossHealthContainer.Position = UDim2.new(0, 0, 0, 8)
	bossHealthContainer.BackgroundTransparency = 1
	bossHealthContainer.Visible = false
	bossHealthContainer.Parent = topCenterContainer

	-- Boss Title Header Card
	local bossHeader = Instance.new("Frame")
	bossHeader.Name = "BossHeader"
	bossHeader.Size = UDim2.new(1, 0, 0, 20)
	bossHeader.Position = UDim2.new(0, 0, 0, 0)
	bossHeader.BackgroundTransparency = 1
	bossHeader.Parent = bossHealthContainer

	local bossNameLabel = Instance.new("TextLabel")
	bossNameLabel.Name = "BossName"
	bossNameLabel.Size = UDim2.new(1, 0, 1, 0)
	bossNameLabel.Position = UDim2.new(0, 0, 0, 0)
	bossNameLabel.BackgroundTransparency = 1
	bossNameLabel.Font = Enum.Font.GothamBold
	bossNameLabel.TextSize = 15.5
	bossNameLabel.TextColor3 = Color3.fromRGB(255, 220, 110)
	bossNameLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 22)
	bossNameLabel.TextStrokeTransparency = 0.2
	bossNameLabel.Text = "💀 ROCKHIDE THE EARTHBREAKER"
	bossNameLabel.Parent = bossHeader

	-- Boss Bar Background Plate
	local bossHealthBg = Instance.new("Frame")
	bossHealthBg.Name = "BarBg"
	bossHealthBg.Size = UDim2.new(1, 0, 0, 22)
	bossHealthBg.Position = UDim2.new(0, 0, 0, 22)
	bossHealthBg.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	bossHealthBg.BorderSizePixel = 0
	bossHealthBg.ClipsDescendants = true
	bossHealthBg.Parent = bossHealthContainer

	local bossBgCorner = Instance.new("UICorner")
	bossBgCorner.CornerRadius = UDim.new(0, 5)
	bossBgCorner.Parent = bossHealthBg

	local bossBgStroke = Instance.new("UIStroke")
	bossBgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bossBgStroke.Color = Color3.fromRGB(215, 175, 75)
	bossBgStroke.Thickness = 1.2
	bossBgStroke.Parent = bossHealthBg

	-- Boss Ghost Buffer Bar (Amber/White trailing damage)
	local bossGhostFill = Instance.new("Frame")
	bossGhostFill.Name = "GhostFill"
	bossGhostFill.Size = UDim2.new(1, 0, 1, 0)
	bossGhostFill.Position = UDim2.new(0, 0, 0, 0)
	bossGhostFill.BackgroundColor3 = Color3.fromRGB(255, 190, 80)
	bossGhostFill.BorderSizePixel = 0
	bossGhostFill.ZIndex = 1
	bossGhostFill.Parent = bossHealthBg

	local bossGhostCorner = Instance.new("UICorner")
	bossGhostCorner.CornerRadius = UDim.new(0, 4)
	bossGhostCorner.Parent = bossGhostFill

	-- Main Boss Crimson Health Fill
	local bossHealthFill = Instance.new("Frame")
	bossHealthFill.Name = "Fill"
	bossHealthFill.Size = UDim2.new(1, 0, 1, 0)
	bossHealthFill.Position = UDim2.new(0, 0, 0, 0)
	bossHealthFill.BackgroundColor3 = Color3.fromRGB(225, 45, 40)
	bossHealthFill.BorderSizePixel = 0
	bossHealthFill.ZIndex = 2
	bossHealthFill.Parent = bossHealthBg

	local bossFillCorner = Instance.new("UICorner")
	bossFillCorner.CornerRadius = UDim.new(0, 4)
	bossFillCorner.Parent = bossHealthFill

	local bossFillGrad = Instance.new("UIGradient")
	bossFillGrad.Color = ColorSequence.new(Color3.fromRGB(245, 60, 50), Color3.fromRGB(155, 18, 24))
	bossFillGrad.Parent = bossHealthFill

	-- Phase Notches (Tick marks at 25%, 50%, 75%)
	for _, notchPct in {0.25, 0.50, 0.75} do
		local notch = Instance.new("Frame")
		notch.Name = "Notch_" .. tostring(notchPct * 100)
		notch.Size = UDim2.new(0, 1.5, 1, 0)
		notch.Position = UDim2.new(notchPct, -1, 0, 0)
		notch.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
		notch.BackgroundTransparency = 0.3
		notch.BorderSizePixel = 0
		notch.ZIndex = 3
		notch.Parent = bossHealthBg
	end

	-- Boss Health Numerical & Percentage Readout
	local bossHealthText = Instance.new("TextLabel")
	bossHealthText.Name = "BossHealthText"
	bossHealthText.Size = UDim2.new(1, 0, 1, 0)
	bossHealthText.Position = UDim2.new(0, 0, 0, 0)
	bossHealthText.BackgroundTransparency = 1
	bossHealthText.Font = Enum.Font.GothamBold
	bossHealthText.TextSize = 14
	bossHealthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	bossHealthText.TextStrokeColor3 = Color3.fromRGB(20, 10, 10)
	bossHealthText.TextStrokeTransparency = 0.2
	bossHealthText.Text = "1,250 / 1,250 HP (100%)"
	bossHealthText.ZIndex = 4
	bossHealthText.Parent = bossHealthBg

	local playerGhostTween: Tween? = nil
	Net.Get("HealthChanged").OnClientEvent:Connect(function(userId, current, max)
		if userId == player.UserId then
			local curClamped = math.max(0, current)
			local maxSafe = math.max(1, max)
			local pct = math.clamp(curClamped / maxSafe, 0, 1)

			playerHealthText.Text = ("%d / %d HP (%d%%)"):format(math.floor(curClamped), math.floor(maxSafe), math.floor(pct * 100))

			TweenService:Create(playerHealthFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(pct, 0, 1, 0)
			}):Play()

			if playerGhostTween then
				playerGhostTween:Cancel()
			end
			playerGhostTween = TweenService:Create(playerGhostFill, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.2), {
				Size = UDim2.new(pct, 0, 1, 0)
			})
			playerGhostTween:Play()
		end
	end)

	local bossGhostTween: Tween? = nil
	Net.Get("BossStateChanged").OnClientEvent:Connect(function(_bossId, _phaseIndex, current, max)
		if current > 0 and max > 0 then
			bossHealthContainer.Visible = true
			local curClamped = math.max(0, current)
			local maxSafe = math.max(1, max)
			local pct = math.clamp(curClamped / maxSafe, 0, 1)

			bossHealthText.Text = ("%s / %s HP (%d%%)"):format(
				formatNumber(math.floor(curClamped)),
				formatNumber(math.floor(maxSafe)),
				math.floor(pct * 100)
			)

			TweenService:Create(bossHealthFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(pct, 0, 1, 0)
			}):Play()

			if bossGhostTween then
				bossGhostTween:Cancel()
			end
			bossGhostTween = TweenService:Create(bossGhostFill, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25), {
				Size = UDim2.new(pct, 0, 1, 0)
			})
			bossGhostTween:Play()
		else
			bossHealthText.Text = "0 HP (0%)"
			bossHealthFill.Size = UDim2.new(0, 0, 1, 0)
			if bossGhostFill then
				bossGhostFill.Size = UDim2.new(0, 0, 1, 0)
			end
			task.delay(1.5, function()
				if bossHealthContainer then
					bossHealthContainer.Visible = false
				end
			end)
		end
	end)

	Net.Get("DungeonResult").OnClientEvent:Connect(function()
		bossHealthContainer.Visible = false
	end)

	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(level, _unspentEXP, classId)
		currentLevel = level
		if classId and type(classId) == "string" then
			currentClassId = classId
			updateClassVisuals()
		end
		if levelBadgeText then
			levelBadgeText.Text = "Lv. " .. tostring(level)
		end
	end)

	Net.Get("EquipmentDataChanged").OnClientEvent:Connect(function(equippedTable)
		if equippedTable and equippedTable.Weapon then
			local eq = Equipment.Items[equippedTable.Weapon]
			if eq and eq.archetype == "Mage" then
				currentClassId = "Mage"
				updateClassVisuals()
			elseif eq and eq.archetype == "Tank" then
				currentClassId = "Tank"
				updateClassVisuals()
			end
		end
	end)

	-- ── Dungeon Objective Tracker (Top-Left, below Player Unit Frame) ─────────
	local objectiveCard = Instance.new("Frame")
	objectiveCard.Name = "DungeonObjectiveCard"
	objectiveCard.Size = UDim2.new(0, 280, 0, 76)
	objectiveCard.Position = UDim2.new(0, 16, 0, 114)
	objectiveCard.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	objectiveCard.BackgroundTransparency = 0.15
	objectiveCard.BorderSizePixel = 0
	objectiveCard.Visible = false
	objectiveCard.Parent = topLeftContainer

	local objCorner = Instance.new("UICorner")
	objCorner.CornerRadius = UDim.new(0, 8)
	objCorner.Parent = objectiveCard

	local objGrad = Instance.new("UIGradient")
	objGrad.Rotation = 45
	objGrad.Color = ColorSequence.new(Color3.fromRGB(24, 30, 42), Color3.fromRGB(14, 16, 24))
	objGrad.Parent = objectiveCard

	local objStroke = Instance.new("UIStroke")
	objStroke.Color = Color3.fromRGB(195, 155, 65)
	objStroke.Thickness = 1.4
	objStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	objStroke.Parent = objectiveCard

	local objHeader = Instance.new("TextLabel")
	objHeader.Size = UDim2.new(1, -16, 0, 20)
	objHeader.Position = UDim2.new(0, 8, 0, 5)
	objHeader.BackgroundTransparency = 1
	objHeader.TextColor3 = Color3.fromRGB(255, 215, 80)
	objHeader.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	objHeader.TextStrokeTransparency = 0.2
	objHeader.Font = Enum.Font.GothamBold
	objHeader.TextSize = 14.5
	objHeader.TextXAlignment = Enum.TextXAlignment.Left
	objHeader.Text = "📜 DUNGEON OBJECTIVE"
	objHeader.Parent = objectiveCard

	local objDesc = Instance.new("TextLabel")
	objDesc.Size = UDim2.new(1, -16, 0, 20)
	objDesc.Position = UDim2.new(0, 8, 0, 26)
	objDesc.BackgroundTransparency = 1
	objDesc.TextColor3 = Color3.fromRGB(240, 242, 250)
	objDesc.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	objDesc.TextStrokeTransparency = 0.3
	objDesc.Font = Enum.Font.GothamMedium
	objDesc.TextSize = 13.5
	objDesc.TextXAlignment = Enum.TextXAlignment.Left
	objDesc.Text = "Slay Dungeon Guardians (0 / 10)"
	objDesc.Parent = objectiveCard

	local objProgressBg = Instance.new("Frame")
	objProgressBg.Size = UDim2.new(1, -16, 0, 12)
	objProgressBg.Position = UDim2.new(0, 8, 0, 52)
	objProgressBg.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	objProgressBg.BorderSizePixel = 0
	objProgressBg.ClipsDescendants = true
	objProgressBg.Parent = objectiveCard

	local objProgCorner = Instance.new("UICorner")
	objProgCorner.CornerRadius = UDim.new(0, 4)
	objProgCorner.Parent = objProgressBg

	local objProgStroke = Instance.new("UIStroke")
	objProgStroke.Color = Color3.fromRGB(50, 56, 70)
	objProgStroke.Thickness = 1
	objProgStroke.Parent = objProgressBg

	local objProgressFill = Instance.new("Frame")
	objProgressFill.Size = UDim2.new(0, 0, 1, 0)
	objProgressFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	objProgressFill.BorderSizePixel = 0
	objProgressFill.Parent = objProgressBg

	local objFillCorner = Instance.new("UICorner")
	objFillCorner.CornerRadius = UDim.new(0, 4)
	objFillCorner.Parent = objProgressFill

	local objFillGrad = Instance.new("UIGradient")
	objFillGrad.Color = ColorSequence.new(Color3.fromRGB(52, 225, 128), Color3.fromRGB(22, 155, 78))
	objFillGrad.Parent = objProgressFill

	local function clearEntranceBarriers()
		local arena = workspace:FindFirstChild("RockhideArena")
		if arena then
			for _, part in arena:GetDescendants() do
				if part:IsA("BasePart") then
					if part.Name == "CombatSeal" or part.Name == "RunicBarrier" then
						part.CanCollide = false
						part.Transparency = 1
					elseif part.Name == "Door_Left" or part.Name == "Door_Right" then
						part.CanCollide = false
					end
				end
			end
		end
	end

	local function updateObjectivePosition()
		local partyGui = playerGui:FindFirstChild("PartyUI")
		local partyCard = (topLeftContainer and topLeftContainer:FindFirstChild("PartyCard"))
			or (partyGui and partyGui:FindFirstChild("PartyCard"))
		local statusLabel = (topLeftContainer and topLeftContainer:FindFirstChild("StatusLabel", true))
			or (partyGui and partyGui:FindFirstChild("StatusLabel", true))

		local partyActive = (partyCard and partyCard.Visible)
			or (statusLabel and statusLabel.Visible and statusLabel.Text ~= "" and statusLabel.Text ~= "No party")

		if partyActive then
			objectiveCard.Position = UDim2.new(0, 16, 0, 150)
		else
			objectiveCard.Position = UDim2.new(0, 16, 0, 102)
		end
	end

	-- Continuous safeguard: ensure entrance barrier never blocks the player and objective card is positioned cleanly
	task.spawn(function()
		while true do
			task.wait(1)
			updateObjectivePosition()
			local arena = workspace:FindFirstChild("RockhideArena")
			if arena then
				local seal = arena:FindFirstChild("CombatSeal", true)
				if seal and seal:IsA("BasePart") then
					seal.CanCollide = false
					seal.Transparency = 1
				end
			end
		end
	end)

	-- ── Boss Chamber Direction Indicator ──────────────────────────────────────
	local isBossGuideActive = false
	local bossGuideConnection: RBXScriptConnection? = nil
	local bossGuideArrowModel: Model? = nil
	local bossGateBeaconModel: Model? = nil

	local function getBossGateTarget(): Vector3
		local arena = workspace:FindFirstChild("RockhideArena")
		if arena then
			local promptPart = arena:FindFirstChild("GatePromptPart", true)
			if promptPart and promptPart:IsA("BasePart") then
				return promptPart.Position
			end
			local gateModel = arena:FindFirstChild("BossArenaGate", true)
			if gateModel and gateModel:IsA("Model") then
				local cf = gateModel:GetPivot()
				return Vector3.new(cf.Position.X, 3, cf.Position.Z)
			end
		end
		return Vector3.new(0, 3, -25)
	end

	local function stopBossDirectionGuide()
		if not isBossGuideActive then
			return
		end
		isBossGuideActive = false

		if bossGuideConnection then
			bossGuideConnection:Disconnect()
			bossGuideConnection = nil
		end

		if bossGuideArrowModel then
			bossGuideArrowModel:Destroy()
			bossGuideArrowModel = nil
		end

		if bossGateBeaconModel then
			bossGateBeaconModel:Destroy()
			bossGateBeaconModel = nil
		end
	end

	local function startBossDirectionGuide()
		if isBossGuideActive then
			return
		end
		isBossGuideActive = true

		local targetPos = getBossGateTarget()

		-- 1. Create the overhead 3D guide arrow model
		local arrowModel = Instance.new("Model")
		arrowModel.Name = "BossGuideArrow"

		local rootPart = Instance.new("Part")
		rootPart.Name = "ArrowRoot"
		rootPart.Size = Vector3.new(0.5, 0.5, 0.5)
		rootPart.Transparency = 1
		rootPart.CanCollide = false
		rootPart.CanTouch = false
		rootPart.CanQuery = false
		rootPart.CastShadow = false
		rootPart.Anchored = true
		rootPart.Parent = arrowModel
		arrowModel.PrimaryPart = rootPart

		-- Simple Big Fat 3D Arrow (Classic arcade / RPG direction indicator)
		-- Left half of triangular arrowhead (WedgePart)
		local headL = Instance.new("WedgePart")
		headL.Name = "HeadL"
		headL.Size = Vector3.new(0.48, 1.3, 1.9)
		headL.Material = Enum.Material.Neon
		headL.Color = Color3.fromRGB(255, 215, 25)
		headL.CanCollide = false
		headL.CanTouch = false
		headL.CanQuery = false
		headL.CastShadow = false
		headL.Anchored = true
		headL.Parent = arrowModel

		-- Right half of triangular arrowhead (WedgePart)
		local headR = Instance.new("WedgePart")
		headR.Name = "HeadR"
		headR.Size = Vector3.new(0.48, 1.3, 1.9)
		headR.Material = Enum.Material.Neon
		headR.Color = Color3.fromRGB(255, 215, 25)
		headR.CanCollide = false
		headR.CanTouch = false
		headR.CanQuery = false
		headR.CastShadow = false
		headR.Anchored = true
		headR.Parent = arrowModel

		-- Chunky Arrow Stem / Shaft (Part)
		local shaft = Instance.new("Part")
		shaft.Name = "ArrowShaft"
		shaft.Size = Vector3.new(1.3, 0.48, 1.7)
		shaft.Material = Enum.Material.Neon
		shaft.Color = Color3.fromRGB(255, 185, 20)
		shaft.CanCollide = false
		shaft.CanTouch = false
		shaft.CanQuery = false
		shaft.CastShadow = false
		shaft.Anchored = true
		shaft.Parent = arrowModel

		-- Ground Navigation Chevron (projected onto floor ahead of player)
		local groundChevron = Instance.new("Part")
		groundChevron.Name = "GroundChevron"
		groundChevron.Size = Vector3.new(2.2, 0.05, 2.2)
		groundChevron.Material = Enum.Material.Neon
		groundChevron.Color = Color3.fromRGB(255, 205, 45)
		groundChevron.Transparency = 0.4
		groundChevron.CanCollide = false
		groundChevron.CanTouch = false
		groundChevron.CanQuery = false
		groundChevron.CastShadow = false
		groundChevron.Anchored = true
		groundChevron.Parent = arrowModel

		-- Golden Ember Sparks (streaming backwards from tail)
		local particles = Instance.new("ParticleEmitter")
		particles.Rate = 8
		particles.Lifetime = NumberRange.new(0.25, 0.5)
		particles.Speed = NumberRange.new(1.0, 2.2)
		particles.EmissionDirection = Enum.NormalId.Back
		particles.SpreadAngle = Vector2.new(15, 15)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		particles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 140, 25))
		particles.LightEmission = 0.9
		particles.LightInfluence = 0
		particles.Parent = shaft

		-- Overhead Billboard HUD Distance Badge
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "DistanceBadge"
		billboard.Size = UDim2.new(0, 150, 0, 28)
		billboard.StudsOffset = Vector3.new(0, 1.8, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 450
		billboard.ClipsDescendants = false
		billboard.Parent = rootPart

		local badgeFrame = Instance.new("Frame")
		badgeFrame.Size = UDim2.new(1, 0, 1, 0)
		badgeFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
		badgeFrame.BackgroundTransparency = 0.22
		badgeFrame.BorderSizePixel = 0
		badgeFrame.Parent = billboard

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 7)
		badgeCorner.Parent = badgeFrame

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = Color3.fromRGB(255, 205, 50)
		badgeStroke.Thickness = 1.4
		badgeStroke.Transparency = 0.2
		badgeStroke.Parent = badgeFrame

		local distLabel = Instance.new("TextLabel")
		distLabel.Size = UDim2.new(1, -8, 1, 0)
		distLabel.Position = UDim2.new(0, 4, 0, 0)
		distLabel.BackgroundTransparency = 1
		distLabel.Font = Enum.Font.GothamBold
		distLabel.TextSize = 14
		distLabel.TextColor3 = Color3.fromRGB(255, 235, 100)
		distLabel.TextStrokeColor3 = Color3.fromRGB(15, 10, 0)
		distLabel.TextStrokeTransparency = 0.3
		distLabel.Text = "⚡ BOSS GATE"
		distLabel.Parent = badgeFrame

		arrowModel.Parent = workspace
		bossGuideArrowModel = arrowModel

		-- 2. Create the Gate Beacon (Light pillar, ground ring & entrance banner at the gate)
		local beaconModel = Instance.new("Model")
		beaconModel.Name = "BossGateBeacon"

		local pillar = Instance.new("Part")
		pillar.Name = "BeaconPillar"
		pillar.Size = Vector3.new(3.2, 26, 3.2)
		pillar.CFrame = CFrame.new(targetPos.X, 13, targetPos.Z)
		pillar.Material = Enum.Material.Neon
		pillar.Color = Color3.fromRGB(255, 195, 45)
		pillar.Transparency = 0.76
		pillar.CanCollide = false
		pillar.CanTouch = false
		pillar.CanQuery = false
		pillar.CastShadow = false
		pillar.Anchored = true
		pillar.Parent = beaconModel

		local gateLight = Instance.new("PointLight")
		gateLight.Brightness = 2.8
		gateLight.Range = 32
		gateLight.Color = Color3.fromRGB(255, 195, 45)
		gateLight.Parent = pillar

		-- Glowing threshold disc on the floor
		local ring = Instance.new("Part")
		ring.Name = "GateRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.12, 16, 16)
		ring.CFrame = CFrame.new(targetPos.X, 1.08, targetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 205, 55)
		ring.Transparency = 0.55
		ring.CanCollide = false
		ring.CanTouch = false
		ring.CanQuery = false
		ring.CastShadow = false
		ring.Anchored = true
		ring.Parent = beaconModel

		-- Downward chevron indicator hovering over gate archway
		local gateChevron = Instance.new("Part")
		gateChevron.Name = "GateChevron"
		gateChevron.Size = Vector3.new(1.8, 1.8, 1.8)
		gateChevron.Shape = Enum.PartType.Ball
		gateChevron.Material = Enum.Material.Neon
		gateChevron.Color = Color3.fromRGB(255, 225, 60)
		gateChevron.CanCollide = false
		gateChevron.CanTouch = false
		gateChevron.CanQuery = false
		gateChevron.CastShadow = false
		gateChevron.Anchored = true
		gateChevron.Parent = beaconModel

		local gateBb = Instance.new("BillboardGui")
		gateBb.Name = "GateBillboard"
		gateBb.Size = UDim2.new(0, 260, 0, 68)
		gateBb.StudsOffset = Vector3.new(0, 3.2, 0)
		gateBb.AlwaysOnTop = true
		gateBb.MaxDistance = 250
		gateBb.Parent = gateChevron

		local gateBg = Instance.new("Frame")
		gateBg.Size = UDim2.new(1, 0, 1, 0)
		gateBg.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
		gateBg.BackgroundTransparency = 0.2
		gateBg.Parent = gateBb

		local gateBgCorner = Instance.new("UICorner")
		gateBgCorner.CornerRadius = UDim.new(0, 8)
		gateBgCorner.Parent = gateBg

		local gateBgStroke = Instance.new("UIStroke")
		gateBgStroke.Color = Color3.fromRGB(255, 210, 50)
		gateBgStroke.Thickness = 1.5
		gateBgStroke.Parent = gateBg

		local gateArrowIcon = Instance.new("TextLabel")
		gateArrowIcon.Size = UDim2.new(1, 0, 0.36, 0)
		gateArrowIcon.Position = UDim2.new(0, 0, 0.02, 0)
		gateArrowIcon.BackgroundTransparency = 1
		gateArrowIcon.Font = Enum.Font.GothamBold
		gateArrowIcon.TextSize = 17
		gateArrowIcon.TextColor3 = Color3.fromRGB(255, 220, 60)
		gateArrowIcon.Text = "▼  ENTER CHAMBER  ▼"
		gateArrowIcon.Parent = gateBg

		local gateTitle = Instance.new("TextLabel")
		gateTitle.Size = UDim2.new(1, 0, 0.34, 0)
		gateTitle.Position = UDim2.new(0, 0, 0.36, 0)
		gateTitle.BackgroundTransparency = 1
		gateTitle.Font = Enum.Font.GothamBold
		gateTitle.TextSize = 15
		gateTitle.TextColor3 = Color3.fromRGB(255, 240, 150)
		gateTitle.Text = "⚡ BOSS GATE UNLOCKED ⚡"
		gateTitle.Parent = gateBg

		local gateSub = Instance.new("TextLabel")
		gateSub.Size = UDim2.new(1, 0, 0.28, 0)
		gateSub.Position = UDim2.new(0, 0, 0.7, 0)
		gateSub.BackgroundTransparency = 1
		gateSub.Font = Enum.Font.Gotham
		gateSub.TextSize = 13.5
		gateSub.TextColor3 = Color3.fromRGB(200, 205, 220)
		gateSub.Text = "[Approach to Awaken Rockhide]"
		gateSub.Parent = gateBg

		beaconModel.Parent = workspace
		bossGateBeaconModel = beaconModel

		-- 3. Connect RenderStepped to update orientation and position every frame
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		bossGuideConnection = RunService.RenderStepped:Connect(function()
			if not workspace:FindFirstChild("RockhideArena") then
				stopBossDirectionGuide()
				return
			end

			local character = Players.LocalPlayer and Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				return
			end

			local playerPos = root.Position
			-- Automatically complete and cleanup once player enters the arena!
			if playerPos.Z > -18 then
				stopBossDirectionGuide()
				return
			end

			local currentTarget = getBossGateTarget()
			local diffX = currentTarget.X - playerPos.X
			local diffZ = currentTarget.Z - playerPos.Z
			local horizontalDist = math.sqrt(diffX * diffX + diffZ * diffZ)

			local dirUnit = horizontalDist > 0.1 and Vector3.new(diffX / horizontalDist, 0, diffZ / horizontalDist) or Vector3.new(0, 0, -1)

			local now = os.clock()
			-- Dynamic hover bobbing + forward surge pulse
			local bob = math.sin(now * 4.5) * 0.28
			local surge = (math.sin(now * 6.5) + 1) * 0.5 * 0.24
			local arrowCenter = playerPos + Vector3.new(0, 5.0 + bob, 0) + (dirUnit * surge)

			-- Orient arrow toward target with slight downward pitch so top face is clearly visible from 3rd-person camera
			local lookCF = CFrame.lookAt(arrowCenter, arrowCenter + dirUnit)
			local tiltCF = lookCF * CFrame.Angles(math.rad(-16), 0, 0)

			-- Update root and all arrow parts relative to tiltCF
			rootPart.CFrame = tiltCF
			headR.CFrame = tiltCF * CFrame.fromMatrix(Vector3.new(0.65, 0, -0.85), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1))
			headL.CFrame = tiltCF * CFrame.fromMatrix(Vector3.new(-0.65, 0, -0.85), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))
			shaft.CFrame = tiltCF * CFrame.new(0, 0, 0.95)

			-- Update ground chevron ahead of player
			rayParams.FilterDescendantsInstances = {character, arrowModel, beaconModel}
			local floorRay = workspace:Raycast(playerPos + (dirUnit * 4.2) + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), rayParams)
			local floorY = floorRay and (floorRay.Position.Y + 0.08) or (playerPos.Y - 2.92)
			local floorPos = Vector3.new(playerPos.X + dirUnit.X * 4.2, floorY, playerPos.Z + dirUnit.Z * 4.2)
			groundChevron.CFrame = CFrame.lookAt(floorPos, floorPos + dirUnit) * CFrame.Angles(0, math.rad(45), 0)
			groundChevron.Transparency = 0.35 + (math.sin(now * 4.5) * 0.18)

			-- Update real-time distance badge
			local distMeters = math.max(1, math.floor(horizontalDist / 3))
			distLabel.Text = ("⚡ BOSS GATE  %dm"):format(distMeters)

			-- Gate Beacon downward chevron bobbing & ring pulse
			if gateChevron and gateChevron.Parent then
				local gateBob = math.sin(now * 3.5) * 0.65
				gateChevron.CFrame = CFrame.new(currentTarget.X, 13.5 + gateBob, currentTarget.Z)
			end
			if ring and ring.Parent then
				local ringAlpha = 0.45 + (math.sin(now * 4) * 0.2)
				ring.Transparency = ringAlpha
			end
		end)
	end

	Net.Get("DungeonObjectiveChanged").OnClientEvent:Connect(function(text, currentKills, totalRequired, isUnlocked, isOpen)
		objectiveCard.Visible = true
		updateObjectivePosition()
		if isOpen then
			stopBossDirectionGuide()
			objDesc.TextColor3 = Color3.fromRGB(255, 120, 100)
			objDesc.Text = "👑 " .. text
			objProgressFill.Size = UDim2.new(1, 0, 1, 0)
			objProgressFill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
			objStroke.Color = Color3.fromRGB(200, 60, 50)
			clearEntranceBarriers()
			task.delay(0.5, clearEntranceBarriers)
			task.delay(1.5, clearEntranceBarriers)
		elseif isUnlocked then
			startBossDirectionGuide()
			objDesc.TextColor3 = Color3.fromRGB(100, 255, 150)
			objDesc.Text = "✨ " .. text .. " [UNLOCKED]"
			objProgressFill.Size = UDim2.new(1, 0, 1, 0)
			objProgressFill.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
			objStroke.Color = Color3.fromRGB(255, 215, 60)
		else
			stopBossDirectionGuide()
			objDesc.TextColor3 = Color3.fromRGB(240, 240, 250)
			objDesc.Text = ("⚔️ %s (%d / %d)"):format(text, currentKills, totalRequired)
			local frac = math.clamp(currentKills / math.max(1, totalRequired), 0, 1)
			objProgressFill.Size = UDim2.new(frac, 0, 1, 0)
			objProgressFill.BackgroundColor3 = Color3.fromRGB(60, 200, 120)
			objStroke.Color = Color3.fromRGB(160, 130, 60)
		end
	end)

	-- ── Telegraph Ground Indicators ────────────────────────────────────────────
	-- Hidden as requested: no visible ground damage circle or ring indicator is shown to players.
	-- Players rely on the boss's physical windup poses, roaring audio, leaps, and kinetic cues.
	Net.Get("TelegraphAttack").OnClientEvent:Connect(function(attackId, position, telegraphTime, radius)
		-- Visual circle damage area is intentionally hidden.
	end)

	-- ── Boss Special Effects (Screen Shake + Flash) ──────────────────────────
	do
		local RunService = game:GetService("RunService")
		local Camera = workspace.CurrentCamera
		local _shakeConn: RBXScriptConnection? = nil
		local _shakeEndTime = 0
		local _shakeIntensity = 0

		local function startScreenShake(intensity: number, duration: number)
			_shakeIntensity = intensity
			_shakeEndTime = os.clock() + duration
			if _shakeConn then return end -- already running
			_shakeConn = RunService.RenderStepped:Connect(function()
				if not Camera then return end
				local now = os.clock()
				if now >= _shakeEndTime then
					if _shakeConn then
						_shakeConn:Disconnect()
						_shakeConn = nil
					end
					return
				end
				local t = 1 - math.clamp((now - (_shakeEndTime - duration)) / duration, 0, 1)
				local mag = _shakeIntensity * t * 1.4
				local offset = Vector3.new(
					(math.random() - 0.5) * mag,
					(math.random() - 0.5) * mag,
					0
				)
				Camera.CFrame = Camera.CFrame * CFrame.new(offset)
			end)
		end

		-- Full-screen colored flash overlay (ScreenGui above all other UI)
		local flashGui = Instance.new("ScreenGui")
		flashGui.Name = "BossFlashGui"
		flashGui.IgnoreGuiInset = true
		flashGui.ResetOnSpawn = false
		flashGui.DisplayOrder = 200
		flashGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

		local flashFrame = Instance.new("Frame")
		flashFrame.Size = UDim2.fromScale(1, 1)
		flashFrame.BackgroundColor3 = Color3.fromRGB(255, 60, 20)
		flashFrame.BackgroundTransparency = 1
		flashFrame.BorderSizePixel = 0
		flashFrame.ZIndex = 200
		flashFrame.Parent = flashGui

		local function screenFlash(color: Color3, peakTransparency: number, duration: number)
			flashFrame.BackgroundColor3 = color
			flashFrame.BackgroundTransparency = peakTransparency
			TweenService:Create(flashFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end

		Net.Get("BossEffect").OnClientEvent:Connect(function(effectType: string, _position, data)
			local intensity = (data and data.intensity) or 0.5
			local dur = (data and data.duration) or 0.5

			if effectType == "lightShake" then
				startScreenShake(intensity * 0.6, dur)
			elseif effectType == "medShake" then
				startScreenShake(intensity * 0.9, dur)
				screenFlash(Color3.fromRGB(255, 100, 30), 0.88, dur * 1.2)
			elseif effectType == "heavyShake" then
				startScreenShake(intensity * 1.4, dur)
				screenFlash(Color3.fromRGB(255, 50, 10), 0.78, dur * 1.5)
			elseif effectType == "phaseShake" then
				startScreenShake(intensity * 1.2, dur)
				screenFlash(Color3.fromRGB(255, 130, 20), 0.72, dur * 2.0)
			elseif effectType == "enrageShake" then
				startScreenShake(intensity * 1.8, dur)
				screenFlash(Color3.fromRGB(220, 20, 10), 0.65, dur * 2.5)
			end
		end)
	end

	-- ── Normal Attack Button (Primary Action for Mobile & Desktop) ─────────────
	local attackFrame = Instance.new("Frame")
	attackFrame.Name = "AttackButton"
	attackFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	attackFrame.Size = UDim2.new(0, ATTACK_BUTTON_SIZE, 0, ATTACK_BUTTON_SIZE)
	attackFrame.Position = UDim2.new(0, ATTACK_POS_X, 0, ATTACK_POS_Y)
	attackFrame.BackgroundColor3 = Color3.fromRGB(215, 45, 38)
	attackFrame.BorderSizePixel = 0
	attackFrame.Parent = bottomRightContainer

	local attackCorner = Instance.new("UICorner")
	attackCorner.CornerRadius = UDim.new(0.5, 0) -- circular
	attackCorner.Parent = attackFrame

	local attackGradient = Instance.new("UIGradient")
	attackGradient.Rotation = 60
	attackGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 60)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(215, 45, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 16, 20)),
	})
	attackGradient.Parent = attackFrame

	local attackStroke = Instance.new("UIStroke")
	attackStroke.Color = Color3.fromRGB(255, 218, 85)
	attackStroke.Thickness = 3
	attackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	attackStroke.Parent = attackFrame

	-- Inner decorative ring for beveled action plate
	local innerRing = Instance.new("Frame")
	innerRing.Name = "InnerRing"
	innerRing.Size = UDim2.new(1, -10, 1, -10)
	innerRing.Position = UDim2.new(0.5, 0, 0.5, 0)
	innerRing.AnchorPoint = Vector2.new(0.5, 0.5)
	innerRing.BackgroundTransparency = 1
	innerRing.Parent = attackFrame

	local innerRingCorner = Instance.new("UICorner")
	innerRingCorner.CornerRadius = UDim.new(0.5, 0)
	innerRingCorner.Parent = innerRing

	local innerRingStroke = Instance.new("UIStroke")
	innerRingStroke.Color = Color3.fromRGB(255, 235, 140)
	innerRingStroke.Thickness = 1.2
	innerRingStroke.Transparency = 0.4
	innerRingStroke.Parent = innerRing

	-- Attack Icon (⚔️ / 🔮)
	local attackIcon = Instance.new("TextLabel")
	attackIcon.Name = "Icon"
	attackIcon.Size = UDim2.new(1, 0, 0.44, 0)
	attackIcon.Position = UDim2.new(0, 0, 0.08, 0)
	attackIcon.BackgroundTransparency = 1
	attackIcon.Text = "⚔️"
	attackIcon.TextScaled = true
	attackIcon.ZIndex = 2
	attackIcon.Parent = attackFrame
	attackIconLabel = attackIcon
	updateClassVisuals()

	-- Attack Label
	local attackLabel = Instance.new("TextLabel")
	attackLabel.Name = "Label"
	attackLabel.Size = UDim2.new(1, 0, 0.22, 0)
	attackLabel.Position = UDim2.new(0, 0, 0.52, 0)
	attackLabel.BackgroundTransparency = 1
	attackLabel.TextColor3 = Color3.fromRGB(255, 245, 215)
	attackLabel.TextStrokeColor3 = Color3.fromRGB(20, 10, 10)
	attackLabel.TextStrokeTransparency = 0.2
	attackLabel.Font = Enum.Font.GothamBlack
	attackLabel.TextSize = 13.5
	attackLabel.TextScaled = false
	attackLabel.Text = "ATTACK"
	attackLabel.ZIndex = 2
	attackLabel.Parent = attackFrame

	-- Cooldown Label on Attack Button
	local attackCdText = Instance.new("TextLabel")
	attackCdText.Name = "CooldownLabel"
	attackCdText.Size = UDim2.new(1, 0, 0.44, 0)
	attackCdText.Position = UDim2.new(0, 0, 0.28, 0)
	attackCdText.BackgroundTransparency = 1
	attackCdText.TextColor3 = Color3.fromRGB(255, 220, 50)
	attackCdText.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	attackCdText.TextStrokeTransparency = 0.2
	attackCdText.Font = Enum.Font.GothamBlack
	attackCdText.TextScaled = true
	attackCdText.Text = ""
	attackCdText.ZIndex = 5
	attackCdText.Parent = attackFrame
	attackCdLabel = attackCdText

	-- Dim Overlay for Attack Cooldown
	local attackOverlay = Instance.new("Frame")
	attackOverlay.Name = "DimOverlay"
	attackOverlay.Size = UDim2.new(1, 0, 1, 0)
	attackOverlay.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	attackOverlay.BackgroundTransparency = 1
	attackOverlay.ZIndex = 4
	attackOverlay.Parent = attackFrame
	attackDimOverlay = attackOverlay

	local attackDimCorner = Instance.new("UICorner")
	attackDimCorner.CornerRadius = UDim.new(0.5, 0)
	attackDimCorner.Parent = attackOverlay

	-- Hit Area Button
	local attackButton = Instance.new("TextButton")
	attackButton.Name = "HitArea"
	attackButton.Size = UDim2.new(1, 0, 1, 0)
	attackButton.BackgroundTransparency = 1
	attackButton.Text = ""
	attackButton.ZIndex = 6
	attackButton.Parent = attackFrame

	local function triggerAttackButtonPress()
		-- Tactile spring bounce animation on press
		TweenService:Create(attackFrame, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, ATTACK_BUTTON_SIZE * 0.92, 0, ATTACK_BUTTON_SIZE * 0.92)
		}):Play()
		task.delay(0.08, function()
			if attackFrame and attackFrame.Parent then
				TweenService:Create(attackFrame, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, ATTACK_BUTTON_SIZE, 0, ATTACK_BUTTON_SIZE)
				}):Play()
			end
		end)
		fireNormalAttack()
	end

	attackButton.Activated:Connect(triggerAttackButtonPress)

	-- ── Dedicated Skills Menu Button (Top-Right: keeps screen center completely clear) ─
	local skillsMenuBtn = Instance.new("TextButton")
	skillsMenuBtn.Name = "SkillsMenuButton"
	skillsMenuBtn.AnchorPoint = Vector2.new(1, 0)
	skillsMenuBtn.Size = UDim2.new(0, 116, 0, 38)
	skillsMenuBtn.Position = UDim2.new(0, -16, 0, 48)
	skillsMenuBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	skillsMenuBtn.BorderSizePixel = 0
	skillsMenuBtn.Font = Enum.Font.GothamBold
	skillsMenuBtn.TextSize = 15.5
	skillsMenuBtn.TextColor3 = Color3.fromRGB(255, 225, 90)
	skillsMenuBtn.Text = "SKILLS"
	skillsMenuBtn.Parent = topRightContainer

	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0, 8)
	menuCorner.Parent = skillsMenuBtn

	local menuStroke = Instance.new("UIStroke")
	menuStroke.Color = Color3.fromRGB(210, 170, 70)
	menuStroke.Thickness = 1.6
	menuStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	menuStroke.Parent = skillsMenuBtn

	skillsMenuBtn.Activated:Connect(function()
		SkillTreeUIController.Toggle()
	end)

	-- ── Dedicated Inventory / Armory Menu Button ──────────────────────────────
	local inventoryBtn = Instance.new("TextButton")
	inventoryBtn.Name = "InventoryMenuButton"
	inventoryBtn.AnchorPoint = Vector2.new(1, 0)
	inventoryBtn.Size = UDim2.new(0, 136, 0, 38)
	inventoryBtn.Position = UDim2.new(0, -140, 0, 48)
	inventoryBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	inventoryBtn.BorderSizePixel = 0
	inventoryBtn.Font = Enum.Font.GothamBold
	inventoryBtn.TextSize = 15.5
	inventoryBtn.TextColor3 = Color3.fromRGB(255, 185, 65)
	inventoryBtn.Text = "INVENTORY"
	inventoryBtn.Parent = topRightContainer

	local invCorner = Instance.new("UICorner")
	invCorner.CornerRadius = UDim.new(0, 8)
	invCorner.Parent = inventoryBtn

	local invStroke = Instance.new("UIStroke")
	invStroke.Color = Color3.fromRGB(220, 145, 40)
	invStroke.Thickness = 1.6
	invStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	invStroke.Parent = inventoryBtn

	inventoryBtn.Activated:Connect(function()
		InventoryUIController.Toggle()
	end)

	for i = 1, TOTAL_SLOTS do
		local offset = SKILL_SLOT_OFFSETS[i] or Vector2.new(-66 * i, 0)

		local frame = Instance.new("Frame")
		frame.Name = "SkillSlot_" .. i
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.new(0, SKILL_BUTTON_SIZE, 0, SKILL_BUTTON_SIZE)
		frame.Position = UDim2.new(0, ATTACK_POS_X + offset.X, 0, ATTACK_POS_Y + offset.Y)
		frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
		frame.BorderSizePixel = 0
		frame.ClipsDescendants = true
		frame.Parent = bottomRightContainer
		slotFrames[i] = frame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame

		local slotGrad = Instance.new("UIGradient")
		slotGrad.Rotation = 45
		slotGrad.Color = ColorSequence.new(Color3.fromRGB(34, 40, 54), Color3.fromRGB(16, 20, 28))
		slotGrad.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(220, 180, 75)
		stroke.Thickness = 1.8
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		slotStrokes[i] = stroke

		-- Desktop Hotkey Pill (1, 2, 3, 4)
		local hotkeyBadge = Instance.new("Frame")
		hotkeyBadge.Name = "HotkeyBadge"
		hotkeyBadge.Size = UDim2.new(0, 18, 0, 18)
		hotkeyBadge.Position = UDim2.new(0, 2, 0, 2)
		hotkeyBadge.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		hotkeyBadge.BackgroundTransparency = 0.2
		hotkeyBadge.BorderSizePixel = 0
		hotkeyBadge.ZIndex = 4
		hotkeyBadge.Parent = frame

		local hkCorner = Instance.new("UICorner")
		hkCorner.CornerRadius = UDim.new(0, 4)
		hkCorner.Parent = hotkeyBadge

		local hkText = Instance.new("TextLabel")
		hkText.Size = UDim2.new(1, 0, 1, 0)
		hkText.BackgroundTransparency = 1
		hkText.Font = Enum.Font.GothamBold
		hkText.TextSize = 12
		hkText.TextColor3 = Color3.fromRGB(240, 205, 90)
		hkText.Text = tostring(i)
		hkText.ZIndex = 5
		hkText.Parent = hotkeyBadge

		-- Icon Label
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 0.52, 0)
		iconLabel.Position = UDim2.new(0, 0, 0.08, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextStrokeColor3 = Color3.fromRGB(12, 14, 20)
		iconLabel.TextStrokeTransparency = 0.35
		iconLabel.Text = ""
		iconLabel.TextScaled = true
		iconLabel.ZIndex = 2
		iconLabel.Parent = frame
		slotIconLabels[i] = iconLabel

		-- Skill Name Banner Plate
		local namePlate = Instance.new("Frame")
		namePlate.Name = "NamePlate"
		namePlate.Size = UDim2.new(1, 0, 0.32, 0)
		namePlate.Position = UDim2.new(0, 0, 0.68, 0)
		namePlate.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		namePlate.BackgroundTransparency = 0.35
		namePlate.BorderSizePixel = 0
		namePlate.ZIndex = 3
		namePlate.Parent = frame

		local nameCorner = Instance.new("UICorner")
		nameCorner.CornerRadius = UDim.new(0, 5)
		nameCorner.Parent = namePlate

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -2, 1, 0)
		nameLabel.Position = UDim2.new(0, 1, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.TextStrokeTransparency = 0.2
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextScaled = false
		nameLabel.Text = ""
		nameLabel.ZIndex = 4
		nameLabel.Parent = namePlate
		slotNameLabels[i] = nameLabel

		-- Cooldown / Lock Label
		local cdLabel = Instance.new("TextLabel")
		cdLabel.Name = "CooldownLabel"
		cdLabel.Size = UDim2.new(1, 0, 0.50, 0)
		cdLabel.Position = UDim2.new(0, 0, 0.22, 0)
		cdLabel.BackgroundTransparency = 1
		cdLabel.TextColor3 = Color3.fromRGB(255, 225, 60)
		cdLabel.TextStrokeColor3 = Color3.fromRGB(10, 10, 15)
		cdLabel.TextStrokeTransparency = 0.2
		cdLabel.Font = Enum.Font.GothamBlack
		cdLabel.TextScaled = true
		cdLabel.Text = ""
		cdLabel.ZIndex = 6
		cdLabel.Parent = frame
		slotCdLabels[i] = cdLabel

		-- Dim Overlay
		local dimOverlay = Instance.new("Frame")
		dimOverlay.Name = "DimOverlay"
		dimOverlay.Size = UDim2.new(1, 0, 1, 0)
		dimOverlay.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		dimOverlay.BackgroundTransparency = 1
		dimOverlay.ZIndex = 5
		dimOverlay.Parent = frame
		slotDimOverlays[i] = dimOverlay

		local dimCorner = Instance.new("UICorner")
		dimCorner.CornerRadius = UDim.new(0, 8)
		dimCorner.Parent = dimOverlay

		local button = Instance.new("TextButton")
		button.Name = "HitArea"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 7
		button.Parent = frame

		local capturedSlot = i
		button.Activated:Connect(function()
			local skillId = equippedSkills[capturedSlot]
			if skillId then
				local expires = cooldownEnds[skillId]
				if expires and os.clock() < expires then
					return -- On cooldown: ignore click completely
				end

				-- Tactile bounce animation on slot press
				TweenService:Create(frame, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, SKILL_BUTTON_SIZE - 6, 0, SKILL_BUTTON_SIZE - 6)
				}):Play()
				task.delay(0.08, function()
					if frame and frame.Parent then
						TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							Size = UDim2.new(0, SKILL_BUTTON_SIZE, 0, SKILL_BUTTON_SIZE)
						}):Play()
					end
				end)

				fireSkill(skillId)
			else
				SkillTreeUIController.Toggle()
			end
		end)
	end

	updateSkillButtons()

	Net.Get("SkillDataChanged").OnClientEvent:Connect(function(points, unlocked, equipped)
		equippedSkills = equipped or {"Taunt"}
		updateSkillButtons()
	end)

	-- ── Input Handling (Keyboard Shortcuts, Mouse Click, Mobile Touch) ─────────
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not screenGui.Enabled then
			return
		end

		-- Desktop Keyboard Shortcuts (1-4 skills, F attack, K skills menu)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne then
				local skillId = equippedSkills[1]
				if skillId then fireSkill(skillId) end
				return
			elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.KeypadTwo then
				local skillId = equippedSkills[2]
				if skillId then fireSkill(skillId) end
				return
			elseif input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.KeypadThree then
				local skillId = equippedSkills[3]
				if skillId then fireSkill(skillId) end
				return
			elseif input.KeyCode == Enum.KeyCode.Four or input.KeyCode == Enum.KeyCode.KeypadFour then
				local skillId = equippedSkills[4]
				if skillId then fireSkill(skillId) end
				return
			elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.E then
				fireNormalAttack()
				return
			elseif input.KeyCode == Enum.KeyCode.K or input.KeyCode == Enum.KeyCode.T then
				SkillTreeUIController.Toggle()
				return
			elseif input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.B then
				InventoryUIController.Toggle()
				return
			end
		end

		-- Mouse Click or Mobile Touch Tap: selecting targets in 3D world only (NO attack)
		local isMouseClick = (input.UserInputType == Enum.UserInputType.MouseButton1)
		local isTouch = (input.UserInputType == Enum.UserInputType.Touch)

		if isMouseClick or isTouch then
			local camera = workspace.CurrentCamera
			if camera then
				local screenPos = (isTouch and input.Position) or UserInputService:GetMouseLocation()
				local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)

				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = player.Character and { player.Character } or {}
				local result = workspace:Raycast(ray.Origin, ray.Direction * TARGET_RAYCAST_DISTANCE, raycastParams)

				local hitEnemy = result and findTaggedEnemyAncestor(result.Instance)
				if hitEnemy and hitEnemy.Name ~= selectedTargetId then
					selectTarget(hitEnemy, hitEnemy.Name)
				end
			end
		end
	end)

	-- ── Per-Frame Cooldown & Lock Display Loop ────────────────────────────────
	RunService.Heartbeat:Connect(function()
		if not screenGui.Enabled then
			return
		end

		local now = os.clock()

		-- Attack button cooldown
		if attackDimOverlay and attackCdLabel then
			if now < normalAttackCooldownEnd then
				local remaining = normalAttackCooldownEnd - now
				attackCdLabel.Text = ("%.1f"):format(remaining)
				attackDimOverlay.BackgroundTransparency = 0.55
			else
				attackCdLabel.Text = ""
				attackDimOverlay.BackgroundTransparency = 1
			end
		end

		-- Skill slots cooldown
		for i = 1, TOTAL_SLOTS do
			local frame = slotFrames[i]
			local cdLabel = slotCdLabels[i]
			local dimOverlay = slotDimOverlays[i]
			local skillId = equippedSkills[i]

			if not frame or not cdLabel or not dimOverlay then
				continue
			end

			if skillId then
				local expires = cooldownEnds[skillId]
				if expires and now < expires then
					local remaining = expires - now
					cdLabel.Text = ("%.1f"):format(remaining)
					dimOverlay.BackgroundTransparency = 0.55
				else
					cdLabel.Text = ""
					dimOverlay.BackgroundTransparency = 1
				end
			else
				cdLabel.Text = ""
				dimOverlay.BackgroundTransparency = 1
			end
		end
	end)

	-- ── Character Lifecycle and Login/HUD Visibility Sync ────────────────────
	local function checkVisibility()
		local charCreationGui = playerGui:FindFirstChild("CharacterCreation")
		local isCreating = charCreationGui and charCreationGui:IsA("ScreenGui") and charCreationGui.Enabled
		local hasChar = player.Character and player.Character.Parent ~= nil
		screenGui.Enabled = (hasChar and not isCreating) == true
	end

	player.CharacterAdded:Connect(function()
		local charCreationGui = playerGui:FindFirstChild("CharacterCreation")
		local isCreating = charCreationGui and charCreationGui:IsA("ScreenGui") and charCreationGui.Enabled
		screenGui.Enabled = not isCreating
		updateClassVisuals()
	end)

	player.CharacterRemoving:Connect(function()
		screenGui.Enabled = false
	end)

	checkVisibility()

	task.spawn(function()
		local charCreationGui = playerGui:WaitForChild("CharacterCreation", 5)
		if charCreationGui and charCreationGui:IsA("ScreenGui") then
			charCreationGui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if charCreationGui.Enabled then
					screenGui.Enabled = false
				else
					if player.Character and player.Character.Parent then
						screenGui.Enabled = true
					end
				end
			end)
			checkVisibility()
		end
	end)
end

return HUDController
