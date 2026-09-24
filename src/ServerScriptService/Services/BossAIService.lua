-- src/ServerScriptService/Services/BossAIService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local BossAttacks = require(ReplicatedStorage.Shared.Data.BossAttacks)
local CombatService = require(script.Parent.CombatService)

local BossAIService = {}

local BOSS_AGGRO_RADIUS = 80
local BOSS_ATTACK_RADIUS = 13.5
local BOSS_PHASE1_SPEED = 11.5
local BOSS_PHASE2_SPEED = 14.5

-- ── WORLD-SPACE VISUAL EFFECTS ────────────────────────────────────────────────
-- All effects are pure BasePart geometry — no external asset IDs required.

-- Returns the actual ground floor Y beneath a position via downward raycast
local function getGroundY(pos: Vector3, fallbackY: number?): number
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true

	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	for _, inst in ipairs(CollectionService:GetTagged("Enemy")) do
		table.insert(ignore, inst)
	end
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and (string.find(m.Name, "Boss") or string.find(m.Name, "Rockhide") or string.find(m.Name, "Solarius") or string.find(m.Name, "TrashMob") or string.find(m.Name, "Minion") or m:FindFirstChildOfClass("Humanoid")) then
			table.insert(ignore, m)
		end
	end
	rayParams.FilterDescendantsInstances = ignore

	local origin = Vector3.new(pos.X, pos.Y + 8, pos.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -60, 0), rayParams)
	if result then
		return result.Position.Y
	end
	return fallbackY or (pos.Y >= 35 and 49.0 or 1.0)
end

-- Calculates the vertical distance from the boss's PrimaryPart down to the lowest point of its feet/legs
local function getFootOffset(model: Model, defaultOffset: number?): number
	local primary = model.PrimaryPart
	if not primary then return defaultOffset or 6 end

	local minY = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local pName = string.lower(part.Name)
			if pName ~= "_bossauralight"
				and not string.find(pName, "sword")
				and not string.find(pName, "blade")
				and not string.find(pName, "halo")
				and not string.find(pName, "wing")
				and not string.find(pName, "effect")
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
		return defaultOffset or 6
	end

	return primary.Position.Y - minY
end

-- Spawns a flat neon ring that expands outward and fades over `duration` seconds
local function spawnShockwaveRing(position: Vector3, startRadius: number, endRadius: number, color: Color3, duration: number, thickness: number)
	local groundY = getGroundY(position) + 0.15
	local ring = Instance.new("Part")
	ring.Name = "BossShockwave"
	ring.Shape = Enum.PartType.Cylinder
	local d = startRadius * 2
	ring.Size = Vector3.new(thickness or 0.25, d, d)
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Position = Vector3.new(position.X, groundY, position.Z)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.55
	ring.Parent = workspace

	local endD = endRadius * 2
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(thickness or 0.25, endD, endD),
		Transparency = 1,
	}):Play()
	task.delay(duration + 0.05, function()
		if ring and ring.Parent then ring:Destroy() end
	end)
	return ring
end

-- Spawns a flat ground scorch/crater disc that fades out
local function spawnGroundScorch(position: Vector3, radius: number, color: Color3, duration: number)
	local groundY = getGroundY(position) + 0.10
	local disc = Instance.new("Part")
	disc.Name = "BossScorch"
	disc.Shape = Enum.PartType.Cylinder
	local d = radius * 2
	disc.Size = Vector3.new(0.15, d, d)
	disc.Orientation = Vector3.new(0, 0, 90)
	disc.Position = Vector3.new(position.X, groundY, position.Z)
	disc.Anchored = true
	disc.CanCollide = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 0.65
	disc.Parent = workspace
	TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()
	task.delay(duration + 0.05, function()
		if disc and disc.Parent then disc:Destroy() end
	end)
	return disc
end

-- Spawns a rising neon pillar of fire/light
local function spawnFirePillar(position: Vector3, height: number, color: Color3, duration: number)
	local groundY = getGroundY(position) + 0.10
	local pillar = Instance.new("Part")
	pillar.Name = "BossFirePillar"
	pillar.Size = Vector3.new(3.5, 0.5, 3.5)
	pillar.Position = Vector3.new(position.X, groundY, position.Z)
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = color
	pillar.Transparency = 0.10
	pillar.Parent = workspace

	local pt = Instance.new("PointLight")
	pt.Color = color
	pt.Brightness = 6
	pt.Range = 28
	pt.Parent = pillar

	-- Rise and fade
	TweenService:Create(pillar, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(3.5, height, 3.5),
		Position = Vector3.new(position.X, groundY + height / 2, position.Z),
		Transparency = 0.4,
	}):Play()
	task.delay(duration * 0.7, function()
		if not (pillar and pillar.Parent) then return end
		TweenService:Create(pillar, TweenInfo.new(duration * 0.3, Enum.EasingStyle.Linear), {
			Transparency = 1,
		}):Play()
		task.delay(duration * 0.3 + 0.05, function()
			if pillar and pillar.Parent then pillar:Destroy() end
		end)
	end)
	return pillar
end

-- Spawns a quick burst orb at a position (charge spark / boulder impact)
local function spawnBurstOrb(position: Vector3, radius: number, color: Color3, duration: number)
	local orb = Instance.new("Part")
	orb.Name = "BossBurstOrb"
	orb.Shape = Enum.PartType.Ball
	local sz = radius * 2
	orb.Size = Vector3.new(sz, sz, sz)
	orb.Position = position
	orb.Anchored = true
	orb.CanCollide = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon
	orb.Color = color
	orb.Transparency = 0.0
	orb.Parent = workspace

	local lt = Instance.new("PointLight")
	lt.Color = color
	lt.Brightness = 5
	lt.Range = 20
	lt.Parent = orb

	TweenService:Create(orb, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(sz * 3, sz * 3, sz * 3),
		Transparency = 1,
	}):Play()
	task.delay(duration + 0.05, function()
		if orb and orb.Parent then orb:Destroy() end
	end)
	return orb
end

-- Spawns a small footstep dust puff at ground level
local function spawnFootstepDust(position: Vector3)
	local groundY = getGroundY(position) + 0.10
	local dust = Instance.new("Part")
	dust.Name = "BossFootDust"
	dust.Shape = Enum.PartType.Cylinder
	dust.Size = Vector3.new(0.2, 2, 2)
	dust.Orientation = Vector3.new(0, 0, 90)
	dust.Position = Vector3.new(position.X, groundY, position.Z)
	dust.Anchored = true
	dust.CanCollide = false
	dust.CastShadow = false
	dust.Material = Enum.Material.SmoothPlastic
	dust.Color = Color3.fromRGB(160, 140, 100)
	dust.Transparency = 0.4
	dust.Parent = workspace
	TweenService:Create(dust, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 8, 8),
		Transparency = 1,
	}):Play()
	task.delay(0.6, function()
		if dust and dust.Parent then dust:Destroy() end
	end)
end

-- ── AUDIO, PHYSICS & WORLD-SPACE COMBAT EFFECTS ──────────────────────────────

-- Plays a 3D positional audio effect safely with volume and pitch adjustments
local function playSound(name: string, soundId: string, parent: Instance, volume: number?, pitch: number?)
	pcall(function()
		local snd = Instance.new("Sound")
		snd.Name = name
		snd.SoundId = soundId
		snd.Volume = volume or 1.0
		snd.PlaybackSpeed = pitch or 1.0
		snd.RollOffMaxDistance = 160
		snd.RollOffMinDistance = 15
		snd.Parent = parent
		snd:Play()
		task.delay(3.5, function()
			if snd and snd.Parent then snd:Destroy() end
		end)
	end)
end

-- Applies directional physical impulse to knock back players hit by heavy attacks
local function applyKnockback(player: Player, fromPos: Vector3, force: number, upward: number?)
	pcall(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local delta = (root.Position - fromPos)
			local horizontal = Vector3.new(delta.X, 0, delta.Z)
			local dir = horizontal.Magnitude > 0.5 and horizontal.Unit or Vector3.new(0, 0, 1)
			root.AssemblyLinearVelocity = dir * force + Vector3.new(0, upward or 18, 0)
		end
	end)
end

-- Spawns a radial ring of jagged earthen rock spikes with custom stone meshes that erupt from the ground
local function spawnRockSpikes(center: Vector3, count: number, radius: number, duration: number, height: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.35
		local r = radius * (0.60 + math.random() * 0.40)
		local spikePos = Vector3.new(center.X + math.cos(angle) * r, 0, center.Z + math.sin(angle) * r)
		local groundY = getGroundY(spikePos)
		local spikeHeight = height * (0.75 + math.random() * 0.50)
		local spikeThickness = math.random(16, 26) / 10

		local spike = Instance.new("Part")
		spike.Name = "BossRockSpike"
		spike.Size = Vector3.new(spikeThickness, spikeHeight, spikeThickness)
		spike.Material = Enum.Material.Rock
		spike.Color = math.random() > 0.35 and Color3.fromRGB(72, 68, 62) or Color3.fromRGB(150, 65, 20)
		spike.Anchored = true
		spike.CanCollide = false
		spike.CastShadow = true

		local sMesh = Instance.new("SpecialMesh")
		sMesh.MeshType = Enum.MeshType.FileMesh
		sMesh.MeshId = "rbxassetid://1290033"
		sMesh.TextureId = "rbxassetid://1290034"
		sMesh.Scale = Vector3.new(spikeThickness * 0.9, spikeHeight * 0.38, spikeThickness * 0.9)
		sMesh.Parent = spike

		local tiltAngleX = math.rad(math.random(-22, 22))
		local tiltAngleZ = math.rad(math.random(-22, 22))
		local baseCF = CFrame.new(spikePos.X, groundY - spikeHeight * 0.6, spikePos.Z) * CFrame.Angles(tiltAngleX, math.rad(math.random(0, 360)), tiltAngleZ)
		spike.CFrame = baseCF
		spike.Parent = workspace

		-- Erupt upward out of the earth
		local targetCF = baseCF + Vector3.new(0, spikeHeight * 0.72, 0)
		TweenService:Create(spike, TweenInfo.new(0.12 + math.random() * 0.05, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = targetCF,
		}):Play()

		task.delay(0.02, function()
			spawnFootstepDust(Vector3.new(spikePos.X, groundY, spikePos.Z))
		end)

		-- Sink back down into the earth and clean up
		task.delay(duration * 0.75, function()
			if not (spike and spike.Parent) then return end
			local sinkTween = TweenService:Create(spike, TweenInfo.new(duration * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = baseCF,
				Transparency = 1,
			})
			sinkTween:Play()
			task.delay(duration * 0.25 + 0.05, function()
				if spike and spike.Parent then spike:Destroy() end
			end)
		end)
	end
end

-- Spawns realistic 3D shattered rock stones with meshes and particle trails that fly away dynamically in ballistic arcs
local function spawnFlyingDebris(origin: Vector3, count: number, maxSpread: number, heightMin: number, heightMax: number)
	local spread = maxSpread or 20
	local hMin = heightMin or 6
	local hMax = heightMax or 14

	for i = 1, count do
		local shard = Instance.new("Part")
		shard.Name = "FlyingStoneShard"
		local shardScale = math.random(10, 24) / 10 -- 1.0 to 2.4 studs
		shard.Size = Vector3.new(shardScale, shardScale, shardScale)
		shard.Material = Enum.Material.Rock
		shard.Color = math.random() > 0.4 and Color3.fromRGB(68, 64, 58) or Color3.fromRGB(150, 68, 22)
		shard.Position = origin + Vector3.new(0, 1.2, 0)
		shard.Anchored = true
		shard.CanCollide = false
		shard.CastShadow = true

		-- Mesh for realistic rock facet structure
		local sMesh = Instance.new("SpecialMesh")
		sMesh.MeshType = Enum.MeshType.FileMesh
		sMesh.MeshId = "rbxassetid://1290033"
		sMesh.TextureId = "rbxassetid://1290034"
		sMesh.Scale = Vector3.new(
			shardScale * (0.8 + math.random() * 0.4),
			shardScale * (0.8 + math.random() * 0.4),
			shardScale * (0.8 + math.random() * 0.4)
		)
		sMesh.Parent = shard
		shard.Parent = workspace

		-- Calculate ballistic dispersion trajectory
		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.5
		local dist = spread * (0.45 + math.random() * 0.55)
		local peakY = math.random(hMin, hMax)
		local endPosRaw = origin + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local endFloor = getGroundY(endPosRaw) + (shardScale * 0.3)
		local finalPos = Vector3.new(endPosRaw.X, endFloor, endPosRaw.Z)

		-- Particle trail on heavier flying rocks
		if shardScale > 1.3 then
			local att = Instance.new("Attachment")
			att.Parent = shard
			local embers = Instance.new("ParticleEmitter")
			embers.Name = "ShardTrail"
			embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			embers.Color = ColorSequence.new(Color3.fromRGB(255, 140, 30))
			embers.Size = NumberSequence.new(0.6, 0.1)
			embers.Lifetime = NumberRange.new(0.18, 0.35)
			embers.Rate = 22
			embers.Speed = NumberRange.new(2, 6)
			embers.LightEmission = 1
			embers.Parent = att
		end

		task.spawn(function()
			local flyDur = 0.40 + math.random() * 0.25
			local flyStart = os.clock()
			local rotSpeed = Vector3.new(math.random(-24, 24), math.random(-24, 24), math.random(-24, 24))
			local curRot = Vector3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360))

			while (os.clock() - flyStart) < flyDur do
				local alpha = math.clamp((os.clock() - flyStart) / flyDur, 0, 1)
				local arcY = 4 * peakY * alpha * (1 - alpha)
				local currentP = (origin + Vector3.new(0, 1.2, 0)):Lerp(finalPos, alpha) + Vector3.new(0, arcY, 0)
				curRot = curRot + rotSpeed * 0.03
				if shard and shard.Parent then
					shard.CFrame = CFrame.new(currentP) * CFrame.Angles(math.rad(curRot.X), math.rad(curRot.Y), math.rad(curRot.Z))
				else
					break
				end
				task.wait(0.02)
			end

			-- Land on ground with impact dust
			if shard and shard.Parent then
				shard.Position = finalPos
				spawnFootstepDust(finalPos)

				task.wait(0.6 + math.random() * 0.5)
				if shard and shard.Parent then
					local fadeTween = TweenService:Create(shard, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Transparency = 1,
						Position = finalPos - Vector3.new(0, 0.8, 0),
					})
					fadeTween:Play()
					task.delay(0.38, function()
						if shard and shard.Parent then shard:Destroy() end
					end)
				end
			end
		end)
	end
