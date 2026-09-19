-- src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua
-- Interactive MMO Skill Tree UI for Tank specializations (Juggernaut & Bulwark).
-- Features:
-- 1. High-Resolution Painted Dark-Fantasy Icons for all skills (no emojis).
-- 2. Fully Responsive Layout:
--    - Desktop: Dual-column side-by-side with large 16px/13px typography and high-res artwork.
--    - Mobile: Full-width branch switcher tabs with touch-friendly ScrollingFrames (never cut off).
-- 3. Strict Progression Order (Tier 1 -> Tier 2 -> Tier 3) with illuminated tier flow connectors.
-- 4. Overlap-proof geometry ensuring descriptions and stats never collide with action buttons.
-- 5. Dedicated active hotbar preview bar with clean icon preview and interactive slot assignment.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)

local SkillTreeUIController = {}

local screenGui: ScreenGui? = nil
local modalFrame: Frame? = nil
local modalScale: UIScale? = nil
local headerBar: Frame? = nil
local titleLabel: TextLabel? = nil
local pointsPill: Frame? = nil
local pillLabel: TextLabel? = nil
local pointsValueLabel: TextLabel? = nil
local closeBtn: TextButton? = nil
local branchTabsContainer: Frame? = nil
local branchesContainer: Frame? = nil
local bottomFrame: Frame? = nil
local equippedSlotsContainer: Frame? = nil
local bottomPromptLabel: TextLabel? = nil

local skillPoints = 0
local unlockedSkills: {string} = {"Taunt"}
local equippedSkills: {string} = {"Taunt"}
local isSelectingSlotForSkill: string? = nil
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

local TIER_TITLES = {
	[1] = "TIER I • NOVICE",
	[2] = "TIER II • ADEPT",
	[3] = "TIER III • MASTER",
}

local function isMobileViewport(): boolean
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	return vp.Y < 580 or vp.X < 880
end

local function playUISound(soundId: string, pitch: number?, volume: number?)
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Pitch = pitch or 1.0
		sound.Volume = volume or 0.5
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end)
end

local function isSkillUnlocked(id: string): boolean
	for _, unlockedId in ipairs(unlockedSkills) do
		if unlockedId == id then
			return true
		end
	end
	return false
end

local function getEquippedSlot(id: string): number?
	for i, eqId in ipairs(equippedSkills) do
		if eqId == id then
			return i
		end
	end
	return nil
end

local function canUnlockSkill(id: string): (boolean, string?)
	local skillData = Skills[id]
	if not skillData then
		return false, "Unknown"
	end
	if isSkillUnlocked(id) then
		return false, "Already Unlocked"
	end
	if skillData.prerequisite and not isSkillUnlocked(skillData.prerequisite) then
		local prereqData = Skills[skillData.prerequisite]
		local prereqName = prereqData and prereqData.displayName or skillData.prerequisite
		return false, "Req: " .. prereqName
	end
	if skillPoints < 1 then
		return false, "Needs 1 SP"
	end
	return true, nil
end

local function createSkillImageIcon(parent: Instance, imageId: string): ImageLabel
	local existing = parent:FindFirstChild("SkillImageIcon")
	if existing and existing:IsA("ImageLabel") then
		existing.Image = imageId
		existing.ScaleType = Enum.ScaleType.Crop
		existing.Visible = true
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

local refreshUI: () -> ()

local function updateResponsiveScale()
	if not modalScale or not modalFrame then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local vp = camera.ViewportSize
	local isMob = isMobileViewport()

	if isMob then
		-- Mobile layout: full-screen touch fit respecting Roblox topbar insets
		modalScale.Scale = 1.0
		modalFrame.Size = UDim2.new(0.98, 0, 0.96, 0)
		modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

		if headerBar then
			headerBar.Size = UDim2.new(1, 0, 0, 42)
		end
		if titleLabel then
			titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
			titleLabel.Position = UDim2.new(0, 12, 0, 0)
			titleLabel.TextSize = 14
			titleLabel.Text = "🛡️ TANK SPECIALIZATION"
		end
		if pointsPill then
			pointsPill.Size = UDim2.new(0, 126, 0, 28)
			pointsPill.Position = UDim2.new(1, -168, 0.5, -14)
		end
		if pillLabel then
			pillLabel.Size = UDim2.new(0.64, 0, 1, 0)
			pillLabel.Position = UDim2.new(0, 8, 0, 0)
			pillLabel.TextSize = 11
			pillLabel.Text = "POINTS:"
		end
		if pointsValueLabel then
			pointsValueLabel.Size = UDim2.new(0.36, 0, 1, 0)
			pointsValueLabel.Position = UDim2.new(0.64, 0, 0, 0)
			pointsValueLabel.TextSize = 16
		end
		if closeBtn then
			closeBtn.Size = UDim2.new(0, 30, 0, 30)
			closeBtn.Position = UDim2.new(1, -36, 0.5, -15)
			closeBtn.Text = "X"
			closeBtn.TextSize = 16
		end

		if branchTabsContainer then
			branchTabsContainer.Visible = true
			branchTabsContainer.Size = UDim2.new(1, -16, 0, 32)
			branchTabsContainer.Position = UDim2.new(0, 8, 0, 46)
		end

		if branchesContainer then
			branchesContainer.Position = UDim2.new(0, 8, 0, 82)
			branchesContainer.Size = UDim2.new(1, -16, 1, -140)
		end

		if bottomFrame then
			bottomFrame.Size = UDim2.new(1, -16, 0, 52)
			bottomFrame.Position = UDim2.new(0, 8, 1, -56)
		end
	else
		-- Desktop / Laptop layout: generous widescreen modal that fills the display beautifully
		-- Base reference: 1180 x 700 (utilizes 94% width and height on laptop screens)
		local scaleX = (vp.X * 0.94) / 1180
		local scaleY = (vp.Y * 0.94) / 700
		local targetScale = math.min(scaleX, scaleY)
		local scale = math.clamp(targetScale, 0.90, 1.65)

		modalScale.Scale = scale
		modalFrame.Size = UDim2.new(0, 1180, 0, 700)
		modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

		if headerBar then
			headerBar.Size = UDim2.new(1, 0, 0, 60)
		end
		if titleLabel then
			titleLabel.Size = UDim2.new(0.55, 0, 1, 0)
			titleLabel.Position = UDim2.new(0, 18, 0, 0)
			titleLabel.TextSize = 24
			titleLabel.Text = "🛡️ TANK SKILL SPECIALIZATION"
		end
		if pointsPill then
			pointsPill.Size = UDim2.new(0, 205, 0, 38)
			pointsPill.Position = UDim2.new(1, -265, 0.5, -19)
		end
		if pillLabel then
			pillLabel.Size = UDim2.new(0.68, 0, 1, 0)
			pillLabel.Position = UDim2.new(0, 10, 0, 0)
			pillLabel.TextSize = 15
			pillLabel.Text = "SKILL POINTS:"
		end
		if pointsValueLabel then
			pointsValueLabel.Size = UDim2.new(0.32, 0, 1, 0)
			pointsValueLabel.Position = UDim2.new(0.68, 0, 0, 0)
			pointsValueLabel.TextSize = 22
		end
		if closeBtn then
			closeBtn.Size = UDim2.new(0, 40, 0, 40)
			closeBtn.Position = UDim2.new(1, -50, 0.5, -20)
			closeBtn.Text = "X"
			closeBtn.TextSize = 20
		end

		if branchTabsContainer then
			branchTabsContainer.Visible = false
			branchTabsContainer.Size = UDim2.new(1, -24, 0, 38)
			branchTabsContainer.Position = UDim2.new(0, 12, 0, 64)
		end

		if branchesContainer then
			branchesContainer.Position = UDim2.new(0, 12, 0, 68)
			branchesContainer.Size = UDim2.new(1, -24, 1, -172)
		end

		if bottomFrame then
			bottomFrame.Size = UDim2.new(1, -24, 0, 88)
			bottomFrame.Position = UDim2.new(0, 12, 1, -96)
		end
	end
