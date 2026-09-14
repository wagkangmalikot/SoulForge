-- src/ServerScriptService/Services/PartyService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local PartyService = {}

local MAX_PARTY_SIZE = 4

-- partyId -> {leader = userId, members = {userId, ...}}
local parties = {}
-- userId -> partyId
local partyOf = {}
local nextPartyId = 1

-- inviteeUserId -> partyId (pending invite)
local pendingInvites = {}

local function broadcastPartyUpdate(partyId: number)
	local party = parties[partyId]
	if not party then
		return
	end
	for _, memberId in party.members do
		local player = Players:GetPlayerByUserId(memberId)
		if player then
			Net.Get("PartyUpdated"):FireClient(player, partyId, party.leader, party.members)
		end
	end
end

local function createParty(leader: Player)
	if partyOf[leader.UserId] then
		return
	end
	local partyId = nextPartyId
	nextPartyId += 1
	parties[partyId] = { leader = leader.UserId, members = {leader.UserId} }
	partyOf[leader.UserId] = partyId
	broadcastPartyUpdate(partyId)
end

local function invite(inviter: Player, targetUserId: number)
	local partyId = partyOf[inviter.UserId]
	if not partyId or parties[partyId].leader ~= inviter.UserId then
		return -- only the leader invites
	end
	if #parties[partyId].members >= MAX_PARTY_SIZE then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or partyOf[targetUserId] then
		return
	end
	pendingInvites[targetUserId] = partyId
	Net.Get("PartyInvite"):FireClient(target, inviter.UserId)
end

local function respondToInvite(invitee: Player, accepted: boolean)
	local partyId = pendingInvites[invitee.UserId]
	pendingInvites[invitee.UserId] = nil
	if not partyId or not accepted then
		return
	end
	if partyOf[invitee.UserId] then
		return -- invitee already joined/created a different party since this invite was sent
	end
	local party = parties[partyId]
	if not party or #party.members >= MAX_PARTY_SIZE then
		return
	end
	table.insert(party.members, invitee.UserId)
	partyOf[invitee.UserId] = partyId
	broadcastPartyUpdate(partyId)
end

local function leaveParty(player: Player)
	local partyId = partyOf[player.UserId]
	if not partyId then
		return
	end
	local party = parties[partyId]
	partyOf[player.UserId] = nil

	for i, memberId in party.members do
		if memberId == player.UserId then
			table.remove(party.members, i)
			break
		end
	end

	if #party.members == 0 then
		parties[partyId] = nil
		return
	end

	if party.leader == player.UserId then
		party.leader = party.members[1] -- leadership migrates to the next member (section 3)
	end

	broadcastPartyUpdate(partyId)
end

function PartyService.GetParty(player: Player)
	local partyId = partyOf[player.UserId]
	return partyId and parties[partyId]
end

function PartyService.Start()
	Net.Get("PartyCreate").OnServerEvent:Connect(function(player)
		createParty(player)
	end)

	Net.Get("PartyInvite").OnServerEvent:Connect(function(player, targetUserId)
		if typeof(targetUserId) ~= "number" then
			return
		end
		invite(player, targetUserId)
	end)

	Net.Get("PartyInviteResponse").OnServerEvent:Connect(function(player, accepted)
		respondToInvite(player, accepted == true)
	end)

	Net.Get("PartyLeave").OnServerEvent:Connect(function(player)
		leaveParty(player)
	end)

	Players.PlayerRemoving:Connect(leaveParty)
end

return PartyService