end

-- Spawns a glowing neon slash crescent sweeping horizontally in front of the boss
local function spawnCleaveArc(originPos: Vector3, forwardDir: Vector3, radius: number, duration: number)
	local groundY = getGroundY(originPos)
	local dir = (Vector3.new(forwardDir.X, 0, forwardDir.Z)).Magnitude > 0.1 and (Vector3.new(forwardDir.X, 0, forwardDir.Z)).Unit or Vector3.new(0, 0, 1)
	local arcPos = originPos + dir * (radius * 0.45)
	local arcCenter = Vector3.new(arcPos.X, groundY + 3.5, arcPos.Z)

	local blade = Instance.new("Part")
	blade.Name = "BossCleaveBlade"
	blade.Shape = Enum.PartType.Cylinder
	local diameter = radius * 1.8
	blade.Size = Vector3.new(0.35, diameter, diameter)
	blade.CFrame = CFrame.lookAt(arcCenter, arcCenter + dir) * CFrame.Angles(0, 0, math.rad(90))
	blade.Material = Enum.Material.Neon
	blade.Color = Color3.fromRGB(255, 110, 30)
	blade.Transparency = 0.35
	blade.Anchored = true
	blade.CanCollide = false
	blade.CastShadow = false
	blade.Parent = workspace

	local lt = Instance.new("PointLight")
	lt.Color = Color3.fromRGB(255, 120, 30)
	lt.Brightness = 4
	lt.Range = radius * 1.4
	lt.Parent = blade

	TweenService:Create(blade, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.35, diameter * 1.35, diameter * 1.35),
		CFrame = blade.CFrame + dir * 6,
		Transparency = 1,
	}):Play()

	task.delay(duration + 0.05, function()
		if blade and blade.Parent then blade:Destroy() end
	end)
end

-- Spawns a physical 3D rock boulder with high-detail rock mesh and blazing smoke trail that arcs through the air and detonates
local function hurlBoulder(startPos: Vector3, targetPos: Vector3, duration: number, onImpact: () -> ())
	local boulder = Instance.new("Part")
	boulder.Name = "BossBoulder"
	boulder.Size = Vector3.new(4.6, 4.6, 4.6)
	boulder.Material = Enum.Material.Rock
	boulder.Color = Color3.fromRGB(68, 62, 56)
	boulder.Position = startPos
	boulder.Anchored = true
	boulder.CanCollide = false
	boulder.CastShadow = true

	local bMesh = Instance.new("SpecialMesh")
	bMesh.MeshType = Enum.MeshType.FileMesh
	bMesh.MeshId = "rbxassetid://1290033"
	bMesh.TextureId = "rbxassetid://1290034"
	bMesh.Scale = Vector3.new(4.4, 4.4, 4.4)
	bMesh.Parent = boulder
	boulder.Parent = workspace

	-- Fiery incandescent core
	local core = Instance.new("Part")
	core.Name = "BoulderCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(2.8, 2.8, 2.8)
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 90, 20)
	core.Transparency = 0.35
	core.Position = startPos
	core.Anchored = true
	core.CanCollide = false
	core.Parent = boulder

	-- Light source
	local lt = Instance.new("PointLight")
	lt.Color = Color3.fromRGB(255, 110, 30)
	lt.Brightness = 5.5
	lt.Range = 22
	lt.Parent = boulder

	-- Trailing smoke and fire particle emitters
	local att = Instance.new("Attachment")
	att.Name = "BoulderTrailAtt"
	att.Parent = boulder

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "SmokeTrail"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 30)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(180, 70, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 38, 36)),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.8),
		NumberSequenceKeypoint.new(1, 4.5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	smoke.Lifetime = NumberRange.new(0.4, 0.65)
	smoke.Rate = 55
	smoke.Speed = NumberRange.new(2, 6)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Parent = att

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 160, 40))
	embers.Size = NumberSequence.new(0.8, 0.2)
	embers.Lifetime = NumberRange.new(0.3, 0.55)
	embers.Rate = 45
	embers.Speed = NumberRange.new(6, 14)
	embers.LightEmission = 1
	embers.Parent = att

	local startTime = os.clock()
	local apexHeight = math.max(9, (targetPos - startPos).Magnitude * 0.38)
	local curRot = Vector3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360))
	local rotSpeed = Vector3.new(22, 35, 18)

	task.spawn(function()
		while (os.clock() - startTime) < duration do
			local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
			local arcY = 4 * apexHeight * alpha * (1 - alpha)
			local currentPos = startPos:Lerp(targetPos, alpha) + Vector3.new(0, arcY, 0)
			curRot = curRot + rotSpeed * 0.03
			if boulder and boulder.Parent then
				boulder.CFrame = CFrame.new(currentPos) * CFrame.Angles(math.rad(curRot.X), math.rad(curRot.Y), math.rad(curRot.Z))
				core.Position = currentPos
			end
			task.wait(0.02)
		end

		if boulder and boulder.Parent then
			boulder:Destroy()
		end

		-- Detonation: 18-22 meshed rock shards violently blasted outward
		spawnFlyingDebris(targetPos, math.random(18, 22), 26, 8, 16)

		onImpact()
	end)
end

-- ── PROCEDURAL JOINT & BODY POSE ANIMATORS ───────────────────────────────────

local function poseJoint(joint: Motor6D?, origC0: CFrame?, offset: CFrame, dur: number)
	if joint and origC0 then
		TweenService:Create(joint, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			C0 = origC0 * offset,
		}):Play()
	end
end

local function poseArms(joints, leftRot: CFrame, rightRot: CFrame, dur: number)
	poseJoint(joints.leftShoulder, joints.origLeftShoulderC0, leftRot, dur)
	poseJoint(joints.rightShoulder, joints.origRightShoulderC0, rightRot, dur)
end

local function poseLegs(joints, leftRot: CFrame, rightRot: CFrame, dur: number)
	poseJoint(joints.leftHip, joints.origLeftHipC0, leftRot, dur)
	poseJoint(joints.rightHip, joints.origRightHipC0, rightRot, dur)
end

local function poseNeck(joints, rot: CFrame, dur: number)
	poseJoint(joints.neck, joints.origNeckC0, rot, dur)
end

local function poseTorso(joints, rot: CFrame, dur: number)
	if joints.rootJoint and joints.origRootJointC0 then
		poseJoint(joints.rootJoint, joints.origRootJointC0, rot, dur)
	end
end

local function resetAllJoints(joints, dur: number)
	poseArms(joints, CFrame.new(), CFrame.new(), dur)
	poseLegs(joints, CFrame.new(), CFrame.new(), dur)
	poseNeck(joints, CFrame.new(), dur)
	poseTorso(joints, CFrame.new(), dur)
end

-- Attaches a temporary coloured PointLight to the boss torso (auto-removes after duration)
local function attachBossLight(torso: BasePart, color: Color3, brightness: number, range: number, duration: number): PointLight
	local existing = torso:FindFirstChild("_BossAuraLight")
	if existing then existing:Destroy() end
	local lt = Instance.new("PointLight")
	lt.Name = "_BossAuraLight"
	lt.Color = color
	lt.Brightness = brightness
	lt.Range = range
	lt.Parent = torso
	if duration > 0 then
		task.delay(duration, function()
			if lt and lt.Parent then lt:Destroy() end
		end)
	end
	return lt
end

