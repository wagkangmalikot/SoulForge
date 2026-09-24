-- src/ServerScriptService/Services/MonsterAIService.lua
-- Trash mobs: animated mesh enemies placed in packs along the dungeon corridor.
-- Uses the mesh template (TrashMobTemplate), welds all parts to PrimaryPart so the head
-- and limbs never detach or fall off, and uses 60 FPS Tween interpolation for smooth, lag-free pursuit.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local CombatService = require(script.Parent.CombatService)

local MonsterAIService = {}

local MOB_MAX_HEALTH = 20
local MOB_ATTACK_DAMAGE = 4
local MOB_ATTACK_RADIUS = 6.0
local MOB_ATTACK_INTERVAL = 1.6
local MOB_AGGRO_RADIUS = 28
local MOB_WALK_SPEED = 12

-- Finds a limb part using keyword matching
local function findLimbPart(model: Model, keywords: {string}): BasePart?
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			local cleanName = string.lower(desc.Name):gsub("[%s_%-]", "")
			for _, kw in keywords do
				if string.find(cleanName, kw) then
					return desc
				end
			end
		end
	end
	return nil
end

-- Connects a limb part to parentPart with a Motor6D joint while preserving its rest transform
local function getOrCreateMotor6D(limb: BasePart?, parentPart: BasePart, jointName: string): Motor6D?
	if not limb or limb == parentPart then
		return nil
	end

	for _, desc in limb.Parent:GetDescendants() do
		if desc:IsA("Motor6D") and ((desc.Part0 == parentPart and desc.Part1 == limb) or (desc.Part0 == limb and desc.Part1 == parentPart)) then
			return desc
		end
	end

	-- Remove any rigid weld constraints on limb so it can rotate
	for _, child in limb:GetChildren() do
		if child:IsA("WeldConstraint") or child:IsA("Weld") then
			child:Destroy()
		end
	end
	for _, child in parentPart:GetChildren() do
		if (child:IsA("WeldConstraint") or child:IsA("Weld")) and (child.Part0 == limb or child.Part1 == limb) then
			child:Destroy()
		end
	end

	local motor = Instance.new("Motor6D")
	motor.Name = jointName
	motor.Part0 = parentPart
	motor.Part1 = limb
	motor.C0 = parentPart.CFrame:ToObjectSpace(limb.CFrame)
	motor.C1 = CFrame.new()
	motor.Parent = parentPart
	return motor
end

-- Raycasts downward from above pos to find the exact floor surface Y
local function getGroundY(pos: Vector3, fallbackY: number?): number
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true

	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged("Enemy")) do
		table.insert(ignore, inst)
	end
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and (m:FindFirstChildOfClass("Humanoid") or string.find(m.Name, "Mob") or string.find(m.Name, "Minion") or string.find(m.Name, "Boss") or string.find(m.Name, "Solarius") or string.find(m.Name, "Rockhide")) then
			table.insert(ignore, m)
		end
	end
	rayParams.FilterDescendantsInstances = ignore

	local origin = Vector3.new(pos.X, pos.Y + 8, pos.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -60, 0), rayParams)
	if result then
		return result.Position.Y
	end
	return fallbackY or (pos.Y >= 35 and 49.0 or (pos.Y >= 15 and pos.Y or 1.0))
end

-- Calculates the vertical distance from model.PrimaryPart down to the lowest part of its feet/limbs
local function getFootOffset(model: Model, defaultOffset: number?): number
	local primary = model.PrimaryPart
	if not primary then
		return defaultOffset or 2.5
	end

	local minY = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local pName = string.lower(part.Name)
			-- Exclude held weapons, floating crystals, wings, and effects from foot calculation
			if pName ~= "_bossauralight"
				and not string.find(pName, "sword")
				and not string.find(pName, "blade")
				and not string.find(pName, "staff")
				and not string.find(pName, "scepter")
				and not string.find(pName, "weapon")
				and not string.find(pName, "gem")
				and not string.find(pName, "halo")
				and not string.find(pName, "wing")
				and not string.find(pName, "effect")
				and not string.find(pName, "floating")
			then
				local cf = part.CFrame
				local sz = part.Size
				-- Calculate world-space half height along world Y taking rotation into account
				local halfY = 0.5 * (
					math.abs(cf.RightVector.Y) * sz.X +
					math.abs(cf.UpVector.Y) * sz.Y +
					math.abs(cf.LookVector.Y) * sz.Z
				)
				local bottomY = cf.Position.Y - halfY
				if bottomY < minY then
					minY = bottomY
				end
			end
		end
	end

	if minY == math.huge then
		return defaultOffset or 2.5
	end

	return primary.Position.Y - minY
end

