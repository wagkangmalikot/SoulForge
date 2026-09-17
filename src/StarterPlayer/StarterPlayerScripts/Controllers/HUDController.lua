-- src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
-- Renders player HP bar, boss HP bar, telegraph ground indicators,
-- on-screen skill buttons (mobile + desktop), normal attack button with ⚔️ icon,
-- and click-to-target + auto-targeting combat controls.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local BossAttacks = require(ReplicatedStorage.Shared.Data.BossAttacks)
local WeaponController = require(script.Parent.WeaponController)
local SkillTreeUIController = require(script.Parent.SkillTreeUIController)

local HUDController = {}

-- ── Button Layout & Sizing ──────────────────────────────────────────────────
local TOTAL_SLOTS = 4
local equippedSkills: {string} = {"Taunt"}

local ATTACK_BUTTON_SIZE   = 136  -- px, extra large circular action button
local ACTION_BAR_Y_CENTER  = 92   -- px above bottom edge for shared vertical center
local ATTACK_RIGHT_MARGIN  = 24   -- px from right edge
local SKILL_BUTTON_SIZE    = 64   -- px, square with rounded corners
local BUTTON_GAP           = 8    -- px between buttons
local RIGHT_MARGIN         = 24   -- px from right edge

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

		if skill then
			frame.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
			stroke.Color = Color3.fromRGB(220, 180, 75)
			stroke.Thickness = 2
			nameLabel.Text = skill.displayName or skillId
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			iconLabel.Text = skill.icon or "⚔️"
		else
			frame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
			stroke.Color = Color3.fromRGB(55, 62, 75)
			stroke.Thickness = 1.4
			nameLabel.Text = "EQUIP"
			nameLabel.TextColor3 = Color3.fromRGB(130, 140, 160)
			iconLabel.Text = "➕"
		end
	end
end

