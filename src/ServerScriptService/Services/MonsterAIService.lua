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

			-- Static accessories not in the jointed tree get welded to torso
			if not jointed[part] then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "IntegrityWeld_" .. part.Name
				weld.Part0 = torso
				weld.Part1 = part
				weld.Parent = torso
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

		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local template = assets and assets:FindFirstChild("TrashMobTemplate")

		local model: Model
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

		-- Elevate slightly above floor and face toward entrance corridor (-Z) BEFORE welding
		model:PivotTo(CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.pi, 0))

		-- Auto-rig limbs and secure integrity
		local primary, joints = ensureModelIntegrityAndRig(model)
		CollectionService:AddTag(model, "Enemy")
		model.Parent = workspace

		local currentHealth = MOB_MAX_HEALTH
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
		nameLabel.Text = "⚔️ Minion [Lv. 1]"
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
			maxHealth = MOB_MAX_HEALTH,
		}

		function handle.onDamaged(amount: number, attackingPlayer: Player?)
			if not alive then
				return
			end
			currentHealth = math.max(0, currentHealth - amount)
			handle.currentHealth = currentHealth
			local fillPct = math.clamp(currentHealth / MOB_MAX_HEALTH, 0, 1)
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
				if dist > MOB_ATTACK_RADIUS then
					-- Start walk animation
					if not isWalking then
						isWalking = true
						if walkTrack and not walkTrack.IsPlaying then
							walkTrack:Play(0.2)
						end
					end

					local step = math.min(MOB_WALK_SPEED * 0.22, dist - MOB_ATTACK_RADIUS + 0.5)
					local dir = (flatTarget - myPos).Unit
					local nextPos = myPos + dir * step
					local targetCFrame = CFrame.lookAt(nextPos, flatTarget) * CFrame.Angles(0, math.pi, 0)

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
					-- Inside melee range: stop walking and face target
					if isWalking then
						isWalking = false
						if walkTrack and walkTrack.IsPlaying then
							walkTrack:Stop(0.2)
						end
					end

					if currentTween then
						currentTween:Cancel()
					end
					model.PrimaryPart.CFrame = CFrame.lookAt(myPos, flatTarget) * CFrame.Angles(0, math.pi, 0)
				end

				-- 3. Melee attack: procedural arm slam + AnimationTrack + physical strike lunge
				local now = os.clock()
				if dist <= (MOB_ATTACK_RADIUS + 2) and (now - lastAttackAt) >= MOB_ATTACK_INTERVAL then
					lastAttackAt = now
					isAttacking = true

					-- A. Play attack AnimationTrack if loaded
					if attackTrack then
						attackTrack:Play(0.08)
					end

					-- B. Procedural heavy strike animation on arms
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

					-- C. Snappy physical strike lunge forward and return
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

					-- D. Deal damage on strike impact (140ms)
					task.delay(0.14, function()
						if alive and targetPlayer and targetPlayer.Character then
							CombatService.ApplyDamageToPlayer(targetPlayer, MOB_ATTACK_DAMAGE)
						end
					end)
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