-- Auto-rigs and locks model integrity:
-- 1. Classifies limbs (arms, legs, head, torso) geometrically and by keywords
-- 2. Connects limbs via Motor6D joints so walking and attack animations can rotate them
-- 3. Welds any static non-skeletal parts so the mesh never drops pieces
-- 4. Disables Humanoid death/ragdoll logic so the head never disappears
local function ensureModelIntegrityAndRig(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		primary = model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("Torso")
			or model:FindFirstChild("Body")
			or model:FindFirstChildWhichIsA("BasePart")
		model.PrimaryPart = primary
	end
	if not primary then
		return nil, {}
	end

	-- Ensure Humanoid exists with self-destruct behaviors disabled
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Health = 1000000
	humanoid.MaxHealth = 1000000
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	end)

	local torso = findLimbPart(model, {"torso", "uppertorso", "lowertorso", "body", "chest", "root"})
		or primary

	-- Classify limbs: keywords first, then geometric fallback based on object-space X/Y
	local leftArm = findLimbPart(model, {"leftarm", "larm", "leftupperarm", "leftforearm", "leftcrystal", "lefthand", "leftwrist"})
	local rightArm = findLimbPart(model, {"rightarm", "rarm", "rightupperarm", "rightforearm", "rightcrystal", "righthand", "rightwrist"})
	local leftLeg = findLimbPart(model, {"leftleg", "lleg", "leftupperleg", "leftthigh", "leftfoot", "leftshin"})
	local rightLeg = findLimbPart(model, {"rightleg", "rleg", "rightupperleg", "rightthigh", "rightfoot", "rightshin"})
	local head = findLimbPart(model, {"head", "skull", "face"})

	-- Geometric classification fallback if arms/legs lacked "left"/"right" prefixes
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= torso and part ~= primary then
			local relPos = torso.CFrame:PointToObjectSpace(part.Position)
			local name = string.lower(part.Name)
			if string.find(name, "arm") or string.find(name, "hand") or string.find(name, "crystal") then
				if relPos.X < -0.3 and not leftArm then
					leftArm = part
				elseif relPos.X > 0.3 and not rightArm then
					rightArm = part
				end
			elseif string.find(name, "leg") or string.find(name, "foot") then
				if relPos.X < -0.2 and not leftLeg then
					leftLeg = part
				elseif relPos.X > 0.2 and not rightLeg then
					rightLeg = part
				end
			end
		end
	end

	-- Connect limbs with Motor6D joints
	local leftShoulder = getOrCreateMotor6D(leftArm, torso, "LeftShoulder")
	local rightShoulder = getOrCreateMotor6D(rightArm, torso, "RightShoulder")
	local leftHip = getOrCreateMotor6D(leftLeg, torso, "LeftHip")
	local rightHip = getOrCreateMotor6D(rightLeg, torso, "RightHip")
	local neck = getOrCreateMotor6D(head, torso, "Neck")

	if primary ~= torso then
		getOrCreateMotor6D(torso, primary, "RootJoint")
	end

	local jointed = {
		[primary] = true,
		[torso] = true,
	}
	if leftArm then jointed[leftArm] = true end
	if rightArm then jointed[rightArm] = true end
	if leftLeg then jointed[leftLeg] = true end
	if rightLeg then jointed[rightLeg] = true end
	if head then jointed[head] = true end

	-- Unanchor all parts so animations can rotate them
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= primary then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true

			-- Static accessories not in the jointed tree get welded to their appropriate limb or torso
			if not jointed[part] then
				local alreadyWelded = false
				for _, w in part:GetChildren() do
					if w:IsA("WeldConstraint") or w:IsA("Weld") then
						alreadyWelded = true
						break
					end
				end
				if not alreadyWelded and part.Parent then
					for _, w in part.Parent:GetChildren() do
						if (w:IsA("WeldConstraint") or w:IsA("Weld")) and (w.Part0 == part or w.Part1 == part) then
							alreadyWelded = true
							break
						end
					end
				end

				if not alreadyWelded then
					local targetLimb = torso
					local pName = string.lower(part.Name)
					if (string.find(pName, "sword") or string.find(pName, "blade") or string.find(pName, "staff") or string.find(pName, "scepter") or string.find(pName, "gem") or string.find(pName, "shield")) and rightArm then
						targetLimb = rightArm
					elseif (string.find(pName, "head") or string.find(pName, "visor") or string.find(pName, "crest") or string.find(pName, "halo")) and head then
						targetLimb = head
					end

					local weld = Instance.new("WeldConstraint")
					weld.Name = "IntegrityWeld_" .. part.Name
					weld.Part0 = targetLimb
					weld.Part1 = part
					weld.Parent = targetLimb
				end
			end
		end
	end

	primary.Anchored = true
	primary.CanCollide = true

	local joints = {
		torso = torso,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		leftHip = leftHip,
		rightHip = rightHip,
		neck = neck,
		origLeftShoulderC0 = leftShoulder and leftShoulder.C0,
		origRightShoulderC0 = rightShoulder and rightShoulder.C0,
		origLeftHipC0 = leftHip and leftHip.C0,
		origRightHipC0 = rightHip and rightHip.C0,
		origNeckC0 = neck and neck.C0,
	}

	return primary, joints
end

