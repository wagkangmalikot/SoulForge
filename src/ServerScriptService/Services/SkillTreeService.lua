-- src/ServerScriptService/Services/SkillTreeService.lua
-- Server authority for the Tank Skill Tree progression system:
-- Validates skill unlocks, checks prerequisites and skill points, manages equipped skill slots,
-- and replicates skill state to the client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SkillTreeService = {}

local function isDungeonActive(): boolean
	return ReplicatedStorage:GetAttribute("IsDungeon") == true
end

function SkillTreeService.SyncSkills(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local char = profile.Data.Character
	local skillPoints = char.SkillPoints or 0
	local unlocked = char.UnlockedSkills or {"Taunt"}
	local equipped = char.EquippedSkills or {"Taunt"}

	Net.Get("SkillDataChanged"):FireClient(player, skillPoints, unlocked, equipped)
end

local function hasSkill(skillList: {string}, skillId: string): boolean
	for _, id in ipairs(skillList) do
		if id == skillId then
			return true
		end
	end
	return false
end

local function onUnlockSkill(player: Player, skillId: string)
	if isDungeonActive() then
		warn(("[SkillTreeService] %s attempted to unlock skill '%s' while inside dungeon (skills locked)"):format(player.Name, tostring(skillId)))
		return
	end

	if type(skillId) ~= "string" then
		return
	end

	local skillData = Skills[skillId]
	if not skillData then
		return -- unknown skill
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local char = profile.Data.Character
	char.UnlockedSkills = char.UnlockedSkills or {"Taunt"}
	char.EquippedSkills = char.EquippedSkills or {"Taunt"}
	char.SkillPoints = char.SkillPoints or 0

	-- Check if already unlocked
	if hasSkill(char.UnlockedSkills, skillId) then
		return
	end

	-- Check available skill points
	if char.SkillPoints < 1 then
		return
	end

	-- Check prerequisite (if any)
	if skillData.prerequisite then
		if not hasSkill(char.UnlockedSkills, skillData.prerequisite) then
			return -- prerequisite not met
		end
	end

	-- Spend skill point and unlock
	char.SkillPoints -= 1
	table.insert(char.UnlockedSkills, skillId)

	-- Auto-equip to first open slot (up to 4 slots)
	if #char.EquippedSkills < 4 and not hasSkill(char.EquippedSkills, skillId) then
		table.insert(char.EquippedSkills, skillId)
	end

	SkillTreeService.SyncSkills(player)
end

local function onEquipSkill(player: Player, skillId: string, slotIndex: number)
	if isDungeonActive() then
		warn(("[SkillTreeService] %s attempted to equip skill '%s' while inside dungeon (loadout locked)"):format(player.Name, tostring(skillId)))
		return
	end

	if type(skillId) ~= "string" or type(slotIndex) ~= "number" then
		return
	end
	slotIndex = math.clamp(math.floor(slotIndex), 1, 4)

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local char = profile.Data.Character
	char.UnlockedSkills = char.UnlockedSkills or {"Taunt"}
	char.EquippedSkills = char.EquippedSkills or {"Taunt"}

	-- Validate that skill is unlocked
	if not hasSkill(char.UnlockedSkills, skillId) then
		return
	end

	-- Remove from existing slot if already equipped in another slot
	for i, id in ipairs(char.EquippedSkills) do
		if id == skillId and i ~= slotIndex then
			table.remove(char.EquippedSkills, i)
			break
		end
	end

	char.EquippedSkills[slotIndex] = skillId
	SkillTreeService.SyncSkills(player)
end

function SkillTreeService.ResetSkills(player: Player): boolean
	if isDungeonActive() then
		warn(("[SkillTreeService] %s attempted to reset/reskill while inside dungeon (reskills locked)"):format(player.Name))
		return false
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile or not profile.Data or not profile.Data.Character then
		return false
	end

	local char = profile.Data.Character
	local classId = char.ClassId or "Tank"
	local classDef = Classes[classId] or Classes.Tank
	local startingSkills = classDef.startingSkills or {"Taunt"}

	local currentUnlocked = char.UnlockedSkills or startingSkills
	local refundedPoints = 0

	for _, skillId in ipairs(currentUnlocked) do
		local isStarting = false
		for _, sId in ipairs(startingSkills) do
			if sId == skillId then
				isStarting = true
				break
			end
		end
		if not isStarting then
			refundedPoints += 1
		end
	end

	char.SkillPoints = (char.SkillPoints or 0) + refundedPoints
	char.UnlockedSkills = table.clone(startingSkills)
	char.EquippedSkills = table.clone(startingSkills)

	SkillTreeService.SyncSkills(player)
	return true
end

function SkillTreeService.Start()
	Net.Get("RequestUnlockSkill").OnServerEvent:Connect(onUnlockSkill)
	Net.Get("RequestEquipSkill").OnServerEvent:Connect(onEquipSkill)
	Net.Get("RequestResetSkills").OnServerEvent:Connect(SkillTreeService.ResetSkills)

	-- Sync skills whenever a player's character is loaded/spawned
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local profile = PlayerDataService.WaitForProfile(player)
			if profile then
				SkillTreeService.SyncSkills(player)
			end
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			SkillTreeService.SyncSkills(player)
		end)
	end
end

return SkillTreeService
