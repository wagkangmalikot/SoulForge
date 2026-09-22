-- src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
-- Dark-Fantasy MMO Pre-Spawn Interface (Title Screen, Hero Selection, Creation & Reforge)
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local CharacterCreationController = {}

local menuBlur: BlurEffect? = nil

local function setMenuBlur(enabled: boolean)
	if enabled then
		if not menuBlur or not menuBlur.Parent then
			local existing = Lighting:FindFirstChild("SoulforgeMenuBlur")
			if existing and existing:IsA("BlurEffect") then
				menuBlur = existing
			else
				menuBlur = Instance.new("BlurEffect")
				menuBlur.Name = "SoulforgeMenuBlur"
				menuBlur.Size = 0
				menuBlur.Parent = Lighting
			end
			TweenService:Create(menuBlur, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = 16,
			}):Play()
		end
	else
		local existing = Lighting:FindFirstChild("SoulforgeMenuBlur")
		local blurToFade = menuBlur or (existing and existing:IsA("BlurEffect") and existing)
		menuBlur = nil
		if blurToFade and blurToFade.Parent then
			local tw = TweenService:Create(blurToFade, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = 0,
			})
			tw:Play()
			tw.Completed:Connect(function()
				if blurToFade and blurToFade.Parent then
					blurToFade:Destroy()
				end
			end)
		end
	end
end

