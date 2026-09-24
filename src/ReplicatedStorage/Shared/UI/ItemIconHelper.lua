-- src/ReplicatedStorage/Shared/UI/ItemIconHelper.lua
-- High-fidelity procedural dark-fantasy MMO icons for equipment slots, gear pieces, materials, and currency.
-- Built entirely using clean vector UI primitives (Frames, UICorner, UIStroke, UIGradient).
-- Strictly NO emojis or emoticons — crisp, resolution-independent, zero-texture-lag aesthetics.

local EquipmentData = require(script.Parent.Parent.Data.Equipment)

local ItemIconHelper = {}

-- ============================================================================
-- COLOR PALETTES
-- ============================================================================
local COLORS = {
	bgDark       = Color3.fromRGB(16, 14, 12),
	bgSlot       = Color3.fromRGB(24, 20, 16),
	borderDim    = Color3.fromRGB(60, 48, 36),
	borderBright = Color3.fromRGB(215, 145, 45),

	steelBright  = Color3.fromRGB(220, 225, 235),
	steelMid     = Color3.fromRGB(150, 158, 170),
	steelDark    = Color3.fromRGB(75, 82, 95),

	goldBright   = Color3.fromRGB(255, 215, 75),
	goldMid      = Color3.fromRGB(215, 165, 45),
	goldDark     = Color3.fromRGB(135, 95, 25),

	rockDark     = Color3.fromRGB(38, 34, 30),
	rockMid      = Color3.fromRGB(58, 52, 46),
	rockLight    = Color3.fromRGB(85, 78, 70),

	magmaGlow    = Color3.fromRGB(255, 110, 20),
	magmaCore    = Color3.fromRGB(255, 185, 45),

	leatherBase  = Color3.fromRGB(115, 75, 42),
	leatherDark  = Color3.fromRGB(70, 44, 24),
	leatherLight = Color3.fromRGB(155, 105, 60),

	woodBase     = Color3.fromRGB(120, 85, 50),
	woodDark     = Color3.fromRGB(68, 48, 28),
	woodLight    = Color3.fromRGB(165, 120, 75),

	runeCyan     = Color3.fromRGB(70, 215, 245),
	runeDark     = Color3.fromRGB(20, 55, 68),

	arcaneViolet = Color3.fromRGB(180, 70, 255),
	arcaneBright = Color3.fromRGB(220, 140, 255),
	arcaneDark   = Color3.fromRGB(80, 25, 120),
	frostCyan    = Color3.fromRGB(110, 220, 255),
	robeIndigo   = Color3.fromRGB(35, 38, 70),
	robeDark     = Color3.fromRGB(22, 24, 45),
}

local function corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, topColor: Color3, bottomColor: Color3, angle: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topColor, bottomColor)
	g.Rotation = angle or 90
	g.Parent = parent
	return g
end

-- ============================================================================
-- BASE ICON TILE BUILDER
-- ============================================================================
local function createBaseTile(parent: Instance, size: UDim2?, isSelected: boolean?): Frame
	local tile = Instance.new("Frame")
	tile.Name = "IconTile"
	tile.Size = size or UDim2.new(0, 36, 0, 36)
	tile.BackgroundColor3 = isSelected and Color3.fromRGB(38, 28, 18) or COLORS.bgSlot
	tile.BorderSizePixel = 0
	tile.ClipsDescendants = true
	corner(tile, 6)
	stroke(tile, isSelected and COLORS.borderBright or COLORS.borderDim, isSelected and 1.6 or 1)
	gradient(tile, Color3.fromRGB(32, 26, 20), Color3.fromRGB(16, 13, 10), 90)
	tile.Parent = parent
	return tile
end

-- ============================================================================
-- 1. GEAR PIECE & SLOT ICONS
-- ============================================================================

-- WEAPON ICON (Crossed Knight Blades / Greatsword)
local function buildWeaponGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "WeaponGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	local bladeColor = isRockhide and COLORS.rockDark or COLORS.steelMid
	local edgeColor = isRockhide and COLORS.magmaGlow or COLORS.steelBright

	-- First blade (diagonal from bottom-left to top-right)
	local blade1 = Instance.new("Frame")
	blade1.Size = UDim2.new(0, 4, 0, 24)
	blade1.AnchorPoint = Vector2.new(0.5, 0.5)
	blade1.Position = UDim2.new(0.5, 0, 0.5, -2)
	blade1.Rotation = 45
	blade1.BackgroundColor3 = bladeColor
	blade1.BorderSizePixel = 0
	corner(blade1, 2)
	gradient(blade1, edgeColor, bladeColor, 90)
	blade1.Parent = center

	-- Crossguard 1
	local guard1 = Instance.new("Frame")
	guard1.Size = UDim2.new(0, 12, 0, 2.5)
	guard1.AnchorPoint = Vector2.new(0.5, 0.5)
	guard1.Position = UDim2.new(0.5, -3, 0.5, 3)
	guard1.Rotation = 45
	guard1.BackgroundColor3 = isRockhide and COLORS.magmaCore or COLORS.goldMid
	guard1.BorderSizePixel = 0
	corner(guard1, 1)
	guard1.Parent = center

	-- Second blade (diagonal from bottom-right to top-left)
	local blade2 = Instance.new("Frame")
	blade2.Size = UDim2.new(0, 4, 0, 24)
	blade2.AnchorPoint = Vector2.new(0.5, 0.5)
	blade2.Position = UDim2.new(0.5, 0, 0.5, -2)
	blade2.Rotation = -45
	blade2.BackgroundColor3 = bladeColor
	blade2.BorderSizePixel = 0
	corner(blade2, 2)
	gradient(blade2, edgeColor, bladeColor, 90)
	blade2.Parent = center

	-- Crossguard 2
	local guard2 = Instance.new("Frame")
	guard2.Size = UDim2.new(0, 12, 0, 2.5)
	guard2.AnchorPoint = Vector2.new(0.5, 0.5)
	guard2.Position = UDim2.new(0.5, 3, 0.5, 3)
	guard2.Rotation = -45
	guard2.BackgroundColor3 = isRockhide and COLORS.magmaCore or COLORS.goldMid
	guard2.BorderSizePixel = 0
	corner(guard2, 1)
	guard2.Parent = center

	-- Central Boss Stud
	local centerGem = Instance.new("Frame")
	centerGem.Size = UDim2.new(0, 5, 0, 5)
	centerGem.AnchorPoint = Vector2.new(0.5, 0.5)
	centerGem.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerGem.BackgroundColor3 = isRockhide and COLORS.magmaGlow or COLORS.goldBright
	centerGem.BorderSizePixel = 0
	corner(centerGem, 3)
	centerGem.Parent = center
