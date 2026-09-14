-- src/ServerScriptService/Services/DungeonEntryService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local PartyService = require(script.Parent.PartyService)

local DungeonEntryService = {}

local function enterDungeon(player: Player, dungeonId: string)
	if dungeonId ~= "Rockhide" then
		return -- only Rockhide's dungeon exists in this slice
	end

	local party = PartyService.GetParty(player)
	local memberUserIds = party and party.members or {player.UserId}
	local leaderUserId = party and party.leader or player.UserId

	if leaderUserId ~= player.UserId then
		return -- only the party leader triggers dungeon entry (spec section 4)
	end

	local players = {}
	for _, userId in memberUserIds do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			table.insert(players, member)
		end
	end

	local ok, reservedCode = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok then
		warn("DungeonEntryService: ReserveServer failed", reservedCode)
		return
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ReservedServerAccessCode = reservedCode
	teleportOptions:SetTeleportData({
		isDungeon = true,
		dungeonId = dungeonId,
		partyMemberUserIds = memberUserIds,
	})

	TeleportService:TeleportAsync(game.PlaceId, players, teleportOptions)
end

function DungeonEntryService.Start()
	Net.Get("RequestEnterDungeon").OnServerEvent:Connect(function(player, dungeonId)
		if type(dungeonId) ~= "string" then
			return
		end
		enterDungeon(player, dungeonId)
	end)
end

return DungeonEntryService
