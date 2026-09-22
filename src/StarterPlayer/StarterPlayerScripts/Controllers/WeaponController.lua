-- src/StarterPlayer/StarterPlayerScripts/Controllers/WeaponController.lua
-- Manages weapon swing animations and visual effects on the client.
-- Controls procedural sword swings, sword trails, slash arcs, shield bashes, and defensive stances.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Net = require(ReplicatedStorage.Shared.Net)

local WeaponController = {}

-- Animation IDs for official Roblox combat animations (Action priority)
local R15_SLASH_ANIM = "rbxassetid://522635514"
local R6_SLASH_ANIM  = "rbxassetid://125750702"

-- Shield Bash forward charge: how far and how fast the caster lunges toward their target.
local SHIELD_BASH_DASH_DISTANCE = 14
local SHIELD_BASH_DASH_TIME = 0.15

local originalShoulderC0: {[Model]: {[string]: CFrame}} = {}
local originalGripC0: {[Model]: CFrame} = {}
local isAttacking: {[Model]: boolean} = {}

local function getAnimator(character: Model): Animator?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function playTrack(character: Model, animId: string)
	local animator = getAnimator(character)
	if not animator then
		return
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(0.04, 1, 1.5)
	end
end

local function findRightShoulder(character: Model): Motor6D?
	-- Check RightUpperArm first (standard R15 location)
	local rightUpperArm = character:FindFirstChild("RightUpperArm")
	if rightUpperArm then
		local shoulder = rightUpperArm:FindFirstChild("RightShoulder") or rightUpperArm:FindFirstChildWhichIsA("Motor6D")
		if shoulder then
			return shoulder
		end
	end

	-- Check UpperTorso
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local shoulder = upperTorso:FindFirstChild("RightShoulder") or upperTorso:FindFirstChildWhichIsA("Motor6D")
		if shoulder then
			return shoulder
		end
	end

	-- Check Torso (R6)
	local torso = character:FindFirstChild("Torso")
	if torso then
		local shoulder = torso:FindFirstChild("Right Shoulder") or torso:FindFirstChild("RightShoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	return nil
end

local function findLeftShoulder(character: Model): Motor6D?
	local leftUpperArm = character:FindFirstChild("LeftUpperArm")
	if leftUpperArm then
		local shoulder = leftUpperArm:FindFirstChild("LeftShoulder") or leftUpperArm:FindFirstChildWhichIsA("Motor6D")
		if shoulder then
			return shoulder
		end
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local shoulder = upperTorso:FindFirstChild("LeftShoulder") or upperTorso:FindFirstChildWhichIsA("Motor6D")
		if shoulder then
			return shoulder
		end
	end

	local torso = character:FindFirstChild("Torso")
	if torso then
		local shoulder = torso:FindFirstChild("Left Shoulder") or torso:FindFirstChild("LeftShoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	return nil
end

local function findSwordGrip(character: Model): Motor6D?
	local sword = character:FindFirstChild("EquippedSword")
	if not sword then
		return nil
	end
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if rightHand then
		local grip = rightHand:FindFirstChild("SwordGrip")
		if grip and grip:IsA("Motor6D") then
			return grip
		end
	end
	return sword:FindFirstChildWhichIsA("Motor6D", true)
end

local function findShieldGrip(character: Model): Motor6D?
	local shield = character:FindFirstChild("EquippedShield")
	if not shield then
		return nil
	end
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if leftHand then
		local grip = leftHand:FindFirstChild("ShieldGrip")
		if grip and grip:IsA("Motor6D") then
			return grip
		end
	end
	return shield:FindFirstChildWhichIsA("Motor6D", true)
end

local function findTorsoJoint(character: Model, jointName: string): Motor6D?
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local joint = upperTorso:FindFirstChild(jointName)
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	return nil -- R6 has no waist joint; torso lean is simply skipped on that rig
end

local function getSwordTrail(character: Model): Trail?
	local sword = character:FindFirstChild("EquippedSword")
	if not sword then
		return nil
	end
	return sword:FindFirstChildWhichIsA("Trail", true)
end

local function isSunforgedEquipped(character: Model): boolean
	local sword = character:FindFirstChild("EquippedSword")
	return sword ~= nil and sword:FindFirstChild("RunicFuller") ~= nil
end

-- Spawns a radial burst of small Pyramid-mesh shards from a point -- shared by several
-- impact effects (Slash, Shield Bash, Earthshaker) for a sharper, more textured hit
-- than a single flat shape alone.
local function spawnShardBurst(center: Vector3, color: Color3, count: number, travelDistance: number, shardSize: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.6
		local outward = Vector3.new(math.sin(angle), 0.6 + math.random() * 0.4, math.cos(angle))

		local shard = Instance.new("Part")
		shard.Name = "ShardBurstPiece"
		shard.Size = Vector3.new(shardSize, shardSize * 1.8, shardSize)
		shard.Color = color
		shard.Material = Enum.Material.Neon
		shard.Transparency = 0.1
		shard.Anchored = true
		shard.CanCollide = false
		shard.CastShadow = false
		shard.CFrame = CFrame.new(center, center + outward)

		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Pyramid
		mesh.Parent = shard

		shard.Parent = workspace

		TweenService:Create(shard, TweenInfo.new(0.22 + math.random() * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = center + outward * travelDistance,
			Transparency = 1,
			Size = Vector3.new(shardSize * 0.3, shardSize * 0.5, shardSize * 0.3),
		}):Play()
		Debris:AddItem(shard, 0.35)
	end
end

-- Spawns a glowing neon slash crescent effect in front of the character during a sword swing
local function spawnSlashArc(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local isSunforged = isSunforgedEquipped(character)
	local outerColor = isSunforged and Color3.fromRGB(255, 210, 65) or Color3.fromRGB(205, 220, 238)
	local coreColor  = isSunforged and Color3.fromRGB(255, 255, 235) or Color3.fromRGB(255, 255, 255)
	local lightColor = isSunforged and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(215, 230, 255)

	-- Outer radiant crescent arc
	local arc = Instance.new("Part")
	arc.Name = "SlashArcEffect"
	arc.Size = Vector3.new(4.8, 0.1, 4.8)
	arc.Color = outerColor
	arc.Material = Enum.Material.Neon
	arc.Transparency = 0.30
	arc.CanCollide = false
	arc.Anchored = true
	arc.CastShadow = false

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.0, 0.04, 1.0)
	mesh.Parent = arc

	-- Inner brilliant white-hot core crescent
	local coreArc = Instance.new("Part")
	coreArc.Name = "SlashCoreArc"
	coreArc.Size = Vector3.new(3.8, 0.08, 3.8)
	coreArc.Color = coreColor
	coreArc.Material = Enum.Material.Neon
	coreArc.Transparency = 0.15
	coreArc.CanCollide = false
	coreArc.Anchored = true
	coreArc.CastShadow = false

	local coreMesh = Instance.new("SpecialMesh")
	coreMesh.MeshType = Enum.MeshType.Sphere
	coreMesh.Scale = Vector3.new(1.0, 0.03, 1.0)
	coreMesh.Parent = coreArc

	local forwardCFrame = root.CFrame * CFrame.new(0.5, 0.2, -2.5) * CFrame.Angles(math.rad(-25), math.rad(30), math.rad(45))
	arc.CFrame = forwardCFrame
	coreArc.CFrame = forwardCFrame
	arc.Parent = workspace
	coreArc.Parent = workspace

	spawnShardBurst(forwardCFrame.Position, coreColor, 4, 1.8, 0.3)

	-- Flash light on impact
	local flashLight = Instance.new("PointLight")
	flashLight.Color = lightColor
	flashLight.Brightness = isSunforged and 3 or 2
	flashLight.Range = 12
	flashLight.Parent = arc

	local tween = TweenService:Create(arc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		CFrame = forwardCFrame * CFrame.new(0, 0, -1.2),
		Size = Vector3.new(6.8, 0.1, 6.8),
	})
	tween:Play()
	Debris:AddItem(arc, 0.25)

	local coreTween = TweenService:Create(coreArc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		CFrame = forwardCFrame * CFrame.new(0, 0, -1.0),
		Size = Vector3.new(5.2, 0.08, 5.2),
	})
	coreTween:Play()
	Debris:AddItem(coreArc, 0.20)

	-- Built-in crisp Roblox sword slash audio
	local sound = Instance.new("Sound")
	sound.Name = "SlashSound"
	sound.SoundId = "rbxasset://sounds/swordslash.wav"
	sound.Volume = 0.65
	sound.PlaybackSpeed = 1.05 + (math.random() - 0.5) * 0.1
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 1.0)
end

local function spawnShieldBashEffect(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local impactCFrame = root.CFrame * CFrame.new(0, 0.2, -4.5)
	local impactPos = impactCFrame.Position

	-- Heavy steel-blue impact disc -- like the slash arc but broader and heavier-reading
	local disc = Instance.new("Part")
	disc.Name = "ShieldBashImpact"
	disc.Size = Vector3.new(5.5, 0.1, 5.5)
	disc.Color = Color3.fromRGB(180, 210, 235)
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.15
	disc.Anchored = true
	disc.CanCollide = false
	disc.CastShadow = false
	disc.CFrame = impactCFrame
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.0, 0.05, 1.0)
	mesh.Parent = disc
	disc.Parent = workspace

	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(210, 230, 255)
	flash.Brightness = 4
	flash.Range = 16
	flash.Parent = disc

	TweenService:Create(disc, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(8.5, 0.1, 8.5),
		Transparency = 1,
	}):Play()
	Debris:AddItem(disc, 0.25)

	spawnShardBurst(impactPos, Color3.fromRGB(200, 215, 230), 6, 3.2, 0.4)