end

-- HEAD ICON (Knight Warhelm / Rockhide Horned Helm)
local function buildHeadGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "HeadGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Helm Crown (Arched skullcap)
	local crown = Instance.new("Frame")
	crown.Size = UDim2.new(0, 20, 0, 16)
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Position = UDim2.new(0.5, 0, 0.5, 0)
	crown.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.steelDark
	crown.BorderSizePixel = 0
	corner(crown, 8)
	gradient(crown, isRockhide and COLORS.rockMid or COLORS.steelMid, isRockhide and COLORS.rockDark or COLORS.steelDark, 90)
	crown.Parent = center

	-- Visor Slit (Dark aperture)
	local visor = Instance.new("Frame")
	visor.Size = UDim2.new(0, 14, 0, 3)
	visor.AnchorPoint = Vector2.new(0.5, 0.5)
	visor.Position = UDim2.new(0.5, 0, 0.5, 0)
	visor.BackgroundColor3 = isRockhide and COLORS.magmaGlow or Color3.fromRGB(15, 12, 10)
	visor.BorderSizePixel = 0
	corner(visor, 1)
	visor.Parent = center

	-- Nasal T-Bar
	local nasal = Instance.new("Frame")
	nasal.Size = UDim2.new(0, 2.5, 0, 7)
	nasal.AnchorPoint = Vector2.new(0.5, 0)
	nasal.Position = UDim2.new(0.5, 0, 0.5, 0)
	nasal.BackgroundColor3 = isRockhide and COLORS.rockLight or COLORS.steelBright
	nasal.BorderSizePixel = 0
	nasal.Parent = center

	-- Horns for Rockhide Helm
	if isRockhide then
		local hornL = Instance.new("Frame")
		hornL.Size = UDim2.new(0, 4, 0, 10)
		hornL.AnchorPoint = Vector2.new(0.5, 1)
		hornL.Position = UDim2.new(0.5, -8, 0.5, -3)
		hornL.Rotation = -35
		hornL.BackgroundColor3 = COLORS.magmaGlow
		hornL.BorderSizePixel = 0
		corner(hornL, 2)
		hornL.Parent = center

		local hornR = Instance.new("Frame")
		hornR.Size = UDim2.new(0, 4, 0, 10)
		hornR.AnchorPoint = Vector2.new(0.5, 1)
		hornR.Position = UDim2.new(0.5, 8, 0.5, -3)
		hornR.Rotation = 35
		hornR.BackgroundColor3 = COLORS.magmaGlow
		hornR.BorderSizePixel = 0
		corner(hornR, 2)
		hornR.Parent = center
	else
		-- Center Comb Crest for Standard Knight Helm
		local crest = Instance.new("Frame")
		crest.Size = UDim2.new(0, 3, 0, 7)
		crest.AnchorPoint = Vector2.new(0.5, 1)
		crest.Position = UDim2.new(0.5, 0, 0.5, -7)
		crest.BackgroundColor3 = COLORS.goldMid
		crest.BorderSizePixel = 0
		corner(crest, 1)
		crest.Parent = center
	end
end

-- BODY ICON (Armored Cuirass / Chestplate)
local function buildBodyGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "BodyGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Breastplate Main Armor Plate
	local breastplate = Instance.new("Frame")
	breastplate.Size = UDim2.new(0, 20, 0, 19)
	breastplate.AnchorPoint = Vector2.new(0.5, 0.5)
	breastplate.Position = UDim2.new(0.5, 0, 0.5, 1)
	breastplate.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.steelDark
	breastplate.BorderSizePixel = 0
	corner(breastplate, 4)
	gradient(breastplate, isRockhide and COLORS.rockMid or COLORS.steelMid, isRockhide and COLORS.rockDark or COLORS.steelDark, 90)
	breastplate.Parent = center

	-- Shoulder Arch Flanges
	local shoulderL = Instance.new("Frame")
	shoulderL.Size = UDim2.new(0, 6, 0, 5)
	shoulderL.AnchorPoint = Vector2.new(0.5, 0.5)
	shoulderL.Position = UDim2.new(0.5, -8, 0.5, -6)
	shoulderL.BackgroundColor3 = isRockhide and COLORS.rockLight or COLORS.steelBright
	shoulderL.BorderSizePixel = 0
	corner(shoulderL, 2)
	shoulderL.Parent = center

	local shoulderR = Instance.new("Frame")
	shoulderR.Size = UDim2.new(0, 6, 0, 5)
	shoulderR.AnchorPoint = Vector2.new(0.5, 0.5)
	shoulderR.Position = UDim2.new(0.5, 8, 0.5, -6)
	shoulderR.BackgroundColor3 = isRockhide and COLORS.rockLight or COLORS.steelBright
	shoulderR.BorderSizePixel = 0
	corner(shoulderR, 2)
	shoulderR.Parent = center

	-- Center Keel / Ridge Line
	local keel = Instance.new("Frame")
	keel.Size = UDim2.new(0, 2.5, 0, 14)
	keel.AnchorPoint = Vector2.new(0.5, 0.5)
	keel.Position = UDim2.new(0.5, 0, 0.5, 2)
	keel.BackgroundColor3 = isRockhide and COLORS.magmaGlow or COLORS.goldMid
	keel.BorderSizePixel = 0
	corner(keel, 1)
	keel.Parent = center

	-- Magma Core Rune for Rockhide
	if isRockhide then
		local core = Instance.new("Frame")
		core.Size = UDim2.new(0, 6, 0, 6)
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.Position = UDim2.new(0.5, 0, 0.5, -1)
		core.Rotation = 45
		core.BackgroundColor3 = COLORS.magmaCore
		core.BorderSizePixel = 0
		corner(core, 1)
		core.Parent = center
	end
