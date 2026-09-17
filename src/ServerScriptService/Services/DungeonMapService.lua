-- src/ServerScriptService/Services/DungeonMapService.lua
-- Generates and manages the physical MMO dungeon architecture for Rockhide's lair.
-- Features a grand Central Colonnade avenue leading directly to the Boss Gate,
-- flanked by the West Crypt (Chamber of Whispers & Alcove of the Undying) and
-- East Catacombs (Vault of Torment & Bone Sanctuary). Zero gaps, elevated airtight floors.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DungeonMapService = {}

local Assets = ReplicatedStorage:WaitForChild("Assets")

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

-- Visual styling constants
local STONE_COLOR    = Color3.fromRGB(75, 78, 82)
local FLOOR_COLOR    = Color3.fromRGB(50, 52, 58)
local WALL_COLOR     = Color3.fromRGB(68, 70, 75)
local DARK_STONE     = Color3.fromRGB(42, 44, 48)
local PILLAR_COLOR   = Color3.fromRGB(85, 88, 92)
local ACCENT_COLOR   = Color3.fromRGB(130, 85, 45)
local BARRIER_COLOR  = Color3.fromRGB(240, 110, 30)
local GOLD_COLOR     = Color3.fromRGB(220, 180, 60)

local WALL_HEIGHT = 22
-- Elevated 1 stud above baseplate (Y = 0) so floor never z-fights or clips with baseplate
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

-- Clones a pre-generated door-leaf mesh template from ReplicatedStorage.Assets, forces
-- it to the given size, and positions it at the given CFrame. Returns nil (with a
-- warning) if the template is missing so a bad asset name never throws during dungeon
-- construction. Matches the CanCollide/Anchored defaults the old makePart(...) slab
-- doors used, so OpenBossGate's existing CanCollide-toggle-then-CFrame-tween logic
-- keeps working unmodified.
--
-- The explicit `size` override matters here: generate_mesh does not reliably hit its
-- requested bounding box (confirmed during this asset's own generation -- the two
-- door-leaf meshes came back at noticeably different, undersized dimensions from each
-- other and from the requested 12.5 x 18 x 2.5). Without forcing both to the same
-- Size, the two leaves of a door meant to meet edge-to-edge in the middle would be
-- visibly mismatched.
local function cloneDoorAsset(parent: Instance, assetName: string, doorName: string, size: Vector3, cframe: CFrame): BasePart?
	local template = Assets:FindFirstChild(assetName)
	if not template or not template:IsA("BasePart") then
		warn("DungeonMapService: missing or invalid door asset ReplicatedStorage.Assets." .. assetName)
		return nil
	end

	local clone = template:Clone()
	clone.Name = doorName
	clone.Size = size
	clone.CFrame = cframe
	clone.Anchored = true
	clone.CanCollide = true
	clone.Parent = parent
	return clone
end

local function makeFloor(parent: Instance, name: string, minX: number, maxX: number, minZ: number, maxZ: number): Part
	local size = Vector3.new(math.abs(maxX - minX), 2, math.abs(maxZ - minZ))
	local cframe = CFrame.new((minX + maxX) / 2, FLOOR_Y - 1, (minZ + maxZ) / 2)
	return makePart(parent, name .. "_Floor", size, cframe, FLOOR_COLOR, Enum.Material.Cobblestone)
end

local function makeCeiling(parent: Instance, name: string, minX: number, maxX: number, minZ: number, maxZ: number, height: number?): Part
	local h = height or WALL_HEIGHT
	local size = Vector3.new(math.abs(maxX - minX), 2, math.abs(maxZ - minZ))
	local cframe = CFrame.new((minX + maxX) / 2, FLOOR_Y + h + 1, (minZ + maxZ) / 2)
	return makePart(parent, name .. "_Ceiling", size, cframe, STONE_COLOR, Enum.Material.Slate)
end

local function makeWallX(parent: Instance, name: string, minX: number, maxX: number, zCenter: number, thickness: number, minY: number?, maxY: number?): Part
	local y0 = minY or 0
	local y1 = maxY or WALL_HEIGHT
	local size = Vector3.new(math.abs(maxX - minX), y1 - y0, thickness)
	local cframe = CFrame.new((minX + maxX) / 2, FLOOR_Y + (y0 + y1) / 2, zCenter)
	return makePart(parent, name, size, cframe, WALL_COLOR, Enum.Material.Cobblestone)
end

