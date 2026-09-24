-- src/ServerScriptService/Services/SunforgedCitadelMapService.lua
-- Generates and manages the physical MMO dungeon architecture for the Sunforged Citadel (Tier 2 Dungeon).
-- Features a 3x expanded, grand celestial fortress with multiple exploration wings,
-- 2 cross-wing shortcut doors (linking distant sections door-to-door),
-- gentle stepped grand colonnades (no steep walls), and the Solar Throne Colosseum.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SunforgedCitadelMapService = {}

local arenaFolder: Model? = nil
local bossGate: Model? = nil
local gateBarrierPart: Part? = nil
local doorLeft: BasePart? = nil
local doorRight: BasePart? = nil
local gatePrompt: ProximityPrompt? = nil
local gateStatusLabel: TextLabel? = nil
local gateTitleLabel: TextLabel? = nil

local isGateUnlocked = false
local isGateOpen = false
local onGateOpenedCallback: (() -> ())? = nil
local onGateOpenRequestedCallback: (() -> ())? = nil

-- Cross-wing shortcut state tracking
local shortcuts = {
	shortcut_crypt_vault = {
		isOpen = false,
		doorL = nil :: BasePart?,
		doorR = nil :: BasePart?,
		prompt = nil :: ProximityPrompt?,
	},
	shortcut_transept_portcullis = {
		isOpen = false,
		gatePart = nil :: BasePart?,
		prompt = nil :: ProximityPrompt?,
	},
}

-- Visual styling constants — Sunforged Celestial Marble & Solar Gold
local MARBLE_WHITE   = Color3.fromRGB(230, 228, 222)
local MARBLE_FLOOR   = Color3.fromRGB(210, 205, 195)
local GOLD_ACCENT    = Color3.fromRGB(225, 185, 65)
local GOLD_DARK      = Color3.fromRGB(160, 125, 40)
local BRONZE_METAL   = Color3.fromRGB(90, 75, 55)
local SOLAR_ORANGE   = Color3.fromRGB(255, 135, 30)
local CELESTIAL_BLUE = Color3.fromRGB(100, 180, 255)
local DESERT_STONE   = Color3.fromRGB(180, 160, 135)

local WALL_HEIGHT = 28
local FLOOR_Y = 1

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

local function makeFloor(parent: Instance, name: string, minX: number, maxX: number, minZ: number, maxZ: number, yLevel: number?): Part
	local y = yLevel or FLOOR_Y
	local size = Vector3.new(math.abs(maxX - minX), 2, math.abs(maxZ - minZ))
	local cframe = CFrame.new((minX + maxX) / 2, y, (minZ + maxZ) / 2)
	return makePart(parent, name .. "_Floor", size, cframe, MARBLE_FLOOR, Enum.Material.Marble)
end

local function makeCeiling(parent: Instance, name: string, minX: number, maxX: number, minZ: number, maxZ: number, height: number?, yBase: number?): Part
	local base = yBase or FLOOR_Y
	local h = height or WALL_HEIGHT
	local size = Vector3.new(math.abs(maxX - minX), 2, math.abs(maxZ - minZ))
	local cframe = CFrame.new((minX + maxX) / 2, base + h, (minZ + maxZ) / 2)
	return makePart(parent, name .. "_Ceiling", size, cframe, MARBLE_WHITE, Enum.Material.Marble)
end

local function makeWallX(parent: Instance, name: string, minX: number, maxX: number, zCenter: number, thickness: number, minY: number?, maxY: number?, yOffset: number?): Part
	local yOff = yOffset or FLOOR_Y
	local y0 = minY or 0
	local y1 = maxY or WALL_HEIGHT
	local size = Vector3.new(math.abs(maxX - minX), y1 - y0, thickness)
	local cframe = CFrame.new((minX + maxX) / 2, yOff + (y0 + y1) / 2, zCenter)
	return makePart(parent, name, size, cframe, MARBLE_WHITE, Enum.Material.Marble)
end

local function makeWallZ(parent: Instance, name: string, xCenter: number, minZ: number, maxZ: number, thickness: number, minY: number?, maxY: number?, yOffset: number?): Part
	local yOff = yOffset or FLOOR_Y
	local y0 = minY or 0
	local y1 = maxY or WALL_HEIGHT
	local size = Vector3.new(thickness, y1 - y0, math.abs(maxZ - minZ))
	local cframe = CFrame.new(xCenter, yOff + (y0 + y1) / 2, (minZ + maxZ) / 2)
	return makePart(parent, name, size, cframe, MARBLE_WHITE, Enum.Material.Marble)
end

local function makeSolarBrazier(parent: Instance, position: Vector3, lightColor: Color3?)
	local col = lightColor or SOLAR_ORANGE
	makePart(parent, "BrazierBase", Vector3.new(3.5, 3, 3.5), CFrame.new(position + Vector3.new(0, 1.5, 0)), GOLD_DARK, Enum.Material.Metal)
	makePart(parent, "BrazierBowl", Vector3.new(4.5, 1.2, 4.5), CFrame.new(position + Vector3.new(0, 3.6, 0)), GOLD_ACCENT, Enum.Material.Metal)

	local flame = Instance.new("Part")
	flame.Name = "SolarFlame"
	flame.Size = Vector3.new(2, 0.6, 2)
	flame.CFrame = CFrame.new(position + Vector3.new(0, 4.4, 0))
	flame.Color = col
	flame.Material = Enum.Material.Neon
	flame.Anchored = true
	flame.CanCollide = false
	flame.Parent = parent

	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Color = col
	fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
	fire.Parent = flame

	local light = Instance.new("PointLight")
	light.Color = col
	light.Brightness = 3.5
	light.Range = 36
	light.Shadows = true
	light.Parent = flame
end

local function makeGoldenPillar(parent: Instance, position: Vector3, height: number, width: number)
	makePart(parent, "Pillar", Vector3.new(width, height, width), CFrame.new(position + Vector3.new(0, height / 2, 0)), MARBLE_WHITE, Enum.Material.Marble)
	makePart(parent, "PillarBase", Vector3.new(width + 1.2, 2.5, width + 1.2), CFrame.new(position + Vector3.new(0, 1.25, 0)), GOLD_DARK, Enum.Material.Metal)
	makePart(parent, "PillarCap", Vector3.new(width + 1.2, 2.5, width + 1.2), CFrame.new(position + Vector3.new(0, height - 1.25, 0)), GOLD_ACCENT, Enum.Material.Metal)
end

-- ============================================================================
-- 3D MESH ASSET DEFINITIONS & HIGH-FIDELITY DECORATION BUILDERS
-- ============================================================================
local MESH_ASSETS = {
	GUARDIAN = {
		name = "PortalGuardianStatue",
		meshId = "rbxassetid://124679527409967",
		textureId = "rbxassetid://134441413553055",
		baseSize = Vector3.new(5, 11, 5),
	},
	SERAPH = {
		name = "ShrineSeraphIdol",
		meshId = "rbxassetid://111513548414082",
		textureId = "rbxassetid://96129369000308",
		baseSize = Vector3.new(6, 6, 2),
	},
	DRAGON = {
		name = "FountainDragonStatue",
		meshId = "rbxassetid://136069627854899",
		textureId = "rbxassetid://139266328436174",
		baseSize = Vector3.new(6, 10, 6),
	},
	CAPSTONE = {
		name = "PortalArchCapstone",
		meshId = "rbxassetid://75585422571738",
		textureId = "rbxassetid://137556938497758",
		baseSize = Vector3.new(3.84, 5, 3.83),
	},
	BANNER = {
		name = "WatchtowerBanner",
		meshId = "rbxassetid://78548585350116",
		textureId = "rbxassetid://80368395271356",
		baseSize = Vector3.new(2, 2.72, 0.4),
	},
	SHIELD = {
		name = "ForgeDisplayShield",
		meshId = "rbxassetid://109237508888055",
		textureId = "rbxassetid://90345909167702",
		baseSize = Vector3.new(1.4, 2.17, 0.6),
	},
	DOOR_LEFT = {
		name = "BossVaultDoor_Left",
		meshId = "rbxassetid://138323525682816",
		textureId = "rbxassetid://106251618778890",
		baseSize = Vector3.new(4.44, 5.34, 2.5),
	},
	DOOR_RIGHT = {
		name = "BossVaultDoor_Right",
		meshId = "rbxassetid://127394666403021",
		textureId = "rbxassetid://77648884602587",
		baseSize = Vector3.new(6.25, 11.31, 2.5),
	},
}