end

-- ARMS ICON (Vambraces & Pauldrons / Buckler Shield)
local function buildArmsGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "ArmsGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Shield / Vambrace Contour
	local shield = Instance.new("Frame")
	shield.Size = UDim2.new(0, 19, 0, 21)
	shield.AnchorPoint = Vector2.new(0.5, 0.5)
	shield.Position = UDim2.new(0.5, 0, 0.5, 0)
	shield.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.steelDark
	shield.BorderSizePixel = 0
	corner(shield, 5)
	gradient(shield, isRockhide and COLORS.rockMid or COLORS.steelMid, isRockhide and COLORS.rockDark or COLORS.steelDark, 90)
	stroke(shield, isRockhide and COLORS.magmaGlow or COLORS.goldMid, 1)
	shield.Parent = center

	-- Central Boss Stud / Umbo
	local boss = Instance.new("Frame")
	boss.Size = UDim2.new(0, 7, 0, 7)
	boss.AnchorPoint = Vector2.new(0.5, 0.5)
	boss.Position = UDim2.new(0.5, 0, 0.5, 0)
	boss.Rotation = 45
	boss.BackgroundColor3 = isRockhide and COLORS.magmaCore or COLORS.steelBright
	boss.BorderSizePixel = 0
	corner(boss, 2)
	boss.Parent = center

	if isRockhide then
		-- Spikes projecting from shield rim
		for _, offset in {{-8, -8}, {8, -8}, {-8, 8}, {8, 8}} do
			local spk = Instance.new("Frame")
			spk.Size = UDim2.new(0, 3, 0, 3)
			spk.AnchorPoint = Vector2.new(0.5, 0.5)
			spk.Position = UDim2.new(0.5, offset[1], 0.5, offset[2])
			spk.Rotation = 45
			spk.BackgroundColor3 = COLORS.magmaGlow
			spk.BorderSizePixel = 0
			corner(spk, 1)
			spk.Parent = center
		end
	end
end

-- FEET ICON (Armored Knight Greaves & Sabatons)
local function buildFeetGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "FeetGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Shin Greave Bar (Vertical)
	local shin = Instance.new("Frame")
	shin.Size = UDim2.new(0, 7, 0, 14)
	shin.AnchorPoint = Vector2.new(0.5, 0.5)
	shin.Position = UDim2.new(0.5, -2, 0.5, -3)
	shin.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.steelDark
	shin.BorderSizePixel = 0
	corner(shin, 2)
	gradient(shin, isRockhide and COLORS.rockMid or COLORS.steelMid, isRockhide and COLORS.rockDark or COLORS.steelDark, 90)
	shin.Parent = center

	-- Knee Cop (Poleyn)
	local knee = Instance.new("Frame")
	knee.Size = UDim2.new(0, 9, 0, 4)
	knee.AnchorPoint = Vector2.new(0.5, 0.5)
	knee.Position = UDim2.new(0.5, -2, 0.5, -9)
	knee.BackgroundColor3 = isRockhide and COLORS.magmaGlow or COLORS.goldMid
	knee.BorderSizePixel = 0
	corner(knee, 1)
	knee.Parent = center

	-- Foot Sabaton Base (Horizontal toe extension)
	local sabaton = Instance.new("Frame")
	sabaton.Size = UDim2.new(0, 16, 0, 6)
	sabaton.AnchorPoint = Vector2.new(0.5, 0.5)
	sabaton.Position = UDim2.new(0.5, 2, 0.5, 6)
	sabaton.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.steelMid
	sabaton.BorderSizePixel = 0
	corner(sabaton, 2)
	sabaton.Parent = center

	-- Toe Claw / Plate
	local toe = Instance.new("Frame")
	toe.Size = UDim2.new(0, 5, 0, 5)
	toe.AnchorPoint = Vector2.new(0.5, 0.5)
	toe.Position = UDim2.new(0.5, 9, 0.5, 6)
	toe.Rotation = 45
	toe.BackgroundColor3 = isRockhide and COLORS.magmaCore or COLORS.steelBright
	toe.BorderSizePixel = 0
	corner(toe, 1)
	toe.Parent = center
end

