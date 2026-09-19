-- src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
-- Dark-Fantasy MMO Pre-Spawn Interface (Title Screen, Hero Selection, Creation & Reforge)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local CharacterCreationController = {}

-- UI Color Palette: Dark Fantasy MMO (Obsidian, Gold, Emerald, Crimson)
local COLORS = {
	bgDark = Color3.fromRGB(10, 12, 16),
	bgCard = Color3.fromRGB(18, 22, 30),
	bgCardInner = Color3.fromRGB(13, 16, 22),
	goldPrimary = Color3.fromRGB(235, 175, 55),
	goldLight = Color3.fromRGB(255, 215, 115),
	goldDark = Color3.fromRGB(160, 110, 25),
	emeraldPrimary = Color3.fromRGB(46, 184, 114),
	emeraldLight = Color3.fromRGB(72, 215, 140),
	emeraldDark = Color3.fromRGB(26, 110, 65),
	crimsonPrimary = Color3.fromRGB(215, 60, 60),
	crimsonLight = Color3.fromRGB(245, 90, 90),
	crimsonDark = Color3.fromRGB(120, 30, 30),
	slateBorder = Color3.fromRGB(42, 50, 66),
	slateLight = Color3.fromRGB(160, 175, 195),
	textWhite = Color3.fromRGB(250, 250, 255),
	textMuted = Color3.fromRGB(130, 142, 162),
}

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

local function applyCorner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function applyStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

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

local function loadAvatarThumbnail(imageLabel: ImageLabel, fallbackLabel: TextLabel?, userId: number)
	task.spawn(function()
		local success, result = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.AvatarBust,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if success and result and result ~= "" then
			imageLabel.Image = result
			imageLabel.Visible = true
			if fallbackLabel then
				fallbackLabel.Visible = false
			end
		else
			imageLabel.Visible = false
			if fallbackLabel then
				fallbackLabel.Visible = true
			end
		end
	end)
end

local function createPillBadge(parent: Instance, text: string, bgColor: Color3, strokeColor: Color3, textColor: Color3): Frame
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = bgColor
	pill.BorderSizePixel = 0
	pill.Size = UDim2.new(0, 0, 1, 0)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Parent = parent

	applyCorner(pill, 12)
	applyStroke(pill, strokeColor, 1.2)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = pill

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 0, 1, 0)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = textColor
	label.TextSize = 13.5
	label.Parent = pill

	return pill
end

local function createStyledButton(params: {
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2?,
	primaryColor: Color3,
	gradientTop: Color3,
	gradientBottom: Color3,
	strokeColor: Color3,
	textColor: Color3,
	textSize: number?,
	font: Enum.Font?,
	onClick: () -> (),
}): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = params.size
	if params.position then
		btn.Position = params.position
	end
	btn.BackgroundColor3 = params.primaryColor
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = params.font or Enum.Font.GothamBlack
	btn.Text = params.text
	btn.TextColor3 = params.textColor
	btn.TextSize = params.textSize or 15
	btn.Parent = params.parent

	applyCorner(btn, 10)
	local stroke = applyStroke(btn, params.strokeColor, 1.5)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(params.gradientTop, params.gradientBottom)
	grad.Rotation = 90
	grad.Parent = btn

	-- Hover & Press micro-animations
	local isPressed = false
	local originalSize = params.size

	btn.MouseEnter:Connect(function()
		if not btn.Active then return end
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = params.gradientTop,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		if not btn.Active then return end
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = params.primaryColor,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = params.strokeColor,
			Thickness = 1.5,
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		if not btn.Active then return end
		isPressed = true
		TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 4, originalSize.Y.Scale, originalSize.Y.Offset - 2),
		}):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		if not isPressed then return end
		isPressed = false
		TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = originalSize,
		}):Play()
	end)

	btn.Activated:Connect(function()
		if not btn.Active then return end
		params.onClick()
	end)

	return btn
end

