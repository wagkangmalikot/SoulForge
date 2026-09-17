-- src/StarterPlayer/StarterPlayerScripts/Controllers/SkillTreeUIController.lua
-- Interactive MMO Skill Tree UI for Tank specializations (Juggernaut & Bulwark).
-- Allows players to spend Skill Points earned from level-ups to unlock powerful abilities
-- and equip them into action slots (1-4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)

local SkillTreeUIController = {}

local screenGui: ScreenGui? = nil
local modalFrame: Frame? = nil
local pointsValueLabel: TextLabel? = nil
local branchesContainer: Frame? = nil
local equippedSlotsContainer: Frame? = nil

local skillPoints = 0
local unlockedSkills: {string} = {"Taunt"}
local equippedSkills: {string} = {"Taunt"}

local isSelectingSlotForSkill: string? = nil

local BRANCH_COLORS = {
	Juggernaut = {
		primary = Color3.fromRGB(215, 65, 50),
		bg = Color3.fromRGB(38, 25, 25),
		border = Color3.fromRGB(180, 50, 40),
		name = "⚔️ JUGGERNAUT",
		tagline = "Offense, heavy threat generation & stagger",
	},
	Bulwark = {
		primary = Color3.fromRGB(45, 140, 240),
		bg = Color3.fromRGB(22, 30, 42),
		border = Color3.fromRGB(40, 110, 190),
		name = "🔰 BULWARK",
		tagline = "Damage mitigation, sustain & party barriers",
	},
}

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
		return false, "Requires " .. prereqName
	end
	if skillPoints < 1 then
		return false, "Needs 1 Skill Point"
	end
	return true, nil
end

local refreshUI: () -> ()

local function buildNodeCard(skillId: string, parent: Instance): Frame
	local skill = Skills[skillId]
	local unlocked = isSkillUnlocked(skillId)
	local equippedSlot = getEquippedSlot(skillId)
	local canUnlock, lockReason = canUnlockSkill(skillId)

	local card = Instance.new("Frame")
	card.Name = "Node_" .. skillId
	card.Size = UDim2.new(1, 0, 0, 88)
	card.BackgroundColor3 = unlocked and Color3.fromRGB(30, 36, 46) or Color3.fromRGB(24, 26, 32)
	card.BorderSizePixel = 0
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = unlocked and 1.8 or 1
	stroke.Color = unlocked and Color3.fromRGB(80, 200, 120) or (canUnlock and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(55, 60, 70))
	stroke.Parent = card

	-- Skill Icon Box
	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.new(0, 56, 0, 56)
	iconBox.Position = UDim2.new(0, 10, 0, 10)
	iconBox.BackgroundColor3 = unlocked and Color3.fromRGB(40, 50, 65) or Color3.fromRGB(18, 20, 25)
	iconBox.BorderSizePixel = 0
	iconBox.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = iconBox

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = skill.icon or "⚔️"
	iconLabel.TextScaled = true
	iconLabel.Parent = iconBox

	-- Name & Tier
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.55, 0, 0, 20)
	titleLabel.Position = UDim2.new(0, 74, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = unlocked and Color3.fromRGB(255, 255, 255) or (canUnlock and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(150, 155, 165))
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = ("%s (Tier %d)"):format(skill.displayName or skillId, skill.tier or 1)
	titleLabel.Parent = card

	-- Stats / Cooldown
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(0.55, 0, 0, 16)
	statsLabel.Position = UDim2.new(0, 74, 0, 28)
	statsLabel.BackgroundTransparency = 1
	statsLabel.TextColor3 = Color3.fromRGB(180, 190, 205)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 11
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left

	local statsText = ("CD: %ds"):format(skill.cooldown or 0)
	if skill.damage and skill.damage > 0 then
		statsText = statsText .. ("  •  Dmg: %d"):format(skill.damage)
	end
	if skill.healAmount and skill.healAmount > 0 then
		statsText = statsText .. ("  •  Heal: %d"):format(skill.healAmount)
	end
	statsLabel.Text = statsText
	statsLabel.Parent = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.55, 0, 0, 36)
	descLabel.Position = UDim2.new(0, 74, 0, 46)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(140, 145, 155)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 10
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Text = skill.description or ""
	descLabel.Parent = card

	-- Action Button (Right Side)
	local actionBtn = Instance.new("TextButton")
	actionBtn.Size = UDim2.new(0, 110, 0, 36)
	actionBtn.Position = UDim2.new(1, -120, 0.5, -18)
	actionBtn.BorderSizePixel = 0
	actionBtn.Font = Enum.Font.GothamBold
	actionBtn.TextSize = 12
	actionBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = actionBtn

	if unlocked then
		if equippedSlot then
			actionBtn.BackgroundColor3 = Color3.fromRGB(35, 100, 60)
			actionBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
			actionBtn.Text = ("EQUIPPED [%d]"):format(equippedSlot)
			actionBtn.AutoButtonColor = false
		else
			if isSelectingSlotForSkill == skillId then
				actionBtn.BackgroundColor3 = Color3.fromRGB(200, 140, 40)
				actionBtn.TextColor3 = Color3.new(1, 1, 1)
				actionBtn.Text = "Select Slot ▼"
			else
				actionBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 180)
				actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				actionBtn.Text = "EQUIP"
				actionBtn.Activated:Connect(function()
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
		actionBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 85)
		actionBtn.TextColor3 = Color3.new(1, 1, 1)
		actionBtn.Text = "UNLOCK (1 SP)"
		actionBtn.Activated:Connect(function()
			Net.Get("RequestUnlockSkill"):FireServer(skillId)
		end)
	else
		actionBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 55)
		actionBtn.TextColor3 = Color3.fromRGB(110, 115, 125)
		actionBtn.Text = lockReason or "LOCKED"
		actionBtn.AutoButtonColor = false
	end

	return card