-- MAGE WEAPON ICON (Arcane Focus Staff / Earthcaller's Basalt Staff)
local function buildStaffGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "StaffGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Staff Haft (Slender diagonal wooden / petrified shaft)
	local shaft = Instance.new("Frame")
	shaft.Size = UDim2.new(0, 3, 0, 26)
	shaft.AnchorPoint = Vector2.new(0.5, 0.5)
	shaft.Position = UDim2.new(0.5, -2, 0.5, 2)
	shaft.Rotation = -30
	shaft.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.woodBase
	shaft.BorderSizePixel = 0
	corner(shaft, 1.5)
	gradient(shaft, isRockhide and COLORS.rockMid or COLORS.woodLight, isRockhide and COLORS.rockDark or COLORS.woodDark, 90)
	shaft.Parent = center

	-- Lower Grip Wrap
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(0, 5, 0, 5)
	wrap.AnchorPoint = Vector2.new(0.5, 0.5)
	wrap.Position = UDim2.new(0.5, -5, 0.5, 7)
	wrap.Rotation = -30
	wrap.BackgroundColor3 = isRockhide and COLORS.leatherDark or COLORS.goldMid
	wrap.BorderSizePixel = 0
	corner(wrap, 1)
	wrap.Parent = center

	-- Upper Collar / Ring Band
	local collar = Instance.new("Frame")
	collar.Size = UDim2.new(0, 7, 0, 3)
	collar.AnchorPoint = Vector2.new(0.5, 0.5)
	collar.Position = UDim2.new(0.5, 3, 0.5, -6)
	collar.Rotation = -30
	collar.BackgroundColor3 = isRockhide and COLORS.magmaCore or COLORS.goldBright
	collar.BorderSizePixel = 0
	corner(collar, 1)
	collar.Parent = center

	-- Crown / Prongs
	local crownL = Instance.new("Frame")
	crownL.Size = UDim2.new(0, 2.5, 0, 8)
	crownL.AnchorPoint = Vector2.new(0.5, 1)
	crownL.Position = UDim2.new(0.5, 3, 0.5, -6)
	crownL.Rotation = -60
	crownL.BackgroundColor3 = isRockhide and COLORS.rockMid or COLORS.goldBright
	crownL.BorderSizePixel = 0
	corner(crownL, 1)
	crownL.Parent = center

	local crownR = Instance.new("Frame")
	crownR.Size = UDim2.new(0, 2.5, 0, 8)
	crownR.AnchorPoint = Vector2.new(0.5, 1)
	crownR.Position = UDim2.new(0.5, 6, 0.5, -7)
	crownR.Rotation = 0
	crownR.BackgroundColor3 = isRockhide and COLORS.rockMid or COLORS.goldBright
	crownR.BorderSizePixel = 0
	corner(crownR, 1)
	crownR.Parent = center

	-- Radiant Head Crystal / Magma Core
	local crystal = Instance.new("Frame")
	crystal.Size = UDim2.new(0, 9, 0, 9)
	crystal.AnchorPoint = Vector2.new(0.5, 0.5)
	crystal.Position = UDim2.new(0.5, 6, 0.5, -11)
	crystal.Rotation = 45
	crystal.BackgroundColor3 = isRockhide and COLORS.magmaGlow or COLORS.arcaneViolet
	crystal.BorderSizePixel = 0
	corner(crystal, isRockhide and 4 or 2)
	gradient(crystal, isRockhide and COLORS.magmaCore or COLORS.arcaneBright, isRockhide and COLORS.magmaGlow or COLORS.arcaneDark, 45)
	crystal.Parent = center

	-- Center Radiant Sparkle
	local spark = Instance.new("Frame")
	spark.Size = UDim2.new(0, 3, 0, 3)
	spark.AnchorPoint = Vector2.new(0.5, 0.5)
	spark.Position = UDim2.new(0.5, 6, 0.5, -11)
	spark.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	spark.BorderSizePixel = 0
	corner(spark, 2)
	spark.Parent = center
end

-- MAGE HEAD ICON (Indigo Arcanist Hood / Rockhide Basalt Cowl)
local function buildHoodGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "HoodGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Hood Outer Dome
	local hoodDome = Instance.new("Frame")
	hoodDome.Size = UDim2.new(0, 20, 0, 19)
	hoodDome.AnchorPoint = Vector2.new(0.5, 0.5)
	hoodDome.Position = UDim2.new(0.5, 0, 0.5, -1)
	hoodDome.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.robeIndigo
	hoodDome.BorderSizePixel = 0
	corner(hoodDome, 9)
	gradient(hoodDome, isRockhide and COLORS.rockMid or COLORS.robeIndigo, isRockhide and COLORS.rockDark or COLORS.robeDark, 90)
	hoodDome.Parent = center

	-- Face Aperture Shadow (Dark Inner Void)
	local shadowAperture = Instance.new("Frame")
	shadowAperture.Size = UDim2.new(0, 11, 0, 11)
	shadowAperture.AnchorPoint = Vector2.new(0.5, 0.5)
	shadowAperture.Position = UDim2.new(0.5, 0, 0.5, 0)
	shadowAperture.BackgroundColor3 = Color3.fromRGB(12, 10, 15)
	shadowAperture.BorderSizePixel = 0
	corner(shadowAperture, 5)
	shadowAperture.Parent = center

	if isRockhide then
		-- Obsidian Brow Plaque
		local browPlaque = Instance.new("Frame")
		browPlaque.Size = UDim2.new(0, 15, 0, 3.5)
		browPlaque.AnchorPoint = Vector2.new(0.5, 0.5)
		browPlaque.Position = UDim2.new(0.5, 0, 0.5, -4)
		browPlaque.BackgroundColor3 = COLORS.rockMid
		browPlaque.BorderSizePixel = 0
		corner(browPlaque, 2)
		browPlaque.Parent = center

		-- Glowing Magma Eye Slits
		local eyeL = Instance.new("Frame")
		eyeL.Size = UDim2.new(0, 3, 0, 1.5)
		eyeL.AnchorPoint = Vector2.new(0.5, 0.5)
		eyeL.Position = UDim2.new(0.5, -3, 0.5, 0.5)
		eyeL.BackgroundColor3 = COLORS.magmaGlow
		eyeL.BorderSizePixel = 0
		eyeL.Parent = center

		local eyeR = Instance.new("Frame")
		eyeR.Size = UDim2.new(0, 3, 0, 1.5)
		eyeR.AnchorPoint = Vector2.new(0.5, 0.5)
		eyeR.Position = UDim2.new(0.5, 3, 0.5, 0.5)
		eyeR.BackgroundColor3 = COLORS.magmaGlow
		eyeR.BorderSizePixel = 0
		eyeR.Parent = center
	else
		-- Fine Gold Hem Trim along hood edge
		local hemTrim = Instance.new("Frame")
		hemTrim.Size = UDim2.new(0, 13, 0, 1.5)
		hemTrim.AnchorPoint = Vector2.new(0.5, 0.5)
		hemTrim.Position = UDim2.new(0.5, 0, 0.5, -5)
		hemTrim.BackgroundColor3 = COLORS.goldBright
		hemTrim.BorderSizePixel = 0
		hemTrim.Parent = center

		-- Subtle Arcane Eye Shimmer
		local shimmer = Instance.new("Frame")
		shimmer.Size = UDim2.new(0, 5, 0, 1.5)
		shimmer.AnchorPoint = Vector2.new(0.5, 0.5)
		shimmer.Position = UDim2.new(0.5, 0, 0.5, 1)
		shimmer.BackgroundColor3 = COLORS.arcaneViolet
		shimmer.BorderSizePixel = 0
		corner(shimmer, 1)
		shimmer.Parent = center
	end
end

-- MAGE BODY ICON (Scholar Robe / Earthcaller Mantle)
local function buildRobeGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "RobeGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Robe Vestment Base (Flowing trapezoidal tunic)
	local vestment = Instance.new("Frame")
	vestment.Size = UDim2.new(0, 22, 0, 22)
	vestment.AnchorPoint = Vector2.new(0.5, 0.5)
	vestment.Position = UDim2.new(0.5, 0, 0.5, 1)
	vestment.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.robeIndigo
	vestment.BorderSizePixel = 0
	corner(vestment, 4)
	gradient(vestment, isRockhide and COLORS.rockMid or COLORS.robeIndigo, isRockhide and COLORS.rockDark or COLORS.robeDark, 90)
	vestment.Parent = center

	-- Shoulder Mantle Folds
	local mantleL = Instance.new("Frame")
	mantleL.Size = UDim2.new(0, 7, 0, 8)
	mantleL.AnchorPoint = Vector2.new(0.5, 0)
	mantleL.Position = UDim2.new(0.5, -8, 0.5, -10)
	mantleL.BackgroundColor3 = isRockhide and COLORS.rockMid or COLORS.robeDark
	mantleL.BorderSizePixel = 0
	corner(mantleL, 2)
	mantleL.Parent = center

	local mantleR = Instance.new("Frame")
	mantleR.Size = UDim2.new(0, 7, 0, 8)
	mantleR.AnchorPoint = Vector2.new(0.5, 0)
	mantleR.Position = UDim2.new(0.5, 8, 0.5, -10)
	mantleR.BackgroundColor3 = isRockhide and COLORS.rockMid or COLORS.robeDark
	mantleR.BorderSizePixel = 0
	corner(mantleR, 2)
	mantleR.Parent = center

	-- V-Neck Inset
	local vNeck = Instance.new("Frame")
	vNeck.Size = UDim2.new(0, 8, 0, 8)
	vNeck.AnchorPoint = Vector2.new(0.5, 0)
	vNeck.Position = UDim2.new(0.5, 0, 0.5, -9)
	vNeck.Rotation = 45
	vNeck.BackgroundColor3 = isRockhide and COLORS.magmaCore or COLORS.goldMid
	vNeck.BorderSizePixel = 0
	vNeck.Parent = center

	-- Central Runic Sash / Tectonic Filament (Vertical stole)
	local stole = Instance.new("Frame")
	stole.Size = UDim2.new(0, 3.5, 0, 16)
	stole.AnchorPoint = Vector2.new(0.5, 0)
	stole.Position = UDim2.new(0.5, 0, 0.5, -3)
	stole.BackgroundColor3 = isRockhide and COLORS.magmaGlow or COLORS.goldBright
	stole.BorderSizePixel = 0
	corner(stole, 1)
	stole.Parent = center
end

-- MAGE ARMS ICON (Apprentice Bracers / Tremor-Bound Wraps)
local function buildMageBracersGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "MageBracersGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Left and Right Bracer Cuffs
	for _, xOffset in {-7, 7} do
		local bracer = Instance.new("Frame")
		bracer.Size = UDim2.new(0, 8, 0, 18)
		bracer.AnchorPoint = Vector2.new(0.5, 0.5)
		bracer.Position = UDim2.new(0.5, xOffset, 0.5, 0)
		bracer.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.leatherBase
		bracer.BorderSizePixel = 0
		corner(bracer, 3)
		gradient(bracer, isRockhide and COLORS.rockMid or COLORS.leatherLight, isRockhide and COLORS.rockDark or COLORS.leatherDark, 90)
		bracer.Parent = center

		-- Wrap Rings / Filaments
		for _, yOff in {-4, 0, 4} do
			local band = Instance.new("Frame")
			band.Size = UDim2.new(0, 8, 0, 1.5)
			band.AnchorPoint = Vector2.new(0.5, 0.5)
			band.Position = UDim2.new(0.5, 0, 0.5, yOff)
			band.BackgroundColor3 = isRockhide and COLORS.magmaGlow or COLORS.goldMid
			band.BorderSizePixel = 0
			band.Parent = bracer
		end
	end

	-- Central Arcane Focus Rune between bracers
	local focusGem = Instance.new("Frame")
	focusGem.Size = UDim2.new(0, 5, 0, 5)
	focusGem.AnchorPoint = Vector2.new(0.5, 0.5)
	focusGem.Position = UDim2.new(0.5, 0, 0.5, 0)
	focusGem.Rotation = 45
	focusGem.BackgroundColor3 = isRockhide and COLORS.magmaCore or COLORS.arcaneViolet
	focusGem.BorderSizePixel = 0
	corner(focusGem, 2)
	focusGem.Parent = center
end

-- MAGE FEET ICON (Apprentice Treads / Earthstrider Boots)
local function buildMageBootsGraphic(parent: Frame, isRockhide: boolean?)
	local center = Instance.new("Frame")
	center.Name = "MageBootsGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Left Boot
	local bootL = Instance.new("Frame")
	bootL.Size = UDim2.new(0, 8, 0, 16)
	bootL.AnchorPoint = Vector2.new(0.5, 0.5)
	bootL.Position = UDim2.new(0.5, -6, 0.5, 0)
	bootL.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.leatherDark
	bootL.BorderSizePixel = 0
	corner(bootL, 3)
	gradient(bootL, isRockhide and COLORS.rockMid or COLORS.leatherBase, isRockhide and COLORS.rockDark or COLORS.leatherDark, 90)
	bootL.Parent = center

	-- Right Boot
	local bootR = Instance.new("Frame")
	bootR.Size = UDim2.new(0, 8, 0, 16)
	bootR.AnchorPoint = Vector2.new(0.5, 0.5)
	bootR.Position = UDim2.new(0.5, 6, 0.5, 0)
	bootR.BackgroundColor3 = isRockhide and COLORS.rockDark or COLORS.leatherDark
	bootR.BorderSizePixel = 0
	corner(bootR, 3)
	gradient(bootR, isRockhide and COLORS.rockMid or COLORS.leatherBase, isRockhide and COLORS.rockDark or COLORS.leatherDark, 90)
	bootR.Parent = center

	-- Ankle Cuffs / Straps
	for _, boot in {bootL, bootR} do
		local cuff = Instance.new("Frame")
		cuff.Size = UDim2.new(0, 9, 0, 3)
		cuff.AnchorPoint = Vector2.new(0.5, 0)
		cuff.Position = UDim2.new(0.5, 0, 0, 0)
		cuff.BackgroundColor3 = isRockhide and COLORS.rockLight or COLORS.goldMid
		cuff.BorderSizePixel = 0
		corner(cuff, 1)
		cuff.Parent = boot

		if isRockhide then
			local glowSole = Instance.new("Frame")
			glowSole.Size = UDim2.new(0, 8, 0, 2)
			glowSole.AnchorPoint = Vector2.new(0.5, 1)
			glowSole.Position = UDim2.new(0.5, 0, 1, 0)
			glowSole.BackgroundColor3 = COLORS.magmaGlow
			glowSole.BorderSizePixel = 0
			glowSole.Parent = boot
		end
	end
end

-- ============================================================================
-- 2. CRAFTING REAGENT ICONS
-- ============================================================================

-- ROCKHIDE FRAGMENT (Volcanic Basalt Shard + Glowing Magma Core)
local function buildRockhideFragmentGraphic(parent: Frame)
	local center = Instance.new("Frame")
	center.Name = "RockhideFragmentGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Outer Jagged Rock Shard 1
	local shard1 = Instance.new("Frame")
	shard1.Size = UDim2.new(0, 18, 0, 18)
	shard1.AnchorPoint = Vector2.new(0.5, 0.5)
	shard1.Position = UDim2.new(0.5, 0, 0.5, 0)
	shard1.Rotation = 45
	shard1.BackgroundColor3 = COLORS.rockDark
	shard1.BorderSizePixel = 0
	corner(shard1, 2)
	stroke(shard1, Color3.fromRGB(55, 48, 42), 1)
	shard1.Parent = center

	-- Outer Jagged Rock Shard 2 (Interlocking at an angle)
	local shard2 = Instance.new("Frame")
	shard2.Size = UDim2.new(0, 14, 0, 14)
	shard2.AnchorPoint = Vector2.new(0.5, 0.5)
	shard2.Position = UDim2.new(0.5, 2, 0.5, -2)
	shard2.Rotation = 20
	shard2.BackgroundColor3 = COLORS.rockMid
	shard2.BorderSizePixel = 0
	corner(shard2, 2)
	shard2.Parent = center

	-- Glowing Magma Core (Interior fissure)
	local core = Instance.new("Frame")
	core.Size = UDim2.new(0, 7, 0, 7)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.new(0.5, 0, 0.5, 0)
	core.Rotation = 45
	core.BackgroundColor3 = COLORS.magmaGlow
	core.BorderSizePixel = 0
	corner(core, 2)
	gradient(core, COLORS.magmaCore, COLORS.magmaGlow, 45)
	core.Parent = center

	-- Molten Ember highlight spark
	local spark = Instance.new("Frame")
	spark.Size = UDim2.new(0, 3, 0, 3)
	spark.AnchorPoint = Vector2.new(0.5, 0.5)
	spark.Position = UDim2.new(0.5, 3, 0.5, -3)
	spark.BackgroundColor3 = Color3.fromRGB(255, 220, 100)
	spark.BorderSizePixel = 0
	corner(spark, 1)
	spark.Parent = center
end

-- IRON INGOT (Forged Metallic Steel Bullion Bar)
local function buildIronIngotGraphic(parent: Frame)
	local center = Instance.new("Frame")
	center.Name = "IronIngotGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Ingot Main Trapezoid / Rectangle
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 22, 0, 12)
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.new(0.5, 0, 0.5, 2)
	bar.BackgroundColor3 = COLORS.steelMid
	bar.BorderSizePixel = 0
	corner(bar, 2)
	gradient(bar, COLORS.steelBright, COLORS.steelDark, 65)
	stroke(bar, Color3.fromRGB(90, 98, 112), 1)
	bar.Parent = center

	-- Top Bevel Sheen Facet
	local topFacet = Instance.new("Frame")
	topFacet.Size = UDim2.new(0, 18, 0, 3)
	topFacet.AnchorPoint = Vector2.new(0.5, 0)
	topFacet.Position = UDim2.new(0.5, 0, 0, 1)
	topFacet.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
	topFacet.BorderSizePixel = 0
	corner(topFacet, 1)
	topFacet.Parent = bar

	-- Embossed Forge Mark (Centered dark stamp)
	local stamp = Instance.new("Frame")
	stamp.Size = UDim2.new(0, 8, 0, 3.5)
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.new(0.5, 0, 0.5, 1)
	stamp.BackgroundColor3 = COLORS.steelDark
	stamp.BorderSizePixel = 0
	corner(stamp, 1)
	stamp.Parent = bar