-- UI Color Palette: Luminous Dark Fantasy MMO (Sapphire Slate, Radiant Gold, Emerald, Ruby)
local COLORS = {
	bgDark = Color3.fromRGB(14, 18, 26),
	bgCard = Color3.fromRGB(28, 36, 52),
	bgCardInner = Color3.fromRGB(20, 26, 38),
	goldPrimary = Color3.fromRGB(250, 195, 65),
	goldLight = Color3.fromRGB(255, 230, 135),
	goldDark = Color3.fromRGB(180, 125, 30),
	emeraldPrimary = Color3.fromRGB(38, 192, 108),
	emeraldLight = Color3.fromRGB(68, 230, 140),
	emeraldDark = Color3.fromRGB(22, 145, 75),
	crimsonPrimary = Color3.fromRGB(230, 60, 75),
	crimsonLight = Color3.fromRGB(255, 110, 125),
	crimsonDark = Color3.fromRGB(160, 36, 48),
	slateBorder = Color3.fromRGB(60, 75, 105),
	slateLight = Color3.fromRGB(185, 200, 225),
	textWhite = Color3.fromRGB(255, 255, 255),
	textMuted = Color3.fromRGB(185, 198, 222),
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
	classTitle.TextSize = 13.5
	classTitle.TextXAlignment = Enum.TextXAlignment.Left
	classTitle.Parent = banner

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 56)
	desc.Position = UDim2.new(0, 10, 0, 44)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.GothamMedium
	desc.Text = info.description
	desc.TextColor3 = COLORS.slateLight
	desc.TextSize = 12.5
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = card

	local traitsFrame = Instance.new("Frame")
	traitsFrame.Size = UDim2.new(1, -20, 0, 100)
	traitsFrame.Position = UDim2.new(0, 10, 0, 106)
	traitsFrame.BackgroundTransparency = 1
	traitsFrame.Parent = card

	local traitsLayout = Instance.new("UIListLayout")
	traitsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	traitsLayout.Padding = UDim.new(0, 4)
	traitsLayout.Parent = traitsFrame

	for _, trait in info.traits do
		local tLabel = Instance.new("TextLabel")
		tLabel.Size = UDim2.new(1, 0, 0, 26)
		tLabel.BackgroundTransparency = 1
		tLabel.Font = Enum.Font.GothamBold
		tLabel.Text = trait[1] .. "  " .. trait[2]
		tLabel.TextColor3 = COLORS.textWhite
		tLabel.TextSize = 12
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
	label.TextSize = 14.5
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
	btn.Text = "" -- Kept empty so UIGradient doesn't tint or darken the button text
	btn.Parent = params.parent

	applyCorner(btn, 10)
	local stroke = applyStroke(btn, params.strokeColor, 1.8)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(params.gradientTop, params.gradientBottom)
	grad.Rotation = 90
	grad.Parent = btn

	-- Dedicated child TextLabel: completely immune to UIGradient color multiplication
	local btnLabel = Instance.new("TextLabel")
	btnLabel.Name = "ButtonText"
	btnLabel.Size = UDim2.new(1, 0, 1, 0)
	btnLabel.Position = UDim2.new(0, 0, 0, 0)
	btnLabel.BackgroundTransparency = 1
	btnLabel.Font = params.font or Enum.Font.GothamBlack
	btnLabel.Text = params.text
	btnLabel.TextColor3 = params.textColor or Color3.fromRGB(255, 255, 255)
	btnLabel.TextSize = params.textSize or 15
	btnLabel.TextStrokeColor3 = Color3.fromRGB(12, 16, 24)
	btnLabel.TextStrokeTransparency = 0.35
	btnLabel.ZIndex = btn.ZIndex + 2
	btnLabel.Parent = btn

	-- Allows external code doing `btn.Text = "..."` to update the displayed label cleanly
	btn:GetPropertyChangedSignal("Text"):Connect(function()
		if btn.Text ~= "" then
			btnLabel.Text = btn.Text
			btn.Text = ""
		end
	end)

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
			Thickness = 2.2,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		if not btn.Active then return end
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = params.primaryColor,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = params.strokeColor,
			Thickness = 1.8,
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

	-- Which remote the class-picker's EMBARK button should fire: "create" for a
	-- first-timer, "reforge" when reached via the "REFORGE HERO?" confirmation.
	local creationFlowMode: "create" | "reforge" = "create"

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

	-- Soft Translucent Vignette Backdrop (Allows 3D World & Hub scene to shine through with depth-of-field blur)
	local background = Instance.new("Frame")
	background.Name = "AtmosphericBackdrop"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(18, 26, 44)
	background.BackgroundTransparency = 0.72 -- Soft and luminous, 3D world shines through brightly
	background.BorderSizePixel = 0
	background.Parent = screenGui

	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 38, 62)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 24, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 18, 30)),
	})
	bgGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.5, 0.82),
		NumberSequenceKeypoint.new(1, 0.65),
	})
	bgGrad.Rotation = 45
	bgGrad.Parent = background

	-- Subtle Ambient Warm Glow Circle in Center
	local glowDeco = Instance.new("ImageLabel")
	glowDeco.Size = UDim2.new(0, 750, 0, 750)
	glowDeco.Position = UDim2.new(0.5, 0, 0.5, 0)
	glowDeco.AnchorPoint = Vector2.new(0.5, 0.5)
	glowDeco.BackgroundTransparency = 1
	glowDeco.Image = "rbxassetid://5028857084"
	glowDeco.ImageColor3 = Color3.fromRGB(235, 175, 65)
	glowDeco.ImageTransparency = 0.94
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
	subtitleLabel.TextSize = 15.5
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
	promptLabel.TextSize = 15
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

	local warnDesc: TextLabel? = nil

	local choiceCard = Instance.new("Frame")
	choiceCard.Size = UDim2.new(0.9, 0, 0.88, 0)
	choiceCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	choiceCard.AnchorPoint = Vector2.new(0.5, 0.5)
	choiceCard.BackgroundColor3 = Color3.fromRGB(26, 32, 48)
	choiceCard.BackgroundTransparency = 0.05
	choiceCard.BorderSizePixel = 0
	choiceCard.Parent = choiceFrame

	local choiceConstraint = Instance.new("UISizeConstraint")
	choiceConstraint.MaxSize = Vector2.new(520, 560)
	choiceConstraint.MinSize = Vector2.new(340, 460)
	choiceConstraint.Parent = choiceCard

	applyCorner(choiceCard, 16)
	applyStroke(choiceCard, COLORS.goldPrimary, 2.0)

	local choiceCardGrad = Instance.new("UIGradient")
	choiceCardGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 46, 68)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 28, 42)),
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
	choiceTopHeader.TextColor3 = COLORS.goldLight
	choiceTopHeader.TextSize = 14
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
	heroPanel.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
	heroPanel.BackgroundTransparency = 0.1
	heroPanel.BorderSizePixel = 0
	heroPanel.Parent = choiceCard

	applyCorner(heroPanel, 12)
	applyStroke(heroPanel, Color3.fromRGB(56, 70, 98), 1.4)

	-- Hero Avatar Crest Frame
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Size = UDim2.new(0, 84, 0, 84)
	avatarFrame.Position = UDim2.new(0, 16, 0, 16)
	avatarFrame.BackgroundColor3 = Color3.fromRGB(30, 38, 56)
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
	heroHandleLabel.TextColor3 = Color3.fromRGB(185, 200, 225)
	heroHandleLabel.TextSize = 14.5
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
		Color3.fromRGB(68, 50, 18),
		Color3.fromRGB(255, 195, 60),
		Color3.fromRGB(255, 230, 130)
	)

	local classBadge = createPillBadge(
		badgesContainer,
		"🔮 MAGE",
		Color3.fromRGB(60, 30, 90),
		Color3.fromRGB(190, 120, 255),
		Color3.fromRGB(240, 210, 255)
	)

	-- Inner Divider Line
	local heroDivider = Instance.new("Frame")
	heroDivider.Size = UDim2.new(1, -32, 0, 1)
	heroDivider.Position = UDim2.new(0, 16, 0, 114)
	heroDivider.BackgroundColor3 = Color3.fromRGB(48, 60, 84)
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

	local function createPerkChip(icon: string, title: string, subtitle: string): (TextLabel, TextLabel)
		local chip = Instance.new("Frame")
		chip.Size = UDim2.new(0.31, 0, 1, 0)
		chip.BackgroundColor3 = Color3.fromRGB(26, 34, 50)
		chip.BackgroundTransparency = 0.08
		chip.BorderSizePixel = 0
		chip.Parent = attrContainer

		applyCorner(chip, 8)
		applyStroke(chip, Color3.fromRGB(56, 72, 102), 1.2)

		local cTitle = Instance.new("TextLabel")
		cTitle.Size = UDim2.new(1, 0, 0, 18)
		cTitle.Position = UDim2.new(0, 0, 0, 8)
		cTitle.BackgroundTransparency = 1
		cTitle.Font = Enum.Font.GothamBold
		cTitle.Text = icon .. " " .. title
		cTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		cTitle.TextSize = 14
		cTitle.Parent = chip

		local cSub = Instance.new("TextLabel")
		cSub.Size = UDim2.new(1, 0, 0, 16)
		cSub.Position = UDim2.new(0, 0, 0, 26)
		cSub.BackgroundTransparency = 1
		cSub.Font = Enum.Font.GothamMedium
		cSub.Text = subtitle
		cSub.TextColor3 = Color3.fromRGB(190, 208, 235)
		cSub.TextSize = 13
		cSub.Parent = chip

		return cTitle, cSub
	end

	local chip1Title, chip1Sub = createPerkChip("❤️", "80 HP", "Base Health")
	local chip2Title, chip2Sub = createPerkChip("🔮", "Arcane Bolt", "Ranged Focus")
	local chip3Title, chip3Sub = createPerkChip("🔥", "Spellweaver", "Fire & Frost")

	local function updateHeroChoiceCard(classId: string, level: number)
		local levelText = ("⭐ LEVEL %d"):format(level)
		local lvlChild = levelBadge:FindFirstChildOfClass("TextLabel")
		if lvlChild then
			lvlChild.Text = levelText
		end

		local isMage = (classId == "Mage")
		local badgeLabel = classBadge:FindFirstChildOfClass("TextLabel")
		local badgeStroke = classBadge:FindFirstChildOfClass("UIStroke")
		if badgeLabel then
			badgeLabel.Text = isMage and "🔮 MAGE" or "🛡️ TANK"
			badgeLabel.TextColor3 = isMage and Color3.fromRGB(240, 210, 255) or Color3.fromRGB(150, 210, 255)
		end
		if badgeStroke then
			badgeStroke.Color = isMage and Color3.fromRGB(190, 120, 255) or Color3.fromRGB(75, 150, 255)
		end
		classBadge.BackgroundColor3 = isMage and Color3.fromRGB(60, 30, 90) or Color3.fromRGB(24, 45, 80)

		if isMage then
			chip1Title.Text = "❤️ 80 HP"
			chip1Sub.Text = "Base Health"
			chip2Title.Text = "🔮 Arcane Bolt"
			chip2Sub.Text = "Ranged Focus"
			chip3Title.Text = "🔥 Spellweaver"
			chip3Sub.Text = "Fire & Frost"
		else
			chip1Title.Text = "❤️ 150 HP"
			chip1Sub.Text = "Base Health"
			chip2Title.Text = "🛡️ Taunt"
			chip2Sub.Text = "Threat Lock"
			chip3Title.Text = "⚔️ Blade & Shield"
			chip3Sub.Text = "Melee Defender"
		end

		if warnDesc then
			warnDesc.Text = ("This will permanently delete your Level %d %s and reset all skill points, unlocked abilities, and level progression."):format(level, isMage and "Mage" or "Tank")
		end
	end

	-- Action Buttons Area
	local actionArea = Instance.new("Frame")
	actionArea.Size = UDim2.new(1, 0, 0, 116)
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
		primaryColor = Color3.fromRGB(36, 185, 104),
		gradientTop = Color3.fromRGB(56, 225, 132),
		gradientBottom = Color3.fromRGB(24, 150, 78),
		strokeColor = Color3.fromRGB(135, 255, 185),
		textColor = Color3.fromRGB(255, 255, 255),
		textSize = 16,
		font = Enum.Font.GothamBlack,
		onClick = function()
			continueBtn.Active = false
			createNewBtn.Active = false
			continueBtn.Text = "ENTERING REALM..."
			setMenuBlur(false)
			Net.Get("RequestLoadCharacter"):FireServer()
		end,
	})

	createNewBtn = createStyledButton({
		parent = actionArea,
		text = "🔄   REFORGE HERO (START ANEW)",
		size = UDim2.new(1, 0, 0, 46),
		position = UDim2.new(0, 0, 0, 60),
		primaryColor = Color3.fromRGB(120, 34, 48),
		gradientTop = Color3.fromRGB(165, 52, 70),
		gradientBottom = Color3.fromRGB(95, 26, 38),
		strokeColor = Color3.fromRGB(255, 120, 135),
		textColor = Color3.fromRGB(255, 255, 255),
		textSize = 15,
		font = Enum.Font.GothamBold,
		-- Actual click behavior is wired below via createNewBtn.Activated,
		-- once confirmFrame (Screen 4) exists to be shown.
		onClick = function() end,
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
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 46, 68)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 28, 42)),
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
	createTopHeader.TextColor3 = COLORS.goldLight
	createTopHeader.TextSize = 14
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
	classCardsRow.Size = UDim2.new(1, 0, 0, 220)
	classCardsRow.Position = UDim2.new(0, 0, 0, 56)
	classCardsRow.BackgroundTransparency = 1
	classCardsRow.Parent = createCard

	local tankCard, tankCardStroke, tankCardHitbox = createClassCard(classCardsRow, "Tank", 0, 0.485)
	local mageCard, mageCardStroke, mageCardHitbox = createClassCard(classCardsRow, "Mage", 0.515, 0.485)

	local selectedClassId = "Mage"

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
	playingAsText.Position = UDim2.new(0, 0, 0, 286)
	playingAsText.BackgroundTransparency = 1
	playingAsText.Font = Enum.Font.GothamMedium
	playingAsText.Text = ("Champion: %s (@%s)"):format(player.DisplayName, player.Name)
	playingAsText.TextColor3 = Color3.fromRGB(190, 205, 230)
	playingAsText.TextSize = 14.5
	playingAsText.Parent = createCard

	local beginBtn: TextButton
	beginBtn = createStyledButton({
		parent = createCard,
		text = "⚔️   EMBARK ON JOURNEY",
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.new(0, 0, 0, 314),
		primaryColor = Color3.fromRGB(36, 185, 104),
		gradientTop = Color3.fromRGB(56, 225, 132),
		gradientBottom = Color3.fromRGB(24, 150, 78),
		strokeColor = Color3.fromRGB(135, 255, 185),
		textColor = Color3.fromRGB(255, 255, 255),
		textSize = 16,
		font = Enum.Font.GothamBlack,
		onClick = function()
			beginBtn.Active = false
			beginBtn.Text = "FORGING HERO..."
			setMenuBlur(false)
			if creationFlowMode == "reforge" then
				Net.Get("RequestCreateNewCharacter"):FireServer(selectedClassId)
			else
				Net.Get("SubmitCharacterCreation"):FireServer(selectedClassId)
			end
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
	confirmCard.BackgroundColor3 = Color3.fromRGB(34, 26, 32)
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
	warnTitle.TextColor3 = Color3.fromRGB(255, 110, 125)
	warnTitle.TextSize = 20
	warnTitle.Parent = confirmCard

	warnDesc = Instance.new("TextLabel")
	warnDesc.Size = UDim2.new(1, 0, 0, 70)
	warnDesc.Position = UDim2.new(0, 0, 0, 80)
	warnDesc.BackgroundTransparency = 1
	warnDesc.Font = Enum.Font.GothamMedium
	warnDesc.Text = "This will permanently delete your character and reset all skill points, unlocked abilities, and level progression."
	warnDesc.TextColor3 = Color3.fromRGB(235, 205, 215)
	warnDesc.TextSize = 14.5
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
		primaryColor = Color3.fromRGB(48, 60, 82),
		gradientTop = Color3.fromRGB(64, 80, 110),
		gradientBottom = Color3.fromRGB(38, 48, 66),
		strokeColor = Color3.fromRGB(120, 150, 195),
		textColor = Color3.fromRGB(255, 255, 255),
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
		primaryColor = Color3.fromRGB(160, 36, 48),
		gradientTop = Color3.fromRGB(200, 52, 68),
		gradientBottom = Color3.fromRGB(130, 28, 38),
		strokeColor = Color3.fromRGB(255, 120, 135),
		textColor = Color3.fromRGB(255, 255, 255),
		textSize = 14,
		font = Enum.Font.GothamBlack,
		onClick = function()
			creationFlowMode = "reforge"
			confirmFrame.Visible = false
			createFrame.Visible = true
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
	loadingCard.Size = UDim2.new(0, 360, 0, 84)
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
	loadingLabel.TextSize = 14.5
	loadingLabel.Parent = loadingCard

	-- ══════════════════════════════════════════════════════════════════════
	-- STATE MACHINE & SCREEN NAVIGATION
	-- ══════════════════════════════════════════════════════════════════════
	local introDismissed = false
	local pendingScreen: "creation" | "choice" | nil = nil
	local pendingLevel = 1
	local pendingClassId = "Mage"

	local function showPendingScreen()
		if not introDismissed or not pendingScreen then
			return
		end
		loadingCard.Visible = false
		if pendingScreen == "creation" then
			createFrame.Visible = true
		elseif pendingScreen == "choice" then
			updateHeroChoiceCard(pendingClassId, pendingLevel)
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

	local function setHudVisible(visible: boolean)
		local hud = playerGui:FindFirstChild("HUD")
		if hud and hud:IsA("ScreenGui") then
			hud.Enabled = visible
		end
		local party = playerGui:FindFirstChild("PartyUI")
		if party and party:IsA("ScreenGui") then
			party.Enabled = visible
		end
	end

	Net.Get("ShowCharacterCreation").OnClientEvent:Connect(function()
		if player.Character and player.Character.Parent then
			screenGui.Enabled = false
			setMenuBlur(false)
			setHudVisible(true)
			return
		end
		setHudVisible(false)
		screenGui.Enabled = true
		setMenuBlur(true)
		pendingScreen = "creation"
		showPendingScreen()
	end)

	Net.Get("ShowCharacterChoice").OnClientEvent:Connect(function(level: number, classId: string?)
		if player.Character and player.Character.Parent then
			screenGui.Enabled = false
			setMenuBlur(false)
			setHudVisible(true)
			return
		end
		setHudVisible(false)
		screenGui.Enabled = true
		setMenuBlur(true)
		pendingScreen = "choice"
		pendingLevel = level or 1
		pendingClassId = classId or "Mage"
		showPendingScreen()
	end)

	-- Clean exit when character spawns in game
	player.CharacterAdded:Connect(function()
		screenGui.Enabled = false
		setMenuBlur(false)
		setHudVisible(true)
	end)

	if player.Character and player.Character.Parent then
		screenGui.Enabled = false
		setMenuBlur(false)
		setHudVisible(true)
	else
		setHudVisible(false)
		screenGui.Enabled = true
		setMenuBlur(true)
		-- Request initial character state in case event arrived before script initialized
		Net.Get("RequestCharacterState"):FireServer()
	end
end


return CharacterCreationController