local function makeWallZ(parent: Instance, name: string, xCenter: number, minZ: number, maxZ: number, thickness: number, minY: number?, maxY: number?): Part
	local y0 = minY or 0
	local y1 = maxY or WALL_HEIGHT
	local size = Vector3.new(thickness, y1 - y0, math.abs(maxZ - minZ))
	local cframe = CFrame.new(xCenter, FLOOR_Y + (y0 + y1) / 2, (minZ + maxZ) / 2)
	return makePart(parent, name, size, cframe, WALL_COLOR, Enum.Material.Cobblestone)
end

local function makeTorch(parent: Instance, position: Vector3)
	makePart(parent, "TorchMount", Vector3.new(1.2, 2.2, 1.2), CFrame.new(position), ACCENT_COLOR, Enum.Material.Wood)

	local flameHead = Instance.new("Part")
	flameHead.Name = "FlameHead"
	flameHead.Size = Vector3.new(0.8, 0.8, 0.8)
	flameHead.CFrame = CFrame.new(position + Vector3.new(0, 1.4, 0))
	flameHead.Color = Color3.fromRGB(255, 150, 50)
	flameHead.Material = Enum.Material.Neon
	flameHead.Anchored = true
	flameHead.CanCollide = false
	flameHead.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 175, 75)
	light.Brightness = 2.4
	light.Range = 32
	light.Shadows = true
	light.Parent = flameHead

	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 5
	fire.Color = Color3.fromRGB(255, 140, 30)
	fire.SecondaryColor = Color3.fromRGB(200, 50, 20)
	fire.Parent = flameHead
end

local function makeBrazier(parent: Instance, position: Vector3, flameColor: Color3)
	makePart(parent, "BrazierBase", Vector3.new(3, 2.5, 3), CFrame.new(position + Vector3.new(0, 1.25, 0)), DARK_STONE, Enum.Material.Slate)
	makePart(parent, "BrazierBowl", Vector3.new(4, 1.2, 4), CFrame.new(position + Vector3.new(0, 3.1, 0)), Color3.fromRGB(45, 48, 52), Enum.Material.Metal)

	local flamePart = Instance.new("Part")
	flamePart.Name = "BrazierFlame"
	flamePart.Size = Vector3.new(1.8, 0.5, 1.8)
	flamePart.CFrame = CFrame.new(position + Vector3.new(0, 3.8, 0))
	flamePart.Color = flameColor
	flamePart.Material = Enum.Material.Neon
	flamePart.Anchored = true
	flamePart.CanCollide = false
	flamePart.Parent = parent

	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 7
	fire.Color = flameColor
	fire.SecondaryColor = Color3.fromRGB(255, 120, 30)
	fire.Parent = flamePart

	local light = Instance.new("PointLight")
	light.Color = flameColor
	light.Brightness = 3.2
	light.Range = 36
	light.Shadows = true
	light.Parent = flamePart
end

local function makePillar(parent: Instance, position: Vector3, height: number, width: number)
	makePart(parent, "Pillar", Vector3.new(width, height, width), CFrame.new(position + Vector3.new(0, height / 2, 0)), PILLAR_COLOR, Enum.Material.Cobblestone)
	makePart(parent, "PillarBase", Vector3.new(width + 1.4, 2, width + 1.4), CFrame.new(position + Vector3.new(0, 1, 0)), STONE_COLOR, Enum.Material.Slate)
	makePart(parent, "PillarCap", Vector3.new(width + 1.4, 2, width + 1.4), CFrame.new(position + Vector3.new(0, height - 1, 0)), STONE_COLOR, Enum.Material.Slate)
end