-- Sets up walking and attack animations for a mob model.
-- Automatically searches for embedded animations in the template or Assets,
-- falling back to official Roblox universal animation assets for R15/R6 rigs.
local function setupMobAnimations(model: Model): (AnimationTrack?, AnimationTrack?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- 1. Search inside the model and ReplicatedStorage for any authored Animation instances
	local walkAnim: Animation? = nil
	local attackAnim: Animation? = nil

	for _, desc in model:GetDescendants() do
		if desc:IsA("Animation") then
			local lower = string.lower(desc.Name)
			if string.find(lower, "walk") or string.find(lower, "run") or string.find(lower, "move") then
				walkAnim = desc
			elseif string.find(lower, "attack") or string.find(lower, "slash") or string.find(lower, "hit") or string.find(lower, "punch") or string.find(lower, "strike") then
				attackAnim = desc
			end
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		for _, desc in assets:GetDescendants() do
			if desc:IsA("Animation") then
				local lower = string.lower(desc.Name)
				if not walkAnim and (string.find(lower, "walk") or string.find(lower, "run") or string.find(lower, "mobwalk")) then
					walkAnim = desc
				elseif not attackAnim and (string.find(lower, "attack") or string.find(lower, "mobattack") or string.find(lower, "punch") or string.find(lower, "slash")) then
					attackAnim = desc
				end
			end
		end
	end

	local isR15 = model:FindFirstChild("UpperTorso") ~= nil
		or model:FindFirstChild("LeftUpperArm") ~= nil
		or (humanoid.RigType == Enum.HumanoidRigType.R15)

	local defaultWalkId = "rbxassetid://180426353"
	local defaultAttackId = "rbxassetid://125750702"
	if isR15 then
		defaultWalkId = "rbxassetid://507777826"
		defaultAttackId = "rbxassetid://522638767"
	end

	if not walkAnim then
		walkAnim = Instance.new("Animation")
		walkAnim.Name = "MobWalkAnim"
		walkAnim.AnimationId = defaultWalkId
	end

	if not attackAnim then
		attackAnim = Instance.new("Animation")
		attackAnim.Name = "MobAttackAnim"
		attackAnim.AnimationId = defaultAttackId
	end

	local walkTrack: AnimationTrack? = nil
	local attackTrack: AnimationTrack? = nil

	pcall(function()
		walkTrack = animator:LoadAnimation(walkAnim)
		if walkTrack then
			walkTrack.Priority = Enum.AnimationPriority.Movement
			walkTrack.Looped = true
		end
	end)

	pcall(function()
		attackTrack = animator:LoadAnimation(attackAnim)
		if attackTrack then
			attackTrack.Priority = Enum.AnimationPriority.Action4
			attackTrack.Looped = false
		end
	end)

	return walkTrack, attackTrack
end

local function buildSunbladeModel(targetId: string): Model
	local model = Instance.new("Model")
	model.Name = targetId

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.4, 3.2, 1.4)
	torso.Color = Color3.fromRGB(225, 180, 50)
	torso.Material = Enum.Material.Metal
	torso.Parent = model
	model.PrimaryPart = torso

	local chestplate = Instance.new("Part")
	chestplate.Name = "Chestplate"
	chestplate.Size = Vector3.new(2.5, 2.4, 0.5)
	chestplate.CFrame = torso.CFrame * CFrame.new(0, 0.2, -0.6)
	chestplate.Color = Color3.fromRGB(245, 240, 230)
	chestplate.Material = Enum.Material.Marble
	chestplate.Parent = model
	local wChest = Instance.new("WeldConstraint")
	wChest.Part0 = torso
	wChest.Part1 = chestplate
	wChest.Parent = torso

	local core = Instance.new("Part")
	core.Name = "SunCore"
	core.Size = Vector3.new(1.2, 1.2, 0.3)
	core.CFrame = torso.CFrame * CFrame.new(0, 0.4, -0.9)
	core.Color = Color3.fromRGB(255, 160, 30)
	core.Material = Enum.Material.Neon
	core.Parent = model
	local wCore = Instance.new("WeldConstraint")
	wCore.Part0 = torso
	wCore.Part1 = core
	wCore.Parent = torso

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.CFrame = torso.CFrame * CFrame.new(0, 2.3, 0)
	head.Color = Color3.fromRGB(235, 190, 60)
	head.Material = Enum.Material.Metal
	head.Parent = model

	local visor = Instance.new("Part")
	visor.Name = "Visor"
	visor.Size = Vector3.new(1.2, 0.3, 0.4)
	visor.CFrame = head.CFrame * CFrame.new(0, 0.1, -0.75)
	visor.Color = Color3.fromRGB(255, 130, 20)
	visor.Material = Enum.Material.Neon
	visor.Parent = model
	local wVisor = Instance.new("WeldConstraint")
	wVisor.Part0 = head
	wVisor.Part1 = visor
	wVisor.Parent = head

	local crest = Instance.new("Part")
	crest.Name = "HelmCrest"
	crest.Size = Vector3.new(0.3, 1.0, 1.8)
	crest.CFrame = head.CFrame * CFrame.new(0, 1.1, -0.1)
	crest.Color = Color3.fromRGB(250, 205, 70)
	crest.Material = Enum.Material.Metal
	crest.Parent = model
	local wCrest = Instance.new("WeldConstraint")
	wCrest.Part0 = head
	wCrest.Part1 = crest
	wCrest.Parent = head

	local lArm = Instance.new("Part")
	lArm.Name = "LeftUpperArm"
	lArm.Size = Vector3.new(1.3, 3.0, 1.3)
	lArm.CFrame = torso.CFrame * CFrame.new(-1.8, 0.1, 0)
	lArm.Color = Color3.fromRGB(180, 140, 45)
	lArm.Material = Enum.Material.Metal
	lArm.Parent = model

	local rArm = Instance.new("Part")
	rArm.Name = "RightUpperArm"
	rArm.Size = Vector3.new(1.3, 3.0, 1.3)
	rArm.CFrame = torso.CFrame * CFrame.new(1.8, 0.1, 0)
	rArm.Color = Color3.fromRGB(180, 140, 45)
	rArm.Material = Enum.Material.Metal
	rArm.Parent = model

	local sword = Instance.new("Part")
	sword.Name = "Sunblade"
	sword.Size = Vector3.new(0.5, 5.0, 0.8)
	sword.CFrame = rArm.CFrame * CFrame.new(0, -1.8, -0.9) * CFrame.Angles(math.rad(35), 0, 0)
	sword.Color = Color3.fromRGB(255, 205, 50)
	sword.Material = Enum.Material.Neon
	sword.Parent = model
	local wSword = Instance.new("WeldConstraint")
	wSword.Part0 = rArm
	wSword.Part1 = sword
	wSword.Parent = rArm

	local lLeg = Instance.new("Part")
	lLeg.Name = "LeftUpperLeg"
	lLeg.Size = Vector3.new(1.2, 3.0, 1.2)
	lLeg.CFrame = torso.CFrame * CFrame.new(-0.7, -3.0, 0)
	lLeg.Color = Color3.fromRGB(160, 120, 35)
	lLeg.Material = Enum.Material.Metal
	lLeg.Parent = model

	local rLeg = Instance.new("Part")
	rLeg.Name = "RightUpperLeg"
	rLeg.Size = Vector3.new(1.2, 3.0, 1.2)
	rLeg.CFrame = torso.CFrame * CFrame.new(0.7, -3.0, 0)
	rLeg.Color = Color3.fromRGB(160, 120, 35)
	rLeg.Material = Enum.Material.Metal
	rLeg.Parent = model

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "SolarEmbers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Rate = 6
	embers.Speed = NumberRange.new(1, 2)
	embers.Lifetime = NumberRange.new(0.5, 1.0)
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 120, 20))
	embers.LightEmission = 0.8
	embers.Parent = sword

	return model
