-- src/ServerScriptService/Services/CombatService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CombatService = {}

-- userId -> skillId -> last-cast os.clock() timestamp, for real skills only.
local lastCastAt = {}

-- userId -> last-cast os.clock() timestamp for the normal attack. Kept in its
-- own table (rather than a synthetic key inside lastCastAt above) since there
-- is only one normal attack -- no per-skill keying is needed, and this avoids
-- any chance of a real skillId ever colliding with a reserved sentinel key.
local lastNormalAttackAt = {}

-- targetId -> {model, currentHealth, maxHealth, onDamaged = function(amount, attackingPlayer) end}
-- Generalizes what used to be a single hardcoded `activeBoss` slot: both
-- BossAIService and MonsterAIService register their spawned enemies here
-- under a stable targetId (the boss's bossId, or a mob's own generated id),
-- so onCastSkill/onCastNormalAttack can resolve ANY currently-targeted enemy
-- through one code path instead of only ever being able to hit "the boss".
local enemies = {}

function CombatService.RegisterEnemy(targetId: string, handle)
	enemies[targetId] = handle
end

function CombatService.UnregisterEnemy(targetId: string)
	enemies[targetId] = nil
end

function CombatService.GetEnemy(targetId: string)
	return enemies[targetId]
end

local NORMAL_ATTACK_COOLDOWN = 1
local NORMAL_ATTACK_DAMAGE = 5
local NORMAL_ATTACK_RANGE = 8

local function isOnCooldown(userId: number, skillId: string, cooldown: number): boolean
	local perPlayer = lastCastAt[userId]
	if not perPlayer then
		return false
	end
	local last = perPlayer[skillId]
	if not last then
		return false
	end
	return (os.clock() - last) < cooldown
end

local function markCast(userId: number, skillId: string)
	lastCastAt[userId] = lastCastAt[userId] or {}
	lastCastAt[userId][skillId] = os.clock()
end

local function onCastSkill(player: Player, skillId: string, targetId: string?)
	local skill = Skills[skillId]
	if not skill then
		return -- unknown skillId: silently ignore (section 15, whitelist real Data lookups)
	end

	-- Skill unlock level (spec section 2b): a skill isn't castable until the
	-- player's Character.Level meets its unlockLevel, checked server-side --
	-- never trust a client that only shows a skill as "locked" cosmetically.
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Character.Level < (skill.unlockLevel or 1) then
		return
	end

	if isOnCooldown(player.UserId, skillId, skill.cooldown) then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	-- Resolved once and reused for both the range check and the damage
	-- application below, rather than looking the target up twice. The
	-- client's targetId is never trusted on its own -- GetEnemy either
	-- returns nil (target doesn't exist / already dead) or a live handle
	-- whose actual current position is what the range check uses.
	local enemy = targetId and enemies[targetId]
	if skill.range > 0 then
		if not enemy or not enemy.model.PrimaryPart then
			return -- no valid target in range: reject, no client-tolerance loophole beyond this check
		end
		local distance = (enemy.model.PrimaryPart.Position - rootPart.Position).Magnitude
		if distance > skill.range then
			return
		end
	end

	markCast(player.UserId, skillId)

	if skill.damage > 0 and enemy then
		enemy.onDamaged(skill.damage, player)
	end
end

local function onCastNormalAttack(player: Player, targetId: string?)
	if not targetId then
		return
	end
	local lastCast = lastNormalAttackAt[player.UserId]
	if lastCast and (os.clock() - lastCast) < NORMAL_ATTACK_COOLDOWN then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local enemy = enemies[targetId]
	if not enemy or not enemy.model.PrimaryPart then
		return
	end
	local distance = (enemy.model.PrimaryPart.Position - rootPart.Position).Magnitude
	if distance > NORMAL_ATTACK_RANGE then
		return
	end

	lastNormalAttackAt[player.UserId] = os.clock()
	enemy.onDamaged(NORMAL_ATTACK_DAMAGE, player)
end

function CombatService.ApplyDamageToPlayer(player: Player, amount: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.Health = math.max(0, humanoid.Health - amount)
	Net.Get("HealthChanged"):FireAllClients(player.UserId, humanoid.Health, humanoid.MaxHealth)
end

-- Shared by BossAIService and MonsterAIService's attack loops to find which
-- players are standing close enough to a given point to be hit by an attack.
function CombatService.PlayersInRadius(center: Vector3, radius: number): {Player}
	local hit = {}
	for _, player in Players:GetPlayers() do
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and (rootPart.Position - center).Magnitude <= radius then
			table.insert(hit, player)
		end
	end
	return hit
end

function CombatService.Start()
	Net.Get("CastSkill").OnServerEvent:Connect(function(player, skillId, targetId)
		if type(skillId) ~= "string" then
			return
		end
		if targetId ~= nil and type(targetId) ~= "string" then
			return
		end
		onCastSkill(player, skillId, targetId)
	end)

	Net.Get("CastNormalAttack").OnServerEvent:Connect(function(player, targetId)
		if type(targetId) ~= "string" then
			return
		end
		onCastNormalAttack(player, targetId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCastAt[player.UserId] = nil
		lastNormalAttackAt[player.UserId] = nil
	end)
end

return CombatService