end

local function buildNodeCard(skillId: string, parent: Instance, branchName: string, isMobile: boolean): Frame
	local skill = Skills[skillId]
	local unlocked = isSkillUnlocked(skillId)
	local equippedSlot = getEquippedSlot(skillId)
	local canUnlock, lockReason = canUnlockSkill(skillId)
	local branchStyle = BRANCH_COLORS[branchName] or BRANCH_COLORS.Juggernaut

	local cardHeight = isMobile and 94 or 132
	local card = Instance.new("Frame")
	card.Name = "Node_" .. skillId
	card.Size = UDim2.new(1, 0, 0, cardHeight)
	card.LayoutOrder = (skill.tier or 1) * 10
	card.BackgroundColor3 = unlocked and branchStyle.cardBg or Color3.fromRGB(22, 25, 32)
	card.BorderSizePixel = 0
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = unlocked and 1.8 or (canUnlock and 1.6 or 1.0)
	stroke.Color = unlocked and Color3.fromRGB(75, 205, 120) or (canUnlock and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(52, 58, 68))
	stroke.Parent = card

	-- ── Left: Skill Icon Box ────────────────────────────────────────────────
	local iconSize = isMobile and 54 or 68
	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.new(0, iconSize, 0, iconSize)
	iconBox.Position = UDim2.new(0, isMobile and 8 or 10, 0.5, -(iconSize / 2))
	iconBox.BackgroundColor3 = unlocked and Color3.fromRGB(36, 44, 58) or Color3.fromRGB(16, 18, 24)
	iconBox.BorderSizePixel = 0
	iconBox.ClipsDescendants = true
	iconBox.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = iconBox

	local iconStroke = Instance.new("UIStroke")
	iconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	iconStroke.Thickness = 1.4
	iconStroke.Color = unlocked and branchStyle.accent or Color3.fromRGB(55, 60, 72)
	iconStroke.Transparency = unlocked and 0.2 or 0.5
	iconStroke.Parent = iconBox

	-- Render painted artwork from registered skill.icon
	local iconPath = skill.icon or "rbxasset://textures/Soulforge/taunt_icon.png"
	createSkillImageIcon(iconBox, iconPath)

	-- Corner Tier Indicator Badge (T1, T2, T3)
	local tierTag = Instance.new("Frame")
	tierTag.Size = UDim2.new(0, isMobile and 24 or 26, 0, isMobile and 16 or 18)
	tierTag.Position = UDim2.new(0, 2, 1, isMobile and -18 or -20)
	tierTag.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
	tierTag.BackgroundTransparency = 0.15
	tierTag.BorderSizePixel = 0
	tierTag.ZIndex = 4
	tierTag.Parent = iconBox

	local tierCorner = Instance.new("UICorner")
	tierCorner.CornerRadius = UDim.new(0, 4)
	tierCorner.Parent = tierTag

	local tierText = Instance.new("TextLabel")
	tierText.Size = UDim2.new(1, 0, 1, 0)
	tierText.BackgroundTransparency = 1
	tierText.TextColor3 = unlocked and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(170, 175, 185)
	tierText.Font = Enum.Font.GothamBold
	tierText.TextSize = isMobile and 10 or 12
	tierText.Text = "T" .. tostring(skill.tier or 1)
	tierText.ZIndex = 5
	tierText.Parent = tierTag

	-- ── Right: Action Button Area ───────────────────────────────────────────
	local btnWidth = isMobile and 98 or 136
	local btnHeight = isMobile and 42 or 56
	local actionBtn = Instance.new("TextButton")
	actionBtn.Name = "ActionButton"
	actionBtn.Size = UDim2.new(0, btnWidth, 0, btnHeight)
	actionBtn.Position = UDim2.new(1, -(btnWidth + (isMobile and 8 or 10)), 0.5, -(btnHeight / 2))
	actionBtn.BorderSizePixel = 0
	actionBtn.AutoButtonColor = true
	actionBtn.Text = ""
	actionBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = actionBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btnStroke.Thickness = 1.4
	btnStroke.Parent = actionBtn

	local btnTitle = Instance.new("TextLabel")
	btnTitle.Name = "BtnTitle"
	btnTitle.Size = UDim2.new(1, 0, 0, isMobile and 20 or 26)
	btnTitle.Position = UDim2.new(0, 0, 0, isMobile and 2 or 4)
	btnTitle.BackgroundTransparency = 1
	btnTitle.Font = Enum.Font.GothamBold
	btnTitle.TextSize = isMobile and 12 or 16.5
	btnTitle.Parent = actionBtn

	local btnSubtext = Instance.new("TextLabel")
	btnSubtext.Name = "BtnSubtext"
	btnSubtext.Size = UDim2.new(1, -4, 0, isMobile and 16 or 20)
	btnSubtext.Position = UDim2.new(0, 2, 0, isMobile and 22 or 30)
	btnSubtext.BackgroundTransparency = 1
	btnSubtext.Font = Enum.Font.GothamMedium
	btnSubtext.TextSize = isMobile and 9.5 or 13.5
	btnSubtext.TextWrapped = true
	btnSubtext.Parent = actionBtn

	if unlocked then
		if equippedSlot then
			actionBtn.BackgroundColor3 = Color3.fromRGB(24, 88, 50)
			btnStroke.Color = Color3.fromRGB(65, 205, 110)
			btnTitle.TextColor3 = Color3.fromRGB(225, 255, 235)
			btnTitle.Text = "✓ EQUIPPED"
			btnSubtext.TextColor3 = Color3.fromRGB(165, 240, 190)
			btnSubtext.Text = ("[ Slot %d ]"):format(equippedSlot)
			actionBtn.AutoButtonColor = false
		else
			if isSelectingSlotForSkill == skillId then
				actionBtn.BackgroundColor3 = Color3.fromRGB(195, 130, 25)
				btnStroke.Color = Color3.fromRGB(255, 220, 80)
				btnTitle.TextColor3 = Color3.new(1, 1, 1)
				btnTitle.Text = "SELECT SLOT"
				btnSubtext.TextColor3 = Color3.fromRGB(255, 240, 190)
				btnSubtext.Text = "Tap Slot Below ▼"
			else
				actionBtn.BackgroundColor3 = Color3.fromRGB(36, 105, 195)
				btnStroke.Color = Color3.fromRGB(80, 170, 255)
				btnTitle.TextColor3 = Color3.new(1, 1, 1)
				btnTitle.Text = "⚡ EQUIP"
				btnSubtext.TextColor3 = Color3.fromRGB(195, 225, 255)
				btnSubtext.Text = "Assign to Hotbar"
				actionBtn.Activated:Connect(function()
					playUISound("rbxasset://sounds/electronicpingshort.wav", 1.5, 0.4)
					if #equippedSkills < 4 then
						Net.Get("RequestEquipSkill"):FireServer(skillId, #equippedSkills + 1)
					else
						isSelectingSlotForSkill = skillId
						refreshUI()
					end
				end)
			end
		end
	elseif canUnlock then
		actionBtn.BackgroundColor3 = Color3.fromRGB(32, 140, 72)
		btnStroke.Color = Color3.fromRGB(255, 215, 80)
		btnTitle.TextColor3 = Color3.new(1, 1, 1)
		btnTitle.Text = "✨ UNLOCK"
		btnSubtext.TextColor3 = Color3.fromRGB(255, 235, 150)
		btnSubtext.Text = "Cost: 1 Skill Point"
		actionBtn.Activated:Connect(function()
			playUISound("rbxasset://sounds/electronicpingshort.wav", 1.1, 0.6)
			Net.Get("RequestUnlockSkill"):FireServer(skillId)
		end)
	else
		actionBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
		btnStroke.Color = Color3.fromRGB(52, 56, 66)
		btnTitle.TextColor3 = Color3.fromRGB(130, 135, 145)
		btnTitle.Text = "🔒 LOCKED"
		btnSubtext.TextColor3 = Color3.fromRGB(160, 145, 120)
		btnSubtext.Text = lockReason or "Prerequisite Req."
		actionBtn.AutoButtonColor = false
	end

	-- ── Center: Content Container (Guaranteed No-Overlap Buffer) ──────────────
	local contentX = iconSize + (isMobile and 10 or 16)
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Position = UDim2.new(0, contentX, 0, isMobile and 4 or 8)
	contentFrame.Size = UDim2.new(1, -(contentX + btnWidth + (isMobile and 10 or 14)), 1, isMobile and -8 or -16)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ClipsDescendants = false
	contentFrame.Parent = card

	-- Row 1: Skill Title
	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.Size = UDim2.new(1, 0, 0, isMobile and 20 or 28)
	titleRow.BackgroundTransparency = 1
	titleRow.Parent = contentFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = unlocked and Color3.fromRGB(255, 255, 255) or (canUnlock and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(175, 180, 192))
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = isMobile and 13.5 or 21
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.None
	titleLabel.Text = skill.displayName or skillId
	titleLabel.Parent = titleRow

	-- Row 2: Stats Row (Tier Badge + Cooldown, Damage, Heal, Duration)
	local statsRow = Instance.new("Frame")
	statsRow.Name = "StatsRow"
	statsRow.Size = UDim2.new(1, 0, 0, isMobile and 18 or 26)
	statsRow.Position = UDim2.new(0, 0, 0, isMobile and 22 or 30)
	statsRow.BackgroundTransparency = 1
	statsRow.Parent = contentFrame

	local sLayout = Instance.new("UIListLayout")
	sLayout.FillDirection = Enum.FillDirection.Horizontal
	sLayout.Padding = UDim.new(0, isMobile and 4 or 6)
	sLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sLayout.Parent = statsRow

	-- Tier Badge Pill (e.g. TIER I • NOVICE)
	local tierPill = Instance.new("Frame")
	tierPill.Size = UDim2.new(0, isMobile and 84 or 124, 0, isMobile and 18 or 24)
	tierPill.BackgroundColor3 = unlocked and branchStyle.secondary or Color3.fromRGB(32, 36, 46)
	tierPill.BorderSizePixel = 0
	tierPill.Parent = statsRow

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 4)
	tCorner.Parent = tierPill

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = unlocked and branchStyle.accent or Color3.fromRGB(65, 72, 85)
	tStroke.Thickness = 1
	tStroke.Parent = tierPill

	local tText = Instance.new("TextLabel")
	tText.Size = UDim2.new(1, 0, 1, 0)
	tText.BackgroundTransparency = 1
	tText.TextColor3 = unlocked and Color3.fromRGB(255, 235, 170) or Color3.fromRGB(180, 188, 200)
	tText.Font = Enum.Font.GothamBold
	tText.TextSize = isMobile and 9.5 or 13.5
	tText.Text = TIER_TITLES[skill.tier or 1] or "TIER I"
	tText.Parent = tierPill

	-- Cooldown Pill
	local cdPill = Instance.new("Frame")
	cdPill.Size = UDim2.new(0, isMobile and 54 or 82, 0, isMobile and 18 or 24)
	cdPill.BackgroundColor3 = Color3.fromRGB(30, 38, 52)
	cdPill.BorderSizePixel = 0
	cdPill.Parent = statsRow

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0, 4)
	cdCorner.Parent = cdPill

	local cdText = Instance.new("TextLabel")
	cdText.Size = UDim2.new(1, 0, 1, 0)
	cdText.BackgroundTransparency = 1
	cdText.TextColor3 = Color3.fromRGB(125, 205, 255)
	cdText.Font = Enum.Font.GothamBold
	cdText.TextSize = isMobile and 9.5 or 14.5
	cdText.Text = ("⏱ %ds CD"):format(skill.cooldown or 0)
	cdText.Parent = cdPill

	-- Damage Pill (if any)
	if skill.damage and skill.damage > 0 then
		local dmgPill = Instance.new("Frame")
		dmgPill.Size = UDim2.new(0, isMobile and 58 or 88, 0, isMobile and 18 or 24)
		dmgPill.BackgroundColor3 = Color3.fromRGB(52, 28, 28)
		dmgPill.BorderSizePixel = 0
		dmgPill.Parent = statsRow

		local dmgCorner = Instance.new("UICorner")
		dmgCorner.CornerRadius = UDim.new(0, 4)
		dmgCorner.Parent = dmgPill

		local dmgText = Instance.new("TextLabel")
		dmgText.Size = UDim2.new(1, 0, 1, 0)
		dmgText.BackgroundTransparency = 1
		dmgText.TextColor3 = Color3.fromRGB(255, 135, 125)
		dmgText.Font = Enum.Font.GothamBold
		dmgText.TextSize = isMobile and 9.5 or 14.5
		dmgText.Text = ("⚔ %d Dmg"):format(skill.damage)
		dmgText.Parent = dmgPill
	end

	-- Heal Pill (if any)
	if skill.healAmount and skill.healAmount > 0 then
		local healPill = Instance.new("Frame")
		healPill.Size = UDim2.new(0, isMobile and 60 or 92, 0, isMobile and 18 or 24)
		healPill.BackgroundColor3 = Color3.fromRGB(25, 48, 34)
		healPill.BorderSizePixel = 0
		healPill.Parent = statsRow

		local healCorner = Instance.new("UICorner")
		healCorner.CornerRadius = UDim.new(0, 4)
		healCorner.Parent = healPill

		local healText = Instance.new("TextLabel")
		healText.Size = UDim2.new(1, 0, 1, 0)
		healText.BackgroundTransparency = 1
		healText.TextColor3 = Color3.fromRGB(135, 245, 165)
		healText.Font = Enum.Font.GothamBold
		healText.TextSize = isMobile and 9.5 or 14.5
		healText.Text = ("💚 %d Heal"):format(skill.healAmount)
		healText.Parent = healPill
	end

	-- Duration Pill (if any)
	if skill.duration and skill.duration > 0 then
		local durPill = Instance.new("Frame")
		durPill.Size = UDim2.new(0, isMobile and 52 or 80, 0, isMobile and 18 or 24)
		durPill.BackgroundColor3 = Color3.fromRGB(44, 40, 24)
		durPill.BorderSizePixel = 0
		durPill.Parent = statsRow

		local durCorner = Instance.new("UICorner")
		durCorner.CornerRadius = UDim.new(0, 4)
		durCorner.Parent = durPill

		local durText = Instance.new("TextLabel")
		durText.Size = UDim2.new(1, 0, 1, 0)
		durText.BackgroundTransparency = 1
		durText.TextColor3 = Color3.fromRGB(255, 220, 95)
		durText.Font = Enum.Font.GothamBold
		durText.TextSize = isMobile and 9.5 or 14.5
		durText.Text = ("🛡 %ds"):format(skill.duration)
		durText.Parent = durPill
	end

	-- Row 3: Description (Clean, readable typography with generous vertical room)
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(1, 0, 1, isMobile and -42 or -60)
	descLabel.Position = UDim2.new(0, 0, 0, isMobile and 42 or 58)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(205, 214, 228)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = isMobile and 11 or 16
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Text = skill.description or ""
	descLabel.Parent = contentFrame

	return card