end

-- LEATHER STRAP (Tanned Hide Strap with Brass Buckle)
local function buildLeatherStrapGraphic(parent: Frame)
	local center = Instance.new("Frame")
	center.Name = "LeatherStrapGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Tanned Leather Belt Strip
	local strap = Instance.new("Frame")
	strap.Size = UDim2.new(0, 22, 0, 10)
	strap.AnchorPoint = Vector2.new(0.5, 0.5)
	strap.Position = UDim2.new(0.5, 1, 0.5, 0)
	strap.BackgroundColor3 = COLORS.leatherBase
	strap.BorderSizePixel = 0
	corner(strap, 2)
	gradient(strap, COLORS.leatherLight, COLORS.leatherDark, 90)
	stroke(strap, Color3.fromRGB(58, 36, 18), 1)
	strap.Parent = center

	-- Stitching Accent Line
	local stitch = Instance.new("Frame")
	stitch.Size = UDim2.new(0, 18, 0, 1)
	stitch.AnchorPoint = Vector2.new(0.5, 0.5)
	stitch.Position = UDim2.new(0.5, 0, 0.5, 0)
	stitch.BackgroundColor3 = Color3.fromRGB(180, 135, 85)
	stitch.BorderSizePixel = 0
	stitch.Parent = strap

	-- Polished Brass Buckle (Outer rectangle frame)
	local buckle = Instance.new("Frame")
	buckle.Size = UDim2.new(0, 9, 0, 13)
	buckle.AnchorPoint = Vector2.new(0.5, 0.5)
	buckle.Position = UDim2.new(0.5, -6, 0.5, 0)
	buckle.BackgroundColor3 = Color3.fromRGB(20, 15, 12)
	buckle.BorderSizePixel = 0
	corner(buckle, 2)
	stroke(buckle, COLORS.goldBright, 1.4)
	buckle.Parent = center

	-- Buckle Tongue Pin
	local pin = Instance.new("Frame")
	pin.Size = UDim2.new(0, 4, 0, 1.5)
	pin.AnchorPoint = Vector2.new(0, 0.5)
	pin.Position = UDim2.new(0.5, -6, 0.5, 0)
	pin.BackgroundColor3 = COLORS.goldBright
	pin.BorderSizePixel = 0
	pin.Parent = center