function CharacterCreationController.Start()
	local player = Players.LocalPlayer

	-- Hub-only check
	if ReplicatedStorage:GetAttribute("IsDungeon") == true then
		return
	end
	local teleportData = TeleportService:GetLocalPlayerTeleportData()
	if teleportData and teleportData.isDungeon then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterCreation"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100
	screenGui.Enabled = (player.Character == nil)
	screenGui.Parent = playerGui

	-- Atmospheric Background with Radial Vignette
	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = COLORS.bgDark
	background.BorderSizePixel = 0
	background.Parent = screenGui

	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 22, 32)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(10, 12, 17)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 6, 8)),
	})
	bgGrad.Rotation = 45
	bgGrad.Parent = background

	-- Subtle Ambient Warm Glow Circle in Center
	local glowDeco = Instance.new("ImageLabel")
	glowDeco.Size = UDim2.new(0, 700, 0, 700)
	glowDeco.Position = UDim2.new(0.5, 0, 0.5, 0)
	glowDeco.AnchorPoint = Vector2.new(0.5, 0.5)
	glowDeco.BackgroundTransparency = 1
	glowDeco.Image = "rbxassetid://5028857084"
	glowDeco.ImageColor3 = Color3.fromRGB(180, 120, 40)
	glowDeco.ImageTransparency = 0.88
	glowDeco.Parent = background

	-- ══════════════════════════════════════════════════════════════════════
	-- SCREEN 1: INTRO TITLE CARD ("First Screen")
	-- ══════════════════════════════════════════════════════════════════════
	local introFrame = Instance.new("Frame")
	introFrame.Size = UDim2.new(1, 0, 1, 0)
	introFrame.BackgroundTransparency = 1
	introFrame.Parent = background

	local titleCenter = Instance.new("Frame")
	titleCenter.Size = UDim2.new(0, 640, 0, 320)
	titleCenter.Position = UDim2.new(0.5, 0, 0.46, 0)
	titleCenter.AnchorPoint = Vector2.new(0.5, 0.5)
	titleCenter.BackgroundTransparency = 1
	titleCenter.Parent = introFrame

	-- Top Emblem Badge
	local emblemLabel = Instance.new("TextLabel")
	emblemLabel.Size = UDim2.new(1, 0, 0, 32)
	emblemLabel.Position = UDim2.new(0, 0, 0, 0)
	emblemLabel.BackgroundTransparency = 1
	emblemLabel.Font = Enum.Font.GothamBold
	emblemLabel.Text = "❖   A C T I O N   R P G   D U N G E O N   C R A W L E R   ❖"
	emblemLabel.TextColor3 = COLORS.goldLight
	emblemLabel.TextSize = 14
	emblemLabel.TextTransparency = 0.3
	emblemLabel.Parent = titleCenter

	-- Main Game Logo: SOULFORGE
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 96)
	titleLabel.Position = UDim2.new(0, 0, 0, 38)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "SOULFORGE"
	titleLabel.TextSize = 72
	titleLabel.Parent = titleCenter

	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 180)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(245, 195, 75)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 130, 25)),
	})
	titleGrad.Rotation = 90
	titleGrad.Parent = titleLabel

	local titleStroke = applyStroke(titleLabel, Color3.fromRGB(80, 45, 10), 3)
	titleStroke.Transparency = 0.2

	-- Subtitle
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0, 24)
	subtitleLabel.Position = UDim2.new(0, 0, 0, 136)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = "CHRONICLES OF THE EARTHBREAKER"
	subtitleLabel.TextColor3 = COLORS.slateLight
	subtitleLabel.TextSize = 14
	subtitleLabel.TextTransparency = 0.2
	subtitleLabel.Parent = titleCenter

	-- Ornate Fantasy Divider
	local dividerFrame = Instance.new("Frame")
	dividerFrame.Size = UDim2.new(0, 360, 0, 2)
	dividerFrame.Position = UDim2.new(0.5, -180, 0, 172)
	dividerFrame.BackgroundColor3 = COLORS.goldPrimary
	dividerFrame.BorderSizePixel = 0
	dividerFrame.Parent = titleCenter

	local divGrad = Instance.new("UIGradient")
	divGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	divGrad.Parent = dividerFrame

	-- Pulsing Enter Prompt Pill
	local promptPill = Instance.new("Frame")
	promptPill.Size = UDim2.new(0, 360, 0, 44)
	promptPill.Position = UDim2.new(0.5, -180, 0, 215)
	promptPill.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	promptPill.BorderSizePixel = 0
	promptPill.Parent = titleCenter

	applyCorner(promptPill, 22)
	local promptStroke = applyStroke(promptPill, COLORS.goldPrimary, 1.5, 0.2)

	local promptLabel = Instance.new("TextLabel")
	promptLabel.Size = UDim2.new(1, 0, 1, 0)
	promptLabel.BackgroundTransparency = 1
	promptLabel.Font = Enum.Font.GothamBold
	promptLabel.Text = "TAP TO ENTER"
	promptLabel.TextColor3 = COLORS.goldLight
	promptLabel.TextSize = 13
	promptLabel.Parent = promptPill

	-- Breathing glow animation for prompt
	local pulseTween = TweenService:Create(
		promptStroke,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8, Thickness = 2.5 }
	)
	pulseTween:Play()

	local promptBgTween = TweenService:Create(
		promptPill,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundColor3 = Color3.fromRGB(35, 42, 60) }
	)
	promptBgTween:Play()

	-- Fullscreen hit-catcher to immediately catch any mouse click or touch tap anywhere
	local introHitbox = Instance.new("TextButton")
	introHitbox.Name = "IntroHitbox"
	introHitbox.Size = UDim2.new(1, 0, 1, 0)
	introHitbox.Position = UDim2.new(0, 0, 0, 0)
	introHitbox.BackgroundTransparency = 1
	introHitbox.Text = ""
	introHitbox.AutoButtonColor = false
	introHitbox.Active = true
	introHitbox.ZIndex = 50
	introHitbox.Parent = introFrame

	-- ══════════════════════════════════════════════════════════════════════
	-- SCREEN 2: HERO SELECTION ("This One" from User Screenshot)
	-- ══════════════════════════════════════════════════════════════════════
	local choiceFrame = Instance.new("Frame")
	choiceFrame.Size = UDim2.new(1, 0, 1, 0)
	choiceFrame.BackgroundTransparency = 1
	choiceFrame.Visible = false
	choiceFrame.Parent = background

	local choiceCard = Instance.new("Frame")
	choiceCard.Size = UDim2.new(0.9, 0, 0.86, 0)
	choiceCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	choiceCard.AnchorPoint = Vector2.new(0.5, 0.5)
	choiceCard.BackgroundColor3 = COLORS.bgCard
	choiceCard.BorderSizePixel = 0
	choiceCard.Parent = choiceFrame

	local choiceConstraint = Instance.new("UISizeConstraint")
	choiceConstraint.MaxSize = Vector2.new(500, 520)
	choiceConstraint.MinSize = Vector2.new(320, 440)
	choiceConstraint.Parent = choiceCard

	applyCorner(choiceCard, 16)
	applyStroke(choiceCard, COLORS.slateBorder, 1.8)

	local choiceCardGrad = Instance.new("UIGradient")
	choiceCardGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 28, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 18, 26)),
	})
	choiceCardGrad.Rotation = 90
	choiceCardGrad.Parent = choiceCard

	local choiceCardPadding = Instance.new("UIPadding")
	choiceCardPadding.PaddingTop = UDim.new(0, 24)
	choiceCardPadding.PaddingBottom = UDim.new(0, 20)
	choiceCardPadding.PaddingLeft = UDim.new(0, 24)
	choiceCardPadding.PaddingRight = UDim.new(0, 24)
	choiceCardPadding.Parent = choiceCard

	-- Top Category Label
	local choiceTopHeader = Instance.new("TextLabel")
	choiceTopHeader.Size = UDim2.new(1, 0, 0, 18)
	choiceTopHeader.BackgroundTransparency = 1
	choiceTopHeader.Font = Enum.Font.GothamBold
	choiceTopHeader.Text = "❖   H E R O   S E L E C T I O N   ❖"
	choiceTopHeader.TextColor3 = COLORS.goldPrimary
	choiceTopHeader.TextSize = 13
	choiceTopHeader.Parent = choiceCard

	-- Main Title Banner
	local welcomeTitle = Instance.new("TextLabel")
	welcomeTitle.Size = UDim2.new(1, 0, 0, 32)
	welcomeTitle.Position = UDim2.new(0, 0, 0, 20)
	welcomeTitle.BackgroundTransparency = 1
	welcomeTitle.Font = Enum.Font.GothamBlack
	welcomeTitle.Text = "Welcome Back, Champion"
	welcomeTitle.TextColor3 = COLORS.textWhite
	welcomeTitle.TextSize = 24
	welcomeTitle.Parent = choiceCard

	-- Hero Showcase Inner Panel
	local heroPanel = Instance.new("Frame")
	heroPanel.Size = UDim2.new(1, 0, 0, 200)
	heroPanel.Position = UDim2.new(0, 0, 0, 60)
	heroPanel.BackgroundColor3 = COLORS.bgCardInner
	heroPanel.BorderSizePixel = 0
	heroPanel.Parent = choiceCard

	applyCorner(heroPanel, 12)
	applyStroke(heroPanel, Color3.fromRGB(32, 38, 52), 1.2)

	-- Hero Avatar Crest Frame
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Size = UDim2.new(0, 84, 0, 84)
	avatarFrame.Position = UDim2.new(0, 16, 0, 16)
	avatarFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	avatarFrame.BorderSizePixel = 0
	avatarFrame.Parent = heroPanel

	applyCorner(avatarFrame, 42)
	applyStroke(avatarFrame, COLORS.goldPrimary, 2.5)

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Size = UDim2.new(1, 0, 1, 0)
	avatarImage.BackgroundTransparency = 1
	avatarImage.Parent = avatarFrame
	applyCorner(avatarImage, 42)

	local fallbackAvatar = Instance.new("TextLabel")
	fallbackAvatar.Size = UDim2.new(1, 0, 1, 0)
	fallbackAvatar.BackgroundTransparency = 1
	fallbackAvatar.Font = Enum.Font.GothamBold
	fallbackAvatar.Text = "🛡️"
	fallbackAvatar.TextSize = 36
	fallbackAvatar.Visible = false
	fallbackAvatar.Parent = avatarFrame

	loadAvatarThumbnail(avatarImage, fallbackAvatar, player.UserId)

	-- Hero Name & Username
	local heroNameLabel = Instance.new("TextLabel")
	heroNameLabel.Size = UDim2.new(1, -124, 0, 26)
	heroNameLabel.Position = UDim2.new(0, 114, 0, 18)
	heroNameLabel.BackgroundTransparency = 1
	heroNameLabel.Font = Enum.Font.GothamBlack
	heroNameLabel.Text = player.DisplayName
	heroNameLabel.TextColor3 = COLORS.textWhite
	heroNameLabel.TextSize = 20
	heroNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	heroNameLabel.Parent = heroPanel

	local heroHandleLabel = Instance.new("TextLabel")
	heroHandleLabel.Size = UDim2.new(1, -124, 0, 18)
	heroHandleLabel.Position = UDim2.new(0, 114, 0, 44)
	heroHandleLabel.BackgroundTransparency = 1
	heroHandleLabel.Font = Enum.Font.GothamMedium
	heroHandleLabel.Text = "@" .. player.Name
	heroHandleLabel.TextColor3 = COLORS.textMuted
	heroHandleLabel.TextSize = 13.5
	heroHandleLabel.TextXAlignment = Enum.TextXAlignment.Left
	heroHandleLabel.Parent = heroPanel

	-- Badges Container (Level & Class)
	local badgesContainer = Instance.new("Frame")
	badgesContainer.Size = UDim2.new(1, -124, 0, 24)
	badgesContainer.Position = UDim2.new(0, 114, 0, 68)
	badgesContainer.BackgroundTransparency = 1
	badgesContainer.Parent = heroPanel

	local badgeLayout = Instance.new("UIListLayout")
	badgeLayout.FillDirection = Enum.FillDirection.Horizontal
	badgeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	badgeLayout.Padding = UDim.new(0, 8)
	badgeLayout.Parent = badgesContainer

	local levelBadge = createPillBadge(
		badgesContainer,
		"⭐ LEVEL 1",
		Color3.fromRGB(48, 36, 12),
		COLORS.goldPrimary,
		COLORS.goldLight
	)

	createPillBadge(
		badgesContainer,
		"🛡️ TANK",
		Color3.fromRGB(18, 32, 54),
		Color3.fromRGB(56, 125, 230),
		Color3.fromRGB(120, 180, 255)
	)

	-- Inner Divider Line
	local heroDivider = Instance.new("Frame")
	heroDivider.Size = UDim2.new(1, -32, 0, 1)
	heroDivider.Position = UDim2.new(0, 16, 0, 114)
	heroDivider.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
	heroDivider.BorderSizePixel = 0
	heroDivider.Parent = heroPanel

	-- Class Attributes Preview Row
	local attrContainer = Instance.new("Frame")
	attrContainer.Size = UDim2.new(1, -32, 0, 64)
	attrContainer.Position = UDim2.new(0, 16, 0, 124)
	attrContainer.BackgroundTransparency = 1
	attrContainer.Parent = heroPanel

	local attrLayout = Instance.new("UIListLayout")
	attrLayout.FillDirection = Enum.FillDirection.Horizontal
	attrLayout.SortOrder = Enum.SortOrder.LayoutOrder
	attrLayout.Padding = UDim.new(0, 8)
	attrLayout.Parent = attrContainer

	local function createPerkChip(icon: string, title: string, subtitle: string)
		local chip = Instance.new("Frame")
		chip.Size = UDim2.new(0.31, 0, 1, 0)
		chip.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
		chip.BorderSizePixel = 0
		chip.Parent = attrContainer

		applyCorner(chip, 8)
		applyStroke(chip, Color3.fromRGB(34, 40, 56), 1)

		local cTitle = Instance.new("TextLabel")
		cTitle.Size = UDim2.new(1, 0, 0, 18)
		cTitle.Position = UDim2.new(0, 0, 0, 8)
		cTitle.BackgroundTransparency = 1
		cTitle.Font = Enum.Font.GothamBold
		cTitle.Text = icon .. " " .. title
		cTitle.TextColor3 = COLORS.textWhite
		cTitle.TextSize = 13
		cTitle.Parent = chip

		local cSub = Instance.new("TextLabel")
		cSub.Size = UDim2.new(1, 0, 0, 16)
		cSub.Position = UDim2.new(0, 0, 0, 26)
		cSub.BackgroundTransparency = 1
		cSub.Font = Enum.Font.Gotham
		cSub.Text = subtitle
		cSub.TextColor3 = COLORS.textMuted
		cSub.TextSize = 11.5
		cSub.Parent = chip
	end

	createPerkChip("❤️", "250 HP", "Base Health")
	createPerkChip("🛡️", "Taunt", "Threat Lock")
	createPerkChip("⚔️", "Blade & Shield", "Melee Defender")

	-- Action Buttons Area
	local actionArea = Instance.new("Frame")
	actionArea.Size = UDim2.new(1, 0, 0, 110)
	actionArea.Position = UDim2.new(0, 0, 0, 276)
	actionArea.BackgroundTransparency = 1
	actionArea.Parent = choiceCard

	local continueBtn: TextButton
	local createNewBtn: TextButton

	continueBtn = createStyledButton({
		parent = actionArea,
		text = "⚔️   ENTER REALM",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.new(0, 0, 0, 0),
		primaryColor = COLORS.emeraldPrimary,
		gradientTop = COLORS.emeraldLight,
		gradientBottom = COLORS.emeraldDark,
		strokeColor = Color3.fromRGB(90, 235, 150),
		textColor = COLORS.textWhite,
		textSize = 16,
		font = Enum.Font.GothamBlack,
		onClick = function()
			continueBtn.Active = false
			createNewBtn.Active = false
			continueBtn.Text = "ENTERING REALM..."
			Net.Get("RequestLoadCharacter"):FireServer()
		end,
	})

	createNewBtn = createStyledButton({
		parent = actionArea,
		text = "🔄   Reforge Hero (Start Anew)",
		size = UDim2.new(1, 0, 0, 42),
		position = UDim2.new(0, 0, 0, 62),
		primaryColor = Color3.fromRGB(28, 22, 26),
		gradientTop = Color3.fromRGB(38, 28, 34),
		gradientBottom = Color3.fromRGB(22, 16, 20),
		strokeColor = Color3.fromRGB(110, 45, 52),
		textColor = Color3.fromRGB(225, 140, 140),
		textSize = 13,
		font = Enum.Font.GothamBold,
		onClick = function()
			-- Will open confirmation modal
		end,
	})

	-- ══════════════════════════════════════════════════════════════════════
	-- SCREEN 3: FIRST-TIMER CHARACTER CREATION ("Create Screen")
	-- ══════════════════════════════════════════════════════════════════════
	local createFrame = Instance.new("Frame")
	createFrame.Size = UDim2.new(1, 0, 1, 0)
	createFrame.BackgroundTransparency = 1
	createFrame.Visible = false
	createFrame.Parent = background

	local createCard = Instance.new("Frame")
	createCard.Size = UDim2.new(0.9, 0, 0.86, 0)
	createCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	createCard.AnchorPoint = Vector2.new(0.5, 0.5)
	createCard.BackgroundColor3 = COLORS.bgCard
	createCard.BorderSizePixel = 0
	createCard.Parent = createFrame

	local createConstraint = Instance.new("UISizeConstraint")
	createConstraint.MaxSize = Vector2.new(500, 520)
	createConstraint.MinSize = Vector2.new(320, 440)
	createConstraint.Parent = createCard

	applyCorner(createCard, 16)
	applyStroke(createCard, COLORS.slateBorder, 1.8)

	local createCardGrad = Instance.new("UIGradient")
	createCardGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 28, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 18, 26)),
	})
	createCardGrad.Rotation = 90
	createCardGrad.Parent = createCard

	local createCardPadding = Instance.new("UIPadding")
	createCardPadding.PaddingTop = UDim.new(0, 24)
	createCardPadding.PaddingBottom = UDim.new(0, 20)
	createCardPadding.PaddingLeft = UDim.new(0, 24)
	createCardPadding.PaddingRight = UDim.new(0, 24)
	createCardPadding.Parent = createCard

	local createTopHeader = Instance.new("TextLabel")
	createTopHeader.Size = UDim2.new(1, 0, 0, 18)
	createTopHeader.BackgroundTransparency = 1
	createTopHeader.Font = Enum.Font.GothamBold
	createTopHeader.Text = "❖   C H O O S E   Y O U R   P A T H   ❖"
	createTopHeader.TextColor3 = COLORS.goldPrimary
	createTopHeader.TextSize = 13
	createTopHeader.Parent = createCard

	local createTitle = Instance.new("TextLabel")
	createTitle.Size = UDim2.new(1, 0, 0, 32)
	createTitle.Position = UDim2.new(0, 0, 0, 20)
	createTitle.BackgroundTransparency = 1
	createTitle.Font = Enum.Font.GothamBlack
	createTitle.Text = "Forge Your Destiny"
	createTitle.TextColor3 = COLORS.textWhite
	createTitle.TextSize = 24
	createTitle.Parent = createCard

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

	-- Playing As Indicator
	local playingAsText = Instance.new("TextLabel")
	playingAsText.Size = UDim2.new(1, 0, 0, 20)
	playingAsText.Position = UDim2.new(0, 0, 0, 280)
	playingAsText.BackgroundTransparency = 1
	playingAsText.Font = Enum.Font.GothamMedium
	playingAsText.Text = ("Champion: %s (@%s)"):format(player.DisplayName, player.Name)
	playingAsText.TextColor3 = COLORS.textMuted
	playingAsText.TextSize = 13.5
	playingAsText.Parent = createCard

	local beginBtn: TextButton
	beginBtn = createStyledButton({
		parent = createCard,
		text = "⚔️   EMBARK ON JOURNEY",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.new(0, 0, 0, 308),
		primaryColor = COLORS.emeraldPrimary,
		gradientTop = COLORS.emeraldLight,
		gradientBottom = COLORS.emeraldDark,
		strokeColor = Color3.fromRGB(90, 235, 150),
		textColor = COLORS.textWhite,
		textSize = 16,
		font = Enum.Font.GothamBlack,
		onClick = function()
			beginBtn.Active = false
			beginBtn.Text = "FORGING HERO..."
			Net.Get("SubmitCharacterCreation"):FireServer(selectedClassId)
		end,
	})

	-- ══════════════════════════════════════════════════════════════════════
	-- SCREEN 4: REFORGE OVERWRITE CONFIRMATION MODAL
	-- ══════════════════════════════════════════════════════════════════════
	local confirmFrame = Instance.new("Frame")
	confirmFrame.Size = UDim2.new(1, 0, 1, 0)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	confirmFrame.BackgroundTransparency = 0.4
	confirmFrame.Visible = false
	confirmFrame.Parent = background

	local confirmCard = Instance.new("Frame")
	confirmCard.Size = UDim2.new(0.9, 0, 0.55, 0)
	confirmCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	confirmCard.AnchorPoint = Vector2.new(0.5, 0.5)
	confirmCard.BackgroundColor3 = Color3.fromRGB(24, 18, 20)
	confirmCard.BorderSizePixel = 0
	confirmCard.Parent = confirmFrame

	local confirmConstraint = Instance.new("UISizeConstraint")
	confirmConstraint.MaxSize = Vector2.new(460, 360)
	confirmConstraint.MinSize = Vector2.new(300, 300)
	confirmConstraint.Parent = confirmCard

	applyCorner(confirmCard, 16)
	applyStroke(confirmCard, COLORS.crimsonPrimary, 2)

	local confirmPad = Instance.new("UIPadding")
	confirmPad.PaddingTop = UDim.new(0, 24)
	confirmPad.PaddingBottom = UDim.new(0, 20)
	confirmPad.PaddingLeft = UDim.new(0, 24)
	confirmPad.PaddingRight = UDim.new(0, 24)
	confirmPad.Parent = confirmCard

	local warnIcon = Instance.new("TextLabel")
	warnIcon.Size = UDim2.new(1, 0, 0, 40)
	warnIcon.BackgroundTransparency = 1
	warnIcon.Font = Enum.Font.GothamBlack
	warnIcon.Text = "⚠️"
	warnIcon.TextSize = 34
	warnIcon.Parent = confirmCard

	local warnTitle = Instance.new("TextLabel")
	warnTitle.Size = UDim2.new(1, 0, 0, 28)
	warnTitle.Position = UDim2.new(0, 0, 0, 46)
	warnTitle.BackgroundTransparency = 1
	warnTitle.Font = Enum.Font.GothamBlack
	warnTitle.Text = "REFORGE HERO?"
	warnTitle.TextColor3 = COLORS.crimsonLight
	warnTitle.TextSize = 20
	warnTitle.Parent = confirmCard

	local warnDesc = Instance.new("TextLabel")
	warnDesc.Size = UDim2.new(1, 0, 0, 70)
	warnDesc.Position = UDim2.new(0, 0, 0, 80)
	warnDesc.BackgroundTransparency = 1
	warnDesc.Font = Enum.Font.GothamMedium
	warnDesc.Text = "This will permanently delete your character and reset all skill points, unlocked abilities, and level progression."
	warnDesc.TextColor3 = Color3.fromRGB(220, 180, 180)
	warnDesc.TextSize = 13
	warnDesc.TextWrapped = true
	warnDesc.Parent = confirmCard

	local confirmBtns = Instance.new("Frame")
	confirmBtns.Size = UDim2.new(1, 0, 0, 96)
	confirmBtns.Position = UDim2.new(0, 0, 1, -96)
	confirmBtns.BackgroundTransparency = 1
	confirmBtns.Parent = confirmCard

	local cancelBtn: TextButton
	local deleteBtn: TextButton

	cancelBtn = createStyledButton({
		parent = confirmBtns,
		text = "🛡️   KEEP EXISTING HERO",
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.new(0, 0, 0, 0),
		primaryColor = Color3.fromRGB(36, 44, 58),
		gradientTop = Color3.fromRGB(48, 58, 76),
		gradientBottom = Color3.fromRGB(28, 34, 46),
		strokeColor = Color3.fromRGB(80, 100, 130),
		textColor = COLORS.textWhite,
		textSize = 14,
		font = Enum.Font.GothamBold,
		onClick = function()
			confirmFrame.Visible = false
			choiceFrame.Visible = true
		end,
	})

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

	-- Hook up createNewBtn to open confirmation
	createNewBtn.Activated:Connect(function()
		choiceFrame.Visible = false
		confirmFrame.Visible = true
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- SCREEN 5: LOADING STATE
	-- ══════════════════════════════════════════════════════════════════════
	local loadingCard = Instance.new("Frame")
	loadingCard.Size = UDim2.new(0, 340, 0, 80)
	loadingCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	loadingCard.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingCard.BackgroundColor3 = COLORS.bgCard
	loadingCard.BorderSizePixel = 0
	loadingCard.Visible = false
	loadingCard.Parent = background

	applyCorner(loadingCard, 14)
	applyStroke(loadingCard, COLORS.goldPrimary, 1.5)

	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Size = UDim2.new(1, 0, 1, 0)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Font = Enum.Font.GothamBold
	loadingLabel.Text = "❖   COMMUNING WITH THE FORGE...   ❖"
	loadingLabel.TextColor3 = COLORS.goldLight
	loadingLabel.TextSize = 13
	loadingLabel.Parent = loadingCard

	-- ══════════════════════════════════════════════════════════════════════
	-- STATE MACHINE & SCREEN NAVIGATION
	-- ══════════════════════════════════════════════════════════════════════
	local introDismissed = false
	local pendingScreen: "creation" | "choice" | nil = nil
	local pendingLevel = 1

	local function showPendingScreen()
		if not introDismissed or not pendingScreen then
			return
		end
		loadingCard.Visible = false
		if pendingScreen == "creation" then
			createFrame.Visible = true
		elseif pendingScreen == "choice" then
			-- Update Level badge text
			local levelText = ("⭐ LEVEL %d"):format(pendingLevel)
			local lvlChild = levelBadge:FindFirstChildOfClass("TextLabel")
			if lvlChild then
				lvlChild.Text = levelText
			end
			warnDesc.Text = ("This will permanently delete your Level %d Tank and reset all skill points, unlocked abilities, and level progression."):format(pendingLevel)
			choiceFrame.Visible = true
		end
	end

	local inputConnection: RBXScriptConnection? = nil
	local function dismissIntro()
		if introDismissed then
			return
		end
		introDismissed = true
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end

		pcall(function()
			pulseTween:Cancel()
		end)
		pcall(function()
			promptBgTween:Cancel()
		end)

		introFrame.Visible = false

		if pendingScreen then
			showPendingScreen()
		else
			loadingCard.Visible = true
		end
	end

	-- Fullscreen hit-catcher: reliable across PC clicks, mobile taps, and gamepad
	introHitbox.Activated:Connect(function()
		dismissIntro()
	end)

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

	Net.Get("ShowCharacterCreation").OnClientEvent:Connect(function()
		if player.Character and player.Character.Parent then
			screenGui.Enabled = false
			return
		end
		screenGui.Enabled = true
		pendingScreen = "creation"
		showPendingScreen()
	end)

	Net.Get("ShowCharacterChoice").OnClientEvent:Connect(function(level: number)
		if player.Character and player.Character.Parent then
			screenGui.Enabled = false
			return
		end
		screenGui.Enabled = true
		pendingScreen = "choice"
		pendingLevel = level
		showPendingScreen()
	end)

	-- Clean exit when character spawns in game
	player.CharacterAdded:Connect(function()
		screenGui.Enabled = false
	end)

	if player.Character and player.Character.Parent then
		screenGui.Enabled = false
	else
		-- Request initial character state in case event arrived before script initialized
		Net.Get("RequestCharacterState"):FireServer()
	end
end


return CharacterCreationController