end

local function buildTierConnector(tierIndex: number, isUnlocked: boolean, branchColor: Color3, parent: Instance, isMobile: boolean): Frame
	local connector = Instance.new("Frame")
	connector.Name = "Connector_Tier_" .. tierIndex
	connector.Size = UDim2.new(1, 0, 0, isMobile and 12 or 18)
	connector.LayoutOrder = tierIndex * 10 - 5
	connector.BackgroundTransparency = 1
	connector.Parent = parent

	-- Centered Line
	local line = Instance.new("Frame")
	line.Size = UDim2.new(0, 2, 1, 0)
	line.Position = UDim2.new(0.5, -1, 0, 0)
	line.BackgroundColor3 = isUnlocked and branchColor or Color3.fromRGB(48, 54, 65)
	line.BorderSizePixel = 0
	line.Parent = connector

	-- Arrow Indicator
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(0, isMobile and 14 or 18, 0, isMobile and 10 or 14)
	arrow.Position = UDim2.new(0.5, isMobile and -7 or -9, 0.5, isMobile and -5 or -7)
	arrow.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	arrow.TextColor3 = isUnlocked and branchColor or Color3.fromRGB(75, 82, 95)
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = isMobile and 9 or 11
	arrow.Text = "▼"
	arrow.BorderSizePixel = 0
	arrow.Parent = connector

	return connector