end

local function buildPyromancerModel(targetId: string): Model
	local model = Instance.new("Model")
	model.Name = targetId

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.0, 2.8, 1.2)
	torso.Color = Color3.fromRGB(245, 240, 235)
	torso.Material = Enum.Material.Marble
	torso.Parent = model
	model.PrimaryPart = torso

	local sash = Instance.new("Part")
	sash.Name = "RobeSash"
	sash.Size = Vector3.new(2.1, 0.6, 1.3)
	sash.CFrame = torso.CFrame * CFrame.new(0, -0.6, 0)
	sash.Color = Color3.fromRGB(235, 185, 55)
	sash.Material = Enum.Material.Fabric
	sash.Parent = model
	local wSash = Instance.new("WeldConstraint")
	wSash.Part0 = torso
	wSash.Part1 = sash
	wSash.Parent = torso

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.CFrame = torso.CFrame * CFrame.new(0, 2.1, 0)
	head.Color = Color3.fromRGB(235, 195, 75)
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	local halo = Instance.new("Part")
	halo.Name = "SolarHalo"
	halo.Shape = Enum.PartType.Cylinder
	halo.Size = Vector3.new(0.2, 3.2, 3.2)
	halo.CFrame = head.CFrame * CFrame.new(0, 0.6, 0.6) * CFrame.Angles(0, math.rad(90), 0)
	halo.Color = Color3.fromRGB(255, 175, 40)
	halo.Material = Enum.Material.Neon
	halo.Parent = model
	local wHalo = Instance.new("WeldConstraint")
	wHalo.Part0 = head
	wHalo.Part1 = halo
	wHalo.Parent = head

	local orb = Instance.new("Part")
	orb.Name = "FloatingSunstone"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.3, 1.3, 1.3)
	orb.CFrame = torso.CFrame * CFrame.new(-1.8, 1.8, 0)
	orb.Color = Color3.fromRGB(255, 140, 20)
	orb.Material = Enum.Material.Neon
	orb.Parent = model
	local wOrb = Instance.new("WeldConstraint")
	wOrb.Part0 = torso
	wOrb.Part1 = orb
	wOrb.Parent = torso

	local orbGlow = Instance.new("ParticleEmitter")
	orbGlow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	orbGlow.Rate = 8
	orbGlow.Speed = NumberRange.new(0.5, 1.5)
	orbGlow.Color = ColorSequence.new(Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 80, 10))
	orbGlow.Parent = orb

	local lArm = Instance.new("Part")
	lArm.Name = "LeftUpperArm"
	lArm.Size = Vector3.new(1.1, 2.6, 1.1)
	lArm.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0)
	lArm.Color = Color3.fromRGB(240, 235, 230)
	lArm.Material = Enum.Material.Fabric
	lArm.Parent = model

	local rArm = Instance.new("Part")
	rArm.Name = "RightUpperArm"
	rArm.Size = Vector3.new(1.1, 2.6, 1.1)
	rArm.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0)
	rArm.Color = Color3.fromRGB(240, 235, 230)
	rArm.Material = Enum.Material.Fabric
	rArm.Parent = model

	local staff = Instance.new("Part")
	staff.Name = "SunScepter"
	staff.Size = Vector3.new(0.35, 4.8, 0.35)
	staff.CFrame = rArm.CFrame * CFrame.new(0, -1.2, -0.6) * CFrame.Angles(math.rad(25), 0, 0)
	staff.Color = Color3.fromRGB(215, 165, 40)
	staff.Material = Enum.Material.Metal
	staff.Parent = model
	local wStaff = Instance.new("WeldConstraint")
	wStaff.Part0 = rArm
	wStaff.Part1 = staff
	wStaff.Parent = rArm

	local gem = Instance.new("Part")
	gem.Name = "ScepterGem"
	gem.Shape = Enum.PartType.Ball
	gem.Size = Vector3.new(1.1, 1.1, 1.1)
	gem.CFrame = staff.CFrame * CFrame.new(0, 2.5, 0)
	gem.Color = Color3.fromRGB(255, 215, 60)
	gem.Material = Enum.Material.Neon
	gem.Parent = model
	local wGem = Instance.new("WeldConstraint")
	wGem.Part0 = staff
	wGem.Part1 = gem
	wGem.Parent = staff

	local lLeg = Instance.new("Part")
	lLeg.Name = "LeftUpperLeg"
	lLeg.Size = Vector3.new(1.1, 2.8, 1.1)
	lLeg.CFrame = torso.CFrame * CFrame.new(-0.6, -2.7, 0)
	lLeg.Color = Color3.fromRGB(240, 235, 230)
	lLeg.Material = Enum.Material.Fabric
	lLeg.Parent = model

	local rLeg = Instance.new("Part")
	rLeg.Name = "RightUpperLeg"
	rLeg.Size = Vector3.new(1.1, 2.8, 1.1)
	rLeg.CFrame = torso.CFrame * CFrame.new(0.6, -2.7, 0)
	rLeg.Color = Color3.fromRGB(240, 235, 230)
	rLeg.Material = Enum.Material.Fabric
	rLeg.Parent = model

	return model