end

-- OAK TIMBER (Hewn Wood Timber Planks)
local function buildOakTimberGraphic(parent: Frame)
	local center = Instance.new("Frame")
	center.Name = "OakTimberGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Base Log Plank
	local log = Instance.new("Frame")
	log.Size = UDim2.new(0, 22, 0, 13)
	log.AnchorPoint = Vector2.new(0.5, 0.5)
	log.Position = UDim2.new(0.5, 0, 0.5, 0)
	log.BackgroundColor3 = COLORS.woodBase
	log.BorderSizePixel = 0
	corner(log, 3)
	gradient(log, COLORS.woodLight, COLORS.woodDark, 90)
	stroke(log, Color3.fromRGB(55, 38, 22), 1)
	log.Parent = center

	-- Bark Edge Trim (Top and Bottom)
	local barkTop = Instance.new("Frame")
	barkTop.Size = UDim2.new(1, 0, 0, 2)
	barkTop.BackgroundColor3 = COLORS.woodDark
	barkTop.BorderSizePixel = 0
	barkTop.Parent = log

	local barkBottom = Instance.new("Frame")
	barkBottom.Size = UDim2.new(1, 0, 0, 2)
	barkBottom.AnchorPoint = Vector2.new(0, 1)
	barkBottom.Position = UDim2.new(0, 0, 1, 0)
	barkBottom.BackgroundColor3 = COLORS.woodDark
	barkBottom.BorderSizePixel = 0
	barkBottom.Parent = log

	-- Circular End Grain Ring
	local ring = Instance.new("Frame")
	ring.Size = UDim2.new(0, 7, 0, 7)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0, 5, 0.5, 0)
	ring.BackgroundColor3 = Color3.fromRGB(95, 65, 38)
	ring.BorderSizePixel = 0
	corner(ring, 4)
	ring.Parent = log
