-- src/ServerScriptService/Services/HubMapService.lua
-- Generates and manages the Grand MMO Hub Sanctuary (Soulforge Outpost):
-- Features a cobblestone town plaza, grand mystic dungeon portal with swirling runes,
-- ancient celestial Level-Up Shrine, combat training grounds with interactive target dummies,
-- an Adventurers' Tavern, Blacksmith Forge, defensive watchtowers, and atmospheric lighting.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = require(script.Parent.CombatService)

local Assets = ReplicatedStorage:WaitForChild("Assets")

local HubMapService = {}

local hubFolder: Model? = nil

-- Palette Constants
local STONE_COLOR    = Color3.fromRGB(80, 83, 88)
local DARK_STONE     = Color3.fromRGB(50, 52, 56)
local PAVING_COLOR   = Color3.fromRGB(115, 118, 122)
local WOOD_COLOR     = Color3.fromRGB(90, 60, 40)
local DARK_WOOD      = Color3.fromRGB(55, 38, 25)
local GOLD_TRIM      = Color3.fromRGB(225, 185, 60)
local ROOF_COLOR     = Color3.fromRGB(145, 55, 45)
local PORTAL_COLOR   = Color3.fromRGB(80, 140, 255)
local SHRINE_COLOR   = Color3.fromRGB(255, 215, 75)

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makePillar(parent: Instance, position: Vector3, height: number, width: number)
	makePart(parent, "Pillar", Vector3.new(width, height, width), CFrame.new(position + Vector3.new(0, height / 2, 0)), STONE_COLOR, Enum.Material.Cobblestone)
	makePart(parent, "PillarBase", Vector3.new(width + 1.2, 1.6, width + 1.2), CFrame.new(position + Vector3.new(0, 0.8, 0)), DARK_STONE, Enum.Material.Slate)
	makePart(parent, "PillarCap", Vector3.new(width + 1.2, 1.6, width + 1.2), CFrame.new(position + Vector3.new(0, height - 0.8, 0)), DARK_STONE, Enum.Material.Slate)
end

local function makeStreetLamp(parent: Instance, position: Vector3)
	-- Wooden post
	makePart(parent, "LampPost", Vector3.new(1, 10, 1), CFrame.new(position + Vector3.new(0, 5, 0)), DARK_WOOD, Enum.Material.Wood)
	-- Iron lantern frame
	makePart(parent, "LampCap", Vector3.new(2, 0.6, 2), CFrame.new(position + Vector3.new(0, 10.3, 0)), DARK_STONE, Enum.Material.Metal)
	-- Glowing core
	local lamp = makePart(parent, "LampCore", Vector3.new(1.2, 1.5, 1.2), CFrame.new(position + Vector3.new(0, 9.2, 0)), Color3.fromRGB(255, 210, 120), Enum.Material.Neon)
	lamp.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 100)
	light.Brightness = 2.2
	light.Range = 28
	light.Shadows = true
	light.Parent = lamp
end

local function makeBrazier(parent: Instance, position: Vector3, flameColor: Color3)
	-- Stone stand
	makePart(parent, "BrazierStand", Vector3.new(2.4, 3, 2.4), CFrame.new(position + Vector3.new(0, 1.5, 0)), DARK_STONE, Enum.Material.Cobblestone)
	-- Metal bowl
	makePart(parent, "BrazierBowl", Vector3.new(3.4, 1.2, 3.4), CFrame.new(position + Vector3.new(0, 3.6, 0)), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)

	-- Fire core
	local firePart = Instance.new("Part")
	firePart.Name = "BrazierFlame"
	firePart.Size = Vector3.new(1.5, 0.5, 1.5)
	firePart.CFrame = CFrame.new(position + Vector3.new(0, 4.2, 0))
	firePart.Color = flameColor
	firePart.Material = Enum.Material.Neon
	firePart.Anchored = true
	firePart.CanCollide = false
	firePart.Parent = parent

	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 6
	fire.Color = flameColor
	fire.SecondaryColor = Color3.fromRGB(255, 120, 30)
	fire.Parent = firePart

	local light = Instance.new("PointLight")
	light.Color = flameColor
	light.Brightness = 3
	light.Range = 32
	light.Shadows = true
	light.Parent = firePart
end

