-- src/ReplicatedStorage/Shared/Net.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local REMOTE_NAMES = {
	"CastSkill",              -- client -> server: {skillId, targetPosition}
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
	"DungeonResult",          -- server -> client: {result = "victory" | "wipe", expEarned}
	"ShowCharacterCreation",     -- server -> client: tells this client to show the create screen (first-timer, no existing character)
	"SubmitCharacterCreation",   -- client -> server: no args -- name comes from player.DisplayName, class is always Tank
	"ShowCharacterChoice",       -- server -> client: {level} -- tells this client to show the Load/Create New choice (returning player)
	"RequestLoadCharacter",      -- client -> server: no args -- spawn as the existing character
	"RequestCreateNewCharacter", -- client -> server: no args -- reset Character to defaults (keeping DisplayName/HasCreatedCharacter) and spawn
	"RequestLevelUp",          -- client -> server (no args)
	"CharacterDataChanged",    -- server -> client: {level, unspentEXP} -- fires on spawn and after each level-up
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
