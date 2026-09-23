-- src/StarterPlayer/StarterPlayerScripts/Controllers/DownedUIController.lua
-- Renders cinematic Victory & Defeat screens with loot breakdown, departure countdown,
-- responsive multi-platform scaling, and polished Downed / Revive indicators.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)

local DownedUIController = {}

function DownedUIController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DownedUI"
	screenGui.DisplayOrder = 15
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- ── Responsive Scaling Container (Mobile, Laptop 1366x768, Desktop 1080p/4K) ─
	local masterContainer = Instance.new("Frame")
	masterContainer.Name = "MasterContainer"
	masterContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	masterContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	masterContainer.Size = UDim2.new(1, 0, 1, 0)
	masterContainer.BackgroundTransparency = 1
	masterContainer.BorderSizePixel = 0
	masterContainer.Parent = screenGui

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ModalScale"
	uiScale.Parent = masterContainer

	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vp = camera.ViewportSize
		if vp.X <= 0 or vp.Y <= 0 then return end

		local scaleY = vp.Y / 420
		local targetScale = 1.0 + math.pow(math.max(0, scaleY - 1.0), 0.8) * 0.55
		uiScale.Scale = math.clamp(targetScale, 1.0, 1.85)
	end

	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCam = workspace.CurrentCamera
		if newCam then
			newCam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)
	updateScale()

	-- ── 1. Downed Warning Card (Frosted Red Warning Pill) ─────────────────────
	local downedCard = Instance.new("Frame")
	downedCard.Name = "DownedCard"
	downedCard.AnchorPoint = Vector2.new(0.5, 0)
	downedCard.Size = UDim2.new(0, 420, 0, 56)
	downedCard.Position = UDim2.new(0.5, 0, 0.22, 0)
	downedCard.BackgroundColor3 = Color3.fromRGB(22, 12, 14)
	downedCard.BackgroundTransparency = 0.18
	downedCard.BorderSizePixel = 0
	downedCard.Visible = false
	downedCard.Parent = masterContainer

	local downedCorner = Instance.new("UICorner")
	downedCorner.CornerRadius = UDim.new(0, 8)
	downedCorner.Parent = downedCard

	local downedStroke = Instance.new("UIStroke")
	downedStroke.Color = Color3.fromRGB(235, 55, 50)
	downedStroke.Thickness = 1.8
	downedStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	downedStroke.Parent = downedCard

	local downedIcon = Instance.new("TextLabel")
	downedIcon.Size = UDim2.new(0, 40, 1, 0)
	downedIcon.Position = UDim2.new(0, 6, 0, 0)
	downedIcon.BackgroundTransparency = 1
	downedIcon.Text = "⚠️"
	downedIcon.TextScaled = true
	downedIcon.Parent = downedCard

	local downedTitle = Instance.new("TextLabel")
	downedTitle.Size = UDim2.new(1, -54, 0, 22)
	downedTitle.Position = UDim2.new(0, 48, 0, 6)
	downedTitle.BackgroundTransparency = 1
	downedTitle.Font = Enum.Font.GothamBold
	downedTitle.TextSize = 15.5
	downedTitle.TextColor3 = Color3.fromRGB(255, 80, 75)
	downedTitle.TextStrokeColor3 = Color3.fromRGB(15, 8, 8)
	downedTitle.TextStrokeTransparency = 0.2
	downedTitle.TextXAlignment = Enum.TextXAlignment.Left
	downedTitle.Text = "YOU HAVE FALLEN IN BATTLE"
	downedTitle.Parent = downedCard

	local downedSub = Instance.new("TextLabel")
	downedSub.Size = UDim2.new(1, -54, 0, 20)
	downedSub.Position = UDim2.new(0, 48, 0, 28)
	downedSub.BackgroundTransparency = 1
	downedSub.Font = Enum.Font.GothamMedium
	downedSub.TextSize = 13.5
	downedSub.TextColor3 = Color3.fromRGB(215, 185, 185)
	downedSub.TextStrokeColor3 = Color3.fromRGB(15, 8, 8)
	downedSub.TextStrokeTransparency = 0.3
	downedSub.TextXAlignment = Enum.TextXAlignment.Left
	downedSub.Text = "Awaiting ally revive or respawn timer..."
	downedSub.Parent = downedCard

	-- ── 2. Global Revive Progress Bar ─────────────────────────────────────────
	local reviveBarBackground = Instance.new("Frame")
	reviveBarBackground.Name = "ReviveBar"
	reviveBarBackground.AnchorPoint = Vector2.new(0.5, 0)
	reviveBarBackground.Size = UDim2.new(0, 360, 0, 32)
	reviveBarBackground.Position = UDim2.new(0.5, 0, 0.32, 0)
	reviveBarBackground.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	reviveBarBackground.BackgroundTransparency = 0.15
	reviveBarBackground.BorderSizePixel = 0
	reviveBarBackground.ClipsDescendants = true
	reviveBarBackground.Visible = false
	reviveBarBackground.Parent = masterContainer

	local revCorner = Instance.new("UICorner")
	revCorner.CornerRadius = UDim.new(0, 6)
	revCorner.Parent = reviveBarBackground

	local revStroke = Instance.new("UIStroke")
	revStroke.Color = Color3.fromRGB(60, 180, 255)
	revStroke.Thickness = 1.4
	revStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	revStroke.Parent = reviveBarBackground

	local reviveBarFill = Instance.new("Frame")
	reviveBarFill.Name = "Fill"
	reviveBarFill.Size = UDim2.new(0, 0, 1, 0)
	reviveBarFill.BackgroundColor3 = Color3.fromRGB(50, 190, 255)
	reviveBarFill.BorderSizePixel = 0
	reviveBarFill.ZIndex = 1
	reviveBarFill.Parent = reviveBarBackground

	local revFillGrad = Instance.new("UIGradient")
	revFillGrad.Color = ColorSequence.new(Color3.fromRGB(70, 215, 255), Color3.fromRGB(20, 140, 225))
	revFillGrad.Parent = reviveBarFill

	local reviveLabel = Instance.new("TextLabel")
	reviveLabel.Size = UDim2.new(1, -12, 1, 0)
	reviveLabel.Position = UDim2.new(0, 6, 0, 0)
	reviveLabel.BackgroundTransparency = 1
	reviveLabel.Font = Enum.Font.GothamBold
	reviveLabel.TextSize = 14.5
	reviveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	reviveLabel.TextStrokeColor3 = Color3.fromRGB(10, 14, 20)
	reviveLabel.TextStrokeTransparency = 0.2
	reviveLabel.Text = ""
	reviveLabel.ZIndex = 2
	reviveLabel.Parent = reviveBarBackground

	-- ── 3. Cinematic Full-Screen Result Presentation ──────────────────────────
	-- Full-screen dim vignette overlay
	local vignetteBackdrop = Instance.new("Frame")
	vignetteBackdrop.Name = "VignetteBackdrop"
	vignetteBackdrop.Size = UDim2.new(1, 0, 1, 0)
	vignetteBackdrop.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
	vignetteBackdrop.BackgroundTransparency = 1
	vignetteBackdrop.BorderSizePixel = 0
	vignetteBackdrop.Visible = false
	vignetteBackdrop.ZIndex = 10
	vignetteBackdrop.Parent = masterContainer

	-- Centered Trophy Result Card Modal
	local resultModal = Instance.new("Frame")
	resultModal.Name = "ResultModal"
	resultModal.AnchorPoint = Vector2.new(0.5, 0.5)
	resultModal.Size = UDim2.new(0, 500, 0, 295)
	resultModal.Position = UDim2.new(0.5, 0, 0.48, 0)
	resultModal.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	resultModal.BorderSizePixel = 0
	resultModal.Visible = false
	resultModal.ZIndex = 11
	resultModal.Parent = masterContainer

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 14)
	modalCorner.Parent = resultModal

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Name = "BorderStroke"
	modalStroke.Thickness = 2.4
	modalStroke.Color = Color3.fromRGB(240, 195, 75)
	modalStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	modalStroke.Parent = resultModal

	local modalGrad = Instance.new("UIGradient")
	modalGrad.Rotation = 45
	modalGrad.Color = ColorSequence.new(Color3.fromRGB(26, 32, 46), Color3.fromRGB(14, 16, 22))
	modalGrad.Parent = resultModal

	-- Floating Top Emblem Crest (Crown for Victory, Skull for Defeat)
	local resultCrest = Instance.new("Frame")
	resultCrest.Name = "ResultCrest"
	resultCrest.AnchorPoint = Vector2.new(0.5, 0.5)
	resultCrest.Size = UDim2.new(0, 56, 0, 56)
	resultCrest.Position = UDim2.new(0.5, 0, 0, 0)
	resultCrest.BackgroundColor3 = Color3.fromRGB(36, 30, 16)
	resultCrest.BorderSizePixel = 0
	resultCrest.ZIndex = 13
	resultCrest.Parent = resultModal

	local crestCorner = Instance.new("UICorner")
	crestCorner.CornerRadius = UDim.new(0.5, 0)
	crestCorner.Parent = resultCrest

	local crestStroke = Instance.new("UIStroke")
	crestStroke.Color = Color3.fromRGB(250, 200, 75)
	crestStroke.Thickness = 2.2
	crestStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	crestStroke.Parent = resultCrest

	local crestIcon = Instance.new("TextLabel")
	crestIcon.Size = UDim2.new(1, 0, 1, 0)
	crestIcon.BackgroundTransparency = 1
	crestIcon.Text = "👑"
	crestIcon.TextScaled = true
	crestIcon.ZIndex = 14
	crestIcon.Parent = resultCrest

	-- Header Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 32)
	titleLabel.Position = UDim2.new(0, 0, 0, 34)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 28
	titleLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(20, 12, 4)
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Text = "VICTORY ACHIEVED"
	titleLabel.ZIndex = 12
	titleLabel.Parent = resultModal

	-- Subtitle
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Size = UDim2.new(1, -32, 0, 22)
	subtitleLabel.Position = UDim2.new(0, 16, 0, 68)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.TextSize = 16.5
	subtitleLabel.TextColor3 = Color3.fromRGB(215, 205, 175)
	subtitleLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	subtitleLabel.TextStrokeTransparency = 0.3
	subtitleLabel.Text = "Rockhide the Earthbreaker has been vanquished!"
	subtitleLabel.ZIndex = 12
	subtitleLabel.Parent = resultModal

	-- Horizontal Gilded Divider Line
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0.86, 0, 0, 1.5)
	divider.Position = UDim2.new(0.07, 0, 0, 92)
	divider.BackgroundColor3 = Color3.fromRGB(240, 195, 75)
	divider.BackgroundTransparency = 0.35
	divider.BorderSizePixel = 0
	divider.ZIndex = 12
	divider.Parent = resultModal

	local divDiamond = Instance.new("Frame")
	divDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
	divDiamond.Size = UDim2.new(0, 8, 0, 8)
	divDiamond.Position = UDim2.new(0.5, 0, 0.5, 0)
	divDiamond.Rotation = 45
	divDiamond.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
	divDiamond.BorderSizePixel = 0
	divDiamond.ZIndex = 13
	divDiamond.Parent = divider

	-- Rewards Inset Box
	local rewardsPanel = Instance.new("Frame")
	rewardsPanel.Name = "RewardsPanel"
	rewardsPanel.Size = UDim2.new(1, -36, 0, 98)
	rewardsPanel.Position = UDim2.new(0, 18, 0, 102)
	rewardsPanel.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
	rewardsPanel.BackgroundTransparency = 0.35
	rewardsPanel.BorderSizePixel = 0
	rewardsPanel.ZIndex = 12
	rewardsPanel.Parent = resultModal

	local rewCorner = Instance.new("UICorner")
	rewCorner.CornerRadius = UDim.new(0, 8)
	rewCorner.Parent = rewardsPanel

	local rewStroke = Instance.new("UIStroke")
	rewStroke.Color = Color3.fromRGB(48, 55, 68)
	rewStroke.Thickness = 1.2
	rewStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rewStroke.Parent = rewardsPanel

	local rewHeader = Instance.new("TextLabel")
	rewHeader.Name = "RewardsHeader"
	rewHeader.Size = UDim2.new(1, -16, 0, 20)
	rewHeader.Position = UDim2.new(0, 10, 0, 6)
	rewHeader.BackgroundTransparency = 1
	rewHeader.Font = Enum.Font.GothamBold
	rewHeader.TextSize = 15
	rewHeader.TextColor3 = Color3.fromRGB(245, 205, 100)
	rewHeader.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	rewHeader.TextStrokeTransparency = 0.3
	rewHeader.TextXAlignment = Enum.TextXAlignment.Left
	rewHeader.Text = "REWARDS & SPOILS"
	rewHeader.ZIndex = 13
	rewHeader.Parent = rewardsPanel

	-- 3 Reward Badges Container (EXP, Fragments, Gold)
	local badgesContainer = Instance.new("Frame")
	badgesContainer.Name = "BadgesContainer"
	badgesContainer.Size = UDim2.new(1, -20, 0, 36)
	badgesContainer.Position = UDim2.new(0, 10, 0, 28)
	badgesContainer.BackgroundTransparency = 1
	badgesContainer.ZIndex = 13
	badgesContainer.Parent = rewardsPanel

	local badgesLayout = Instance.new("UIListLayout")
	badgesLayout.FillDirection = Enum.FillDirection.Horizontal
	badgesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	badgesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	badgesLayout.Padding = UDim.new(0, 8)
	badgesLayout.Parent = badgesContainer

	local function createLootPill(parent: Instance, icon: string, text: string, bgCol: Color3, strokeCol: Color3, textCol: Color3): Frame
		local pill = Instance.new("Frame")
		pill.Size = UDim2.new(0.31, 0, 1, 0)
		pill.BackgroundColor3 = bgCol
		pill.BorderSizePixel = 0
		pill.ZIndex = 14
		pill.Parent = parent

		local pCorner = Instance.new("UICorner")
		pCorner.CornerRadius = UDim.new(0, 6)
		pCorner.Parent = pill

		local pStroke = Instance.new("UIStroke")
		pStroke.Color = strokeCol
		pStroke.Thickness = 1
		pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		pStroke.Parent = pill

		local pLabel = Instance.new("TextLabel")
		pLabel.Size = UDim2.new(1, -6, 1, 0)
		pLabel.Position = UDim2.new(0, 3, 0, 0)
		pLabel.BackgroundTransparency = 1
		pLabel.Font = Enum.Font.GothamBold
		pLabel.TextSize = 15.5
		pLabel.TextColor3 = textCol
		pLabel.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
		pLabel.TextStrokeTransparency = 0.3
		pLabel.TextScaled = false
		pLabel.Text = icon .. " " .. text
		pLabel.ZIndex = 15
		pLabel.Parent = pill

		return pill
	end

	local rewSubline = Instance.new("TextLabel")
	rewSubline.Name = "RewardsSubline"
	rewSubline.Size = UDim2.new(1, -16, 0, 18)
	rewSubline.Position = UDim2.new(0, 10, 0, 70)
	rewSubline.BackgroundTransparency = 1
	rewSubline.Font = Enum.Font.GothamMedium
	rewSubline.TextSize = 14.5
	rewSubline.TextColor3 = Color3.fromRGB(160, 225, 175)
	rewSubline.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	rewSubline.TextStrokeTransparency = 0.3
	rewSubline.Text = "DUNGEON STATUS: 100% COMPLETE ✓"
	rewSubline.ZIndex = 13
	rewSubline.Parent = rewardsPanel

	-- Countdown & Progress Bar to Hub Return
	local countdownContainer = Instance.new("Frame")
	countdownContainer.Name = "CountdownContainer"
	countdownContainer.Size = UDim2.new(1, -36, 0, 52)
	countdownContainer.Position = UDim2.new(0, 18, 0, 214)
	countdownContainer.BackgroundTransparency = 1
	countdownContainer.ZIndex = 12
	countdownContainer.Parent = resultModal

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.new(1, 0, 0, 20)
	countdownLabel.Position = UDim2.new(0, 0, 0, 2)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.TextSize = 14.5
	countdownLabel.TextColor3 = Color3.fromRGB(215, 220, 235)
	countdownLabel.TextStrokeColor3 = Color3.fromRGB(12, 14, 18)
	countdownLabel.TextStrokeTransparency = 0.3
	countdownLabel.Text = "Returning to Sanctuary in 5s..."
	countdownLabel.ZIndex = 13
	countdownLabel.Parent = countdownContainer

	local progressBarBg = Instance.new("Frame")
	progressBarBg.Name = "ProgressBarBg"
	progressBarBg.Size = UDim2.new(1, 0, 0, 8)
	progressBarBg.Position = UDim2.new(0, 0, 0, 28)
	progressBarBg.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
	progressBarBg.BorderSizePixel = 0
	progressBarBg.ClipsDescendants = true
	progressBarBg.ZIndex = 13
	progressBarBg.Parent = countdownContainer

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 3)
	barCorner.Parent = progressBarBg

	local progressBarFill = Instance.new("Frame")
	progressBarFill.Name = "Fill"
	progressBarFill.Size = UDim2.new(1, 0, 1, 0)
	progressBarFill.BackgroundColor3 = Color3.fromRGB(245, 195, 60)
	progressBarFill.BorderSizePixel = 0
	progressBarFill.ZIndex = 14
	progressBarFill.Parent = progressBarBg

	local barGrad = Instance.new("UIGradient")
	barGrad.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(215, 150, 30))
	barGrad.Parent = progressBarFill

	-- ── Event wiring ───────────────────────────────────────────────────────────

	Net.Get("PlayerDowned").OnClientEvent:Connect(function(userId)
		if userId == player.UserId then
			downedCard.Visible = true
			-- Pulsing tactile warning on player death
			TweenService:Create(downedStroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Color = Color3.fromRGB(255, 120, 110)
			}):Play()
		end
	end)

	Net.Get("PlayerRevived").OnClientEvent:Connect(function(userId)
		if userId == player.UserId then
			downedCard.Visible = false
		end
		reviveBarBackground.Visible = false
	end)

	player.CharacterAdded:Connect(function()
		downedCard.Visible = false
		reviveBarBackground.Visible = false
	end)

	Net.Get("ReviveProgress").OnClientEvent:Connect(function(reviverUserId, downedUserId, progress)
		if progress <= 0 then
			reviveBarBackground.Visible = false
			return
		end

		local reviverName: string
		local downedName: string
		do
			local ok1, n1 = pcall(Players.GetNameFromUserIdAsync, Players, reviverUserId)
			reviverName = ok1 and n1 or tostring(reviverUserId)
			local ok2, n2 = pcall(Players.GetNameFromUserIdAsync, Players, downedUserId)
			downedName = ok2 and n2 or tostring(downedUserId)
		end

		reviveBarFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
		local pct = math.floor(math.clamp(progress, 0, 1) * 100)
		reviveLabel.Text = ("✨ %s reviving %s (%d%%)"):format(reviverName, downedName, pct)
		reviveBarBackground.Visible = true
	end)

	Net.Get("DungeonResult").OnClientEvent:Connect(function(result, expEarned, fragmentsEarned, goldEarned)
		downedCard.Visible = false
		reviveBarBackground.Visible = false

		local exp = expEarned or 0
		local frags = fragmentsEarned or 0
		local gold = goldEarned or 0
		local isVictory = (result == "victory")

		-- Clear existing badges
		for _, child in ipairs(badgesContainer:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		if isVictory then
			-- VICTORY THEME (Gilded Gold, Emerald and Royal Navy)
			modalStroke.Color = Color3.fromRGB(240, 195, 75)
			modalGrad.Color = ColorSequence.new(Color3.fromRGB(26, 32, 46), Color3.fromRGB(14, 16, 22))
			divider.BackgroundColor3 = Color3.fromRGB(240, 195, 75)
			divDiamond.BackgroundColor3 = Color3.fromRGB(255, 220, 90)

			resultCrest.BackgroundColor3 = Color3.fromRGB(36, 30, 16)
			crestStroke.Color = Color3.fromRGB(250, 200, 75)
			crestIcon.Text = "👑"

			titleLabel.Text = "VICTORY ACHIEVED"
			titleLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
			subtitleLabel.Text = "Rockhide the Earthbreaker has been vanquished!"
			subtitleLabel.TextColor3 = Color3.fromRGB(215, 205, 175)

			rewHeader.Text = "REWARDS & SPOILS"
			rewHeader.TextColor3 = Color3.fromRGB(245, 205, 100)
			rewSubline.Text = "DUNGEON STATUS: 100% COMPLETE ✓"
			rewSubline.TextColor3 = Color3.fromRGB(160, 225, 175)

			barGrad.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(215, 150, 30))

			createLootPill(badgesContainer, "✨", ("+%d EXP"):format(exp), Color3.fromRGB(42, 34, 14), Color3.fromRGB(220, 175, 50), Color3.fromRGB(255, 225, 90))
			createLootPill(badgesContainer, "💎", ("+%d Frag"):format(frags), Color3.fromRGB(14, 32, 42), Color3.fromRGB(50, 170, 220), Color3.fromRGB(100, 220, 255))
			createLootPill(badgesContainer, "🪙", ("+%d Gold"):format(gold), Color3.fromRGB(38, 28, 12), Color3.fromRGB(210, 140, 40), Color3.fromRGB(255, 200, 70))
		else
			-- DEFEAT THEME (Ominous Crimson and Blood-Ash Charcoal)
			modalStroke.Color = Color3.fromRGB(220, 50, 45)
			modalGrad.Color = ColorSequence.new(Color3.fromRGB(36, 16, 18), Color3.fromRGB(14, 12, 14))
			divider.BackgroundColor3 = Color3.fromRGB(220, 50, 45)
			divDiamond.BackgroundColor3 = Color3.fromRGB(255, 70, 70)

			resultCrest.BackgroundColor3 = Color3.fromRGB(36, 16, 18)
			crestStroke.Color = Color3.fromRGB(220, 50, 45)
			crestIcon.Text = "💀"

			titleLabel.Text = "PARTY DEFEATED"
			titleLabel.TextColor3 = Color3.fromRGB(255, 65, 60)
			subtitleLabel.Text = "Your party succumbed to the dungeon's horrors."
			subtitleLabel.TextColor3 = Color3.fromRGB(205, 165, 165)

			rewHeader.Text = "ENCOUNTER LOG"
			rewHeader.TextColor3 = Color3.fromRGB(255, 120, 110)
			rewSubline.Text = "TIP: Evade yellow shockwave circles & coordinate aggro"
			rewSubline.TextColor3 = Color3.fromRGB(190, 195, 205)

			barGrad.Color = ColorSequence.new(Color3.fromRGB(240, 60, 50), Color3.fromRGB(160, 20, 25))

			createLootPill(badgesContainer, "⚔️", "WIPED", Color3.fromRGB(42, 14, 16), Color3.fromRGB(200, 45, 40), Color3.fromRGB(255, 90, 80))
			createLootPill(badgesContainer, "💎", "+0 Frag", Color3.fromRGB(22, 24, 28), Color3.fromRGB(60, 65, 75), Color3.fromRGB(150, 155, 165))
			createLootPill(badgesContainer, "🪙", "+0 Gold", Color3.fromRGB(22, 24, 28), Color3.fromRGB(60, 65, 75), Color3.fromRGB(150, 155, 165))
		end

		-- Play glorious entry sound
		local fanfare = Instance.new("Sound")
		fanfare.Name = "ResultFanfare"
		fanfare.SoundId = isVictory and "rbxasset://sounds/electronicpingshort.wav" or "rbxasset://sounds/uuhhh.mp3"
		fanfare.Volume = 0.7
		fanfare.Parent = screenGui
		fanfare:Play()

		-- Show elements with smooth animation
		vignetteBackdrop.BackgroundTransparency = 1
		vignetteBackdrop.Visible = true
		TweenService:Create(vignetteBackdrop, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.42
		}):Play()

		resultModal.Position = UDim2.new(0.5, 0, 0.49, 0)
		resultModal.Visible = true
		TweenService:Create(resultModal, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.45, 0)
		}):Play()

		-- 5.0 Second Departure Countdown
		local totalSeconds = 5
		progressBarFill.Size = UDim2.new(1, 0, 1, 0)
		TweenService:Create(progressBarFill, TweenInfo.new(totalSeconds, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0)
		}):Play()

		task.spawn(function()
			for remaining = totalSeconds, 1, -1 do
				countdownLabel.Text = ("Returning to Sanctuary in %ds..."):format(remaining)
				task.wait(1.0)
			end
			countdownLabel.Text = "Teleporting..."
		end)
	end)
end

return DownedUIController