end

refreshUI = function()
	if not modalFrame or not screenGui or not screenGui.Enabled then
		return
	end

	local isMobile = isMobileViewport()

	if pointsValueLabel then
		pointsValueLabel.Text = tostring(skillPoints)
	end

	if bottomPromptLabel then
		if isMobile then
			if isSelectingSlotForSkill then
				local targetSkill = Skills[isSelectingSlotForSkill]
				local skillName = targetSkill and targetSkill.displayName or isSelectingSlotForSkill
				bottomPromptLabel.Visible = true
				bottomPromptLabel.Text = ("⚡ TAP A SLOT BELOW TO EQUIP [%s] (OR CANCEL)"):format(string.upper(skillName))
				bottomPromptLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
				bottomPromptLabel.TextSize = 10.5
				bottomPromptLabel.Position = UDim2.new(0, 8, 0, 2)
				bottomPromptLabel.Size = UDim2.new(1, -16, 0, 14)
			else
				bottomPromptLabel.Visible = false
			end
		else
			bottomPromptLabel.Visible = true
			bottomPromptLabel.Position = UDim2.new(0, 12, 0, 5)
			bottomPromptLabel.Size = UDim2.new(1, -20, 0, 22)
			bottomPromptLabel.TextSize = 14.5
			if isSelectingSlotForSkill then
				local targetSkill = Skills[isSelectingSlotForSkill]
				local skillName = targetSkill and targetSkill.displayName or isSelectingSlotForSkill
				bottomPromptLabel.Text = ("⚡ SELECT A SLOT BELOW TO EQUIP [%s] (OR CLICK CANCEL)"):format(string.upper(skillName))
				bottomPromptLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
			else
				bottomPromptLabel.Text = "ACTIVE ACTION SLOTS: Click an unlocked ability above to equip it into your hotbar."
				bottomPromptLabel.TextColor3 = Color3.fromRGB(180, 190, 205)
			end
		end
	end

	if equippedSlotsContainer then
		if isMobile then
			if isSelectingSlotForSkill then
				equippedSlotsContainer.Position = UDim2.new(0, 6, 0, 16)
				equippedSlotsContainer.Size = UDim2.new(1, -12, 0, 32)
			else
				equippedSlotsContainer.Position = UDim2.new(0, 6, 0.5, -19)
				equippedSlotsContainer.Size = UDim2.new(1, -12, 0, 38)
			end
		else
			equippedSlotsContainer.Position = UDim2.new(0, 8, 0, 28)
			equippedSlotsContainer.Size = UDim2.new(1, -16, 0, 54)
		end
	end

	-- ── Branch Tabs (Visible on Mobile to give 100% width and zero cut-off) ───
	if branchTabsContainer then
		branchTabsContainer.Visible = isMobile
		branchTabsContainer:ClearAllChildren()

		if isMobile then
			local tabLayout = Instance.new("UIListLayout")
			tabLayout.FillDirection = Enum.FillDirection.Horizontal
			tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			tabLayout.Padding = UDim.new(0, 8)
			tabLayout.Parent = branchTabsContainer

			local tankData = Classes.Tank
			for _, branchName in ipairs(BRANCH_ORDER) do
				local colStyle = BRANCH_COLORS[branchName]
				local isSelected = (activeMobileBranch == branchName)
				local branchInfo = tankData and tankData.branches and tankData.branches[branchName]
				local unlockedCount = 0
				local totalCount = 3
				if branchInfo then
					totalCount = #branchInfo.skills
					for _, sId in ipairs(branchInfo.skills) do
						if isSkillUnlocked(sId) then
							unlockedCount += 1
						end
					end
				end

				local tabBtn = Instance.new("TextButton")
				tabBtn.Name = "Tab_" .. branchName
				tabBtn.Size = UDim2.new(0.485, 0, 1, 0)
				tabBtn.BackgroundColor3 = isSelected and colStyle.border or Color3.fromRGB(24, 28, 38)
				tabBtn.BorderSizePixel = 0
				tabBtn.Font = Enum.Font.GothamBold
				tabBtn.TextSize = 13
				tabBtn.TextColor3 = isSelected and Color3.new(1, 1, 1) or Color3.fromRGB(160, 170, 185)
				local iconPrefix = branchName == "Bulwark" and "🛡️ " or "⚔️ "
				tabBtn.Text = ("%s%s (%d/%d)"):format(iconPrefix, colStyle.name, unlockedCount, totalCount)
				tabBtn.Parent = branchTabsContainer

				local tCorner = Instance.new("UICorner")
				tCorner.CornerRadius = UDim.new(0, 8)
				tCorner.Parent = tabBtn

				local tStroke = Instance.new("UIStroke")
				tStroke.Color = isSelected and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(50, 56, 68)
				tStroke.Thickness = isSelected and 2.0 or 1.0
				tStroke.Parent = tabBtn

				tabBtn.Activated:Connect(function()
					playUISound("rbxasset://sounds/electronicpingshort.wav", 1.4, 0.3)
					activeMobileBranch = branchName
					refreshUI()
				end)
			end
		end
	end

	-- ── Render Branch Columns (Dual-Column on Desktop, Single-Branch on Mobile)
	if branchesContainer then
		branchesContainer:ClearAllChildren()

		local tankData = Classes.Tank
		if tankData and tankData.branches then
			local branchesToShow = isMobile and {activeMobileBranch} or BRANCH_ORDER

			local branchesLayout = Instance.new("UIListLayout")
			branchesLayout.FillDirection = Enum.FillDirection.Horizontal
			branchesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			branchesLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			branchesLayout.Padding = UDim.new(0, 16)
			branchesLayout.Parent = branchesContainer

			for _, branchName in ipairs(branchesToShow) do
				local branchInfo = tankData.branches[branchName]
				if not branchInfo then
					continue
				end

				local colStyle = BRANCH_COLORS[branchName] or BRANCH_COLORS.Juggernaut

				local unlockedCount = 0
				for _, sId in ipairs(branchInfo.skills) do
					if isSkillUnlocked(sId) then
						unlockedCount += 1
					end
				end

				local column = Instance.new("Frame")
				column.Name = "Branch_" .. branchName
				column.Size = isMobile and UDim2.new(1, 0, 1, 0) or UDim2.new(0.488, 0, 1, 0)
				column.BackgroundColor3 = colStyle.bg
				column.BorderSizePixel = 0
				column.Parent = branchesContainer

				local colCorner = Instance.new("UICorner")
				colCorner.CornerRadius = UDim.new(0, 10)
				colCorner.Parent = column

				local colStroke = Instance.new("UIStroke")
				colStroke.Color = colStyle.border
				colStroke.Thickness = 1.6
				colStroke.Parent = column

				-- Branch Header Banner
				local colHeader = Instance.new("Frame")
				colHeader.Size = UDim2.new(1, 0, 0, isMobile and 26 or 60)
				colHeader.BackgroundColor3 = isMobile and Color3.fromRGB(15, 18, 25) or colStyle.border
				colHeader.BorderSizePixel = 0
				colHeader.Parent = column

				local headCorner = Instance.new("UICorner")
				headCorner.CornerRadius = UDim.new(0, isMobile and 6 or 10)
				headCorner.Parent = colHeader

				if not isMobile then
					local colTitle = Instance.new("TextLabel")
					colTitle.Size = UDim2.new(1, -110, 0, 28)
					colTitle.Position = UDim2.new(0, 14, 0, 4)
					colTitle.BackgroundTransparency = 1
					colTitle.TextColor3 = Color3.new(1, 1, 1)
					colTitle.Font = Enum.Font.GothamBold
					colTitle.TextSize = 20
					colTitle.TextXAlignment = Enum.TextXAlignment.Left
					colTitle.Text = colStyle.displayName
					colTitle.Parent = colHeader

					local colDesc = Instance.new("TextLabel")
					colDesc.Size = UDim2.new(1, -110, 0, 22)
					colDesc.Position = UDim2.new(0, 14, 0, 32)
					colDesc.BackgroundTransparency = 1
					colDesc.TextColor3 = Color3.fromRGB(225, 232, 245)
					colDesc.Font = Enum.Font.Gotham
					colDesc.TextSize = 15
					colDesc.TextXAlignment = Enum.TextXAlignment.Left
					colDesc.Text = colStyle.tagline
					colDesc.Parent = colHeader

					-- Branch Mastery Progress Pill (e.g. 1 / 3)
					local progPill = Instance.new("Frame")
					progPill.Size = UDim2.new(0, 88, 0, 32)
					progPill.Position = UDim2.new(1, -98, 0.5, -16)
					progPill.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
					progPill.BorderSizePixel = 0
					progPill.Parent = colHeader

					local pCorner = Instance.new("UICorner")
					pCorner.CornerRadius = UDim.new(0, 6)
					pCorner.Parent = progPill

					local pStroke = Instance.new("UIStroke")
					pStroke.Color = colStyle.accent
					pStroke.Thickness = 1.2
					pStroke.Parent = progPill

					local progLabel = Instance.new("TextLabel")
					progLabel.Size = UDim2.new(1, 0, 1, 0)
					progLabel.BackgroundTransparency = 1
					progLabel.TextColor3 = Color3.fromRGB(255, 235, 170)
					progLabel.Font = Enum.Font.GothamBold
					progLabel.TextSize = 15.5
					progLabel.Text = ("%d / %d"):format(unlockedCount, #branchInfo.skills)
					progLabel.Parent = progPill
				else
					local colDesc = Instance.new("TextLabel")
					colDesc.Size = UDim2.new(1, -16, 1, 0)
					colDesc.Position = UDim2.new(0, 8, 0, 0)
					colDesc.BackgroundTransparency = 1
					colDesc.TextColor3 = colStyle.accent
					colDesc.Font = Enum.Font.GothamMedium
					colDesc.TextSize = 11.5
					colDesc.TextXAlignment = Enum.TextXAlignment.Center
					colDesc.Text = "✧ " .. colStyle.tagline
					colDesc.Parent = colHeader
				end

				-- ScrollingFrame for Nodes: GUARANTEED NEVER TO CUT OFF TEXT ON MOBILE OR DESKTOP
				local nodesList = Instance.new("ScrollingFrame")
				nodesList.Name = "NodesList"
				nodesList.Size = UDim2.new(1, -12, 1, isMobile and -32 or -70)
				nodesList.Position = UDim2.new(0, 6, 0, isMobile and 30 or 64)
				nodesList.BackgroundTransparency = 1
				nodesList.BorderSizePixel = 0
				nodesList.ScrollBarThickness = 5
				nodesList.ScrollBarImageColor3 = Color3.fromRGB(195, 160, 70)
				nodesList.CanvasSize = UDim2.new(0, 0, 0, 0)
				nodesList.AutomaticCanvasSize = Enum.AutomaticSize.Y
				nodesList.ScrollingDirection = Enum.ScrollingDirection.Y
				nodesList.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
				nodesList.ClipsDescendants = true
				nodesList.Parent = column

				local nLayout = Instance.new("UIListLayout")
				nLayout.SortOrder = Enum.SortOrder.LayoutOrder
				nLayout.FillDirection = Enum.FillDirection.Vertical
				nLayout.Padding = UDim.new(0, 6)
				nLayout.Parent = nodesList

				-- Sort skills deterministically by Tier 1 -> Tier 2 -> Tier 3
				local sortedSkills = table.clone(branchInfo.skills)
				table.sort(sortedSkills, function(a, b)
					local skillA = Skills[a]
					local skillB = Skills[b]
					local tierA = skillA and skillA.tier or 1
					local tierB = skillB and skillB.tier or 1
					return tierA < tierB
				end)

				for idx, skillId in ipairs(sortedSkills) do
					buildNodeCard(skillId, nodesList, branchName, isMobile)

					if idx < #sortedSkills then
						local thisUnlocked = isSkillUnlocked(skillId)
						buildTierConnector(idx + 1, thisUnlocked, colStyle.primary, nodesList, isMobile)
					end
				end
			end
		end
	end

	-- ── Render Active Hotbar Preview Slots (1 to 4) ─────────────────────────
	if equippedSlotsContainer then
		equippedSlotsContainer:ClearAllChildren()

		local barLayout = Instance.new("UIListLayout")
		barLayout.FillDirection = Enum.FillDirection.Horizontal
		barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		barLayout.Padding = UDim.new(0, isMobile and 6 or 10)
		barLayout.Parent = equippedSlotsContainer

		for slotIndex = 1, 4 do
			local eqId = equippedSkills[slotIndex]
			local skillData = eqId and Skills[eqId]
			local isTargeted = isSelectingSlotForSkill ~= nil

			local slotBox = Instance.new("Frame")
			slotBox.Name = "Slot_" .. slotIndex
			slotBox.Size = isMobile and UDim2.new(0.24, -4, 1, 0) or UDim2.new(0, 205, 0, 52)
			slotBox.BackgroundColor3 = isTargeted and Color3.fromRGB(44, 38, 24) or (skillData and Color3.fromRGB(28, 35, 48) or Color3.fromRGB(18, 20, 26))
			slotBox.BorderSizePixel = 0
			slotBox.Parent = equippedSlotsContainer

			local sCorner = Instance.new("UICorner")
			sCorner.CornerRadius = UDim.new(0, 8)
			sCorner.Parent = slotBox

			local sStroke = Instance.new("UIStroke")
			sStroke.Color = isTargeted and Color3.fromRGB(255, 215, 80) or (skillData and Color3.fromRGB(75, 98, 130) or Color3.fromRGB(48, 52, 64))
			sStroke.Thickness = isTargeted and 1.8 or 1.2
			sStroke.Parent = slotBox

			-- Slot Key Number Badge [1-4]
			local keyBadge = Instance.new("Frame")
			keyBadge.Size = UDim2.new(0, isMobile and 18 or 24, 0, isMobile and 18 or 24)
			keyBadge.Position = UDim2.new(0, isMobile and 4 or 6, 0.5, isMobile and -9 or -12)
			keyBadge.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
			keyBadge.BorderSizePixel = 0
			keyBadge.Parent = slotBox

			local kCorner = Instance.new("UICorner")
			kCorner.CornerRadius = UDim.new(0, 4)
			kCorner.Parent = keyBadge

			local kStroke = Instance.new("UIStroke")
			kStroke.Color = Color3.fromRGB(185, 155, 70)
			kStroke.Thickness = 1
			kStroke.Parent = keyBadge

			local keyText = Instance.new("TextLabel")
			keyText.Size = UDim2.new(1, 0, 1, 0)
			keyText.BackgroundTransparency = 1
			keyText.TextColor3 = Color3.fromRGB(255, 225, 100)
			keyText.Font = Enum.Font.GothamBold
			keyText.TextSize = isMobile and 10.5 or 13.5
			keyText.Text = tostring(slotIndex)
			keyText.Parent = keyBadge

			-- Skill Icon Tile (Image Texture Only - NO RAW ASSET PATH IN TEXT)
			local slotIconFrame = Instance.new("Frame")
			slotIconFrame.Size = UDim2.new(0, isMobile and 28 or 38, 0, isMobile and 28 or 38)
			slotIconFrame.Position = UDim2.new(0, isMobile and 26 or 34, 0.5, isMobile and -14 or -19)
			slotIconFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
			slotIconFrame.BorderSizePixel = 0
			slotIconFrame.ClipsDescendants = true
			slotIconFrame.Parent = slotBox

			local siCorner = Instance.new("UICorner")
			siCorner.CornerRadius = UDim.new(0, 6)
			siCorner.Parent = slotIconFrame

			if skillData and skillData.icon then
				createSkillImageIcon(slotIconFrame, skillData.icon)
			else
				local emptyPlus = Instance.new("TextLabel")
				emptyPlus.Size = UDim2.new(1, 0, 1, 0)
				emptyPlus.BackgroundTransparency = 1
				emptyPlus.TextColor3 = Color3.fromRGB(90, 96, 110)
				emptyPlus.Font = Enum.Font.GothamBold
				emptyPlus.TextSize = isMobile and 13 or 16
				emptyPlus.Text = "+"
				emptyPlus.Parent = slotIconFrame
			end

			-- Clean Skill Display Name (Never asset paths!)
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, isMobile and -58 or -80, 1, 0)
			nameLabel.Position = UDim2.new(0, isMobile and 56 or 78, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.TextColor3 = isTargeted and Color3.fromRGB(255, 225, 120) or (skillData and Color3.fromRGB(240, 246, 255) or Color3.fromRGB(115, 120, 130))
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = isMobile and 10 or 14.5
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Text = isTargeted and "TAP EQUIP" or (skillData and (skillData.displayName or eqId) or "(Empty)")
			nameLabel.Parent = slotBox

			-- Interactive Button
			local slotBtn = Instance.new("TextButton")
			slotBtn.Size = UDim2.new(1, 0, 1, 0)
			slotBtn.BackgroundTransparency = 1
			slotBtn.Text = ""
			slotBtn.Parent = slotBox

			slotBtn.Activated:Connect(function()
				if isSelectingSlotForSkill then
					playUISound("rbxasset://sounds/electronicpingshort.wav", 1.3, 0.5)
					Net.Get("RequestEquipSkill"):FireServer(isSelectingSlotForSkill, slotIndex)
					isSelectingSlotForSkill = nil
					refreshUI()
				end
			end)
		end
	end
end

function SkillTreeUIController.Toggle()
	if not screenGui then
		return
	end
	if screenGui.Enabled then
		SkillTreeUIController.Close()
	else
		SkillTreeUIController.Open()
	end
end

function SkillTreeUIController.Open()
	if not screenGui or not modalFrame then
		return
	end
	screenGui.Enabled = true
	isSelectingSlotForSkill = nil
	updateResponsiveScale()
	refreshUI()

	playUISound("rbxasset://sounds/electronicpingshort.wav", 1.4, 0.35)

	local targetPos = UDim2.new(0.5, 0, 0.5, 0)
	modalFrame.Position = UDim2.new(0.5, 0, 0.53, 0)

	local tween = TweenService:Create(modalFrame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPos,
	})
	tween:Play()