local function spawnMeshAsset(parent: Instance, assetKey: string, cframe: CFrame, scaleFactor: number?, canCollide: boolean?): Instance?
	local info = MESH_ASSETS[assetKey]
	if not info then return nil end

	local scale = scaleFactor or 1
	local collide = (canCollide == true)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")

	-- Primary: Clone studio template if present
	if assetsFolder then
		local template = assetsFolder:FindFirstChild(info.name)
		if template then
			local clone = template:Clone()
			if clone:IsA("Model") then
				local geom = clone:FindFirstChildWhichIsA("MeshPart", true) or clone:FindFirstChildWhichIsA("BasePart", true)
				if geom then
					clone.PrimaryPart = geom
					for _, bp in ipairs(clone:GetDescendants()) do
						if bp:IsA("BasePart") then
							bp.Anchored = true
							bp.CanCollide = collide
							bp.CastShadow = true
						end
					end
					if scale ~= 1 then
						clone:ScaleTo(scale)
					end
					clone:PivotTo(cframe)
					clone.Parent = parent
					return clone
				end
			elseif clone:IsA("BasePart") then
				clone.Anchored = true
				clone.CanCollide = collide
				clone.CastShadow = true
				if scale ~= 1 then
					clone.Size = clone.Size * scale
				end
				clone.CFrame = cframe
				clone.Parent = parent
				return clone
			end
		end
	end

	-- Procedural SpecialMesh Part Fallback (zero dependency, always succeeds)
	local part = Instance.new("Part")
	part.Name = info.name
	part.Size = info.baseSize * scale
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = collide
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.FileMesh
	sm.MeshId = info.meshId
	sm.TextureId = info.textureId
	sm.Scale = Vector3.new(scale, scale, scale)
	sm.Parent = part

	part.Parent = parent
	return part
end

local function spawnGuardianStatue(parent: Instance, pos: Vector3, rotY: number, scale: number?)
	local s = scale or 1.25
	local model = Instance.new("Model")
	model.Name = "CitadelGuardianStatue"
	model.Parent = parent

	-- Tiered Marble & Gold Pedestal
	local rotCF = CFrame.Angles(0, rotY, 0)
	makePart(model, "PedestalBase", Vector3.new(7 * s, 2.5 * s, 7 * s), CFrame.new(pos + Vector3.new(0, 1.25 * s, 0)) * rotCF, MARBLE_WHITE, Enum.Material.Marble)
	makePart(model, "PedestalTrim", Vector3.new(6.2 * s, 0.8 * s, 6.2 * s), CFrame.new(pos + Vector3.new(0, 2.9 * s, 0)) * rotCF, GOLD_DARK, Enum.Material.Metal)
	local pedTop = makePart(model, "PedestalTop", Vector3.new(5.6 * s, 0.8 * s, 5.6 * s), CFrame.new(pos + Vector3.new(0, 3.7 * s, 0)) * rotCF, MARBLE_WHITE, Enum.Material.Marble)

	local statueY = pos.Y + (4.1 * s) + (5.5 * s)
	local statueCF = CFrame.new(pos.X, statueY, pos.Z) * rotCF
	spawnMeshAsset(model, "GUARDIAN", statueCF, s, false)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 120)
	light.Brightness = 1.6
	light.Range = 22 * s
	light.Parent = pedTop

	return model
end

local function spawnSeraphIdol(parent: Instance, pos: Vector3, rotY: number, scale: number?)
	local s = scale or 1.5
	local model = Instance.new("Model")
	model.Name = "CelestialSeraphIdol"
	model.Parent = parent

	local rotCF = CFrame.Angles(0, rotY, 0)
	makePart(model, "PlinthBase", Vector3.new(4.5 * s, 2.8 * s, 4.5 * s), CFrame.new(pos + Vector3.new(0, 1.4 * s, 0)) * rotCF, GOLD_DARK, Enum.Material.Metal)
	makePart(model, "PlinthShaft", Vector3.new(3.8 * s, 2 * s, 3.8 * s), CFrame.new(pos + Vector3.new(0, 3.8 * s, 0)) * rotCF, MARBLE_WHITE, Enum.Material.Marble)
	local pedCap = makePart(model, "PlinthCap", Vector3.new(4.2 * s, 0.6 * s, 4.2 * s), CFrame.new(pos + Vector3.new(0, 5.1 * s, 0)) * rotCF, GOLD_ACCENT, Enum.Material.Metal)

	local idolY = pos.Y + (5.4 * s) + (3.0 * s)
	local idolCF = CFrame.new(pos.X, idolY, pos.Z) * rotCF
	spawnMeshAsset(model, "SERAPH", idolCF, s, false)

	local light = Instance.new("PointLight")
	light.Color = CELESTIAL_BLUE
	light.Brightness = 2.4
	light.Range = 26 * s
	light.Parent = pedCap

	return model
end

local function spawnDragonStatue(parent: Instance, pos: Vector3, rotY: number, scale: number?)
	local s = scale or 1.2
	local model = Instance.new("Model")
	model.Name = "SunforgedDragonStatue"
	model.Parent = parent

	local rotCF = CFrame.Angles(0, rotY, 0)
	makePart(model, "DragonPlinthBase", Vector3.new(6.5 * s, 2 * s, 6.5 * s), CFrame.new(pos + Vector3.new(0, 1.0 * s, 0)) * rotCF, BRONZE_METAL, Enum.Material.Metal)
	local pedTop = makePart(model, "DragonPlinthTop", Vector3.new(5.8 * s, 1 * s, 5.8 * s), CFrame.new(pos + Vector3.new(0, 2.5 * s, 0)) * rotCF, GOLD_DARK, Enum.Material.Metal)

	local dragonY = pos.Y + (3.0 * s) + (5.0 * s)
	local dragonCF = CFrame.new(pos.X, dragonY, pos.Z) * rotCF
	spawnMeshAsset(model, "DRAGON", dragonCF, s, false)

	local light = Instance.new("PointLight")
	light.Color = SOLAR_ORANGE
	light.Brightness = 2.2
	light.Range = 24 * s
	light.Parent = pedTop

	return model
end

local function spawnArchCapstone(parent: Instance, pos: Vector3, rotY: number, scale: number?)
	local s = scale or 1.3
	local capCF = CFrame.new(pos) * CFrame.Angles(0, rotY, 0)
	return spawnMeshAsset(parent, "CAPSTONE", capCF, s, false)
end

local function spawnWallBanner(parent: Instance, pos: Vector3, rotY: number, scale: number?)
	local s = scale or 3.2
	local bannerModel = Instance.new("Model")
	bannerModel.Name = "CitadelWallBanner"
	bannerModel.Parent = parent

	local rotCF = CFrame.Angles(0, rotY, 0)
	local rod = Instance.new("Part")
	rod.Name = "BannerRod"
	rod.Size = Vector3.new(3.6 * s, 0.4 * s, 0.4 * s)
	rod.CFrame = CFrame.new(pos) * rotCF
	rod.Color = GOLD_DARK
	rod.Material = Enum.Material.Metal
	rod.Anchored = true
	rod.CanCollide = false
	rod.Parent = bannerModel

	local bannerY = pos.Y - (1.35 * s)
	local bannerCF = CFrame.new(pos.X, bannerY, pos.Z) * rotCF
	spawnMeshAsset(bannerModel, "BANNER", bannerCF, s, false)

	return bannerModel
end

local function spawnHeraldicShield(parent: Instance, pos: Vector3, rotY: number, scale: number?)
	local s = scale or 2.5
	local shieldCF = CFrame.new(pos) * CFrame.Angles(0, rotY, 0)
	return spawnMeshAsset(parent, "SHIELD", shieldCF, s, false)
end