end

function MonsterAIService.SpawnMobs(
	positions: {Vector3},
	onKilled: (Player) -> (),
	onMobDied: ((remaining: number, total: number) -> ())?
): () -> ()
	local handles = {}
	local mobList = {}
	local totalMobs = #positions
	local aliveCount = #positions

	for index, entry in ipairs(positions) do
		local targetId = "TrashMob_" .. index
		local pos: Vector3
		local packIndex: number

		if typeof(entry) == "Vector3" then
			pos = entry
			packIndex = math.ceil(index / 2)
		elseif typeof(entry) == "table" then
			pos = entry.position or entry.pos or entry[1]
			packIndex = entry.packIndex or entry.pack or math.ceil(index / 2)
		else
			continue
		end

		local isSunforged = (typeof(entry) == "table" and entry.isSunforged == true)
		local mobArchetype = "Minion"
		local model: Model

		if isSunforged then
			mobArchetype = (index % 2 == 1) and "Sunblade" or "Pyromancer"
			if mobArchetype == "Sunblade" then
				model = buildSunbladeModel(targetId)
			else
				model = buildPyromancerModel(targetId)
			end
		else
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			local template = assets and assets:FindFirstChild("TrashMobTemplate")
			if template then
				model = template:Clone()
				model.Name = targetId
			else
				model = Instance.new("Model")
				model.Name = targetId

				local body = Instance.new("Part")
				body.Name = "Body"
				body.Size = Vector3.new(3, 4, 3)
				body.Color = Color3.fromRGB(120, 110, 90)
				body.Parent = model
				model.PrimaryPart = body
			end
		end

		-- Calculate foot offset and floor height so mob stands flush on ground
		local footOffset = getFootOffset(model)
		local floorY = getGroundY(pos, pos.Y)
		local spawnPos = Vector3.new(pos.X, floorY + footOffset + 0.05, pos.Z)

		model:PivotTo(CFrame.new(spawnPos) * CFrame.Angles(0, math.pi, 0))

		-- Auto-rig limbs and secure integrity
		local primary, joints = ensureModelIntegrityAndRig(model)
		if primary then
			primary.CFrame = CFrame.new(spawnPos) * CFrame.Angles(0, math.pi, 0)
		end
		CollectionService:AddTag(model, "Enemy")
		model.Parent = workspace

		local mobMaxHealth = isSunforged and ((mobArchetype == "Sunblade") and 85 or 70) or MOB_MAX_HEALTH
		local mobAttackDamage = isSunforged and ((mobArchetype == "Sunblade") and 16 or 20) or MOB_ATTACK_DAMAGE
		local mobNameText = isSunforged and ((mobArchetype == "Sunblade") and "☀️ Citadel Sunblade [Lv. 25]" or "✨ Citadel Pyromancer [Lv. 25]") or "⚔️ Minion [Lv. 1]"
		local mobAttackRadius = (mobArchetype == "Pyromancer") and 30 or MOB_ATTACK_RADIUS
		local mobWalkSpeed = (mobArchetype == "Pyromancer") and 12 or (isSunforged and 16 or MOB_WALK_SPEED)

		local currentHealth = mobMaxHealth
		local alive = true
		local inCombat = false
		local targetPlayer: Player? = nil

		local mobData = {
			targetId = targetId,
			packIndex = packIndex,
			model = model,
			getAlive = function() return alive end,
			aggroOn = function(player: Player)
				inCombat = true
				targetPlayer = player
			end,
		}
		table.insert(mobList, mobData)

		local function alertPack(aggroTarget: Player)
			for _, other in ipairs(mobList) do
				if other.packIndex == packIndex and other.getAlive() then
					other.aggroOn(aggroTarget)
				end
			end
		end

		-- Overhead mini HP bar for mob
		local hpBillboard = Instance.new("BillboardGui")
		hpBillboard.Name = "MobHP"
		hpBillboard.Size = UDim2.new(0, 96, 0, 22)
		local _, mobExtents = model:GetBoundingBox()
		local mobHeightOffset = math.clamp((mobExtents.Y / 2) + 0.8, 2.2, 3.8)
		hpBillboard.StudsOffset = Vector3.new(0, mobHeightOffset, 0)
		hpBillboard.AlwaysOnTop = false
		hpBillboard.LightInfluence = 0
		hpBillboard.MaxDistance = 50
		hpBillboard.Parent = model.PrimaryPart

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "MobName"
		nameLabel.Size = UDim2.new(1, 0, 0, 11)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = mobNameText
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 10
		nameLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
		nameLabel.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
		nameLabel.TextStrokeTransparency = 0.2
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Parent = hpBillboard

		local hpBg = Instance.new("Frame")
		hpBg.Name = "HpContainer"
		hpBg.Size = UDim2.new(1, 0, 0, 7)
		hpBg.Position = UDim2.new(0, 0, 0, 13)
		hpBg.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
		hpBg.BorderSizePixel = 0
		hpBg.ClipsDescendants = true
		hpBg.Parent = hpBillboard

		local hpCorner = Instance.new("UICorner")
		hpCorner.CornerRadius = UDim.new(0, 3)
		hpCorner.Parent = hpBg

		local hpStroke = Instance.new("UIStroke")
		hpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		hpStroke.Color = Color3.fromRGB(65, 72, 90)
		hpStroke.Thickness = 1.2
		hpStroke.Transparency = 0.1
		hpStroke.Parent = hpBg

		-- Ghost buffer fill (delayed damage trail)
		local hpGhostFill = Instance.new("Frame")
		hpGhostFill.Name = "HpGhostFill"
		hpGhostFill.Size = UDim2.new(1, 0, 1, 0)
		hpGhostFill.Position = UDim2.new(0, 0, 0, 0)
		hpGhostFill.BackgroundColor3 = Color3.fromRGB(245, 185, 75)
		hpGhostFill.BorderSizePixel = 0
		hpGhostFill.ZIndex = 1
		hpGhostFill.Parent = hpBg

		local hpGhostCorner = Instance.new("UICorner")
		hpGhostCorner.CornerRadius = UDim.new(0, 3)
		hpGhostCorner.Parent = hpGhostFill

		-- Main crimson fill
		local hpFill = Instance.new("Frame")
		hpFill.Name = "HpFill"
		hpFill.Size = UDim2.new(1, 0, 1, 0)
		hpFill.Position = UDim2.new(0, 0, 0, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(225, 52, 45)
		hpFill.BorderSizePixel = 0
		hpFill.ZIndex = 2
		hpFill.Parent = hpBg

		local hpFillCorner = Instance.new("UICorner")
		hpFillCorner.CornerRadius = UDim.new(0, 3)
		hpFillCorner.Parent = hpFill

		local hpFillGrad = Instance.new("UIGradient")
		hpFillGrad.Color = ColorSequence.new(Color3.fromRGB(250, 68, 58), Color3.fromRGB(175, 22, 28))
		hpFillGrad.Parent = hpFill

		local function flashHit()
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Material ~= Enum.Material.Neon then
					local orig = part.Color
					part.Color = Color3.fromRGB(255, 90, 80)
					task.delay(0.12, function()
						if part and part.Parent then
							part.Color = orig
						end
					end)
				end
			end
		end

		local handle = {
			model = model,
			currentHealth = currentHealth,
			maxHealth = mobMaxHealth,
		}

		function handle.onDamaged(amount: number, attackingPlayer: Player?)
			if not alive then
				return
			end
			currentHealth = math.max(0, currentHealth - amount)
			handle.currentHealth = currentHealth
			local fillPct = math.clamp(currentHealth / mobMaxHealth, 0, 1)
			TweenService:Create(hpFill, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(fillPct, 0, 1, 0)
			}):Play()
			TweenService:Create(hpGhostFill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.18), {
				Size = UDim2.new(fillPct, 0, 1, 0)
			}):Play()
			flashHit()

			if attackingPlayer then
				alertPack(attackingPlayer)
			end

			if currentHealth <= 0 then
				alive = false
				aliveCount = math.max(0, aliveCount - 1)
				CombatService.UnregisterEnemy(targetId)
				hpBillboard.Enabled = false
				task.delay(0.3, function()
					if model and model.Parent then
						model:Destroy()
					end
				end)
				if attackingPlayer then
					onKilled(attackingPlayer)
				end
				if onMobDied then
					onMobDied(aliveCount, totalMobs)
				end
			end
		end

		function handle.onTaunted(player: Player)
			if alive then
				alertPack(player)
			end
		end

		CombatService.RegisterEnemy(targetId, handle)
		handles[targetId] = handle

		-- ── PROCEDURAL LIMB ANIMATOR & 60 FPS COMBAT AI ───────────────────────
		task.spawn(function()
			local lastAttackAt = 0
			local currentTween: Tween? = nil
			local isWalking = false
			local isAttacking = false

			local walkTrack, attackTrack = setupMobAnimations(model)

			-- Continuous walking swing on joints
			local walkCycle = 0
			task.spawn(function()
				while alive and model.Parent do
					task.wait(0.033)
					if not alive or not model.Parent then
						break
					end

					if isWalking and not isAttacking then
						walkCycle = (walkCycle + 0.38) % (2 * math.pi)
						local legAngle = math.sin(walkCycle) * math.rad(36)
						local armAngle = -legAngle * 0.9

						if joints.leftHip and joints.origLeftHipC0 then
							joints.leftHip.C0 = joints.origLeftHipC0 * CFrame.Angles(legAngle, 0, 0)
						end
						if joints.rightHip and joints.origRightHipC0 then
							joints.rightHip.C0 = joints.origRightHipC0 * CFrame.Angles(-legAngle, 0, 0)
						end
						if joints.leftShoulder and joints.origLeftShoulderC0 then
							joints.leftShoulder.C0 = joints.origLeftShoulderC0 * CFrame.Angles(armAngle, 0, 0)
						end
						if joints.rightShoulder and joints.origRightShoulderC0 then
							joints.rightShoulder.C0 = joints.origRightShoulderC0 * CFrame.Angles(-armAngle, 0, 0)
						end
					elseif not isAttacking then
						if joints.leftHip and joints.origLeftHipC0 and joints.leftHip.C0 ~= joints.origLeftHipC0 then
							joints.leftHip.C0 = joints.origLeftHipC0
						end
						if joints.rightHip and joints.origRightHipC0 and joints.rightHip.C0 ~= joints.origRightHipC0 then
							joints.rightHip.C0 = joints.origRightHipC0
						end
						if joints.leftShoulder and joints.origLeftShoulderC0 and joints.leftShoulder.C0 ~= joints.origLeftShoulderC0 then
							joints.leftShoulder.C0 = joints.origLeftShoulderC0
						end
						if joints.rightShoulder and joints.origRightShoulderC0 and joints.rightShoulder.C0 ~= joints.origRightShoulderC0 then
							joints.rightShoulder.C0 = joints.origRightShoulderC0
						end
					end
				end
			end)

			while alive do
				task.wait(0.20)
				if not alive or not model.Parent or not model.PrimaryPart then
					break
				end

				-- 1. Aggro detection
				if not inCombat then
					local myPos = model.PrimaryPart.Position
					for _, player in ipairs(Players:GetPlayers()) do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						if root and hum and hum.Health > 0 then
							if (root.Position - myPos).Magnitude <= MOB_AGGRO_RADIUS then
								alertPack(player)
								break
							end
						end
					end
				end

				if not inCombat or not targetPlayer or not targetPlayer.Character then
					if isWalking then
						isWalking = false
						if walkTrack and walkTrack.IsPlaying then
							walkTrack:Stop(0.2)
						end
					end
					continue
				end

				local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
				local targetHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
				if not targetRoot or not targetHum or targetHum.Health <= 0 then
					inCombat = false
					targetPlayer = nil
					if currentTween then
						currentTween:Cancel()
					end
					if isWalking then
						isWalking = false
						if walkTrack and walkTrack.IsPlaying then
							walkTrack:Stop(0.2)
						end
					end
					continue
				end

				local myPos = model.PrimaryPart.Position
				local targetPos = targetRoot.Position
				local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
				local dist = (flatTarget - myPos).Magnitude

				-- 2. Smooth 60 FPS movement toward player
				if dist > mobAttackRadius then
					-- Start walk animation
					if not isWalking then
						isWalking = true
						if walkTrack and not walkTrack.IsPlaying then
							walkTrack:Play(0.2)
						end
					end

					local step = math.min(mobWalkSpeed * 0.22, dist - mobAttackRadius + 0.5)
					local dir = (flatTarget - myPos).Unit
					local rawNextPos = myPos + dir * step
					local nextFloorY = getGroundY(rawNextPos, myPos.Y - footOffset)
					local nextPos = Vector3.new(rawNextPos.X, nextFloorY + footOffset + 0.05, rawNextPos.Z)
					local targetLookAt = Vector3.new(flatTarget.X, nextPos.Y, flatTarget.Z)
					local targetCFrame = CFrame.lookAt(nextPos, targetLookAt) * CFrame.Angles(0, math.pi, 0)

					if currentTween then
						currentTween:Cancel()
					end
					currentTween = TweenService:Create(
						model.PrimaryPart,
						TweenInfo.new(0.22, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
						{ CFrame = targetCFrame }
					)
					currentTween:Play()
				else
					-- Inside attack range: stop walking and face target
					if isWalking then
						isWalking = false
						if walkTrack and walkTrack.IsPlaying then
							walkTrack:Stop(0.2)
						end
					end

					if currentTween then
						currentTween:Cancel()
					end
					local currentFloorY = getGroundY(myPos, myPos.Y - footOffset)
					local standingPos = Vector3.new(myPos.X, currentFloorY + footOffset + 0.05, myPos.Z)
					local targetLookAt = Vector3.new(flatTarget.X, standingPos.Y, flatTarget.Z)
					model.PrimaryPart.CFrame = CFrame.lookAt(standingPos, targetLookAt) * CFrame.Angles(0, math.pi, 0)
				end

				-- 3. Attack Execution
				local now = os.clock()
				local attackInterval = (mobArchetype == "Pyromancer") and 2.4 or MOB_ATTACK_INTERVAL

				if dist <= (mobAttackRadius + 3) and (now - lastAttackAt) >= attackInterval then
					lastAttackAt = now
					isAttacking = true

					if mobArchetype == "Pyromancer" then
						-- ── PYROMANCER RANGED SOLAR FIREBALL ──
						if joints.rightShoulder and joints.origRightShoulderC0 then
							joints.rightShoulder.C0 = joints.origRightShoulderC0 * CFrame.Angles(math.rad(-105), 0, math.rad(20))
						end
						playSound("PyroCharge", "rbxasset://sounds/action_jump.mp3", model.PrimaryPart, 1.8, 1.3)

						task.delay(0.30, function()
							if not alive or not targetRoot then
								isAttacking = false
								return
							end

							local startPos = model.PrimaryPart.Position + Vector3.new(0, 3.2, 0)
							local aimPos = targetRoot.Position + Vector3.new(0, 1.2, 0)
							local flightDir = (aimPos - startPos).Unit

							local fireball = Instance.new("Part")
							fireball.Name = "SolarFireball"
							fireball.Shape = Enum.PartType.Ball
							fireball.Size = Vector3.new(1.8, 1.8, 1.8)
							fireball.Color = Color3.fromRGB(255, 150, 30)
							fireball.Material = Enum.Material.Neon
							fireball.CanCollide = false
							fireball.Anchored = true
							fireball.CFrame = CFrame.new(startPos)
							fireball.Parent = workspace

							local fireTrail = Instance.new("ParticleEmitter")
							fireTrail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
							fireTrail.Rate = 22
							fireTrail.Speed = NumberRange.new(1, 3)
							fireTrail.Lifetime = NumberRange.new(0.3, 0.5)
							fireTrail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 80, 20))
							fireTrail.Parent = fireball

							playSound("PyroLaunch", "rbxasset://sounds/swordslash.wav", fireball, 2.0, 1.2)

							task.spawn(function()
								local currentPos = startPos
								for step = 1, 24 do
									currentPos = currentPos + flightDir * 2.4
									fireball.CFrame = CFrame.new(currentPos)
									local hit = false
									for _, p in CombatService.PlayersInRadius(currentPos, 4) do
										CombatService.ApplyDamageToPlayer(p, mobAttackDamage)
										hit = true
									end
									if hit then break end
									task.wait(0.03)
								end
								playSound("PyroImpact", "rbxasset://sounds/action_explode.mp3", fireball, 2.2, 1.0)
								fireball:Destroy()
							end)

							task.wait(0.2)
							if joints.rightShoulder and joints.origRightShoulderC0 then
								joints.rightShoulder.C0 = joints.origRightShoulderC0
							end
							isAttacking = false
						end)
					else
						-- ── MELEE ATTACK (Sunblade / Minion) ──
						if attackTrack then
							attackTrack:Play(0.08)
						end

						task.spawn(function()
							-- 1. Windup: raise arm high back (0.16s)
							local t0 = os.clock()
							while (os.clock() - t0) < 0.16 and alive do
								local a = math.clamp((os.clock() - t0) / 0.16, 0, 1)
								if joints.rightShoulder and joints.origRightShoulderC0 then
									joints.rightShoulder.C0 = joints.origRightShoulderC0 * CFrame.Angles(math.rad(a * 85), 0, math.rad(-a * 25))
								end
								if joints.leftShoulder and joints.origLeftShoulderC0 then
									joints.leftShoulder.C0 = joints.origLeftShoulderC0 * CFrame.Angles(math.rad(a * 40), 0, math.rad(a * 20))
								end
								task.wait(0.025)
							end

							-- 2. Heavy strike: slam downward & forward (0.10s)
							t0 = os.clock()
							while (os.clock() - t0) < 0.10 and alive do
								local a = math.clamp((os.clock() - t0) / 0.10, 0, 1)
								if joints.rightShoulder and joints.origRightShoulderC0 then
									local pitch = 85 - (a * 170)
									joints.rightShoulder.C0 = joints.origRightShoulderC0 * CFrame.Angles(math.rad(pitch), 0, math.rad(-25 + a * 45))
								end
								if joints.leftShoulder and joints.origLeftShoulderC0 then
									local pitch = 40 - (a * 80)
									joints.leftShoulder.C0 = joints.origLeftShoulderC0 * CFrame.Angles(math.rad(pitch), 0, math.rad(20 - a * 30))
								end
								task.wait(0.025)
							end

							-- 3. Recovery back to neutral (0.22s)
							t0 = os.clock()
							while (os.clock() - t0) < 0.22 and alive do
								local a = math.clamp((os.clock() - t0) / 0.22, 0, 1)
								if joints.rightShoulder and joints.origRightShoulderC0 then
									local pitch = -85 + (a * 85)
									joints.rightShoulder.C0 = joints.origRightShoulderC0 * CFrame.Angles(math.rad(pitch), 0, math.rad(20 - a * 20))
								end
								if joints.leftShoulder and joints.origLeftShoulderC0 then
									local pitch = -40 + (a * 40)
									joints.leftShoulder.C0 = joints.origLeftShoulderC0 * CFrame.Angles(math.rad(pitch), 0, math.rad(-10 + a * 10))
								end
								task.wait(0.025)
							end

							if joints.rightShoulder and joints.origRightShoulderC0 then
								joints.rightShoulder.C0 = joints.origRightShoulderC0
							end
							if joints.leftShoulder and joints.origLeftShoulderC0 then
								joints.leftShoulder.C0 = joints.origLeftShoulderC0
							end
							isAttacking = false
						end)

						local forwardDir = (flatTarget - myPos).Unit
						local strikeOffset = forwardDir * 1.5
						local lungeCF = CFrame.lookAt(myPos + strikeOffset, flatTarget + strikeOffset) * CFrame.Angles(0, math.pi, 0)
						local restCF = CFrame.lookAt(myPos, flatTarget) * CFrame.Angles(0, math.pi, 0)

						local lungeTween = TweenService:Create(
							model.PrimaryPart,
							TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ CFrame = lungeCF }
						)
						local recoilTween = TweenService:Create(
							model.PrimaryPart,
							TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
							{ CFrame = restCF }
						)
						lungeTween:Play()
						lungeTween.Completed:Connect(function()
							recoilTween:Play()
						end)

						task.delay(0.14, function()
							if alive and targetPlayer and targetPlayer.Character then
								CombatService.ApplyDamageToPlayer(targetPlayer, mobAttackDamage)
								playSound("MobHit", "rbxasset://sounds/swordslash.wav", model.PrimaryPart, 1.4, 1.2)
							end
						end)
					end
				end
			end

			-- Cleanup animations on mob death
			if walkTrack then
				pcall(function()
					walkTrack:Stop(0.1)
					walkTrack:Destroy()
				end)
			end
			if attackTrack then
				pcall(function()
					attackTrack:Stop(0.1)
					attackTrack:Destroy()
				end)
			end
		end)
	end

	return function()
		for _, handle in pairs(handles) do
			if handle.model and handle.model.Parent then
				handle.onDamaged(handle.currentHealth, nil)
			end
		end
	end
end

return MonsterAIService