end

local function spawnGuardStanceEffect(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	-- Personal steel-grey dome pulse -- distinct from Fortress Aura's blue party-wide dome
	local dome = Instance.new("Part")
	dome.Name = "GuardStanceDome"
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.new(4, 4, 4)
	dome.Position = root.Position
	dome.Anchored = true
	dome.CanCollide = false
	dome.Color = Color3.fromRGB(150, 160, 175)
	dome.Material = Enum.Material.ForceField
	dome.Transparency = 0.35
	dome.Parent = workspace
	TweenService:Create(dome, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(8, 8, 8),
		Transparency = 0.85,
	}):Play()
	Debris:AddItem(dome, 1.0)

	-- Ground ring stamping down at the feet as the stance locks in
	local floorY = root.Position.Y - 2.85
	local ring = Instance.new("Part")
	ring.Name = "GuardStanceRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Position = Vector3.new(root.Position.X, floorY, root.Position.Z)
	ring.Size = Vector3.new(0.3, 3, 3)
	ring.Color = Color3.fromRGB(170, 180, 195)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, 9, 9),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.45)
end

local function spawnEarthshakerEffect(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local wave = Instance.new("Part")
	wave.Name = "EarthshakerWave"
	wave.Shape = Enum.PartType.Cylinder
	wave.Size = Vector3.new(0.5, 2, 2)
	wave.Orientation = Vector3.new(0, 0, 90)
	wave.Position = root.Position - Vector3.new(0, 2.5, 0)
	wave.Anchored = true
	wave.CanCollide = false
	wave.Color = Color3.fromRGB(196, 112, 42) -- earthy rust-orange, reads as ground/rock rather than generic fire-orange
	wave.Material = Enum.Material.Neon
	wave.Transparency = 0.25
	wave.Parent = workspace

	local tween = TweenService:Create(wave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.5, 32, 32),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(wave, 0.5)

	-- Jagged rock spikes bursting up out of the ground in a ring, so the impact reads
	-- specifically as "earth" rather than just a colored shockwave.
	local groundY = root.Position.Y - 2.5
	local spikeCount = 8
	local spikeRadius = 6
	for i = 1, spikeCount do
		local angle = (i / spikeCount) * math.pi * 2
		local spikeX = root.Position.X + math.sin(angle) * spikeRadius
		local spikeZ = root.Position.Z + math.cos(angle) * spikeRadius

		local spike = Instance.new("Part")
		spike.Name = "EarthshakerSpike"
		spike.Size = Vector3.new(1.2, 0.5, 1.2)
		spike.Color = Color3.fromRGB(120, 78, 48)
		spike.Material = Enum.Material.Slate
		spike.Anchored = true
		spike.CanCollide = false
		spike.CastShadow = false
		spike.Position = Vector3.new(spikeX, groundY, spikeZ)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Pyramid
		mesh.Parent = spike
		spike.Parent = workspace

		local risenHeight = 2.6 + math.random() * 1.2
		TweenService:Create(spike, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(1.2, risenHeight, 1.2),
			Position = Vector3.new(spikeX, groundY + risenHeight * 0.5, spikeZ),
		}):Play()

		task.delay(0.35, function()
			if spike and spike.Parent then
				TweenService:Create(spike, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = Vector3.new(1.2, 0.2, 1.2),
					Position = Vector3.new(spikeX, groundY, spikeZ),
				}):Play()
			end
		end)
		Debris:AddItem(spike, 0.65)
	end
end

local function spawnIronWillEffect(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local pillar = Instance.new("Part")
	pillar.Name = "IronWillAura"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(10, 4, 4)
	pillar.Orientation = Vector3.new(0, 0, 90)
	pillar.Position = root.Position
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Color = Color3.fromRGB(255, 220, 90)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.35
	pillar.Parent = workspace

	local tween = TweenService:Create(pillar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = root.Position + Vector3.new(0, 4, 0),
		Size = Vector3.new(14, 6, 6),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(pillar, 0.65)

	-- Small golden motes rising and fading around the caster, for a more magical
	-- restoration feel than the pillar alone.
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local radius = 1.6 + math.random() * 0.8
		local motePos = root.Position + Vector3.new(math.sin(angle) * radius, -1.5, math.cos(angle) * radius)

		local mote = Instance.new("Part")
		mote.Name = "IronWillMote"
		mote.Shape = Enum.PartType.Ball
		mote.Size = Vector3.new(0.35, 0.35, 0.35)
		mote.Color = Color3.fromRGB(255, 235, 150)
		mote.Material = Enum.Material.Neon
		mote.Transparency = 0.1
		mote.Anchored = true
		mote.CanCollide = false
		mote.CastShadow = false
		mote.Position = motePos
		mote.Parent = workspace

		TweenService:Create(mote, TweenInfo.new(0.6 + math.random() * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = motePos + Vector3.new(0, 4.5, 0),
			Transparency = 1,
			Size = Vector3.new(0.15, 0.15, 0.15),
		}):Play()
		Debris:AddItem(mote, 0.85)
	end
end

local function spawnFortressAuraEffect(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local dome = Instance.new("Part")
	dome.Name = "FortressAuraDome"
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.new(6, 6, 6)
	dome.Position = root.Position
	dome.Anchored = true
	dome.CanCollide = false
	dome.Color = Color3.fromRGB(60, 160, 255)
	dome.Material = Enum.Material.ForceField
	dome.Transparency = 0.35
	dome.Parent = workspace

	local tween = TweenService:Create(dome, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(24, 24, 24),
		Transparency = 0.85,
	})
	tween:Play()
	Debris:AddItem(dome, 2.0)

	-- Ground ring spreading outward, visually suggesting the aura reaching nearby party
	-- members rather than just a bubble around the caster.
	local floorY = root.Position.Y - 2.85
	local groundRing = Instance.new("Part")
	groundRing.Name = "FortressAuraGroundRing"
	groundRing.Shape = Enum.PartType.Cylinder
	groundRing.Orientation = Vector3.new(0, 0, 90)
	groundRing.Position = Vector3.new(root.Position.X, floorY, root.Position.Z)
	groundRing.Size = Vector3.new(0.3, 4, 4)
	groundRing.Color = Color3.fromRGB(80, 170, 255)
	groundRing.Material = Enum.Material.Neon
	groundRing.Transparency = 0.35
	groundRing.Anchored = true
	groundRing.CanCollide = false
	groundRing.CastShadow = false
	groundRing.Parent = workspace
	TweenService:Create(groundRing, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, 26, 26),
		Transparency = 1,
	}):Play()
	Debris:AddItem(groundRing, 0.9)
end