local function spawnCelestialOrrery(parent: Instance, centerPos: Vector3)
	local orrery = Instance.new("Model")
	orrery.Name = "CelestialOrreryOfSol"
	orrery.Parent = parent

	-- Tiered Marble and Gold Dais
	makePart(orrery, "OrreryDais_1", Vector3.new(22, 1.5, 22), CFrame.new(centerPos + Vector3.new(0, 0.75, 0)), GOLD_DARK, Enum.Material.Marble)
	makePart(orrery, "OrreryDais_2", Vector3.new(17, 1.5, 17), CFrame.new(centerPos + Vector3.new(0, 2.25, 0)), MARBLE_WHITE, Enum.Material.Marble)
	makePart(orrery, "OrreryDais_3", Vector3.new(13, 1.2, 13), CFrame.new(centerPos + Vector3.new(0, 3.6, 0)), GOLD_ACCENT, Enum.Material.Metal)

	-- Spindle and Ring Base
	makePart(orrery, "SpindleShaft", Vector3.new(3.5, 10, 3.5), CFrame.new(centerPos + Vector3.new(0, 8.5, 0)), GOLD_DARK, Enum.Material.Metal)

	local coreY = centerPos.Y + 16
	local core = Instance.new("Part")
	core.Name = "SunstoneCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(6.5, 6.5, 6.5)
	core.CFrame = CFrame.new(centerPos.X, coreY, centerPos.Z)
	core.Color = Color3.fromRGB(255, 205, 45)
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.Parent = orrery

	local coreLight = Instance.new("PointLight")
	coreLight.Color = Color3.fromRGB(255, 190, 50)
	coreLight.Brightness = 4.5
	coreLight.Range = 50
	coreLight.Shadows = true
	coreLight.Parent = core

	-- Concentric armillary gimbal rings
	local ringAngles = {
		Vector3.new(0, 0, 0),
		Vector3.new(35, 25, 0),
		Vector3.new(-35, 75, 0),
		Vector3.new(65, -45, 0),
	}
	local ringRadii = { 11, 14, 17, 20 }

	for i, radius in ipairs(ringRadii) do
		local ringAngle = ringAngles[i]
		local ringPart = Instance.new("Part")
		ringPart.Name = "ArmillaryRing_" .. i
		ringPart.Size = Vector3.new(radius * 2, 0.8, radius * 2)
		ringPart.CFrame = CFrame.new(centerPos.X, coreY, centerPos.Z) * CFrame.Angles(math.rad(ringAngle.X), math.rad(ringAngle.Y), math.rad(ringAngle.Z))
		ringPart.Color = (i % 2 == 0) and GOLD_ACCENT or GOLD_DARK
		ringPart.Material = Enum.Material.Metal
		ringPart.Anchored = true
		ringPart.CanCollide = false
		ringPart.Parent = orrery

		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Cylinder
		sm.Scale = Vector3.new(0.3, 1, 1)
		sm.Parent = ringPart
	end

	-- Orbital rotation animation
	task.spawn(function()
		local angle = 0
		while orrery.Parent do
			angle = (angle + 1) % 360
			core.CFrame = CFrame.new(centerPos.X, coreY + math.sin(math.rad(angle * 2)) * 0.7, centerPos.Z) * CFrame.Angles(0, math.rad(angle), 0)
			task.wait(0.04)
		end
	end)

	return orrery
end

-- Constructs a physical, completely walkable staircase (slope < 22 degrees)
local function makeStairs(parent: Instance, name: string, minX: number, maxX: number, startZ: number, endZ: number, startY: number, endY: number, numSteps: number)
	local width = math.abs(maxX - minX)
	local totalDepth = math.abs(endZ - startZ)
	local totalHeight = endY - startY
	local stepDepth = totalDepth / numSteps
	local stepHeight = totalHeight / numSteps
	local stepZDir = (endZ >= startZ) and 1 or -1

	local stairsFolder = Instance.new("Folder")
	stairsFolder.Name = name .. "_Stairs"
	stairsFolder.Parent = parent

	-- Solid smooth walkable wedge base underlay
	local rampWedge = Instance.new("WedgePart")
	rampWedge.Name = name .. "_WedgeBase"
	rampWedge.Size = Vector3.new(width, totalHeight, totalDepth)
	local wedgeCenterY = startY + (totalHeight / 2)
	local wedgeCenterZ = (startZ + endZ) / 2
	local wedgeRot = (endZ >= startZ) and 0 or math.pi
	rampWedge.CFrame = CFrame.new((minX + maxX) / 2, wedgeCenterY, wedgeCenterZ) * CFrame.Angles(0, wedgeRot, 0)
	rampWedge.Color = MARBLE_FLOOR
	rampWedge.Material = Enum.Material.Marble
	rampWedge.Anchored = true
	rampWedge.CanCollide = true
	rampWedge.Parent = stairsFolder

	-- Stepped treads for visual and tactile fidelity
	for i = 1, numSteps do
		local curY = startY + (i * stepHeight)
		local curZ = startZ + ((i - 0.5) * stepDepth * stepZDir)
		local step = makePart(stairsFolder, ("%s_Step_%d"):format(name, i), Vector3.new(width, stepHeight, stepDepth + 0.1), CFrame.new((minX + maxX) / 2, curY - (stepHeight / 2), curZ), GOLD_DARK, Enum.Material.Marble)
		step.CanCollide = true
	end
end

-- Constructs a massive radiant golden sun disc door leaf
local function createSunforgedDoorLeaf(parent: Instance, doorName: string, isLeft: boolean, size: Vector3, cframe: CFrame): BasePart
	local doorBase = Instance.new("Part")
	doorBase.Name = doorName
	doorBase.Size = size
	doorBase.CFrame = cframe
	doorBase.Color = GOLD_DARK
	doorBase.Material = Enum.Material.Metal
	doorBase.Anchored = true
	doorBase.CanCollide = true
	doorBase.Parent = parent

	local function addDetail(pSize: Vector3, pCFrame: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = "DoorDetail"
		p.Size = pSize
		p.CFrame = pCFrame
		p.Color = color
		p.Material = material
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Parent = doorBase

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = doorBase
		weld.Part1 = p
		weld.Parent = doorBase
		return p
	end

	-- Golden Sunburst Relief Inlay
	addDetail(Vector3.new(size.X * 0.8, size.Y * 0.75, 0.4), cframe * CFrame.new(0, 0, 1.4), GOLD_ACCENT, Enum.Material.Metal)
	addDetail(Vector3.new(size.X * 0.5, size.Y * 0.5, 0.6), cframe * CFrame.new(0, 0, 1.6), Color3.fromRGB(255, 210, 80), Enum.Material.Neon)
	addDetail(Vector3.new(size.X * 0.8, size.Y * 0.75, 0.4), cframe * CFrame.new(0, 0, -1.4), GOLD_ACCENT, Enum.Material.Metal)

	-- 3D Mesh Vault Relief Overlay welded to the door leaf
	local doorMeshKey = isLeft and "DOOR_LEFT" or "DOOR_RIGHT"
	local meshPart = spawnMeshAsset(doorBase, doorMeshKey, cframe * CFrame.new(0, 0, 1.6), 1, false)
	if meshPart then
		if meshPart:IsA("Model") then
			for _, bp in ipairs(meshPart:GetDescendants()) do
				if bp:IsA("BasePart") then
					bp.Anchored = false
					bp.CanCollide = false
					bp.Massless = true
					local w = Instance.new("WeldConstraint")
					w.Part0 = doorBase
					w.Part1 = bp
					w.Parent = doorBase
				end
			end
		elseif meshPart:IsA("BasePart") then
			meshPart.Anchored = false
			meshPart.CanCollide = false
			meshPart.Massless = true
			meshPart.Size = Vector3.new(size.X * 0.85, size.Y * 0.95, 2)
			meshPart.CFrame = cframe * CFrame.new(0, 0, 1.6)
			local w = Instance.new("WeldConstraint")
			w.Part0 = doorBase
			w.Part1 = meshPart
			w.Parent = doorBase
		end
	end

	return doorBase
end

-- ============================================================================
-- SHORTCUT 1: West Crypts to Grand Archives (Door-to-Door passage)
-- Connects outer crypts (Z = -950, X = -80) directly to Grand Archives (Z = -750, X = -80)
-- ============================================================================
local function setupCryptToArchivesShortcut(dungeon: Model, passagePos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Shortcut_CryptVault"
	model.Parent = dungeon

	local doorX = passagePos.X
	local doorY = passagePos.Y
	local doorZ = passagePos.Z

	-- Portal Archway
	makePart(model, "Arch_L", Vector3.new(3, WALL_HEIGHT, 4), CFrame.new(doorX - 7.5, doorY + WALL_HEIGHT/2, doorZ), GOLD_DARK, Enum.Material.Metal)
	makePart(model, "Arch_R", Vector3.new(3, WALL_HEIGHT, 4), CFrame.new(doorX + 7.5, doorY + WALL_HEIGHT/2, doorZ), GOLD_DARK, Enum.Material.Metal)
	makePart(model, "Arch_Top", Vector3.new(18, 4, 5), CFrame.new(doorX, doorY + WALL_HEIGHT - 2, doorZ), GOLD_ACCENT, Enum.Material.Metal)

	-- 3D Mesh Arch Capstone & Heraldic Shields
	spawnArchCapstone(model, Vector3.new(doorX, doorY + WALL_HEIGHT + 1, doorZ), 0, 1.4)
	spawnHeraldicShield(model, Vector3.new(doorX - 7.5, doorY + 14, doorZ + 2.3), 0, 2.0)
	spawnHeraldicShield(model, Vector3.new(doorX + 7.5, doorY + 14, doorZ + 2.3), 0, 2.0)

	-- Double heavy bronze vault doors
	local doorL = makePart(model, "VaultDoor_L", Vector3.new(6, WALL_HEIGHT - 4, 1.5), CFrame.new(doorX - 3, doorY + (WALL_HEIGHT - 4)/2, doorZ), BRONZE_METAL, Enum.Material.Metal)
	local doorR = makePart(model, "VaultDoor_R", Vector3.new(6, WALL_HEIGHT - 4, 1.5), CFrame.new(doorX + 3, doorY + (WALL_HEIGHT - 4)/2, doorZ), BRONZE_METAL, Enum.Material.Metal)
	shortcuts.shortcut_crypt_vault.doorL = doorL
	shortcuts.shortcut_crypt_vault.doorR = doorR

	-- Locked side examination prompt (North/Crypt side at doorZ - 3)
	local cryptSidePart = Instance.new("Part")
	cryptSidePart.Size = Vector3.new(4, 4, 2)
	cryptSidePart.CFrame = CFrame.new(doorX, doorY + 4, doorZ - 4)
	cryptSidePart.Transparency = 1
	cryptSidePart.Anchored = true
	cryptSidePart.CanCollide = false
	cryptSidePart.Parent = model

	local cryptPrompt = Instance.new("ProximityPrompt")
	cryptPrompt.ActionText = "Examine Vault Door"
	cryptPrompt.ObjectText = "Barred from the inside"
	cryptPrompt.MaxActivationDistance = 14
	cryptPrompt.HoldDuration = 0.3
	cryptPrompt.RequiresLineOfSight = false
	cryptPrompt.Parent = cryptSidePart

	cryptPrompt.Triggered:Connect(function(player)
		if not shortcuts.shortcut_crypt_vault.isOpen then
			cryptPrompt.ActionText = "Barred from Archives side"
			task.delay(2.0, function()
				if cryptPrompt and not shortcuts.shortcut_crypt_vault.isOpen then
					cryptPrompt.ActionText = "Examine Vault Door"
				end
			end)
		end
	end)

	-- Unlock mechanism on the Archives side (South side at doorZ + 4)
	local unlockPart = Instance.new("Part")
	unlockPart.Size = Vector3.new(4, 4, 2)
	unlockPart.CFrame = CFrame.new(doorX, doorY + 4, doorZ + 4)
	unlockPart.Transparency = 1
	unlockPart.Anchored = true
	unlockPart.CanCollide = false
	unlockPart.Parent = model

	local unlockPrompt = Instance.new("ProximityPrompt")
	unlockPrompt.ActionText = "Unlock Shortcut Door"
	unlockPrompt.ObjectText = "West Crypts Passage"
	unlockPrompt.MaxActivationDistance = 14
	unlockPrompt.HoldDuration = 1.0
	unlockPrompt.RequiresLineOfSight = false
	unlockPrompt.Parent = unlockPart
	shortcuts.shortcut_crypt_vault.prompt = unlockPrompt

	unlockPrompt.Triggered:Connect(function(player)
		if shortcuts.shortcut_crypt_vault.isOpen then return end
		shortcuts.shortcut_crypt_vault.isOpen = true
		unlockPrompt.Enabled = false
		cryptPrompt.Enabled = false

		doorL.CanCollide = false
		doorR.CanCollide = false
		local openL = CFrame.new(doorX - 6, doorY + (WALL_HEIGHT - 4)/2, doorZ) * CFrame.Angles(0, math.rad(-90), 0)
		local openR = CFrame.new(doorX + 6, doorY + (WALL_HEIGHT - 4)/2, doorZ) * CFrame.Angles(0, math.rad(90), 0)
		TweenService:Create(doorL, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = openL }):Play()
		TweenService:Create(doorR, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = openR }):Play()
	end)
