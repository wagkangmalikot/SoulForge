-- src/ServerScriptService/Services/BossAIService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local BossAttacks = require(ReplicatedStorage.Shared.Data.BossAttacks)
local CombatService = require(script.Parent.CombatService)

local BossAIService = {}

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

local function playersInRadius(center: Vector3, radius: number): {Player}
	local hit = {}
	for _, player in Players:GetPlayers() do
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and (rootPart.Position - center).Magnitude <= radius then
			table.insert(hit, player)
		end
	end
	return hit
end

-- CombatService.RegisterBoss's range check reads `activeBoss.model.PrimaryPart.Position`
-- (see CombatService.lua), which requires `model` to be a Model with PrimaryPart set — a
-- bare Part has no PrimaryPart property. Boss art assets live directly in the published
-- place under ReplicatedStorage.Assets (not Rojo-managed source, same as the hub's
-- RockhidePortal/LevelUpShrine scenery Parts -- binary content isn't practical to keep
-- in git this way), named "<bossId>BossTemplate", each already a Model with its
-- PrimaryPart set to the correct height for the telegraph ground-projection math in the
-- attack loop below to keep working unmodified. Falls back to a plain placeholder Part
-- for any boss that doesn't have a template yet, so this never hard-fails.
local function createBossModel(bossId: string, spawnCFrame: CFrame): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild(bossId .. "BossTemplate")

	local model: Model
	if template then
		model = template:Clone()
		model.Name = bossId
		model:PivotTo(spawnCFrame)
	else
		model = Instance.new("Model")
		model.Name = bossId

		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(6, 10, 6)
		torso.Anchored = true
		torso.CFrame = spawnCFrame
		torso.Parent = model

		model.PrimaryPart = torso
	end

	model.Parent = workspace

	return model
end

function BossAIService.SpawnBoss(bossId: string, spawnCFrame: CFrame, onDeath: (() -> ())?)
	local bossData = require(ReplicatedStorage.Shared.Data.Bosses[bossId])

	local model = createBossModel(bossId, spawnCFrame)

	local currentHealth = bossData.maxHealth
	local alive = true
	local firedPhaseTransitions = {}

	local handle = {
		model = model,
		currentHealth = currentHealth,
		maxHealth = bossData.maxHealth,
	}

	function handle.onDamaged(amount: number)
		if not alive then
			return
		end
		currentHealth = math.max(0, currentHealth - amount)
		handle.currentHealth = currentHealth
		local _, phaseIndex = pickPhase(bossData, currentHealth, bossData.maxHealth)
		Net.Get("BossStateChanged"):FireAllClients(bossId, phaseIndex, currentHealth, bossData.maxHealth)
		if currentHealth <= 0 then
			alive = false
		end
	end

	CombatService.RegisterBoss(handle)

	task.spawn(function()
		while alive do
			local phase = pickPhase(bossData, currentHealth, bossData.maxHealth)

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
					task.wait(transition.duration)
					if not alive then
						break
					end
				end
			end

			local waitTime = phase.attackIntervalRange[1]
				+ math.random() * (phase.attackIntervalRange[2] - phase.attackIntervalRange[1])
			task.wait(waitTime)

			if not alive then
				break
			end

			local attackId = phase.attackPool[math.random(1, #phase.attackPool)]
			local attack = BossAttacks[attackId]
			local multiplier = phase.telegraphTimeMultiplier or 1.0

			-- HUDController renders this as a flat ground-level disc. Firing
			-- model.PrimaryPart.Position directly would center it at the boss's
			-- torso height instead of its feet -- a thin, half-transparent disc
			-- floating mid-air is very easy to miss standing at ground level,
			-- defeating the whole point of a telegraph warning. Project down by
			-- half the model's height to put it where a player is actually
			-- looking.
			local groundPosition = model.PrimaryPart.Position - Vector3.new(0, model.PrimaryPart.Size.Y / 2, 0)
			Net.Get("TelegraphAttack"):FireAllClients(attackId, groundPosition, attack.telegraphTime * multiplier)
			task.wait(attack.telegraphTime * multiplier)

			if not alive then
				break
			end

			for _, player in playersInRadius(model.PrimaryPart.Position, attack.radius) do
				CombatService.ApplyDamageToPlayer(player, attack.damage)
			end
		end

		CombatService.ClearBoss()
		model:Destroy()
		if onDeath then
			onDeath()
		end
	end)

	return handle
end

-- Force-kills the active boss (e.g. on a party wipe, so the boss's attack
-- coroutine doesn't keep telegraphing/attacking an emptying server). Reuses
-- onDamaged so the existing alive=false transition, BossStateChanged fire,
-- and the coroutine's own "if not alive then break end" checks handle
-- cleanup (ClearBoss/model:Destroy/onDeath) the same way a normal kill does.
function BossAIService.ForceKill(handle)
	handle.onDamaged(handle.currentHealth)
end

return BossAIService