end

refreshUI = function()
	if not modalFrame or not screenGui or not screenGui.Enabled then
		return
	end

	if pointsValueLabel then
		pointsValueLabel.Text = tostring(skillPoints)
	end

	if branchesContainer then
		branchesContainer:ClearAllChildren()

		local branchesLayout = Instance.new("UIListLayout")
		branchesLayout.FillDirection = Enum.FillDirection.Horizontal
		branchesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		branchesLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		branchesLayout.Padding = UDim.new(0, 18)
		branchesLayout.Parent = branchesContainer

		local tankData = Classes.Tank
		if tankData and tankData.branches then
			for branchName, branchInfo in pairs(tankData.branches) do
				local colStyle = BRANCH_COLORS[branchName] or BRANCH_COLORS.Juggernaut

				local column = Instance.new("Frame")
				column.Name = "Branch_" .. branchName
				column.Size = UDim2.new(0.485, 0, 1, 0)
				column.BackgroundColor3 = colStyle.bg
				column.BorderSizePixel = 0
				column.Parent = branchesContainer

				local colCorner = Instance.new("UICorner")
				colCorner.CornerRadius = UDim.new(0, 10)
				colCorner.Parent = column

				local colStroke = Instance.new("UIStroke")
				colStroke.Color = colStyle.border
				colStroke.Thickness = 1.5
				colStroke.Parent = column

				-- Branch Header
				local colHeader = Instance.new("Frame")
				colHeader.Size = UDim2.new(1, 0, 0, 48)
				colHeader.BackgroundColor3 = colStyle.border
				colHeader.BorderSizePixel = 0
				colHeader.Parent = column

				local headCorner = Instance.new("UICorner")
				headCorner.CornerRadius = UDim.new(0, 10)
				headCorner.Parent = colHeader

				local colTitle = Instance.new("TextLabel")
				colTitle.Size = UDim2.new(1, -12, 0, 24)
				colTitle.Position = UDim2.new(0, 12, 0, 3)
				colTitle.BackgroundTransparency = 1
				colTitle.TextColor3 = Color3.new(1, 1, 1)
				colTitle.Font = Enum.Font.GothamBold
				colTitle.TextSize = 15
				colTitle.TextXAlignment = Enum.TextXAlignment.Left
				colTitle.Text = colStyle.name
				colTitle.Parent = colHeader

				local colDesc = Instance.new("TextLabel")
				colDesc.Size = UDim2.new(1, -12, 0, 18)
				colDesc.Position = UDim2.new(0, 12, 0, 26)
				colDesc.BackgroundTransparency = 1
				colDesc.TextColor3 = Color3.fromRGB(220, 225, 235)
				colDesc.Font = Enum.Font.Gotham
				colDesc.TextSize = 11
				colDesc.TextXAlignment = Enum.TextXAlignment.Left
				colDesc.Text = colStyle.tagline
				colDesc.Parent = colHeader

				-- Scrollable / List Container for Nodes
				local nodesList = Instance.new("Frame")
				nodesList.Size = UDim2.new(1, -16, 1, -62)
				nodesList.Position = UDim2.new(0, 8, 0, 54)
				nodesList.BackgroundTransparency = 1
				nodesList.Parent = column

				local nLayout = Instance.new("UIListLayout")
				nLayout.FillDirection = Enum.FillDirection.Vertical
				nLayout.Padding = UDim.new(0, 10)
				nLayout.Parent = nodesList

				for _, skillId in ipairs(branchInfo.skills) do
					buildNodeCard(skillId, nodesList)
				end
			end
		end
	end

	-- Equipped Slots Preview Bar
	if equippedSlotsContainer then
		equippedSlotsContainer:ClearAllChildren()

		local barLayout = Instance.new("UIListLayout")
		barLayout.FillDirection = Enum.FillDirection.Horizontal
		barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		barLayout.Padding = UDim.new(0, 12)
		barLayout.Parent = equippedSlotsContainer

		for slotIndex = 1, 4 do
			local eqId = equippedSkills[slotIndex]
			local skillData = eqId and Skills[eqId]

			local slotBox = Instance.new("Frame")
			slotBox.Name = "Slot_" .. slotIndex
			slotBox.Size = UDim2.new(0, 150, 0, 42)
			slotBox.BackgroundColor3 = skillData and Color3.fromRGB(32, 38, 48) or Color3.fromRGB(22, 24, 30)
			slotBox.BorderSizePixel = 0
			slotBox.Parent = equippedSlotsContainer

			local sCorner = Instance.new("UICorner")
			sCorner.CornerRadius = UDim.new(0, 6)
			sCorner.Parent = slotBox

			local sStroke = Instance.new("UIStroke")
			sStroke.Color = isSelectingSlotForSkill and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(60, 65, 75)
			sStroke.Thickness = 1.2
			sStroke.Parent = slotBox

			local nameBadge = Instance.new("TextLabel")
			nameBadge.Size = UDim2.new(1, -24, 1, 0)
			nameBadge.Position = UDim2.new(0, 12, 0, 0)
			nameBadge.BackgroundTransparency = 1
			nameBadge.TextColor3 = skillData and Color3.new(1, 1, 1) or Color3.fromRGB(110, 115, 125)
			nameBadge.Font = Enum.Font.GothamMedium
			nameBadge.TextSize = 12
			nameBadge.TextXAlignment = Enum.TextXAlignment.Left
			nameBadge.Text = skillData and ((skillData.icon or "") .. " " .. (skillData.displayName or eqId)) or "(Empty Slot)"
			nameBadge.Parent = slotBox

			local slotBtn = Instance.new("TextButton")
			slotBtn.Size = UDim2.new(1, 0, 1, 0)
			slotBtn.BackgroundTransparency = 1
			slotBtn.Text = ""
			slotBtn.Parent = slotBox

			slotBtn.Activated:Connect(function()
				if isSelectingSlotForSkill then
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
	screenGui.Enabled = not screenGui.Enabled
	if screenGui.Enabled then
		isSelectingSlotForSkill = nil
		refreshUI()
	end
end

function SkillTreeUIController.Open()
	if not screenGui then
		return
	end
	screenGui.Enabled = true
	isSelectingSlotForSkill = nil
	refreshUI()
end

function SkillTreeUIController.Close()
	if not screenGui then
		return
	end
	screenGui.Enabled = false
	isSelectingSlotForSkill = nil
end

function SkillTreeUIController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkillTreeUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Dim Backdrop
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Parent = screenGui

	backdrop.Activated:Connect(function()
		SkillTreeUIController.Close()
	end)

	-- Main Modal Frame
	modalFrame = Instance.new("Frame")
	modalFrame.Name = "MainModal"
	modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	modalFrame.Size = UDim2.new(0.78, 0, 0.82, 0)
	modalFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	modalFrame.BorderSizePixel = 0
	modalFrame.Parent = screenGui

	local modalConstraint = Instance.new("UISizeConstraint")
	modalConstraint.MinSize = Vector2.new(620, 480)
	modalConstraint.MaxSize = Vector2.new(880, 680)
	modalConstraint.Parent = modalFrame

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 12)
	modalCorner.Parent = modalFrame

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Color3.fromRGB(185, 150, 70)
	modalStroke.Thickness = 2.5
	modalStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	modalStroke.Parent = modalFrame

	-- Top Header Bar
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 56)
	headerBar.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	headerBar.BorderSizePixel = 0
	headerBar.Parent = modalFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = headerBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
	titleLabel.Position = UDim2.new(0, 20, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "🛡️ TANK SKILL SPECIALIZATION"
	titleLabel.Parent = headerBar

	-- Skill Points Pill
	local pointsPill = Instance.new("Frame")
	pointsPill.Size = UDim2.new(0, 180, 0, 32)
	pointsPill.Position = UDim2.new(1, -240, 0.5, -16)
	pointsPill.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
	pointsPill.BorderSizePixel = 0
	pointsPill.Parent = headerBar

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 16)
	pillCorner.Parent = pointsPill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = Color3.fromRGB(255, 215, 80)
	pillStroke.Thickness = 1.5
	pillStroke.Parent = pointsPill

	local pillLabel = Instance.new("TextLabel")
	pillLabel.Size = UDim2.new(0.7, 0, 1, 0)
	pillLabel.Position = UDim2.new(0, 8, 0, 0)
	pillLabel.BackgroundTransparency = 1
	pillLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
	pillLabel.Font = Enum.Font.GothamMedium
	pillLabel.TextSize = 11
	pillLabel.Text = "SKILL POINTS:"
	pillLabel.Parent = pointsPill

	pointsValueLabel = Instance.new("TextLabel")
	pointsValueLabel.Size = UDim2.new(0.3, 0, 1, 0)
	pointsValueLabel.Position = UDim2.new(0.7, 0, 0, 0)
	pointsValueLabel.BackgroundTransparency = 1
	pointsValueLabel.TextColor3 = Color3.fromRGB(255, 220, 70)
	pointsValueLabel.Font = Enum.Font.GothamBold
	pointsValueLabel.TextSize = 16
	pointsValueLabel.Text = "0"
	pointsValueLabel.Parent = pointsPill

	-- Close Button [✕]
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -44, 0.5, -17)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.Text = "✕"
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = headerBar

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.Activated:Connect(function()
		SkillTreeUIController.Close()
	end)

	-- Center Branches Container
	branchesContainer = Instance.new("Frame")
	branchesContainer.Name = "BranchesContainer"
	branchesContainer.Size = UDim2.new(1, -24, 1, -136)
	branchesContainer.Position = UDim2.new(0, 12, 0, 66)
	branchesContainer.BackgroundTransparency = 1
	branchesContainer.Parent = modalFrame

	-- Bottom Equipped Slots Bar
	local bottomFrame = Instance.new("Frame")
	bottomFrame.Name = "BottomEquippedBar"
	bottomFrame.Size = UDim2.new(1, -24, 0, 56)
	bottomFrame.Position = UDim2.new(0, 12, 1, -64)
	bottomFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	bottomFrame.BorderSizePixel = 0
	bottomFrame.Parent = modalFrame

	local bottomCorner = Instance.new("UICorner")
	bottomCorner.CornerRadius = UDim.new(0, 8)
	bottomCorner.Parent = bottomFrame

	local bottomTitle = Instance.new("TextLabel")
	bottomTitle.Size = UDim2.new(0, 120, 1, 0)
	bottomTitle.Position = UDim2.new(0, 12, 0, 0)
	bottomTitle.BackgroundTransparency = 1
	bottomTitle.TextColor3 = Color3.fromRGB(180, 185, 195)
	bottomTitle.Font = Enum.Font.GothamBold
	bottomTitle.TextSize = 11
	bottomTitle.TextXAlignment = Enum.TextXAlignment.Left
	bottomTitle.Text = "ACTIVE SKILL SLOTS:"
	bottomTitle.Parent = bottomFrame

	equippedSlotsContainer = Instance.new("Frame")
	equippedSlotsContainer.Name = "SlotsContainer"
	equippedSlotsContainer.Size = UDim2.new(1, -140, 1, 0)
	equippedSlotsContainer.Position = UDim2.new(0, 135, 0, 0)
	equippedSlotsContainer.BackgroundTransparency = 1
	equippedSlotsContainer.Parent = bottomFrame

	-- Sync with Server
	Net.Get("SkillDataChanged").OnClientEvent:Connect(function(points, unlocked, equipped)
		skillPoints = points or 0
		unlockedSkills = unlocked or {"Taunt"}
		equippedSkills = equipped or {"Taunt"}
		refreshUI()
	end)
end

return SkillTreeUIController
