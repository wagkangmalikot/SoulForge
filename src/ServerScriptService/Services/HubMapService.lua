-- src/ServerScriptService/Services/HubMapService.lua
-- Generates and manages the Grand MMO Hub Sanctuary (Soulforge Outpost):
-- Features an expansive cobblestone town square, grand mystic dungeon portal with swirling runes,
-- ancient celestial Level-Up Shrine with orbital rings, combat training grounds with interactive target dummies & archery targets,
-- an Adventurers' Tavern with outdoor patio & tankards, Blacksmith Forge with working furnace, bellows & realistic anvil,
-- towering defensive fortress perimeter walls with authentic crenellated battlements & 4 corner bastion towers,
-- a grand South Gatehouse with iron chains, spiked portcullis & drawbridge leading to an alpine Mountain Overlook Vista with a brass telescope,
-- surrounding mountain peaks and pine forests, and atmospheric cinematic lighting.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local CombatService = require(script.Parent.CombatService)
local Net = require(ReplicatedStorage.Shared.Net)

local Assets = ReplicatedStorage:FindFirstChild("Assets")

local HubMapService = {}

local hubFolder: Model? = nil

-- Palette Constants
local STONE_COLOR    = Color3.fromRGB(80, 83, 88)
local DARK_STONE     = Color3.fromRGB(48, 50, 54)
local WALL_STONE     = Color3.fromRGB(68, 72, 78)
local PAVING_COLOR   = Color3.fromRGB(115, 118, 122)
local PATH_COLOR     = Color3.fromRGB(88, 90, 96)
local WOOD_COLOR     = Color3.fromRGB(92, 62, 42)
local DARK_WOOD      = Color3.fromRGB(52, 36, 24)
local GOLD_TRIM      = Color3.fromRGB(225, 185, 60)
local ROOF_COLOR     = Color3.fromRGB(145, 55, 45)
local PORTAL_COLOR   = Color3.fromRGB(80, 140, 255)
local SHRINE_COLOR   = Color3.fromRGB(255, 215, 75)
local IRON_COLOR     = Color3.fromRGB(55, 58, 65)
local BRASS_COLOR    = Color3.fromRGB(195, 155, 65)

-- ── PROCEDURAL GEOMETRY & MESH HELPERS ──────────────────────────────────────

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, canCollide: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = (canCollide ~= false)
	part.Parent = parent
	return part
end

local function addMesh(part: BasePart, meshType: Enum.MeshType, scale: Vector3?, offset: Vector3?): SpecialMesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshType
	if scale then
		mesh.Scale = scale
	end
	if offset then
		mesh.Offset = offset
	end
	mesh.Parent = part
	return mesh
end

-- Constructs an upright vertical cylinder with exact diameter and height.
local function makeCylinder(parent: Instance, name: string, diameter: number, height: number, cframe: CFrame, color: Color3, material: Enum.Material, canCollide: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = (canCollide ~= false)
	part.Parent = parent
	return part
end

local function makeWedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material
	wedge.Anchored = true
	wedge.CanCollide = true
	wedge.Parent = parent
	return wedge
end

-- Constructs an authentic Romanesque/Gothic fluted stone column with sculpted torus base and carved capital
local function makeColumn(parent: Instance, position: Vector3, height: number, radius: number, isDark: boolean?)
	local stoneCol = if isDark then DARK_STONE else STONE_COLOR
	local trimCol = if isDark then Color3.fromRGB(38, 40, 44) else DARK_STONE
	local d = radius * 2

	-- 1. Stepped Plinth Base
	makePart(parent, "ColPlinthLower", Vector3.new(d + 1.4, 0.6, d + 1.4), CFrame.new(position + Vector3.new(0, 0.3, 0)), trimCol, Enum.Material.Slate)
	makePart(parent, "ColPlinthUpper", Vector3.new(d + 1.0, 0.5, d + 1.0), CFrame.new(position + Vector3.new(0, 0.85, 0)), stoneCol, Enum.Material.Slate)

	-- 2. Torus Base Molding (squashed sphere mesh)
	local torus = makePart(parent, "ColTorusBase", Vector3.new(d + 0.8, 0.5, d + 0.8), CFrame.new(position + Vector3.new(0, 1.35, 0)), trimCol, Enum.Material.Slate, false)
	addMesh(torus, Enum.MeshType.Sphere, Vector3.new(1.0, 0.7, 1.0))

	-- 3. Fluted Column Shaft
	local shaftH = height - 2.8
	local shaft = makeCylinder(parent, "ColShaft", d, shaftH, CFrame.new(position + Vector3.new(0, 1.6 + shaftH / 2, 0)), stoneCol, Enum.Material.Cobblestone)
	
	-- Fluting collar rings along shaft
	local collarBottom = makePart(parent, "ColCollarB", Vector3.new(d + 0.3, 0.3, d + 0.3), CFrame.new(position + Vector3.new(0, 1.8, 0)), trimCol, Enum.Material.Slate, false)
	addMesh(collarBottom, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))
	local collarTop = makePart(parent, "ColCollarT", Vector3.new(d + 0.3, 0.3, d + 0.3), CFrame.new(position + Vector3.new(0, height - 1.4, 0)), trimCol, Enum.Material.Slate, false)
	addMesh(collarTop, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))

	-- 4. Carved Capital
	local capitalNeck = makePart(parent, "ColCapNeck", Vector3.new(d + 0.6, 0.5, d + 0.6), CFrame.new(position + Vector3.new(0, height - 0.95, 0)), trimCol, Enum.Material.Slate, false)
	addMesh(capitalNeck, Enum.MeshType.Sphere, Vector3.new(1.0, 0.8, 1.0))

	local capitalAbacus = makePart(parent, "ColCapAbacus", Vector3.new(d + 1.2, 0.7, d + 1.2), CFrame.new(position + Vector3.new(0, height - 0.35, 0)), trimCol, Enum.Material.Slate)
end

local function makePillar(parent: Instance, position: Vector3, height: number, width: number)
	makeColumn(parent, position, height, width / 2)
end

-- Constructs a detailed Gothic Wrought-Iron Street Lamp with chamfered pedestal, curved bracket & carriage lantern
local function makeStreetLamp(parent: Instance, position: Vector3)
	-- Molded cast-iron pedestal base
	local baseOct = makePart(parent, "LampBase", Vector3.new(2.4, 1.2, 2.4), CFrame.new(position + Vector3.new(0, 0.6, 0)), DARK_STONE, Enum.Material.Metal)
	addMesh(baseOct, Enum.MeshType.Cylinder, Vector3.new(1.0, 0.8, 1.0))

	local baseCollar = makePart(parent, "LampBaseCollar", Vector3.new(1.8, 0.6, 1.8), CFrame.new(position + Vector3.new(0, 1.4, 0)), IRON_COLOR, Enum.Material.Metal)
	addMesh(baseCollar, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))

	-- Fluted dark oak / cast iron post
	makeCylinder(parent, "LampPost", 1.1, 9.5, CFrame.new(position + Vector3.new(0, 6.2, 0)), DARK_WOOD, Enum.Material.Wood)

	-- Brass decorative collar rings
	local midRing = makePart(parent, "LampMidRing", Vector3.new(1.4, 0.4, 1.4), CFrame.new(position + Vector3.new(0, 6.0, 0)), GOLD_TRIM, Enum.Material.Metal, false)
	addMesh(midRing, Enum.MeshType.Sphere, Vector3.new(1.0, 0.4, 1.0))

	-- Wrought iron scrolled bracket arm
	makePart(parent, "LampArmH", Vector3.new(0.5, 0.5, 2.2), CFrame.new(position + Vector3.new(0, 10.8, 0.9)), IRON_COLOR, Enum.Material.Metal, false)
	makePart(parent, "LampArmDiagonal", Vector3.new(0.4, 1.6, 0.4), CFrame.new(position + Vector3.new(0, 10.1, 0.6)) * CFrame.Angles(math.rad(45), 0, 0), IRON_COLOR, Enum.Material.Metal, false)

	local lanternPos = position + Vector3.new(0, 10.2, 1.8)

	-- Lantern Housing Base
	local lBase = makePart(parent, "LanternBase", Vector3.new(1.8, 0.35, 1.8), CFrame.new(lanternPos + Vector3.new(0, -1.0, 0)), IRON_COLOR, Enum.Material.Metal, false)
	addMesh(lBase, Enum.MeshType.Cylinder, Vector3.new(1.0, 1.0, 1.0))

	-- Beveled Glass Panes
	local glassCage = makePart(parent, "LanternGlass", Vector3.new(1.5, 2.0, 1.5), CFrame.new(lanternPos), Color3.fromRGB(255, 230, 170), Enum.Material.Glass, false)
	glassCage.Transparency = 0.35

	-- Corner Iron Ribs
	for _, ox in {-0.75, 0.75} do
		for _, oz in {-0.75, 0.75} do
			makePart(parent, "LanternRib", Vector3.new(0.18, 2.0, 0.18), CFrame.new(lanternPos + Vector3.new(ox, 0, oz)), IRON_COLOR, Enum.Material.Metal, false)
		end
	end

	-- Pyramidal Roof Cap with Spire
	local roofCap = makePart(parent, "LanternRoof", Vector3.new(2.0, 0.9, 2.0), CFrame.new(lanternPos + Vector3.new(0, 1.35, 0)), DARK_STONE, Enum.Material.Metal, false)
	addMesh(roofCap, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.0, 1.0))

	local finialOrb = makePart(parent, "LanternFinialOrb", Vector3.new(0.5, 0.5, 0.5), CFrame.new(lanternPos + Vector3.new(0, 2.0, 0)), GOLD_TRIM, Enum.Material.Metal, false)
	addMesh(finialOrb, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))

	-- Glowing Mantle Core & Dynamic PointLight
	local lampCore = makePart(parent, "LampCore", Vector3.new(0.7, 1.1, 0.7), CFrame.new(lanternPos), Color3.fromRGB(255, 220, 140), Enum.Material.Neon, false)
	addMesh(lampCore, Enum.MeshType.Sphere, Vector3.new(0.8, 1.3, 0.8))

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Brightness = 1.2
	light.Range = 18
	light.Shadows = true
	light.Parent = lampCore
end

-- Constructs a Carved Stone Pedestal & Hammered Iron War Brazier with sculpted bowl mesh & ember bed
local function makeBrazier(parent: Instance, position: Vector3, flameColor: Color3)
	-- Molded stone pedestal
	makePart(parent, "BrazierPlinth", Vector3.new(3.2, 0.6, 3.2), CFrame.new(position + Vector3.new(0, 0.3, 0)), DARK_STONE, Enum.Material.Slate)
	local stem = makeCylinder(parent, "BrazierStem", 2.2, 2.0, CFrame.new(position + Vector3.new(0, 1.6, 0)), STONE_COLOR, Enum.Material.Cobblestone)
	local stemCollar = makePart(parent, "BrazierCollar", Vector3.new(2.8, 0.5, 2.8), CFrame.new(position + Vector3.new(0, 2.7, 0)), DARK_STONE, Enum.Material.Slate, false)
	addMesh(stemCollar, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))

	-- 4 Beast-Claw Support Brackets
	for angle = 0, 270, 90 do
		local rad = math.rad(angle)
		local bx = math.cos(rad) * 1.5
		local bz = math.sin(rad) * 1.5
		local claw = makePart(parent, "BrazierClaw", Vector3.new(0.4, 1.4, 0.4), CFrame.new(position + Vector3.new(bx, 3.1, bz)), IRON_COLOR, Enum.Material.Metal, false)
		claw.CFrame = CFrame.lookAt(claw.Position, position + Vector3.new(0, 3.1, 0)) * CFrame.Angles(math.rad(-25), 0, 0)
	end

	-- Hemispherical Hammered Iron Fire Bowl (using squashed sphere mesh)
	local bowl = makePart(parent, "BrazierBowl", Vector3.new(4.2, 1.8, 4.2), CFrame.new(position + Vector3.new(0, 3.6, 0)), Color3.fromRGB(38, 40, 45), Enum.Material.Metal)
	addMesh(bowl, Enum.MeshType.Sphere, Vector3.new(1.0, 0.7, 1.0))

	-- Spiked Crown Rim Collar
	local rim = makeCylinder(parent, "BrazierRim", 4.3, 0.35, CFrame.new(position + Vector3.new(0, 4.2, 0)), IRON_COLOR, Enum.Material.Metal, false)
	for angle = 22.5, 337.5, 45 do
		local rad = math.rad(angle)
		local px = math.cos(rad) * 2.1
		local pz = math.sin(rad) * 2.1
		local spike = makePart(parent, "RimSpike", Vector3.new(0.3, 0.6, 0.3), CFrame.new(position + Vector3.new(px, 4.5, pz)), IRON_COLOR, Enum.Material.Metal, false)
		addMesh(spike, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.2, 1.0))
	end

	-- Glowing Bed of Hot Embers
	local emberBed = makePart(parent, "BrazierEmbers", Vector3.new(3.2, 0.4, 3.2), CFrame.new(position + Vector3.new(0, 4.15, 0)), Color3.fromRGB(255, 90, 15), Enum.Material.Neon, false)
	addMesh(emberBed, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))

	-- Dynamic Fire Core & Flame Emitter
	local firePart = Instance.new("Part")
	firePart.Name = "BrazierFlame"
	firePart.Size = Vector3.new(1.8, 0.8, 1.8)
	firePart.CFrame = CFrame.new(position + Vector3.new(0, 4.5, 0))
	firePart.Color = flameColor
	firePart.Material = Enum.Material.Neon
	firePart.Anchored = true
	firePart.CanCollide = false
	firePart.Parent = parent

	local fire = Instance.new("Fire")
	fire.Size = 5.5
	fire.Heat = 7
	fire.Color = flameColor
	fire.SecondaryColor = Color3.fromRGB(255, 140, 40)
	fire.Parent = firePart

	local light = Instance.new("PointLight")
	light.Color = flameColor
	light.Brightness = 1.4
	light.Range = 18
	light.Shadows = true
	light.Parent = firePart

	-- Floating Sparkle Embers
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(flameColor, Color3.fromRGB(255, 220, 100))
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	embers.Lifetime = NumberRange.new(1.0, 1.8)
	embers.Rate = 16
	embers.Speed = NumberRange.new(3, 7)
	embers.SpreadAngle = Vector2.new(30, 30)
	embers.Parent = firePart
end