end

function SkillTreeUIController.Close()
	if not screenGui or not modalFrame then
		return
	end
	isSelectingSlotForSkill = nil

	local tween = TweenService:Create(modalFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.54, 0),
	})
	tween:Play()
	task.delay(0.18, function()
		if screenGui then
			screenGui.Enabled = false
		end
	end)
end

function SkillTreeUIController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkillTreeUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	pcall(function()
		screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	screenGui.DisplayOrder = 10
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Dim Backdrop
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(2, 0, 2, 0)
	backdrop.Position = UDim2.new(-0.5, 0, -0.5, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
	backdrop.BackgroundTransparency = 0.42
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Parent = screenGui

	backdrop.Activated:Connect(function()
		SkillTreeUIController.Close()
	end)

	-- Main Modal Frame (Responsive Desktop Reference: 1180 x 700)
	modalFrame = Instance.new("Frame")
	modalFrame.Name = "MainModal"
	modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	modalFrame.Size = UDim2.new(0, 1180, 0, 700)
	modalFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	modalFrame.BorderSizePixel = 0
	modalFrame.Parent = screenGui

	modalScale = Instance.new("UIScale")
	modalScale.Parent = modalFrame

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 12)
	modalCorner.Parent = modalFrame

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Color3.fromRGB(195, 155, 65)
	modalStroke.Thickness = 2.4
	modalStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	modalStroke.Parent = modalFrame

	-- Top Header Bar
	headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 60)
	headerBar.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
	headerBar.BorderSizePixel = 0
	headerBar.Parent = modalFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = headerBar

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.55, 0, 1, 0)
	titleLabel.Position = UDim2.new(0, 18, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "🛡️ TANK SKILL SPECIALIZATION"
	titleLabel.Parent = headerBar

	-- Skill Points Badge Pill
	pointsPill = Instance.new("Frame")
	pointsPill.Size = UDim2.new(0, 205, 0, 38)
	pointsPill.Position = UDim2.new(1, -265, 0.5, -19)
	pointsPill.BackgroundColor3 = Color3.fromRGB(32, 38, 50)
	pointsPill.BorderSizePixel = 0
	pointsPill.Parent = headerBar

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 19)
	pillCorner.Parent = pointsPill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = Color3.fromRGB(255, 215, 80)
	pillStroke.Thickness = 1.5
	pillStroke.Parent = pointsPill

	pillLabel = Instance.new("TextLabel")
	pillLabel.Size = UDim2.new(0.68, 0, 1, 0)
	pillLabel.Position = UDim2.new(0, 10, 0, 0)
	pillLabel.BackgroundTransparency = 1
	pillLabel.TextColor3 = Color3.fromRGB(220, 228, 238)
	pillLabel.Font = Enum.Font.GothamBold
	pillLabel.TextSize = 15
	pillLabel.Text = "SKILL POINTS:"
	pillLabel.Parent = pointsPill

	pointsValueLabel = Instance.new("TextLabel")
	pointsValueLabel.Size = UDim2.new(0.32, 0, 1, 0)
	pointsValueLabel.Position = UDim2.new(0.68, 0, 0, 0)
	pointsValueLabel.BackgroundTransparency = 1
	pointsValueLabel.TextColor3 = Color3.fromRGB(255, 220, 70)
	pointsValueLabel.Font = Enum.Font.GothamBold
	pointsValueLabel.TextSize = 22
	pointsValueLabel.Text = "0"
	pointsValueLabel.Parent = pointsPill

	-- Close Button [X]
	closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0.5, -20)
	closeBtn.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.Text = "X"
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = headerBar

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.Activated:Connect(function()
		SkillTreeUIController.Close()
	end)

	-- Mobile Branch Switcher Tabs Container
	branchTabsContainer = Instance.new("Frame")
	branchTabsContainer.Name = "BranchTabsContainer"
	branchTabsContainer.Size = UDim2.new(1, -24, 0, 38)
	branchTabsContainer.Position = UDim2.new(0, 12, 0, 64)
	branchTabsContainer.BackgroundTransparency = 1
	branchTabsContainer.Visible = false
	branchTabsContainer.Parent = modalFrame

	-- Center Branches Container
	branchesContainer = Instance.new("Frame")
	branchesContainer.Name = "BranchesContainer"
	branchesContainer.Size = UDim2.new(1, -24, 1, -172)
	branchesContainer.Position = UDim2.new(0, 12, 0, 68)
	branchesContainer.BackgroundTransparency = 1
	branchesContainer.Parent = modalFrame

	-- Bottom Equipped Slots Bar
	bottomFrame = Instance.new("Frame")
	bottomFrame.Name = "BottomEquippedBar"
	bottomFrame.Size = UDim2.new(1, -24, 0, 88)
	bottomFrame.Position = UDim2.new(0, 12, 1, -96)
	bottomFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
	bottomFrame.BorderSizePixel = 0
	bottomFrame.Parent = modalFrame

	local bottomCorner = Instance.new("UICorner")
	bottomCorner.CornerRadius = UDim.new(0, 8)
	bottomCorner.Parent = bottomFrame

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(50, 56, 70)
	bStroke.Thickness = 1.2
	bStroke.Parent = bottomFrame

	-- Bottom Action Bar Prompt / Subtitle
	bottomPromptLabel = Instance.new("TextLabel")
	bottomPromptLabel.Name = "BottomPrompt"
	bottomPromptLabel.Size = UDim2.new(1, -20, 0, 22)
	bottomPromptLabel.Position = UDim2.new(0, 12, 0, 5)
	bottomPromptLabel.BackgroundTransparency = 1
	bottomPromptLabel.TextColor3 = Color3.fromRGB(180, 190, 205)
	bottomPromptLabel.Font = Enum.Font.GothamMedium
	bottomPromptLabel.TextSize = 14.5
	bottomPromptLabel.TextXAlignment = Enum.TextXAlignment.Left
	bottomPromptLabel.Text = "ACTIVE ACTION SLOTS: Click an unlocked ability above to equip it into your hotbar."
	bottomPromptLabel.Parent = bottomFrame

	equippedSlotsContainer = Instance.new("Frame")
	equippedSlotsContainer.Name = "SlotsContainer"
	equippedSlotsContainer.Size = UDim2.new(1, -16, 0, 54)
	equippedSlotsContainer.Position = UDim2.new(0, 8, 0, 28)
	equippedSlotsContainer.BackgroundTransparency = 1
	equippedSlotsContainer.Parent = bottomFrame

	-- Responsive Viewport Listener
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updateResponsiveScale()
			if screenGui and screenGui.Enabled then
				refreshUI()
			end
		end)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCam = workspace.CurrentCamera
		if newCam then
			newCam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				updateResponsiveScale()
				if screenGui and screenGui.Enabled then
					refreshUI()
				end
			end)
			updateResponsiveScale()
		end
	end)
	updateResponsiveScale()

	-- Sync with Server
	Net.Get("SkillDataChanged").OnClientEvent:Connect(function(points, unlocked, equipped)
		skillPoints = points or 0
		unlockedSkills = unlocked or {"Taunt"}
		equippedSkills = equipped or {"Taunt"}
		refreshUI()
	end)
end

return SkillTreeUIController