end

-- SUNSTONE CORE (Radiant Golden Solar Diamond)
local function buildSunstoneCoreGraphic(parent: Frame)
	local center = Instance.new("Frame")
	center.Name = "SunstoneCoreGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Outer Diamond Gem
	local outerGem = Instance.new("Frame")
	outerGem.Size = UDim2.new(0, 16, 0, 16)
	outerGem.AnchorPoint = Vector2.new(0.5, 0.5)
	outerGem.Position = UDim2.new(0.5, 0, 0.5, 0)
	outerGem.Rotation = 45
	outerGem.BackgroundColor3 = COLORS.goldMid
	outerGem.BorderSizePixel = 0
	corner(outerGem, 2)
	gradient(outerGem, Color3.fromRGB(255, 240, 140), Color3.fromRGB(215, 140, 20), 45)
	stroke(outerGem, COLORS.goldBright, 1)
	outerGem.Parent = center

	-- Inner Radiant Core
	local innerCore = Instance.new("Frame")
	innerCore.Size = UDim2.new(0, 8, 0, 8)
	innerCore.AnchorPoint = Vector2.new(0.5, 0.5)
	innerCore.Position = UDim2.new(0.5, 0, 0.5, 0)
	innerCore.Rotation = 45
	innerCore.BackgroundColor3 = Color3.fromRGB(255, 255, 220)
	innerCore.BorderSizePixel = 0
	corner(innerCore, 1)
	innerCore.Parent = center
end

-- ANCIENT RUNE (Obsidian Tablet with Glowing Cyan Glyph)
local function buildAncientRuneGraphic(parent: Frame)
	local center = Instance.new("Frame")
	center.Name = "AncientRuneGraphic"
	center.Size = UDim2.new(1, 0, 1, 0)
	center.BackgroundTransparency = 1
	center.Parent = parent

	-- Obsidian Tablet
	local tablet = Instance.new("Frame")
	tablet.Size = UDim2.new(0, 16, 0, 20)
	tablet.AnchorPoint = Vector2.new(0.5, 0.5)
	tablet.Position = UDim2.new(0.5, 0, 0.5, 0)
	tablet.BackgroundColor3 = Color3.fromRGB(18, 24, 30)
	tablet.BorderSizePixel = 0
	corner(tablet, 3)
	stroke(tablet, COLORS.runeCyan, 1)
	tablet.Parent = center

	-- Inscribed Rune Cross
	local runeH = Instance.new("Frame")
	runeH.Size = UDim2.new(0, 8, 0, 2)
	runeH.AnchorPoint = Vector2.new(0.5, 0.5)
	runeH.Position = UDim2.new(0.5, 0, 0.5, 0)
	runeH.BackgroundColor3 = COLORS.runeCyan
	runeH.BorderSizePixel = 0
	runeH.Parent = tablet

	local runeV = Instance.new("Frame")
	runeV.Size = UDim2.new(0, 2, 0, 12)
	runeV.AnchorPoint = Vector2.new(0.5, 0.5)
	runeV.Position = UDim2.new(0.5, 0, 0.5, 0)
	runeV.BackgroundColor3 = COLORS.runeCyan
	runeV.BorderSizePixel = 0
	runeV.Parent = tablet