end

-- ============================================================================
-- SHORTCUT 2: East Sunken Tombs to Grand Solar Cathedral (Door-to-Door passage)
-- Connects East Tombs (Z = -900, X = 80) directly to Cathedral Transept (Z = -550, X = 70)
-- ============================================================================
local function setupTombsToCathedralShortcut(dungeon: Model, gatePos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Shortcut_TombsPortcullis"
	model.Parent = dungeon

	local gateX = gatePos.X
	local gateY = gatePos.Y
	local gateZ = gatePos.Z

	-- Portal Archway
	makePart(model, "PortcullisArch_L", Vector3.new(3, WALL_HEIGHT, 4), CFrame.new(gateX - 7.5, gateY + WALL_HEIGHT/2, gateZ), GOLD_DARK, Enum.Material.Metal)
	makePart(model, "PortcullisArch_R", Vector3.new(3, WALL_HEIGHT, 4), CFrame.new(gateX + 7.5, gateY + WALL_HEIGHT/2, gateZ), GOLD_DARK, Enum.Material.Metal)
	makePart(model, "PortcullisArch_Top", Vector3.new(18, 4, 5), CFrame.new(gateX, gateY + WALL_HEIGHT - 2, gateZ), GOLD_ACCENT, Enum.Material.Metal)

	-- 3D Mesh Arch Capstone & Heraldic Shields
	spawnArchCapstone(model, Vector3.new(gateX, gateY + WALL_HEIGHT + 1, gateZ), 0, 1.4)
	spawnHeraldicShield(model, Vector3.new(gateX - 7.5, gateY + 14, gateZ + 2.3), 0, 2.0)
	spawnHeraldicShield(model, Vector3.new(gateX + 7.5, gateY + 14, gateZ + 2.3), 0, 2.0)

	-- Heavy iron grate
	local grate = makePart(model, "TranseptGrate", Vector3.new(12, WALL_HEIGHT - 4, 1.2), CFrame.new(gateX, gateY + (WALL_HEIGHT - 4)/2, gateZ), BRONZE_METAL, Enum.Material.Metal)
	shortcuts.shortcut_transept_portcullis.gatePart = grate

	-- Locked side (East Tombs side at gateZ - 4)
	local tombsSidePart = Instance.new("Part")
	tombsSidePart.Size = Vector3.new(4, 4, 2)
	tombsSidePart.CFrame = CFrame.new(gateX, gateY + 4, gateZ - 4)
	tombsSidePart.Transparency = 1
	tombsSidePart.Anchored = true
	tombsSidePart.CanCollide = false
	tombsSidePart.Parent = model

	local tombsPrompt = Instance.new("ProximityPrompt")
	tombsPrompt.ActionText = "Examine Iron Portcullis"
	tombsPrompt.ObjectText = "Mechanism locked from Cathedral"
	tombsPrompt.MaxActivationDistance = 14
	tombsPrompt.HoldDuration = 0.3
	tombsPrompt.RequiresLineOfSight = false
	tombsPrompt.Parent = tombsSidePart

	tombsPrompt.Triggered:Connect(function(player)
		if not shortcuts.shortcut_transept_portcullis.isOpen then
			tombsPrompt.ActionText = "Cannot lift from this side"
			task.delay(2.0, function()
				if tombsPrompt and not shortcuts.shortcut_transept_portcullis.isOpen then
					tombsPrompt.ActionText = "Examine Iron Portcullis"
				end
			end)
		end
	end)

	-- Winch mechanism on Cathedral side (gateZ + 4)
	local winchWheel = makePart(model, "TranseptWinch", Vector3.new(2, 2, 0.8), CFrame.new(gateX + 7, gateY + 4, gateZ + 3.5), GOLD_ACCENT, Enum.Material.Metal)

	local winchPrompt = Instance.new("ProximityPrompt")
	winchPrompt.ActionText = "Raise Transept Portcullis"
	winchPrompt.ObjectText = "Shortcut Passage"
	winchPrompt.MaxActivationDistance = 14
	winchPrompt.HoldDuration = 1.0
	winchPrompt.RequiresLineOfSight = false
	winchPrompt.Parent = winchWheel
	shortcuts.shortcut_transept_portcullis.prompt = winchPrompt

	winchPrompt.Triggered:Connect(function(player)
		if shortcuts.shortcut_transept_portcullis.isOpen then return end
		shortcuts.shortcut_transept_portcullis.isOpen = true
		winchPrompt.Enabled = false
		tombsPrompt.Enabled = false

		local raiseTween = TweenService:Create(grate, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(gateX, gateY + WALL_HEIGHT + 6, gateZ)
		})
		raiseTween:Play()
		grate.CanCollide = false
	end)
end