-- Returns the phase whose hpThreshold applies at the given health, plus its 1-based index
-- in bossData.phases (used to populate BossStateChanged's documented phaseIndex argument).
local function pickPhase(bossData, currentHealth: number, maxHealth: number)
	local hpPercent = currentHealth / maxHealth
	local chosen = bossData.phases[1]
	local chosenIndex = 1
	for index, phase in bossData.phases do
		if hpPercent <= phase.hpThreshold then
			chosen = phase
			chosenIndex = index
		end
	end
	return chosen, chosenIndex
end

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
-- Uses the true joint socket pivot (top of limb) so rotating C0 pivots naturally without detaching
local function getOrCreateMotor6D(limb: BasePart?, parentPart: BasePart, jointName: string, isArm: boolean?): Motor6D?
	if not limb or limb == parentPart then
		return nil
	end

	-- Check if existing joint connects parentPart and limb
	for _, desc in limb.Parent:GetDescendants() do
		if desc:IsA("Motor6D") and ((desc.Part0 == parentPart and desc.Part1 == limb) or (desc.Part0 == limb and desc.Part1 == parentPart)) then
			if desc.Part0 ~= parentPart then
				desc.Part0 = parentPart
				desc.Part1 = limb
			end
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

	-- Calculate the true socket pivot:
	-- For an arm, the shoulder socket is at the TOP of the arm (facing torso).
	-- Using this socket pivot guarantees the arm rotates around the shoulder without translating away!
	local limbRelToTorso = parentPart.CFrame:PointToObjectSpace(limb.Position)
	local topY = limb.Size.Y * 0.42
	local inwardX = (limbRelToTorso.X < 0) and (limb.Size.X * 0.25) or (-limb.Size.X * 0.25)
	local pivotOffsetInLimb = isArm and Vector3.new(inwardX, topY, 0) or Vector3.new(0, topY, 0)
	local pivotWorldCFrame = limb.CFrame * CFrame.new(pivotOffsetInLimb)

	motor.C0 = parentPart.CFrame:ToObjectSpace(pivotWorldCFrame)
	motor.C1 = CFrame.new(pivotOffsetInLimb)
	motor.Parent = parentPart
	return motor
end

-- Auto-rigs and locks model integrity:
-- 1. Classifies limbs (arms, legs, head, torso) geometrically and by keywords
-- 2. Connects limbs via Motor6D joints with true shoulder/hip pivot sockets
-- 3. Welds limb-specific subparts (forearm, hand, claws, armor) to their parent limb, NOT torso
-- 4. Disables Humanoid death/ragdoll logic so the head never disappears
local function ensureModelIntegrityAndRig(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		primary = model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("Torso")
			or model:FindFirstChild("UpperTorso")
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
	humanoid.Health = 10000000
	humanoid.MaxHealth = 10000000
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

	-- Classify limbs
	local leftArm = findLimbPart(model, {"leftarm", "larm", "leftupperarm", "leftforearm", "leftcrystal", "lefthand", "leftwrist"})
	local rightArm = findLimbPart(model, {"rightarm", "rarm", "rightupperarm", "rightforearm", "rightcrystal", "righthand", "rightwrist"})
	local leftLeg = findLimbPart(model, {"leftleg", "lleg", "leftupperleg", "leftthigh", "leftfoot", "leftshin"})
	local rightLeg = findLimbPart(model, {"rightleg", "rleg", "rightupperleg", "rightthigh", "rightfoot", "rightshin"})
	local head = findLimbPart(model, {"head", "skull", "face", "horn", "horns"})

	-- Geometric classification fallback
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

	-- Connect limbs with Motor6D joints using true socket pivots
	local leftShoulder = getOrCreateMotor6D(leftArm, torso, "LeftShoulder", true)
	local rightShoulder = getOrCreateMotor6D(rightArm, torso, "RightShoulder", true)
	local leftHip = getOrCreateMotor6D(leftLeg, torso, "LeftHip", false)
	local rightHip = getOrCreateMotor6D(rightLeg, torso, "RightHip", false)
	local neck = getOrCreateMotor6D(head, torso, "Neck", false)

	local rootJoint: Motor6D? = nil
	if primary ~= torso then
		rootJoint = getOrCreateMotor6D(torso, primary, "RootJoint", false)
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

	-- Unanchor all animated limbs and weld sub-parts to their proper parent limb
	-- (so forearms/hands/crystals move with the arm rather than being pinned to the torso)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= primary then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true

			if not jointed[part] then
				local targetLimb = torso
				local pName = string.lower(part.Name)
				local relPos = torso.CFrame:PointToObjectSpace(part.Position)

				local isLeftName = string.find(pName, "left") or string.find(pName, "l_") or string.sub(pName, 1, 1) == "l"
				local isRightName = string.find(pName, "right") or string.find(pName, "r_") or string.sub(pName, 1, 1) == "r"
				local isArmName = string.find(pName, "arm") or string.find(pName, "hand") or string.find(pName, "wrist") or string.find(pName, "claw") or string.find(pName, "crystal") or string.find(pName, "shoulder") or string.find(pName, "finger") or string.find(pName, "forearm") or string.find(pName, "bicep")
				local isLegName = string.find(pName, "leg") or string.find(pName, "foot") or string.find(pName, "thigh") or string.find(pName, "shin") or string.find(pName, "knee") or string.find(pName, "calf") or string.find(pName, "toe")
				local isHeadName = string.find(pName, "head") or string.find(pName, "skull") or string.find(pName, "horn") or string.find(pName, "face") or string.find(pName, "jaw") or string.find(pName, "eye") or string.find(pName, "teeth") or string.find(pName, "ear")

				if leftArm and (isLeftName and isArmName or (relPos.X < -0.6 and relPos.Y > -1.5 and not isLegName)) then
					targetLimb = leftArm
				elseif rightArm and (isRightName and isArmName or (relPos.X > 0.6 and relPos.Y > -1.5 and not isLegName)) then
					targetLimb = rightArm
				elseif leftLeg and (isLeftName and isLegName or (relPos.X < -0.2 and relPos.Y <= -1.5)) then
					targetLimb = leftLeg
				elseif rightLeg and (isRightName and isLegName or (relPos.X > 0.2 and relPos.Y <= -1.5)) then
					targetLimb = rightLeg
				elseif head and (isHeadName or relPos.Y > (torso.Size.Y * 0.40)) then
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

	primary.Anchored = true
	primary.CanCollide = true

	local joints = {
		torso = torso,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		leftHip = leftHip,
		rightHip = rightHip,
		neck = neck,
		rootJoint = rootJoint,
		origLeftShoulderC0 = leftShoulder and leftShoulder.C0,
		origRightShoulderC0 = rightShoulder and rightShoulder.C0,
		origLeftHipC0 = leftHip and leftHip.C0,
		origRightHipC0 = rightHip and rightHip.C0,
		origNeckC0 = neck and neck.C0,
		origRootJointC0 = rootJoint and rootJoint.C0,
	}

	return primary, joints
end

-- Sets up walking and attack animations if authored, falling back to standard IDs
local function setupBossAnimations(model: Model): (AnimationTrack?, AnimationTrack?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local walkAnim: Animation? = nil
	local attackAnim: Animation? = nil

	for _, desc in model:GetDescendants() do
		if desc:IsA("Animation") then
			local lower = string.lower(desc.Name)
			if string.find(lower, "walk") or string.find(lower, "run") or string.find(lower, "move") then
				walkAnim = desc
			elseif string.find(lower, "attack") or string.find(lower, "slam") or string.find(lower, "slash") or string.find(lower, "pound") then
				attackAnim = desc
			end
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		for _, desc in assets:GetDescendants() do
			if desc:IsA("Animation") then
				local lower = string.lower(desc.Name)
				if not walkAnim and (string.find(lower, "bosswalk") or string.find(lower, "walk")) then
					walkAnim = desc
				elseif not attackAnim and (string.find(lower, "bossattack") or string.find(lower, "slam")) then
					attackAnim = desc
				end
			end
		end
	end

	local isR15 = model:FindFirstChild("UpperTorso") ~= nil
		or model:FindFirstChild("LeftUpperArm") ~= nil
		or (humanoid.RigType == Enum.HumanoidRigType.R15)

	local defaultWalkId = isR15 and "rbxassetid://507777826" or "rbxassetid://180426353"

	if not walkAnim then
		walkAnim = Instance.new("Animation")
		walkAnim.Name = "BossWalkAnim"
		walkAnim.AnimationId = defaultWalkId
	end

	local walkTrack: AnimationTrack? = nil
	local attackTrack: AnimationTrack? = nil

	pcall(function()
		if walkAnim then
			walkTrack = animator:LoadAnimation(walkAnim)
			if walkTrack then
				walkTrack.Priority = Enum.AnimationPriority.Movement
				walkTrack.Looped = true
			end
		end
		if attackAnim then
			attackTrack = animator:LoadAnimation(attackAnim)
			if attackTrack then
				attackTrack.Priority = Enum.AnimationPriority.Action4
				attackTrack.Looped = false
			end
		end
	end)

	return walkTrack, attackTrack
end

-- Boss art assets live under ReplicatedStorage.Assets
local function createBossModel(bossId: string, spawnCFrame: CFrame): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild(bossId .. "BossTemplate")

	local model: Model
	if template then
		model = template:Clone()
		model.Name = bossId
	elseif bossId == "Solarius" then
		-- ── SOLARIUS, THE SUNFORGED COLOSSUS (Tier 2 Boss Model) ────────────
		model = Instance.new("Model")
		model.Name = "Solarius"

		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(7, 11, 5)
		torso.Color = Color3.fromRGB(215, 175, 55)
		torso.Material = Enum.Material.Metal
		torso.Parent = model
		model.PrimaryPart = torso

		-- Solar Chestplate Inlay & Core
		local chestSun = Instance.new("Part")
		chestSun.Name = "ChestSun"
		chestSun.Size = Vector3.new(4.5, 4.5, 1)
		chestSun.CFrame = torso.CFrame * CFrame.new(0, 1.5, -2.6)
		chestSun.Color = Color3.fromRGB(255, 140, 30)
		chestSun.Material = Enum.Material.Neon
		chestSun.Parent = model
		local wChest = Instance.new("WeldConstraint")
		wChest.Part0 = torso
		wChest.Part1 = chestSun
		wChest.Parent = torso

		local coreEmbers = Instance.new("ParticleEmitter")
		coreEmbers.Name = "CoreEmbers"
		coreEmbers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		coreEmbers.Rate = 12
		coreEmbers.Speed = NumberRange.new(2, 4)
		coreEmbers.Lifetime = NumberRange.new(0.6, 1.2)
		coreEmbers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		coreEmbers.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 100, 20))
		coreEmbers.LightEmission = 0.9
		coreEmbers.Parent = chestSun

		-- Radiant Head with Solar Halo & Crown
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(4, 4.5, 4)
		head.CFrame = torso.CFrame * CFrame.new(0, 7.8, 0)
		head.Color = Color3.fromRGB(235, 195, 75)
		head.Material = Enum.Material.Metal
		head.Parent = model

		local visor = Instance.new("Part")
		visor.Name = "Visor"
		visor.Size = Vector3.new(3.2, 0.6, 0.8)
		visor.CFrame = head.CFrame * CFrame.new(0, 0.2, -2.1)
		visor.Color = Color3.fromRGB(60, 220, 255)
		visor.Material = Enum.Material.Neon
		visor.Parent = model
		local wVisor = Instance.new("WeldConstraint")
		wVisor.Part0 = head
		wVisor.Part1 = visor
		wVisor.Parent = head

		local halo = Instance.new("Part")
		halo.Name = "SolarHalo"
		halo.Size = Vector3.new(8.5, 8.5, 0.5)
		halo.CFrame = head.CFrame * CFrame.new(0, 1.5, 1.6)
		halo.Color = Color3.fromRGB(255, 175, 40)
		halo.Material = Enum.Material.Neon
		halo.Parent = model
		local wHalo = Instance.new("WeldConstraint")
		wHalo.Part0 = head
		wHalo.Part1 = halo
		wHalo.Parent = head

		-- Radiant Wings of Light on Upper Back
		local wingTL = Instance.new("Part")
		wingTL.Name = "SolarWing_TL"
		wingTL.Size = Vector3.new(0.6, 13, 2.4)
		wingTL.CFrame = torso.CFrame * CFrame.new(-3.6, 5.5, 2.4) * CFrame.Angles(math.rad(15), math.rad(-20), math.rad(-35))
		wingTL.Color = Color3.fromRGB(255, 215, 60)
		wingTL.Material = Enum.Material.Neon
		wingTL.Parent = model
		local wWingTL = Instance.new("WeldConstraint")
		wWingTL.Part0 = torso
		wWingTL.Part1 = wingTL
		wWingTL.Parent = torso

		local wingTR = Instance.new("Part")
		wingTR.Name = "SolarWing_TR"
		wingTR.Size = Vector3.new(0.6, 13, 2.4)
		wingTR.CFrame = torso.CFrame * CFrame.new(3.6, 5.5, 2.4) * CFrame.Angles(math.rad(15), math.rad(20), math.rad(35))
		wingTR.Color = Color3.fromRGB(255, 215, 60)
		wingTR.Material = Enum.Material.Neon
		wingTR.Parent = model
		local wWingTR = Instance.new("WeldConstraint")
		wWingTR.Part0 = torso
		wWingTR.Part1 = wingTR
		wWingTR.Parent = torso

		local wingBL = Instance.new("Part")
		wingBL.Name = "SolarWing_BL"
		wingBL.Size = Vector3.new(0.5, 9, 2.0)
		wingBL.CFrame = torso.CFrame * CFrame.new(-3.0, 1.8, 2.2) * CFrame.Angles(math.rad(10), math.rad(-15), math.rad(-60))
		wingBL.Color = Color3.fromRGB(255, 175, 40)
		wingBL.Material = Enum.Material.Neon
		wingBL.Parent = model
		local wWingBL = Instance.new("WeldConstraint")
		wWingBL.Part0 = torso
		wWingBL.Part1 = wingBL
		wWingBL.Parent = torso

		local wingBR = Instance.new("Part")
		wingBR.Name = "SolarWing_BR"
		wingBR.Size = Vector3.new(0.5, 9, 2.0)
		wingBR.CFrame = torso.CFrame * CFrame.new(3.0, 1.8, 2.2) * CFrame.Angles(math.rad(10), math.rad(15), math.rad(60))
		wingBR.Color = Color3.fromRGB(255, 175, 40)
		wingBR.Material = Enum.Material.Neon
		wingBR.Parent = model
		local wWingBR = Instance.new("WeldConstraint")
		wWingBR.Part0 = torso
		wWingBR.Part1 = wingBR
		wWingBR.Parent = torso

		-- Massive Pauldron Limbs & Arms
		local lArm = Instance.new("Part")
		lArm.Name = "LeftUpperArm"
		lArm.Size = Vector3.new(3.5, 10, 3.5)
		lArm.CFrame = torso.CFrame * CFrame.new(-5.5, 0, 0)
		lArm.Color = Color3.fromRGB(180, 140, 40)
		lArm.Material = Enum.Material.Metal
		lArm.Parent = model

		local rArm = Instance.new("Part")
		rArm.Name = "RightUpperArm"
		rArm.Size = Vector3.new(3.5, 10, 3.5)
		rArm.CFrame = torso.CFrame * CFrame.new(5.5, 0, 0)
		rArm.Color = Color3.fromRGB(180, 140, 40)
		rArm.Material = Enum.Material.Metal
		rArm.Parent = model

		-- Dawnbreaker Sunforged Greatsword in Right Arm
		local sword = Instance.new("Part")
		sword.Name = "SunforgedGreatsword"
		sword.Size = Vector3.new(1.8, 17, 0.9)
		sword.CFrame = rArm.CFrame * CFrame.new(0, -6, -2) * CFrame.Angles(math.rad(45), 0, 0)
		sword.Color = Color3.fromRGB(255, 215, 75)
		sword.Material = Enum.Material.Neon
		sword.Parent = model
		local wSword = Instance.new("WeldConstraint")
		wSword.Part0 = rArm
		wSword.Part1 = sword
		wSword.Parent = rArm

		local swordEmbers = Instance.new("ParticleEmitter")
		swordEmbers.Name = "SwordEmbers"
		swordEmbers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		swordEmbers.Rate = 16
		swordEmbers.Speed = NumberRange.new(2, 4)
		swordEmbers.Lifetime = NumberRange.new(0.6, 1.2)
		swordEmbers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		swordEmbers.Color = ColorSequence.new(Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 130, 25))
		swordEmbers.LightEmission = 0.9
		swordEmbers.Parent = sword

		-- Heavy Armored Legs
		local lLeg = Instance.new("Part")
		lLeg.Name = "LeftUpperLeg"
		lLeg.Size = Vector3.new(3.2, 9, 3.2)
		lLeg.CFrame = torso.CFrame * CFrame.new(-2, -9.5, 0)
		lLeg.Color = Color3.fromRGB(160, 120, 35)
		lLeg.Material = Enum.Material.Metal
		lLeg.Parent = model

		local rLeg = Instance.new("Part")
		rLeg.Name = "RightUpperLeg"
		rLeg.Size = Vector3.new(3.2, 9, 3.2)
		rLeg.CFrame = torso.CFrame * CFrame.new(2, -9.5, 0)
		rLeg.Color = Color3.fromRGB(160, 120, 35)
		rLeg.Material = Enum.Material.Metal
		rLeg.Parent = model
	else
		-- Rockhide, Earthbreaker Colossus (procedural earth golem model if template is missing)
		model = Instance.new("Model")
		model.Name = bossId

		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(8, 10, 6)
		torso.Color = Color3.fromRGB(90, 85, 80)
		torso.Material = Enum.Material.Slate
		torso.Parent = model
		model.PrimaryPart = torso

		-- Glowing Earth Crystal Core in chest
		local core = Instance.new("Part")
		core.Name = "EarthCore"
		core.Size = Vector3.new(4, 4, 1.2)
		core.CFrame = torso.CFrame * CFrame.new(0, 1.2, -3.1)
		core.Color = Color3.fromRGB(130, 220, 70)
		core.Material = Enum.Material.Neon
		core.Parent = model
		local wCore = Instance.new("WeldConstraint")
		wCore.Part0 = torso
		wCore.Part1 = core
		wCore.Parent = torso

		-- Rugged Stone Head with Horns
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(4.5, 4, 4.2)
		head.CFrame = torso.CFrame * CFrame.new(0, 6.8, 0)
		head.Color = Color3.fromRGB(105, 100, 95)
		head.Material = Enum.Material.Slate
		head.Parent = model

		local hornL = Instance.new("Part")
		hornL.Name = "HornL"
		hornL.Size = Vector3.new(1.2, 3.5, 1.2)
		hornL.CFrame = head.CFrame * CFrame.new(-2.2, 2.2, -0.5) * CFrame.Angles(0, 0, math.rad(30))
		hornL.Color = Color3.fromRGB(70, 65, 60)
		hornL.Material = Enum.Material.Rock
		hornL.Parent = model
		local wHornL = Instance.new("WeldConstraint")
		wHornL.Part0 = head
		wHornL.Part1 = hornL
		wHornL.Parent = head

		local hornR = Instance.new("Part")
		hornR.Name = "HornR"
		hornR.Size = Vector3.new(1.2, 3.5, 1.2)
		hornR.CFrame = head.CFrame * CFrame.new(2.2, 2.2, -0.5) * CFrame.Angles(0, 0, math.rad(-30))
		hornR.Color = Color3.fromRGB(70, 65, 60)
		hornR.Material = Enum.Material.Rock
		hornR.Parent = model
		local wHornR = Instance.new("WeldConstraint")
		wHornR.Part0 = head
		wHornR.Part1 = hornR
		wHornR.Parent = head

		-- Massive Stone Fist Arms
		local lArm = Instance.new("Part")
		lArm.Name = "LeftUpperArm"
		lArm.Size = Vector3.new(3.6, 9.5, 3.6)
		lArm.CFrame = torso.CFrame * CFrame.new(-5.8, 0, 0)
		lArm.Color = Color3.fromRGB(85, 80, 75)
		lArm.Material = Enum.Material.Slate
		lArm.Parent = model

		local rArm = Instance.new("Part")
		rArm.Name = "RightUpperArm"
		rArm.Size = Vector3.new(3.6, 9.5, 3.6)
		rArm.CFrame = torso.CFrame * CFrame.new(5.8, 0, 0)
		rArm.Color = Color3.fromRGB(85, 80, 75)
		rArm.Material = Enum.Material.Slate
		rArm.Parent = model

		-- Heavy Pillar Legs
		local lLeg = Instance.new("Part")
		lLeg.Name = "LeftUpperLeg"
		lLeg.Size = Vector3.new(3.4, 8.5, 3.4)
		lLeg.CFrame = torso.CFrame * CFrame.new(-2.2, -8.5, 0)
		lLeg.Color = Color3.fromRGB(80, 75, 70)
		lLeg.Material = Enum.Material.Slate
		lLeg.Parent = model

		local rLeg = Instance.new("Part")
		rLeg.Name = "RightUpperLeg"
		rLeg.Size = Vector3.new(3.4, 8.5, 3.4)
		rLeg.CFrame = torso.CFrame * CFrame.new(2.2, -8.5, 0)
		rLeg.Color = Color3.fromRGB(80, 75, 70)
		rLeg.Material = Enum.Material.Slate
		rLeg.Parent = model
	end

	model:PivotTo(spawnCFrame)
	CollectionService:AddTag(model, "Enemy")
	model.Parent = workspace

	return model
