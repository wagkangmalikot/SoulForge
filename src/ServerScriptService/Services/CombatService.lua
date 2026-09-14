-- src/ServerScriptService/Services/CombatService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)

local CombatService = {}

-- userId -> skillId -> last-cast os.clock() timestamp
local lastCastAt = {}

-- Registered by BossAIService so player attacks can hit the boss.
-- {model, currentHealth, maxHealth, onDamaged = function(amount) end}
local activeBoss = nil

function CombatService.RegisterBoss(bossHandle)
	activeBoss = bossHandle
end

function CombatService.ClearBoss()
	activeBoss = nil
end

function CombatService.GetActiveBoss()
	return activeBoss
end

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

local function onCastSkill(player: Player, skillId: string, targetPosition: Vector3?)
	local skill = Skills[skillId]
	if not skill then
		return -- unknown skillId: silently ignore (section 15, whitelist real Data lookups)
	end

	if isOnCooldown(player.UserId, skillId, skill.cooldown) then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	if skill.range > 0 then
		if not activeBoss or not activeBoss.model.PrimaryPart then
			return
		end
		local distance = (activeBoss.model.PrimaryPart.Position - rootPart.Position).Magnitude
		if distance > skill.range then
			return -- out of range: reject, no client-tolerance loophole beyond this check
		end
	end

	markCast(player.UserId, skillId)

	if skill.damage > 0 and activeBoss then
		activeBoss.onDamaged(skill.damage)
	end
end

function CombatService.ApplyDamageToPlayer(player: Player, amount: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.Health = math.max(0, humanoid.Health - amount)
	Net.Get("HealthChanged"):FireAllClients(player.UserId, humanoid.Health, humanoid.MaxHealth)
end

function CombatService.Start()
	Net.Get("CastSkill").OnServerEvent:Connect(function(player, skillId, targetPosition)
		if type(skillId) ~= "string" then
			return
		end
		if targetPosition ~= nil and typeof(targetPosition) ~= "Vector3" then
			return
		end
		onCastSkill(player, skillId, targetPosition)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCastAt[player.UserId] = nil
	end)
end

return CombatService