function SunforgedCitadelMapService.BuildDungeon(): Model
	if arenaFolder and arenaFolder.Parent then
		arenaFolder:Destroy()
	end

	local dungeon = Instance.new("Model")
	dungeon.Name = "SunforgedCitadel"
	arenaFolder = dungeon

	-- Comprehensive Void Catcher: covers entire 3x expanded citadel
	local voidCatcher = Instance.new("Part")
	voidCatcher.Name = "CitadelVoidCatcher"
	voidCatcher.Size = Vector3.new(600, 6, 1800)
	voidCatcher.CFrame = CFrame.new(0, -25, -600)
	voidCatcher.Transparency = 1
	voidCatcher.CanCollide = false
	voidCatcher.Anchored = true
	voidCatcher.Parent = dungeon
	voidCatcher.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if player and char then
			char:PivotTo(CFrame.new(0, 5.5, -1300))
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 1: THE IMPERIAL SUNCOURT & ANTECHAMBER (Z = -1350 to -1200, X = -50 to 50)
	-- Grand golden colonnade, spawn location, and twin guardian statues
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Antechamber", -50, 50, -1350, -1200)
	makeCeiling(dungeon, "Antechamber", -50, 50, -1350, -1200)

	-- Solid Grand Landing Dais
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "SunforgedDungeonSpawn"
	spawnPad.Size = Vector3.new(26, 1.2, 26)
	spawnPad.CFrame = CFrame.new(0, FLOOR_Y + 0.6, -1300)
	spawnPad.Color = GOLD_DARK
	spawnPad.Material = Enum.Material.Marble
	spawnPad.Transparency = 0
	spawnPad.CanCollide = true
	spawnPad.Anchored = true
	spawnPad.Duration = 0
	spawnPad.Parent = dungeon

	local daisTrim = Instance.new("Part")
	daisTrim.Name = "DaisTrim"
	daisTrim.Size = Vector3.new(28, 0.4, 28)
	daisTrim.CFrame = CFrame.new(0, FLOOR_Y + 0.2, -1300)
	daisTrim.Color = GOLD_ACCENT
	daisTrim.Material = Enum.Material.Metal
	daisTrim.Anchored = true
	daisTrim.CanCollide = true
	daisTrim.Parent = dungeon

	-- Perimeter Walls
	makeWallX(dungeon, "Antechamber_BackWall", -50, 50, -1350, 4)
	makeWallZ(dungeon, "Antechamber_WestWall", -50, -1350, -1200, 4)
	makeWallZ(dungeon, "Antechamber_EastWall", 50, -1350, -1200, 4)

	-- South Wall flanking 3-portal exit into Labyrinth (West Wing, Central, East Wing)
	makeWallX(dungeon, "Antechamber_South_W1", -50, -32, -1200, 4)
	makeWallX(dungeon, "Antechamber_South_Lintel_W", -32, -18, -1200, 4, 18, WALL_HEIGHT) -- West Portal
	makeWallX(dungeon, "Antechamber_South_Mid1", -18, -8, -1200, 4)
	makeWallX(dungeon, "Antechamber_South_Lintel_C", -8, 8, -1200, 4, 20, WALL_HEIGHT)    -- Central Portal
	makeWallX(dungeon, "Antechamber_South_Mid2", 8, 18, -1200, 4)
	makeWallX(dungeon, "Antechamber_South_Lintel_E", 18, 32, -1200, 4, 18, WALL_HEIGHT)   -- East Portal
	makeWallX(dungeon, "Antechamber_South_E1", 32, 50, -1200, 4)

	-- Columns & Solar Braziers
	makeGoldenPillar(dungeon, Vector3.new(-24, FLOOR_Y, -1320), WALL_HEIGHT, 5)
	makeGoldenPillar(dungeon, Vector3.new(24, FLOOR_Y, -1320), WALL_HEIGHT, 5)
	makeGoldenPillar(dungeon, Vector3.new(-24, FLOOR_Y, -1250), WALL_HEIGHT, 5)
	makeGoldenPillar(dungeon, Vector3.new(24, FLOOR_Y, -1250), WALL_HEIGHT, 5)
	makeSolarBrazier(dungeon, Vector3.new(-36, FLOOR_Y, -1330), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(36, FLOOR_Y, -1330), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(-36, FLOOR_Y, -1220), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(36, FLOOR_Y, -1220), SOLAR_ORANGE)

	-- 3D Mesh Details: Antechamber Sentinels, Seraphs, Banners & Crests
	spawnGuardianStatue(dungeon, Vector3.new(-12, FLOOR_Y, -1320), 0, 1.35)
	spawnGuardianStatue(dungeon, Vector3.new(12, FLOOR_Y, -1320), 0, 1.35)
	spawnSeraphIdol(dungeon, Vector3.new(-38, FLOOR_Y, -1265), math.rad(45), 1.3)
	spawnSeraphIdol(dungeon, Vector3.new(38, FLOOR_Y, -1265), math.rad(-45), 1.3)
	spawnWallBanner(dungeon, Vector3.new(-48, FLOOR_Y + 16, -1310), math.rad(90), 3.2)
	spawnWallBanner(dungeon, Vector3.new(-48, FLOOR_Y + 16, -1250), math.rad(90), 3.2)
	spawnWallBanner(dungeon, Vector3.new(48, FLOOR_Y + 16, -1310), math.rad(-90), 3.2)
	spawnWallBanner(dungeon, Vector3.new(48, FLOOR_Y + 16, -1250), math.rad(-90), 3.2)
	spawnHeraldicShield(dungeon, Vector3.new(-24, FLOOR_Y + 12, -1317), 0, 2.4)
	spawnHeraldicShield(dungeon, Vector3.new(24, FLOOR_Y + 12, -1317), 0, 2.4)
	spawnHeraldicShield(dungeon, Vector3.new(-24, FLOOR_Y + 12, -1247), 0, 2.4)
	spawnHeraldicShield(dungeon, Vector3.new(24, FLOOR_Y + 12, -1247), 0, 2.4)
	spawnArchCapstone(dungeon, Vector3.new(-25, FLOOR_Y + 20, -1200), 0, 1.4)
	spawnArchCapstone(dungeon, Vector3.new(0, FLOOR_Y + 22, -1200), 0, 1.8)
	spawnArchCapstone(dungeon, Vector3.new(25, FLOOR_Y + 20, -1200), 0, 1.4)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 2: THE 3-WING GRAND SOLAR LABYRINTH & CATACOMBS (Z = -1200 to -800, X = -120 to 120)
	-- Vast interconnected maze: West Crypts, Central Avenue, East Sunken Tombs
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Labyrinth_MainFloor", -120, 120, -1200, -800)
	makeCeiling(dungeon, "Labyrinth_MainCeiling", -120, 120, -1200, -800)

	-- Outer Boundary Walls
	makeWallX(dungeon, "Labyrinth_NorthCap_W", -120, -50, -1200, 4)
	makeWallX(dungeon, "Labyrinth_NorthCap_E", 50, 120, -1200, 4)
	makeWallZ(dungeon, "Labyrinth_OuterWest", -120, -1200, -800, 4)
	makeWallZ(dungeon, "Labyrinth_OuterEast", 120, -1200, -800, 4)

	-- West Wing Interior Partition Walls (The Crypt of the Sunken Sun)
	makeWallZ(dungeon, "Crypt_Div_W", -45, -1200, -960, 4)
	makeWallZ(dungeon, "Crypt_Div_W2", -45, -920, -800, 4) -- Opening at Z[-960, -920] to center
	makeWallX(dungeon, "Crypt_Wall_1", -110, -65, -1140, 3)
	makeWallZ(dungeon, "Crypt_Wall_2", -85, -1140, -1040, 3)
	makeWallX(dungeon, "Crypt_Wall_3", -120, -75, -1040, 3)
	makeWallZ(dungeon, "Crypt_Wall_4", -65, -1080, -950, 3)
	makeWallX(dungeon, "Crypt_Wall_5", -105, -55, -950, 3)
	makeWallZ(dungeon, "Crypt_Wall_6", -95, -950, -860, 3)
	makeWallX(dungeon, "Crypt_Wall_7", -95, -55, -860, 3)

	-- Central Avenue Partition Walls (The Imperial Way)
	makeWallZ(dungeon, "Avenue_Wall_L1", -15, -1160, -1070, 3)
	makeWallZ(dungeon, "Avenue_Wall_R1", 15, -1160, -1070, 3)
	makeWallX(dungeon, "Avenue_Cross_1", -35, 10, -1070, 3)
	makeWallX(dungeon, "Avenue_Cross_2", -10, 35, -990, 3)
	makeWallZ(dungeon, "Avenue_Wall_L2", -18, -990, -880, 3)
	makeWallZ(dungeon, "Avenue_Wall_R2", 18, -990, -880, 3)

	-- East Wing Interior Partition Walls (The Hall of Sunken Runes)
	makeWallZ(dungeon, "Tombs_Div_E", 45, -1200, -960, 4)
	makeWallZ(dungeon, "Tombs_Div_E2", 45, -920, -800, 4) -- Opening at Z[-960, -920] to center
	makeWallX(dungeon, "Tombs_Wall_1", 65, 110, -1140, 3)
	makeWallZ(dungeon, "Tombs_Wall_2", 85, -1140, -1040, 3)
	makeWallX(dungeon, "Tombs_Wall_3", 75, 120, -1040, 3)
	makeWallZ(dungeon, "Tombs_Wall_4", 65, -1080, -950, 3)
	makeWallX(dungeon, "Tombs_Wall_5", 55, 105, -950, 3)
	makeWallZ(dungeon, "Tombs_Wall_6", 95, -950, -860, 3)
	makeWallX(dungeon, "Tombs_Wall_7", 55, 95, -860, 3)

	-- Labyrinth Braziers & Lighting
	makeSolarBrazier(dungeon, Vector3.new(-85, FLOOR_Y, -1100), CELESTIAL_BLUE)
	makeSolarBrazier(dungeon, Vector3.new(-85, FLOOR_Y, -900), CELESTIAL_BLUE)
	makeSolarBrazier(dungeon, Vector3.new(0, FLOOR_Y, -1120), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(0, FLOOR_Y, -930), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(85, FLOOR_Y, -1100), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(85, FLOOR_Y, -900), SOLAR_ORANGE)

	-- 3D Mesh Details: Labyrinth Guardians, Dragon Idols & Banners
	spawnDragonStatue(dungeon, Vector3.new(-45, FLOOR_Y, -960), math.rad(-90), 1.3)
	spawnWallBanner(dungeon, Vector3.new(-118, FLOOR_Y + 14, -1100), math.rad(90), 2.8)
	spawnWallBanner(dungeon, Vector3.new(-118, FLOOR_Y + 14, -900), math.rad(90), 2.8)
	spawnGuardianStatue(dungeon, Vector3.new(-22, FLOOR_Y, -1030), math.rad(45), 1.25)
	spawnGuardianStatue(dungeon, Vector3.new(22, FLOOR_Y, -1030), math.rad(-45), 1.25)
	spawnDragonStatue(dungeon, Vector3.new(45, FLOOR_Y, -960), math.rad(90), 1.3)
	spawnWallBanner(dungeon, Vector3.new(118, FLOOR_Y + 14, -1100), math.rad(-90), 2.8)
	spawnWallBanner(dungeon, Vector3.new(118, FLOOR_Y + 14, -900), math.rad(-90), 2.8)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SHORTCUT DOOR 1: Crypt Vault Door (West Crypts to Grand Archives)
	-- Cross-wing portal at X = -80, Z = -800
	-- ═══════════════════════════════════════════════════════════════════════════
	setupCryptToArchivesShortcut(dungeon, Vector3.new(-80, FLOOR_Y, -800))

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 3: THE GRAND ARCHIVES & SUNKEN VAULTS (Z = -800 to -550, X = -100 to 100)
	-- Massive vaulted hall connecting the labyrinth to the Grand Cathedral
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Archives", -100, 100, -800, -550)
	makeCeiling(dungeon, "Archives", -100, 100, -800, -550, 32)

	-- North Wall separating Labyrinth and Archives (Openings at X[-87, -73] for Shortcut 1, Center X[-14, 14], East X[73, 87] for Shortcut 2 corridor)
	makeWallX(dungeon, "Archives_North_W1", -100, -88, -800, 4)
	makeWallX(dungeon, "Archives_North_W2", -72, -14, -800, 4)
	makeWallX(dungeon, "Archives_North_Lintel_C", -14, 14, -800, 4, 20, 32) -- Main entrance from Center Avenue
	makeWallX(dungeon, "Archives_North_E1", 14, 72, -800, 4)
	makeWallX(dungeon, "Archives_North_E2", 88, 100, -800, 4)

	makeWallZ(dungeon, "Archives_West", -100, -800, -550, 4, 0, 32)
	makeWallZ(dungeon, "Archives_East", 100, -800, -550, 4, 0, 32)

	-- South Wall of Archives connecting to Cathedral (Center opening X[-20, 20])
	makeWallX(dungeon, "Archives_South_W", -100, -20, -550, 4, 0, 32)
	makeWallX(dungeon, "Archives_South_Lintel", -20, 20, -550, 4, 22, 32)
	makeWallX(dungeon, "Archives_South_E", 20, 62, -550, 4, 0, 32)
	makeWallX(dungeon, "Archives_South_E2", 78, 100, -550, 4, 0, 32)

	-- Grand Archives Colonnade Rows & Statuary
	for z = -750, -600, 50 do
		makeGoldenPillar(dungeon, Vector3.new(-45, FLOOR_Y, z), 32, 5)
		makeGoldenPillar(dungeon, Vector3.new(45, FLOOR_Y, z), 32, 5)
		makeSolarBrazier(dungeon, Vector3.new(-45, FLOOR_Y, z + 20), SOLAR_ORANGE)
		makeSolarBrazier(dungeon, Vector3.new(45, FLOOR_Y, z + 20), SOLAR_ORANGE)
		spawnHeraldicShield(dungeon, Vector3.new(-45, FLOOR_Y + 12, z + 2.6), 0, 2.2)
		spawnHeraldicShield(dungeon, Vector3.new(45, FLOOR_Y + 12, z + 2.6), 0, 2.2)
	end
	makeGoldenPillar(dungeon, Vector3.new(0, FLOOR_Y, -675), 32, 7) -- Central celestial pillar
	makeSolarBrazier(dungeon, Vector3.new(0, FLOOR_Y, -650), CELESTIAL_BLUE)

	-- 3D Mesh Details: Floating Celestial Orrery, 4 Seraphs, Wall Banners & Arch Capstones
	spawnCelestialOrrery(dungeon, Vector3.new(0, FLOOR_Y, -675))
	spawnSeraphIdol(dungeon, Vector3.new(-25, FLOOR_Y, -700), math.rad(45), 1.3)
	spawnSeraphIdol(dungeon, Vector3.new(25, FLOOR_Y, -700), math.rad(-45), 1.3)
	spawnSeraphIdol(dungeon, Vector3.new(-25, FLOOR_Y, -650), math.rad(135), 1.3)
	spawnSeraphIdol(dungeon, Vector3.new(25, FLOOR_Y, -650), math.rad(-135), 1.3)
	spawnWallBanner(dungeon, Vector3.new(-98, FLOOR_Y + 18, -750), math.rad(90), 3.2)
	spawnWallBanner(dungeon, Vector3.new(-98, FLOOR_Y + 18, -650), math.rad(90), 3.2)
	spawnWallBanner(dungeon, Vector3.new(98, FLOOR_Y + 18, -750), math.rad(-90), 3.2)
	spawnWallBanner(dungeon, Vector3.new(98, FLOOR_Y + 18, -650), math.rad(-90), 3.2)
	spawnArchCapstone(dungeon, Vector3.new(0, FLOOR_Y + 22, -800), 0, 1.8)
	spawnArchCapstone(dungeon, Vector3.new(0, FLOOR_Y + 24, -550), 0, 1.8)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SHORTCUT DOOR 2: Transept Portcullis (East Sunken Tombs to Grand Cathedral)
	-- Cross-wing portal at X = 70, Z = -550
	-- ═══════════════════════════════════════════════════════════════════════════
	setupTombsToCathedralShortcut(dungeon, Vector3.new(70, FLOOR_Y, -550))

	-- Enclosed transit gallery for Shortcut 2 from East Tombs (Z[-800, -550], X[62, 78])
	makeFloor(dungeon, "Shortcut2Gallery_Floor", 62, 78, -800, -550)
	makeCeiling(dungeon, "Shortcut2Gallery_Ceiling", 62, 78, -800, -550, 26)
	makeWallZ(dungeon, "Shortcut2Gallery_W", 62, -800, -550, 3)
	makeWallZ(dungeon, "Shortcut2Gallery_E", 78, -800, -550, 3)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 4: THE GRAND SOLAR CATHEDRAL OF RADIANCE (Z = -550 to -280, X = -70 to 70)
	-- Soaring 36-stud high celestial sanctuary
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Cathedral", -70, 70, -550, -280)
	makeCeiling(dungeon, "Cathedral", -70, 70, -550, -280, 36)

	makeWallZ(dungeon, "Cathedral_West", -70, -550, -280, 4, 0, 36)
	makeWallZ(dungeon, "Cathedral_East", 70, -550, -280, 4, 0, 36)

	-- South Wall flanking Grand Stepped Colonnade Entrance (Center opening X[-16, 16])
	makeWallX(dungeon, "Cathedral_South_W", -70, -16, -280, 4, 0, 36)
	makeWallX(dungeon, "Cathedral_South_Lintel", -16, 16, -280, 4, 24, 36)
	makeWallX(dungeon, "Cathedral_South_E", 16, 70, -280, 4, 0, 36)

	-- Rows of Colossal Radiant Columns
	for z = -500, -320, 45 do
		makeGoldenPillar(dungeon, Vector3.new(-32, FLOOR_Y, z), 36, 5)
		makeGoldenPillar(dungeon, Vector3.new(32, FLOOR_Y, z), 36, 5)
		makeSolarBrazier(dungeon, Vector3.new(-24, FLOOR_Y, z), SOLAR_ORANGE)
		makeSolarBrazier(dungeon, Vector3.new(24, FLOOR_Y, z), SOLAR_ORANGE)
		spawnWallBanner(dungeon, Vector3.new(-68, FLOOR_Y + 20, z), math.rad(90), 3.4)
		spawnWallBanner(dungeon, Vector3.new(68, FLOOR_Y + 20, z), math.rad(-90), 3.4)
		spawnHeraldicShield(dungeon, Vector3.new(-32, FLOOR_Y + 14, z + 2.6), 0, 2.4)
		spawnHeraldicShield(dungeon, Vector3.new(32, FLOOR_Y + 14, z + 2.6), 0, 2.4)
	end

	-- 3D Mesh Details: High Altar Dais, Central 2.0x Seraph, Twin Dragons & Grand Portal Capstone
	makeFloor(dungeon, "CathedralAltar_Dais1", -15, 15, -315, -295, FLOOR_Y + 1)
	makeFloor(dungeon, "CathedralAltar_Dais2", -10, 10, -313, -297, FLOOR_Y + 2)
	spawnSeraphIdol(dungeon, Vector3.new(0, FLOOR_Y + 2, -305), 0, 2.0)
	spawnDragonStatue(dungeon, Vector3.new(-16, FLOOR_Y + 1, -305), math.rad(45), 1.3)
	spawnDragonStatue(dungeon, Vector3.new(16, FLOOR_Y + 1, -305), math.rad(-45), 1.3)
	spawnArchCapstone(dungeon, Vector3.new(0, FLOOR_Y + 26, -280), 0, 2.0)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 5: THE GRAND STEPPED COLONNADE (Z = -280 to -100, rising from Y = 1 to Y = 48)
	-- Smooth, 100% walkable stepped ascension: 45 gentle steps (slope < 15 degrees)
	-- NO steep walls or impassable ramps!
	-- ═══════════════════════════════════════════════════════════════════════════
	local stairWidth = 32
	local stairMinX = -stairWidth / 2
	local stairMaxX = stairWidth / 2

	-- Side Enclosure Walls running from Y = 1 to Y = 80
	makeWallZ(dungeon, "Colonnade_WestWall", stairMinX, -280, -100, 4, 0, 80)
	makeWallZ(dungeon, "Colonnade_EastWall", stairMaxX, -280, -100, 4, 0, 80)

	-- High vaulted sloped ceiling over Grand Stepped Colonnade
	local colCeilingAngle = math.atan(47 / 180) -- gentle ~14.6 degrees
	local colCeilingLen = math.sqrt(180^2 + 47^2) + 6
	local colCeiling = makePart(dungeon, "Colonnade_Ceiling", Vector3.new(stairWidth + 8, 3, colCeilingLen),
		CFrame.new(0, 56, -190) * CFrame.Angles(colCeilingAngle, 0, 0), MARBLE_WHITE, Enum.Material.Marble)

	-- 45 gentle steps: 1 stud rise each, 4 studs depth = completely walkable by any character!
	makeStairs(dungeon, "Colonnade_Ascent", stairMinX, stairMaxX, -280, -100, 1, 48, 45)

	-- Stepped Colonnade Braziers along the climb
	makeSolarBrazier(dungeon, Vector3.new(-12, 12, -240), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(12, 12, -240), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(-12, 28, -180), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(12, 28, -180), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(-12, 44, -120), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(12, 44, -120), SOLAR_ORANGE)

	-- 3D Mesh Details: Sentinel Statues & Shields stationed along the climb
	spawnGuardianStatue(dungeon, Vector3.new(-12, 12, -240), math.rad(90), 1.25)
	spawnGuardianStatue(dungeon, Vector3.new(12, 12, -240), math.rad(-90), 1.25)
	spawnGuardianStatue(dungeon, Vector3.new(-12, 28, -180), math.rad(90), 1.25)
	spawnGuardianStatue(dungeon, Vector3.new(12, 28, -180), math.rad(-90), 1.25)
	spawnGuardianStatue(dungeon, Vector3.new(-12, 44, -120), math.rad(90), 1.25)
	spawnGuardianStatue(dungeon, Vector3.new(12, 44, -120), math.rad(-90), 1.25)
	spawnHeraldicShield(dungeon, Vector3.new(stairMinX + 2.1, 12 + 8, -240), math.rad(90), 2.2)
	spawnHeraldicShield(dungeon, Vector3.new(stairMaxX - 2.1, 12 + 8, -240), math.rad(-90), 2.2)
	spawnHeraldicShield(dungeon, Vector3.new(stairMinX + 2.1, 28 + 8, -180), math.rad(90), 2.2)
	spawnHeraldicShield(dungeon, Vector3.new(stairMaxX - 2.1, 28 + 8, -180), math.rad(-90), 2.2)
	spawnHeraldicShield(dungeon, Vector3.new(stairMinX + 2.1, 44 + 8, -120), math.rad(90), 2.2)
	spawnHeraldicShield(dungeon, Vector3.new(stairMaxX - 2.1, 44 + 8, -120), math.rad(-90), 2.2)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 6: SPIRE COURTYARD & PRE-BOSS GATE SANCTUM (Z = -100 to -50, X = -60 to 60, Y = 48)
	-- Grand high-elevation terrace under the sky leading to the boss gate
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "SpireTerrace", -60, 60, -100, -50, 48)
	makeCeiling(dungeon, "SpireTerrace", -60, 60, -100, -50, 32, 48)

	-- North Wall at Z = -100 (flanking entrance at top of stairs X[-16, 16])
	makeWallX(dungeon, "Spire_North_W", -60, -16, -100, 4, 0, 32, 48)
	makeWallX(dungeon, "Spire_North_Lintel", -16, 16, -100, 4, 22, 32, 48)
	makeWallX(dungeon, "Spire_North_E", 16, 60, -100, 4, 0, 32, 48)

	-- Outer Parapet Walls
	makeWallZ(dungeon, "Spire_WestWall", -60, -100, -50, 4, 0, 32, 48)
	makeWallZ(dungeon, "Spire_EastWall", 60, -100, -50, 4, 0, 32, 48)

	-- South Wall flanking Gate at Z = -50
	makeWallX(dungeon, "Spire_South_W", -60, -18, -50, 4, 0, 32, 48)
	makeWallX(dungeon, "Spire_South_E", 18, 60, -50, 4, 0, 32, 48)

	makeSolarBrazier(dungeon, Vector3.new(-35, 48, -75), CELESTIAL_BLUE)
	makeSolarBrazier(dungeon, Vector3.new(35, 48, -75), CELESTIAL_BLUE)

	-- 3D Mesh Details: Twin Giant Colossi, Seraph Viewpoints & Arch Capstone
	spawnGuardianStatue(dungeon, Vector3.new(-24, 48, -58), math.rad(30), 1.5)
	spawnGuardianStatue(dungeon, Vector3.new(24, 48, -58), math.rad(-30), 1.5)
	spawnSeraphIdol(dungeon, Vector3.new(-38, 48, -75), math.rad(90), 1.5)
	spawnSeraphIdol(dungeon, Vector3.new(38, 48, -75), math.rad(-90), 1.5)
	spawnArchCapstone(dungeon, Vector3.new(0, 48 + 24, -100), 0, 1.8)
	spawnWallBanner(dungeon, Vector3.new(-58, 48 + 16, -75), math.rad(90), 3.2)
	spawnWallBanner(dungeon, Vector3.new(58, 48 + 16, -75), math.rad(-90), 3.2)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 7: THE SOLAR SANCTUM GATE (Z = -50, at Y = 48)
	-- Massive sealed double disc gate leading to Solarius's Solar Throne
	-- ═══════════════════════════════════════════════════════════════════════════
	local gateModel = Instance.new("Model")
	gateModel.Name = "BossArenaGate"
	gateModel.Parent = dungeon
	bossGate = gateModel

	local gateZ = -50
	local gateY = 48

	-- Gate arch frame
	makePart(gateModel, "GatePost_L", Vector3.new(5, 26, 5), CFrame.new(-18, gateY + 13, gateZ), GOLD_DARK, Enum.Material.Metal)
	makePart(gateModel, "GatePost_R", Vector3.new(5, 26, 5), CFrame.new(18, gateY + 13, gateZ), GOLD_DARK, Enum.Material.Metal)
	makePart(gateModel, "GateArch_Top", Vector3.new(40, 5, 6), CFrame.new(0, gateY + 23, gateZ), GOLD_ACCENT, Enum.Material.Metal)

	-- 3D Mesh Arch Capstone & Heraldic Shields
	spawnArchCapstone(gateModel, Vector3.new(0, gateY + 26, gateZ), 0, 2.2)
	spawnHeraldicShield(gateModel, Vector3.new(-18, gateY + 16, gateZ - 2.6), 0, 2.5)
	spawnHeraldicShield(gateModel, Vector3.new(18, gateY + 16, gateZ - 2.6), 0, 2.5)

	-- Left and Right radiant golden vault doors
	doorLeft = createSunforgedDoorLeaf(gateModel, "Door_Left", true,
		Vector3.new(16, 22, 3), CFrame.new(-8, gateY + 11, gateZ))
	doorRight = createSunforgedDoorLeaf(gateModel, "Door_Right", false,
		Vector3.new(16, 22, 3), CFrame.new(8, gateY + 11, gateZ))

	-- Magical Runic Solar Ward Barrier
	local barrier = Instance.new("Part")
	barrier.Name = "RunicBarrier"
	barrier.Size = Vector3.new(31, 21.8, 0.4)
	barrier.CFrame = CFrame.new(0, gateY + 11, gateZ - 1.5)
	barrier.Color = SOLAR_ORANGE
	barrier.Material = Enum.Material.Neon
	barrier.Transparency = 0.45
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.Parent = gateModel
	gateBarrierPart = barrier

	local barrierPulse = TweenService:Create(
		barrier,
		TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.20 }
	)
	barrierPulse:Play()

	-- 3D Billboard above Gate
	local displayPart = Instance.new("Part")
	displayPart.Name = "GateDisplayAnchor"
	displayPart.Size = Vector3.new(1, 1, 1)
	displayPart.CFrame = CFrame.new(0, gateY + 28, gateZ)
	displayPart.Transparency = 1
	displayPart.CanCollide = false
	displayPart.Anchored = true
	displayPart.Parent = gateModel

	local bb = Instance.new("BillboardGui")
	bb.Name = "GateStatusBillboard"
	bb.Size = UDim2.new(0, 380, 0, 85)
	bb.StudsOffset = Vector3.new(0, 1, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	bb.Parent = displayPart

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 235, 180)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.Text = "THRONE OF THE SUNFORGED COLOSSUS"
	title.Parent = bb
	gateTitleLabel = title

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 0.5, 0)
	status.Position = UDim2.new(0, 0, 0.45, 0)
	status.BackgroundTransparency = 1
	status.TextColor3 = Color3.fromRGB(255, 170, 50)
	status.Font = Enum.Font.GothamBold
	status.TextSize = 19
	status.Text = "🔒 [SEALED: Citadel Guardians Remain]"
	status.Parent = bb
	gateStatusLabel = status

	local promptPart = Instance.new("Part")
	promptPart.Name = "GatePromptPart"
	promptPart.Size = Vector3.new(4, 4, 4)
	promptPart.CFrame = CFrame.new(0, gateY + 5, gateZ - 2)
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.Anchored = true
	promptPart.Parent = gateModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenGatePrompt"
	prompt.ActionText = "Examine Gate"
	prompt.ObjectText = "Solar Sanctum"
	prompt.MaxActivationDistance = 20
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	gatePrompt = prompt

	prompt.Triggered:Connect(function(player)
		if not isGateUnlocked then
			prompt.ActionText = "Clear all Sentinels to break seal"
			task.delay(2.0, function()
				if prompt and not isGateUnlocked then
					prompt.ActionText = "Examine Gate"
				end
			end)
		else
			if onGateOpenRequestedCallback then
				onGateOpenRequestedCallback(player)
			else
				SunforgedCitadelMapService.OpenBossGate()
			end
		end
	end)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 8: THE SOLAR THRONE ARENA (Z = -50 to 140, X = -75 to 75 at Y = 48)
	-- Colossal celestial open-air arena under desert sun
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Arena", -75, 75, -50, 140, 48)
	makePart(dungeon, "Arena_SolarCenterDisc", Vector3.new(70, 0.2, 70), CFrame.new(0, 49.1, 40), GOLD_ACCENT, Enum.Material.Marble)

	-- Surrounding Colosseum Walls
	local arenaHeight = 38
	makeWallX(dungeon, "Arena_NorthWall", -75, 75, 140, 5, 0, arenaHeight, 48)
	makeWallZ(dungeon, "Arena_WestWall", -75, -50, 140, 5, 0, arenaHeight, 48)
	makeWallZ(dungeon, "Arena_EastWall", 75, -50, 140, 5, 0, arenaHeight, 48)

	-- South Wall flanking gate
	makeWallX(dungeon, "Arena_South_L", -75, -18, -50, 5, 0, arenaHeight, 48)
	makeWallX(dungeon, "Arena_South_R", 18, 75, -50, 5, 0, arenaHeight, 48)

	-- Ring of 8 Colossal Sun Pillars with Heraldic Shields facing inward
	local pillarRadius = 55
	for angle = 0, 315, 45 do
		local rad = math.rad(angle)
		local px = math.cos(rad) * pillarRadius
		local pz = 40 + math.sin(rad) * pillarRadius
		if not (math.abs(px) < 12 and pz < -20) then
			makeGoldenPillar(dungeon, Vector3.new(px, 48, pz), arenaHeight, 6.5)
			makeSolarBrazier(dungeon, Vector3.new(px * 0.85, 48, pz * 0.85), SOLAR_ORANGE)
			local lookAngle = math.atan2(-px, 40 - pz)
			local shieldPos = Vector3.new(px * 0.94, 48 + 14, pz * 0.94)
			spawnHeraldicShield(dungeon, shieldPos, lookAngle, 2.5)
		end
	end

	-- 3D Mesh Details: High Solar Dais, Throne Seraph & Twin Throne Dragons
	makeFloor(dungeon, "SolarThrone_Dais1", -20, 20, 120, 138, 49.5)
	makeFloor(dungeon, "SolarThrone_Dais2", -14, 14, 124, 138, 51)
	spawnSeraphIdol(dungeon, Vector3.new(0, 51, 134), math.rad(180), 2.2)
	spawnDragonStatue(dungeon, Vector3.new(-24, 48, 124), math.rad(150), 1.4)
	spawnDragonStatue(dungeon, Vector3.new(24, 48, 124), math.rad(-150), 1.4)

	dungeon.Parent = workspace
	return dungeon
