-- src/ServerScriptService/Services/MonsterAIService.lua
-- Trash mobs (spec 10a): weak, stationary enemies placed along Rockhide's
-- entrance corridor as a basic combat-teaching beat before the boss fight.
-- Unlike BossAIService's bosses, they have no phases or telegraphs -- just a
-- periodic "is anyone close enough" check that deals damage automatically.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local CombatService = require(script.Parent.CombatService)

local MonsterAIService = {}

local MOB_MAX_HEALTH = 20
local MOB_ATTACK_DAMAGE = 4
local MOB_ATTACK_RADIUS = 6
local MOB_ATTACK_INTERVAL = 2 -- seconds between automatic attacks while a player is in range

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

-- Spawns one mob at `position`, registered under CombatService as `targetId`.
-- `onKilled(attackingPlayer)` fires once, the moment the mob's health
-- reaches 0, so the caller (DungeonSessionService, which owns EXP/reward
-- economy) can award its EXP trickle -- this service only knows about
-- combat/positioning, matching the existing separation where BossAIService
-- has no idea EXP or profiles exist either.
local function spawnMob(targetId: string, position: Vector3, onKilled: (Player) -> ())
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("TrashMobTemplate")

	local model: Model
	if template then
		model = template:Clone()
		model.Name = targetId
		model:PivotTo(CFrame.new(position))
	else
		-- No art asset yet -- plain placeholder, same fallback pattern as
		-- BossAIService.createBossModel.
		model = Instance.new("Model")
		model.Name = targetId

		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3, 4, 3)
		body.Anchored = true
		body.CFrame = CFrame.new(position)
		body.Color = Color3.fromRGB(120, 110, 90)
		body.Parent = model

		model.PrimaryPart = body
	end

	CollectionService:AddTag(model, "Enemy")
	model.Parent = workspace

	local currentHealth = MOB_MAX_HEALTH
	local alive = true

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
		if currentHealth <= 0 then
			alive = false
			CombatService.UnregisterEnemy(targetId)
			model:Destroy()
			if attackingPlayer then
				onKilled(attackingPlayer)
			end
		end
	end

	CombatService.RegisterEnemy(targetId, handle)

	-- Stationary: never moves or paths toward players (spec 10a) -- just
	-- checks periodically whether anyone is close enough to hit. Mirrors
	-- BossAIService's own attack-loop shape, minus phases/telegraphs.
	task.spawn(function()
		while alive do
			task.wait(MOB_ATTACK_INTERVAL)
			if not alive then
				break
			end
			for _, player in playersInRadius(model.PrimaryPart.Position, MOB_ATTACK_RADIUS) do
				CombatService.ApplyDamageToPlayer(player, MOB_ATTACK_DAMAGE)
			end
		end
	end)

	return handle
end

-- Spawns one mob per entry in `positions`, each getting its own targetId
-- ("TrashMob_1", "TrashMob_2", ...). `onKilled(attackingPlayer)` is called
-- once per mob death, from whichever player's attack lands the killing blow.
-- Returns a cleanup function that force-destroys any mobs still alive --
-- call it when the dungeon session ends (victory or wipe), mirroring
-- BossAIService.ForceKill/RespawnService.Stop, so a party that finishes the
-- run doesn't leave stray mobs attacking an emptying server.
function MonsterAIService.SpawnMobs(positions: {Vector3}, onKilled: (Player) -> ()): () -> ()
	local handles = {}
	for index, position in positions do
		local targetId = "TrashMob_" .. index
		handles[targetId] = spawnMob(targetId, position, onKilled)
	end

	return function()
		for targetId, handle in handles do
			if handle.model.Parent then
				CombatService.UnregisterEnemy(targetId)
				handle.model:Destroy()
			end
		end
	end
end

return MonsterAIService
