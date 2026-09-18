-- src/ServerScriptService/Services/CombatService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RespawnService = require(script.Parent.RespawnService)
local EquipmentData = require(ReplicatedStorage.Shared.Data.Equipment)

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

local NORMAL_ATTACK_COOLDOWN = 0.55
local NORMAL_ATTACK_DAMAGE = 8
local NORMAL_ATTACK_RANGE = 20

local function getDamageMultiplier(player: Player): number
	local profile = PlayerDataService.GetProfile(player)
	local charData = profile and profile.Data.Character
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and charData and charData.EquippedEquipment then
		if EquipmentData.IsSetBonusActive("Rockhide", charData.EquippedEquipment) then
			if humanoid.Health / math.max(humanoid.MaxHealth, 1) <= 0.5 then
				return 1.15 -- +15% damage from Seismic Fury set bonus!
			end
		end
	end
	return 1.0
end

local function getPlayerNormalAttackDamage(player: Player): number
	local profile = PlayerDataService.GetProfile(player)
	local charData = profile and profile.Data.Character
	local weaponId = (charData and charData.EquippedEquipment and charData.EquippedEquipment.Weapon)
		or (charData and charData.EquippedWeapon)
		or "StandardSword"
	local weaponItem = EquipmentData.Items[weaponId]
	local baseDamage = (weaponItem and weaponItem.stats and weaponItem.stats.physicalDamage) or NORMAL_ATTACK_DAMAGE
	local mult = getDamageMultiplier(player)
	return math.floor(baseDamage * mult)
end

local function getPlayerSkillDamage(player: Player, baseDamage: number): number
	local mult = getDamageMultiplier(player)
	return math.floor(baseDamage * mult)
end

-- Schedules tickCount follow-up hits of tickDamage against enemy, interval seconds
-- apart, for dotDamage/aoeDotDamage skills. Each tick re-resolves the damage
-- multiplier at fire time (not once upfront) so a mid-DoT health-threshold change
-- (e.g. the Rockhide set bonus) is reflected correctly, matching how an instant hit
-- always computes its multiplier fresh. If the enemy is already dead/despawned by
-- the time a given tick fires, enemy.onDamaged's own "if not alive" guard (already
-- present in both MonsterAIService and BossAIService) makes that tick a safe no-op --
-- no cancellation/cleanup bookkeeping needed here.
local function applyDotTicks(enemy, player: Player, tickDamage: number, tickCount: number, interval: number)
	for i = 1, tickCount do
		task.delay(interval * i, function()
			if enemy and enemy.model and enemy.model.Parent then
				enemy.onDamaged(getPlayerSkillDamage(player, tickDamage), player)
			end
		end)
	end
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