end

function SunforgedCitadelMapService.UpdateGateStatus(mobsRemaining: number, totalMobs: number)
	if isGateOpen then return end

	if mobsRemaining > 0 then
		isGateUnlocked = false
		if gateStatusLabel then
			gateStatusLabel.TextColor3 = Color3.fromRGB(255, 170, 50)
			gateStatusLabel.Text = ("🔒 [SEALED: %d / %d Citadel Guardians Remain]"):format(mobsRemaining, totalMobs)
		end
		if gatePrompt then
			gatePrompt.ActionText = "Examine Gate"
		end
	else
		isGateUnlocked = true
		if gateBarrierPart then
			gateBarrierPart.CanCollide = false
			TweenService:Create(gateBarrierPart, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0.95,
				Color = Color3.fromRGB(255, 230, 100),
			}):Play()
		end
		if gateStatusLabel then
			gateStatusLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
			gateStatusLabel.Text = "✨ [UNLOCKED - ENTER THE SOLAR THRONE]"
		end
		if gatePrompt then
			gatePrompt.ActionText = "Open Solar Gate"
		end
	end
end

function SunforgedCitadelMapService.OpenBossGate(onOpened: (() -> ())?)
	if isGateOpen then return end
	isGateOpen = true

	if onOpened then
		onGateOpenedCallback = onOpened
	end

	if gatePrompt then gatePrompt.Enabled = false end
	if gateStatusLabel then
		gateStatusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		gateStatusLabel.Text = "⚔️ [THE SUNFORGED COLOSSUS AWAITS]"
	end

	if gateBarrierPart then
		TweenService:Create(gateBarrierPart, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1
		}):Play()
		task.delay(0.85, function()
			if gateBarrierPart then gateBarrierPart:Destroy() end
		end)
	end

	if doorLeft and doorRight then
		doorLeft.CanCollide = false
		doorRight.CanCollide = false

		local gateZ = -50
		local gateY = 48
		local leftHinge = CFrame.new(-18, gateY + 11, gateZ)
		local rightHinge = CFrame.new(18, gateY + 11, gateZ)

		local openLeft = leftHinge * CFrame.Angles(0, math.rad(-95), 0) * CFrame.new(8, 0, 0)
		local openRight = rightHinge * CFrame.Angles(0, math.rad(95), 0) * CFrame.new(-8, 0, 0)

		local t1 = TweenService:Create(doorLeft, TweenInfo.new(2.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = openLeft })
		local t2 = TweenService:Create(doorRight, TweenInfo.new(2.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = openRight })
		t1:Play()
		t2:Play()
	end

	if onGateOpenedCallback then
		onGateOpenedCallback()
	end
end

function SunforgedCitadelMapService.SetOnGateOpenRequested(callback: (Player?) -> ())
	onGateOpenRequestedCallback = callback
end

function SunforgedCitadelMapService.IsGateUnlocked(): boolean
	return isGateUnlocked
end

function SunforgedCitadelMapService.IsGateOpen(): boolean
	return isGateOpen
end

function SunforgedCitadelMapService.UnsealBossGate()
	if bossGate then
		local seal = bossGate:FindFirstChild("CombatSeal")
		if seal then
			seal:Destroy()
		end
	end
end

function SunforgedCitadelMapService.Cleanup()
	if arenaFolder and arenaFolder.Parent then
		arenaFolder:Destroy()
	end
	arenaFolder = nil
	bossGate = nil
	gateBarrierPart = nil
	doorLeft = nil
	doorRight = nil
	gatePrompt = nil
	gateStatusLabel = nil
	gateTitleLabel = nil
	isGateUnlocked = false
	isGateOpen = false
	onGateOpenedCallback = nil
	shortcuts.shortcut_crypt_vault.isOpen = false
	shortcuts.shortcut_transept_portcullis.isOpen = false
end

return SunforgedCitadelMapService
