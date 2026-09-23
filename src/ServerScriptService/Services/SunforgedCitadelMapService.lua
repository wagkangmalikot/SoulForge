-- src/ServerScriptService/Services/SunforgedCitadelMapService.lua
-- Generates and manages the physical MMO dungeon architecture for the Sunforged Citadel (Tier 2 Dungeon).
-- Features a large, interconnected maze-like canyon fortress with verticality,
-- golden marble halls, celestial orreries, solar braziers, and two Elden Ring-style
-- one-way shortcuts (heavy portcullis winch and solar elevator lift).
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

-- Elden Ring shortcut state tracking:
-- shortcut_portcullis: heavy iron gate between Lower Bastion and Antechamber
-- shortcut_elevator: solar lift connecting Orrery Spire directly down to Antechamber
local shortcuts = {
	shortcut_portcullis = {
		isOpen = false,
		gatePart = nil :: BasePart?,
		prompt = nil :: ProximityPrompt?,
	},
	shortcut_elevator = {
		isOpen = false,
		platformPart = nil :: BasePart?,
		leverPrompt = nil :: ProximityPrompt?,
		isMoving = false,
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

local WALL_HEIGHT = 26
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

	return doorBase
end

-- ============================================================================
-- SHORTCUT 1: Lower Bastion One-Way Portcullis
-- ============================================================================
local function setupPortcullisShortcut(dungeon: Model, gatePos: Vector3)
	local frame = Instance.new("Model")
	frame.Name = "ShortcutPortcullis"
	frame.Parent = dungeon

	-- Arch frame
	makePart(frame, "PortcullisPillar_L", Vector3.new(3, WALL_HEIGHT, 3), CFrame.new(gatePos + Vector3.new(-7.5, WALL_HEIGHT/2, 0)), GOLD_DARK, Enum.Material.Metal)
	makePart(frame, "PortcullisPillar_R", Vector3.new(3, WALL_HEIGHT, 3), CFrame.new(gatePos + Vector3.new(7.5, WALL_HEIGHT/2, 0)), GOLD_DARK, Enum.Material.Metal)
	makePart(frame, "PortcullisTop", Vector3.new(18, 3, 4), CFrame.new(gatePos + Vector3.new(0, WALL_HEIGHT - 1.5, 0)), GOLD_ACCENT, Enum.Material.Metal)

	-- The sliding heavy iron grate
	local grate = makePart(frame, "PortcullisGrate", Vector3.new(12, WALL_HEIGHT - 3, 1), CFrame.new(gatePos + Vector3.new(0, (WALL_HEIGHT - 3)/2, 0)), BRONZE_METAL, Enum.Material.Metal)
	shortcuts.shortcut_portcullis.gatePart = grate

	-- LOCKED SIDE INTERACTION (Front/South: Antechamber side)
	local frontExamPart = Instance.new("Part")
	frontExamPart.Size = Vector3.new(4, 4, 2)
	frontExamPart.CFrame = CFrame.new(gatePos + Vector3.new(0, 4, -4))
	frontExamPart.Transparency = 1
	frontExamPart.Anchored = true
	frontExamPart.CanCollide = false
	frontExamPart.Parent = frame

	local frontPrompt = Instance.new("ProximityPrompt")
	frontPrompt.ActionText = "Examine Gate"
	frontPrompt.ObjectText = "Heavy Portcullis"
	frontPrompt.MaxActivationDistance = 14
	frontPrompt.HoldDuration = 0.4
	frontPrompt.RequiresLineOfSight = false
	frontPrompt.Parent = frontExamPart

	frontPrompt.Triggered:Connect(function(player)
		if not shortcuts.shortcut_portcullis.isOpen then
			frontPrompt.ActionText = "Does not open from this side"
			task.delay(2.0, function()
				if frontPrompt and not shortcuts.shortcut_portcullis.isOpen then
					frontPrompt.ActionText = "Examine Gate"
				end
			end)
		end
	end)

	-- UNLOCK MECHANISM (Back/North: Lower Bastion side)
	local winchMount = makePart(frame, "WinchMount", Vector3.new(2.5, 3.5, 2.5), CFrame.new(gatePos + Vector3.new(7.5, 3.5/2, 3.5)), GOLD_DARK, Enum.Material.Metal)
	local winchWheel = makePart(frame, "WinchWheel", Vector3.new(2, 2, 0.6), CFrame.new(gatePos + Vector3.new(7.5, 3, 4.5)), GOLD_ACCENT, Enum.Material.Metal)

	local winchPrompt = Instance.new("ProximityPrompt")
	winchPrompt.ActionText = "Turn Winch Mechanism"
	winchPrompt.ObjectText = "Shortcut Gate"
	winchPrompt.MaxActivationDistance = 14
	winchPrompt.HoldDuration = 1.0
	winchPrompt.RequiresLineOfSight = false
	winchPrompt.Parent = winchWheel
	shortcuts.shortcut_portcullis.prompt = winchPrompt

	winchPrompt.Triggered:Connect(function(player)
		if shortcuts.shortcut_portcullis.isOpen then return end
		shortcuts.shortcut_portcullis.isOpen = true
		winchPrompt.Enabled = false
		frontPrompt.Enabled = false

		-- Animate portcullis raising
		local raiseTween = TweenService:Create(grate, TweenInfo.new(3.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(gatePos + Vector3.new(0, WALL_HEIGHT + 6, 0))
		})
		raiseTween:Play()
		grate.CanCollide = false
	end)
end

-- ============================================================================
-- SHORTCUT 2: Solar Orrery Spire Elevator Lift
-- ============================================================================
local function setupElevatorShortcut(dungeon: Model, shaftPos: Vector3, topY: number, bottomY: number)
	local elevModel = Instance.new("Model")
	elevModel.Name = "ShortcutElevator"
	elevModel.Parent = dungeon

	-- Elevator Platform (Hexagonal disc)
	local platform = makePart(elevModel, "LiftPlatform", Vector3.new(16, 2, 16), CFrame.new(shaftPos.X, topY, shaftPos.Z), GOLD_ACCENT, Enum.Material.Metal)
	shortcuts.shortcut_elevator.platformPart = platform

	-- Solar Rune Inlay in center of elevator
	local runeInlay = Instance.new("Part")
	runeInlay.Size = Vector3.new(8, 0.4, 8)
	runeInlay.CFrame = platform.CFrame * CFrame.new(0, 1.1, 0)
	runeInlay.Color = SOLAR_ORANGE
	runeInlay.Material = Enum.Material.Neon
	runeInlay.CanCollide = false
	runeInlay.Anchored = false
	runeInlay.Parent = platform

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = platform
	weld.Part1 = runeInlay
	weld.Parent = platform

	-- Lower Lever (Antechamber bottom - locked until activated from top)
	local bottomLeverBase = makePart(elevModel, "BottomLeverBase", Vector3.new(2, 3, 2), CFrame.new(shaftPos.X + 11, bottomY + 1.5, shaftPos.Z), GOLD_DARK, Enum.Material.Metal)
	local bottomPrompt = Instance.new("ProximityPrompt")
	bottomPrompt.ActionText = "Call Solar Lift"
	bottomPrompt.ObjectText = "Elevator Lever"
	bottomPrompt.MaxActivationDistance = 14
	bottomPrompt.HoldDuration = 0.5
	bottomPrompt.Enabled = false -- starts disabled until top lever is pulled
	bottomPrompt.Parent = bottomLeverBase

	-- Top Lever (Spire top - initial unlock)
	local topLeverBase = makePart(elevModel, "TopLeverBase", Vector3.new(2, 3, 2), CFrame.new(shaftPos.X + 11, topY + 1.5, shaftPos.Z), GOLD_DARK, Enum.Material.Metal)
	local topPrompt = Instance.new("ProximityPrompt")
	topPrompt.ActionText = "Pull Lever (Unlock Shortcut Lift)"
	topPrompt.ObjectText = "Solar Orrery Lift"
	topPrompt.MaxActivationDistance = 14
	topPrompt.HoldDuration = 1.0
	topPrompt.Parent = topLeverBase
	shortcuts.shortcut_elevator.leverPrompt = topPrompt

	local function moveElevator(targetY: number, duration: number)
		if shortcuts.shortcut_elevator.isMoving then return end
		shortcuts.shortcut_elevator.isMoving = true

		local tween = TweenService:Create(platform, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			CFrame = CFrame.new(shaftPos.X, targetY, shaftPos.Z)
		})
		tween:Play()
		tween.Completed:Connect(function()
			shortcuts.shortcut_elevator.isMoving = false
		end)
	end

	topPrompt.Triggered:Connect(function()
		shortcuts.shortcut_elevator.isOpen = true
		topPrompt.ActionText = "Operate Lift"
		topPrompt.HoldDuration = 0.4
		bottomPrompt.Enabled = true

		-- Ride it down or call down
		local currentY = platform.Position.Y
		if math.abs(currentY - topY) < 3 then
			moveElevator(bottomY, 4.5)
		else
			moveElevator(topY, 4.5)
		end
	end)

	bottomPrompt.Triggered:Connect(function()
		local currentY = platform.Position.Y
		if math.abs(currentY - bottomY) < 3 then
			moveElevator(topY, 4.5)
		else
			moveElevator(bottomY, 4.5)
		end
	end)
end

-- ============================================================================
-- MAIN CITADEL DUNGEON BUILDER
-- ============================================================================
function SunforgedCitadelMapService.BuildDungeon(): Model
	local existing = workspace:FindFirstChild("SunforgedCitadel")
	if existing then
		existing:Destroy()
	end

	local dungeon = Instance.new("Model")
	dungeon.Name = "SunforgedCitadel"
	arenaFolder = dungeon

	isGateUnlocked = false
	isGateOpen = false

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 1: Sunlit Staging Antechamber (Safe Spawn Courtyard, Z = -450 to -390)
	-- Grand golden marble courtyard with sunlight shafts & shortcut access points
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Antechamber", -35, 35, -450, -390)
	makeCeiling(dungeon, "Antechamber", -35, 35, -450, -390)

	-- Native Dungeon SpawnLocation pad
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "SunforgedDungeonSpawn"
	spawnPad.Size = Vector3.new(16, 1, 16)
	spawnPad.CFrame = CFrame.new(0, FLOOR_Y + 0.5, -420)
	spawnPad.Transparency = 1
	spawnPad.CanCollide = true
	spawnPad.Anchored = true
	spawnPad.Duration = 0
	spawnPad.Parent = dungeon

	-- Back & side walls
	makeWallX(dungeon, "Antechamber_BackWall", -35, 35, -450, 4)
	makeWallZ(dungeon, "Antechamber_WestWall", -35, -450, -390, 4)
	makeWallZ(dungeon, "Antechamber_EastWall", 35, -450, -390, 4)

	-- South Wall flanking Entryway to Main Maze (Center open X = -8 to 8)
	makeWallX(dungeon, "Antechamber_SouthWall_L", -35, -8, -390, 4)
	makeWallX(dungeon, "Antechamber_SouthWall_R", 8, 35, -390, 4)
	makeWallX(dungeon, "Antechamber_SouthWall_Lintel", -8, 8, -390, 4, 18, WALL_HEIGHT)

	-- Antechamber Pillars & Braziers
	makeGoldenPillar(dungeon, Vector3.new(-18, FLOOR_Y, -420), WALL_HEIGHT, 4.5)
	makeGoldenPillar(dungeon, Vector3.new(18, FLOOR_Y, -420), WALL_HEIGHT, 4.5)
	makeSolarBrazier(dungeon, Vector3.new(-24, FLOOR_Y, -440), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(24, FLOOR_Y, -440), SOLAR_ORANGE)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SHORTCUT 1 CONNECTION: Lower Bastion Grate (Located at X = 25, Z = -390)
	-- Leads directly into Zone 3 when unlocked!
	-- ═══════════════════════════════════════════════════════════════════════════
	setupPortcullisShortcut(dungeon, Vector3.new(25, FLOOR_Y, -390))

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SHORTCUT 2 CONNECTION: Elevator Lift Shaft (Located at X = -25, Z = -420)
	-- Drops down from Orrery Spire (topY = 48, bottomY = 1)
	-- ═══════════════════════════════════════════════════════════════════════════
	setupElevatorShortcut(dungeon, Vector3.new(-25, 0, -420), 48, 1)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 2: The Sunken Canyon Maze (Z = -390 to -270, X = -50 to 50)
	-- Multi-branched labyrinth with dead-ends, ambush corners, and mob packs
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Maze_Ground", -50, 50, -390, -270)
	makeCeiling(dungeon, "Maze_Ceiling", -50, 50, -390, -270)

	-- Perimeter walls for Maze
	makeWallZ(dungeon, "Maze_OuterWest", -50, -390, -270, 4)
	makeWallZ(dungeon, "Maze_OuterEast", 50, -390, -270, 4)

	-- Internal Maze Partition Walls (creating winding paths & loops)
	-- Avenue 1: Forced detour west
	makeWallX(dungeon, "Maze_Wall_1", -20, 30, -370, 3)
	makeWallZ(dungeon, "Maze_Wall_2", -20, -370, -340, 3)
	makeWallX(dungeon, "Maze_Wall_3", -40, -5, -340, 3)
	makeWallZ(dungeon, "Maze_Wall_4", 15, -370, -320, 3)
	makeWallX(dungeon, "Maze_Wall_5", -10, 45, -320, 3)
	makeWallZ(dungeon, "Maze_Wall_6", -35, -330, -290, 3)
	makeWallX(dungeon, "Maze_Wall_7", -35, 10, -290, 3)
	makeWallZ(dungeon, "Maze_Wall_8", 30, -310, -275, 3)

	-- Torches and braziers scattered inside the maze
	makeSolarBrazier(dungeon, Vector3.new(-35, FLOOR_Y, -360), CELESTIAL_BLUE)
	makeSolarBrazier(dungeon, Vector3.new(35, FLOOR_Y, -345), SOLAR_ORANGE)
	makeSolarBrazier(dungeon, Vector3.new(0, FLOOR_Y, -305), SOLAR_ORANGE)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 3: Cathedral of Radiance & Grand Library (Z = -270 to -140, X = -40 to 40)
	-- Expansive high-ceiling hall, light beams, and connection to Shortcut 1's winch
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Cathedral", -40, 40, -270, -140)
	makeCeiling(dungeon, "Cathedral", -40, 40, -270, -140, 34)

	makeWallZ(dungeon, "Cathedral_West", -40, -270, -140, 4, 0, 34)
	makeWallZ(dungeon, "Cathedral_East", 40, -270, -140, 4, 0, 34)

	-- Southern doorway connecting from Maze
	makeWallX(dungeon, "Cathedral_South_L", -40, -10, -270, 4, 0, 34)
	makeWallX(dungeon, "Cathedral_South_R", 10, 40, -270, 4, 0, 34)
	makeWallX(dungeon, "Cathedral_South_Lintel", -10, 10, -270, 4, 20, 34)

	-- Grand rows of fluted marble pillars
	for z = -250, -160, 30 do
		makeGoldenPillar(dungeon, Vector3.new(-22, FLOOR_Y, z), 34, 4.5)
		makeGoldenPillar(dungeon, Vector3.new(22, FLOOR_Y, z), 34, 4.5)
		makeSolarBrazier(dungeon, Vector3.new(-18, FLOOR_Y, z), SOLAR_ORANGE)
		makeSolarBrazier(dungeon, Vector3.new(18, FLOOR_Y, z), SOLAR_ORANGE)
	end

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 4: Solar Orrery Spire & Elevated Terrace (Z = -140 to -50, X = -50 to 50)
	-- High elevation (y = 48) terrace where the elevator shortcut is unlocked
	-- ═══════════════════════════════════════════════════════════════════════════
	-- Grand Ramp ascending to Spire (Z = -140 to -100, rising from Y = 1 to Y = 48)
	local ramp = makePart(dungeon, "Spire_AscendingRamp", Vector3.new(18, 2, 45), CFrame.new(0, 24, -120) * CFrame.Angles(math.rad(46), 0, 0), GOLD_DARK, Enum.Material.Cobblestone)
	ramp.CanCollide = true

	-- Upper Spire Platform (Y = 48)
	makeFloor(dungeon, "SpireTerrace", -50, 50, -100, -50, 48)
	makeCeiling(dungeon, "SpireTerrace", -50, 50, -100, -50, 30, 48)

	makeWallZ(dungeon, "Spire_West", -50, -100, -50, 4, 0, 30, 48)
	makeWallZ(dungeon, "Spire_East", 50, -100, -50, 4, 0, 30, 48)

	-- Elevated Balcony Braziers
	makeSolarBrazier(dungeon, Vector3.new(-35, 48, -75), CELESTIAL_BLUE)
	makeSolarBrazier(dungeon, Vector3.new(35, 48, -75), CELESTIAL_BLUE)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 5: THE SOLAR SANCTUM GATE (Z = -50, at Y = 48)
	-- Massive sealed double disc gate leading to Solarius's Solar Throne
	-- ═══════════════════════════════════════════════════════════════════════════
	local gateModel = Instance.new("Model")
	gateModel.Name = "BossArenaGate"
	gateModel.Parent = dungeon
	bossGate = gateModel

	local gateZ = -50
	local gateY = 48

	-- Gate arch frame
	makePart(gateModel, "GatePost_L", Vector3.new(5, 26, 5), CFrame.new(-16, gateY + 13, gateZ), GOLD_DARK, Enum.Material.Metal)
	makePart(gateModel, "GatePost_R", Vector3.new(5, 26, 5), CFrame.new(16, gateY + 13, gateZ), GOLD_DARK, Enum.Material.Metal)
	makePart(gateModel, "GateArch_Top", Vector3.new(36, 5, 6), CFrame.new(0, gateY + 23, gateZ), GOLD_ACCENT, Enum.Material.Metal)

	-- Left and Right radiant golden vault doors
	doorLeft = createSunforgedDoorLeaf(gateModel, "Door_Left", true,
		Vector3.new(14, 22, 3), CFrame.new(-7, gateY + 11, gateZ))
	doorRight = createSunforgedDoorLeaf(gateModel, "Door_Right", false,
		Vector3.new(14, 22, 3), CFrame.new(7, gateY + 11, gateZ))

	-- Magical Runic Solar Ward Barrier
	local barrier = Instance.new("Part")
	barrier.Name = "RunicBarrier"
	barrier.Size = Vector3.new(27, 21.8, 0.4)
	barrier.CFrame = CFrame.new(0, gateY + 11, gateZ - 1.5)
	barrier.Color = SOLAR_ORANGE
	barrier.Material = Enum.Material.Neon
	barrier.Transparency = 0.80
	barrier.CanCollide = true
	barrier.Anchored = true
	barrier.Parent = gateModel
	gateBarrierPart = barrier

	local barrierPulse = TweenService:Create(
		barrier,
		TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.92 }
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
	bb.Size = UDim2.new(0, 360, 0, 85)
	bb.StudsOffset = Vector3.new(0, 1, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
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
	prompt.MaxActivationDistance = 18
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	gatePrompt = prompt

	prompt.Triggered:Connect(function(player: Player)
		if isGateOpen then return end
		if not isGateUnlocked then
			prompt.ActionText = "Locked! Defeat Citadel Guardians"
			task.delay(1.5, function()
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
	-- ZONE 6: THE SOLAR THRONE ARENA (Z = -50 to 90, X = -70 to 70 at Y = 48)
	-- Colossal celestial open-air arena under desert sun
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Arena", -70, 70, -50, 90, 48)
	makePart(dungeon, "Arena_SolarCenterDisc", Vector3.new(70, 2.1, 70), CFrame.new(0, 47, 20), GOLD_ACCENT, Enum.Material.Marble)

	-- Surrounding Colosseum Walls
	local arenaHeight = 36
	makeWallX(dungeon, "Arena_NorthWall", -70, 70, 90, 5, 0, arenaHeight, 48)
	makeWallZ(dungeon, "Arena_WestWall", -70, -50, 90, 5, 0, arenaHeight, 48)
	makeWallZ(dungeon, "Arena_EastWall", 70, -50, 90, 5, 0, arenaHeight, 48)

	-- South Wall flanking gate
	makeWallX(dungeon, "Arena_South_L", -70, -14, -50, 5, 0, arenaHeight, 48)
	makeWallX(dungeon, "Arena_South_R", 14, 70, -50, 5, 0, arenaHeight, 48)

	-- Ring of 8 Colossal Sun Pillars
	local pillarRadius = 50
	for angle = 0, 315, 45 do
		local rad = math.rad(angle)
		local px = math.cos(rad) * pillarRadius
		local pz = 20 + math.sin(rad) * pillarRadius
		if not (math.abs(px) < 10 and pz < -20) then
			makeGoldenPillar(dungeon, Vector3.new(px, 48, pz), arenaHeight, 6)
			makeSolarBrazier(dungeon, Vector3.new(px * 0.85, 48, pz * 0.85), SOLAR_ORANGE)
		end
	end

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

function SunforgedCitadelMapService.OpenBossGate()
	if isGateOpen then return end
	isGateOpen = true

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
		local leftHinge = CFrame.new(-14, gateY + 11, gateZ)
		local rightHinge = CFrame.new(14, gateY + 11, gateZ)

		local openLeft = leftHinge * CFrame.Angles(0, math.rad(-95), 0) * CFrame.new(7, 0, 0)
		local openRight = rightHinge * CFrame.Angles(0, math.rad(95), 0) * CFrame.new(-7, 0, 0)

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
end

return SunforgedCitadelMapService