local function spawnTauntEffect(character: Model, rangeRadius: number?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local radius = rangeRadius or 30
	local diameter = radius * 2
	local centre = root.Position
	local floorY = centre.Y - 2.85

	-- ── 1. THREE STAGGERED SHOCKWAVE RINGS ──────────────────────────────────
	-- Ring 1: snappy initial burst (fires at cast — Phase 1 wind-up)
	local function makeRing(delay: number, startD: number, endD: number, color: Color3, alpha: number, thick: number)
		task.delay(delay, function()
			if not (root and root.Parent) then return end
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Cylinder
			ring.Orientation = Vector3.new(0, 0, 90)
			ring.Position = Vector3.new(centre.X, floorY + 0.12, centre.Z)
			ring.Size = Vector3.new(thick, startD, startD)
			ring.Color = color
			ring.Material = Enum.Material.Neon
			ring.Transparency = alpha
			ring.Anchored = true
			ring.CanCollide = false
			ring.CastShadow = false
			ring.Parent = workspace
			TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(thick, endD, endD),
				Transparency = 1,
			}):Play()
			Debris:AddItem(ring, 0.65)
		end)
	end
	-- Ring 1: fast burst at cast moment
	makeRing(0,    6,  diameter * 0.6, Color3.fromRGB(255, 215, 50),  0.20, 0.55)
	-- Ring 2: mid-shout (timed to Phase 2 at 0.14s) — reaches full range
	makeRing(0.14, 4,  diameter,       Color3.fromRGB(255, 185, 40),  0.28, 0.40)
	-- Ring 3: echo ring after roar settles (0.45s) — thin golden pulse
	makeRing(0.45, diameter * 0.7, diameter * 1.05, Color3.fromRGB(255, 240, 120), 0.18, 0.22)

	-- ── 2. EXACT RANGE BOUNDARY ──────────────────────────────────────────────
	local boundaryRing = Instance.new("Part")
	boundaryRing.Name = "TauntRangeBoundary"
	boundaryRing.Shape = Enum.PartType.Cylinder
	boundaryRing.Orientation = Vector3.new(0, 0, 90)
	boundaryRing.Position = Vector3.new(centre.X, floorY + 0.18, centre.Z)
	boundaryRing.Size = Vector3.new(0.28, diameter, diameter)
	boundaryRing.Color = Color3.fromRGB(255, 200, 50)
	boundaryRing.Material = Enum.Material.Neon
	boundaryRing.Transparency = 0.30
	boundaryRing.Anchored = true
	boundaryRing.CanCollide = false
	boundaryRing.Parent = workspace

	local innerZone = Instance.new("Part")
	innerZone.Name = "TauntRangeZone"
	innerZone.Shape = Enum.PartType.Cylinder
	innerZone.Orientation = Vector3.new(0, 0, 90)
	innerZone.Position = Vector3.new(centre.X, floorY + 0.13, centre.Z)
	innerZone.Size = Vector3.new(0.12, diameter - 1.5, diameter - 1.5)
	innerZone.Color = Color3.fromRGB(255, 130, 20)
	innerZone.Material = Enum.Material.ForceField
	innerZone.Transparency = 0.50
	innerZone.Anchored = true
	innerZone.CanCollide = false
	innerZone.Parent = workspace

	task.delay(0.90, function()
		for _, p in {boundaryRing, innerZone} do
			if p and p.Parent then
				TweenService:Create(p, TweenInfo.new(0.30, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(boundaryRing, 1.3)
	Debris:AddItem(innerZone, 1.3)

	-- ── 3. CHEST BURST ORB ────────────────────────────────────────────────────
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(3, 3, 3)
	orb.Position = centre + Vector3.new(0, 1, 0)
	orb.Color = Color3.fromRGB(255, 220, 60)
	orb.Material = Enum.Material.Neon
	orb.Transparency = 0.05
	orb.Anchored = true
	orb.CanCollide = false
	orb.CastShadow = false
	orb.Parent = workspace
	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(255, 215, 80)
	orbLight.Brightness = 7
	orbLight.Range = 24
	orbLight.Parent = orb
	TweenService:Create(orb, TweenInfo.new(0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(diameter * 0.85, diameter * 0.85, diameter * 0.85),
		Transparency = 1,
	}):Play()
	Debris:AddItem(orb, 0.60)

	-- ── 4. GOLDEN FIRE PILLAR rising from feet ────────────────────────────────
	local pillar = Instance.new("Part")
	pillar.Name = "TauntWarcryPillar"
	pillar.Size = Vector3.new(3.5, 0.8, 3.5)
	pillar.Position = Vector3.new(centre.X, floorY, centre.Z)
	pillar.Color = Color3.fromRGB(255, 210, 50)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.10
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CastShadow = false
	pillar.Parent = workspace
	local pillarLight = Instance.new("PointLight")
	pillarLight.Color = Color3.fromRGB(255, 200, 60)
	pillarLight.Brightness = 6
	pillarLight.Range = 28
	pillarLight.Parent = pillar
	-- Rise to 20 studs
	TweenService:Create(pillar, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(3.5, 20, 3.5),
		Position = Vector3.new(centre.X, floorY + 10, centre.Z),
		Transparency = 0.35,
	}):Play()
	task.delay(0.55, function()
		if pillar and pillar.Parent then
			TweenService:Create(pillar, TweenInfo.new(0.35, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(pillar, 1.0)

	-- ── 5. BODY AURA LIGHT on the caster's torso ─────────────────────────────
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
	if torso then
		local aura = Instance.new("PointLight")
		aura.Name = "TauntAuraLight"
		aura.Color = Color3.fromRGB(255, 215, 60)
		aura.Brightness = 8
		aura.Range = 20
		aura.Parent = torso
		-- Pulse: fade to bright then off over 0.9s
		TweenService:Create(aura, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 12 }):Play()
		task.delay(0.18, function()
			if aura and aura.Parent then
				TweenService:Create(aura, TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
			end
		end)
		Debris:AddItem(aura, 1.0)
	end

	-- ── 6. OVERHEAD "😡 WARCRY!" BADGE ─────────────────────────────────────────
	local headPart = character:FindFirstChild("Head") or root
	local bb = Instance.new("BillboardGui")
	bb.Name = "WarcryBillboard"
	bb.Size = UDim2.new(0, 180, 0, 42)
	bb.StudsOffset = Vector3.new(0, 2.0, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 80
	bb.ClipsDescendants = false
	bb.Parent = headPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 230, 60)
	label.TextStrokeColor3 = Color3.fromRGB(30, 15, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "⚡ WARCRY!"
	label.TextTransparency = 1   -- starts invisible — scales in
	label.TextStrokeTransparency = 1
	label.Parent = bb

	-- Scale-in then float-up and fade
	task.spawn(function()
		-- Pop in quickly (0–0.12s)
		local popIn = 0.12
		local hold   = 0.35  -- hold visible
		local fadeOut = 0.40
		local startOffset = 2.0
		local peakOffset  = 4.5
		local t = 0

		while t < popIn and bb.Parent do
			local dt = task.wait()
			t += dt
			local p = math.clamp(t / popIn, 0, 1)
			label.TextTransparency = 1 - p
			label.TextStrokeTransparency = 1 - p
			bb.StudsOffset = Vector3.new(0, startOffset + p * 0.8, 0)
		end
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0

		-- Hold pose
		local elapsed = 0
		while elapsed < hold and bb.Parent do
			local dt = task.wait()
			elapsed += dt
			bb.StudsOffset = Vector3.new(0, peakOffset - 1 + elapsed * 0.5, 0)
		end

		-- Float-up + fade
		elapsed = 0
		while elapsed < fadeOut and bb.Parent do
			local dt = task.wait()
			elapsed += dt
			local p = math.clamp(elapsed / fadeOut, 0, 1)
			label.TextTransparency = p
			label.TextStrokeTransparency = p
			bb.StudsOffset = Vector3.new(0, peakOffset + elapsed * 3.5, 0)
		end
		if bb and bb.Parent then bb:Destroy() end
	end)
end

local function showTauntedEnemyFeedback(enemyModel: Model)
	if not enemyModel or not enemyModel.Parent then return end

	local part = enemyModel.PrimaryPart or enemyModel:FindFirstChildWhichIsA("BasePart")
	if not part then return end

	-- ── 1. DOUBLE RED FLASH (two pulses — the second confirms the lock-on) ────
	local flashParts = {}
	for _, desc in enemyModel:GetDescendants() do
		if desc:IsA("BasePart") and desc.Material ~= Enum.Material.Neon then
			flashParts[#flashParts + 1] = { part = desc, orig = desc.Color }
		end
	end
	local function doFlash(delay: number)
		task.delay(delay, function()
			for _, e in flashParts do
				if e.part and e.part.Parent then
					e.part.Color = Color3.fromRGB(255, 50, 40)
				end
			end
			task.delay(0.12, function()
				for _, e in flashParts do
					if e.part and e.part.Parent then
						e.part.Color = e.orig
					end
				end
			end)
		end)
	end
	doFlash(0)
	doFlash(0.22)  -- second confirming pulse

	-- ── 2. THREAT AURA LIGHT on enemy body ───────────────────────────────────
	local threatLight = Instance.new("PointLight")
	threatLight.Name = "TauntThreatLight"
	threatLight.Color = Color3.fromRGB(255, 40, 20)
	threatLight.Brightness = 6
	threatLight.Range = 18
	threatLight.Parent = part
	TweenService:Create(threatLight, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 10 }):Play()
	task.delay(0.20, function()
		if threatLight and threatLight.Parent then
			TweenService:Create(threatLight, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		end
	end)
	Debris:AddItem(threatLight, 1.3)

	-- ── 3. SPINNING THREAT RING around the enemy ──────────────────────────────
	local _, extents = enemyModel:GetBoundingBox()
	local enemyWidth = math.max(extents.X, extents.Z) + 1.5
	local ringHeight = part.Position.Y -- centre height
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.30, enemyWidth * 2, enemyWidth * 2)
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Position = Vector3.new(part.Position.X, ringHeight, part.Position.Z)
	ring.Color = Color3.fromRGB(255, 55, 40)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Parent = workspace

	-- Spin the ring on Y axis and fade out over 1.0s
	task.spawn(function()
		local elapsed = 0
		local spinDur = 1.0
		local angle = 0
		while elapsed < spinDur and ring and ring.Parent do
			local dt = task.wait()
			elapsed += dt
			angle += dt * 280  -- degrees per second
			local p = math.clamp(elapsed / spinDur, 0, 1)
			ring.Transparency = 0.25 + p * 0.75
			ring.Orientation = Vector3.new(angle * 0.4, angle, 90)
		end
		if ring and ring.Parent then ring:Destroy() end
	end)

	-- ── 4. OVERHEAD "💢 TAUNTED!" BADGE ──────────────────────────────────────
	local heightOffset = math.clamp((extents.Y / 2) + 1.5, 2.5, 8.0)

	local bb = Instance.new("BillboardGui")
	bb.Name = "TauntHitBillboard"
	bb.Size = UDim2.new(0, 170, 0, 40)
	bb.StudsOffset = Vector3.new(0, heightOffset, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 55, 45)
	label.TextStrokeColor3 = Color3.fromRGB(15, 5, 5)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "💢 TAUNTED!"
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.Parent = bb

	task.spawn(function()
		-- Quick pop-in (0.10s)
		local t = 0
		while t < 0.10 and bb.Parent do
			local dt = task.wait()
			t += dt
			local p = math.clamp(t / 0.10, 0, 1)
			label.TextTransparency = 1 - p
			label.TextStrokeTransparency = 1 - p
		end
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0

		-- Hold (0.45s)
		local elapsed = 0
		while elapsed < 0.45 and bb.Parent do
			local dt = task.wait()
			elapsed += dt
			bb.StudsOffset = Vector3.new(0, heightOffset + elapsed * 0.4, 0)
		end

		-- Float-up + fade (0.55s)
		elapsed = 0
		while elapsed < 0.55 and bb.Parent do
			local dt = task.wait()
			elapsed += dt
			local p = math.clamp(elapsed / 0.55, 0, 1)
			label.TextTransparency = p
			label.TextStrokeTransparency = p
			bb.StudsOffset = Vector3.new(0, heightOffset + 0.18 + elapsed * 3.0, 0)
		end
		if bb and bb.Parent then bb:Destroy() end
	end)
end

local function safeGetC0(joint: Instance?): CFrame?
	if not joint then return nil end
	local ok, c0 = pcall(function()
		return (joint :: any).C0
	end)
	if ok and typeof(c0) == "CFrame" then
		return c0
	end
	return nil
end

local function safeSetC0(joint: Instance?, c0: CFrame)
	if not joint then return end
	pcall(function()
		(joint :: any).C0 = c0
	end)
end

local function safeTweenC0(joint: Instance?, tweenInfo: TweenInfo, targetC0: CFrame): Tween?
	if not joint then return nil end
	local ok, tween = pcall(function()
		local t = TweenService:Create(joint, tweenInfo, { C0 = targetC0 })
		t:Play()
		return t
	end)
	if ok and tween then
		return tween
	end
	return nil
end

-- ============================================================================
-- MAGE SPELL EFFECT HELPERS
-- ============================================================================

local function getCastOrigin(character: Model): Vector3
	local staff = character:FindFirstChild("EquippedSword") or character:FindFirstChild("EquippedWeapon")
	if staff then
		local crystal = staff:FindFirstChild("FocusCrystal") or staff:FindFirstChild("MagmaCore") or staff:FindFirstChild("CrownBase")
		if crystal and crystal:IsA("BasePart") then
			return crystal.Position
		end
	end
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if rightHand then
		local root = character:FindFirstChild("HumanoidRootPart")
		local forward = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
		return rightHand.Position + forward * 1.5 + Vector3.new(0, 0.5, 0)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 0.5, 0)) or Vector3.zero
end

local function findSpellTarget(character: Model, maxDist: number, maxAngle: number?): Vector3
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return character:GetPivot().Position + character:GetPivot().LookVector * (maxDist or 30)
	end

	local look = root.CFrame.LookVector
	local origin = root.Position
	local bestTarget: Vector3? = nil
	local bestDist = maxDist or 45
	local angleThreshold = math.cos(math.rad(maxAngle or 60))

	for _, enemy in CollectionService:GetTagged("Enemy") do
		if enemy:IsA("Model") and enemy.Parent then
			local part = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart")
			if part then
				local toPart = (part.Position - origin)
				local dist = toPart.Magnitude
				if dist > 0 and dist <= bestDist then
					local dot = look:Dot(toPart.Unit)
					if dot >= angleThreshold then
						bestDist = dist
						bestTarget = part.Position + Vector3.new(0, 0.5, 0)
					end
				end
			end
		end
	end

	if bestTarget then
		return bestTarget
	end

	return origin + look * (maxDist or 30)
end

local function playSpellSound(parent: Instance, soundId: string, volume: number?, speed: number?)
	local snd = Instance.new("Sound")
	snd.SoundId = soundId
	snd.Volume = volume or 0.65
	snd.PlaybackSpeed = (speed or 1.0) + (math.random() - 0.5) * 0.1
	snd.Parent = parent
	snd:Play()
	Debris:AddItem(snd, 1.2)
end

local function spawnArcaneBoltEffect(character: Model)
	local origin = getCastOrigin(character)
	local target = findSpellTarget(character, 35)

	-- Arcane projectile orb
	local bolt = Instance.new("Part")
	bolt.Name = "ArcaneBoltProjectile"
	bolt.Size = Vector3.new(0.85, 0.85, 0.85)
	bolt.Shape = Enum.PartType.Ball
	bolt.Position = origin
	bolt.Color = Color3.fromRGB(195, 85, 255)
	bolt.Material = Enum.Material.Neon
	bolt.CanCollide = false
	bolt.Anchored = true
	bolt.CastShadow = false

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(215, 120, 255)
	glow.Brightness = 3.5
	glow.Range = 10
	glow.Parent = bolt

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.LightEmission = 1
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 40, 255)),
	})
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Lifetime = NumberRange.new(0.15, 0.35)
	sparkles.Rate = 25
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.Parent = bolt
	bolt.Parent = workspace

	playSpellSound(bolt, "rbxasset://sounds/electronicpingshort.wav", 0.5, 1.3)

	local travelDist = (target - origin).Magnitude
	local flightTime = math.clamp(travelDist / 120, 0.12, 0.28)

	local tween = TweenService:Create(bolt, TweenInfo.new(flightTime, Enum.EasingStyle.Linear), {
		Position = target,
	})
	tween:Play()

	task.delay(flightTime, function()
		if bolt and bolt.Parent then
			bolt:Destroy()
		end

		-- Arcane impact ring
		local ring = Instance.new("Part")
		ring.Name = "ArcaneImpactRing"
		ring.Size = Vector3.new(1.0, 0.1, 1.0)
		ring.Position = target
		ring.Color = Color3.fromRGB(215, 110, 255)
		ring.Material = Enum.Material.Neon
		ring.CanCollide = false
		ring.Anchored = true
		ring.CastShadow = false

		local rMesh = Instance.new("SpecialMesh")
		rMesh.MeshType = Enum.MeshType.Sphere
		rMesh.Scale = Vector3.new(1.0, 0.05, 1.0)
		rMesh.Parent = ring
		ring.Parent = workspace

		TweenService:Create(ring, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(5.0, 0.1, 5.0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.25)

		spawnShardBurst(target, Color3.fromRGB(205, 95, 255), 6, 2.5, 0.25)
		playSpellSound(workspace, "rbxasset://sounds/bell.wav", 0.6, 1.8)
	end)
end

local function spawnFireboltEffect(character: Model)
	local origin = getCastOrigin(character)
	local target = findSpellTarget(character, 35)

	local bolt = Instance.new("Part")
	bolt.Name = "FireboltProjectile"
	bolt.Size = Vector3.new(0.7, 0.7, 1.4)
	bolt.CFrame = CFrame.new(origin, target)
	bolt.Color = Color3.fromRGB(255, 115, 20)
	bolt.Material = Enum.Material.Neon
	bolt.CanCollide = false
	bolt.Anchored = true
	bolt.CastShadow = false

	local bMesh = Instance.new("SpecialMesh")
	bMesh.MeshType = Enum.MeshType.Sphere
	bMesh.Scale = Vector3.new(0.8, 0.8, 1.4)
	bMesh.Parent = bolt

	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 130, 30)
	fireLight.Brightness = 4.0
	fireLight.Range = 12
	fireLight.Parent = bolt

	local fireTrail = Instance.new("ParticleEmitter")
	fireTrail.LightEmission = 1
	fireTrail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 90, 15)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 5)),
	})
	fireTrail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	fireTrail.Lifetime = NumberRange.new(0.2, 0.4)
	fireTrail.Rate = 35
	fireTrail.Speed = NumberRange.new(0.5, 2.0)
	fireTrail.Parent = bolt
	bolt.Parent = workspace

	playSpellSound(bolt, "rbxasset://sounds/swordslash.wav", 0.5, 1.4)

	local travelDist = (target - origin).Magnitude
	local flightTime = math.clamp(travelDist / 130, 0.12, 0.26)

	TweenService:Create(bolt, TweenInfo.new(flightTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(target, target + (target - origin)),
	}):Play()

	task.delay(flightTime, function()
		if bolt and bolt.Parent then bolt:Destroy() end

		-- Fiery burst pop
		local blast = Instance.new("Part")
		blast.Shape = Enum.PartType.Ball
		blast.Size = Vector3.new(1.8, 1.8, 1.8)
		blast.Position = target
		blast.Color = Color3.fromRGB(255, 130, 25)
		blast.Material = Enum.Material.Neon
		blast.CanCollide = false
		blast.Anchored = true
		blast.Parent = workspace

		TweenService:Create(blast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(5.5, 5.5, 5.5),
			Transparency = 1,
		}):Play()
		Debris:AddItem(blast, 0.25)

		spawnShardBurst(target, Color3.fromRGB(255, 120, 20), 8, 3.2, 0.35)
		playSpellSound(workspace, "rbxasset://sounds/collide.wav", 0.6, 1.5)
	end)
