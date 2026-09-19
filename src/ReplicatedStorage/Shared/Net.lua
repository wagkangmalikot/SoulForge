-- src/ReplicatedStorage/Shared/Net.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local REMOTE_NAMES = {
	"CastSkill",              -- client -> server: {skillId, targetId}
	"CastNormalAttack",       -- client -> server: {targetId} -- always-available basic attack, no unlockLevel gate
	"TelegraphAttack",        -- server -> client: {attackId, position, telegraphTime}
	"HealthChanged",          -- server -> client: {targetUserId, currentHealth, maxHealth}
	"BossStateChanged",       -- server -> client: {bossId, phaseIndex, currentHealth, maxHealth}
	"PartyCreate",            -- client -> server
	"PartyInvite",            -- client -> server: {targetUserId}; also server -> client to notify invitee
	"PartyInviteResponse",    -- client -> server: {accepted}
	"PartyLeave",             -- client -> server
	"PartyUpdated",           -- server -> client: {partyId, leaderUserId, memberUserIds}
	"RequestEnterDungeon",    -- client -> server: {dungeonId}
	"PlayerDowned",           -- server -> client: {userId}
	"PlayerRevived",          -- server -> client: {userId}
	"RequestChannelRevive",   -- client -> server: {downedUserId}
	"CancelChannelRevive",    -- client -> server
	"ReviveProgress",         -- server -> client: {reviverUserId, downedUserId, progress}
	"DungeonResult",          -- server -> client: {result = "victory" | "wipe", expEarned, fragmentsEarned, goldEarned}
	"ShowCharacterCreation",     -- server -> client: tells this client to show the create screen (first-timer, no existing character)
	"SubmitCharacterCreation",   -- client -> server: {classId} -- name comes from player.DisplayName
	"ShowCharacterChoice",       -- server -> client: {level} -- tells this client to show the Load/Create New choice (returning player)
	"RequestLoadCharacter",      -- client -> server: no args -- spawn as the existing character
	"RequestCreateNewCharacter", -- client -> server: {classId} -- reset Character to defaults (keeping DisplayName/HasCreatedCharacter) and spawn
	"RequestLevelUp",          -- client -> server (no args)
	"CharacterDataChanged",    -- server -> client: {level, unspentEXP, classId} -- fires on spawn and after each level-up
	"WeaponAttack",            -- server -> client: {userId, attackType} -- triggers sword swing / shield bash visuals
	"RequestUnlockSkill",      -- client -> server: {skillId} -- spends 1 SkillPoint to unlock a skill in the tree
	"RequestEquipSkill",       -- client -> server: {skillId, slotIndex} -- equips an unlocked skill to slot 1-4
	"SkillDataChanged",        -- server -> client: {skillPoints, unlockedSkills, equippedSkills} -- syncs skill tree state
	"DungeonObjectiveChanged", -- server -> client: {objectiveText, currentKills, totalRequired, isUnlocked, isOpen}
	"RequestOpenBossGate",     -- client -> server: asks server to open the unlocked boss gate
	"RequestCharacterState",   -- client -> server: requests current character creation / selection state
	"TargetTaunted",          -- server -> client: {enemyModel} -- plays visual taunted feedback / billboard on target
	"BossEffect",             -- server -> client: {effectType, position, data} -- screen shake, flash, aura pulses
	"EquipmentDataChanged",   -- server -> client: {equippedWeapon, equippedShield, storedEquipment, craftingMaterials}
	"RequestEquipEquipment",  -- client -> server: {equipmentId} -- switches active weapon/shield set
	"RequestCraftItem",       -- client -> server: {setId} -- request to craft a gear set
	"CraftingResult",         -- server -> client: {success, message, storedEquipment, craftingMaterials}
	"OpenCraftingUI",         -- server -> client: triggers crafting panel (fired from ProximityPrompt)
}


local remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "NetRemotes"
	for _, remoteName in REMOTE_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = folder
		remotes[remoteName] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("NetRemotes")
	for _, remoteName in REMOTE_NAMES do
		remotes[remoteName] = folder:WaitForChild(remoteName)
	end
end

function Net.Get(remoteName: string): RemoteEvent
	local remote = remotes[remoteName]
	if not remote then
		error(("Net.Get: unknown remote %q"):format(remoteName), 2)
	end
	return remote
end

return Net