local function fireSkill(skillId: string)
	local skill = Skills[skillId]
	if not skill then
		return
	end

	-- Auto-target nearest only if skill is a single-target enemy skill (e.g. ProvokingStrike, ShieldBash)
	-- AoE and self buffs (Taunt, Earthshaker, IronWill, FortressAura) cast freely around the player
	local isAoeOrSelf = (skillId == "Taunt" or skillId == "Earthshaker" or skillId == "IronWill" or skillId == "FortressAura")
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

	Net.Get("CastSkill"):FireServer(skillId, selectedTargetId)

	local char = Players.LocalPlayer.Character
	if char then
		WeaponController.PlaySwing(char, skillId)
	end

	cooldownEnds[skillId] = os.clock() + (skill.cooldown or 0)
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
		WeaponController.PlaySwing(char, "Slash")
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
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- ── Player Unit Frame (Bottom-Left) ─────────────────────────────────────────
	local playerFrame = Instance.new("Frame")
	playerFrame.Name = "PlayerUnitFrame"
	playerFrame.Size = UDim2.new(0, 330, 0, 56)
	playerFrame.Position = UDim2.new(0, 20, 1, -78)
	playerFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	playerFrame.BackgroundTransparency = 0.15
	playerFrame.BorderSizePixel = 0
	playerFrame.Parent = screenGui

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
	badgeCorner.CornerRadius = UDim.new(0, 8)
	badgeCorner.Parent = levelBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(220, 180, 75)
	badgeStroke.Thickness = 1.5
	badgeStroke.Parent = levelBadge

	local badgeIcon = Instance.new("TextLabel")
	badgeIcon.Name = "ClassIcon"
	badgeIcon.Size = UDim2.new(1, 0, 0.48, 0)
	badgeIcon.Position = UDim2.new(0, 0, 0.04, 0)
	badgeIcon.BackgroundTransparency = 1
	badgeIcon.Text = "🛡️"
	badgeIcon.TextScaled = true
	badgeIcon.Parent = levelBadge

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelText"
	levelLabel.Size = UDim2.new(1, 0, 0.42, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.52, 0)
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
	local playerNameLabel = Instance.new("TextLabel")
	playerNameLabel.Name = "PlayerName"
	playerNameLabel.Size = UDim2.new(1, -62, 0, 16)
	playerNameLabel.Position = UDim2.new(0, 56, 0, 6)
	playerNameLabel.BackgroundTransparency = 1
	playerNameLabel.Font = Enum.Font.GothamBold
	playerNameLabel.TextSize = 12
	playerNameLabel.TextColor3 = Color3.fromRGB(240, 242, 248)
	playerNameLabel.TextStrokeColor3 = Color3.fromRGB(12, 14, 18)
	playerNameLabel.TextStrokeTransparency = 0.3
	playerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	playerNameLabel.Text = player.DisplayName .. "  •  [WARRIOR TANK]"
	playerNameLabel.Parent = playerFrame

	-- Health Bar Container
	local playerHealthBg = Instance.new("Frame")
	playerHealthBg.Name = "HealthBg"
	playerHealthBg.Size = UDim2.new(1, -64, 0, 22)
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
	playerHealthText.TextSize = 11
	playerHealthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	playerHealthText.TextStrokeColor3 = Color3.fromRGB(12, 15, 14)
	playerHealthText.TextStrokeTransparency = 0.2
	playerHealthText.Text = "100 / 100 HP (100%)"
	playerHealthText.ZIndex = 4
	playerHealthText.Parent = playerHealthBg

	-- ── Boss Health Bar (Top-Center, hidden until fighting the boss starts) ───
	local bossHealthContainer = Instance.new("Frame")
	bossHealthContainer.Name = "BossHealthContainer"
	bossHealthContainer.Size = UDim2.new(0, 480, 0, 58)
	bossHealthContainer.Position = UDim2.new(0.5, -240, 0, 28)
	bossHealthContainer.BackgroundTransparency = 1
	bossHealthContainer.Visible = false
	bossHealthContainer.Parent = screenGui

	-- Boss Title Header Card
	local bossHeader = Instance.new("Frame")
	bossHeader.Name = "BossHeader"
	bossHeader.Size = UDim2.new(1, 0, 0, 26)
	bossHeader.Position = UDim2.new(0, 0, 0, 0)
	bossHeader.BackgroundTransparency = 1
	bossHeader.Parent = bossHealthContainer

	local bossNameLabel = Instance.new("TextLabel")
	bossNameLabel.Name = "BossName"
	bossNameLabel.Size = UDim2.new(1, 0, 0, 15)
	bossNameLabel.Position = UDim2.new(0, 0, 0, 0)
	bossNameLabel.BackgroundTransparency = 1
	bossNameLabel.Font = Enum.Font.GothamBold
	bossNameLabel.TextSize = 13
	bossNameLabel.TextColor3 = Color3.fromRGB(255, 220, 110)
	bossNameLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 22)
	bossNameLabel.TextStrokeTransparency = 0.2
	bossNameLabel.Text = "💀 ROCKHIDE THE EARTHBREAKER"
	bossNameLabel.Parent = bossHeader

	local bossSubtitleLabel = Instance.new("TextLabel")
	bossSubtitleLabel.Name = "BossSubtitle"
	bossSubtitleLabel.Size = UDim2.new(1, 0, 0, 11)
	bossSubtitleLabel.Position = UDim2.new(0, 0, 0, 15)
	bossSubtitleLabel.BackgroundTransparency = 1
	bossSubtitleLabel.Font = Enum.Font.Gotham
	bossSubtitleLabel.TextSize = 9
	bossSubtitleLabel.TextColor3 = Color3.fromRGB(195, 175, 135)
	bossSubtitleLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 22)
	bossSubtitleLabel.TextStrokeTransparency = 0.3
	bossSubtitleLabel.Text = "DUNGEON GUARDIAN • TANK ENCOUNTER"
	bossSubtitleLabel.Parent = bossHeader

	-- Boss Bar Background Plate
	local bossHealthBg = Instance.new("Frame")
	bossHealthBg.Name = "BarBg"
	bossHealthBg.Size = UDim2.new(1, 0, 0, 24)
	bossHealthBg.Position = UDim2.new(0, 0, 0, 28)
	bossHealthBg.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	bossHealthBg.BorderSizePixel = 0
	bossHealthBg.ClipsDescendants = true
	bossHealthBg.Parent = bossHealthContainer

	local bossBgCorner = Instance.new("UICorner")
	bossBgCorner.CornerRadius = UDim.new(0, 6)
	bossBgCorner.Parent = bossHealthBg

	local bossBgStroke = Instance.new("UIStroke")
	bossBgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bossBgStroke.Color = Color3.fromRGB(215, 175, 75)
	bossBgStroke.Thickness = 2
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
	bossGhostCorner.CornerRadius = UDim.new(0, 6)
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
	bossFillCorner.CornerRadius = UDim.new(0, 6)
	bossFillCorner.Parent = bossHealthFill

	local bossFillGrad = Instance.new("UIGradient")
	bossFillGrad.Color = ColorSequence.new(Color3.fromRGB(245, 60, 50), Color3.fromRGB(155, 18, 24))
	bossFillGrad.Parent = bossHealthFill

	-- Phase Notches (Tick marks at 25%, 50%, 75%)
	for _, notchPct in {0.25, 0.50, 0.75} do
		local notch = Instance.new("Frame")
		notch.Name = "Notch_" .. tostring(notchPct * 100)
		notch.Size = UDim2.new(0, 2, 1, 0)
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
	bossHealthText.TextSize = 12
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

	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(level, _unspentEXP)
		currentLevel = level
		if levelBadgeText then
			levelBadgeText.Text = "Lv. " .. tostring(level)
		end
	end)

	-- ── Dungeon Objective Tracker (Top-Left) ──────────────────────────────────
	local objectiveCard = Instance.new("Frame")
	objectiveCard.Name = "DungeonObjectiveCard"
	objectiveCard.Size = UDim2.new(0, 270, 0, 78)
	objectiveCard.Position = UDim2.new(0, 16, 0, 195)
	objectiveCard.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	objectiveCard.BackgroundTransparency = 0.15
	objectiveCard.BorderSizePixel = 0
	objectiveCard.Visible = false
	objectiveCard.Parent = screenGui

	local objCorner = Instance.new("UICorner")
	objCorner.CornerRadius = UDim.new(0, 8)
	objCorner.Parent = objectiveCard

	local objGrad = Instance.new("UIGradient")
	objGrad.Rotation = 45
	objGrad.Color = ColorSequence.new(Color3.fromRGB(24, 30, 42), Color3.fromRGB(14, 16, 24))
	objGrad.Parent = objectiveCard

	local objStroke = Instance.new("UIStroke")
	objStroke.Color = Color3.fromRGB(195, 155, 65)
	objStroke.Thickness = 1.6
	objStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	objStroke.Parent = objectiveCard

	local objHeader = Instance.new("TextLabel")
	objHeader.Size = UDim2.new(1, -20, 0, 20)
	objHeader.Position = UDim2.new(0, 10, 0, 6)
	objHeader.BackgroundTransparency = 1
	objHeader.TextColor3 = Color3.fromRGB(255, 215, 80)
	objHeader.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	objHeader.TextStrokeTransparency = 0.2
	objHeader.Font = Enum.Font.GothamBold
	objHeader.TextSize = 13
	objHeader.TextXAlignment = Enum.TextXAlignment.Left
	objHeader.Text = "📜 DUNGEON OBJECTIVE"
	objHeader.Parent = objectiveCard

	local objDesc = Instance.new("TextLabel")
	objDesc.Size = UDim2.new(1, -20, 0, 22)
	objDesc.Position = UDim2.new(0, 10, 0, 26)
	objDesc.BackgroundTransparency = 1
	objDesc.TextColor3 = Color3.fromRGB(240, 242, 250)
	objDesc.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	objDesc.TextStrokeTransparency = 0.3
	objDesc.Font = Enum.Font.GothamMedium
	objDesc.TextSize = 12
	objDesc.TextXAlignment = Enum.TextXAlignment.Left
	objDesc.Text = "Slay Dungeon Guardians (0 / 10)"
	objDesc.Parent = objectiveCard

	local objProgressBg = Instance.new("Frame")
	objProgressBg.Size = UDim2.new(1, -20, 0, 8)
	objProgressBg.Position = UDim2.new(0, 10, 0, 54)
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
		local statusLabel = partyGui and partyGui:FindFirstChild("StatusLabel")
		if statusLabel and statusLabel.Visible and statusLabel.Text ~= "" and statusLabel.Text ~= "No party" then
			objectiveCard.Position = UDim2.new(0, 16, 0, 135)
		else
			objectiveCard.Position = UDim2.new(0, 16, 0, 72)
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

	Net.Get("DungeonObjectiveChanged").OnClientEvent:Connect(function(text, currentKills, totalRequired, isUnlocked, isOpen)
		objectiveCard.Visible = true
		updateObjectivePosition()
		if isOpen then
			objDesc.TextColor3 = Color3.fromRGB(255, 120, 100)
			objDesc.Text = "👑 " .. text
			objProgressFill.Size = UDim2.new(1, 0, 1, 0)
			objProgressFill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
			objStroke.Color = Color3.fromRGB(200, 60, 50)
			clearEntranceBarriers()
			task.delay(0.5, clearEntranceBarriers)
			task.delay(1.5, clearEntranceBarriers)
		elseif isUnlocked then
			objDesc.TextColor3 = Color3.fromRGB(100, 255, 150)
			objDesc.Text = "✨ " .. text .. " [UNLOCKED]"
			objProgressFill.Size = UDim2.new(1, 0, 1, 0)
			objProgressFill.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
			objStroke.Color = Color3.fromRGB(100, 255, 150)
		else
			objDesc.TextColor3 = Color3.fromRGB(240, 240, 250)
			objDesc.Text = ("⚔️ %s (%d / %d)"):format(text, currentKills, totalRequired)
			local frac = math.clamp(currentKills / math.max(1, totalRequired), 0, 1)
			objProgressFill.Size = UDim2.new(frac, 0, 1, 0)
			objProgressFill.BackgroundColor3 = Color3.fromRGB(60, 200, 120)
			objStroke.Color = Color3.fromRGB(160, 130, 60)
		end
	end)

	-- ── Telegraph Ground Indicators ────────────────────────────────────────────
	Net.Get("TelegraphAttack").OnClientEvent:Connect(function(attackId, position, telegraphTime, radius)
		local attackRadius = radius or (BossAttacks[attackId] and BossAttacks[attackId].radius) or 10
		local diameter = attackRadius * 2

		-- Snap directly to ground floor geometry via downward raycast
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local char = Players.LocalPlayer and Players.LocalPlayer.Character
		if char then
			rayParams.FilterDescendantsInstances = {char}
		end
		local hit = workspace:Raycast(Vector3.new(position.X, 25, position.Z), Vector3.new(0, -60, 0), rayParams)
		local groundY = hit and (hit.Position.Y + 0.10) or (position.Y > 5 and 1.10 or position.Y)
		local groundPos = Vector3.new(position.X, groundY, position.Z)

		-- Main telegraph zone disc
		local indicator = Instance.new("Part")
		indicator.Name = "TelegraphIndicator_" .. attackId
		indicator.Shape = Enum.PartType.Cylinder
		indicator.Size = Vector3.new(0.12, diameter, diameter)
		indicator.Orientation = Vector3.new(0, 0, 90)
		indicator.Position = groundPos
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Color = Color3.fromRGB(255, 90, 25)
		indicator.Material = Enum.Material.Neon
		indicator.Transparency = 0.72
		indicator.Parent = workspace

		-- Perimeter warning ring
		local outerRing = Instance.new("Part")
		outerRing.Name = "TelegraphRing_" .. attackId
		outerRing.Shape = Enum.PartType.Cylinder
		outerRing.Size = Vector3.new(0.18, diameter + 0.6, diameter + 0.6)
		outerRing.Orientation = Vector3.new(0, 0, 90)
		outerRing.Position = groundPos + Vector3.new(0, 0.02, 0)
		outerRing.Anchored = true
		outerRing.CanCollide = false
		outerRing.Color = Color3.fromRGB(255, 185, 45)
		outerRing.Material = Enum.Material.Neon
		outerRing.Transparency = 0.65
		outerRing.Parent = workspace

		-- Pulsing border during telegraph
		local pulseTween = TweenService:Create(outerRing, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.88,
		})
		pulseTween:Play()

		task.delay(telegraphTime, function()
			pulseTween:Cancel()
			if indicator and indicator.Parent then indicator:Destroy() end
			if outerRing and outerRing.Parent then outerRing:Destroy() end
		end)
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
	attackFrame.Position = UDim2.new(1, -ATTACK_RIGHT_MARGIN - (ATTACK_BUTTON_SIZE / 2), 1, -ACTION_BAR_Y_CENTER)
	attackFrame.BackgroundColor3 = Color3.fromRGB(215, 45, 38)
	attackFrame.BorderSizePixel = 0
	attackFrame.Parent = screenGui

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
	attackStroke.Thickness = 4.5
	attackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	attackStroke.Parent = attackFrame

	-- Inner decorative ring for beveled action plate
	local innerRing = Instance.new("Frame")
	innerRing.Name = "InnerRing"
	innerRing.Size = UDim2.new(1, -14, 1, -14)
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

	-- Attack Icon (⚔️)
	local attackIcon = Instance.new("TextLabel")
	attackIcon.Name = "Icon"
	attackIcon.Size = UDim2.new(1, 0, 0.44, 0)
	attackIcon.Position = UDim2.new(0, 0, 0.08, 0)
	attackIcon.BackgroundTransparency = 1
	attackIcon.Text = "⚔️"
	attackIcon.TextScaled = true
	attackIcon.ZIndex = 2
	attackIcon.Parent = attackFrame

	-- Attack Label
	local attackLabel = Instance.new("TextLabel")
	attackLabel.Name = "Label"
	attackLabel.Size = UDim2.new(1, 0, 0.20, 0)
	attackLabel.Position = UDim2.new(0, 0, 0.52, 0)
	attackLabel.BackgroundTransparency = 1
	attackLabel.TextColor3 = Color3.fromRGB(255, 245, 215)
	attackLabel.TextStrokeColor3 = Color3.fromRGB(20, 10, 10)
	attackLabel.TextStrokeTransparency = 0.2
	attackLabel.Font = Enum.Font.GothamBlack
	attackLabel.TextScaled = true
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

	-- ── Skill Buttons (1-4) ────────────────────────────────────────────────────
	local skillYOffset = ACTION_BAR_Y_CENTER - (SKILL_BUTTON_SIZE / 2)
	local skillBaseOffset = ATTACK_RIGHT_MARGIN + ATTACK_BUTTON_SIZE + 16

	-- Dedicated Skills menu button
	local skillsMenuBtn = Instance.new("TextButton")
	skillsMenuBtn.Name = "SkillsMenuButton"
	skillsMenuBtn.Size = UDim2.new(0, 124, 0, 32)
	skillsMenuBtn.Position = UDim2.new(1, -skillBaseOffset - (TOTAL_SLOTS * (SKILL_BUTTON_SIZE + BUTTON_GAP)) + BUTTON_GAP, 1, -skillYOffset - SKILL_BUTTON_SIZE - 40)
	skillsMenuBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	skillsMenuBtn.BorderSizePixel = 0
	skillsMenuBtn.Font = Enum.Font.GothamBold
	skillsMenuBtn.TextSize = 12
	skillsMenuBtn.TextColor3 = Color3.fromRGB(255, 225, 90)
	skillsMenuBtn.Text = "📜 SKILLS"
	skillsMenuBtn.Parent = screenGui

	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0, 8)
	menuCorner.Parent = skillsMenuBtn

	local menuGrad = Instance.new("UIGradient")
	menuGrad.Rotation = 45
	menuGrad.Color = ColorSequence.new(Color3.fromRGB(36, 42, 58), Color3.fromRGB(18, 22, 32))
	menuGrad.Parent = skillsMenuBtn

	local menuStroke = Instance.new("UIStroke")
	menuStroke.Color = Color3.fromRGB(210, 170, 70)
	menuStroke.Thickness = 1.6
	menuStroke.Parent = skillsMenuBtn

	skillsMenuBtn.Activated:Connect(function()
		SkillTreeUIController.Toggle()
	end)

	for i = 1, TOTAL_SLOTS do
		local xOffset = skillBaseOffset + (TOTAL_SLOTS - i) * (SKILL_BUTTON_SIZE + BUTTON_GAP)

		local frame = Instance.new("Frame")
		frame.Name = "SkillSlot_" .. i
		frame.Size = UDim2.new(0, SKILL_BUTTON_SIZE, 0, SKILL_BUTTON_SIZE)
		frame.Position = UDim2.new(1, -xOffset - SKILL_BUTTON_SIZE, 1, -skillYOffset - SKILL_BUTTON_SIZE)
		frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
		frame.BorderSizePixel = 0
		frame.Parent = screenGui
		slotFrames[i] = frame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

		local slotGrad = Instance.new("UIGradient")
		slotGrad.Rotation = 45
		slotGrad.Color = ColorSequence.new(Color3.fromRGB(34, 40, 54), Color3.fromRGB(16, 20, 28))
		slotGrad.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(220, 180, 75)
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		slotStrokes[i] = stroke

		-- Icon Label
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 0.44, 0)
		iconLabel.Position = UDim2.new(0, 0, 0.14, 0)
		iconLabel.BackgroundTransparency = 1
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
		namePlate.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		namePlate.BackgroundTransparency = 0.25
		namePlate.BorderSizePixel = 0
		namePlate.ZIndex = 2
		namePlate.Parent = frame

		local nameCorner = Instance.new("UICorner")
		nameCorner.CornerRadius = UDim.new(0, 6)
		nameCorner.Parent = namePlate

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -4, 1, 0)
		nameLabel.Position = UDim2.new(0, 2, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.Text = ""
		nameLabel.ZIndex = 3
		nameLabel.Parent = namePlate
		slotNameLabels[i] = nameLabel

		-- Cooldown / Lock Label
		local cdLabel = Instance.new("TextLabel")
		cdLabel.Name = "CooldownLabel"
		cdLabel.Size = UDim2.new(1, 0, 0.48, 0)
		cdLabel.Position = UDim2.new(0, 0, 0.26, 0)
		cdLabel.BackgroundTransparency = 1
		cdLabel.TextColor3 = Color3.fromRGB(255, 225, 60)
		cdLabel.TextStrokeColor3 = Color3.fromRGB(10, 10, 15)
		cdLabel.TextStrokeTransparency = 0.2
		cdLabel.Font = Enum.Font.GothamBlack
		cdLabel.TextScaled = true
		cdLabel.Text = ""
		cdLabel.ZIndex = 5
		cdLabel.Parent = frame
		slotCdLabels[i] = cdLabel

		-- Dim Overlay
		local dimOverlay = Instance.new("Frame")
		dimOverlay.Name = "DimOverlay"
		dimOverlay.Size = UDim2.new(1, 0, 1, 0)
		dimOverlay.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		dimOverlay.BackgroundTransparency = 1
		dimOverlay.ZIndex = 4
		dimOverlay.Parent = frame
		slotDimOverlays[i] = dimOverlay

		local dimCorner = Instance.new("UICorner")
		dimCorner.CornerRadius = UDim.new(0, 10)
		dimCorner.Parent = dimOverlay

		local button = Instance.new("TextButton")
		button.Name = "HitArea"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 6
		button.Parent = frame

		local capturedSlot = i
		button.Activated:Connect(function()
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

			local skillId = equippedSkills[capturedSlot]
			if skillId then
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

	-- ── Pointer Input Handling (Mouse Click and Mobile Touch) ───────────────────
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Mouse Click or Mobile Touch Tap: selecting targets in 3D world only (NO attack)
		local isMouseClick = (input.UserInputType == Enum.UserInputType.MouseButton1)
		local isTouch = (input.UserInputType == Enum.UserInputType.Touch)

		if (isMouseClick or isTouch) and not gameProcessed then
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
	game:GetService("RunService").Heartbeat:Connect(function()
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
end

return HUDController