function DungeonMapService.BuildDungeon(): Model
	local existing = workspace:FindFirstChild("RockhideArena")
	if existing then
		existing:Destroy()
	end

	local dungeon = Instance.new("Model")
	dungeon.Name = "RockhideArena"
	arenaFolder = dungeon

	isGateUnlocked = false
	isGateOpen = false

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 1: Staging Antechamber (Safe Spawn Courtyard, Z = -310 to -260)
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Antechamber", -24, 24, -312, -260)
	makeCeiling(dungeon, "Antechamber", -24, 24, -312, -260)

	-- Back Wall (North)
	makeWallX(dungeon, "Antechamber_BackWall", -24, 24, -310, 4)
	-- Side Walls
	makeWallZ(dungeon, "Antechamber_WestWall", -22, -310, -260, 4)
	makeWallZ(dungeon, "Antechamber_EastWall", 22, -310, -260, 4)

	-- South Wall flanking Entry Corridor doorway (X = -10 to 10 is open)
	makeWallX(dungeon, "Antechamber_SouthWall_L", -24, -10, -260, 4)
	makeWallX(dungeon, "Antechamber_SouthWall_R", 10, 24, -260, 4)
	makeWallX(dungeon, "Antechamber_SouthWall_Lintel", -10, 10, -260, 4, 16, WALL_HEIGHT)

	-- Antechamber Pillars & Braziers
	makePillar(dungeon, Vector3.new(-14, FLOOR_Y, -270), WALL_HEIGHT, 3.5)
	makePillar(dungeon, Vector3.new(14, FLOOR_Y, -270), WALL_HEIGHT, 3.5)
	makeBrazier(dungeon, Vector3.new(-12, FLOOR_Y, -295), Color3.fromRGB(80, 160, 255))
	makeBrazier(dungeon, Vector3.new(12, FLOOR_Y, -295), Color3.fromRGB(80, 160, 255))

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 2: Entry Corridor (Z = -260 to -230, X = -10 to 10)
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "EntryCorridor", -10, 10, -260, -230)
	makeCeiling(dungeon, "EntryCorridor", -10, 10, -260, -230)
	makeWallZ(dungeon, "Entry_WestWall", -10, -260, -230, 2)
	makeWallZ(dungeon, "Entry_EastWall", 10, -260, -230, 2)

	makeTorch(dungeon, Vector3.new(-8.5, FLOOR_Y + 7, -245))
	makeTorch(dungeon, Vector3.new(8.5, FLOOR_Y + 7, -245))

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 3: Grand Central Colonnade Avenue (Z = -230 to -25, X = -13 to 13)
	-- Majestic main hall leading straight to the Boss Gate, with archways into both wings
	-- ═══════════════════════════════════════════════════════════════════════════
	makeFloor(dungeon, "Colonnade", -13, 13, -230, -25)
	makeCeiling(dungeon, "Colonnade", -13, 13, -230, -25)

	-- North Wall flanking entry corridor doorway at X = -10 to 10
	makeWallX(dungeon, "Colonnade_NorthWall_L", -13, -10, -230, 2)
	makeWallX(dungeon, "Colonnade_NorthLintel", -10, 10, -230, 2, 16, WALL_HEIGHT)
	makeWallX(dungeon, "Colonnade_NorthWall_R", 10, 13, -230, 2)

	-- West Wall (X = -13) with 2 wide archways into West Crypt
	makeWallZ(dungeon, "Colonnade_WestWall_1", -13, -230, -190, 2)
	makeWallZ(dungeon, "Colonnade_WestLintel_1", -13, -190, -170, 2, 16, WALL_HEIGHT) -- Doorway to West Room 1
	makeWallZ(dungeon, "Colonnade_WestWall_2", -13, -170, -140, 2)
	makeWallZ(dungeon, "Colonnade_WestLintel_2", -13, -140, -120, 2, 16, WALL_HEIGHT) -- Doorway to West Room 2
	makeWallZ(dungeon, "Colonnade_WestWall_3", -13, -120, -25, 2)

	-- East Wall (X = 13) with 2 wide archways into East Catacombs
	makeWallZ(dungeon, "Colonnade_EastWall_1", 13, -230, -190, 2)
	makeWallZ(dungeon, "Colonnade_EastLintel_1", 13, -190, -170, 2, 16, WALL_HEIGHT) -- Doorway to East Room 1
	makeWallZ(dungeon, "Colonnade_EastWall_2", 13, -170, -140, 2)
	makeWallZ(dungeon, "Colonnade_EastLintel_2", 13, -140, -120, 2, 16, WALL_HEIGHT) -- Doorway to East Room 2
	makeWallZ(dungeon, "Colonnade_EastWall_3", 13, -120, -25, 2)

	-- Double row of grand colonnade pillars and torches
	for z = -215, -45, 25 do
		makePillar(dungeon, Vector3.new(-9.5, FLOOR_Y, z), WALL_HEIGHT, 2.8)
		makePillar(dungeon, Vector3.new(9.5, FLOOR_Y, z), WALL_HEIGHT, 2.8)
		makeTorch(dungeon, Vector3.new(-11.5, FLOOR_Y + 7, z))
		makeTorch(dungeon, Vector3.new(11.5, FLOOR_Y + 7, z))
	end

	-- Wing entrance marker braziers (Red for Crypt, Blue for Catacombs)
	makeBrazier(dungeon, Vector3.new(-10, FLOOR_Y, -180), Color3.fromRGB(255, 100, 30))
	makeBrazier(dungeon, Vector3.new(10, FLOOR_Y, -180), Color3.fromRGB(60, 150, 255))
	makeBrazier(dungeon, Vector3.new(-10, FLOOR_Y, -130), Color3.fromRGB(255, 100, 30))
	makeBrazier(dungeon, Vector3.new(10, FLOOR_Y, -130), Color3.fromRGB(60, 150, 255))

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 4: WEST WING (Crypt of Whispers)
	-- ═══════════════════════════════════════════════════════════════════════════
	-- Connector 1: Colonnade to West Room 1 (X = -35 to -13, Z = -190 to -170)
	makeFloor(dungeon, "WestConn1", -35, -13, -190, -170)
	makeCeiling(dungeon, "WestConn1", -35, -13, -190, -170)
	makeWallX(dungeon, "WestConn1_NorthWall", -35, -13, -190, 2)
	makeWallX(dungeon, "WestConn1_SouthWall", -35, -13, -170, 2)
	makeTorch(dungeon, Vector3.new(-24, FLOOR_Y + 7, -188))

	-- West Room 1: Chamber of Whispers (Center: -55, 0, -180, Size 40x40)
	makeFloor(dungeon, "WestRoom1", -75, -35, -200, -160)
	makeCeiling(dungeon, "WestRoom1", -75, -35, -200, -160)

	makeWallX(dungeon, "WestRoom1_NorthWall", -75, -35, -200, 3)
	makeWallZ(dungeon, "WestRoom1_WestWall", -75, -200, -160, 3)

	-- East Wall (Doorway to Connector 1 at Z = -190 to -170)
	makeWallZ(dungeon, "WestRoom1_EastWall_N", -35, -200, -190, 3)
	makeWallZ(dungeon, "WestRoom1_EastLintel", -35, -190, -170, 3, 16, WALL_HEIGHT)
	makeWallZ(dungeon, "WestRoom1_EastWall_S", -35, -170, -160, 3)

	-- South Wall (Doorway to Connecting Hallway at X = -65 to -45)
	makeWallX(dungeon, "WestRoom1_SouthWall_W", -75, -65, -160, 3)
	makeWallX(dungeon, "WestRoom1_SouthLintel", -65, -45, -160, 3, 16, WALL_HEIGHT)
	makeWallX(dungeon, "WestRoom1_SouthWall_E", -45, -35, -160, 3)

	-- Room 1 Props & Mob Pack 1: Vector3.new(-62, 3, -180), Vector3.new(-48, 3, -180)
	makePillar(dungeon, Vector3.new(-65, FLOOR_Y, -180), WALL_HEIGHT, 3)
	makePillar(dungeon, Vector3.new(-45, FLOOR_Y, -180), WALL_HEIGHT, 3)
	makeBrazier(dungeon, Vector3.new(-55, FLOOR_Y, -180), Color3.fromRGB(240, 90, 40))
	makeTorch(dungeon, Vector3.new(-73, FLOOR_Y + 7, -180))
	makeTorch(dungeon, Vector3.new(-55, FLOOR_Y + 7, -198))

	-- Connecting Hallway: Room 1 to Room 2 (X = -65 to -45, Z = -160 to -145)
	makeFloor(dungeon, "WestHall", -65, -45, -160, -145)
	makeCeiling(dungeon, "WestHall", -65, -45, -160, -145)
	makeWallZ(dungeon, "WestHall_WestWall", -65, -160, -145, 2)
	makeWallZ(dungeon, "WestHall_EastWall", -45, -160, -145, 2)
	makeTorch(dungeon, Vector3.new(-63.5, FLOOR_Y + 7, -152.5))

	-- West Room 2: Alcove of the Undying (Center: -50, 0, -130, Size 40x30)
	makeFloor(dungeon, "WestRoom2", -70, -30, -145, -115)
	makeCeiling(dungeon, "WestRoom2", -70, -30, -145, -115)

	-- North Wall (Doorway from Connecting Hallway at X = -65 to -45)
	makeWallX(dungeon, "WestRoom2_NorthWall_W", -70, -65, -145, 3)
	makeWallX(dungeon, "WestRoom2_NorthLintel", -65, -45, -145, 3, 16, WALL_HEIGHT)
	makeWallX(dungeon, "WestRoom2_NorthWall_E", -45, -30, -145, 3)

	makeWallZ(dungeon, "WestRoom2_WestWall", -70, -145, -115, 3)
	makeWallX(dungeon, "WestRoom2_SouthWall", -70, -30, -115, 3)

	-- East Wall (Doorway to Connector 2 at Z = -140 to -120)
	makeWallZ(dungeon, "WestRoom2_EastWall_N", -30, -145, -140, 3)
	makeWallZ(dungeon, "WestRoom2_EastLintel", -30, -140, -120, 3, 16, WALL_HEIGHT)
	makeWallZ(dungeon, "WestRoom2_EastWall_S", -30, -120, -115, 3)

	-- Room 2 Props & Mob Pack 2: Vector3.new(-54, 3, -130), Vector3.new(-44, 3, -130)
	makeBrazier(dungeon, Vector3.new(-50, FLOOR_Y, -130), Color3.fromRGB(240, 90, 40))
	makeTorch(dungeon, Vector3.new(-68, FLOOR_Y + 7, -130))
	makeTorch(dungeon, Vector3.new(-50, FLOOR_Y + 7, -117))

	-- Connector 2: Room 2 back into Colonnade (X = -30 to -13, Z = -140 to -120)
	makeFloor(dungeon, "WestConn2", -30, -13, -140, -120)
	makeCeiling(dungeon, "WestConn2", -30, -13, -140, -120)
	makeWallX(dungeon, "WestConn2_NorthWall", -30, -13, -140, 2)
	makeWallX(dungeon, "WestConn2_SouthWall", -30, -13, -120, 2)
	makeTorch(dungeon, Vector3.new(-21, FLOOR_Y + 7, -138))

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 5: EAST WING (Sunken Catacombs)
	-- ═══════════════════════════════════════════════════════════════════════════
	-- Connector 1: Colonnade to East Room 1 (X = 13 to 35, Z = -190 to -170)
	makeFloor(dungeon, "EastConn1", 13, 35, -190, -170)
	makeCeiling(dungeon, "EastConn1", 13, 35, -190, -170)
	makeWallX(dungeon, "EastConn1_NorthWall", 13, 35, -190, 2)
	makeWallX(dungeon, "EastConn1_SouthWall", 13, 35, -170, 2)
	makeTorch(dungeon, Vector3.new(24, FLOOR_Y + 7, -188))

	-- East Room 1: Vault of Torment (Center: 55, 0, -180, Size 40x40)
	makeFloor(dungeon, "EastRoom1", 35, 75, -200, -160)
	makeCeiling(dungeon, "EastRoom1", 35, 75, -200, -160)

	makeWallX(dungeon, "EastRoom1_NorthWall", 35, 75, -200, 3)
	makeWallZ(dungeon, "EastRoom1_EastWall", 75, -200, -160, 3)

	-- West Wall (Doorway from Connector 1 at Z = -190 to -170)
	makeWallZ(dungeon, "EastRoom1_WestWall_N", 35, -200, -190, 3)
	makeWallZ(dungeon, "EastRoom1_WestLintel", 35, -190, -170, 3, 16, WALL_HEIGHT)
	makeWallZ(dungeon, "EastRoom1_WestWall_S", 35, -170, -160, 3)

	-- South Wall (Doorway to Connecting Hallway at X = 45 to 65)
	makeWallX(dungeon, "EastRoom1_SouthWall_W", 35, 45, -160, 3)
	makeWallX(dungeon, "EastRoom1_SouthLintel", 45, 65, -160, 3, 16, WALL_HEIGHT)
	makeWallX(dungeon, "EastRoom1_SouthWall_E", 65, 75, -160, 3)

	-- Room 1 Props & Mob Pack 3: Vector3.new(48, 3, -180), Vector3.new(62, 3, -180)
	makePillar(dungeon, Vector3.new(45, FLOOR_Y, -180), WALL_HEIGHT, 3)
	makePillar(dungeon, Vector3.new(65, FLOOR_Y, -180), WALL_HEIGHT, 3)
	makeBrazier(dungeon, Vector3.new(55, FLOOR_Y, -180), Color3.fromRGB(60, 140, 255))
	makeTorch(dungeon, Vector3.new(73, FLOOR_Y + 7, -180))
	makeTorch(dungeon, Vector3.new(55, FLOOR_Y + 7, -198))

	-- Connecting Hallway: Room 1 to Room 2 (X = 45 to 65, Z = -160 to -145)
	makeFloor(dungeon, "EastHall", 45, 65, -160, -145)
	makeCeiling(dungeon, "EastHall", 45, 65, -160, -145)
	makeWallZ(dungeon, "EastHall_WestWall", 45, -160, -145, 2)
	makeWallZ(dungeon, "EastHall_EastWall", 65, -160, -145, 2)
	makeTorch(dungeon, Vector3.new(63.5, FLOOR_Y + 7, -152.5))

	-- East Room 2: Bone Sanctuary (Center: 50, 0, -130, Size 40x30)
	makeFloor(dungeon, "EastRoom2", 30, 70, -145, -115)
	makeCeiling(dungeon, "EastRoom2", 30, 70, -145, -115)

	-- North Wall (Doorway from Connecting Hallway at X = 45 to 65)
	makeWallX(dungeon, "EastRoom2_NorthWall_W", 30, 45, -145, 3)
	makeWallX(dungeon, "EastRoom2_NorthLintel", 45, 65, -145, 3, 16, WALL_HEIGHT)
	makeWallX(dungeon, "EastRoom2_NorthWall_E", 65, 70, -145, 3)

	makeWallZ(dungeon, "EastRoom2_EastWall", 70, -145, -115, 3)
	makeWallX(dungeon, "EastRoom2_SouthWall", 30, 70, -115, 3)

	-- West Wall (Doorway to Connector 2 at Z = -140 to -120)
	makeWallZ(dungeon, "EastRoom2_WestWall_N", 30, -145, -140, 3)
	makeWallZ(dungeon, "EastRoom2_WestLintel", 30, -140, -120, 3, 16, WALL_HEIGHT)
	makeWallZ(dungeon, "EastRoom2_WestWall_S", 30, -120, -115, 3)

	-- Room 2 Props & Mob Pack 4: Vector3.new(44, 3, -130), Vector3.new(54, 3, -130)
	makeBrazier(dungeon, Vector3.new(50, FLOOR_Y, -130), Color3.fromRGB(60, 140, 255))
	makeTorch(dungeon, Vector3.new(68, FLOOR_Y + 7, -130))
	makeTorch(dungeon, Vector3.new(50, FLOOR_Y + 7, -117))

	-- Connector 2: Room 2 back into Colonnade (X = 13 to 30, Z = -140 to -120)
	makeFloor(dungeon, "EastConn2", 13, 30, -140, -120)
	makeCeiling(dungeon, "EastConn2", 13, 30, -140, -120)
	makeWallX(dungeon, "EastConn2_NorthWall", 13, 30, -140, 2)
	makeWallX(dungeon, "EastConn2_SouthWall", 13, 30, -120, 2)
	makeTorch(dungeon, Vector3.new(21, FLOOR_Y + 7, -138))

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 6: THE GRAND BOSS CHAMBER GATE (Z = -25)
	-- ═══════════════════════════════════════════════════════════════════════════
	local gateModel = Instance.new("Model")
	gateModel.Name = "BossArenaGate"
	gateModel.Parent = dungeon
	bossGate = gateModel

	local gateZ = -25

	-- Gate archway frame
	makePart(gateModel, "GatePost_L", Vector3.new(4, WALL_HEIGHT, 4),
		CFrame.new(-14, FLOOR_Y + WALL_HEIGHT / 2, gateZ), STONE_COLOR, Enum.Material.Slate)
	makePart(gateModel, "GatePost_R", Vector3.new(4, WALL_HEIGHT, 4),
		CFrame.new(14, FLOOR_Y + WALL_HEIGHT / 2, gateZ), STONE_COLOR, Enum.Material.Slate)
	makePart(gateModel, "GateArch_Top", Vector3.new(32, 4.5, 5),
		CFrame.new(0, FLOOR_Y + WALL_HEIGHT - 2, gateZ), DARK_STONE, Enum.Material.Slate)
	makePart(gateModel, "GateArch_Trim", Vector3.new(33, 1.2, 6),
		CFrame.new(0, FLOOR_Y + WALL_HEIGHT + 0.5, gateZ), GOLD_COLOR, Enum.Material.Metal)

	-- Left and Right sculpted stone vault doors
	doorLeft = cloneDoorAsset(gateModel, "BossVaultDoor_Left", "Door_Left",
		Vector3.new(12.5, WALL_HEIGHT - 4, 2.5), CFrame.new(-6.25, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ))

	doorRight = cloneDoorAsset(gateModel, "BossVaultDoor_Right", "Door_Right",
		Vector3.new(12.5, WALL_HEIGHT - 4, 2.5), CFrame.new(6.25, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ))


	-- Glowing Runic Barrier Part (blocks passage until guardians are defeated).
	-- Transparency is high enough, and pulses further, so the sculpted vault
	-- doors behind it stay visible as a shimmering ward rather than a flat wall.
	local barrier = Instance.new("Part")
	barrier.Name = "RunicBarrier"
	barrier.Size = Vector3.new(25, WALL_HEIGHT - 4, 3.5)
	barrier.CFrame = CFrame.new(0, FLOOR_Y + (WALL_HEIGHT - 4) / 2, gateZ)
	barrier.Color = BARRIER_COLOR
	barrier.Material = Enum.Material.Neon
	barrier.Transparency = 0.65
	barrier.CanCollide = true
	barrier.Anchored = true
	barrier.Parent = gateModel
	gateBarrierPart = barrier

	-- Looping breathing pulse: OpenBossGate()'s fade-out tween (created later,
	-- when the gate unlocks) targets the same Transparency property and takes
	-- over cleanly when it plays; this loop doesn't need to be cancelled
	-- explicitly because the barrier is destroyed shortly after that fade-out.
	local barrierPulse = TweenService:Create(
		barrier,
		TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.78 }
	)
	barrierPulse:Play()

	local barrierSparkles = Instance.new("ParticleEmitter")
	barrierSparkles.Color = ColorSequence.new(BARRIER_COLOR)
	barrierSparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	barrierSparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	barrierSparkles.Lifetime = NumberRange.new(1.5, 2.5)
	barrierSparkles.Rate = 12
	barrierSparkles.Speed = NumberRange.new(1, 2)
	barrierSparkles.SpreadAngle = Vector2.new(15, 15)
	barrierSparkles.Parent = barrier

	-- 3D Status Billboard above the gate arch
	local displayPart = Instance.new("Part")
	displayPart.Name = "GateDisplayAnchor"
	displayPart.Size = Vector3.new(1, 1, 1)
	displayPart.CFrame = CFrame.new(0, FLOOR_Y + WALL_HEIGHT + 4, gateZ)
	displayPart.Transparency = 1
	displayPart.CanCollide = false
	displayPart.Anchored = true
	displayPart.Parent = gateModel

	local bb = Instance.new("BillboardGui")
	bb.Name = "GateStatusBillboard"
	bb.Size = UDim2.new(0, 320, 0, 80)
	bb.StudsOffset = Vector3.new(0, 1, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Parent = displayPart

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.Text = "SANCTUM OF ROCKHIDE"
	title.Parent = bb
	gateTitleLabel = title

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 0.5, 0)
	status.Position = UDim2.new(0, 0, 0.45, 0)
	status.BackgroundTransparency = 1
	status.TextColor3 = Color3.fromRGB(255, 140, 40)
	status.Font = Enum.Font.GothamBold
	status.TextSize = 18
	status.Text = "🔒 [SEALED: 10 Guardians Remain]"
	status.Parent = bb
	gateStatusLabel = status

	-- Proximity Prompt on the gate for player interaction
	local promptPart = Instance.new("Part")
	promptPart.Name = "GatePromptPart"
	promptPart.Size = Vector3.new(4, 4, 4)
	promptPart.CFrame = CFrame.new(0, FLOOR_Y + 5, gateZ - 2)
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.Anchored = true
	promptPart.Parent = gateModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenGatePrompt"
	prompt.ActionText = "Examine Gate"
	prompt.ObjectText = "Boss Chamber"
	prompt.MaxActivationDistance = 18
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	gatePrompt = prompt

	prompt.Triggered:Connect(function(player: Player)
		if isGateOpen then
			return
		end

		if not isGateUnlocked then
			prompt.ActionText = "Locked! Defeat Guardians"
			task.delay(1.5, function()
				if prompt and not isGateUnlocked then
					prompt.ActionText = "Examine Gate"
				end
			end)
		else
			if onGateOpenRequestedCallback then
				onGateOpenRequestedCallback(player)
			else
				DungeonMapService.OpenBossGate()
			end
		end
	end)

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ZONE 7: THE GRAND BOSS COLOSSEUM (Z = -25 to 105, X = -60 to 60)
	-- ═══════════════════════════════════════════════════════════════════════════
	local arenaHeight = WALL_HEIGHT + 8

	-- Arena Floor
	makeFloor(dungeon, "Arena", -60, 60, -25, 105)
	makePart(dungeon, "Arena_InnerFloor", Vector3.new(80, 2.05, 80),
		CFrame.new(0, FLOOR_Y - 1, 45), Color3.fromRGB(65, 68, 72), Enum.Material.Cobblestone)

	-- Elevated Arena Ceiling
	makeCeiling(dungeon, "Arena", -60, 60, -25, 105, arenaHeight)

	-- Outer Perimeter Walls
	makeWallX(dungeon, "Arena_NorthWall", -60, 60, 105, 4, 0, arenaHeight)
	makeWallZ(dungeon, "Arena_WestWall", -60, -25, 105, 4, 0, arenaHeight)
	makeWallZ(dungeon, "Arena_EastWall", 60, -25, 105, 4, 0, arenaHeight)

	-- South Wall flanking the Boss Gate (Doorway at X = -13 to 13)
	makeWallX(dungeon, "Arena_SouthWall_W", -60, -13, -25, 4, 0, arenaHeight)
	makeWallX(dungeon, "Arena_SouthWall_Lintel", -13, 13, -25, 4, WALL_HEIGHT, arenaHeight)
	makeWallX(dungeon, "Arena_SouthWall_E", 13, 60, -25, 4, 0, arenaHeight)

	-- Ring of Grand Colosseum Pillars (entrance avenue kept clear)
	local pillarRadius = 45
	for angle = 0, 315, 45 do
		local rad = math.rad(angle)
		local px = math.cos(rad) * pillarRadius
		local pz = 45 + math.sin(rad) * pillarRadius
		if pz > -16 and not (math.abs(px) < 6 and pz < 15) then
			makePillar(dungeon, Vector3.new(px, FLOOR_Y, pz), arenaHeight, 5)
			makeBrazier(dungeon, Vector3.new(px * 0.88, FLOOR_Y, pz * 0.88), Color3.fromRGB(255, 120, 20))
		end
	end

	dungeon.Parent = workspace
	return dungeon