end

local function spawnFireballEffect(character: Model)
	local origin = getCastOrigin(character)
	local target = findSpellTarget(character, 35)

	local orb = Instance.new("Part")
	orb.Name = "FireballOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2.2, 2.2, 2.2)
	orb.Position = origin
	orb.Color = Color3.fromRGB(255, 95, 15)
	orb.Material = Enum.Material.Neon
	orb.CanCollide = false
	orb.Anchored = true
	orb.CastShadow = false

	local core = Instance.new("Part")
	core.Name = "FireballCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.4, 1.4, 1.4)
	core.Position = origin
	core.Color = Color3.fromRGB(255, 230, 90)
	core.Material = Enum.Material.Neon
	core.CanCollide = false
	core.Anchored = true
	core.Parent = orb

	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 130, 25)
	fireLight.Brightness = 6.0
	fireLight.Range = 20
	fireLight.Parent = orb

	local emberEmitter = Instance.new("ParticleEmitter")
	emberEmitter.LightEmission = 1
	emberEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 110)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 105, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 15, 5)),
	})
	emberEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emberEmitter.Lifetime = NumberRange.new(0.3, 0.6)
	emberEmitter.Rate = 50
	emberEmitter.Speed = NumberRange.new(1.0, 3.5)
	emberEmitter.Parent = orb
	orb.Parent = workspace

	playSpellSound(orb, "rbxasset://sounds/collide.wav", 0.7, 0.9)

	local travelDist = (target - origin).Magnitude
	local flightTime = math.clamp(travelDist / 105, 0.16, 0.32)

	TweenService:Create(orb, TweenInfo.new(flightTime, Enum.EasingStyle.Linear), { Position = target }):Play()
	TweenService:Create(core, TweenInfo.new(flightTime, Enum.EasingStyle.Linear), { Position = target }):Play()

	task.delay(flightTime, function()
		if orb and orb.Parent then orb:Destroy() end

		-- Heavy Explosive Detonation Blast Dome
		local blast = Instance.new("Part")
		blast.Name = "FireballBlastDome"
		blast.Shape = Enum.PartType.Ball
		blast.Size = Vector3.new(3.0, 3.0, 3.0)
		blast.Position = target
		blast.Color = Color3.fromRGB(255, 110, 20)
		blast.Material = Enum.Material.Neon
		blast.Transparency = 0.1
		blast.CanCollide = false
		blast.Anchored = true
		blast.Parent = workspace

		local blastLight = Instance.new("PointLight")
		blastLight.Color = Color3.fromRGB(255, 150, 40)
		blastLight.Brightness = 8.0
		blastLight.Range = 26
		blastLight.Parent = blast

		TweenService:Create(blast, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(10.5, 10.5, 10.5),
			Transparency = 1,
		}):Play()
		Debris:AddItem(blast, 0.38)

		-- Radial Shockwave Ring
		local ring = Instance.new("Part")
		ring.Name = "FireballShockwaveRing"
		ring.Size = Vector3.new(2.0, 0.15, 2.0)
		ring.Position = target
		ring.Color = Color3.fromRGB(255, 175, 45)
		ring.Material = Enum.Material.Neon
		ring.CanCollide = false
		ring.Anchored = true
		local rMesh = Instance.new("SpecialMesh")
		rMesh.MeshType = Enum.MeshType.Sphere
		rMesh.Scale = Vector3.new(1.0, 0.05, 1.0)
		rMesh.Parent = ring
		ring.Parent = workspace

		TweenService:Create(ring, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(14.0, 0.15, 14.0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.32)

		spawnShardBurst(target, Color3.fromRGB(255, 120, 20), 14, 5.5, 0.5)
		playSpellSound(workspace, "rbxasset://sounds/collide.wav", 0.9, 0.75)
	end)