end

function BossAIService.SpawnBoss(bossId: string, spawnCFrame: CFrame, onDeath: (() -> ())?, onAggro: (() -> ())?)
	local bossData = require(ReplicatedStorage.Shared.Data.Bosses[bossId])

	local model = createBossModel(bossId, spawnCFrame)
	local primary, joints = ensureModelIntegrityAndRig(model)
	local walkTrack, attackTrack = setupBossAnimations(model)

	-- Calculate dynamic vertical distance from PrimaryPart to bottom of feet
	local footOffset = getFootOffset(model)
	local spawnFloorY = getGroundY(spawnCFrame.Position, (spawnCFrame.Y >= 35 and 49.0 or 1.0))
	local adjustedSpawnPos = Vector3.new(spawnCFrame.X, spawnFloorY + footOffset + 0.05, spawnCFrame.Z)
	local adjustedCFrame = CFrame.new(adjustedSpawnPos) * spawnCFrame.Rotation
	model:PivotTo(adjustedCFrame)
	if primary then
		primary.CFrame = adjustedCFrame
	end

	local currentHealth = bossData.maxHealth
	local alive = true
	local inCombat = false
	local targetPlayer: Player? = nil
	local aggroTriggered = false
	local firedPhaseTransitions = {}

	-- Cache all colorable parts once for O(1) flash hit (avoids GetDescendants every attack)
	local _flashParts = {}
	local _flashHitCount = 0
	local function refreshFlashParts()
		_flashParts = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Material ~= Enum.Material.Neon then
				_flashParts[#_flashParts + 1] = { part = part, orig = part.Color }
			end
		end
	end
	refreshFlashParts()

	local function flashHit()
		_flashHitCount += 1
		-- Only flash every 2nd hit to reduce per-frame cost
		if _flashHitCount % 2 ~= 1 then return end
		for _, entry in _flashParts do
			local part = entry.part
			if part and part.Parent then
				part.Color = Color3.fromRGB(255, 80, 70)
				task.delay(0.10, function()
					if part and part.Parent then
						part.Color = entry.orig
					end
				end)
			end
		end
	end

	local function triggerAggro(player: Player?)
		if inCombat and aggroTriggered then
			return
		end
		inCombat = true
		aggroTriggered = true
		if player then
			targetPlayer = player
		end
		if onAggro then
			onAggro()
		end

		local _, phaseIndex = pickPhase(bossData, currentHealth, bossData.maxHealth)
		Net.Get("BossStateChanged"):FireAllClients(bossId, phaseIndex, currentHealth, bossData.maxHealth)
	end

	local handle = {
		model = model,
		currentHealth = currentHealth,
		maxHealth = bossData.maxHealth,
	}

	function handle.onDamaged(amount: number, attackingPlayer: Player?)
		if not alive then
			return
		end
		currentHealth = math.max(0, currentHealth - amount)
		handle.currentHealth = currentHealth
		flashHit()

		triggerAggro(attackingPlayer)

		local _, phaseIndex = pickPhase(bossData, currentHealth, bossData.maxHealth)
		Net.Get("BossStateChanged"):FireAllClients(bossId, phaseIndex, currentHealth, bossData.maxHealth)

		if currentHealth <= 0 then
			alive = false
			Net.Get("BossStateChanged"):FireAllClients(bossId, 0, 0, bossData.maxHealth)
		end
	end

	function handle.onTaunted(player: Player)
		if alive then
			targetPlayer = player
			triggerAggro(player)
		end
	end

	CombatService.RegisterEnemy(bossId, handle)

	-- ── PROCEDURAL GAIT ANIMATOR ──────────────────────────────────────────
	local isWalking = false
	local isAttacking = false
	local walkCycle = 0
	local lastFootDustTime = 0

	-- Persistent ambient aura light on the boss torso
	local auraLight = attachBossLight(joints.torso or primary, Color3.fromRGB(200, 60, 20), 2.5, 22, -1)

	task.spawn(function()
		while alive and model.Parent do
			task.wait(0.033)
			if not alive or not model.Parent then
				break
			end

			if isWalking and not isAttacking then
				walkCycle = (walkCycle + 0.30) % (2 * math.pi)
				local legAngle = math.sin(walkCycle) * math.rad(32)
				local armAngle = -legAngle * 0.75

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

				-- Footstep dust: spawn a puff at each foot-strike (when legAngle crosses zero)
				local now = os.clock()
				if math.abs(math.sin(walkCycle)) < 0.12 and (now - lastFootDustTime) > 0.38 and primary then
					lastFootDustTime = now
					local footPos = primary.Position - Vector3.new(0, footOffset, 0)
					spawnFootstepDust(footPos)
					-- Pulse aura light briefly brighter on each footstep
					if auraLight and auraLight.Parent then
						auraLight.Brightness = 6
						task.delay(0.15, function()
							if auraLight and auraLight.Parent then
								auraLight.Brightness = 2.5
							end
						end)
					end
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
				if joints.neck and joints.origNeckC0 and joints.neck.C0 ~= joints.origNeckC0 then
					joints.neck.C0 = joints.origNeckC0
				end
				if joints.rootJoint and joints.origRootJointC0 and joints.rootJoint.C0 ~= joints.origRootJointC0 then
					joints.rootJoint.C0 = joints.origRootJointC0
				end
			end
		end
	end)

	-- ── 60 FPS COMBAT & PURSUIT AI LOOP ────────────────────────────────────
	task.spawn(function()
		local currentTween: Tween? = nil
		local lastAttackTime = os.clock()

		while alive do
			task.wait(0.20)
			if not alive or not model.Parent or not model.PrimaryPart then
				break
			end

			local phase, phaseIndex = pickPhase(bossData, currentHealth, bossData.maxHealth)
			local moveSpeed = (phaseIndex > 1) and BOSS_PHASE2_SPEED or BOSS_PHASE1_SPEED

			-- Phase transition: dramatic visual + world effects + screen shake
			if not firedPhaseTransitions[phase.hpThreshold] and phase.hpThreshold < 1.0 then
				firedPhaseTransitions[phase.hpThreshold] = true
				local transition
				for _, t in bossData.phaseTransition do
					if t.hpThreshold == phase.hpThreshold then
						transition = t
						break
					end
				end
				if transition then
					isWalking = false
					if walkTrack and walkTrack.IsPlaying then
						walkTrack:Stop(0.2)
					end
					if currentTween then
						currentTween:Cancel()
					end

					local tPos = model.PrimaryPart.Position
					local floorY = tPos.Y - model.PrimaryPart.Size.Y / 2

					-- Phase 3 enrage gets deeper crimson, Phase 2 gets orange
					local isEnragePhase = phase.hpThreshold <= 0.25
					local pillarColor = isEnragePhase
						and Color3.fromRGB(255, 30, 10)
						or Color3.fromRGB(255, 140, 20)
					local ringColor = isEnragePhase
						and Color3.fromRGB(255, 60, 20)
						or Color3.fromRGB(255, 180, 40)

					-- Flash boss body
					for _, entry in _flashParts do
						if entry.part and entry.part.Parent then
							entry.part.Color = pillarColor
						end
					end

					-- Upgrade aura light color for new phase
					if auraLight and auraLight.Parent then
						auraLight.Color = pillarColor
						auraLight.Brightness = 10
						auraLight.Range = 40
					end

					-- Fire pillar ring: 6 pillars radiating outward
					local pillarHeight = isEnragePhase and 28 or 20
					for i = 1, 6 do
						local angle = (i / 6) * 2 * math.pi
						local offset = Vector3.new(math.cos(angle) * 7, 0, math.sin(angle) * 7)
						task.delay((i - 1) * 0.07, function()
							if alive then
								spawnFirePillar(
									Vector3.new(tPos.X + offset.X, floorY, tPos.Z + offset.Z),
									pillarHeight, pillarColor,
									transition.duration * 0.9
								)
							end
						end)
					end

					-- Central burst orb
					spawnBurstOrb(
						Vector3.new(tPos.X, tPos.Y, tPos.Z),
						isEnragePhase and 6 or 4, pillarColor, 0.6
					)

					-- Expanding shockwave ring at ground level
					task.delay(0.25, function()
						if alive then
							spawnShockwaveRing(
								Vector3.new(tPos.X, floorY + 0.15, tPos.Z),
								4, isEnragePhase and 42 or 32,
								ringColor, transition.duration * 0.8, 0.5
							)
							-- Second inner ring slightly delayed
							task.delay(0.15, function()
								if alive then
									spawnShockwaveRing(
										Vector3.new(tPos.X, floorY + 0.35, tPos.Z),
										2, isEnragePhase and 22 or 16,
										pillarColor, transition.duration * 0.6, 0.3
									)
								end
							end)
						end
					end)

					-- Screen shake + flash signal to all clients
					Net.Get("BossEffect"):FireAllClients(
						isEnragePhase and "enrageShake" or "phaseShake",
						tPos,
						{ intensity = isEnragePhase and 1.0 or 0.6, duration = 0.8 }
					)

					task.wait(transition.duration)

					-- Restore boss colors after roar
					for _, entry in _flashParts do
						if entry.part and entry.part.Parent then
							entry.part.Color = entry.orig
						end
					end
					-- Settle aura to new phase brightness
					if auraLight and auraLight.Parent then
						auraLight.Brightness = isEnragePhase and 5 or 3.5
						auraLight.Range = isEnragePhase and 30 or 25
					end

					if not alive then
						break
					end
				end
			end

			-- 1. Aggro check: detect any player entering the arena
			local myPos = model.PrimaryPart.Position
			if not inCombat then
				for _, player in ipairs(Players:GetPlayers()) do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if root and hum and hum.Health > 0 then
						-- Only aggro if player has actually entered the boss arena chamber (Z >= -22)
						if root.Position.Z >= -22 and (root.Position - myPos).Magnitude <= BOSS_AGGRO_RADIUS then
							triggerAggro(player)
							break
						end
					end
				end
			end

			-- 2. Target validation
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
				-- Find next closest living player
				local closestPlayer: Player? = nil
				local closestDist = math.huge
				for _, player in ipairs(Players:GetPlayers()) do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if root and hum and hum.Health > 0 then
						local d = (root.Position - myPos).Magnitude
						if d < closestDist then
							closestDist = d
							closestPlayer = player
						end
					end
				end

				if closestPlayer then
					targetPlayer = closestPlayer
					targetRoot = closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
				else
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
			end

			if not targetRoot then
				continue
			end

			local targetPos = targetRoot.Position
			local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
			local dist = (flatTarget - myPos).Magnitude

			-- 3. Boss Movement & Pursuit towards player
			if not isAttacking then
				if dist > BOSS_ATTACK_RADIUS then
					if not isWalking then
						isWalking = true
						if walkTrack and not walkTrack.IsPlaying then
							walkTrack:Play(0.2)
						end
					end

					local step = math.min(moveSpeed * 0.22, dist - BOSS_ATTACK_RADIUS + 0.8)
					local dir = (flatTarget - myPos).Unit
					local rawNextPos = myPos + dir * step

					-- Keep boss strictly inside colosseum arena boundaries and resting flush on the floor
					local targetFloorY = getGroundY(rawNextPos, (rawNextPos.Y >= 35 and 49.0 or 1.0))
					local nextPos = Vector3.new(
						math.clamp(rawNextPos.X, -50, 50),
						targetFloorY + footOffset + 0.05,
						math.clamp(rawNextPos.Z, -20, 95)
					)

					local targetLookAt = Vector3.new(flatTarget.X, targetFloorY + footOffset + 0.05, flatTarget.Z)
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
					-- Within attack range: stop walking, face player
					if isWalking then
						isWalking = false
						if walkTrack and walkTrack.IsPlaying then
							walkTrack:Stop(0.2)
						end
					end
					if currentTween then
						currentTween:Cancel()
					end
					local currentFloorY = getGroundY(myPos, (myPos.Y >= 35 and 49.0 or 1.0))
					local standingY = currentFloorY + footOffset + 0.05
					local lookTarget = Vector3.new(flatTarget.X, standingY, flatTarget.Z)
					model.PrimaryPart.CFrame = CFrame.lookAt(Vector3.new(myPos.X, standingY, myPos.Z), lookTarget) * CFrame.Angles(0, math.pi, 0)
				end
			end

			-- 4. Execute Attacks according to Phase Attack Interval
			local now = os.clock()
			local nextInterval = phase.attackIntervalRange[1]
				+ math.random() * (phase.attackIntervalRange[2] - phase.attackIntervalRange[1])

			if (now - lastAttackTime) >= nextInterval and not isAttacking then
				lastAttackTime = now
				isAttacking = true
				isWalking = false
				if walkTrack and walkTrack.IsPlaying then
					walkTrack:Stop(0.15)
				end
				if currentTween then
					currentTween:Cancel()
				end

				-- Face player before initiating attack
				local currentFloorY = getGroundY(myPos, (myPos.Y >= 35 and 49.0 or 1.0))
				local standingY = currentFloorY + footOffset + 0.05
				local lookTarget = Vector3.new(flatTarget.X, standingY, flatTarget.Z)
				model.PrimaryPart.CFrame = CFrame.lookAt(Vector3.new(myPos.X, standingY, myPos.Z), lookTarget) * CFrame.Angles(0, math.pi, 0)

				-- Anti-repeat: avoid picking the same attack twice in a row
				local pool = phase.attackPool
				local attackId
				if #pool > 1 and handle._lastAttackId then
					repeat
						attackId = pool[math.random(1, #pool)]
					until attackId ~= handle._lastAttackId
				else
					attackId = pool[math.random(1, #pool)]
				end
				handle._lastAttackId = attackId

				local attack = BossAttacks[attackId]
				local multiplier = phase.telegraphTimeMultiplier or 1.0
				local telegraphDur = attack.telegraphTime * multiplier

				-- Determine telegraph location based on attack type, snapped flush to arena floor
				local facing = (flatTarget - myPos).Magnitude > 0.5 and (flatTarget - myPos).Unit or Vector3.zAxis
				local myGroundY = getGroundY(myPos, (myPos.Y >= 35 and 49.0 or 1.0)) + 0.12
				local targetGroundY = getGroundY(targetPos, (targetPos.Y >= 35 and 49.0 or 1.0)) + 0.12
				local floorY = myGroundY
				local telegraphPos = Vector3.new(myPos.X, myGroundY, myPos.Z)

				if attackId == "Rockhide_OverheadSlam" or attackId == "Solarius_SolarSmite" or attack.type == "TargetedAoe" then
					floorY = targetGroundY
					telegraphPos = Vector3.new(
						math.clamp(targetPos.X, -46, 46),
						floorY,
						math.clamp(targetPos.Z, -18, 90)
					)
				elseif attackId == "Rockhide_SweepingBackhand" or attackId == "Solarius_RadiantSlash" or attackId == "Solarius_Sunburst" or attack.type == "Cleave" or attack.type == "Sweep" then
					local cleavePos = myPos + facing * 8
					floorY = getGroundY(cleavePos, (cleavePos.Y >= 35 and 49.0 or 1.0)) + 0.12
					telegraphPos = Vector3.new(cleavePos.X, floorY, cleavePos.Z)
				elseif attack.type == "Charge" then
					local chargeDist = attack.chargeDistance or 20
					local rawChargeEnd = myPos + facing * chargeDist
					local chargeFloorY = getGroundY(rawChargeEnd, (rawChargeEnd.Y >= 35 and 49.0 or 1.0))
					local chargeEnd = Vector3.new(
						math.clamp(rawChargeEnd.X, -50, 50),
						chargeFloorY + footOffset + 0.05,
						math.clamp(rawChargeEnd.Z, -20, 95)
					)
					floorY = chargeFloorY + 0.12
					telegraphPos = Vector3.new(chargeEnd.X, floorY, chargeEnd.Z)
				elseif attack.type == "Pound" or attackId == "Solarius_SweepingCleave" or attackId == "Solarius_BlindingAura" or attackId == "Solarius_Supernova" then
					floorY = myGroundY
					telegraphPos = Vector3.new(myPos.X, floorY, myPos.Z)
				else
					local slamCenter = myPos + facing * 4
					floorY = getGroundY(slamCenter, (slamCenter.Y >= 35 and 49.0 or 1.0)) + 0.12
					telegraphPos = Vector3.new(slamCenter.X, floorY, slamCenter.Z)
				end

				Net.Get("TelegraphAttack"):FireAllClients(attackId, telegraphPos, telegraphDur, attack.radius)

				-- ── BESPOKE ATTACK EXECUTION PIPELINE ─────────────────────────
				if attackId == "Rockhide_OverheadSlam" then
					-- ── 1. OVERHEAD SLAM (Earthbreaker Leap Smash) ────────────
					local windupDur = math.max(0.25, telegraphDur - 0.45)

					-- Windup: crouch down low into a jump prep stance
					poseTorso(joints, CFrame.Angles(math.rad(-18), 0, 0), 0.35)
					poseNeck(joints, CFrame.Angles(math.rad(-30), 0, 0), 0.35)
					poseArms(joints, CFrame.Angles(math.rad(-90), 0, math.rad(12)), CFrame.Angles(math.rad(-90), 0, math.rad(-12)), 0.35)
					poseLegs(joints, CFrame.Angles(math.rad(28), 0, 0), CFrame.Angles(math.rad(28), 0, 0), 0.35)
					spawnFootstepDust(myPos)
					task.wait(windupDur)

					if not alive then break end

					-- Leap: boss leaps through the sky directly toward telegraphPos
					local landingPos = Vector3.new(telegraphPos.X, getGroundY(telegraphPos, (telegraphPos.Y >= 35 and 49.0 or 1.0)) + footOffset + 0.05, telegraphPos.Z)
					local leapApex = math.max(9, (landingPos - myPos).Magnitude * 0.32)
					local leapStartTime = os.clock()
					local leapDur = 0.42
					playSound("BossLeap", "rbxasset://sounds/action_jump.mp3", model.PrimaryPart, 1.8, 0.65)

					-- Fists raised high in apex sledgehammer pose
					poseArms(joints, CFrame.Angles(math.rad(-105), 0, math.rad(8)), CFrame.Angles(math.rad(-105), 0, math.rad(-8)), 0.15)
					poseNeck(joints, CFrame.Angles(math.rad(-15), 0, 0), 0.15)

					while (os.clock() - leapStartTime) < leapDur do
						if not alive then break end
						local alpha = math.clamp((os.clock() - leapStartTime) / leapDur, 0, 1)
						local arcY = 4 * leapApex * alpha * (1 - alpha)
						local currentP = myPos:Lerp(landingPos, alpha) + Vector3.new(0, arcY, 0)
						local lookTarget = Vector3.new(landingPos.X, currentP.Y, landingPos.Z)
						model.PrimaryPart.CFrame = CFrame.lookAt(currentP, lookTarget) * CFrame.Angles(0, math.pi, 0)
						task.wait(0.02)
					end

					if not alive then break end

					-- Ensure snapped to final landing CFrame
					local finalLook = Vector3.new(targetPos.X, landingPos.Y, targetPos.Z)
					model.PrimaryPart.CFrame = CFrame.lookAt(landingPos, finalLook) * CFrame.Angles(0, math.pi, 0)

					-- Violent impact slam
					poseArms(joints, CFrame.Angles(math.rad(62), 0, math.rad(-8)), CFrame.Angles(math.rad(62), 0, math.rad(8)), 0.08)
					poseTorso(joints, CFrame.Angles(math.rad(30), 0, 0), 0.08)
					poseNeck(joints, CFrame.Angles(math.rad(30), 0, 0), 0.08)
					poseLegs(joints, CFrame.Angles(math.rad(36), 0, 0), CFrame.Angles(math.rad(36), 0, 0), 0.08)

					local impactFloor = getGroundY(telegraphPos) + 0.12
					spawnRockSpikes(telegraphPos, 8, attack.radius * 0.85, 2.5, 4.2)
					spawnFlyingDebris(telegraphPos, 14, 20, 6, 12)
					spawnShockwaveRing(Vector3.new(telegraphPos.X, impactFloor + 0.15, telegraphPos.Z), 2, attack.radius, Color3.fromRGB(255, 95, 20), 0.6, 0.4)
					spawnGroundScorch(Vector3.new(telegraphPos.X, impactFloor + 0.10, telegraphPos.Z), attack.radius * 0.6, Color3.fromRGB(160, 50, 10), 3.5)
					playSound("SlamBoom", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.2, 0.7)
					Net.Get("BossEffect"):FireAllClients("medShake", telegraphPos, { intensity = 0.85, duration = 0.55 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, telegraphPos, 34, 16)
					end

					task.wait(0.35)
					resetAllJoints(joints, 0.30)
					task.wait(0.20)

				elseif attackId == "Rockhide_ArmSweep" or attack.type == "Sweep" then
					-- ── NORMAL ARM SWEEP (Frontal Arm Swipe) ──────────────────
					local windupDur = math.max(0.18, telegraphDur - 0.20)

					-- Windup: cock left arm back high, twist torso left, lean in
					poseTorso(joints, CFrame.Angles(0, math.rad(-35), 0), 0.25)
					poseArms(joints, CFrame.Angles(math.rad(55), math.rad(-30), math.rad(-25)), CFrame.Angles(math.rad(15), 0, math.rad(10)), 0.25)
					poseNeck(joints, CFrame.Angles(0, math.rad(25), 0), 0.25)
					poseLegs(joints, CFrame.Angles(math.rad(12), 0, 0), CFrame.Angles(math.rad(-8), 0, 0), 0.25)
					spawnFootstepDust(myPos)
					task.wait(windupDur)

					if not alive then break end

					-- Release: ferocious horizontal arm sweep from left to right across front
					poseTorso(joints, CFrame.Angles(0, math.rad(45), 0), 0.10)
					poseArms(joints, CFrame.Angles(math.rad(40), math.rad(65), math.rad(15)), CFrame.Angles(math.rad(-15), 0, 0), 0.10)
					poseNeck(joints, CFrame.Angles(0, math.rad(-20), 0), 0.10)

					local impactFloor = getGroundY(telegraphPos) + 0.12
					playSound("SweepSlash", "rbxasset://sounds/swordslash.wav", model.PrimaryPart, 2.0, 0.85)
					spawnCleaveArc(model.PrimaryPart.Position, facing, attack.radius, 0.28)
					spawnFlyingDebris(telegraphPos, 8, 14, 3, 6)
					spawnFootstepDust(model.PrimaryPart.Position + facing * 5)
					Net.Get("BossEffect"):FireAllClients("lightShake", telegraphPos, { intensity = 0.35, duration = 0.25 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, model.PrimaryPart.Position, 24, 10)
					end

					task.wait(0.25)
					resetAllJoints(joints, 0.25)
					task.wait(0.15)

				elseif attackId == "Rockhide_SweepingBackhand" or attack.type == "Cleave" then
					-- ── 2. SWEEPING BACKHAND (160° Frontal Cleave) ────────────
					local windupDur = math.max(0.25, telegraphDur - 0.22)

					-- Cock right arm back to the right side and twist torso forward-right
					poseTorso(joints, CFrame.Angles(0, math.rad(35), 0), 0.35)
					poseArms(joints, CFrame.Angles(math.rad(15), 0, math.rad(10)), CFrame.Angles(math.rad(55), math.rad(-45), math.rad(25)), 0.35)
					poseNeck(joints, CFrame.Angles(0, math.rad(-25), 0), 0.35)
					poseLegs(joints, CFrame.Angles(math.rad(-10), 0, 0), CFrame.Angles(math.rad(15), 0, 0), 0.35)
					spawnFootstepDust(myPos)
					task.wait(windupDur)

					if not alive then break end

					-- Release: ferocious 160° horizontal whip across chest from right to left
					poseTorso(joints, CFrame.Angles(0, math.rad(-50), 0), 0.12)
					poseArms(joints, CFrame.Angles(math.rad(-15), 0, 0), CFrame.Angles(math.rad(45), math.rad(70), math.rad(-20)), 0.12)
					poseNeck(joints, CFrame.Angles(0, math.rad(25), 0), 0.12)

					local impactFloor = getGroundY(telegraphPos) + 0.12
					playSound("CleaveSlash", "rbxasset://sounds/swordslash.wav", model.PrimaryPart, 2.2, 0.6)
					spawnCleaveArc(model.PrimaryPart.Position, facing, attack.radius, 0.35)
					spawnFlyingDebris(telegraphPos, 10, 16, 4, 8)
					spawnShockwaveRing(Vector3.new(telegraphPos.X, impactFloor + 0.15, telegraphPos.Z), 2, attack.radius * 0.8, Color3.fromRGB(255, 120, 30), 0.45, 0.3)
					spawnGroundScorch(Vector3.new(telegraphPos.X, impactFloor + 0.10, telegraphPos.Z), attack.radius * 0.5, Color3.fromRGB(160, 50, 10), 2.5)
					Net.Get("BossEffect"):FireAllClients("lightShake", telegraphPos, { intensity = 0.5, duration = 0.35 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, model.PrimaryPart.Position, 30, 12)
					end

					task.wait(0.35)
					resetAllJoints(joints, 0.30)
					task.wait(0.20)

				elseif attackId == "Rockhide_GroundPound" or (attack.type == "Pound" and not attack.isEnrage) then
					-- ── 3. GROUND POUND (Tectonic Shockwave) ───────────────────
					local windupDur = math.max(0.30, telegraphDur - 0.20)

					-- Rearing roar
					poseNeck(joints, CFrame.Angles(math.rad(-45), 0, 0), 0.45)
					poseArms(joints, CFrame.Angles(math.rad(-95), 0, math.rad(28)), CFrame.Angles(math.rad(-95), 0, math.rad(-28)), 0.45)
					poseTorso(joints, CFrame.Angles(math.rad(-18), 0, 0), 0.45)
					poseLegs(joints, CFrame.Angles(math.rad(-10), 0, 0), CFrame.Angles(math.rad(-10), 0, 0), 0.45)

					for _, entry in _flashParts do
						if entry.part and entry.part.Parent then
							entry.part.Color = Color3.fromRGB(255, 75, 20)
						end
					end
					Net.Get("BossEffect"):FireAllClients("lightShake", telegraphPos, { intensity = 0.3, duration = windupDur })
					task.wait(windupDur)

					if not alive then break end

					for _, entry in _flashParts do
						if entry.part and entry.part.Parent then
							entry.part.Color = entry.orig
						end
					end

					-- Smashing impact
					poseArms(joints, CFrame.Angles(math.rad(62), 0, 0), CFrame.Angles(math.rad(62), 0, 0), 0.10)
					poseTorso(joints, CFrame.Angles(math.rad(30), 0, 0), 0.10)
					poseNeck(joints, CFrame.Angles(math.rad(35), 0, 0), 0.10)
					poseLegs(joints, CFrame.Angles(math.rad(40), 0, 0), CFrame.Angles(math.rad(40), 0, 0), 0.10)

					local impactFloor = getGroundY(telegraphPos) + 0.12
					spawnRockSpikes(telegraphPos, 10, attack.radius * 0.80, 3.2, 5.0)
					spawnFlyingDebris(telegraphPos, 18, 28, 8, 16)
					spawnShockwaveRing(Vector3.new(telegraphPos.X, impactFloor + 0.15, telegraphPos.Z), 3, attack.radius, Color3.fromRGB(255, 80, 20), 0.8, 0.5)
					task.delay(0.12, function()
						if alive then
							spawnShockwaveRing(Vector3.new(telegraphPos.X, impactFloor + 0.20, telegraphPos.Z), 1.5, attack.radius * 0.65, Color3.fromRGB(255, 150, 35), 0.6, 0.3)
						end
					end)
					spawnGroundScorch(Vector3.new(telegraphPos.X, impactFloor + 0.10, telegraphPos.Z), attack.radius * 0.65, Color3.fromRGB(160, 45, 10), 4.5)
					playSound("PoundBoom", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.3, 0.55)
					Net.Get("BossEffect"):FireAllClients("medShake", telegraphPos, { intensity = 0.9, duration = 0.7 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, telegraphPos, 38, 20)
					end

					task.wait(0.40)
					resetAllJoints(joints, 0.40)
					task.wait(0.20)

				elseif attack.type == "Charge" then
					-- ── 4. STONE CHARGE (Bull Rush) ───────────────────────────
					local windupDur = math.max(0.25, telegraphDur - 0.28)

					-- Low bull stance
					poseTorso(joints, CFrame.Angles(math.rad(28), 0, 0), 0.25)
					poseNeck(joints, CFrame.Angles(math.rad(22), 0, 0), 0.25)
					poseArms(joints, CFrame.Angles(math.rad(40), 0, math.rad(15)), CFrame.Angles(math.rad(40), 0, math.rad(-15)), 0.25)
					spawnFootstepDust(myPos)
					playSound("Scrape", "rbxasset://sounds/action_footsteps_plastic.mp3", model.PrimaryPart, 1.5, 0.6)
					task.wait(windupDur)

					if not alive then break end

					-- Dash forward
					local chargeDist = attack.chargeDistance or 20
					local rawChargeEnd = myPos + facing * chargeDist
					local chargeFloorY = getGroundY(rawChargeEnd, (rawChargeEnd.Y >= 35 and 49.0 or 1.0))
					local chargeEnd = Vector3.new(
						math.clamp(rawChargeEnd.X, -50, 50),
						chargeFloorY + footOffset + 0.05,
						math.clamp(rawChargeEnd.Z, -20, 95)
					)
					local chargeLookTarget = Vector3.new(chargeEnd.X + facing.X, chargeFloorY + footOffset + 0.05, chargeEnd.Z + facing.Z)
					local chargeCFrame = CFrame.lookAt(chargeEnd, chargeLookTarget) * CFrame.Angles(0, math.pi, 0)
					playSound("ChargeRush", "rbxasset://sounds/action_jump.mp3", model.PrimaryPart, 1.8, 0.5)

					currentTween = TweenService:Create(
						model.PrimaryPart,
						TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ CFrame = chargeCFrame }
					)
					currentTween:Play()
					task.wait(0.28)

					if not alive then break end

					-- Brake and thrust arms forward
					poseArms(joints, CFrame.Angles(math.rad(-25), 0, 0), CFrame.Angles(math.rad(-25), 0, 0), 0.12)
					local arrivedPos = model.PrimaryPart and model.PrimaryPart.Position or chargeEnd
					local impactFloor = getGroundY(arrivedPos) + 0.12
					spawnBurstOrb(Vector3.new(arrivedPos.X, impactFloor + 1.5, arrivedPos.Z), 4, Color3.fromRGB(255, 100, 30), 0.45)
					spawnFlyingDebris(arrivedPos, 12, 18, 5, 10)
					spawnShockwaveRing(Vector3.new(arrivedPos.X, impactFloor + 0.15, arrivedPos.Z), 2, attack.radius + 4, Color3.fromRGB(255, 140, 50), 0.55, 0.4)
					spawnGroundScorch(Vector3.new(arrivedPos.X, impactFloor + 0.10, arrivedPos.Z), attack.radius * 0.7, Color3.fromRGB(200, 75, 20), 3.5)
					playSound("ChargeCrash", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.0, 0.8)
					Net.Get("BossEffect"):FireAllClients("medShake", arrivedPos, { intensity = 0.7, duration = 0.45 })

					for _, player in CombatService.PlayersInRadius(arrivedPos, attack.radius + 2) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, arrivedPos, 32, 14)
					end

					task.wait(0.25)
					resetAllJoints(joints, 0.30)
					task.wait(0.20)

				elseif attackId == "Rockhide_BoulderBarrage" or (attack.type == "TargetedAoe" and attack.hitCount and attack.hitCount > 1) then
					-- ── 5. BOULDER BARRAGE (Earthen Hurling) ──────────────────
					local hitCount = attack.hitCount or 3
					local allPlayers = Players:GetPlayers()

					for i = 1, hitCount do
						if not alive then break end
						local targetP = allPlayers[math.random(1, #allPlayers)]
						local targetR = targetP and targetP.Character and targetP.Character:FindFirstChild("HumanoidRootPart")
						local rawPos = targetR and targetR.Position or telegraphPos
						local waveFloor = getGroundY(rawPos) + 0.12
						local wavePos = Vector3.new(
							math.clamp(rawPos.X, -46, 46),
							waveFloor,
							math.clamp(rawPos.Z, -18, 90)
						)

						-- Face target wave position
						local curPos = model.PrimaryPart.Position
						local lookTarget = Vector3.new(wavePos.X, curPos.Y, wavePos.Z)
						model.PrimaryPart.CFrame = CFrame.lookAt(curPos, lookTarget) * CFrame.Angles(0, math.pi, 0)

						-- Windup & rip boulder out of ground
						poseArms(joints, CFrame.Angles(math.rad(-75), 0, math.rad(15)), CFrame.Angles(math.rad(-75), 0, math.rad(-15)), 0.20)
						poseTorso(joints, CFrame.Angles(math.rad(-15), 0, 0), 0.20)
						local handPos = model.PrimaryPart.Position + model.PrimaryPart.CFrame.LookVector * 4 + Vector3.new(0, 4, 0)
						spawnFootstepDust(curPos)
						spawnFlyingDebris(handPos - Vector3.new(0, 3.5, 0), 6, 8, 3, 6)
						task.wait(0.24)

						if not alive then break end

						-- Throw motion
						poseArms(joints, CFrame.Angles(math.rad(45), 0, 0), CFrame.Angles(math.rad(45), 0, 0), 0.10)
						poseTorso(joints, CFrame.Angles(math.rad(20), 0, 0), 0.10)
						playSound("Throw", "rbxasset://sounds/action_jump.mp3", model.PrimaryPart, 1.4, 0.7)

						Net.Get("TelegraphAttack"):FireAllClients(attackId .. "_wave" .. i, wavePos, 0.42, attack.radius)
						hurlBoulder(handPos, wavePos, 0.42, function()
							if not alive then return end
							local floorHit = getGroundY(wavePos) + 0.12
							spawnBurstOrb(Vector3.new(wavePos.X, floorHit + 1.2, wavePos.Z), 3, Color3.fromRGB(255, 120, 30), 0.4)
							spawnGroundScorch(Vector3.new(wavePos.X, floorHit + 0.10, wavePos.Z), attack.radius * 0.6, Color3.fromRGB(180, 60, 10), 2.5)
							playSound("Detonation", "rbxasset://sounds/action_explode.mp3", workspace, 1.6, 1.05)
							Net.Get("BossEffect"):FireAllClients("lightShake", wavePos, { intensity = 0.4, duration = 0.3 })
							for _, player in CombatService.PlayersInRadius(wavePos, attack.radius) do
								CombatService.ApplyDamageToPlayer(player, attack.damage)
								applyKnockback(player, wavePos, 28, 14)
							end
						end)

						task.wait(0.48)
					end

					resetAllJoints(joints, 0.30)
					task.wait(0.20)

				elseif attack.isEnrage then
					-- ── 6. SEISMIC SLAM (Phase 3 Enrage Ultimate) ─────────────
					local windupDur = math.max(0.35, telegraphDur - 0.30)

					-- Full-body molten incandescent glow
					for _, entry in _flashParts do
						if entry.part and entry.part.Parent then
							entry.part.Color = Color3.fromRGB(255, 60, 20)
						end
					end

					-- Roar and rear back
					poseNeck(joints, CFrame.Angles(math.rad(-50), 0, 0), 0.45)
					poseArms(joints, CFrame.Angles(math.rad(-95), 0, math.rad(30)), CFrame.Angles(math.rad(-95), 0, math.rad(-30)), 0.45)
					poseTorso(joints, CFrame.Angles(math.rad(-22), 0, 0), 0.45)
					playSound("EnrageRoar", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.2, 0.45)
					Net.Get("BossEffect"):FireAllClients("heavyShake", telegraphPos, { intensity = 0.8, duration = windupDur })
					task.wait(windupDur)

					if not alive then break end

					for _, entry in _flashParts do
						if entry.part and entry.part.Parent then
							entry.part.Color = entry.orig
						end
					end

					-- Cataclysmic smash
					poseArms(joints, CFrame.Angles(math.rad(65), 0, 0), CFrame.Angles(math.rad(65), 0, 0), 0.08)
					poseTorso(joints, CFrame.Angles(math.rad(32), 0, 0), 0.08)
					poseNeck(joints, CFrame.Angles(math.rad(35), 0, 0), 0.08)

					local impactFloor = getGroundY(telegraphPos) + 0.12
					spawnRockSpikes(telegraphPos, 14, attack.radius * 0.85, 4.0, 6.0)
					spawnFlyingDebris(telegraphPos, 26, 36, 10, 20)

					for i = 1, 4 do
						local r = i * (attack.radius / 4)
						local angle = (i * math.pi / 2) + math.random() * 0.8
						local pPos = Vector3.new(
							telegraphPos.X + math.cos(angle) * r,
							impactFloor,
							telegraphPos.Z + math.sin(angle) * r
						)
						task.delay((i - 1) * 0.1, function()
							if alive then spawnFirePillar(pPos, 24, Color3.fromRGB(255, 50, 10), 1.2) end
						end)
					end

					spawnShockwaveRing(Vector3.new(telegraphPos.X, impactFloor + 0.15, telegraphPos.Z), 3, attack.radius, Color3.fromRGB(255, 80, 20), 0.9, 0.7)
					task.delay(0.18, function()
						if alive then
							spawnShockwaveRing(Vector3.new(telegraphPos.X, impactFloor + 0.20, telegraphPos.Z), 1.5, attack.radius * 0.65, Color3.fromRGB(255, 160, 40), 0.7, 0.35)
						end
					end)
					spawnGroundScorch(Vector3.new(telegraphPos.X, impactFloor + 0.10, telegraphPos.Z), attack.radius * 0.8, Color3.fromRGB(180, 30, 10), 5.0)
					playSound("MegaBoom", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.8, 0.5)
					Net.Get("BossEffect"):FireAllClients("heavyShake", telegraphPos, { intensity = 1.2, duration = 1.0 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, telegraphPos, 45, 22)
					end

					task.wait(0.50)
					resetAllJoints(joints, 0.50)
					task.wait(0.25)

				elseif attackId == "Solarius_RadiantSlash" then
					-- ── SOLARIUS: RADIANT SLASH ──
					local windupDur = math.max(0.18, telegraphDur - 0.22)
					poseArms(joints, CFrame.Angles(math.rad(60), math.rad(-40), math.rad(-25)), CFrame.Angles(math.rad(20), 0, math.rad(15)), 0.22)
					poseTorso(joints, CFrame.Angles(0, math.rad(-30), 0), 0.22)
					poseNeck(joints, CFrame.Angles(0, math.rad(20), 0), 0.22)
					playSound("SolarCharge", "rbxasset://sounds/swordslash.wav", model.PrimaryPart, 2.2, 1.2)
					task.wait(windupDur)
					if not alive then break end

					poseTorso(joints, CFrame.Angles(0, math.rad(45), 0), 0.10)
					poseArms(joints, CFrame.Angles(math.rad(45), math.rad(70), math.rad(20)), CFrame.Angles(math.rad(-15), 0, 0), 0.10)
					playSound("RadiantSlash", "rbxasset://sounds/swordslash.wav", model.PrimaryPart, 2.5, 0.9)
					spawnCleaveArc(model.PrimaryPart.Position, facing, attack.radius, 0.35)
					spawnShockwaveRing(Vector3.new(telegraphPos.X, floorY + 0.15, telegraphPos.Z), 2, attack.radius * 0.7, Color3.fromRGB(255, 200, 50), 0.5, 0.3)
					Net.Get("BossEffect"):FireAllClients("medShake", telegraphPos, { intensity = 0.5, duration = 0.3 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, model.PrimaryPart.Position, 28, 12)
					end
					task.wait(0.3)
					resetAllJoints(joints, 0.25)
					task.wait(0.15)

				elseif attackId == "Solarius_SweepingCleave" then
					-- ── SOLARIUS: SWEEPING CLEAVE ──
					local windupDur = math.max(0.2, telegraphDur - 0.25)
					poseArms(joints, CFrame.Angles(math.rad(80), math.rad(-60), math.rad(-30)), CFrame.Angles(math.rad(-30), 0, math.rad(-15)), 0.25)
					poseTorso(joints, CFrame.Angles(math.rad(-10), math.rad(-45), 0), 0.25)
					task.wait(windupDur)
					if not alive then break end

					playSound("SweepingCleave", "rbxasset://sounds/swordslash.wav", model.PrimaryPart, 2.6, 0.75)
					poseTorso(joints, CFrame.Angles(0, math.rad(180), 0), 0.12)
					poseArms(joints, CFrame.Angles(math.rad(30), math.rad(90), math.rad(45)), CFrame.Angles(math.rad(30), math.rad(-90), math.rad(-45)), 0.12)
					spawnShockwaveRing(Vector3.new(telegraphPos.X, floorY + 0.15, telegraphPos.Z), 3, attack.radius, Color3.fromRGB(255, 160, 30), 0.8, 0.5)
					spawnGroundScorch(Vector3.new(telegraphPos.X, floorY + 0.1, telegraphPos.Z), attack.radius * 0.7, Color3.fromRGB(255, 130, 20), 4.0)
					Net.Get("BossEffect"):FireAllClients("heavyShake", telegraphPos, { intensity = 0.7, duration = 0.4 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, model.PrimaryPart.Position, 38, 16)
					end
					task.wait(0.35)
					resetAllJoints(joints, 0.3)
					task.wait(0.2)

				elseif attackId == "Solarius_SolarSmite" then
					-- ── SOLARIUS: SOLAR SMITE (PILLARS OF SUNLIGHT) ──
					local windupDur = math.max(0.3, telegraphDur - 0.35)
					poseArms(joints, CFrame.Angles(math.rad(-120), 0, math.rad(10)), CFrame.Angles(math.rad(-100), 0, math.rad(-10)), 0.3)
					poseNeck(joints, CFrame.Angles(math.rad(-35), 0, 0), 0.3)
					playSound("SmiteCharge", "rbxasset://sounds/action_jump.mp3", model.PrimaryPart, 2.0, 1.4)
					task.wait(windupDur)
					if not alive then break end

					poseArms(joints, CFrame.Angles(math.rad(70), 0, 0), CFrame.Angles(math.rad(70), 0, 0), 0.1)
					poseTorso(joints, CFrame.Angles(math.rad(25), 0, 0), 0.1)
					playSound("SmiteImpact", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.8, 0.7)

					for i = 1, 3 do
						local offsetAngle = (i / 3) * 2 * math.pi
						local pPos = (i == 1) and telegraphPos or (telegraphPos + Vector3.new(math.cos(offsetAngle) * 10, 0, math.sin(offsetAngle) * 10))
						local groundP = Vector3.new(pPos.X, getGroundY(pPos) + 0.12, pPos.Z)
						spawnFirePillar(groundP, 30, Color3.fromRGB(255, 215, 60), 1.4)
						spawnShockwaveRing(groundP + Vector3.new(0, 0.1, 0), 2, attack.radius * 0.6, Color3.fromRGB(255, 230, 80), 0.7, 0.4)
					end
					Net.Get("BossEffect"):FireAllClients("heavyShake", telegraphPos, { intensity = 0.9, duration = 0.6 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, telegraphPos, 35, 18)
					end
					task.wait(0.4)
					resetAllJoints(joints, 0.3)
					task.wait(0.2)

				elseif attackId == "Solarius_Sunburst" then
					-- ── SOLARIUS: SUNBURST (RADIANT PROJECTILE ORBS) ──
					local windupDur = math.max(0.25, telegraphDur - 0.3)
					poseArms(joints, CFrame.Angles(math.rad(-45), math.rad(30), 0), CFrame.Angles(math.rad(-45), math.rad(-30), 0), 0.25)
					playSound("SunburstCharge", "rbxasset://sounds/swordslash.wav", model.PrimaryPart, 2.2, 1.3)
					task.wait(windupDur)
					if not alive then break end

					for i = -1, 1 do
						local spreadAngle = i * 0.35
						local burstDir = (CFrame.Angles(0, spreadAngle, 0) * CFrame.new(facing)).Position.Unit
						task.spawn(function()
							local orb = Instance.new("Part")
							orb.Name = "SunburstDisc"
							orb.Shape = Enum.PartType.Ball
							orb.Size = Vector3.new(2.8, 2.8, 2.8)
							orb.CFrame = CFrame.lookAt(model.PrimaryPart.Position + Vector3.new(0, 4, 0), model.PrimaryPart.Position + burstDir * 10)
							orb.Color = Color3.fromRGB(255, 200, 40)
							orb.Material = Enum.Material.Neon
							orb.CanCollide = false
							orb.Anchored = true
							orb.Parent = workspace

							local trail = Instance.new("ParticleEmitter")
							trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
							trail.Rate = 20
							trail.Speed = NumberRange.new(2, 4)
							trail.Lifetime = NumberRange.new(0.3, 0.6)
							trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 100, 20))
							trail.Parent = orb

							for step = 1, 20 do
								orb.CFrame = orb.CFrame + burstDir * 3.5
								for _, player in CombatService.PlayersInRadius(orb.Position, 5) do
									CombatService.ApplyDamageToPlayer(player, attack.damage)
									applyKnockback(player, orb.Position, 30, 10)
								end
								task.wait(0.03)
							end
							orb:Destroy()
						end)
					end
					playSound("SunburstLaunch", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.4, 1.1)
					task.wait(0.4)
					resetAllJoints(joints, 0.25)
					task.wait(0.15)

				elseif attackId == "Solarius_BlindingAura" then
					-- ── SOLARIUS: BLINDING AURA ──
					local windupDur = math.max(0.25, telegraphDur - 0.3)
					poseArms(joints, CFrame.Angles(0, 0, math.rad(-75)), CFrame.Angles(0, 0, math.rad(75)), 0.3)
					poseNeck(joints, CFrame.Angles(math.rad(-25), 0, 0), 0.3)
					task.wait(windupDur)
					if not alive then break end

					playSound("BlindingFlash", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.5, 0.9)
					spawnShockwaveRing(Vector3.new(telegraphPos.X, floorY + 0.2, telegraphPos.Z), 4, attack.radius, Color3.fromRGB(255, 255, 160), 0.8, 0.9)
					Net.Get("BossEffect"):FireAllClients("heavyShake", telegraphPos, { intensity = 0.8, duration = 0.5 })

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, model.PrimaryPart.Position, 45, 18)
					end
					task.wait(0.35)
					resetAllJoints(joints, 0.3)
					task.wait(0.2)
					-- ── 6. SUPERNOVA ENRAGE (Room-Wide Solar Flare) ───────────
					local windupDur = math.max(0.5, telegraphDur - 0.4)

					-- Ascend slightly & hover arms outward channeling radiant power
					poseArms(joints, CFrame.Angles(0, 0, math.rad(-85)), CFrame.Angles(0, 0, math.rad(85)), 0.6)
					poseTorso(joints, CFrame.Angles(math.rad(-15), 0, 0), 0.6)
					poseNeck(joints, CFrame.Angles(math.rad(-40), 0, 0), 0.6)

					Net.Get("BossEffect"):FireAllClients("heavyShake", telegraphPos, { intensity = 1.4, duration = windupDur })
					playSound("SupernovaCharge", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 2.5, 0.6)

					-- Solar charge visual orbs
					for i = 1, 8 do
						local angle = (i / 8) * 2 * math.pi
						local orbPos = telegraphPos + Vector3.new(math.cos(angle) * 12, 12, math.sin(angle) * 12)
						spawnBurstOrb(orbPos, 6, Color3.fromRGB(255, 180, 50), windupDur)
					end

					task.wait(windupDur)
					if not alive then break end

					-- Cataclysmic Solar Explosion
					playSound("SupernovaBlast", "rbxasset://sounds/action_explode.mp3", model.PrimaryPart, 3.0, 0.4)
					Net.Get("BossEffect"):FireAllClients("heavyShake", telegraphPos, { intensity = 1.8, duration = 1.5 })

					local impactFloor = getGroundY(telegraphPos) + 0.12
					spawnShockwaveRing(Vector3.new(telegraphPos.X, impactFloor + 0.2, telegraphPos.Z), 4, attack.radius, Color3.fromRGB(255, 220, 80), 1.2, 0.9)
					spawnGroundScorch(Vector3.new(telegraphPos.X, impactFloor + 0.1, telegraphPos.Z), attack.radius * 0.9, Color3.fromRGB(255, 120, 30), 6.0)

					for _, player in CombatService.PlayersInRadius(telegraphPos, attack.radius) do
						CombatService.ApplyDamageToPlayer(player, attack.damage)
						applyKnockback(player, telegraphPos, 50, 25)
					end

					task.wait(0.60)
					resetAllJoints(joints, 0.50)
					task.wait(0.30)
				end

				isAttacking = false
			end
		end

		CombatService.UnregisterEnemy(bossId)
		model:Destroy()
		if onDeath then
			onDeath()
		end
	end)

	return handle
end

-- Force-kills the active boss on wipe/cleanup
function BossAIService.ForceKill(handle)
	handle.onDamaged(handle.currentHealth, nil)
end

return BossAIService