end

function DungeonMapService.UpdateGateStatus(mobsRemaining: number, totalMobs: number)
	if isGateOpen then
		return
	end

	if mobsRemaining > 0 then
		isGateUnlocked = false
		if gateStatusLabel then
			gateStatusLabel.TextColor3 = Color3.fromRGB(255, 140, 40)
			gateStatusLabel.Text = ("🔒 [SEALED: %d / %d Guardians Remain]"):format(mobsRemaining, totalMobs)
		end
		if gatePrompt then
			gatePrompt.ActionText = "Examine Gate"
		end
	else
		isGateUnlocked = true
		if gateBarrierPart then
			gateBarrierPart.CanCollide = false
			TweenService:Create(gateBarrierPart, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0.9,
				Color = Color3.fromRGB(100, 255, 150),
			}):Play()
		end
		if gateStatusLabel then
			gateStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 140)
			gateStatusLabel.Text = "✨ [UNLOCKED - INTERACT TO OPEN]"
		end
		if gatePrompt then
			gatePrompt.ActionText = "Open Boss Gate"
		end
	end
end

function DungeonMapService.OpenBossGate(onOpened: (() -> ())?)
	if isGateOpen or not isGateUnlocked then
		return
	end
	isGateOpen = true

	if onOpened then
		onGateOpenedCallback = onOpened
	end

	if gatePrompt then
		gatePrompt.Enabled = false
	end

	if gateStatusLabel then
		gateStatusLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
		gateStatusLabel.Text = "🚪 [BOSS SANCTUM OPEN]"
	end

	-- Immediately disable collision and destroy the barrier
	if gateBarrierPart then
		gateBarrierPart.CanCollide = false
		local t = TweenService:Create(gateBarrierPart, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(28, 26, 6),
		})
		t:Play()
		task.delay(0.4, function()
			if gateBarrierPart then
				gateBarrierPart:Destroy()
				gateBarrierPart = nil
			end
		end)
	end

	-- Remove any existing CombatSeal immediately so entrance is 100% walkable
	if bossGate then
		local seal = bossGate:FindFirstChild("CombatSeal")
		if seal then
			seal:Destroy()
		end
	end

	-- Animated double-door opening (doors swing outward into the arena)
	if doorLeft and doorRight then
		doorLeft.CanCollide = false
		doorRight.CanCollide = false

		local gateZ = -25
		local leftHinge = CFrame.new(-12.5, FLOOR_Y + 9, gateZ)
		local rightHinge = CFrame.new(12.5, FLOOR_Y + 9, gateZ)

		local openLeftCFrame = leftHinge * CFrame.Angles(0, math.rad(-95), 0) * CFrame.new(6.25, 0, 0)
		local openRightCFrame = rightHinge * CFrame.Angles(0, math.rad(95), 0) * CFrame.new(-6.25, 0, 0)

		local t1 = TweenService:Create(doorLeft, TweenInfo.new(2.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = openLeftCFrame
		})
		local t2 = TweenService:Create(doorRight, TweenInfo.new(2.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = openRightCFrame
		})

		t1:Play()
		t2:Play()
		-- Doors permanently remain CanCollide = false so they never block or trap players
	end

	if onGateOpenedCallback then
		onGateOpenedCallback()
	end
end

function DungeonMapService.SetOnGateOpenRequested(callback: (Player?) -> ())
	onGateOpenRequestedCallback = callback
end

function DungeonMapService.IsGateUnlocked(): boolean
	return isGateUnlocked
end

function DungeonMapService.IsGateOpen(): boolean
	return isGateOpen
end

function DungeonMapService.SealBossGate()
	-- Deprecated: Keep entrance completely open and clear so players can freely enter and re-enter the boss chamber
end

function DungeonMapService.UnsealBossGate()
	if bossGate then
		local seal = bossGate:FindFirstChild("CombatSeal")
		if seal then
			seal:Destroy()
		end
	end
end

function DungeonMapService.Cleanup()
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

return DungeonMapService
