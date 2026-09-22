-- src/StarterPlayer/StarterPlayerScripts/Controllers/LevelUpUIController.lua
-- Shrine of Ascension: Souls-like manual leveling UI.
-- Upgraded with gilded dark-fantasy aesthetics, animated EXP gauge, level progression hero banner,
-- stat perks preview, tactile level-up action button, audio chimes, and responsive UIScale.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Net)

local LevelUpUIController = {}

local function expCostForLevel(level: number): number
	return level * 50
end

local function calculateAffordableLevels(startLevel: number, exp: number): number
	local count = 0
	local tempLevel = startLevel
	local tempEXP = exp
	while true do
		local cost = tempLevel * 50
		if tempEXP >= cost then
			tempEXP -= cost
			tempLevel += 1
			count += 1
		else
			break
		end
	end
	return count
end

local function playUISound(soundId: string, pitch: number?, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = pitch or 1.0
	sound.Volume = volume or 0.55
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

function LevelUpUIController.Start()
	local player = Players.LocalPlayer

	-- Hub-only check: distinguish hub from dungeon server
	if ReplicatedStorage:GetAttribute("IsDungeon") == true then
		return
	end
	local teleportData = TeleportService:GetLocalPlayerTeleportData()
	if teleportData and teleportData.isDungeon then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	local currentLevel = 1
	local currentEXP = 0

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LevelUpUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 15
	screenGui.Enabled = false
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	-- ── Dimmed Backdrop Overlay (Click to close) ───────────────────────────────
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "DimBackdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.Position = UDim2.new(0, 0, 0, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.55
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	-- ── Central Modal Frame ───────────────────────────────────────────────────
	local modalFrame = Instance.new("Frame")
	modalFrame.Name = "ModalFrame"
	modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	modalFrame.Size = UDim2.new(0, 500, 0, 375)
	modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	modalFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
	modalFrame.BorderSizePixel = 0
	modalFrame.ClipsDescendants = false
	modalFrame.Parent = screenGui

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 12)
	modalCorner.Parent = modalFrame

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Color3.fromRGB(220, 185, 75)
	modalStroke.Thickness = 1.8
	modalStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	modalStroke.Parent = modalFrame

	local modalGrad = Instance.new("UIGradient")
	modalGrad.Rotation = 45
	modalGrad.Color = ColorSequence.new(Color3.fromRGB(24, 30, 46), Color3.fromRGB(12, 15, 22))
	modalGrad.Parent = modalFrame

	-- Responsive UIScale (scales comfortably between mobile landscape, laptop, and desktop)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ModalScale"
	uiScale.Parent = modalFrame

	local function updateModalScale()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vSize = camera.ViewportSize
		if vSize.Y <= 0 then return end
		-- Base reference: ~400px height. Fits mobile landscape perfectly.
		local scale = math.clamp(math.min(vSize.X / 540, vSize.Y / 400), 0.72, 1.25)
		uiScale.Scale = scale
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateModalScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCam = workspace.CurrentCamera
		if newCam then
			newCam:GetPropertyChangedSignal("ViewportSize"):Connect(updateModalScale)
			updateModalScale()
		end
	end)
	updateModalScale()

	-- ── 1. Top Header Bar ─────────────────────────────────────────────────────
	local headerIcon = Instance.new("TextLabel")
	headerIcon.Size = UDim2.new(0, 36, 0, 36)
	headerIcon.Position = UDim2.new(0, 14, 0, 10)
	headerIcon.BackgroundTransparency = 1
	headerIcon.Font = Enum.Font.GothamBold
	headerIcon.TextSize = 24
	headerIcon.Text = "✨"
	headerIcon.Parent = modalFrame

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, -100, 0, 24)
	headerTitle.Position = UDim2.new(0, 54, 0, 8)
	headerTitle.BackgroundTransparency = 1
	headerTitle.TextColor3 = Color3.fromRGB(255, 225, 100)
	headerTitle.Font = Enum.Font.GothamBlack
	headerTitle.TextSize = 20
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Text = "SHRINE OF ASCENSION"
	headerTitle.Parent = modalFrame

	local headerSub = Instance.new("TextLabel")
	headerSub.Size = UDim2.new(1, -100, 0, 18)
	headerSub.Position = UDim2.new(0, 54, 0, 32)
	headerSub.BackgroundTransparency = 1
	headerSub.TextColor3 = Color3.fromRGB(175, 185, 205)
	headerSub.Font = Enum.Font.GothamMedium
	headerSub.TextSize = 14.5
	headerSub.TextXAlignment = Enum.TextXAlignment.Left
	headerSub.Text = "Channel banked experience into power and talent points"
	headerSub.Parent = modalFrame

	-- Close Button [✕]
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 34, 0, 34)
	closeButton.Position = UDim2.new(1, -46, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.Text = "✕"
	closeButton.BorderSizePixel = 0
	closeButton.Parent = modalFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 7)
	closeCorner.Parent = closeButton

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(220, 80, 80)
	closeStroke.Thickness = 1.2
	closeStroke.Parent = closeButton

	-- ── 2. Hero Level Progression Banner ──────────────────────────────────────
	local heroFrame = Instance.new("Frame")
	heroFrame.Name = "HeroProgression"
	heroFrame.Size = UDim2.new(1, -28, 0, 70)
	heroFrame.Position = UDim2.new(0, 14, 0, 56)
	heroFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	heroFrame.BorderSizePixel = 0
	heroFrame.Parent = modalFrame

	local heroCorner = Instance.new("UICorner")
	heroCorner.CornerRadius = UDim.new(0, 8)
	heroCorner.Parent = heroFrame

	local heroStroke = Instance.new("UIStroke")
	heroStroke.Color = Color3.fromRGB(65, 75, 95)
	heroStroke.Thickness = 1.2
	heroStroke.Parent = heroFrame

	-- Left: Current Rank
	local curRankSub = Instance.new("TextLabel")
	curRankSub.Size = UDim2.new(0.4, 0, 0, 18)
	curRankSub.Position = UDim2.new(0, 12, 0, 10)
	curRankSub.BackgroundTransparency = 1
	curRankSub.TextColor3 = Color3.fromRGB(150, 165, 185)
	curRankSub.Font = Enum.Font.GothamBold
	curRankSub.TextSize = 13.5
	curRankSub.TextXAlignment = Enum.TextXAlignment.Left
	curRankSub.Text = "CURRENT RANK"
	curRankSub.Parent = heroFrame

	local curRankVal = Instance.new("TextLabel")
	curRankVal.Name = "CurrentRankValue"
	curRankVal.Size = UDim2.new(0.4, 0, 0, 28)
	curRankVal.Position = UDim2.new(0, 12, 0, 28)
	curRankVal.BackgroundTransparency = 1
	curRankVal.TextColor3 = Color3.fromRGB(235, 240, 250)
	curRankVal.Font = Enum.Font.GothamBlack
	curRankVal.TextSize = 24
	curRankVal.TextXAlignment = Enum.TextXAlignment.Left
	curRankVal.Text = "LEVEL 1"
	curRankVal.Parent = heroFrame

	-- Center: Glowing Celestial Arrow
	local centerArrow = Instance.new("TextLabel")
	centerArrow.Size = UDim2.new(0.2, 0, 1, 0)
	centerArrow.Position = UDim2.new(0.4, 0, 0, 0)
	centerArrow.BackgroundTransparency = 1
	centerArrow.TextColor3 = Color3.fromRGB(255, 215, 65)
	centerArrow.Font = Enum.Font.GothamBlack
	centerArrow.TextSize = 26
	centerArrow.Text = "➔"
	centerArrow.Parent = heroFrame

	-- Right: Next Rank
	local nextRankSub = Instance.new("TextLabel")
	nextRankSub.Size = UDim2.new(0.4, 0, 0, 18)
	nextRankSub.Position = UDim2.new(0.6, -12, 0, 10)
	nextRankSub.BackgroundTransparency = 1
	nextRankSub.TextColor3 = Color3.fromRGB(255, 205, 75)
	nextRankSub.Font = Enum.Font.GothamBold
	nextRankSub.TextSize = 13.5
	nextRankSub.TextXAlignment = Enum.TextXAlignment.Right
	nextRankSub.Text = "ASCENDED RANK"
	nextRankSub.Parent = heroFrame

	local nextRankVal = Instance.new("TextLabel")
	nextRankVal.Name = "NextRankValue"
	nextRankVal.Size = UDim2.new(0.4, 0, 0, 28)
	nextRankVal.Position = UDim2.new(0.6, -12, 0, 28)
	nextRankVal.BackgroundTransparency = 1
	nextRankVal.TextColor3 = Color3.fromRGB(255, 225, 80)
	nextRankVal.Font = Enum.Font.GothamBlack
	nextRankVal.TextSize = 24
	nextRankVal.TextXAlignment = Enum.TextXAlignment.Right
	nextRankVal.Text = "LEVEL 2"
	nextRankVal.Parent = heroFrame

	-- ── 3. Ascension Rewards & Perks Preview ──────────────────────────────────
	local perksContainer = Instance.new("Frame")
	perksContainer.Name = "PerksContainer"
	perksContainer.Size = UDim2.new(1, -28, 0, 32)
	perksContainer.Position = UDim2.new(0, 14, 0, 134)
	perksContainer.BackgroundTransparency = 1
	perksContainer.Parent = modalFrame

	-- Perk 1: Talent Point
	local perk1 = Instance.new("Frame")
	perk1.Size = UDim2.new(0.5, -6, 1, 0)
	perk1.Position = UDim2.new(0, 0, 0, 0)
	perk1.BackgroundColor3 = Color3.fromRGB(26, 34, 52)
	perk1.BorderSizePixel = 0
	perk1.Parent = perksContainer

	local p1Corner = Instance.new("UICorner")
	p1Corner.CornerRadius = UDim.new(0, 6)
	p1Corner.Parent = perk1

	local p1Stroke = Instance.new("UIStroke")
	p1Stroke.Color = Color3.fromRGB(180, 145, 55)
	p1Stroke.Thickness = 1
	p1Stroke.Parent = perk1

	local p1Text = Instance.new("TextLabel")
	p1Text.Size = UDim2.new(1, 0, 1, 0)
	p1Text.BackgroundTransparency = 1
	p1Text.TextColor3 = Color3.fromRGB(255, 225, 90)
	p1Text.Font = Enum.Font.GothamBold
	p1Text.TextSize = 14.5
	p1Text.Text = "⭐ +1 Talent Skill Point"
	p1Text.Parent = perk1

	-- Perk 2: Stat Scaling
	local perk2 = Instance.new("Frame")
	perk2.Size = UDim2.new(0.5, -6, 1, 0)
	perk2.Position = UDim2.new(0.5, 6, 0, 0)
	perk2.BackgroundColor3 = Color3.fromRGB(20, 38, 30)
	perk2.BorderSizePixel = 0
	perk2.Parent = perksContainer

	local p2Corner = Instance.new("UICorner")
	p2Corner.CornerRadius = UDim.new(0, 6)
	p2Corner.Parent = perk2

	local p2Stroke = Instance.new("UIStroke")
	p2Stroke.Color = Color3.fromRGB(70, 160, 100)
	p2Stroke.Thickness = 1
	p2Stroke.Parent = perk2

	local p2Text = Instance.new("TextLabel")
	p2Text.Size = UDim2.new(1, 0, 1, 0)
	p2Text.BackgroundTransparency = 1
	p2Text.TextColor3 = Color3.fromRGB(120, 240, 155)
	p2Text.Font = Enum.Font.GothamBold
	p2Text.TextSize = 14.5
	p2Text.Text = "💚 +Max Health & Power"
	p2Text.Parent = perk2

	-- ── 4. Experience Progress Gauge & Breakdown ───────────────────────────────
	local expHeaderL = Instance.new("TextLabel")
	expHeaderL.Size = UDim2.new(0.5, 0, 0, 18)
	expHeaderL.Position = UDim2.new(0, 14, 0, 174)
	expHeaderL.BackgroundTransparency = 1
	expHeaderL.TextColor3 = Color3.fromRGB(180, 190, 205)
	expHeaderL.Font = Enum.Font.GothamBold
	expHeaderL.TextSize = 14
	expHeaderL.TextXAlignment = Enum.TextXAlignment.Left
	expHeaderL.Text = "ASCENSION PROGRESS"
	expHeaderL.Parent = modalFrame

	local expHeaderR = Instance.new("TextLabel")
	expHeaderR.Name = "ExpHeaderStatus"
	expHeaderR.Size = UDim2.new(0.5, 0, 0, 18)
	expHeaderR.Position = UDim2.new(0.5, -14, 0, 174)
	expHeaderR.BackgroundTransparency = 1
	expHeaderR.TextColor3 = Color3.fromRGB(255, 220, 80)
	expHeaderR.Font = Enum.Font.GothamBold
	expHeaderR.TextSize = 14.5
	expHeaderR.TextXAlignment = Enum.TextXAlignment.Right
	expHeaderR.Text = "430 / 50 EXP (Ready!)"
	expHeaderR.Parent = modalFrame

	-- EXP Track Bar
	local expTrack = Instance.new("Frame")
	expTrack.Name = "ExpTrack"
	expTrack.Size = UDim2.new(1, -28, 0, 18)
	expTrack.Position = UDim2.new(0, 14, 0, 196)
	expTrack.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	expTrack.BorderSizePixel = 0
	expTrack.ClipsDescendants = true
	expTrack.Parent = modalFrame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 7)
	trackCorner.Parent = expTrack

	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Color3.fromRGB(55, 62, 78)
	trackStroke.Thickness = 1
	trackStroke.Parent = expTrack

	-- EXP Fill Bar
	local expFill = Instance.new("Frame")
	expFill.Name = "ExpFill"
	expFill.Size = UDim2.new(1, 0, 1, 0)
	expFill.Position = UDim2.new(0, 0, 0, 0)
	expFill.BackgroundColor3 = Color3.fromRGB(255, 195, 45)
	expFill.BorderSizePixel = 0
	expFill.Parent = expTrack

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = expFill

	local fillGrad = Instance.new("UIGradient")
	fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 160, 30), Color3.fromRGB(255, 235, 85))
	fillGrad.Parent = expFill

	-- Sub-details row (Banked / Cost / Remaining)
	local detailsRow = Instance.new("TextLabel")
	detailsRow.Name = "DetailsRow"
	detailsRow.Size = UDim2.new(1, -28, 0, 18)
	detailsRow.Position = UDim2.new(0, 14, 0, 220)
	detailsRow.BackgroundTransparency = 1
	detailsRow.TextColor3 = Color3.fromRGB(190, 200, 215)
	detailsRow.Font = Enum.Font.GothamMedium
	detailsRow.TextSize = 14
	detailsRow.TextXAlignment = Enum.TextXAlignment.Center
	detailsRow.Text = "Banked: 430 EXP  •  Cost: 50 EXP  •  Remaining: 380 EXP"
	detailsRow.Parent = modalFrame

	-- Consecutive Level-Ups Banner
	local multiBadge = Instance.new("TextLabel")
	multiBadge.Name = "MultiLevelBadge"
	multiBadge.Size = UDim2.new(1, -28, 0, 18)
	multiBadge.Position = UDim2.new(0, 14, 0, 242)
	multiBadge.BackgroundTransparency = 1
	multiBadge.TextColor3 = Color3.fromRGB(255, 215, 90)
	multiBadge.Font = Enum.Font.GothamBold
	multiBadge.TextSize = 14
	multiBadge.TextXAlignment = Enum.TextXAlignment.Center
	multiBadge.Text = "🔥 Multiple levels available to claim!"
	multiBadge.Visible = false
	multiBadge.Parent = modalFrame

	-- ── 5. Tactile Ascension Action Button ────────────────────────────────────
	local confirmButton = Instance.new("TextButton")
	confirmButton.Name = "AscendButton"
	confirmButton.Size = UDim2.new(1, -28, 0, 56)
	confirmButton.Position = UDim2.new(0, 14, 0, 268)
	confirmButton.BackgroundColor3 = Color3.fromRGB(38, 155, 75)
	confirmButton.BorderSizePixel = 0
	confirmButton.AutoButtonColor = false
	confirmButton.Text = ""
	confirmButton.Parent = modalFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = confirmButton

	local btnGrad = Instance.new("UIGradient")
	btnGrad.Rotation = 45
	btnGrad.Color = ColorSequence.new(Color3.fromRGB(44, 175, 88), Color3.fromRGB(20, 105, 50))
	btnGrad.Parent = confirmButton

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(245, 215, 80)
	btnStroke.Thickness = 1.6
	btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btnStroke.Parent = confirmButton

	local btnTitle = Instance.new("TextLabel")
	btnTitle.Name = "ButtonTitle"
	btnTitle.Size = UDim2.new(1, 0, 0, 24)
	btnTitle.Position = UDim2.new(0, 0, 0, 7)
	btnTitle.BackgroundTransparency = 1
	btnTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnTitle.Font = Enum.Font.GothamBlack
	btnTitle.TextSize = 18
	btnTitle.Text = "✨ ASCEND TO LEVEL 2"
	btnTitle.Parent = confirmButton

	local btnSub = Instance.new("TextLabel")
	btnSub.Name = "ButtonSubtitle"
	btnSub.Size = UDim2.new(1, 0, 0, 18)
	btnSub.Position = UDim2.new(0, 0, 0, 31)
	btnSub.BackgroundTransparency = 1
	btnSub.TextColor3 = Color3.fromRGB(220, 255, 220)
	btnSub.Font = Enum.Font.GothamBold
	btnSub.TextSize = 13.5
	btnSub.Text = "SPEND 50 EXP  •  RECEIVE +1 TALENT POINT"
	btnSub.Parent = confirmButton

	-- ── Floating Level Up Toast Burst ─────────────────────────────────────────
	local function playAscendCelebration(newLevel: number)
		playUISound("rbxasset://sounds/electronicpingshort.wav", 1.25, 0.65)

		local burstLabel = Instance.new("TextLabel")
		burstLabel.Size = UDim2.new(0, 200, 0, 36)
		burstLabel.Position = UDim2.new(0.5, -100, 0, 4)
		burstLabel.BackgroundTransparency = 1
		burstLabel.TextColor3 = Color3.fromRGB(255, 235, 90)
		burstLabel.TextStrokeColor3 = Color3.fromRGB(15, 20, 30)
		burstLabel.TextStrokeTransparency = 0.2
		burstLabel.Font = Enum.Font.GothamBlack
		burstLabel.TextSize = 20
		burstLabel.Text = "✨ LEVEL UP! (" .. tostring(newLevel) .. ")"
		burstLabel.ZIndex = 20
		burstLabel.Parent = modalFrame

		local floatTween = TweenService:Create(
			burstLabel,
			TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, -100, 0, -32), TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		floatTween:Play()
		Debris:AddItem(burstLabel, 0.85)
	end

	-- ── Refresh Label & State Calculations ────────────────────────────────────
	local function refreshLabel()
		local cost = expCostForLevel(currentLevel)
		local nextLevel = currentLevel + 1
		local canAfford = (currentEXP >= cost)
		local affordableLevels = calculateAffordableLevels(currentLevel, currentEXP)

		curRankVal.Text = "LEVEL " .. tostring(currentLevel)
		nextRankVal.Text = "LEVEL " .. tostring(nextLevel)

		-- Progress Bar calculations
		local ratio = math.clamp(currentEXP / cost, 0, 1)
		TweenService:Create(expFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()

		if canAfford then
			expHeaderR.TextColor3 = Color3.fromRGB(255, 220, 80)
			expHeaderR.Text = ("%d / %d EXP (Ready!)"):format(currentEXP, cost)
			fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 160, 30), Color3.fromRGB(255, 235, 85))
		else
			expHeaderR.TextColor3 = Color3.fromRGB(230, 120, 110)
			expHeaderR.Text = ("%d / %d EXP"):format(currentEXP, cost)
			fillGrad.Color = ColorSequence.new(Color3.fromRGB(180, 80, 50), Color3.fromRGB(230, 110, 70))
		end

		-- Numerical details
		local remaining = math.max(0, currentEXP - cost)
		detailsRow.Text = ("Banked: %d EXP   •   Cost: %d EXP   •   Remaining: %d EXP"):format(currentEXP, cost, remaining)

		-- Multi-level available badge
		if affordableLevels > 1 then
			multiBadge.Visible = true
			multiBadge.Text = ("🔥 %d Levels Available to Claim in this visit!"):format(affordableLevels)
		else
			multiBadge.Visible = false
		end

		-- Button state styling
		if canAfford then
			confirmButton.BackgroundColor3 = Color3.fromRGB(38, 155, 75)
			btnGrad.Color = ColorSequence.new(Color3.fromRGB(44, 175, 88), Color3.fromRGB(20, 105, 50))
			btnStroke.Color = Color3.fromRGB(245, 215, 80)
			btnTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
			btnTitle.Text = "✨ ASCEND TO LEVEL " .. tostring(nextLevel)
			btnSub.TextColor3 = Color3.fromRGB(220, 255, 220)
			btnSub.Text = ("SPEND %d EXP  •  RECEIVE +1 TALENT POINT"):format(cost)
		else
			local needed = cost - currentEXP
			confirmButton.BackgroundColor3 = Color3.fromRGB(42, 46, 54)
			btnGrad.Color = ColorSequence.new(Color3.fromRGB(48, 52, 62), Color3.fromRGB(34, 38, 46))
			btnStroke.Color = Color3.fromRGB(70, 76, 90)
			btnTitle.TextColor3 = Color3.fromRGB(170, 175, 185)
			btnTitle.Text = "🔒 INSUFFICIENT EXPERIENCE"
			btnSub.TextColor3 = Color3.fromRGB(140, 146, 158)
			btnSub.Text = ("Defeat monsters in Dungeons to gain %d more EXP"):format(needed)
		end
	end

	-- ── Remote Event Synchronization ──────────────────────────────────────────
	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(level, unspentEXP)
		local prev = currentLevel
		currentLevel = level
		currentEXP = unspentEXP

		if screenGui.Enabled and level > prev then
			playAscendCelebration(level)
		end

		refreshLabel()
	end)

	-- ── Interaction Handlers ──────────────────────────────────────────────────
	confirmButton.Activated:Connect(function()
		local cost = expCostForLevel(currentLevel)
		if currentEXP >= cost then
			-- Tactile press bounce
			TweenService:Create(confirmButton, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -38, 0, 52)
			}):Play()
			task.delay(0.08, function()
				if confirmButton and confirmButton.Parent then
					TweenService:Create(confirmButton, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, -28, 0, 56)
					}):Play()
				end
			end)

			Net.Get("RequestLevelUp"):FireServer()
		else
			-- Subtle error shake
			playUISound("rbxasset://sounds/uuhhh.mp3", 1.4, 0.3)
			local origPos = confirmButton.Position
			local shakeRight = UDim2.new(origPos.X.Scale, origPos.X.Offset + 6, origPos.Y.Scale, origPos.Y.Offset)
			local shakeLeft = UDim2.new(origPos.X.Scale, origPos.X.Offset - 6, origPos.Y.Scale, origPos.Y.Offset)

			local t1 = TweenService:Create(confirmButton, TweenInfo.new(0.04), { Position = shakeRight })
			local t2 = TweenService:Create(confirmButton, TweenInfo.new(0.04), { Position = shakeLeft })
			local t3 = TweenService:Create(confirmButton, TweenInfo.new(0.04), { Position = origPos })
			t1:Play()
			t1.Completed:Connect(function()
				t2:Play()
				t2.Completed:Connect(function()
					t3:Play()
				end)
			end)
		end
	end)

	local function closeUI()
		screenGui.Enabled = false
	end

	closeButton.Activated:Connect(closeUI)
	backdrop.Activated:Connect(closeUI)

	-- ── Attach ProximityPrompt to the LevelUpShrine ───────────────────────────
	task.spawn(function()
		local shrine = workspace:WaitForChild("LevelUpShrine", 5)
		if not shrine then
			warn("LevelUpUIController: LevelUpShrine not found on hub server within 5s")
			return
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ascend / Level Up"
		prompt.ObjectText = "Shrine of Ascension"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 14
		prompt.Parent = shrine

		prompt.Triggered:Connect(function()
			refreshLabel()
			updateModalScale()
			screenGui.Enabled = true

			-- Smooth pop-in animation
			modalFrame.Position = UDim2.new(0.5, 0, 0.52, 0)
			TweenService:Create(
				modalFrame,
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0.5, 0, 0.5, 0) }
			):Play()
		end)
	end)
end

return LevelUpUIController