-- Constructs a Carved Griffin-Profile Stone Bench with contoured dark oak seat planks & brass rivet studs
local function makeStoneBench(parent: Instance, position: Vector3, yawAngle: number)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(yawAngle or 0), 0)

	-- Sculpted Stone Bench Standards (Legs with stepped plinth & chamfered profile)
	for _, lx in {-3.2, 3.2} do
		local legBase = makePart(parent, "BenchLegBase", Vector3.new(1.2, 0.4, 2.4), cf * CFrame.new(lx, 0.2, 0), DARK_STONE, Enum.Material.Slate)
		local legPillar = makePart(parent, "BenchLegPillar", Vector3.new(1.0, 1.2, 1.8), cf * CFrame.new(lx, 0.9, 0), STONE_COLOR, Enum.Material.Cobblestone)
		addMesh(legPillar, Enum.MeshType.Cylinder, Vector3.new(1.0, 1.0, 1.0))
		local legCap = makePart(parent, "BenchLegCap", Vector3.new(1.3, 0.35, 2.2), cf * CFrame.new(lx, 1.5, 0), DARK_STONE, Enum.Material.Slate)
	end

	-- Contoured Dark Oak Wooden Seat Planks with rounded bullnose edges
	local seat = makePart(parent, "BenchSeat", Vector3.new(8.0, 0.35, 2.1), cf * CFrame.new(0, 1.7, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	
	-- Front Bullnose Rounded Edge
	local bullnose = makePart(parent, "BenchBullnose", Vector3.new(8.0, 0.35, 0.35), cf * CFrame.new(0, 1.7, 1.05), DARK_WOOD, Enum.Material.Wood, false)
	addMesh(bullnose, Enum.MeshType.Cylinder, Vector3.new(1.0, 1.0, 1.0))

	-- Brass Rivet Studs along the seat
	for _, rx in {-3.5, -2.9, 2.9, 3.5} do
		for _, rz in {-0.7, 0.7} do
			local rivet = makePart(parent, "BenchRivet", Vector3.new(0.18, 0.1, 0.18), cf * CFrame.new(rx, 1.9, rz), BRASS_COLOR, Enum.Material.Metal, false)
			addMesh(rivet, Enum.MeshType.Sphere, Vector3.new(1.0, 0.6, 1.0))
		end
	end

	-- Carved Backrest Posts with Ornate Finials
	for _, px in {-3.0, 3.0} do
		makePart(parent, "BenchBackPost", Vector3.new(0.6, 2.4, 0.6), cf * CFrame.new(px, 2.8, -0.9), DARK_WOOD, Enum.Material.Wood)
		local finial = makePart(parent, "BenchFinial", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(px, 4.1, -0.9), BRASS_COLOR, Enum.Material.Metal, false)
		addMesh(finial, Enum.MeshType.Sphere, Vector3.new(1.0, 1.2, 1.0))
	end

	-- Dual Curved Backrest Wooden Planks
	makePart(parent, "BenchBackUpper", Vector3.new(7.6, 0.8, 0.35), cf * CFrame.new(0, 3.6, -0.9), WOOD_COLOR, Enum.Material.WoodPlanks)
	makePart(parent, "BenchBackLower", Vector3.new(7.6, 0.6, 0.35), cf * CFrame.new(0, 2.6, -0.9), WOOD_COLOR, Enum.Material.WoodPlanks)
end

-- Constructs a Classical Romanesque Sculpted Chalice Planter Urn with lush clustered shrubbery & blooming floral buds
local function makePlanterUrn(parent: Instance, position: Vector3)
	-- Molded Plinth Base
	makePart(parent, "UrnPlinth", Vector3.new(3.0, 0.4, 3.0), CFrame.new(position + Vector3.new(0, 0.2, 0)), DARK_STONE, Enum.Material.Slate)
	local footRing = makePart(parent, "UrnFoot", Vector3.new(2.6, 0.5, 2.6), CFrame.new(position + Vector3.new(0, 0.55, 0)), STONE_COLOR, Enum.Material.Slate, false)
	addMesh(footRing, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))

	-- Fluted Pedestal Stem
	makeCylinder(parent, "UrnStem", 1.8, 0.8, CFrame.new(position + Vector3.new(0, 1.0, 0)), DARK_STONE, Enum.Material.Cobblestone)

	-- Sculpted Chalice Bowl with flared scalloped rim
	local bowl = makePart(parent, "UrnBowlMesh", Vector3.new(3.8, 2.0, 3.8), CFrame.new(position + Vector3.new(0, 2.0, 0)), STONE_COLOR, Enum.Material.Cobblestone)
	addMesh(bowl, Enum.MeshType.Sphere, Vector3.new(1.0, 0.8, 1.0))

	local bowlLip = makePart(parent, "UrnLip", Vector3.new(4.2, 0.4, 4.2), CFrame.new(position + Vector3.new(0, 2.8, 0)), DARK_STONE, Enum.Material.Slate, false)
	addMesh(bowlLip, Enum.MeshType.Sphere, Vector3.new(1.0, 0.4, 1.0))

	-- Rich Earth Soil Bed
	local soil = makeCylinder(parent, "UrnSoil", 3.4, 0.2, CFrame.new(position + Vector3.new(0, 2.85, 0)), Color3.fromRGB(55, 42, 30), Enum.Material.Ground)

	-- Multi-Clustered Volumetric Foliage Shrub (SpecialMesh spheres clustered naturally)
	local leafCol = Color3.fromRGB(44, 98, 48)
	local shrubCenter = makePart(parent, "ShrubCenter", Vector3.new(3.6, 3.4, 3.6), CFrame.new(position + Vector3.new(0, 4.2, 0)), leafCol, Enum.Material.Grass, false)
	addMesh(shrubCenter, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))

	local shrubOffsets = {
		Vector3.new(-0.8, 0.3, 0.5), Vector3.new(0.8, 0.2, -0.6),
		Vector3.new(0.5, 0.4, 0.8),  Vector3.new(-0.6, 0.1, -0.7),
		Vector3.new(0, 0.8, 0)
	}
	for i, off in ipairs(shrubOffsets) do
		local cluster = makePart(parent, "ShrubCluster_" .. i, Vector3.new(2.4, 2.4, 2.4), CFrame.new(position + Vector3.new(0, 4.0, 0) + off), Color3.fromRGB(38 + i*4, 92 + i*3, 42 + i*2), Enum.Material.Grass, false)
		addMesh(cluster, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))
	end

	-- Blooming Floral Accents (Vibrant crimson & white blossoms)
	local flowerColors = { Color3.fromRGB(235, 60, 80), Color3.fromRGB(255, 240, 200), Color3.fromRGB(240, 90, 140) }
	for i = 1, 8 do
		local fAngle = (i / 8) * math.pi * 2
		local fx = math.cos(fAngle) * 1.6
		local fz = math.sin(fAngle) * 1.6
		local fy = 4.2 + (i % 3) * 0.4
		local flower = makePart(parent, "UrnFlower_" .. i, Vector3.new(0.45, 0.45, 0.45), CFrame.new(position + Vector3.new(fx, fy, fz)), flowerColors[(i % #flowerColors) + 1], Enum.Material.SmoothPlastic, false)
		addMesh(flower, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))
	end
end

-- Constructs a realistic Coopered Ale Barrel with authentic stave bulge curvature, iron hoops & tap spigot
local function makeBarrel(parent: Instance, position: Vector3, diameter: number, height: number)
	local cf = CFrame.new(position + Vector3.new(0, height / 2, 0))

	-- Bulging Wooden Stave Core (squashed sphere mesh gives natural barrel bulge!)
	local staveBody = makePart(parent, "BarrelStaves", Vector3.new(diameter * 1.08, height, diameter * 1.08), cf, DARK_WOOD, Enum.Material.WoodPlanks)
	addMesh(staveBody, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))

	-- Recessed Top & Bottom Chime Head Planks
	makeCylinder(parent, "BarrelHeadTop", diameter * 0.88, 0.25, cf * CFrame.new(0, height * 0.46, 0), WOOD_COLOR, Enum.Material.WoodPlanks)
	makeCylinder(parent, "BarrelHeadBottom", diameter * 0.88, 0.25, cf * CFrame.new(0, -height * 0.46, 0), WOOD_COLOR, Enum.Material.WoodPlanks)

	-- 4 Forged Iron Hoop Bands (Chime & Bilge Hoops)
	local hoopOffsets = { height * 0.42, height * 0.18, -height * 0.18, -height * 0.42 }
	local hoopRadii   = { diameter * 0.92, diameter * 1.06, diameter * 1.06, diameter * 0.92 }
	for i, yOff in ipairs(hoopOffsets) do
		local hoop = makeCylinder(parent, "BarrelHoop_" .. i, hoopRadii[i] + 0.08, 0.32, cf * CFrame.new(0, yOff, 0), IRON_COLOR, Enum.Material.Metal, false)
	end

	-- Oak Bung Stopper & Brass Spigot Tap
	local bung = makePart(parent, "BarrelBung", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(0, 0, diameter * 0.54), WOOD_COLOR, Enum.Material.Wood, false)
	addMesh(bung, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))

	local spigot = makePart(parent, "BarrelSpigot", Vector3.new(0.25, 0.25, 0.8), cf * CFrame.new(0, -height * 0.25, diameter * 0.52), BRASS_COLOR, Enum.Material.Metal, false)
end

-- Constructs a Heavy Chamfered Supply Crate with forged iron angle brackets, cross-braces & rivet meshes
local function makeCrate(parent: Instance, position: Vector3, size: Vector3, yaw: number?)
	local cf = CFrame.new(position + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0)

	-- Wooden Plank Core
	makePart(parent, "CrateBody", size, cf, WOOD_COLOR, Enum.Material.WoodPlanks)

	-- Iron Corner Edge Bands
	local bandThick = 0.35
	makePart(parent, "CrateBandTop", Vector3.new(size.X + 0.08, bandThick, size.Z + 0.08), cf * CFrame.new(0, size.Y / 2 - bandThick / 2, 0), IRON_COLOR, Enum.Material.Metal, false)
	makePart(parent, "CrateBandBottom", Vector3.new(size.X + 0.08, bandThick, size.Z + 0.08), cf * CFrame.new(0, -size.Y / 2 + bandThick / 2, 0), IRON_COLOR, Enum.Material.Metal, false)

	-- 8 Steel Corner Angle Brackets with Rivets
	for _, cx in {-1, 1} do
		for _, cy in {-1, 1} do
			for _, cz in {-1, 1} do
				local cornerCf = cf * CFrame.new(cx * (size.X / 2 - 0.2), cy * (size.Y / 2 - 0.2), cz * (size.Z / 2 - 0.2))
				local bracket = makePart(parent, "CrateBracket", Vector3.new(0.55, 0.55, 0.55), cornerCf, IRON_COLOR, Enum.Material.Metal, false)
				local rivet = makePart(parent, "CrateRivet", Vector3.new(0.2, 0.2, 0.2), cornerCf * CFrame.new(0, cy * 0.2, 0), BRASS_COLOR, Enum.Material.Metal, false)
				addMesh(rivet, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))
			end
		end
	end

	-- Diagonal Cross-Bracing on Top Face
	makePart(parent, "CrateDiagonalTop", Vector3.new(0.4, 0.15, size.Z * 1.1), cf * CFrame.new(0, size.Y / 2 + 0.08, 0) * CFrame.Angles(0, math.rad(45), 0), DARK_WOOD, Enum.Material.Wood, false)
end

-- Constructs an Alpine Pine Tree with layered pyramid needle foliage & pine cones
local function makePineTree(parent: Instance, position: Vector3, scale: number?)
	pcall(function()
		local s = scale or 1.0
		local trunkH = 8 * s
		local trunkW = 1.8 * s
		-- Fluted Wood Trunk
		makeCylinder(parent, "TreeTrunk", trunkW, trunkH, CFrame.new(position + Vector3.new(0, trunkH / 2, 0)), DARK_WOOD, Enum.Material.Wood)

		-- 4 Layered Pine Foliage Pyramids in graduated evergreen shades
		local leafColors = { Color3.fromRGB(32, 64, 38), Color3.fromRGB(40, 78, 46), Color3.fromRGB(48, 92, 55), Color3.fromRGB(56, 105, 64) }
		for i = 1, 4 do
			local layerH = (6.5 - (i - 1) * 0.9) * s
			local layerR = (9.5 - (i - 1) * 1.9) * s
			local yCenter = position.Y + trunkH * 0.55 + (i - 1) * 3.2 * s
			local foliage = makePart(parent, "PineFoliage_" .. i, Vector3.new(layerR * 2, layerH, layerR * 2), CFrame.new(position.X, yCenter, position.Z), leafColors[i], Enum.Material.Grass, false)
			addMesh(foliage, Enum.MeshType.Pyramid, Vector3.new(1, 1, 1))

			-- Hanging Pine Cone on lower branches
			if i <= 2 then
				local cone = makePart(parent, "PineCone_" .. i, Vector3.new(0.6 * s, 1.0 * s, 0.6 * s), CFrame.new(position.X + layerR * 0.6, yCenter - layerH * 0.4, position.Z + layerR * 0.4), DARK_WOOD, Enum.Material.Wood, false)
				addMesh(cone, Enum.MeshType.Sphere, Vector3.new(0.8, 1.4, 0.8))
			end
		end
	end)
end