-- Clones a pre-generated mesh template from ReplicatedStorage.Assets, anchors it,
-- and positions it at the given CFrame. Returns nil (with a warning) if the
-- template is missing so a bad asset name never throws during hub construction.
local function cloneAsset(parent: Instance, assetName: string, cframe: CFrame): Instance?
	local template = Assets:FindFirstChild(assetName)
	if not template then
		warn("HubMapService: missing asset ReplicatedStorage.Assets." .. assetName)
		return nil
	end

	local clone = template:Clone()
	if clone:IsA("Model") then
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		clone:PivotTo(cframe)
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
		clone.Anchored = true
	end

	clone.Parent = parent
	return clone
end

-- ── BUILD TRAINING DUMMIES ──────────────────────────────────────────────────
local function makeTrainingDummy(parent: Instance, name: string, position: Vector3)
	local dummy = Instance.new("Model")
	dummy.Name = name

	-- Stand / Pole
	local pole = makePart(dummy, "Pole", Vector3.new(0.8, 6, 0.8), CFrame.new(position + Vector3.new(0, 3, 0)), DARK_WOOD, Enum.Material.Wood)
	pole.CanCollide = true

	-- Straw Torso
	local torso = makePart(dummy, "HumanoidRootPart", Vector3.new(2.4, 3.6, 1.6), CFrame.new(position + Vector3.new(0, 4.2, 0)), Color3.fromRGB(180, 160, 110), Enum.Material.Fabric)
	torso.CanCollide = true
	dummy.PrimaryPart = torso

	-- Straw Head / Target
	local head = makePart(dummy, "Head", Vector3.new(1.8, 1.8, 1.8), CFrame.new(position + Vector3.new(0, 6.8, 0)), Color3.fromRGB(190, 170, 120), Enum.Material.Fabric)
	head.CanCollide = true

	-- Iron Helmet
	local helm = makePart(dummy, "Helmet", Vector3.new(2.0, 0.8, 2.0), CFrame.new(position + Vector3.new(0, 7.6, 0)), Color3.fromRGB(85, 90, 95), Enum.Material.Metal)
	helm.CanCollide = false

	-- Crossbeam Arms
	local crossbeam = makePart(dummy, "Crossbeam", Vector3.new(5.0, 0.6, 0.6), CFrame.new(position + Vector3.new(0, 4.6, 0)), DARK_WOOD, Enum.Material.Wood)
	crossbeam.CanCollide = false

	-- Welds
	local function weld(p0, p1)
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p0
	end
	weld(torso, pole)
	weld(torso, head)
	weld(torso, helm)
	weld(torso, crossbeam)

	-- Floating Name / Health Billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "DummyInfo"
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.5, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "Training Dummy"
	label.Parent = bb

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.4, 0)
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextScaled = true
	subLabel.Text = "[Practice Target]"
	subLabel.Parent = bb

	CollectionService:AddTag(dummy, "Enemy")
	dummy.Parent = parent

	-- Register in CombatService so players can test normal attack and skills!
	local dummyHandle = {
		model = dummy,
		currentHealth = 999999,
		maxHealth = 999999,
		onDamaged = function(amount: number, attackingPlayer: Player?)
			-- Damage punch wobble animation
			local defaultCFrame = CFrame.new(position + Vector3.new(0, 4.2, 0))
			local hitTilt = defaultCFrame * CFrame.Angles(math.rad(-15), 0, math.rad(math.random(-8, 8)))
			torso.CFrame = hitTilt

			-- Floating damage indicator
			if attackingPlayer and head then
				local dmgPart = Instance.new("Part")
				dmgPart.Size = Vector3.new(0.1, 0.1, 0.1)
				dmgPart.Transparency = 1
				dmgPart.Anchored = true
				dmgPart.CanCollide = false
				dmgPart.CFrame = head.CFrame * CFrame.new(math.random(-1, 1), 1.5, math.random(-1, 1))
				dmgPart.Parent = workspace

				local dmgBb = Instance.new("BillboardGui")
				dmgBb.Size = UDim2.new(0, 80, 0, 30)
				dmgBb.AlwaysOnTop = true
				dmgBb.Parent = dmgPart

				local dmgText = Instance.new("TextLabel")
				dmgText.Size = UDim2.new(1, 0, 1, 0)
				dmgText.BackgroundTransparency = 1
				dmgText.TextColor3 = Color3.fromRGB(255, 235, 80)
				dmgText.Font = Enum.Font.GothamBlack
				dmgText.TextScaled = true
				dmgText.Text = "-" .. tostring(amount)
				dmgText.Parent = dmgBb

				local floatTween = TweenService:Create(dmgPart, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = dmgPart.CFrame + Vector3.new(0, 3, 0)
				})
				floatTween:Play()
				Debris:AddItem(dmgPart, 0.65)
			end

			task.delay(0.12, function()
				if torso and torso.Parent then
					torso.CFrame = defaultCFrame
				end
			end)
		end,
		onTaunted = function(_player: Player)
			subLabel.Text = "[Taunted!]"
			task.delay(1.5, function()
				if subLabel and subLabel.Parent then
					subLabel.Text = "[Practice Target]"
				end
			end)
		end,
	}
	CombatService.RegisterEnemy(name, dummyHandle)