end

local function spawnMeteorEffect(character: Model)
	local target = findSpellTarget(character, 30)

	-- 1. Red Molten Ground Summoning Rune
	local rune = Instance.new("Part")
	rune.Name = "MeteorGroundRune"
	rune.Size = Vector3.new(16.0, 0.1, 16.0)
	rune.Position = Vector3.new(target.X, target.Y - 0.2, target.Z)
	rune.Color = Color3.fromRGB(255, 55, 15)
	rune.Material = Enum.Material.Neon
	rune.Transparency = 0.4
	rune.CanCollide = false
	rune.Anchored = true
	local rMesh = Instance.new("SpecialMesh")
	rMesh.MeshType = Enum.MeshType.Sphere
	rMesh.Scale = Vector3.new(1.0, 0.04, 1.0)
	rMesh.Parent = rune
	rune.Parent = workspace

	local runeGlow = Instance.new("PointLight")
	runeGlow.Color = Color3.fromRGB(255, 80, 20)
	runeGlow.Brightness = 4.0
	runeGlow.Range = 22
	runeGlow.Parent = rune

	-- 2. Falling Giant Blazing Meteor from the Sky
	local skyOrigin = target + Vector3.new(-14, 55, -12)

	local meteor = Instance.new("Part")
	meteor.Name = "MeteorRock"
	meteor.Size = Vector3.new(4.2, 4.2, 4.2)
	meteor.Position = skyOrigin
	meteor.Color = Color3.fromRGB(38, 30, 24)
	meteor.Material = Enum.Material.Slate
	meteor.CanCollide = false
	meteor.Anchored = true
	meteor.Parent = workspace

	local mCore = Instance.new("Part")
	mCore.Shape = Enum.PartType.Ball
	mCore.Size = Vector3.new(3.8, 3.8, 3.8)
	mCore.Position = skyOrigin
	mCore.Color = Color3.fromRGB(255, 90, 15)
	mCore.Material = Enum.Material.Neon
	mCore.CanCollide = false
	mCore.Anchored = true
	mCore.Parent = meteor

	local mLight = Instance.new("PointLight")
	mLight.Color = Color3.fromRGB(255, 120, 25)
	mLight.Brightness = 8.0
	mLight.Range = 30
	mLight.Parent = meteor

	local flameColumn = Instance.new("ParticleEmitter")
	flameColumn.LightEmission = 1
	flameColumn.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 100)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 15)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 15, 5)),
	})
	flameColumn.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	flameColumn.Lifetime = NumberRange.new(0.4, 0.8)
	flameColumn.Rate = 70
	flameColumn.Speed = NumberRange.new(3.0, 7.0)
	flameColumn.Parent = meteor

	playSpellSound(meteor, "rbxasset://sounds/collide.wav", 0.7, 0.6)

	-- Meteor plunge
	local fallTime = 0.42
	TweenService:Create(meteor, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target }):Play()
	TweenService:Create(mCore, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target }):Play()

	task.delay(fallTime, function()
		if meteor and meteor.Parent then meteor:Destroy() end
		if rune and rune.Parent then rune:Destroy() end

		-- Massive Impact Blast
		local craterBlast = Instance.new("Part")
		craterBlast.Name = "MeteorBlastDome"
		craterBlast.Shape = Enum.PartType.Ball
		craterBlast.Size = Vector3.new(4.0, 4.0, 4.0)
		craterBlast.Position = target
		craterBlast.Color = Color3.fromRGB(255, 100, 20)
		craterBlast.Material = Enum.Material.Neon
		craterBlast.Transparency = 0.05
		craterBlast.CanCollide = false
		craterBlast.Anchored = true
		craterBlast.Parent = workspace

		TweenService:Create(craterBlast, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(18.0, 18.0, 18.0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(craterBlast, 0.50)

		-- Ground Volcanic Shockwave Ring
		local sRing = Instance.new("Part")
		sRing.Name = "MeteorShockwave"
		sRing.Size = Vector3.new(3.0, 0.2, 3.0)
		sRing.Position = target
		sRing.Color = Color3.fromRGB(255, 160, 35)
		sRing.Material = Enum.Material.Neon
		sRing.CanCollide = false
		sRing.Anchored = true
		local srMesh = Instance.new("SpecialMesh")
		srMesh.MeshType = Enum.MeshType.Sphere
		srMesh.Scale = Vector3.new(1.0, 0.04, 1.0)
		srMesh.Parent = sRing
		sRing.Parent = workspace

		TweenService:Create(sRing, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(24.0, 0.2, 24.0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(sRing, 0.45)

		-- Cooling Magma Ground Scorch Crater
		local crater = Instance.new("Part")
		crater.Name = "MeteorCraterPlate"
		crater.Size = Vector3.new(14.0, 0.1, 14.0)
		crater.Position = Vector3.new(target.X, target.Y - 0.15, target.Z)
		crater.Color = Color3.fromRGB(180, 50, 15)
		crater.Material = Enum.Material.Neon
		crater.Transparency = 0.2
		crater.CanCollide = false
		crater.Anchored = true
		local cMesh = Instance.new("SpecialMesh")
		cMesh.MeshType = Enum.MeshType.Sphere
		cMesh.Scale = Vector3.new(1.0, 0.04, 1.0)
		cMesh.Parent = crater
		crater.Parent = workspace

		TweenService:Create(crater, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Color = Color3.fromRGB(35, 28, 24),
			Transparency = 1,
		}):Play()
		Debris:AddItem(crater, 1.5)

		spawnShardBurst(target, Color3.fromRGB(255, 100, 20), 18, 7.5, 0.65)
		playSpellSound(workspace, "rbxasset://sounds/collide.wav", 1.0, 0.6)
	end)
end

local function spawnFrostboltEffect(character: Model)
	local origin = getCastOrigin(character)
	local target = findSpellTarget(character, 35)

	local shard = Instance.new("Part")
	shard.Name = "FrostboltShard"
	shard.Size = Vector3.new(0.65, 0.65, 1.8)
	shard.CFrame = CFrame.new(origin, target)
	shard.Color = Color3.fromRGB(150, 230, 255)
	shard.Material = Enum.Material.Neon
	shard.CanCollide = false
	shard.Anchored = true

	local sMesh = Instance.new("SpecialMesh")
	sMesh.MeshType = Enum.MeshType.Sphere
	sMesh.Scale = Vector3.new(0.7, 0.7, 1.5)
	sMesh.Parent = shard

	local frostLight = Instance.new("PointLight")
	frostLight.Color = Color3.fromRGB(130, 215, 255)
	frostLight.Brightness = 3.5
	frostLight.Range = 10
	frostLight.Parent = shard

	local mistEmitter = Instance.new("ParticleEmitter")
	mistEmitter.LightEmission = 1
	mistEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 245, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 185, 255)),
	})
	mistEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	mistEmitter.Lifetime = NumberRange.new(0.2, 0.4)
	mistEmitter.Rate = 30
	mistEmitter.Speed = NumberRange.new(0.5, 1.5)
	mistEmitter.Parent = shard
	shard.Parent = workspace

	playSpellSound(shard, "rbxasset://sounds/snap.wav", 0.5, 1.6)

	local travelDist = (target - origin).Magnitude
	local flightTime = math.clamp(travelDist / 125, 0.12, 0.26)

	TweenService:Create(shard, TweenInfo.new(flightTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(target, target + (target - origin)),
	}):Play()

	task.delay(flightTime, function()
		if shard and shard.Parent then shard:Destroy() end

		-- Shattering ice crystal burst
		local burst = Instance.new("Part")
		burst.Name = "FrostImpactBurst"
		burst.Size = Vector3.new(1.2, 1.2, 1.2)
		burst.Position = target
		burst.Color = Color3.fromRGB(170, 240, 255)
		burst.Material = Enum.Material.Neon
		burst.CanCollide = false
		burst.Anchored = true
		burst.Parent = workspace

		TweenService:Create(burst, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(4.5, 4.5, 4.5),
			Transparency = 1,
		}):Play()
		Debris:AddItem(burst, 0.22)

		spawnShardBurst(target, Color3.fromRGB(140, 225, 255), 8, 2.8, 0.3)
		playSpellSound(workspace, "rbxasset://sounds/electronicpingshort.wav", 0.6, 2.0)
	end)