-- ── BUILD TRAINING DUMMY WITH MESH HELMET, STRAW TORSO & HIT FEEDBACK ───────
local function makeTrainingDummy(parent: Instance, name: string, position: Vector3)
	local dummy = Instance.new("Model")
	dummy.Name = name

	-- Heavy Timber Cross-Stand Base
	local standCf = CFrame.new(position + Vector3.new(0, 0.25, 0))
	makePart(dummy, "StandBeam1", Vector3.new(4.5, 0.5, 0.8), standCf, DARK_WOOD, Enum.Material.Wood)
	makePart(dummy, "StandBeam2", Vector3.new(0.8, 0.5, 4.5), standCf, DARK_WOOD, Enum.Material.Wood)

	-- Center Post
	local pole = makePart(dummy, "Pole", Vector3.new(0.8, 6.2, 0.8), CFrame.new(position + Vector3.new(0, 3.2, 0)), DARK_WOOD, Enum.Material.Wood)
	pole.CanCollide = true

	-- Anatomical Straw Torso (Upper Chest + Cinched Waist + Leather Harness)
	local torso = makePart(dummy, "HumanoidRootPart", Vector3.new(2.4, 3.6, 1.6), CFrame.new(position + Vector3.new(0, 4.3, 0)), Color3.fromRGB(185, 165, 115), Enum.Material.Fabric)
	torso.CanCollide = true
	dummy.PrimaryPart = torso
	addMesh(torso, Enum.MeshType.Sphere, Vector3.new(1.0, 1.1, 0.9))

	-- Cinched Leather Waist Belt with Brass Buckle
	local belt = makePart(dummy, "DummyBelt", Vector3.new(2.3, 0.45, 1.6), CFrame.new(position + Vector3.new(0, 3.2, 0)), DARK_WOOD, Enum.Material.Fabric, false)
	local buckle = makePart(dummy, "DummyBuckle", Vector3.new(0.5, 0.55, 0.2), CFrame.new(position + Vector3.new(0, 3.2, 0.85)), BRASS_COLOR, Enum.Material.Metal, false)

	-- Cross-Body Leather Harness Straps
	makePart(dummy, "HarnessStrap1", Vector3.new(0.35, 3.2, 0.15), CFrame.new(position + Vector3.new(0, 4.4, 0.8)) * CFrame.Angles(0, 0, math.rad(28)), DARK_WOOD, Enum.Material.Fabric, false)
	makePart(dummy, "HarnessStrap2", Vector3.new(0.35, 3.2, 0.15), CFrame.new(position + Vector3.new(0, 4.4, 0.8)) * CFrame.Angles(0, 0, math.rad(-28)), DARK_WOOD, Enum.Material.Fabric, false)

	-- Sculpted Straw Burlap Sack Head with Top Tied Knot
	local head = makePart(dummy, "Head", Vector3.new(1.8, 2.0, 1.8), CFrame.new(position + Vector3.new(0, 6.7, 0)), Color3.fromRGB(195, 175, 125), Enum.Material.Fabric)
	head.CanCollide = true
	addMesh(head, Enum.MeshType.Sphere, Vector3.new(0.9, 1.05, 0.9))

	local headKnot = makePart(dummy, "HeadKnot", Vector3.new(0.6, 0.6, 0.6), CFrame.new(position + Vector3.new(0, 7.8, 0)), Color3.fromRGB(160, 140, 95), Enum.Material.Fabric, false)
	addMesh(headKnot, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))

	-- Domed Iron Kettle-Hat Helmet (Sphere Skullcap + Flattened Cylinder Brim)
	local helmDome = makePart(dummy, "HelmetDome", Vector3.new(2.1, 1.2, 2.1), CFrame.new(position + Vector3.new(0, 7.4, 0)), Color3.fromRGB(80, 85, 92), Enum.Material.Metal, false)
	addMesh(helmDome, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))

	local helmBrim = makeCylinder(dummy, "HelmetBrim", 2.7, 0.18, CFrame.new(position + Vector3.new(0, 7.0, 0)), Color3.fromRGB(70, 75, 82), Enum.Material.Metal, false)
	local helmNasal = makePart(dummy, "HelmetNasal", Vector3.new(0.3, 0.8, 0.2), CFrame.new(position + Vector3.new(0, 6.7, 1.0)), Color3.fromRGB(80, 85, 92), Enum.Material.Metal, false)

	-- Crossbeam Arms (Dark Timber)
	local crossbeam = makePart(dummy, "Crossbeam", Vector3.new(5.4, 0.6, 0.6), CFrame.new(position + Vector3.new(0, 4.8, 0)), DARK_WOOD, Enum.Material.Wood, false)

	-- Left Arm: Mounted Wooden Sparring Buckler Shield (Round with Iron Rim & Domed Boss)
	local shieldCf = CFrame.new(position + Vector3.new(-2.6, 4.8, 0.4))
	makeCylinder(dummy, "DummyShieldBody", 2.4, 0.25, shieldCf, DARK_WOOD, Enum.Material.WoodPlanks, false)
	makeCylinder(dummy, "DummyShieldRim", 2.5, 0.15, shieldCf, IRON_COLOR, Enum.Material.Metal, false)
	local shieldBoss = makePart(dummy, "DummyShieldBoss", Vector3.new(0.9, 0.9, 0.4), shieldCf * CFrame.new(0, 0, 0.2), IRON_COLOR, Enum.Material.Metal, false)
	addMesh(shieldBoss, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))

	-- Right Arm: Clutched Wooden Sparring Sword
	local swordCf = CFrame.new(position + Vector3.new(2.6, 5.0, 0.4)) * CFrame.Angles(math.rad(15), 0, math.rad(-20))
	makePart(dummy, "DummySwordBlade", Vector3.new(0.25, 2.8, 0.4), swordCf * CFrame.new(0, 0.8, 0), WOOD_COLOR, Enum.Material.Wood, false)
	makePart(dummy, "DummySwordGuard", Vector3.new(1.2, 0.2, 0.3), swordCf * CFrame.new(0, -0.6, 0), DARK_WOOD, Enum.Material.Wood, false)

	-- Welds
	local function weld(p0, p1)
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p0
	end
	weld(torso, pole)
	weld(torso, head)
	weld(torso, headKnot)
	weld(torso, belt)
	weld(torso, buckle)
	weld(torso, helmDome)
	weld(torso, helmBrim)
	weld(torso, helmNasal)
	weld(torso, crossbeam)
	weld(torso, shieldBoss)

	-- Straw Burst Hit Feedback Particle Emitter
	local chaffEmitter = Instance.new("ParticleEmitter")
	chaffEmitter.Name = "StrawChaff"
	chaffEmitter.Color = ColorSequence.new(Color3.fromRGB(210, 190, 130), Color3.fromRGB(160, 140, 90))
	chaffEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	chaffEmitter.Lifetime = NumberRange.new(0.4, 0.8)
	chaffEmitter.Rate = 0 -- Triggered in bursts
	chaffEmitter.Speed = NumberRange.new(4, 10)
	chaffEmitter.SpreadAngle = Vector2.new(60, 60)
	chaffEmitter.Parent = torso

	-- Floating Name / Health Billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "DummyInfo"
	bb.Size = UDim2.new(0, 140, 0, 44)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.5, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "Sparring Dummy"
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

	-- Register in CombatService so players can test normal attacks and skills!
	local dummyHandle = {
		model = dummy,
		currentHealth = 999999,
		maxHealth = 999999,
		onDamaged = function(amount: number, attackingPlayer: Player?)
			local defaultCFrame = CFrame.new(position + Vector3.new(0, 4.3, 0))
			local hitTilt = defaultCFrame * CFrame.Angles(math.rad(-16), 0, math.rad(math.random(-10, 10)))
			torso.CFrame = hitTilt

			-- Trigger Burst of Straw Chaff particles
			chaffEmitter:Emit(14)

			-- Floating damage indicator
			if attackingPlayer and head then
				local dmgPart = Instance.new("Part")
				dmgPart.Size = Vector3.new(0.1, 0.1, 0.1)
				dmgPart.Transparency = 1
				dmgPart.Anchored = true
				dmgPart.CanCollide = false
				dmgPart.CFrame = head.CFrame * CFrame.new(math.random(-1, 1), 1.6, math.random(-1, 1))
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

				local floatTween = TweenService:Create(dmgPart, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = dmgPart.CFrame + Vector3.new(0, 3.2, 0)
				})
				floatTween:Play()
				Debris:AddItem(dmgPart, 0.7)
			end

			task.delay(0.14, function()
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

-- ── BUILD ARCHERY TARGET WITH EMBEDDED ARROWS & BRAIDED STRAW MESH ──────────
local function makeArcheryTarget(parent: Instance, position: Vector3, yawAngle: number)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(yawAngle or 0), 0)

	-- Wooden Tripod Legs with chamfered timber
	makePart(parent, "TripodLegL", Vector3.new(0.4, 5.0, 0.4), cf * CFrame.new(-1.2, 2.3, -0.6) * CFrame.Angles(math.rad(15), 0, math.rad(-15)), DARK_WOOD, Enum.Material.Wood)
	makePart(parent, "TripodLegR", Vector3.new(0.4, 5.0, 0.4), cf * CFrame.new(1.2, 2.3, -0.6) * CFrame.Angles(math.rad(15), 0, math.rad(15)), DARK_WOOD, Enum.Material.Wood)
	makePart(parent, "TripodLegB", Vector3.new(0.4, 5.2, 0.4), cf * CFrame.new(0, 2.3, 1.2) * CFrame.Angles(math.rad(-25), 0, 0), DARK_WOOD, Enum.Material.Wood)

	-- Tied Hemp Rope Lashings at Apex
	local ropeLash = makePart(parent, "TripodRope", Vector3.new(0.9, 0.5, 0.9), cf * CFrame.new(0, 4.3, 0), Color3.fromRGB(150, 130, 90), Enum.Material.Fabric, false)
	addMesh(ropeLash, Enum.MeshType.Sphere, Vector3.new(1.0, 0.7, 1.0))

	-- Slanted Target Disc Mount
	local discCf = cf * CFrame.new(0, 4.0, 0) * CFrame.Angles(math.rad(-15), 0, 0)

	-- Braided Outer Straw Rim (squashed torus ring)
	local strawRim = makePart(parent, "TargetStrawRim", Vector3.new(4.2, 4.2, 0.6), discCf, Color3.fromRGB(175, 155, 105), Enum.Material.Fabric, false)
	addMesh(strawRim, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.6))

	-- Target Straw Disc Body
	makeCylinder(parent, "TargetStraw", 3.8, 0.5, discCf, Color3.fromRGB(195, 175, 125), Enum.Material.Fabric)

	-- Concentric Bullseye Rings
	makeCylinder(parent, "BullseyeOuter", 2.8, 0.52, discCf, Color3.fromRGB(215, 60, 50), Enum.Material.SmoothPlastic, false)
	makeCylinder(parent, "BullseyeMid", 1.8, 0.54, discCf, Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, false)
	makeCylinder(parent, "BullseyeCenter", 0.9, 0.56, discCf, Color3.fromRGB(225, 185, 45), Enum.Material.SmoothPlastic, false)

	-- 2 Realistic Embedded Wooden Arrows with Fletching Feathers
	local arrow1Cf = discCf * CFrame.new(0.3, 0.25, 0.3) * CFrame.Angles(math.rad(8), math.rad(-12), 0)
	makePart(parent, "Arrow1Shaft", Vector3.new(0.12, 0.12, 2.2), arrow1Cf * CFrame.new(0, 0, 1.1), WOOD_COLOR, Enum.Material.Wood, false)
	makePart(parent, "Arrow1Fletch", Vector3.new(0.35, 0.35, 0.5), arrow1Cf * CFrame.new(0, 0, 2.0), Color3.fromRGB(225, 50, 50), Enum.Material.Fabric, false)

	local arrow2Cf = discCf * CFrame.new(-0.7, -0.4, 0.3) * CFrame.Angles(math.rad(-14), math.rad(15), 0)
	makePart(parent, "Arrow2Shaft", Vector3.new(0.12, 0.12, 2.0), arrow2Cf * CFrame.new(0, 0, 1.0), WOOD_COLOR, Enum.Material.Wood, false)
	makePart(parent, "Arrow2Fletch", Vector3.new(0.35, 0.35, 0.5), arrow2Cf * CFrame.new(0, 0, 1.8), Color3.fromRGB(240, 240, 240), Enum.Material.Fabric, false)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN HUB CONSTRUCTION FUNCTION
-- ═══════════════════════════════════════════════════════════════════════════