end

local function attachIconImage(tile: Frame, imagePath: string?): ImageLabel?
	if not imagePath or imagePath == "" then return nil end

	local img = Instance.new("ImageLabel")
	img.Name = "ItemArtwork"
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Position = UDim2.new(0.5, 0, 0.5, 0)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Crop
	img.Image = imagePath
	img.ZIndex = 3
	img.Parent = tile

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = img

	return img
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Creates an icon tile for a gear slot ("Weapon" | "Head" | "Body" | "Arms" | "Feet")
function ItemIconHelper.CreateSlotIcon(parent: Instance, slotName: string, size: UDim2?, isSelected: boolean?): Frame
	local tile = createBaseTile(parent, size, isSelected)
	if slotName == "Weapon" then
		buildWeaponGraphic(tile, false)
	elseif slotName == "Head" then
		buildHeadGraphic(tile, false)
	elseif slotName == "Body" then
		buildBodyGraphic(tile, false)
	elseif slotName == "Arms" then
		buildArmsGraphic(tile, false)
	elseif slotName == "Feet" then
		buildFeetGraphic(tile, false)
	end

	local slotImages = {
		Weapon = "rbxasset://textures/Soulforge/standard_sword_icon.png",
		Head   = "rbxasset://textures/Soulforge/standard_helm_icon.png",
		Body   = "rbxasset://textures/Soulforge/standard_chest_icon.png",
		Arms   = "rbxasset://textures/Soulforge/standard_arms_icon.png",
		Feet   = "rbxasset://textures/Soulforge/standard_feet_icon.png",
	}
	if slotImages[slotName] then
		local img = attachIconImage(tile, slotImages[slotName])
		if img then
			img.ImageTransparency = 0.45
		end
	end

	return tile
end

-- Creates an icon tile for a specific equipment item ID
function ItemIconHelper.CreateItemIcon(parent: Instance, itemId: string, size: UDim2?, isSelected: boolean?): Frame
	local tile = createBaseTile(parent, size, isSelected)
	local item = EquipmentData.Items[itemId]
	local slot = item and item.slot or "Weapon"
	local isRockhide = (item and (item.setId == "Rockhide" or item.setId == "RockhideMage" or item.setId == "RockhideHealer"))
	-- "Caster-style" gear renders with the staff/hood/robe/bracer/boot graphics -- covers
	-- Mage and (Phase 1 of) Healer, which deliberately reuses these same shapes for now.
	local isMage = (item and (item.setId == "Apprentice" or item.setId == "RockhideMage" or item.setId == "Sanctum" or item.setId == "RockhideHealer"))

	if slot == "Weapon" then
		if isMage or itemId == "ApprenticeStaff" or itemId == "RockhideStaff" then
			buildStaffGraphic(tile, isRockhide)
		else
			buildWeaponGraphic(tile, isRockhide)
		end
	elseif slot == "Head" then
		if isMage or itemId == "ApprenticeHood" or itemId == "RockhideCowl" then
			buildHoodGraphic(tile, isRockhide)
		else
			buildHeadGraphic(tile, isRockhide)
		end
	elseif slot == "Body" then
		if isMage or itemId == "ApprenticeRobe" or itemId == "RockhideRobes" then
			buildRobeGraphic(tile, isRockhide)
		else
			buildBodyGraphic(tile, isRockhide)
		end
	elseif slot == "Arms" then
		if isMage or itemId == "ApprenticeBracers" or itemId == "RockhideWraps" then
			buildMageBracersGraphic(tile, isRockhide)
		else
			buildArmsGraphic(tile, isRockhide)
		end
	elseif slot == "Feet" then
		if isMage or itemId == "ApprenticeBoots" or itemId == "RockhideStriders" then
			buildMageBootsGraphic(tile, isRockhide)
		else
			buildFeetGraphic(tile, isRockhide)
		end
	end

	if item and item.icon then
		attachIconImage(tile, item.icon)
	end

	return tile
end

-- Creates an icon tile for a crafting material reagent
function ItemIconHelper.CreateMaterialIcon(parent: Instance, matId: string, size: UDim2?): Frame
	local tile = createBaseTile(parent, size or UDim2.new(0, 30, 0, 30), false)
	local matDef = EquipmentData.Materials[matId]

	if matId == "RockhideFragment" then
		buildRockhideFragmentGraphic(tile)
	elseif matId == "IronIngot" then
		buildIronIngotGraphic(tile)
	elseif matId == "LeatherStrap" then
		buildLeatherStrapGraphic(tile)
	elseif matId == "OakTimber" then
		buildOakTimberGraphic(tile)
	elseif matId == "SunstoneCore" then
		buildSunstoneCoreGraphic(tile)
	elseif matId == "AncientRune" then
		buildAncientRuneGraphic(tile)
	else
		-- Generic gemstone fallback (no emojis!)
		buildSunstoneCoreGraphic(tile)
	end

	if matDef and matDef.icon then
		attachIconImage(tile, matDef.icon)
	end

	return tile
end

-- Creates a minted gold coin insignia
function ItemIconHelper.CreateGoldCoinIcon(parent: Instance, size: UDim2?): Frame
	local coin = Instance.new("Frame")
	coin.Name = "GoldCoin"
	coin.Size = size or UDim2.new(0, 18, 0, 18)
	coin.BackgroundColor3 = COLORS.goldMid
	coin.BorderSizePixel = 0
	corner(coin, 100)
	stroke(coin, COLORS.goldBright, 1.2)
	gradient(coin, Color3.fromRGB(255, 235, 120), Color3.fromRGB(190, 135, 30), 45)

	local gLabel = Instance.new("TextLabel")
	gLabel.Text = "G"
	gLabel.TextColor3 = Color3.fromRGB(75, 45, 10)
	gLabel.Font = Enum.Font.GothamBlack
	gLabel.TextSize = 10
	gLabel.BackgroundTransparency = 1
	gLabel.Size = UDim2.new(1, 0, 1, 0)
	gLabel.Parent = coin

	coin.Parent = parent
	return coin
end

return ItemIconHelper