end

function HubMapService.BuildHub(): Model
	-- Clean up existing hub if any
	local existing = workspace:FindFirstChild("SoulforgeHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "SoulforgeHub"
	hubFolder = hub

	local FLOOR_Y = 0

	-- ── 1. CENTRAL TOWN SQUARE PLAZA ──────────────────────────────────────────
	-- Grand cobblestone courtyard (150 x 150 studs)
	local plazaSize = 160
	makePart(hub, "Plaza_Floor", Vector3.new(plazaSize, 2, plazaSize),
		CFrame.new(0, FLOOR_Y - 1, 0), PAVING_COLOR, Enum.Material.Cobblestone)

	-- Decorative darker perimeter border
	makePart(hub, "Plaza_Border_N", Vector3.new(plazaSize, 1.2, 4), CFrame.new(0, FLOOR_Y + 0.6, -plazaSize/2 + 2), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "Plaza_Border_S", Vector3.new(plazaSize, 1.2, 4), CFrame.new(0, FLOOR_Y + 0.6, plazaSize/2 - 2), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "Plaza_Border_E", Vector3.new(4, 1.2, plazaSize), CFrame.new(plazaSize/2 - 2, FLOOR_Y + 0.6, 0), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "Plaza_Border_W", Vector3.new(4, 1.2, plazaSize), CFrame.new(-plazaSize/2 + 2, FLOOR_Y + 0.6, 0), DARK_STONE, Enum.Material.Slate)

	-- Decorative inner stone pathways (cross pattern leading to portal, shrine, training)
	makePart(hub, "Path_NorthSouth", Vector3.new(20, 2.05, plazaSize - 8), CFrame.new(0, FLOOR_Y - 1, 0), Color3.fromRGB(90, 92, 98), Enum.Material.Slate)
	makePart(hub, "Path_EastWest", Vector3.new(plazaSize - 8, 2.05, 20), CFrame.new(0, FLOOR_Y - 1, 0), Color3.fromRGB(90, 92, 98), Enum.Material.Slate)

	-- ── 2. CENTRAL SANCTUARY FOUNTAIN & SPAWN LOCATION ────────────────────────
	-- Raised circular marble dais in plaza center where players spawn
	local spawnDais = makePart(hub, "SpawnDais", Vector3.new(26, 1.2, 26), CFrame.new(0, FLOOR_Y + 0.6, 0), Color3.fromRGB(190, 195, 205), Enum.Material.Marble)
	local spawnCylinder = Instance.new("CylinderMesh")
	spawnCylinder.Parent = spawnDais

	-- Central fountain basin
	local fountainBasin = makePart(hub, "FountainBasin", Vector3.new(14, 2.5, 14), CFrame.new(0, FLOOR_Y + 1.8, 0), STONE_COLOR, Enum.Material.Cobblestone)
	local basinMesh = Instance.new("CylinderMesh")
	basinMesh.Parent = fountainBasin

	-- Fountain water
	local water = makePart(hub, "FountainWater", Vector3.new(12, 0.4, 12), CFrame.new(0, FLOOR_Y + 2.8, 0), Color3.fromRGB(50, 140, 220), Enum.Material.Glass)
	water.Transparency = 0.3
	local waterMesh = Instance.new("CylinderMesh")
	waterMesh.Parent = water

	-- Central Spire — sculpted dragon statue
	cloneAsset(hub, "FountainDragonStatue", CFrame.new(0, FLOOR_Y + 2.8, 0))

	-- The official SpawnLocation Part
	local existingSpawn = workspace:FindFirstChild("SpawnLocation")
	if existingSpawn then
		existingSpawn:Destroy()
	end
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, FLOOR_Y + 1.2, 0)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Anchored = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = workspace

	-- ── 3. GRAND MYSTIC DUNGEON GATEWAY (RockhidePortal) ───────────────────────
	-- Located at the North edge of the plaza (Z = -58)
	local portalPos = Vector3.new(0, FLOOR_Y, -58)

	-- Raised stone dais with steps
	makePart(hub, "PortalDais", Vector3.new(34, 2, 22), CFrame.new(portalPos + Vector3.new(0, 1, 0)), DARK_STONE, Enum.Material.Cobblestone)
	makePart(hub, "PortalSteps", Vector3.new(24, 1, 6), CFrame.new(portalPos + Vector3.new(0, 0.5, 13)), STONE_COLOR, Enum.Material.Slate)

	-- Massive Runic Stone Pillars (Portal Frame)
	makePillar(hub, portalPos + Vector3.new(-10, 2, 0), 22, 4.5)
	makePillar(hub, portalPos + Vector3.new(10, 2, 0), 22, 4.5)

	-- Arch beam across the top, topped with a sculpted rune capstone
	local portalArch = makePart(hub, "PortalArch", Vector3.new(24, 4, 4), CFrame.new(portalPos + Vector3.new(0, 23, 0)), DARK_STONE, Enum.Material.Slate)
	cloneAsset(hub, "PortalArchCapstone", CFrame.new(portalPos + Vector3.new(0, 25.5, 0)))

	-- Glowing Rune Inscriptions on the pillars
	local runeL = makePart(hub, "RuneLeft", Vector3.new(0.4, 12, 1.2), CFrame.new(portalPos + Vector3.new(-7.8, 12, 0)), PORTAL_COLOR, Enum.Material.Neon)
	runeL.CanCollide = false
	local runeR = makePart(hub, "RuneRight", Vector3.new(0.4, 12, 1.2), CFrame.new(portalPos + Vector3.new(7.8, 12, 0)), PORTAL_COLOR, Enum.Material.Neon)
	runeR.CanCollide = false

	-- The Active RockhidePortal Part (Target of ProximityPrompt)
	local existingPortal = workspace:FindFirstChild("RockhidePortal")
	if existingPortal then
		existingPortal:Destroy()
	end

	local portalCore = Instance.new("Part")
	portalCore.Name = "RockhidePortal"
	portalCore.Size = Vector3.new(16, 18, 1.5)
	portalCore.CFrame = CFrame.new(portalPos + Vector3.new(0, 11, 0))
	portalCore.Color = PORTAL_COLOR
	portalCore.Material = Enum.Material.Neon
	portalCore.Transparency = 0.35
	portalCore.Anchored = true
	portalCore.CanCollide = false
	portalCore.Parent = workspace

	-- Portal Particle Vortex
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 180, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 120, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 80, 255)),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	particles.Lifetime = NumberRange.new(1.2, 2.0)
	particles.Rate = 45
	particles.Speed = NumberRange.new(3, 8)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Parent = portalCore

	local portalLight = Instance.new("PointLight")
	portalLight.Color = PORTAL_COLOR
	portalLight.Brightness = 4
	portalLight.Range = 36
	portalLight.Shadows = true
	portalLight.Parent = portalCore

	-- Portal Nameplate / Banner
	local portalBb = Instance.new("BillboardGui")
	portalBb.Name = "PortalTitle"
	portalBb.Size = UDim2.new(0, 240, 0, 50)
	portalBb.StudsOffset = Vector3.new(0, 12, 0)
	portalBb.AlwaysOnTop = true
	portalBb.Parent = portalCore

	local pTitle = Instance.new("TextLabel")
	pTitle.Size = UDim2.new(1, 0, 0.6, 0)
	pTitle.BackgroundTransparency = 1
	pTitle.TextColor3 = Color3.fromRGB(180, 220, 255)
	pTitle.Font = Enum.Font.GothamBlack
	pTitle.TextScaled = true
	pTitle.Text = "ROCKHIDE'S DUNGEON"
	pTitle.Parent = portalBb

	local pSub = Instance.new("TextLabel")
	pSub.Size = UDim2.new(1, 0, 0.38, 0)
	pSub.Position = UDim2.new(0, 0, 0.62, 0)
	pSub.BackgroundTransparency = 1
	pSub.TextColor3 = Color3.fromRGB(240, 200, 100)
	pSub.Font = Enum.Font.GothamBold
	pSub.TextScaled = true
	pSub.Text = "[Party Level 1-5 Dungeon]"
	pSub.Parent = portalBb

	-- Flanking Braziers with blue mystic flames
	makeBrazier(hub, portalPos + Vector3.new(-15, 2, 4), Color3.fromRGB(80, 150, 255))
	makeBrazier(hub, portalPos + Vector3.new(15, 2, 4), Color3.fromRGB(80, 150, 255))

	-- Flanking stone guardian statues (south side of the pillars, facing the
	-- spawn/plaza approach — their sculpted front faces +Z by default)
	cloneAsset(hub, "PortalGuardianStatue", CFrame.new(portalPos + Vector3.new(-10, 2, 6)))
	cloneAsset(hub, "PortalGuardianStatue", CFrame.new(portalPos + Vector3.new(10, 2, 6)))

	-- ── 4. ANCIENT CELESTIAL LEVEL-UP SHRINE (LevelUpShrine) ───────────────────
	-- Located at the East wing of the plaza (X = 58, Z = 0)
	local shrinePos = Vector3.new(58, FLOOR_Y, 0)

	-- Circular stone dais
	local shrineDais = makePart(hub, "ShrineDais", Vector3.new(28, 2, 28), CFrame.new(shrinePos + Vector3.new(0, 1, 0)), DARK_STONE, Enum.Material.Cobblestone)
	local daisMesh = Instance.new("CylinderMesh")
	daisMesh.Parent = shrineDais

	-- Inner gold circle
	local shrineGold = makePart(hub, "ShrineRing", Vector3.new(20, 2.1, 20), CFrame.new(shrinePos + Vector3.new(0, 1, 0)), GOLD_TRIM, Enum.Material.Metal)
	local goldMesh = Instance.new("CylinderMesh")
	goldMesh.Parent = shrineGold

	-- 4 Stone Obelisks surrounding the shrine
	for angle = 45, 315, 90 do
		local rad = math.rad(angle)
		local ox = shrinePos.X + math.cos(rad) * 11
		local oz = shrinePos.Z + math.sin(rad) * 11
		makePillar(hub, Vector3.new(ox, FLOOR_Y + 2, oz), 12, 2.8)
		makePart(hub, "ObeliskRune", Vector3.new(0.8, 6, 0.8), CFrame.new(ox, FLOOR_Y + 8, oz), SHRINE_COLOR, Enum.Material.Neon)
	end

	-- Carved Central Altar
	local altarBase = makePart(hub, "AltarBase", Vector3.new(4.5, 3.5, 4.5), CFrame.new(shrinePos + Vector3.new(0, 3.75, 0)), DARK_STONE, Enum.Material.Slate)

	-- The Active LevelUpShrine Part (Target of ProximityPrompt)
	local existingShrine = workspace:FindFirstChild("LevelUpShrine")
	if existingShrine then
		existingShrine:Destroy()
	end

	local shrineCrystal = Instance.new("Part")
	shrineCrystal.Name = "LevelUpShrine"
	shrineCrystal.Size = Vector3.new(2.8, 5.0, 2.8)
	shrineCrystal.CFrame = CFrame.new(shrinePos + Vector3.new(0, 7.5, 0))
	shrineCrystal.Color = SHRINE_COLOR
	shrineCrystal.Material = Enum.Material.Neon
	shrineCrystal.Anchored = true
	shrineCrystal.CanCollide = false

	local crystalMesh = Instance.new("SpecialMesh")
	crystalMesh.MeshType = Enum.MeshType.Sphere
	crystalMesh.Scale = Vector3.new(0.8, 1.6, 0.8)
	crystalMesh.Parent = shrineCrystal
	shrineCrystal.Parent = workspace

	local shrineLight = Instance.new("PointLight")
	shrineLight.Color = SHRINE_COLOR
	shrineLight.Brightness = 3.5
	shrineLight.Range = 28
	shrineLight.Shadows = true
	shrineLight.Parent = shrineCrystal

	-- Shrine Sparkles
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 240, 140)
	sparkles.Parent = shrineCrystal

	-- Carved seraph idol floating above the crystal
	cloneAsset(hub, "ShrineSeraphIdol", CFrame.new(shrinePos + Vector3.new(0, 12, 0)))

	-- Shrine Title Billboard
	local shrineBb = Instance.new("BillboardGui")
	shrineBb.Name = "ShrineTitle"
	shrineBb.Size = UDim2.new(0, 220, 0, 50)
	shrineBb.StudsOffset = Vector3.new(0, 4.5, 0)
	shrineBb.AlwaysOnTop = true
	shrineBb.Parent = shrineCrystal

	local sTitle = Instance.new("TextLabel")
	sTitle.Size = UDim2.new(1, 0, 0.6, 0)
	sTitle.BackgroundTransparency = 1
	sTitle.TextColor3 = Color3.fromRGB(255, 230, 100)
	sTitle.Font = Enum.Font.GothamBlack
	sTitle.TextScaled = true
	sTitle.Text = "SHRINE OF ASCENSION"
	sTitle.Parent = shrineBb

	local sSub = Instance.new("TextLabel")
	sSub.Size = UDim2.new(1, 0, 0.38, 0)
	sSub.Position = UDim2.new(0, 0, 0.62, 0)
	sSub.BackgroundTransparency = 1
	sSub.TextColor3 = Color3.fromRGB(200, 255, 200)
	sSub.Font = Enum.Font.GothamBold
	sSub.TextScaled = true
	sSub.Text = "[Spend EXP to Level Up]"
	sSub.Parent = shrineBb

	-- ── 5. COMBAT TRAINING GROUNDS (Target Dummies) ───────────────────────────
	-- Located at the West wing of the plaza (X = -58, Z = 0)
	local trainingPos = Vector3.new(-58, FLOOR_Y, 0)
	local yardWidth = 36
	local yardLength = 46

	-- Dirt/Gravel Ground
	makePart(hub, "TrainingGround", Vector3.new(yardWidth, 2.1, yardLength),
		CFrame.new(trainingPos + Vector3.new(0, 0.05, 0)), Color3.fromRGB(105, 88, 68), Enum.Material.Ground)

	-- Wooden Fence Perimeter
	for z = -yardLength/2 + 3, yardLength/2 - 3, 8 do
		makePart(hub, "FencePostW", Vector3.new(1, 4.5, 1), CFrame.new(trainingPos + Vector3.new(-yardWidth/2, 2.2, z)), DARK_WOOD, Enum.Material.Wood)
		makePart(hub, "FenceRailW", Vector3.new(0.6, 0.6, 8), CFrame.new(trainingPos + Vector3.new(-yardWidth/2, 3.2, z)), WOOD_COLOR, Enum.Material.Wood)
	end
	for x = -yardWidth/2 + 3, yardWidth/2 - 3, 8 do
		makePart(hub, "FencePostN", Vector3.new(1, 4.5, 1), CFrame.new(trainingPos + Vector3.new(x, 2.2, -yardLength/2)), DARK_WOOD, Enum.Material.Wood)
		makePart(hub, "FenceRailN", Vector3.new(8, 0.6, 0.6), CFrame.new(trainingPos + Vector3.new(x, 3.2, -yardLength/2)), WOOD_COLOR, Enum.Material.Wood)
		makePart(hub, "FencePostS", Vector3.new(1, 4.5, 1), CFrame.new(trainingPos + Vector3.new(x, 2.2, yardLength/2)), DARK_WOOD, Enum.Material.Wood)
		makePart(hub, "FenceRailS", Vector3.new(8, 0.6, 0.6), CFrame.new(trainingPos + Vector3.new(x, 3.2, yardLength/2)), WOOD_COLOR, Enum.Material.Wood)
	end

	-- Weapon Racks in Training Yard
	local rack1 = makePart(hub, "WeaponRack", Vector3.new(6, 4, 1.2), CFrame.new(trainingPos + Vector3.new(-12, 2, -18)), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "RackSword", Vector3.new(0.3, 3.2, 0.5), CFrame.new(trainingPos + Vector3.new(-12, 2.2, -17.2)), Color3.fromRGB(220, 225, 235), Enum.Material.Metal)

	-- 2 Interactive Training Dummies (Registered in CombatService!)
	makeTrainingDummy(hub, "TrainingDummy_1", trainingPos + Vector3.new(-5, 0, -6))
	makeTrainingDummy(hub, "TrainingDummy_2", trainingPos + Vector3.new(5, 0, 6))

	-- ── 6. ADVENTURERS' TAVERN & GUILD HALL (South-West) ──────────────────────
	-- Located at X = -45, Z = 45
	local tavernPos = Vector3.new(-45, FLOOR_Y, 45)
	local tavernW, tavernL, tavernH = 34, 28, 18

	-- Tavern Foundation & Walls
	makePart(hub, "TavernFoundation", Vector3.new(tavernW, 3, tavernL), CFrame.new(tavernPos + Vector3.new(0, 1.5, 0)), STONE_COLOR, Enum.Material.Cobblestone)
	makePart(hub, "TavernWalls", Vector3.new(tavernW - 2, tavernH - 3, tavernL - 2), CFrame.new(tavernPos + Vector3.new(0, tavernH/2 + 1.5, 0)), Color3.fromRGB(150, 135, 115), Enum.Material.WoodPlanks)

	-- Timber Framing Beams
	makePart(hub, "TavernBeam_Corner1", Vector3.new(2, tavernH, 2), CFrame.new(tavernPos + Vector3.new(-tavernW/2 + 1, tavernH/2, -tavernL/2 + 1)), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "TavernBeam_Corner2", Vector3.new(2, tavernH, 2), CFrame.new(tavernPos + Vector3.new(tavernW/2 - 1, tavernH/2, -tavernL/2 + 1)), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "TavernBeam_Corner3", Vector3.new(2, tavernH, 2), CFrame.new(tavernPos + Vector3.new(-tavernW/2 + 1, tavernH/2, tavernL/2 - 1)), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "TavernBeam_Corner4", Vector3.new(2, tavernH, 2), CFrame.new(tavernPos + Vector3.new(tavernW/2 - 1, tavernH/2, tavernL/2 - 1)), DARK_WOOD, Enum.Material.Wood)

	-- Tiled Roof (A-frame peak)
	makePart(hub, "TavernRoof", Vector3.new(tavernW + 4, 3, tavernL + 4), CFrame.new(tavernPos + Vector3.new(0, tavernH + 1.5, 0)), ROOF_COLOR, Enum.Material.Slate)

	-- Glowing Warm Windows
	local win1 = makePart(hub, "TavernWindow1", Vector3.new(4, 3, 0.4), CFrame.new(tavernPos + Vector3.new(-8, 8, -tavernL/2)), Color3.fromRGB(255, 210, 120), Enum.Material.Neon)
	win1.CanCollide = false
	local win2 = makePart(hub, "TavernWindow2", Vector3.new(4, 3, 0.4), CFrame.new(tavernPos + Vector3.new(8, 8, -tavernL/2)), Color3.fromRGB(255, 210, 120), Enum.Material.Neon)
	win2.CanCollide = false

	-- Sculpted hanging tavern sign
	cloneAsset(hub, "TavernHangingSign", CFrame.new(tavernPos + Vector3.new(tavernW/2 + 2, 5.5, -tavernL/2 + 4)))

	-- ── 7. BLACKSMITH FORGE & ARMORY (South-East) ──────────────────────────────
	-- Located at X = 45, Z = 45
	local forgePos = Vector3.new(45, FLOOR_Y, 45)
	local forgeW, forgeL = 30, 26

	-- Stone Forge Foundation
	makePart(hub, "ForgeFloor", Vector3.new(forgeW, 1.5, forgeL), CFrame.new(forgePos + Vector3.new(0, 0.75, 0)), DARK_STONE, Enum.Material.Cobblestone)

	-- Open Timber Roof Posts
	makePillar(hub, forgePos + Vector3.new(-forgeW/2 + 2, 1, -forgeL/2 + 2), 12, 2.5)
	makePillar(hub, forgePos + Vector3.new(forgeW/2 - 2, 1, -forgeL/2 + 2), 12, 2.5)
	makePillar(hub, forgePos + Vector3.new(-forgeW/2 + 2, 1, forgeL/2 - 2), 12, 2.5)
	makePillar(hub, forgePos + Vector3.new(forgeW/2 - 2, 1, forgeL/2 - 2), 12, 2.5)

	-- Forge Canopy Roof
	makePart(hub, "ForgeRoof", Vector3.new(forgeW + 2, 2, forgeL + 2), CFrame.new(forgePos + Vector3.new(0, 14, 0)), ROOF_COLOR, Enum.Material.Slate)

	-- Stone Chimney Furnace
	makePart(hub, "FurnaceChimney", Vector3.new(6, 18, 6), CFrame.new(forgePos + Vector3.new(8, 9, 8)), DARK_STONE, Enum.Material.Cobblestone)
	local furnaceCore = makePart(hub, "FurnaceFire", Vector3.new(3.5, 2.5, 3.5), CFrame.new(forgePos + Vector3.new(8, 3, 6.5)), Color3.fromRGB(255, 120, 20), Enum.Material.Neon)
	furnaceCore.CanCollide = false

	local fFire = Instance.new("Fire")
	fFire.Size = 4
	fFire.Heat = 6
	fFire.Color = Color3.fromRGB(255, 130, 20)
	fFire.Parent = furnaceCore

	local fLight = Instance.new("PointLight")
	fLight.Color = Color3.fromRGB(255, 140, 30)
	fLight.Brightness = 3
	fLight.Range = 24
	fLight.Parent = furnaceCore

	-- Sculpted anvil and hammer
	cloneAsset(hub, "ForgeAnvilHammer", CFrame.new(forgePos + Vector3.new(-2, 2, 2)))

	-- Sculpted display shield
	cloneAsset(hub, "ForgeDisplayShield", CFrame.new(forgePos + Vector3.new(-10, 4, 10)) * CFrame.Angles(0, math.rad(45), 0))

	-- ── 8. TOWN WATCHTOWERS & BATTLEMENT GATEWAY (South) ───────────────────────
	local gatePos = Vector3.new(0, FLOOR_Y, 72)
	-- Twin Grand Guard Towers
	makePillar(hub, gatePos + Vector3.new(-14, 0, 0), 24, 6)
	makePillar(hub, gatePos + Vector3.new(14, 0, 0), 24, 6)
	-- Tower Tops / Battlements
	makePart(hub, "TowerCapL", Vector3.new(8, 3, 8), CFrame.new(gatePos + Vector3.new(-14, 25.5, 0)), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "TowerCapR", Vector3.new(8, 3, 8), CFrame.new(gatePos + Vector3.new(14, 25.5, 0)), DARK_STONE, Enum.Material.Slate)
	-- Gatehouse Arch
	makePart(hub, "GatehouseArch", Vector3.new(24, 4, 4), CFrame.new(gatePos + Vector3.new(0, 18, 0)), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "PortcullisBar", Vector3.new(20, 0.8, 0.8), CFrame.new(gatePos + Vector3.new(0, 14, 0)), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)

	-- Wall Braziers on the towers
	makeBrazier(hub, gatePos + Vector3.new(-14, 27, 0), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, gatePos + Vector3.new(14, 27, 0), Color3.fromRGB(255, 140, 30))

	-- Heraldry banners hanging from the tower battlements
	cloneAsset(hub, "WatchtowerBanner", CFrame.new(gatePos + Vector3.new(-14, 19, 4)))
	cloneAsset(hub, "WatchtowerBanner", CFrame.new(gatePos + Vector3.new(14, 19, 4)))

	-- ── 9. STREET LAMPS AROUND THE PLAZA ───────────────────────────────────────
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(-50, FLOOR_Y, -30))
	makeStreetLamp(hub, Vector3.new(50, FLOOR_Y, -30))

	-- ── 10. PLAZA GREENERY & CLUTTER ────────────────────────────────────────────
	-- Trees in the open plaza corners, away from building footprints
	cloneAsset(hub, "PlazaTree1", CFrame.new(-70, FLOOR_Y, -35))
	cloneAsset(hub, "PlazaTree1", CFrame.new(70, FLOOR_Y, -35) * CFrame.Angles(0, math.pi, 0))
	cloneAsset(hub, "PlazaTree2", CFrame.new(-30, FLOOR_Y, 68))
	cloneAsset(hub, "PlazaTree2", CFrame.new(30, FLOOR_Y, 68) * CFrame.Angles(0, math.pi, 0))

	-- Shrubs lining the cross paths
	cloneAsset(hub, "PlazaShrub", CFrame.new(11, FLOOR_Y, -40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(-11, FLOOR_Y, -40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(11, FLOOR_Y, 40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(-11, FLOOR_Y, 40))
	cloneAsset(hub, "PlazaShrub", CFrame.new(40, FLOOR_Y, 11))
	cloneAsset(hub, "PlazaShrub", CFrame.new(-40, FLOOR_Y, 11))

	-- Crates and barrels clustered near the tavern and forge
	cloneAsset(hub, "SupplyCrate", CFrame.new(tavernPos + Vector3.new(-16, 0, 12)))
	cloneAsset(hub, "SupplyCrate", CFrame.new(tavernPos + Vector3.new(-14, 0, 14)) * CFrame.Angles(0, math.rad(20), 0))
	cloneAsset(hub, "SupplyCrate", CFrame.new(forgePos + Vector3.new(14, 0, -10)))
	cloneAsset(hub, "SupplyCrate", CFrame.new(forgePos + Vector3.new(12, 0, -12)) * CFrame.Angles(0, math.rad(-15), 0))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(tavernPos + Vector3.new(-17, 0, 15)))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(tavernPos + Vector3.new(-13, 0, 16)))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(forgePos + Vector3.new(15, 0, -13)))
	cloneAsset(hub, "SupplyBarrel", CFrame.new(forgePos + Vector3.new(11, 0, -15)))

	hub.Parent = workspace
	return hub
end

function HubMapService.Cleanup()
	if hubFolder and hubFolder.Parent then
		hubFolder:Destroy()
	end
	hubFolder = nil
end

return HubMapService