end

local function spawnIceLanceEffect(character: Model)
	local origin = getCastOrigin(character)
	local target = findSpellTarget(character, 35)

	-- Long piercing glacial lance
	local lance = Instance.new("Part")
	lance.Name = "IceLanceSpear"
	lance.Size = Vector3.new(0.5, 0.5, 3.4)
	lance.CFrame = CFrame.new(origin, target)
	lance.Color = Color3.fromRGB(130, 225, 255)
	lance.Material = Enum.Material.Neon
	lance.CanCollide = false
	lance.Anchored = true

	local lMesh = Instance.new("SpecialMesh")
	lMesh.MeshType = Enum.MeshType.Sphere
	lMesh.Scale = Vector3.new(0.6, 0.6, 1.8)
	lMesh.Parent = lance

	local lanceLight = Instance.new("PointLight")
	lanceLight.Color = Color3.fromRGB(150, 230, 255)
	lanceLight.Brightness = 4.5
	lanceLight.Range = 14
	lanceLight.Parent = lance

	local vaporEmitter = Instance.new("ParticleEmitter")
	vaporEmitter.LightEmission = 1
	vaporEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 250, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 180, 255)),
	})
	vaporEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	vaporEmitter.Lifetime = NumberRange.new(0.2, 0.45)
	vaporEmitter.Rate = 45
	vaporEmitter.Speed = NumberRange.new(0.8, 2.5)
	vaporEmitter.Parent = lance
	lance.Parent = workspace

	playSpellSound(lance, "rbxasset://sounds/swordslash.wav", 0.6, 1.8)

	local travelDist = (target - origin).Magnitude
	local flightTime = math.clamp(travelDist / 160, 0.10, 0.22)

	TweenService:Create(lance, TweenInfo.new(flightTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(target, target + (target - origin)),
	}):Play()

	task.delay(flightTime, function()
		if lance and lance.Parent then lance:Destroy() end

		-- Glacial Nova Ring
		local ring = Instance.new("Part")
		ring.Name = "IceNovaRing"
		ring.Size = Vector3.new(2.0, 0.12, 2.0)
		ring.Position = target
		ring.Color = Color3.fromRGB(160, 235, 255)
		ring.Material = Enum.Material.Neon
		ring.CanCollide = false
		ring.Anchored = true
		local rMesh = Instance.new("SpecialMesh")
		rMesh.MeshType = Enum.MeshType.Sphere
		rMesh.Scale = Vector3.new(1.0, 0.05, 1.0)
		rMesh.Parent = ring
		ring.Parent = workspace

		TweenService:Create(ring, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(9.0, 0.12, 9.0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.28)

		spawnShardBurst(target, Color3.fromRGB(150, 230, 255), 12, 4.5, 0.4)
		playSpellSound(workspace, "rbxasset://sounds/snap.wav", 0.7, 1.4)
	end)
end

local function spawnBlizzardEffect(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	local centre = root and root.Position or character:GetPivot().Position
	local floorY = centre.Y - 2.8

	-- 1. Large Winter Glyphic Ground Ring (20 studs diameter)
	local ring = Instance.new("Part")
	ring.Name = "BlizzardGroundZone"
	ring.Shape = Enum.PartType.Cylinder
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Position = Vector3.new(centre.X, floorY + 0.1, centre.Z)
	ring.Size = Vector3.new(0.12, 22.0, 22.0)
	ring.Color = Color3.fromRGB(120, 210, 255)
	ring.Material = Enum.Material.ForceField
	ring.Transparency = 0.35
	ring.CanCollide = false
	ring.Anchored = true
	ring.Parent = workspace

	local zoneLight = Instance.new("PointLight")
	zoneLight.Color = Color3.fromRGB(140, 220, 255)
	zoneLight.Brightness = 4.0
	zoneLight.Range = 26
	zoneLight.Parent = ring

	-- 2. Cloud Emitter raining snowflakes & icicles for 3.5 seconds
	local cloud = Instance.new("Part")
	cloud.Name = "BlizzardStormCloud"
	cloud.Size = Vector3.new(18, 1, 18)
	cloud.Position = Vector3.new(centre.X, floorY + 16, centre.Z)
	cloud.Transparency = 1
	cloud.CanCollide = false
	cloud.Anchored = true

	local snowEmitter = Instance.new("ParticleEmitter")
	snowEmitter.LightEmission = 1
	snowEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 225, 255)),
	})
	snowEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	snowEmitter.Lifetime = NumberRange.new(0.8, 1.4)
	snowEmitter.Rate = 60
	snowEmitter.Speed = NumberRange.new(12, 18)
	snowEmitter.EmissionDirection = Enum.NormalId.Bottom
	snowEmitter.SpreadAngle = Vector2.new(20, 20)
	snowEmitter.Parent = cloud
	cloud.Parent = workspace

	playSpellSound(ring, "rbxasset://sounds/swordslash.wav", 0.6, 0.7)

	-- Burst shards every 0.5s for the duration
	task.spawn(function()
		for i = 1, 6 do
			task.wait(0.5)
			if not ring or not ring.Parent then break end
			local randOffset = Vector3.new((math.random() - 0.5) * 16, 0.5, (math.random() - 0.5) * 16)
			spawnShardBurst(centre + randOffset, Color3.fromRGB(150, 230, 255), 4, 2.0, 0.25)
		end
	end)

	task.delay(3.5, function()
		if snowEmitter and snowEmitter.Parent then
			snowEmitter.Enabled = false
		end
		if ring and ring.Parent then
			TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(cloud, 4.5)
	Debris:AddItem(ring, 4.2)
end

function WeaponController.PlaySwing(character: Model, attackType: string)
	if not character or not character.Parent then
		return
	end

	local rightShoulder = findRightShoulder(character)
	local leftShoulder = findLeftShoulder(character)
	local swordGrip = findSwordGrip(character)
	local trail = getSwordTrail(character)

	-- Store default C0s if not already stored
	if not originalShoulderC0[character] then
		originalShoulderC0[character] = {}
	end
	if rightShoulder and not originalShoulderC0[character]["Right"] then
		originalShoulderC0[character]["Right"] = safeGetC0(rightShoulder)
	end
	if leftShoulder and not originalShoulderC0[character]["Left"] then
		originalShoulderC0[character]["Left"] = safeGetC0(leftShoulder)
	end
	if swordGrip and not originalGripC0[character] then
		originalGripC0[character] = safeGetC0(swordGrip)
	end

	local defaultRightC0 = rightShoulder and originalShoulderC0[character]["Right"]
	local defaultLeftC0 = leftShoulder and originalShoulderC0[character]["Left"]
	local defaultGripC0 = swordGrip and originalGripC0[character]

	-- ── 1. SWORD SLASH (Normal Attack / Provoking Strike) ──────────────────────
	if attackType == "Slash" or attackType == "ProvokingStrike" or attackType == "HeavySlash" then
		-- Play Humanoid AnimationTrack (blends naturally with upper body)
		local isR15 = (character:FindFirstChild("UpperTorso") ~= nil)
		if isR15 then
			playTrack(character, R15_SLASH_ANIM)
		else
			playTrack(character, R6_SLASH_ANIM)
		end

		-- Spawn slash arc effect in front of the blade
		spawnSlashArc(character)

		-- Enable Sword Trail
		if trail then
			trail.Enabled = true
			task.delay(0.25, function()
				if trail and trail.Parent then
					trail.Enabled = false
				end
			end)
		end

		-- Procedural Sword Grip swing
		if swordGrip and defaultGripC0 then
			local windupGrip = defaultGripC0 * CFrame.Angles(math.rad(40), math.rad(-25), math.rad(30))
			local slashGrip = defaultGripC0 * CFrame.Angles(math.rad(-110), math.rad(45), math.rad(-50))

			safeSetC0(swordGrip, windupGrip)
			safeTweenC0(swordGrip, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), windupGrip)

			task.delay(0.06, function()
				safeTweenC0(swordGrip, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), slashGrip)
				task.delay(0.12, function()
					safeTweenC0(swordGrip, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultGripC0)
				end)
			end)
		end

		-- Procedural Right Shoulder swing
		if rightShoulder and defaultRightC0 then
			local windupShoulder = defaultRightC0 * CFrame.Angles(math.rad(45), math.rad(-30), math.rad(30))
			local slashShoulder = defaultRightC0 * CFrame.Angles(math.rad(-85), math.rad(40), math.rad(-45))

			safeTweenC0(rightShoulder, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), windupShoulder)

			task.delay(0.06, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), slashShoulder)
				task.delay(0.12, function()
					safeTweenC0(rightShoulder, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
				end)
			end)
		end

	-- ── 2. SHIELD BASH (Leaping charge, shield leading, off-arm cocked back) ──
	elseif attackType == "ShieldBash" then
		-- No Humanoid animation track here (unlike other attacks): a punch/slash track
		-- would drive the right arm too, which visibly "raises the sword" during what
		-- should read as a shield-only bash. Only the shoulders + waist are hand-posed.
		local waist = findTorsoJoint(character, "Waist")
		local defaultWaistC0 = waist and safeGetC0(waist)

		-- Phase 1: WIND-UP -- shield pulls in tight, off-arm coils back, torso dips (0-0.08s)
		if leftShoulder and defaultLeftC0 then
			local coilL = defaultLeftC0 * CFrame.new(0.1, 0, -0.3) * CFrame.Angles(math.rad(45), 0, 0)
			safeTweenC0(leftShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), coilL)
		end
		if rightShoulder and defaultRightC0 then
			local coilR = defaultRightC0 * CFrame.Angles(math.rad(-65), math.rad(15), math.rad(-10))
			safeTweenC0(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), coilR)
		end
		if waist and defaultWaistC0 then
			local coilWaist = defaultWaistC0 * CFrame.Angles(math.rad(8), 0, 0)
			safeTweenC0(waist, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), coilWaist)
		end

		-- Phase 2: BASH -- shield punches out in front of the chest, torso leans hard
		-- into the charge, off-arm stays cocked back and up for balance (0.08-0.18s)
		task.delay(0.08, function()
			if not (character and character.Parent) then return end
			spawnShieldBashEffect(character)
			if leftShoulder and defaultLeftC0 then
				local bashC0 = defaultLeftC0 * CFrame.new(0.2, 0.1, -1.6) * CFrame.Angles(math.rad(95), math.rad(10), math.rad(-10))
				safeTweenC0(leftShoulder, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), bashC0)
			end
			if rightShoulder and defaultRightC0 then
				local backR = defaultRightC0 * CFrame.Angles(math.rad(-110), math.rad(20), math.rad(-15))
				safeTweenC0(rightShoulder, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), backR)
			end
			if waist and defaultWaistC0 then
				local leanWaist = defaultWaistC0 * CFrame.Angles(math.rad(22), 0, 0)
				safeTweenC0(waist, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), leanWaist)
			end

			-- Phase 3: RECOVER -- snap everything back to rest (0.18s onward)
			task.delay(0.14, function()
				if not (character and character.Parent) then return end
				if leftShoulder and defaultLeftC0 then
					safeTweenC0(leftShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultLeftC0)
				end
				if rightShoulder and defaultRightC0 then
					safeTweenC0(rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
				end
				if waist and defaultWaistC0 then
					safeTweenC0(waist, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultWaistC0)
				end
			end)
		end)

		-- Shield reorientation: some avatar rigs have no shoulder/waist Motor6D to pose at
		-- all (modern constraint-rig bodies), so the phases above silently do nothing on
		-- them. The shield's own grip IS a real Motor6D on every rig (it's how the shield
		-- attaches to the hand), so spin the shield itself to face forward -- the hand
		-- stays where it rests, but the shield reads as presented forward, not sideways.
		do
			local shieldGrip = findShieldGrip(character)
			local defaultShieldGripC0 = shieldGrip and safeGetC0(shieldGrip)
			local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
			local bashRoot = character:FindFirstChild("HumanoidRootPart")
			if shieldGrip and defaultShieldGripC0 and leftHand and bashRoot then
				-- The shield's local +Z is its outward/front face (see WeaponService's
				-- createStandardShieldModel: the decorative face sits in front of the
				-- backing along +Z). Re-aim that axis at the character's current facing.
				local desiredLocalZ = leftHand.CFrame:VectorToObjectSpace(bashRoot.CFrame.LookVector)
				local forwardFacing = CFrame.new(defaultShieldGripC0.Position) * CFrame.new(Vector3.new(), -desiredLocalZ)
				safeTweenC0(shieldGrip, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), forwardFacing)

				task.delay(0.22, function()
					safeTweenC0(shieldGrip, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultShieldGripC0)
				end)
			end
		end

		-- Only the caster's own client drives the lunge (they're the network owner of their
		-- HumanoidRootPart), so the movement replicates to everyone else through normal
		-- character-position replication instead of fighting it from a non-owning client.
		if character == Players.LocalPlayer.Character then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local targetCFrame = root.CFrame + (root.CFrame.LookVector * SHIELD_BASH_DASH_DISTANCE)
				pcall(function()
					TweenService:Create(
						root,
						TweenInfo.new(SHIELD_BASH_DASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ CFrame = targetCFrame }
					):Play()
				end)
			end
		end

	-- ── 3. TAUNT (Full battle-shout animation + layered warcry effects) ───────
	elseif attackType == "Taunt" then
		local root = character:FindFirstChild("HumanoidRootPart")
		local head = character:FindFirstChild("Head")
		local neck = (function()
			-- Try to find Neck joint (R15: head/UpperTorso, R6: head/Torso)
			if head then
				for _, j in head:GetChildren() do
					if j:IsA("Motor6D") then return j end
				end
			end
			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			if torso then
				for _, j in torso:GetChildren() do
					if j:IsA("Motor6D") and j.Name == "Neck" then return j end
				end
			end
			return nil
		end)()
		local defaultNeckC0 = neck and safeGetC0(neck)

		-- ── Phase 1: WIND-UP — arms explode wide, chest puffed (0–0.14s) ────────
		-- Both shoulders sweep out dramatically
		if rightShoulder and defaultRightC0 then
			-- Sword arm rockets upward-outward
			local spreadR = defaultRightC0 * CFrame.Angles(math.rad(-115), math.rad(25), math.rad(35))
			safeTweenC0(rightShoulder, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), spreadR)
		end
		if leftShoulder and defaultLeftC0 then
			-- Shield arm swings out to the left
			local spreadL = defaultLeftC0 * CFrame.Angles(math.rad(-100), math.rad(-20), math.rad(-30))
			safeTweenC0(leftShoulder, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), spreadL)
		end
		-- Head tilts slightly back (pre-roar wind-up)
		if neck and defaultNeckC0 then
			local tiltBack = defaultNeckC0 * CFrame.Angles(math.rad(-12), 0, 0)
			safeTweenC0(neck, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), tiltBack)
		end

		-- ── Phase 2: SHOUT — arms punch forward/down, head tilts back into roar (0.14–0.38s)
		task.delay(0.14, function()
			if not (character and character.Parent) then return end
			if rightShoulder and defaultRightC0 then
				-- Right arm thrusts forward-down (battle cry punch)
				local crierR = defaultRightC0 * CFrame.Angles(math.rad(70), math.rad(-30), math.rad(-20))
				safeTweenC0(rightShoulder, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), crierR)
			end
			if leftShoulder and defaultLeftC0 then
				-- Left arm thrusts forward-out (shield forward during cry)
				local crierL = defaultLeftC0 * CFrame.Angles(math.rad(60), math.rad(25), math.rad(15))
				safeTweenC0(leftShoulder, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), crierL)
			end
			-- Head snaps back fully — character is ROARING at the sky
			if neck and defaultNeckC0 then
				local roarHead = defaultNeckC0 * CFrame.Angles(math.rad(-30), 0, 0)
				safeTweenC0(neck, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), roarHead)
			end

			-- ── Phase 3: HOLD — sustain the roar pose briefly (0.24–0.52s) ─────
			task.delay(0.24, function()
				if not (character and character.Parent) then return end
				-- Slight arm tremor: punch arms a tiny bit further out (shaking with effort)
				if rightShoulder and defaultRightC0 then
					local trembleR = defaultRightC0 * CFrame.Angles(math.rad(75), math.rad(-28), math.rad(-22))
					safeTweenC0(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), trembleR)
				end
				if leftShoulder and defaultLeftC0 then
					local trembleL = defaultLeftC0 * CFrame.Angles(math.rad(65), math.rad(22), math.rad(18))
					safeTweenC0(leftShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), trembleL)
				end

				-- ── Phase 4: RECOVER — snap everything back (0.52s→) ───────────
				task.delay(0.28, function()
					if not (character and character.Parent) then return end
					if rightShoulder and defaultRightC0 then
						safeTweenC0(rightShoulder, TweenInfo.new(0.30, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), defaultRightC0)
					end
					if leftShoulder and defaultLeftC0 then
						safeTweenC0(leftShoulder, TweenInfo.new(0.30, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), defaultLeftC0)
					end
					if neck and defaultNeckC0 then
						safeTweenC0(neck, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultNeckC0)
					end
				end)
			end)
		end)

		-- ── WORLD EFFECTS ────────────────────────────────────────────────────────
		spawnTauntEffect(character, 30)

	-- ── 4. GUARD STANCE (Raise shield across chest) ───────────────────────────
	elseif attackType == "GuardStance" or attackType == "Guard" then
		spawnGuardStanceEffect(character)
		if leftShoulder and defaultLeftC0 then
			local guardC0 = defaultLeftC0 * CFrame.new(0.5, 0, -0.7) * CFrame.Angles(math.rad(55), math.rad(30), 0)
			safeTweenC0(leftShoulder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), guardC0)

			task.delay(0.65, function()
				safeTweenC0(leftShoulder, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultLeftC0)
			end)
		end

	-- ── 5. EARTHSHAKER (Overhead leap slam and shockwave) ────────────────────
	elseif attackType == "Earthshaker" then
		playTrack(character, R15_SLASH_ANIM)
		if rightShoulder and defaultRightC0 then
			local windupC0 = defaultRightC0 * CFrame.Angles(math.rad(140), math.rad(-15), math.rad(25))
			local slamC0 = defaultRightC0 * CFrame.Angles(math.rad(-75), math.rad(0), math.rad(-25))

			safeTweenC0(rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), windupC0)

			task.delay(0.18, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.In), slamC0)
				spawnEarthshakerEffect(character)

				task.delay(0.25, function()
					safeTweenC0(rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
				end)
			end)
		else
			spawnEarthshakerEffect(character)
		end

	-- ── 6. IRON WILL (Raise sword to channel golden heal) ─────────────────────
	elseif attackType == "IronWill" then
		if rightShoulder and defaultRightC0 then
			local prayC0 = defaultRightC0 * CFrame.Angles(math.rad(115), math.rad(-25), math.rad(15))
			safeTweenC0(rightShoulder, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), prayC0)

			spawnIronWillEffect(character)

			task.delay(0.55, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
			end)
		else
			spawnIronWillEffect(character)
		end

	-- ── 7. FORTRESS AURA (Project defensive shield barrier) ───────────────────
	elseif attackType == "FortressAura" then
		if leftShoulder and defaultLeftC0 then
			local raiseShield = defaultLeftC0 * CFrame.new(0.3, 0.2, -0.6) * CFrame.Angles(math.rad(75), math.rad(15), 0)
			safeTweenC0(leftShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), raiseShield)

			spawnFortressAuraEffect(character)

			task.delay(0.7, function()
				safeTweenC0(leftShoulder, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultLeftC0)
			end)
		else
			spawnFortressAuraEffect(character)
		end

	-- ── 8. ARCANE BOLT (Mage Starter / Normal Attack) ─────────────────────────
	elseif attackType == "ArcaneBolt" or attackType == "MageAttack" then
		if rightShoulder and defaultRightC0 then
			local thrustC0 = defaultRightC0 * CFrame.Angles(math.rad(85), math.rad(-10), math.rad(15))
			safeTweenC0(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), thrustC0)
			spawnArcaneBoltEffect(character)
			if trail then
				trail.Enabled = true
				task.delay(0.22, function()
					if trail and trail.Parent then trail.Enabled = false end
				end)
			end
			task.delay(0.18, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
			end)
		else
			spawnArcaneBoltEffect(character)
		end

	-- ── 9. FIREBOLT (Searing flame missile) ──────────────────────────────────
	elseif attackType == "Firebolt" then
		if rightShoulder and defaultRightC0 then
			local castC0 = defaultRightC0 * CFrame.Angles(math.rad(95), math.rad(-15), math.rad(10))
			safeTweenC0(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), castC0)
			spawnFireboltEffect(character)
			if trail then
				trail.Enabled = true
				task.delay(0.22, function()
					if trail and trail.Parent then trail.Enabled = false end
				end)
			end
			task.delay(0.18, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
			end)
		else
			spawnFireboltEffect(character)
		end

	-- ── 10. FIREBALL (Roaring heavy magma orb) ───────────────────────────────
	elseif attackType == "Fireball" then
		if rightShoulder and defaultRightC0 then
			local windupC0 = defaultRightC0 * CFrame.Angles(math.rad(45), math.rad(25), math.rad(-20))
			local launchC0 = defaultRightC0 * CFrame.Angles(math.rad(110), math.rad(-15), math.rad(15))
			safeTweenC0(rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), windupC0)
			task.delay(0.12, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.In), launchC0)
				spawnFireballEffect(character)
				if trail then
					trail.Enabled = true
					task.delay(0.28, function()
						if trail and trail.Parent then trail.Enabled = false end
					end)
				end
				task.delay(0.22, function()
					safeTweenC0(rightShoulder, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
				end)
			end)
		else
			spawnFireballEffect(character)
		end

	-- ── 11. METEOR (Summon blazing asteroid from sky) ────────────────────────
	elseif attackType == "Meteor" then
		if rightShoulder and defaultRightC0 then
			local raiseC0 = defaultRightC0 * CFrame.Angles(math.rad(155), math.rad(-15), math.rad(20))
			safeTweenC0(rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), raiseC0)
			spawnMeteorEffect(character)
			task.delay(0.65, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
			end)
		else
			spawnMeteorEffect(character)
		end

	-- ── 12. FROSTBOLT (Crystalline ice shard) ────────────────────────────────
	elseif attackType == "Frostbolt" then
		if rightShoulder and defaultRightC0 then
			local castC0 = defaultRightC0 * CFrame.Angles(math.rad(85), math.rad(-10), math.rad(12))
			safeTweenC0(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), castC0)
			spawnFrostboltEffect(character)
			if trail then
				trail.Enabled = true
				task.delay(0.22, function()
					if trail and trail.Parent then trail.Enabled = false end
				end)
			end
			task.delay(0.18, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
			end)
		else
			spawnFrostboltEffect(character)
		end

	-- ── 13. ICE LANCE (Glacial piercing spear) ───────────────────────────────
	elseif attackType == "IceLance" then
		if rightShoulder and defaultRightC0 then
			local pullbackC0 = defaultRightC0 * CFrame.Angles(math.rad(30), math.rad(15), math.rad(-15))
			local spearC0 = defaultRightC0 * CFrame.Angles(math.rad(100), math.rad(-10), math.rad(10))
			safeTweenC0(rightShoulder, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), pullbackC0)
			task.delay(0.10, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), spearC0)
				spawnIceLanceEffect(character)
				if trail then
					trail.Enabled = true
					task.delay(0.20, function()
						if trail and trail.Parent then trail.Enabled = false end
					end)
				end
				task.delay(0.20, function()
					safeTweenC0(rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
				end)
			end)
		else
			spawnIceLanceEffect(character)
		end

	-- ── 14. BLIZZARD (Swirling winter vortex) ────────────────────────────────
	elseif attackType == "Blizzard" then
		if rightShoulder and defaultRightC0 then
			local channelC0 = defaultRightC0 * CFrame.Angles(math.rad(150), math.rad(-15), math.rad(25))
			safeTweenC0(rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), channelC0)
			spawnBlizzardEffect(character)
			task.delay(1.2, function()
				safeTweenC0(rightShoulder, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), defaultRightC0)
			end)
		else
			spawnBlizzardEffect(character)
		end
	end
end

function WeaponController.Start()
	-- Listen for weapon attack events from server (broadcasted for other players)
	Net.Get("WeaponAttack").OnClientEvent:Connect(function(userId: number, attackType: string)
		if userId == Players.LocalPlayer.UserId then
			return -- local player already played immediately with 0 latency
		end
		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		if character then
			WeaponController.PlaySwing(character, attackType)
		end
	end)

	-- Visual and auditory reaction on any enemy that gets taunted
	Net.Get("TargetTaunted").OnClientEvent:Connect(function(enemyModel: Model)
		if enemyModel and enemyModel.Parent then
			showTauntedEnemyFeedback(enemyModel)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		if player.Character then
			originalShoulderC0[player.Character] = nil
			originalGripC0[player.Character] = nil
			isAttacking[player.Character] = nil
		end
	end)
end

return WeaponController