local function onCastSkill(player: Player, skillId: string, targetId: string?)
	if RespawnService.IsPlayerDowned(player.UserId) then
		return -- downed players' Character/Humanoid stay alive during bleed-out/revive, so this must be checked explicitly
	end

	local skill = Skills[skillId]
	if not skill then
		return -- unknown skillId: silently ignore (section 15, whitelist real Data lookups)
	end

	-- Skill unlock validation: verify skill is actually unlocked in player's skill tree.
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end
	local unlocked = profile.Data.Character.UnlockedSkills or {"Taunt"}
	local isUnlocked = false
	for _, id in ipairs(unlocked) do
		if id == skillId then
			isUnlocked = true
			break
		end
	end
	if not isUnlocked then
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

	local isAoeOrSelf = (skill.effectType == "tauntAoe" or skill.effectType == "aoeDamage" or skill.effectType == "aoeDotDamage"
		or skill.effectType == "selfHeal" or skill.effectType == "buffSelf" or skill.effectType == "buffParty")
	local enemy = targetId and enemies[targetId]
	if skill.range > 0 and not isAoeOrSelf then
		if not enemy or not enemy.model.PrimaryPart then
			return
		end
		local distance = (enemy.model.PrimaryPart.Position - rootPart.Position).Magnitude
		if distance > skill.range then
			return
		end
	end

	markCast(player.UserId, skillId)
	Net.Get("WeaponAttack"):FireAllClients(player.UserId, skillId)

	if skill.effectType == "tauntAoe" then
		-- AoE Warcry: Taunts all enemies within skill.range (30 studs)
		local tauntRadius = skill.range > 0 and skill.range or 30
		for _, e in pairs(enemies) do
			if e and e.model and e.model.Parent then
				local part = e.model.PrimaryPart or e.model:FindFirstChildWhichIsA("BasePart")
				if part then
					local dist = (part.Position - rootPart.Position).Magnitude
					if dist <= tauntRadius then
						if e.onTaunted then
							e.onTaunted(player)
						end
						Net.Get("TargetTaunted"):FireAllClients(e.model)
					end
				end
			end
		end
	elseif skill.effectType == "aoeDamage" or skill.effectType == "aoeDotDamage" then
		-- AoE slam: damage all registered enemies within range, plus follow-up DoT ticks if this skill has them
		local aoeRadius = skill.range > 0 and skill.range or 16
		for _, e in pairs(enemies) do
			if e and e.model and e.model.PrimaryPart and e.model.Parent then
				local dist = (e.model.PrimaryPart.Position - rootPart.Position).Magnitude
				if dist <= aoeRadius then
					e.onDamaged(getPlayerSkillDamage(player, skill.damage), player)
					if skill.effectType == "aoeDotDamage" and skill.dotTicks then
						applyDotTicks(e, player, skill.dotTickDamage, skill.dotTicks, skill.dotInterval)
					end
				end
			end
		end
	elseif skill.effectType == "selfHeal" then
		-- Self sustain: restore health
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local heal = skill.healAmount or 40
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
			Net.Get("HealthChanged"):FireAllClients(player.UserId, humanoid.Health, humanoid.MaxHealth)
		end
	elseif skill.effectType == "damage" or skill.effectType == "dotDamage" then
		if enemy then
			if skill.tauntsOnHit and enemy.onTaunted then
				enemy.onTaunted(player)
			end
			if skill.damage > 0 then
				enemy.onDamaged(getPlayerSkillDamage(player, skill.damage), player)
			end
			if skill.effectType == "dotDamage" and skill.dotTicks then
				applyDotTicks(enemy, player, skill.dotTickDamage, skill.dotTicks, skill.dotInterval)
			end
		end
	end
	-- Any other effectType (buffSelf, buffParty) is intentionally unhandled here --
	-- GuardStance/FortressAura already did nothing when cast before this refactor;
	-- this keeps that exact (pre-existing, out of scope) behavior while making the
	-- gap explicit and labeled instead of hidden inside a name check.
end

local function onCastNormalAttack(player: Player, targetId: string?)
	if RespawnService.IsPlayerDowned(player.UserId) then
		return -- downed players' Character/Humanoid stay alive during bleed-out/revive, so this must be checked explicitly
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

	lastNormalAttackAt[player.UserId] = os.clock()
	Net.Get("WeaponAttack"):FireAllClients(player.UserId, "Slash")

	local normalDmg = getPlayerNormalAttackDamage(player)

	-- 1. Try specified target first with dynamic model size padding
	local targetEnemy = targetId and enemies[targetId]
	if targetEnemy and targetEnemy.model and targetEnemy.model.Parent then
		local part = targetEnemy.model.PrimaryPart or targetEnemy.model:FindFirstChildWhichIsA("BasePart")
		if part then
			local extents = targetEnemy.model:GetExtentsSize()
			local radius = math.max(extents.X, extents.Z) * 0.5
			local dist = (part.Position - rootPart.Position).Magnitude
			if dist <= (NORMAL_ATTACK_RANGE + radius) then
				targetEnemy.onDamaged(normalDmg, player)
				return
			end
		end
	end

	-- 2. Proximity fallback: hit closest enemy in melee reach (great for untargeted swings / mobs moving)
	local closestEnemy = nil
	local closestDist = math.huge
	for _, e in pairs(enemies) do
		if e and e.model and e.model.Parent then
			local part = e.model.PrimaryPart or e.model:FindFirstChildWhichIsA("BasePart")
			if part then
				local extents = e.model:GetExtentsSize()
				local radius = math.max(extents.X, extents.Z) * 0.5
				local dist = (part.Position - rootPart.Position).Magnitude - radius
				if dist <= NORMAL_ATTACK_RANGE and dist < closestDist then
					closestDist = dist
					closestEnemy = e
				end
			end
		end
	end

	if closestEnemy then
		closestEnemy.onDamaged(normalDmg, player)
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
		if targetId ~= nil and type(targetId) ~= "string" then
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