function HubMapService.GetSpawnCFrame(): CFrame
	return CFrame.lookAt(Vector3.new(0, 3.0, 18), Vector3.new(0, 3.0, -58))
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
	hub.Parent = workspace

	local FLOOR_Y = 0

	-- ── 1. CENTRAL TOWN SQUARE PLAZA ──────────────────────────────────────────
	local plazaSize = 170
	makePart(hub, "Plaza_Floor", Vector3.new(plazaSize, 2, plazaSize),
		CFrame.new(0, FLOOR_Y - 1, 0), PAVING_COLOR, Enum.Material.Cobblestone)

	makePart(hub, "Plaza_FoundationSkirt", Vector3.new(plazaSize + 12, 10, plazaSize + 12),
		CFrame.new(0, FLOOR_Y - 7, 0), DARK_STONE, Enum.Material.Slate, true)

	-- Curbs around the town square
	makePart(hub, "Plaza_Curb_N", Vector3.new(plazaSize, 0.5, 3), CFrame.new(0, FLOOR_Y + 0.25, -plazaSize/2 + 1.5), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "Plaza_Curb_S", Vector3.new(plazaSize, 0.5, 3), CFrame.new(0, FLOOR_Y + 0.25, plazaSize/2 - 1.5), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "Plaza_Curb_E", Vector3.new(3, 0.5, plazaSize), CFrame.new(plazaSize/2 - 1.5, FLOOR_Y + 0.25, 0), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "Plaza_Curb_W", Vector3.new(3, 0.5, plazaSize), CFrame.new(-plazaSize/2 + 1.5, FLOOR_Y + 0.25, 0), DARK_STONE, Enum.Material.Slate)

	-- Wide inlaid flagstone crosswalk avenues connecting the 4 main districts
	makePart(hub, "Avenue_NorthSouth", Vector3.new(22, 0.05, plazaSize - 8), CFrame.new(0, FLOOR_Y + 0.025, 0), PATH_COLOR, Enum.Material.Slate)
	makePart(hub, "Avenue_EastWest", Vector3.new(plazaSize - 8, 0.05, 22), CFrame.new(0, FLOOR_Y + 0.025, 0), PATH_COLOR, Enum.Material.Slate)

	-- Concentric circular stone border
	makeCylinder(hub, "Plaza_CircleRing", 50, 0.06, CFrame.new(0, FLOOR_Y + 0.03, 0), DARK_STONE, Enum.Material.Slate, false)

	-- Inlaid 8-Point Celestial Compass Rose Mosaic in the Central Plaza
	for angle = 0, 315, 45 do
		local rad = math.rad(angle)
		local starRay = makePart(hub, "CompassRay_" .. angle, Vector3.new(1.2, 0.07, 18), CFrame.new(0, FLOOR_Y + 0.035, 0) * CFrame.Angles(0, rad, 0) * CFrame.new(0, 0, 10), GOLD_TRIM, Enum.Material.Metal, false)
		addMesh(starRay, Enum.MeshType.Wedge, Vector3.new(1.0, 1.0, 1.0))
	end

	-- ── 2. CENTRAL SANCTUARY FOUNTAIN & SPAWN LOCATION ────────────────────────
	-- Raised 2-tier marble dais
	makeCylinder(hub, "SpawnDais_BaseStep", 32, 0.35, CFrame.new(0, FLOOR_Y + 0.175, 0), DARK_STONE, Enum.Material.Slate)
	makeCylinder(hub, "SpawnDais_Marble", 28, 0.35, CFrame.new(0, FLOOR_Y + 0.525, 0), Color3.fromRGB(200, 205, 215), Enum.Material.Marble)
	makeCylinder(hub, "SpawnDais_GoldTrim", 28.4, 0.1, CFrame.new(0, FLOOR_Y + 0.72, 0), GOLD_TRIM, Enum.Material.Metal, false)

	-- Cascading Multi-Tier Fountain Basin
	local fountainBaseY = FLOOR_Y + 0.7
	-- Lower Basin
	local lowerCoping = makeCylinder(hub, "FountainBasinCoping", 17.2, 0.45, CFrame.new(0, fountainBaseY + 2.2, 0), DARK_STONE, Enum.Material.Slate)
	makeCylinder(hub, "FountainBasinWall", 15.6, 2.1, CFrame.new(0, fountainBaseY + 1.05, 0), STONE_COLOR, Enum.Material.Cobblestone)

	-- Beveled Rounded Lip on Lower Coping (squashed sphere torus ring)
	local copingLip = makePart(hub, "FountainCopingLip", Vector3.new(17.4, 0.4, 17.4), CFrame.new(0, fountainBaseY + 2.45, 0), DARK_STONE, Enum.Material.Slate, false)
	addMesh(copingLip, Enum.MeshType.Sphere, Vector3.new(1.0, 0.4, 1.0))

	-- Lower animated glass water surface
	local water = makeCylinder(hub, "FountainWater", 14.2, 0.2, CFrame.new(0, fountainBaseY + 1.9, 0), Color3.fromRGB(55, 160, 240), Enum.Material.Glass, false)
	water.Transparency = 0.32

	local waterLight = Instance.new("PointLight")
	waterLight.Color = Color3.fromRGB(75, 205, 255)
	waterLight.Brightness = 0.6
	waterLight.Range = 12
	waterLight.Parent = water

	-- Central Pedestal Column with 4 Sculpted Gargoyle Water Spouts
	makeColumn(hub, Vector3.new(0, fountainBaseY + 0.2, 0), 6.5, 2.0)

	-- 4 Sculpted Water Spouts
	for angle = 0, 270, 90 do
		local rad = math.rad(angle)
		local sx = math.cos(rad) * 2.1
		local sz = math.sin(rad) * 2.1
		local spout = makePart(hub, "GargoyleSpout_" .. angle, Vector3.new(0.6, 0.6, 1.2), CFrame.new(sx, fountainBaseY + 5.2, sz), DARK_STONE, Enum.Material.Slate, false)
		spout.CFrame = CFrame.lookAt(spout.Position, Vector3.new(sx * 2, fountainBaseY + 5.2, sz * 2))
		addMesh(spout, Enum.MeshType.Head, Vector3.new(0.8, 0.8, 1.2))

		-- Arc Water Stream Particle Emitter
		local spoutStream = Instance.new("ParticleEmitter")
		spoutStream.Color = ColorSequence.new(Color3.fromRGB(160, 225, 255))
		spoutStream.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 0.6),
		})
		spoutStream.Transparency = NumberSequence.new(0.2, 0.8)
		spoutStream.Lifetime = NumberRange.new(0.8, 1.2)
		spoutStream.Rate = 20
		spoutStream.Speed = NumberRange.new(3, 5)
		spoutStream.SpreadAngle = Vector2.new(10, 10)
		spoutStream.Parent = spout
	end

	-- Upper Cascading Basin (Raised Chalice)
	local upperChalice = makePart(hub, "UpperChaliceBowl", Vector3.new(7.6, 1.8, 7.6), CFrame.new(0, fountainBaseY + 6.8, 0), STONE_COLOR, Enum.Material.Cobblestone)
	addMesh(upperChalice, Enum.MeshType.Sphere, Vector3.new(1.0, 0.6, 1.0))
	makeCylinder(hub, "UpperChaliceWater", 6.8, 0.2, CFrame.new(0, fountainBaseY + 7.2, 0), Color3.fromRGB(60, 170, 250), Enum.Material.Glass, false)

	-- Central Spire Obelisk & Lotus Filigree Mount
	local upperSpire = makePart(hub, "FountainObelisk", Vector3.new(2.4, 4.5, 2.4), CFrame.new(0, fountainBaseY + 9.5, 0), DARK_STONE, Enum.Material.Slate)
	addMesh(upperSpire, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.4, 0.8))

	-- Gold Filigree Lotus Claws cradling the floating crystal
	for angle = 0, 300, 60 do
		local rad = math.rad(angle)
		local lx = math.cos(rad) * 1.3
		local lz = math.sin(rad) * 1.3
		local claw = makePart(hub, "LotusClaw_" .. angle, Vector3.new(0.3, 1.6, 0.3), CFrame.new(lx, fountainBaseY + 11.2, lz), GOLD_TRIM, Enum.Material.Metal, false)
		claw.CFrame = CFrame.lookAt(claw.Position, Vector3.new(0, fountainBaseY + 12.0, 0)) * CFrame.Angles(math.rad(25), 0, 0)
		addMesh(claw, Enum.MeshType.Head, Vector3.new(0.6, 1.4, 0.6))
	end

	-- Pulsating Floating Aquamarine Celestial Crystal
	local spireCrystal = makePart(hub, "FountainCrystal", Vector3.new(2.0, 3.4, 2.0), CFrame.new(0, fountainBaseY + 12.4, 0), Color3.fromRGB(90, 215, 255), Enum.Material.Neon, false)
	local crystalMesh = Instance.new("SpecialMesh")
	crystalMesh.MeshType = Enum.MeshType.Sphere
	crystalMesh.Scale = Vector3.new(0.75, 1.6, 0.75)
	crystalMesh.Parent = spireCrystal

	local crystalLight = Instance.new("PointLight")
	crystalLight.Color = Color3.fromRGB(100, 225, 255)
	crystalLight.Brightness = 1.0
	crystalLight.Range = 14
	crystalLight.Parent = spireCrystal

	-- Rotating Orbital Energy Rings around the Fountain Crystal (SmoothPlastic with transparency to avoid blinding neon glare)
	local ring1 = makePart(hub, "FountainOrbitalRing1", Vector3.new(3.8, 0.15, 3.8), CFrame.new(0, fountainBaseY + 12.4, 0), GOLD_TRIM, Enum.Material.SmoothPlastic, false)
	addMesh(ring1, Enum.MeshType.Sphere, Vector3.new(1.0, 0.12, 1.0))
	ring1.Transparency = 0.4

	local ring2 = makePart(hub, "FountainOrbitalRing2", Vector3.new(4.6, 0.15, 4.6), CFrame.new(0, fountainBaseY + 12.4, 0) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(120, 220, 255), Enum.Material.SmoothPlastic, false)
	addMesh(ring2, Enum.MeshType.Sphere, Vector3.new(1.0, 0.1, 1.0))
	ring2.Transparency = 0.5

	-- Floating crystal hover tween
	local fTween = TweenService:Create(
		spireCrystal,
		TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = CFrame.new(0, fountainBaseY + 13.1, 0) }
	)
	fTween:Play()

	-- Fountain Water Splash Particles
	local splashEmitter = Instance.new("ParticleEmitter")
	splashEmitter.Color = ColorSequence.new(Color3.fromRGB(190, 235, 255))
	splashEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	splashEmitter.Lifetime = NumberRange.new(0.8, 1.5)
	splashEmitter.Rate = 28
	splashEmitter.Speed = NumberRange.new(2, 5)
	splashEmitter.SpreadAngle = Vector2.new(40, 40)
	splashEmitter.Parent = spireCrystal

	-- Clean up stray SpawnLocations across workspace
	for _, desc in workspace:GetDescendants() do
		if desc:IsA("SpawnLocation") then
			desc:Destroy()
		end
	end

	-- Official Hub SpawnLocation
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(16, 0.2, 16)
	spawnLocation.CFrame = CFrame.lookAt(Vector3.new(0, FLOOR_Y + 0.1, 18), Vector3.new(0, FLOOR_Y + 0.1, -58))
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = true
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Enabled = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = hub

	-- 4 Sculpted Stone Benches around the central fountain plaza
	makeStoneBench(hub, Vector3.new(-18, FLOOR_Y, 0), 90)
	makeStoneBench(hub, Vector3.new(18, FLOOR_Y, 0), -90)
	makeStoneBench(hub, Vector3.new(0, FLOOR_Y, -18), 0)
	makeStoneBench(hub, Vector3.new(0, FLOOR_Y, 32), 180)

	-- 4 Sculpted Planter Urns at the fountain diagonal corners
	makePlanterUrn(hub, Vector3.new(-16, FLOOR_Y, -16))
	makePlanterUrn(hub, Vector3.new(16, FLOOR_Y, -16))
	makePlanterUrn(hub, Vector3.new(-16, FLOOR_Y, 26))
	makePlanterUrn(hub, Vector3.new(16, FLOOR_Y, 26))

	-- ── 3A. TIER 1 ROCKHIDE'S DUNGEON GATEWAY (RockhidePortal) ───────────────
	-- Positioned on the Northwest plaza (X = -28, Z = -58)
	local portalPos = Vector3.new(-28, FLOOR_Y, -58)

	-- Raised stone dais with molded steps
	makePart(hub, "PortalDais", Vector3.new(32, 2, 24), CFrame.new(portalPos + Vector3.new(0, 1, 0)), DARK_STONE, Enum.Material.Cobblestone)
	makePart(hub, "PortalSteps", Vector3.new(24, 1, 6), CFrame.new(portalPos + Vector3.new(0, 0.5, 13)), STONE_COLOR, Enum.Material.Slate)

	-- Massive Fluted Runic Stone Megaliths (Portal Frame)
	makeColumn(hub, portalPos + Vector3.new(-8.5, 2, 0), 22, 2.4, true)
	makeColumn(hub, portalPos + Vector3.new(8.5, 2, 0), 22, 2.4, true)

	-- Stepped Gothic Portal Archway with Sculpted Keystone
	makePart(hub, "PortalArchLower", Vector3.new(21.5, 3.5, 4.8), CFrame.new(portalPos + Vector3.new(0, 22.0, 0)), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "PortalArchUpper", Vector3.new(23.0, 1.2, 5.2), CFrame.new(portalPos + Vector3.new(0, 24.2, 0)), GOLD_TRIM, Enum.Material.Metal)

	-- Sculpted Arch Keystone
	local keystone = makePart(hub, "PortalKeystone", Vector3.new(3.0, 4.0, 5.4), CFrame.new(portalPos + Vector3.new(0, 23.2, 0)), DARK_STONE, Enum.Material.Slate)
	addMesh(keystone, Enum.MeshType.Wedge, Vector3.new(1.0, 1.0, 1.0))

	-- Carved Dragon-Head Corbel Brackets
	local corbelL = makePart(hub, "CorbelL", Vector3.new(2.2, 2.2, 4.4), CFrame.new(portalPos + Vector3.new(-6.8, 20.2, 0)), DARK_STONE, Enum.Material.Slate, false)
	addMesh(corbelL, Enum.MeshType.Head, Vector3.new(1.0, 1.0, 1.0))
	local corbelR = makePart(hub, "CorbelR", Vector3.new(2.2, 2.2, 4.4), CFrame.new(portalPos + Vector3.new(6.8, 20.2, 0)), DARK_STONE, Enum.Material.Slate, false)
	addMesh(corbelR, Enum.MeshType.Head, Vector3.new(1.0, 1.0, 1.0))

	-- Glowing Ancient Runic Glyphs carved along the pillars
	makePart(hub, "RuneLeft", Vector3.new(0.5, 12, 1.0), CFrame.new(portalPos + Vector3.new(-6.8, 12, 0)), PORTAL_COLOR, Enum.Material.Neon, false)
	makePart(hub, "RuneRight", Vector3.new(0.5, 12, 1.0), CFrame.new(portalPos + Vector3.new(6.8, 12, 0)), PORTAL_COLOR, Enum.Material.Neon, false)

	-- Active RockhidePortal Part (Target of ProximityPrompt)
	local existingPortal = workspace:FindFirstChild("RockhidePortal")
	if existingPortal then existingPortal:Destroy() end

	local portalCore = Instance.new("Part")
	portalCore.Name = "RockhidePortal"
	portalCore.Size = Vector3.new(13.5, 17, 1.5)
	portalCore.CFrame = CFrame.new(portalPos + Vector3.new(0, 11, 0))
	portalCore.Color = PORTAL_COLOR
	portalCore.Material = Enum.Material.Neon
	portalCore.Transparency = 0.35
	portalCore.Anchored = true
	portalCore.CanCollide = false
	portalCore.Parent = workspace

	-- Concentric Orbiting Celestial Rune Stone Rings
	local pRing1 = makePart(hub, "PortalRing1", Vector3.new(16, 16, 0.4), CFrame.new(portalPos + Vector3.new(0, 11, 0)), GOLD_TRIM, Enum.Material.SmoothPlastic, false)
	addMesh(pRing1, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.08))
	pRing1.Transparency = 0.4

	-- Portal Particle Vortex
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 190, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 130, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 90, 255)),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	particles.Lifetime = NumberRange.new(1.2, 2.2)
	particles.Rate = 45
	particles.Speed = NumberRange.new(3, 8)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Parent = portalCore

	local portalLight = Instance.new("PointLight")
	portalLight.Color = PORTAL_COLOR
	portalLight.Brightness = 1.2
	portalLight.Range = 20
	portalLight.Shadows = true
	portalLight.Parent = portalCore

	-- Portal Nameplate / Banner
	local portalBb = Instance.new("BillboardGui")
	portalBb.Name = "PortalTitle"
	portalBb.Size = UDim2.new(0, 260, 0, 56)
	portalBb.StudsOffset = Vector3.new(0, 12, 0)
	portalBb.AlwaysOnTop = false
	portalBb.MaxDistance = 90
	portalBb.Parent = portalCore

	local pTitle = Instance.new("TextLabel")
	pTitle.Size = UDim2.new(1, 0, 0.58, 0)
	pTitle.BackgroundTransparency = 1
	pTitle.TextColor3 = Color3.fromRGB(180, 220, 255)
	pTitle.Font = Enum.Font.GothamBlack
	pTitle.TextScaled = true
	pTitle.Text = "ROCKHIDE'S DUNGEON"
	pTitle.Parent = portalBb

	local pSub = Instance.new("TextLabel")
	pSub.Size = UDim2.new(1, 0, 0.38, 0)
	pSub.Position = UDim2.new(0, 0, 0.60, 0)
	pSub.BackgroundTransparency = 1
	pSub.TextColor3 = Color3.fromRGB(240, 200, 100)
	pSub.Font = Enum.Font.GothamBold
	pSub.TextScaled = true
	pSub.Text = "[Tier 1 | Level 1-5 Normal]"
	pSub.Parent = portalBb

	makeBrazier(hub, portalPos + Vector3.new(-12, 2, 4), Color3.fromRGB(80, 150, 255))
	makeBrazier(hub, portalPos + Vector3.new(12, 2, 4), Color3.fromRGB(80, 150, 255))

	-- ── 3B. CENTRAL EXPEDITION WAYFINDER MONUMENT ─────────────────────────────
	-- Positioned directly in the center between the twin portals (X = 0, Z = -58)
	local wayfinderPos = Vector3.new(0, FLOOR_Y, -58)
	makePart(hub, "WayfinderDais", Vector3.new(16, 1.5, 14), CFrame.new(wayfinderPos + Vector3.new(0, 0.75, 0)), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "WayfinderPlinth", Vector3.new(8, 0.8, 8), CFrame.new(wayfinderPos + Vector3.new(0, 1.9, 0)), STONE_COLOR, Enum.Material.Marble)
	makeColumn(hub, wayfinderPos + Vector3.new(0, 2.3, 0), 16, 1.8, true)

	local wfPart = makePart(hub, "WayfinderSignPart", Vector3.new(12, 3.5, 0.6), CFrame.new(wayfinderPos + Vector3.new(0, 17, 0)), GOLD_TRIM, Enum.Material.Metal, false)
	local wfBb = Instance.new("BillboardGui")
	wfBb.Name = "WayfinderTitle"
	wfBb.Size = UDim2.new(0, 360, 0, 75)
	wfBb.StudsOffset = Vector3.new(0, 1.5, 0)
	wfBb.AlwaysOnTop = false
	wfBb.MaxDistance = 80
	wfBb.Parent = wfPart

	local wfTitle = Instance.new("TextLabel")
	wfTitle.Size = UDim2.new(1, 0, 0.5, 0)
	wfTitle.BackgroundTransparency = 1
	wfTitle.TextColor3 = Color3.fromRGB(255, 230, 130)
	wfTitle.Font = Enum.Font.GothamBlack
	wfTitle.TextScaled = true
	wfTitle.Text = "⚔️ DUNGEON EXPEDITIONS ⚔️"
	wfTitle.Parent = wfBb

	local wfSub = Instance.new("TextLabel")
	wfSub.Size = UDim2.new(1, 0, 0.44, 0)
	wfSub.Position = UDim2.new(0, 0, 0.52, 0)
	wfSub.BackgroundTransparency = 1
	wfSub.TextColor3 = Color3.fromRGB(230, 235, 245)
	wfSub.Font = Enum.Font.GothamBold
	wfSub.TextScaled = true
	wfSub.Text = "⬅ Tier 1: Rockhide (Lv. 1-5)  |  Tier 2: Sunforged (Lv. 5-30+) ➡"
	wfSub.Parent = wfBb

	-- ── 3C. TIER 2 SUNFORGED CITADEL PORTAL (SunforgedPortal) ───────────────
	-- Positioned on the Northeast plaza (X = 28, Z = -58)
	local sunPortalPos = Vector3.new(28, FLOOR_Y, -58)

	-- Raised solar stone dais with gold nosing
	makePart(hub, "SunPortalDais", Vector3.new(32, 2, 24), CFrame.new(sunPortalPos + Vector3.new(0, 1, 0)), DARK_STONE, Enum.Material.Cobblestone)
	makePart(hub, "SunPortalSteps", Vector3.new(24, 1, 6), CFrame.new(sunPortalPos + Vector3.new(0, 0.5, 13)), GOLD_TRIM, Enum.Material.Metal)

	-- Golden Fluted Portal Arch Columns
	makeColumn(hub, sunPortalPos + Vector3.new(-8.5, 2, 0), 22, 2.4, true)
	makeColumn(hub, sunPortalPos + Vector3.new(8.5, 2, 0), 22, 2.4, true)

	-- Golden Arch Head & Sunburst Keystone
	makePart(hub, "SunArchLintel", Vector3.new(21.5, 3.5, 4.8), CFrame.new(sunPortalPos + Vector3.new(0, 22.0, 0)), GOLD_TRIM, Enum.Material.Metal)
	makePart(hub, "SunArchUpper", Vector3.new(23.0, 1.2, 5.2), CFrame.new(sunPortalPos + Vector3.new(0, 24.2, 0)), Color3.fromRGB(255, 205, 75), Enum.Material.Metal)

	local sunKeystone = makePart(hub, "SunKeystone", Vector3.new(3.0, 4.0, 5.4), CFrame.new(sunPortalPos + Vector3.new(0, 23.2, 0)), GOLD_TRIM, Enum.Material.Metal)
	addMesh(sunKeystone, Enum.MeshType.Wedge, Vector3.new(1.0, 1.0, 1.0))

	-- Active SunforgedPortal Part (Target of ProximityPrompt)
	local existingSunPortal = workspace:FindFirstChild("SunforgedPortal")
	if existingSunPortal then existingSunPortal:Destroy() end

	local sunPortalCore = Instance.new("Part")
	sunPortalCore.Name = "SunforgedPortal"
	sunPortalCore.Size = Vector3.new(13.5, 17, 1.5)
	sunPortalCore.CFrame = CFrame.new(sunPortalPos + Vector3.new(0, 11, 0))
	sunPortalCore.Color = Color3.fromRGB(255, 150, 40)
	sunPortalCore.Material = Enum.Material.Neon
	sunPortalCore.Transparency = 0.30
	sunPortalCore.Anchored = true
	sunPortalCore.CanCollide = false
	sunPortalCore.Parent = workspace

	-- Concentric Orbiting Golden Solar Rings
	local sRing1 = makePart(hub, "SunPortalRing1", Vector3.new(16, 16, 0.4), CFrame.new(sunPortalPos + Vector3.new(0, 11, 0)), Color3.fromRGB(255, 215, 60), Enum.Material.SmoothPlastic, false)
	addMesh(sRing1, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.08))
	sRing1.Transparency = 0.45

	-- Golden Solar Particle Vortex
	local sunParticles = Instance.new("ParticleEmitter")
	sunParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 20)),
	})
	sunParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	sunParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	sunParticles.Lifetime = NumberRange.new(1.0, 2.0)
	sunParticles.Rate = 45
	sunParticles.Speed = NumberRange.new(3, 8)
	sunParticles.SpreadAngle = Vector2.new(45, 45)
	sunParticles.Parent = sunPortalCore

	local sunLight = Instance.new("PointLight")
	sunLight.Color = Color3.fromRGB(255, 160, 40)
	sunLight.Brightness = 1.4
	sunLight.Range = 22
	sunLight.Shadows = true
	sunLight.Parent = sunPortalCore

	-- Sunforged Portal Title Banner
	local sunBb = Instance.new("BillboardGui")
	sunBb.Name = "SunPortalTitle"
	sunBb.Size = UDim2.new(0, 280, 0, 56)
	sunBb.StudsOffset = Vector3.new(0, 12, 0)
	sunBb.AlwaysOnTop = false
	sunBb.MaxDistance = 90
	sunBb.Parent = sunPortalCore

	local sTitle = Instance.new("TextLabel")
	sTitle.Size = UDim2.new(1, 0, 0.58, 0)
	sTitle.BackgroundTransparency = 1
	sTitle.TextColor3 = Color3.fromRGB(255, 215, 110)
	sTitle.Font = Enum.Font.GothamBlack
	sTitle.TextScaled = true
	sTitle.Text = "SUNFORGED CITADEL"
	sTitle.Parent = sunBb

	local sSub = Instance.new("TextLabel")
	sSub.Size = UDim2.new(1, 0, 0.38, 0)
	sSub.Position = UDim2.new(0, 0, 0.60, 0)
	sSub.BackgroundTransparency = 1
	sSub.TextColor3 = Color3.fromRGB(255, 175, 60)
	sSub.Font = Enum.Font.GothamBold
	sSub.TextScaled = true
	sSub.Text = "[Tier 2 | Level 5-30+ Hardcore]"
	sSub.Parent = sunBb

	makeBrazier(hub, sunPortalPos + Vector3.new(-12, 2, 4), Color3.fromRGB(255, 130, 30))
	makeBrazier(hub, sunPortalPos + Vector3.new(12, 2, 4), Color3.fromRGB(255, 130, 30))

	-- ── 4. ANCIENT CELESTIAL LEVEL-UP SHRINE (LevelUpShrine) ───────────────────
	local shrinePos = Vector3.new(58, FLOOR_Y, 0)

	-- Multi-tiered circular stone dais with beveled gold nosing
	makeCylinder(hub, "ShrineStep1", 33, 0.35, CFrame.new(shrinePos + Vector3.new(0, 0.175, 0)), DARK_STONE, Enum.Material.Slate)
	makeCylinder(hub, "ShrineDais", 29, 0.45, CFrame.new(shrinePos + Vector3.new(0, 0.575, 0)), STONE_COLOR, Enum.Material.Cobblestone)
	makeCylinder(hub, "ShrineGoldRing", 23, 0.15, CFrame.new(shrinePos + Vector3.new(0, 0.875, 0)), GOLD_TRIM, Enum.Material.Metal)
	makeCylinder(hub, "ShrineInnerSanctum", 19, 0.15, CFrame.new(shrinePos + Vector3.new(0, 0.95, 0)), Color3.fromRGB(38, 42, 48), Enum.Material.Slate)

	-- Inlaid Celestial Sunburst Pattern on Inner Sanctum
	for angle = 0, 315, 45 do
		local rad = math.rad(angle)
		local ray = makePart(hub, "ShrineSunRay_" .. angle, Vector3.new(0.6, 0.08, 7.5), CFrame.new(shrinePos + Vector3.new(0, 1.04, 0)) * CFrame.Angles(0, rad, 0) * CFrame.new(0, 0, 4.5), SHRINE_COLOR, Enum.Material.Neon, false)
		addMesh(ray, Enum.MeshType.Wedge, Vector3.new(1.0, 1.0, 1.0))
	end

	-- 4 Towering Celestial Obelisks with Pyramidion Caps & Rune Inlays
	for angle = 45, 315, 90 do
		local rad = math.rad(angle)
		local ox = shrinePos.X + math.cos(rad) * 11.5
		local oz = shrinePos.Z + math.sin(rad) * 11.5
		makeColumn(hub, Vector3.new(ox, FLOOR_Y + 0.8, oz), 13.5, 1.6, true)

		-- Tapered Pyramidion Cap
		local cap = makePart(hub, "ObeliskCap", Vector3.new(2.4, 2.2, 2.4), CFrame.new(ox, FLOOR_Y + 14.8, oz), GOLD_TRIM, Enum.Material.Metal, false)
		addMesh(cap, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.4, 1.0))

		-- Glowing Celestial Rune Inlay
		makePart(hub, "ObeliskRune", Vector3.new(0.7, 7.5, 0.7), CFrame.new(ox, FLOOR_Y + 7.5, oz), SHRINE_COLOR, Enum.Material.Neon, false)
	end

	-- Sculpted Celestial Altar with Gold Filigree
	local altarBase = makePart(hub, "AltarBase", Vector3.new(5.2, 3.2, 5.2), CFrame.new(shrinePos + Vector3.new(0, 1.025 + 1.6, 0)), DARK_STONE, Enum.Material.Slate)
	local altarMolding = makePart(hub, "AltarMolding", Vector3.new(5.6, 0.6, 5.6), CFrame.new(shrinePos + Vector3.new(0, 1.025 + 2.8, 0)), STONE_COLOR, Enum.Material.Slate, false)
	addMesh(altarMolding, Enum.MeshType.Sphere, Vector3.new(1.0, 0.4, 1.0))

	local altarCap = makePart(hub, "AltarCap", Vector3.new(6.0, 0.7, 6.0), CFrame.new(shrinePos + Vector3.new(0, 1.025 + 3.6, 0)), GOLD_TRIM, Enum.Material.Metal)

	-- Carved Offering Basin on Altar Top
	local altarBasin = makePart(hub, "AltarBasin", Vector3.new(4.2, 0.5, 4.2), CFrame.new(shrinePos + Vector3.new(0, 5.2, 0)), Color3.fromRGB(32, 35, 42), Enum.Material.Slate, false)
	addMesh(altarBasin, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))

	-- The Active LevelUpShrine Part (Target of ProximityPrompt)
	local existingShrine = workspace:FindFirstChild("LevelUpShrine")
	if existingShrine then
		existingShrine:Destroy()
	end

	local shrineCrystal = Instance.new("Part")
	shrineCrystal.Name = "LevelUpShrine"
	shrineCrystal.Size = Vector3.new(2.8, 5.2, 2.8)
	shrineCrystal.CFrame = CFrame.new(shrinePos + Vector3.new(0, 8.0, 0))
	shrineCrystal.Color = SHRINE_COLOR
	shrineCrystal.Material = Enum.Material.Neon
	shrineCrystal.Anchored = true
	shrineCrystal.CanCollide = false

	local sMesh = Instance.new("SpecialMesh")
	sMesh.MeshType = Enum.MeshType.Sphere
	sMesh.Scale = Vector3.new(0.85, 1.65, 0.85)
	sMesh.Parent = shrineCrystal
	shrineCrystal.Parent = workspace

	local shrineLight = Instance.new("PointLight")
	shrineLight.Color = SHRINE_COLOR
	shrineLight.Brightness = 1.4
	shrineLight.Range = 20
	shrineLight.Shadows = true
	shrineLight.Parent = shrineCrystal

	-- Dual Counter-Rotating Golden Halo Rings
	local sRing1 = makePart(hub, "ShrineRing1", Vector3.new(4.6, 0.15, 4.6), CFrame.new(shrinePos + Vector3.new(0, 8.0, 0)), GOLD_TRIM, Enum.Material.Metal, false)
	addMesh(sRing1, Enum.MeshType.Sphere, Vector3.new(1.0, 0.08, 1.0))
	sRing1.Transparency = 0.2

	local sRing2 = makePart(hub, "ShrineRing2", Vector3.new(5.6, 0.15, 5.6), CFrame.new(shrinePos + Vector3.new(0, 8.0, 0)) * CFrame.Angles(math.rad(50), math.rad(25), 0), SHRINE_COLOR, Enum.Material.SmoothPlastic, false)
	addMesh(sRing2, Enum.MeshType.Sphere, Vector3.new(1.0, 0.08, 1.0))
	sRing2.Transparency = 0.35

	-- Upward celestial light sparkles
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 230, 110)
	sparkles.Parent = shrineCrystal

	-- Floating animation for shrine crystal
	local crystalTween = TweenService:Create(
		shrineCrystal,
		TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = CFrame.new(shrinePos + Vector3.new(0, 8.9, 0)) }
	)
	crystalTween:Play()

	-- Shrine Nameplate Billboard
	local shrineBb = Instance.new("BillboardGui")
	shrineBb.Name = "ShrineTitle"
	shrineBb.Size = UDim2.new(0, 260, 0, 54)
	shrineBb.StudsOffset = Vector3.new(0, 4.6, 0)
	shrineBb.AlwaysOnTop = false
	shrineBb.MaxDistance = 80
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

	-- ── 5. COMBAT TRAINING GROUNDS (Sparring Yard) ─────────────────────────────
	local trainingPos = Vector3.new(-58, FLOOR_Y, 0)
	local yardWidth = 38
	local yardLength = 50

	-- Packed Dirt Ground
	makePart(hub, "TrainingGround", Vector3.new(yardWidth, 0.25, yardLength),
		CFrame.new(trainingPos + Vector3.new(0, 0.125, 0)), Color3.fromRGB(115, 95, 72), Enum.Material.Ground)

	-- Cobblestone curb perimeter
	makePart(hub, "YardCurbN", Vector3.new(yardWidth + 2, 0.6, 1.4), CFrame.new(trainingPos + Vector3.new(0, 0.3, -yardLength/2)), DARK_STONE, Enum.Material.Cobblestone)
	makePart(hub, "YardCurbS", Vector3.new(yardWidth + 2, 0.6, 1.4), CFrame.new(trainingPos + Vector3.new(0, 0.3, yardLength/2)), DARK_STONE, Enum.Material.Cobblestone)
	makePart(hub, "YardCurbW", Vector3.new(1.4, 0.6, yardLength + 2), CFrame.new(trainingPos + Vector3.new(-yardWidth/2, 0.3, 0)), DARK_STONE, Enum.Material.Cobblestone)

	-- Wooden Post-and-Rail Fence with Mortise Joints
	for z = -yardLength/2 + 3, yardLength/2 - 3, 8 do
		makePart(hub, "FencePostW", Vector3.new(1, 4.5, 1), CFrame.new(trainingPos + Vector3.new(-yardWidth/2, 0.25 + 2.25, z)), DARK_WOOD, Enum.Material.Wood)
		makePart(hub, "FenceRailW1", Vector3.new(0.6, 0.6, 8), CFrame.new(trainingPos + Vector3.new(-yardWidth/2, 0.25 + 3.4, z)), WOOD_COLOR, Enum.Material.Wood)
		makePart(hub, "FenceRailW2", Vector3.new(0.6, 0.6, 8), CFrame.new(trainingPos + Vector3.new(-yardWidth/2, 0.25 + 1.8, z)), WOOD_COLOR, Enum.Material.Wood)
	end
	for x = -yardWidth/2 + 3, yardWidth/2 - 3, 8 do
		makePart(hub, "FencePostN", Vector3.new(1, 4.5, 1), CFrame.new(trainingPos + Vector3.new(x, 0.25 + 2.25, -yardLength/2)), DARK_WOOD, Enum.Material.Wood)
		makePart(hub, "FenceRailN", Vector3.new(8, 0.6, 0.6), CFrame.new(trainingPos + Vector3.new(x, 0.25 + 3.2, -yardLength/2)), WOOD_COLOR, Enum.Material.Wood)
		makePart(hub, "FencePostS", Vector3.new(1, 4.5, 1), CFrame.new(trainingPos + Vector3.new(x, 0.25 + 2.25, yardLength/2)), DARK_WOOD, Enum.Material.Wood)
		makePart(hub, "FenceRailS", Vector3.new(8, 0.6, 0.6), CFrame.new(trainingPos + Vector3.new(x, 0.25 + 3.2, yardLength/2)), WOOD_COLOR, Enum.Material.Wood)
	end

	-- Masterwork Wooden A-Frame Weapon Rack with Broadswords, Spears & Battleaxes
	local rackCf = CFrame.new(trainingPos + Vector3.new(-12, 0.25 + 2.0, -18))
	makePart(hub, "WeaponRackFrameL", Vector3.new(0.6, 4.0, 1.4), rackCf * CFrame.new(-2.8, 0, 0), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "WeaponRackFrameR", Vector3.new(0.6, 4.0, 1.4), rackCf * CFrame.new(2.8, 0, 0), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "WeaponRackCrossH", Vector3.new(6.0, 0.4, 0.4), rackCf * CFrame.new(0, 0.8, 0), WOOD_COLOR, Enum.Material.Wood)

	-- Racked Broadsword
	makePart(hub, "RackSwordBlade", Vector3.new(0.2, 3.2, 0.4), rackCf * CFrame.new(-1.6, 0.4, 0.3), Color3.fromRGB(220, 225, 235), Enum.Material.Metal, false)
	makePart(hub, "RackSwordGuard", Vector3.new(0.9, 0.2, 0.2), rackCf * CFrame.new(-1.6, -0.9, 0.3), BRASS_COLOR, Enum.Material.Metal, false)

	-- Racked Leaf-Bladed Spear
	makePart(hub, "RackSpearShaft", Vector3.new(0.18, 5.0, 0.18), rackCf * CFrame.new(0, 0.6, 0.3) * CFrame.Angles(0, 0, math.rad(-5)), DARK_WOOD, Enum.Material.Wood, false)
	local spearHead = makePart(hub, "RackSpearHead", Vector3.new(0.45, 1.0, 0.15), rackCf * CFrame.new(-0.25, 3.3, 0.3), Color3.fromRGB(230, 235, 245), Enum.Material.Metal, false)
	addMesh(spearHead, Enum.MeshType.Wedge, Vector3.new(1.0, 1.0, 1.0))

	-- Racked Double-Bitted Battleaxe
	makePart(hub, "RackAxeHaft", Vector3.new(0.2, 3.8, 0.2), rackCf * CFrame.new(1.6, 0.5, 0.3), DARK_WOOD, Enum.Material.Wood, false)
	local axeBlade = makePart(hub, "RackAxeBlade", Vector3.new(1.4, 1.0, 0.15), rackCf * CFrame.new(1.6, 1.8, 0.3), Color3.fromRGB(210, 215, 225), Enum.Material.Metal, false)
	addMesh(axeBlade, Enum.MeshType.Sphere, Vector3.new(1.2, 0.8, 0.3))

	-- 2 Interactive Sparring Dummies
	makeTrainingDummy(hub, "TrainingDummy_1", trainingPos + Vector3.new(-6, 0.25, -6))
	makeTrainingDummy(hub, "TrainingDummy_2", trainingPos + Vector3.new(6, 0.25, 6))

	-- 2 Braided Straw Archery Targets with Embedded Arrows
	makeArcheryTarget(hub, trainingPos + Vector3.new(-9, 0.25, 18), 180)
	makeArcheryTarget(hub, trainingPos + Vector3.new(3, 0.25, 18), 180)

	-- ── 6. ADVENTURERS' TAVERN & GUILD HALL ("The Rusty Anvil") ───────────────
	local tavernPos = Vector3.new(-48, FLOOR_Y, 46)
	local tavernW, tavernL, tavernH = 34, 28, 18

	-- Foundation & Timber-Framed Facade (Fachwerk)
	makePart(hub, "TavernFoundation", Vector3.new(tavernW, 2, tavernL), CFrame.new(tavernPos + Vector3.new(0, 1.0, 0)), STONE_COLOR, Enum.Material.Cobblestone)
	makePart(hub, "TavernWalls", Vector3.new(tavernW - 2, tavernH - 2, tavernL - 2), CFrame.new(tavernPos + Vector3.new(0, tavernH/2 + 1.0, 0)), Color3.fromRGB(205, 195, 175), Enum.Material.Plaster)

	-- Dark Timber Corner Posts & Horizontal Mid-Beams
	for _, tx in {-tavernW/2 + 1, tavernW/2 - 1} do
		for _, tz in {-tavernL/2 + 1, tavernL/2 - 1} do
			makePart(hub, "TavernCornerPost", Vector3.new(2, tavernH, 2), CFrame.new(tavernPos + Vector3.new(tx, tavernH/2 + 1.0, tz)), DARK_WOOD, Enum.Material.Wood)
		end
	end
	makePart(hub, "TavernMidBeamFront", Vector3.new(tavernW, 1.2, 0.8), CFrame.new(tavernPos + Vector3.new(0, tavernH * 0.55 + 1.0, -tavernL/2)), DARK_WOOD, Enum.Material.Wood)

	-- Diagonal Timber Braces on Front Facade
	makePart(hub, "TavernBrace1", Vector3.new(0.6, 7.5, 0.6), CFrame.new(tavernPos + Vector3.new(-11, 6.0, -tavernL/2)) * CFrame.Angles(0, 0, math.rad(35)), DARK_WOOD, Enum.Material.Wood, false)
	makePart(hub, "TavernBrace2", Vector3.new(0.6, 7.5, 0.6), CFrame.new(tavernPos + Vector3.new(11, 6.0, -tavernL/2)) * CFrame.Angles(0, 0, math.rad(-35)), DARK_WOOD, Enum.Material.Wood, false)

	-- Overhanging Slate Tiled Roof with Carved Corbels
	makePart(hub, "TavernRoof", Vector3.new(tavernW + 5, 3.2, tavernL + 5), CFrame.new(tavernPos + Vector3.new(0, tavernH + 1.6, 0)), ROOF_COLOR, Enum.Material.Slate)

	-- Stone Chimney with Chimney Pot & Smoke Particles
	makePart(hub, "TavernChimney", Vector3.new(4.5, tavernH + 7, 4.5), CFrame.new(tavernPos + Vector3.new(-tavernW/2 + 1, (tavernH + 7)/2, 0)), DARK_STONE, Enum.Material.Cobblestone)
	local chimneyPot = makeCylinder(hub, "TavernChimneyPot", 2.2, 2.4, CFrame.new(tavernPos + Vector3.new(-tavernW/2 + 1, tavernH + 8.2, 0)), Color3.fromRGB(155, 75, 60), Enum.Material.Brick)
	
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(215, 215, 220)
	smoke.Size = 2.5
	smoke.RiseVelocity = 3.5
	smoke.Opacity = 0.4
	smoke.Parent = chimneyPot

	-- Studded Arched Tavern Door with Iron Strap Hinges & Ring Knocker
	local doorCf = CFrame.new(tavernPos + Vector3.new(0, 5.0, -tavernL/2 + 0.1))
	makePart(hub, "TavernDoor", Vector3.new(4.8, 8.0, 0.6), doorCf, DARK_WOOD, Enum.Material.WoodPlanks)
	makePart(hub, "TavernHinge1", Vector3.new(2.4, 0.35, 0.1), doorCf * CFrame.new(-1.0, 2.4, -0.32), IRON_COLOR, Enum.Material.Metal, false)
	makePart(hub, "TavernHinge2", Vector3.new(2.4, 0.35, 0.1), doorCf * CFrame.new(-1.0, -2.4, -0.32), IRON_COLOR, Enum.Material.Metal, false)
	local ringKnocker = makePart(hub, "TavernKnocker", Vector3.new(0.6, 0.6, 0.2), doorCf * CFrame.new(1.0, 0.2, -0.35), BRASS_COLOR, Enum.Material.Metal, false)
	addMesh(ringKnocker, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.3))

	-- Outdoor Tavern Patio & Beer Garden
	makePart(hub, "TavernPatioFloor", Vector3.new(24, 0.4, 14), CFrame.new(tavernPos + Vector3.new(0, 0.2, -tavernL/2 - 7)), DARK_WOOD, Enum.Material.WoodPlanks)
	makeStoneBench(hub, tavernPos + Vector3.new(-7, 0.4, -tavernL/2 - 7), 0)
	makeStoneBench(hub, tavernPos + Vector3.new(7, 0.4, -tavernL/2 - 7), 180)

	-- Trestle Table with Sculpted Wooden Ale Tankards
	local tableCf = CFrame.new(tavernPos + Vector3.new(0, 0.4 + 1.1, -tavernL/2 - 7))
	makePart(hub, "TavernTableTop", Vector3.new(9.0, 0.4, 3.6), tableCf * CFrame.new(0, 0.9, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	makePart(hub, "TavernTableLegL", Vector3.new(0.8, 1.8, 2.8), tableCf * CFrame.new(-3.4, 0, 0), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "TavernTableLegR", Vector3.new(0.8, 1.8, 2.8), tableCf * CFrame.new(3.4, 0, 0), DARK_WOOD, Enum.Material.Wood)

	-- 3 Sculpted Wooden Ale Tankards with Foaming Heads
	for _, mugX in {-2.2, 0.4, 2.4} do
		local mugCf = tableCf * CFrame.new(mugX, 1.4, 0.2)
		makeCylinder(hub, "AleTankard", 0.6, 0.8, mugCf, DARK_WOOD, Enum.Material.Wood, false)
		-- Foam Head
		local foam = makePart(hub, "AleFoam", Vector3.new(0.65, 0.25, 0.65), mugCf * CFrame.new(0, 0.45, 0), Color3.fromRGB(245, 240, 220), Enum.Material.SmoothPlastic, false)
		addMesh(foam, Enum.MeshType.Sphere, Vector3.new(1.0, 0.8, 1.0))
		-- Handle
		makePart(hub, "AleHandle", Vector3.new(0.12, 0.5, 0.25), mugCf * CFrame.new(0.35, 0, 0), BRASS_COLOR, Enum.Material.Metal, false)
	end

	-- Warm Glowing Leaded Glass Windows
	local win1 = makePart(hub, "TavernWindow1", Vector3.new(4, 3.2, 0.4), CFrame.new(tavernPos + Vector3.new(-8.5, 8, -tavernL/2)), Color3.fromRGB(255, 215, 130), Enum.Material.Neon, false)
	local win2 = makePart(hub, "TavernWindow2", Vector3.new(4, 3.2, 0.4), CFrame.new(tavernPos + Vector3.new(8.5, 8, -tavernL/2)), Color3.fromRGB(255, 215, 130), Enum.Material.Neon, false)

	-- Swinging Tavern Signboard on Wrought-Iron Bracket
	local signArm = makePart(hub, "SignBracket", Vector3.new(0.4, 0.4, 3.6), CFrame.new(tavernPos + Vector3.new(0, 11.5, -tavernL/2 - 1.8)), IRON_COLOR, Enum.Material.Metal, false)
	local tSign = makePart(hub, "TavernSign", Vector3.new(5.8, 3.0, 0.4), CFrame.new(tavernPos + Vector3.new(0, 9.8, -tavernL/2 - 1.8)), DARK_WOOD, Enum.Material.Wood)

	local signBb = Instance.new("BillboardGui")
	signBb.Size = UDim2.new(1, 0, 1, 0)
	signBb.AlwaysOnTop = false
	signBb.MaxDistance = 60
	signBb.Parent = tSign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.TextColor3 = Color3.fromRGB(255, 215, 120)
	signText.Font = Enum.Font.GothamBold
	signText.TextScaled = true
	signText.Text = "THE RUSTY ANVIL"
	signText.Parent = signBb

	-- Stacked coopered ale barrels and supply crates by the tavern
	makeBarrel(hub, tavernPos + Vector3.new(tavernW/2 + 2.5, 0, -4), 2.6, 3.4)
	makeBarrel(hub, tavernPos + Vector3.new(tavernW/2 + 2.5, 0, -1), 2.6, 3.4)
	makeCrate(hub, tavernPos + Vector3.new(tavernW/2 + 2.5, 0, 4), Vector3.new(3.2, 3.2, 3.2), 15)

	-- ── 7. BLACKSMITH FORGE & ARMORY (South-East) ──────────────────────────────
	local forgePos = Vector3.new(48, FLOOR_Y, 46)
	local forgeW, forgeL = 32, 26

	-- Stone Forge Foundation
	makePart(hub, "ForgeFloor", Vector3.new(forgeW, 1.0, forgeL), CFrame.new(forgePos + Vector3.new(0, 0.5, 0)), DARK_STONE, Enum.Material.Cobblestone)
	makePart(hub, "ForgeStep", Vector3.new(16, 0.5, 4), CFrame.new(forgePos + Vector3.new(0, 0.25, -forgeL/2 - 2)), STONE_COLOR, Enum.Material.Slate)

	-- 4 Imposing Fluted Stone Columns Supporting Forge Canopy
	makeColumn(hub, forgePos + Vector3.new(-forgeW/2 + 2.5, 1, -forgeL/2 + 2.5), 13, 1.6)
	makeColumn(hub, forgePos + Vector3.new(forgeW/2 - 2.5, 1, -forgeL/2 + 2.5), 13, 1.6)
	makeColumn(hub, forgePos + Vector3.new(-forgeW/2 + 2.5, 1, forgeL/2 - 2.5), 13, 1.6)
	makeColumn(hub, forgePos + Vector3.new(forgeW/2 - 2.5, 1, forgeL/2 - 2.5), 13, 1.6)

	-- Forge Canopy Roof
	makePart(hub, "ForgeRoof", Vector3.new(forgeW + 3, 2.2, forgeL + 3), CFrame.new(forgePos + Vector3.new(0, 14.5, 0)), ROOF_COLOR, Enum.Material.Slate)

	-- Stone Hearth Furnace with Firebrick Firebox & Arched Hood
	local furnacePos = forgePos + Vector3.new(8, 1.0, 6.5)
	makePart(hub, "FurnaceChimney", Vector3.new(7.5, 19, 7.5), CFrame.new(furnacePos + Vector3.new(0, 9.5, 0)), DARK_STONE, Enum.Material.Cobblestone)
	makePart(hub, "FurnaceHearthStone", Vector3.new(6.0, 1.4, 5.0), CFrame.new(furnacePos + Vector3.new(0, 1.7, -1.8)), STONE_COLOR, Enum.Material.Slate)

	-- Glowing Bed of Molten Coals
	local furnaceCore = makePart(hub, "FurnaceFire", Vector3.new(4.2, 2.6, 3.8), CFrame.new(furnacePos + Vector3.new(0, 3.0, -1.2)), Color3.fromRGB(255, 115, 20), Enum.Material.Neon, false)

	local fFire = Instance.new("Fire")
	fFire.Size = 6
	fFire.Heat = 8
	fFire.Color = Color3.fromRGB(255, 125, 20)
	fFire.SecondaryColor = Color3.fromRGB(255, 200, 40)
	fFire.Parent = furnaceCore

	local fLight = Instance.new("PointLight")
	fLight.Color = Color3.fromRGB(255, 135, 25)
	fLight.Brightness = 1.2
	fLight.Range = 18
	fLight.Parent = furnaceCore

	-- Double-Chamber Oak & Pleated Leather Blacksmith Bellows
	local bellowsCf = CFrame.new(furnacePos + Vector3.new(-4.2, 2.4, -0.8)) * CFrame.Angles(0, math.rad(-25), 0)
	makePart(hub, "BellowsPlankTop", Vector3.new(2.0, 0.25, 3.2), bellowsCf * CFrame.new(0, 0.6, 0), DARK_WOOD, Enum.Material.Wood)
	makePart(hub, "BellowsPlankBottom", Vector3.new(2.0, 0.25, 3.2), bellowsCf * CFrame.new(0, -0.6, 0), DARK_WOOD, Enum.Material.Wood)
	local bellowsBody = makePart(hub, "BellowsLeather", Vector3.new(1.8, 1.1, 2.8), bellowsCf, Color3.fromRGB(80, 50, 35), Enum.Material.Fabric, false)
	addMesh(bellowsBody, Enum.MeshType.Sphere, Vector3.new(1.0, 0.9, 1.1))
	makePart(hub, "BellowsNozzle", Vector3.new(0.3, 0.3, 1.4), bellowsCf * CFrame.new(0, 0, 1.8), IRON_COLOR, Enum.Material.Metal, false)

	-- Hanging Blacksmith Tongs and Forging Hammer on Hearth Flue
	makePart(hub, "ToolRackBar", Vector3.new(4.2, 0.2, 0.2), CFrame.new(furnacePos + Vector3.new(0, 6.2, -3.9)), IRON_COLOR, Enum.Material.Metal, false)
	makePart(hub, "ForgingHammer", Vector3.new(0.3, 1.6, 0.7), CFrame.new(furnacePos + Vector3.new(-1.2, 5.4, -3.8)), IRON_COLOR, Enum.Material.Metal, false)
	makePart(hub, "ForgingTongs", Vector3.new(0.2, 2.0, 0.4), CFrame.new(furnacePos + Vector3.new(1.2, 5.2, -3.8)), IRON_COLOR, Enum.Material.Metal, false)

	-- Masterwork Blacksmith Anvil on Heavy Tree Stump
	local anvilX, anvilZ = -4, 2
	local stumpPos = forgePos + Vector3.new(anvilX, 1.0, anvilZ)
	makeCylinder(hub, "AnvilStump", 3.4, 1.8, CFrame.new(stumpPos + Vector3.new(0, 0.9, 0)), DARK_WOOD, Enum.Material.Wood)

	-- Iron Holding Dog-Cleats on Stump
	for angle = 45, 315, 90 do
		local rad = math.rad(angle)
		makePart(hub, "AnvilCleat", Vector3.new(0.3, 0.8, 0.3), CFrame.new(stumpPos + Vector3.new(math.cos(rad) * 1.5, 1.5, math.sin(rad) * 1.5)), IRON_COLOR, Enum.Material.Metal, false)
	end

	-- Realistic Anvil Anatomy:
	local anvilCf = CFrame.new(stumpPos + Vector3.new(0, 1.8, 0))
	-- 1. Flared Swage Foot Base
	local anvilBase = makePart(hub, "AnvilBase", Vector3.new(2.8, 0.6, 2.0), anvilCf * CFrame.new(0, 0.3, 0), DARK_STONE, Enum.Material.Slate)
	addMesh(anvilBase, Enum.MeshType.Sphere, Vector3.new(1.0, 0.6, 1.0))

	-- 2. Narrow Waist Transition
	local anvilWaist = makePart(hub, "AnvilWaist", Vector3.new(1.8, 0.8, 1.4), anvilCf * CFrame.new(0, 0.9, 0), IRON_COLOR, Enum.Material.Metal)

	-- 3. Hardened Steel Face & Table
	local anvilFace = makePart(hub, "AnvilFace", Vector3.new(2.6, 0.8, 1.5), anvilCf * CFrame.new(0.2, 1.5, 0), Color3.fromRGB(160, 165, 175), Enum.Material.Metal)

	-- 4. Conical Forged Steel Horn (Left side for shaping curves)
	local anvilHorn = makePart(hub, "AnvilHorn", Vector3.new(1.8, 0.7, 1.2), anvilCf * CFrame.new(-1.6, 1.5, 0), IRON_COLOR, Enum.Material.Metal)
	addMesh(anvilHorn, Enum.MeshType.Wedge, Vector3.new(1.0, 1.0, 1.0))
	anvilHorn.CFrame = anvilCf * CFrame.new(-1.6, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0)

	-- Crafting ProximityPrompt on the Anvil
	local craftPrompt = Instance.new("ProximityPrompt")
	craftPrompt.ObjectText = "Soulforge Armory"
	craftPrompt.ActionText = "Craft Gear"
	craftPrompt.KeyboardKeyCode = Enum.KeyCode.E
	craftPrompt.MaxActivationDistance = 8
	craftPrompt.HoldDuration = 0
	craftPrompt.Parent = anvilFace
	craftPrompt.Triggered:Connect(function(player: Player)
		Net.Get("OpenCraftingUI"):FireClient(player)
	end)

	-- Blacksmith Water Quenching Trough with Steam Particles
	local tubPos = forgePos + Vector3.new(anvilX + 5.2, 1.0, anvilZ)
	makeCylinder(hub, "CoolingTub", 3.6, 2.2, CFrame.new(tubPos + Vector3.new(0, 1.1, 0)), DARK_WOOD, Enum.Material.Wood)
	local tubWater = makeCylinder(hub, "TubWater", 3.2, 0.2, CFrame.new(tubPos + Vector3.new(0, 2.0, 0)), Color3.fromRGB(45, 115, 185), Enum.Material.Glass, false)

	local steamEmitter = Instance.new("ParticleEmitter")
	steamEmitter.Color = ColorSequence.new(Color3.fromRGB(225, 230, 240))
	steamEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	steamEmitter.Transparency = NumberSequence.new(0.3, 1.0)
	steamEmitter.Lifetime = NumberRange.new(1.0, 1.8)
	steamEmitter.Rate = 12
	steamEmitter.Speed = NumberRange.new(1.5, 3.5)
	steamEmitter.SpreadAngle = Vector2.new(20, 20)
	steamEmitter.Parent = tubWater

	-- Forge Signboard
	local fSign = makePart(hub, "ForgeSign", Vector3.new(6.2, 2.8, 0.4), CFrame.new(forgePos + Vector3.new(0, 11.5, -forgeL/2 - 0.4)), DARK_WOOD, Enum.Material.Wood)
	local fsignBb = Instance.new("BillboardGui")
	fsignBb.Size = UDim2.new(1, 0, 1, 0)
	fsignBb.AlwaysOnTop = true
	fsignBb.Parent = fSign
	local fsignText = Instance.new("TextLabel")
	fsignText.Size = UDim2.new(1, 0, 1, 0)
	fsignText.BackgroundTransparency = 1
	fsignText.TextColor3 = Color3.fromRGB(255, 180, 80)
	fsignText.Font = Enum.Font.GothamBold
	fsignText.TextScaled = true
	fsignText.Text = "SOULFORGE ARMORY"
	fsignText.Parent = fsignBb

	-- Stacked iron ingots & supply crates
	makeCrate(hub, forgePos + Vector3.new(-forgeW/2 - 2.5, 0, -4), Vector3.new(3.2, 3.2, 3.2), -20)
	makeCrate(hub, forgePos + Vector3.new(-forgeW/2 - 2.5, 0, 0), Vector3.new(3.6, 3.2, 3.6), 10)

	-- ── 8. DEFENSIVE FORTRESS PERIMETER WALLS & CORNER BASTIONS ───────────────
	-- Fully enclosed with authentic Castellated Battlements (Merlons & Crenels)
	local wallH = 22
	local wallThick = 5.0
	local halfP = plazaSize / 2

	-- North Wall (Behind Portal)
	makePart(hub, "Wall_North", Vector3.new(plazaSize, wallH, wallThick),
		CFrame.new(0, FLOOR_Y + wallH / 2, -halfP), WALL_STONE, Enum.Material.Cobblestone)
	makePart(hub, "CorbelTrim_N", Vector3.new(plazaSize, 1.2, 2.4),
		CFrame.new(0, FLOOR_Y + wallH - 0.6, -halfP + 1.2), DARK_STONE, Enum.Material.Slate)

	-- West Wall (Behind Training Grounds)
	makePart(hub, "Wall_West", Vector3.new(wallThick, wallH, plazaSize),
		CFrame.new(-halfP, FLOOR_Y + wallH / 2, 0), WALL_STONE, Enum.Material.Cobblestone)
	makePart(hub, "CorbelTrim_W", Vector3.new(2.4, 1.2, plazaSize),
		CFrame.new(-halfP + 1.2, FLOOR_Y + wallH - 0.6, 0), DARK_STONE, Enum.Material.Slate)

	-- East Wall (Behind Ascension Shrine)
	makePart(hub, "Wall_East", Vector3.new(wallThick, wallH, plazaSize),
		CFrame.new(halfP, FLOOR_Y + wallH / 2, 0), WALL_STONE, Enum.Material.Cobblestone)
	makePart(hub, "CorbelTrim_E", Vector3.new(2.4, 1.2, plazaSize),
		CFrame.new(halfP - 1.2, FLOOR_Y + wallH - 0.6, 0), DARK_STONE, Enum.Material.Slate)

	-- South Wall (Continuous, Fortified & Fully Enclosing the Hub)
	makePart(hub, "Wall_South", Vector3.new(plazaSize, wallH, wallThick),
		CFrame.new(0, FLOOR_Y + wallH / 2, halfP), WALL_STONE, Enum.Material.Cobblestone)
	makePart(hub, "CorbelTrim_S", Vector3.new(plazaSize, 1.2, 2.4),
		CFrame.new(0, FLOOR_Y + wallH - 0.6, halfP - 1.2), DARK_STONE, Enum.Material.Slate)

	-- Castellated Merlons & Crenels along Fortress Battlements
	local function makeMerlonsX(startX: number, endX: number, zPos: number, step: number)
		for x = startX, endX, step do
			makePart(hub, "Merlon", Vector3.new(step * 0.55, 3.4, 2.2), CFrame.new(x, FLOOR_Y + wallH + 1.7, zPos), DARK_STONE, Enum.Material.Slate)
		end
	end
	local function makeMerlonsZ(startZ: number, endZ: number, xPos: number, step: number)
		for z = startZ, endZ, step do
			makePart(hub, "Merlon", Vector3.new(2.2, 3.4, step * 0.55), CFrame.new(xPos, FLOOR_Y + wallH + 1.7, z), DARK_STONE, Enum.Material.Slate)
		end
	end

	makeMerlonsX(-halfP + 8, halfP - 8, -halfP - 1.4, 8)
	makeMerlonsZ(-halfP + 8, halfP - 8, -halfP - 1.4, 8)
	makeMerlonsZ(-halfP + 8, halfP - 8, halfP + 1.4, 8)
	makeMerlonsX(-halfP + 8, halfP - 8, halfP + 1.4, 8)

	-- 4 Grand Corner Bastion Towers with Octagonal Turrets & Spires
	local corners = {
		Vector3.new(-halfP, FLOOR_Y, -halfP),
		Vector3.new(halfP, FLOOR_Y, -halfP),
		Vector3.new(-halfP, FLOOR_Y, halfP),
		Vector3.new(halfP, FLOOR_Y, halfP),
	}
	for i, cPos in ipairs(corners) do
		makeColumn(hub, cPos, 32, 6.5, true)
		local roof = makePart(hub, "BastionRoof_" .. i, Vector3.new(15, 6, 15), CFrame.new(cPos + Vector3.new(0, 35, 0)), ROOF_COLOR, Enum.Material.Slate)
		addMesh(roof, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.4, 1.0))
		local spire = makePart(hub, "BastionSpire_" .. i, Vector3.new(1.2, 3.5, 1.2), CFrame.new(cPos + Vector3.new(0, 39.5, 0)), GOLD_TRIM, Enum.Material.Metal, false)
		addMesh(spire, Enum.MeshType.Sphere, Vector3.new(0.6, 2.0, 0.6))
		makeBrazier(hub, cPos + Vector3.new(0, 33, 0), Color3.fromRGB(255, 140, 30))
	end

	-- Wall Braziers along the fortress battlements
	makeBrazier(hub, Vector3.new(-halfP + 2, FLOOR_Y + wallH, -25), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, Vector3.new(-halfP + 2, FLOOR_Y + wallH, 25), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, Vector3.new(halfP - 2, FLOOR_Y + wallH, -25), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, Vector3.new(halfP - 2, FLOOR_Y + wallH, 25), Color3.fromRGB(255, 140, 30))

	-- ── 9. SOUTH GATEHOUSE (SEALED & FORTIFIED CASTLE GATES) ───────────────────
	local gateZ = halfP
	-- Twin Gatehouse Guard Towers
	makeColumn(hub, Vector3.new(-18, FLOOR_Y, gateZ), 34, 4.2, true)
	makeColumn(hub, Vector3.new(18, FLOOR_Y, gateZ), 34, 4.2, true)

	local gRoofL = makePart(hub, "GateRoofL", Vector3.new(11, 5, 11), CFrame.new(-18, FLOOR_Y + 36.5, gateZ), ROOF_COLOR, Enum.Material.Slate)
	addMesh(gRoofL, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.3, 1.0))
	local gRoofR = makePart(hub, "GateRoofR", Vector3.new(11, 5, 11), CFrame.new(18, FLOOR_Y + 36.5, gateZ), ROOF_COLOR, Enum.Material.Slate)
	addMesh(gRoofR, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.3, 1.0))

	makeBrazier(hub, Vector3.new(-18, FLOOR_Y + 34, gateZ), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, Vector3.new(18, FLOOR_Y + 34, gateZ), Color3.fromRGB(255, 140, 30))

	-- Gatehouse Archway Lintel & Sculpted Crest
	makePart(hub, "GatehouseArch", Vector3.new(36, 6, 6), CFrame.new(0, FLOOR_Y + 23, gateZ), DARK_STONE, Enum.Material.Slate)
	local crest = makePart(hub, "GatehouseCrest", Vector3.new(4.2, 4.2, 0.8), CFrame.new(0, FLOOR_Y + 23, gateZ - 2.8), GOLD_TRIM, Enum.Material.Metal, false)
	addMesh(crest, Enum.MeshType.Sphere, Vector3.new(1.0, 1.2, 0.5))

	-- Hanging Heraldic Crimson Banners on Guard Towers
	for _, bx in {-18, 18} do
		local banner = makePart(hub, "GateBanner", Vector3.new(2.8, 12, 0.2), CFrame.new(bx, FLOOR_Y + 20, gateZ - 3.8), Color3.fromRGB(175, 35, 40), Enum.Material.Fabric, false)
		makePart(hub, "BannerGoldTrim", Vector3.new(3.0, 0.6, 0.3), CFrame.new(bx, FLOOR_Y + 14.2, gateZ - 3.8), GOLD_TRIM, Enum.Material.Metal, false)
	end

	-- Solid Closed & Barred Heavy Oak Fortress Gate
	local gateDoorW, gateDoorH = 14, 18
	makePart(hub, "ClosedGate_Left", Vector3.new(gateDoorW, gateDoorH, 1.4), CFrame.new(-gateDoorW / 2, FLOOR_Y + gateDoorH / 2, gateZ - 1.2), DARK_WOOD, Enum.Material.WoodPlanks)
	makePart(hub, "ClosedGate_Right", Vector3.new(gateDoorW, gateDoorH, 1.4), CFrame.new(gateDoorW / 2, FLOOR_Y + gateDoorH / 2, gateZ - 1.2), DARK_WOOD, Enum.Material.WoodPlanks)

	-- Iron Studs & Strapping on Closed Gates
	for _, gx in {-11, -5, 5, 11} do
		for _, gy in {3.5, 9.0, 14.5} do
			local stud = makePart(hub, "GateStud", Vector3.new(0.5, 0.5, 0.3), CFrame.new(gx, FLOOR_Y + gy, gateZ - 2.0), BRASS_COLOR, Enum.Material.Metal, false)
			addMesh(stud, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.8))
		end
	end

	-- Heavy Locking Iron Crossbar Across Gates
	makePart(hub, "GateLockBar", Vector3.new(28, 1.4, 0.8), CFrame.new(0, FLOOR_Y + 9.0, gateZ - 2.1), IRON_COLOR, Enum.Material.Metal)

	-- Fully Lowered Heavy Iron Portcullis Grille (Rests firmly on ground at FLOOR_Y, sealing the archway)
	for barX = -12, 12, 3 do
		local pBar = makePart(hub, "PortcullisBar_" .. barX, Vector3.new(0.8, 18, 0.8), CFrame.new(barX, FLOOR_Y + 9.0, gateZ - 0.5), IRON_COLOR, Enum.Material.Metal)
		local pSpike = makePart(hub, "PortcullisSpike_" .. barX, Vector3.new(0.9, 1.2, 0.9), CFrame.new(barX, FLOOR_Y + 0.6, gateZ - 0.5), IRON_COLOR, Enum.Material.Metal, false)
		addMesh(pSpike, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.4, 1.0))
		pSpike.CFrame = CFrame.new(barX, FLOOR_Y + 0.6, gateZ - 0.5) * CFrame.Angles(math.rad(180), 0, 0)
	end
	makePart(hub, "PortcullisCrossTop", Vector3.new(28, 0.8, 0.8), CFrame.new(0, FLOOR_Y + 17, gateZ - 0.5), IRON_COLOR, Enum.Material.Metal)
	makePart(hub, "PortcullisCrossMid", Vector3.new(28, 0.8, 0.8), CFrame.new(0, FLOOR_Y + 9, gateZ - 0.5), IRON_COLOR, Enum.Material.Metal)
	makePart(hub, "PortcullisCrossBot", Vector3.new(28, 0.8, 0.8), CFrame.new(0, FLOOR_Y + 1.5, gateZ - 0.5), IRON_COLOR, Enum.Material.Metal)

	-- Heavy Forged Iron Drawbridge Suspension Chains
	for _, cx in {-8.5, 8.5} do
		local chain = makePart(hub, "DrawbridgeChain", Vector3.new(0.5, 24, 0.5), CFrame.new(cx, FLOOR_Y + 12, gateZ + 11) * CFrame.Angles(math.rad(40), 0, 0), IRON_COLOR, Enum.Material.Metal, false)
		addMesh(chain, Enum.MeshType.Cylinder, Vector3.new(1.0, 1.0, 1.0))
	end

	-- ── Grand Stone Drawbridge & Mountain Overlook ──
	local bridgeLen = 50
	local bridgeWidth = 18
	local bridgeCenterZ = gateZ + bridgeLen / 2 -- Z = 110

	makePart(hub, "Drawbridge_Floor", Vector3.new(bridgeWidth, 2.0, bridgeLen),
		CFrame.new(0, FLOOR_Y - 1, bridgeCenterZ), PAVING_COLOR, Enum.Material.Cobblestone)
	makePart(hub, "Drawbridge_Beams", Vector3.new(bridgeWidth + 1.4, 1.6, bridgeLen),
		CFrame.new(0, FLOOR_Y - 2.6, bridgeCenterZ), DARK_WOOD, Enum.Material.WoodPlanks)

	-- Stone Balustrades on Drawbridge sides
	makePart(hub, "BridgeRailingW", Vector3.new(1.8, 3.8, bridgeLen),
		CFrame.new(-bridgeWidth / 2 + 0.9, FLOOR_Y + 1.9, bridgeCenterZ), DARK_STONE, Enum.Material.Slate)
	makePart(hub, "BridgeRailingE", Vector3.new(1.8, 3.8, bridgeLen),
		CFrame.new(bridgeWidth / 2 - 0.9, FLOOR_Y + 1.9, bridgeCenterZ), DARK_STONE, Enum.Material.Slate)

	-- Bridge Street Lamps
	makeStreetLamp(hub, Vector3.new(-bridgeWidth / 2 + 1.2, FLOOR_Y, bridgeCenterZ))
	makeStreetLamp(hub, Vector3.new(bridgeWidth / 2 - 1.2, FLOOR_Y, bridgeCenterZ))

	-- Mountain Overlook Vista Platform (Z = 145)
	local overlookZ = gateZ + bridgeLen + 10 -- Z = 145
	makeCylinder(hub, "OverlookDais", 35, 2.0, CFrame.new(0, FLOOR_Y - 1, overlookZ), PAVING_COLOR, Enum.Material.Cobblestone)
	makeCylinder(hub, "OverlookTrim", 36, 0.5, CFrame.new(0, FLOOR_Y + 0.25, overlookZ), DARK_STONE, Enum.Material.Slate)

	-- Sculpted Stone Lookout Balusters around southern rim
	for angle = -70, 70, 15 do
		local rad = math.rad(angle)
		local bx = math.sin(rad) * 16.8
		local bz = overlookZ + math.cos(rad) * 16.8
		local post = makePart(hub, "LookoutPost_" .. angle, Vector3.new(2.2, 4.2, 2.2), CFrame.new(bx, FLOOR_Y + 2.1, bz), DARK_STONE, Enum.Material.Slate)
		local postCap = makePart(hub, "LookoutCap_" .. angle, Vector3.new(2.5, 0.4, 2.5), CFrame.new(bx, FLOOR_Y + 4.3, bz), STONE_COLOR, Enum.Material.Slate, false)
		addMesh(postCap, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))
	end

	-- Antique Brass Astronomical Spyglass / Telescope on Tripod pointing at peaks
	local teleCf = CFrame.new(0, FLOOR_Y + 3.8, overlookZ + 12) * CFrame.Angles(math.rad(-18), math.rad(180), 0)
	makePart(hub, "TeleBarrel", Vector3.new(0.6, 0.6, 4.2), teleCf, BRASS_COLOR, Enum.Material.Metal, false)
	local teleLens = makePart(hub, "TeleLens", Vector3.new(0.8, 0.8, 0.4), teleCf * CFrame.new(0, 0, 2.1), GOLD_TRIM, Enum.Material.Metal, false)
	addMesh(teleLens, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.6))
	makePart(hub, "TeleTripod", Vector3.new(1.2, 3.4, 1.2), CFrame.new(0, FLOOR_Y + 1.7, overlookZ + 12), DARK_WOOD, Enum.Material.Wood, false)

	-- Lookout Braziers & Viewing Bench
	makeBrazier(hub, Vector3.new(-12, FLOOR_Y, overlookZ + 8), Color3.fromRGB(255, 140, 30))
	makeBrazier(hub, Vector3.new(12, FLOOR_Y, overlookZ + 8), Color3.fromRGB(255, 140, 30))
	makeStoneBench(hub, Vector3.new(0, FLOOR_Y, overlookZ + 4), 180)

	-- Invisible Safety Boundary
	local function makeBarrier(name: string, size: Vector3, cf: CFrame)
		local b = Instance.new("Part")
		b.Name = name
		b.Size = size
		b.CFrame = cf
		b.Transparency = 1
		b.CanCollide = true
		b.Anchored = true
		b.Parent = hub
	end

	-- Airtight, Impassable 80-Stud High Hub Perimeter Collision Boundaries (All 4 Sides: North, South, East, West)
	-- Strictly keeps the player inside the Hub courtyard at all times with zero escape
	local hubBarrierH = 80
	makeBarrier("HubPerimeterBarrier_North", Vector3.new(plazaSize + 30, hubBarrierH, 6), CFrame.new(0, FLOOR_Y + hubBarrierH / 2, -halfP - 2))
	makeBarrier("HubPerimeterBarrier_South", Vector3.new(plazaSize + 30, hubBarrierH, 6), CFrame.new(0, FLOOR_Y + hubBarrierH / 2, halfP + 2))
	makeBarrier("HubPerimeterBarrier_West",  Vector3.new(6, hubBarrierH, plazaSize + 30), CFrame.new(-halfP - 2, FLOOR_Y + hubBarrierH / 2, 0))
	makeBarrier("HubPerimeterBarrier_East",  Vector3.new(6, hubBarrierH, plazaSize + 30), CFrame.new(halfP + 2, FLOOR_Y + hubBarrierH / 2, 0))

	-- Bridge & Overlook Background Scenic Boundaries
	makeBarrier("SafetyWall_OverlookS", Vector3.new(45, 16, 2), CFrame.new(0, FLOOR_Y + 8, overlookZ + 18))
	makeBarrier("SafetyWall_OverlookW", Vector3.new(2, 16, 35), CFrame.new(-18, FLOOR_Y + 8, overlookZ))
	makeBarrier("SafetyWall_OverlookE", Vector3.new(2, 16, 35), CFrame.new(18, FLOOR_Y + 8, overlookZ))
	makeBarrier("SafetyWall_BridgeW", Vector3.new(2, 16, bridgeLen), CFrame.new(-bridgeWidth / 2 - 1, FLOOR_Y + 8, bridgeCenterZ))
	makeBarrier("SafetyWall_BridgeE", Vector3.new(2, 16, bridgeLen), CFrame.new(bridgeWidth / 2 + 1, FLOOR_Y + 8, bridgeCenterZ))

	-- ── 10. SURROUNDING ALPINE MOUNTAIN VISTA & LANDSCAPE ──────────────────────
	makePart(hub, "ChasmBottom", Vector3.new(340, 4, 340), CFrame.new(0, FLOOR_Y - 28, 0), Color3.fromRGB(28, 30, 34), Enum.Material.Slate)

	local mountainSpawns = {
		{ pos = Vector3.new(-120, FLOOR_Y - 10, -120), size = Vector3.new(70, 55, 70), rot = 35 },
		{ pos = Vector3.new(120, FLOOR_Y - 10, -120),  size = Vector3.new(70, 55, 70), rot = -35 },
		{ pos = Vector3.new(-130, FLOOR_Y - 10, 0),     size = Vector3.new(65, 48, 65), rot = 15 },
		{ pos = Vector3.new(130, FLOOR_Y - 10, 0),      size = Vector3.new(65, 48, 65), rot = -15 },
		{ pos = Vector3.new(-110, FLOOR_Y - 10, 110),   size = Vector3.new(60, 45, 60), rot = 55 },
		{ pos = Vector3.new(110, FLOOR_Y - 10, 110),    size = Vector3.new(60, 45, 60), rot = -55 },
		{ pos = Vector3.new(0, FLOOR_Y - 15, -135),     size = Vector3.new(90, 60, 50), rot = 0 },
	}
	for i, m in ipairs(mountainSpawns) do
		pcall(function()
			makePart(hub, "MountainBase_" .. i, m.size,
				CFrame.new(m.pos) * CFrame.Angles(0, math.rad(m.rot), 0), Color3.fromRGB(50, 52, 58), Enum.Material.Rock)
			makeWedge(hub, "MountainPeak_" .. i, Vector3.new(m.size.X * 0.8, 28, m.size.Z * 0.8),
				CFrame.new(m.pos + Vector3.new(0, m.size.Y / 2 + 14, 0)) * CFrame.Angles(0, math.rad(m.rot), 0), Color3.fromRGB(42, 45, 50), Enum.Material.Slate)
		end)
	end

	-- Clusters of Alpine Pine Trees
	local treeSpawns = {
		Vector3.new(-105, FLOOR_Y - 4, -85), Vector3.new(-115, FLOOR_Y - 4, -70),
		Vector3.new(105, FLOOR_Y - 4, -85),  Vector3.new(115, FLOOR_Y - 4, -70),
		Vector3.new(-100, FLOOR_Y - 4, 35),  Vector3.new(-110, FLOOR_Y - 4, 50),
		Vector3.new(100, FLOOR_Y - 4, 35),   Vector3.new(110, FLOOR_Y - 4, 50),
		Vector3.new(-35, FLOOR_Y - 4, 115),  Vector3.new(35, FLOOR_Y - 4, 115),
	}
	for _, tPos in ipairs(treeSpawns) do
		makePineTree(hub, tPos, 1.4)
	end

	-- ── 11. STREET LAMPS AROUND THE TOWN SQUARE ───────────────────────────────
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, -25))
	makeStreetLamp(hub, Vector3.new(-25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(25, FLOOR_Y, 25))
	makeStreetLamp(hub, Vector3.new(-50, FLOOR_Y, -30))
	makeStreetLamp(hub, Vector3.new(50, FLOOR_Y, -30))
	makeStreetLamp(hub, Vector3.new(-22, FLOOR_Y, 60))
	makeStreetLamp(hub, Vector3.new(22, FLOOR_Y, 60))

	-- ── 12. CINEMATIC ATMOSPHERIC LIGHTING & POST-PROCESSING ──────────────────
	pcall(function()
		Lighting.ClockTime = 16.6
		Lighting.Brightness = 1.15
		Lighting.Ambient = Color3.fromRGB(65, 70, 80)
		Lighting.OutdoorAmbient = Color3.fromRGB(80, 85, 95)
		Lighting.GlobalShadows = true
		Lighting.ShadowSoftness = 0.2

		-- Clean up ALL existing Atmosphere, Bloom, or ColorCorrection so duplicates never stack
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("BloomEffect") or child:IsA("Atmosphere") or child:IsA("ColorCorrectionEffect") then
				child:Destroy()
			end
		end

		local atmo = Instance.new("Atmosphere")
		atmo.Name = "SoulforgeAtmosphere"
		atmo.Density = 0.28
		atmo.Offset = 0.22
		atmo.Color = Color3.fromRGB(190, 205, 230)
		atmo.Decay = Color3.fromRGB(135, 120, 145)
		atmo.Glare = 0.0
		atmo.Haze = 0.15
		atmo.Parent = Lighting

		-- Calibrated Bloom: Threshold 2.8 ensures ONLY true intense neon/spells bloom,
		-- preventing character skin, faces, clothes, marble, and ground from glowing.
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "SoulforgeBloom"
		bloom.Intensity = 0.16
		bloom.Size = 12
		bloom.Threshold = 2.8
		bloom.Parent = Lighting

		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "SoulforgeColorCorrection"
		cc.Contrast = 0.05
		cc.Saturation = 0.06
		cc.TintColor = Color3.fromRGB(255, 252, 248)
		cc.Parent = Lighting
	end)

	hub.Parent = workspace
	return hub
end

function HubMapService.Cleanup()
	if hubFolder and hubFolder.Parent then
		hubFolder:Destroy()
	end
	hubFolder = nil

	pcall(function()
		local atmo = Lighting:FindFirstChild("SoulforgeAtmosphere")
		if atmo then atmo:Destroy() end
		local bloom = Lighting:FindFirstChild("SoulforgeBloom")
		if bloom then bloom:Destroy() end
		local cc = Lighting:FindFirstChild("SoulforgeColorCorrection")
		if cc then cc:Destroy() end
	end)
end

return HubMapService
