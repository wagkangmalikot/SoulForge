-- src/ServerScriptService/Services/DungeonEntryService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local PartyService = require(script.Parent.PartyService)

local DungeonEntryService = {}

local function enterDungeon(player: Player, dungeonId: string)
	if dungeonId ~= "Rockhide" and dungeonId ~= "Sunforged" then
		return
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

	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then
		-- In Studio Play Solo, TeleportService:ReserveServer is blocked.
		-- Directly transition the server into the dungeon session for seamless testing:
		ReplicatedStorage:SetAttribute("IsDungeon", true)
		local DungeonSessionService = require(script.Parent.DungeonSessionService)
		local HUB_ONLY_SCENERY = {"RockhidePortal", "SunforgedPortal", "LevelUpShrine", "SpawnLocation", "SoulforgeHub"}
		for _, name in HUB_ONLY_SCENERY do
			local instance = workspace:FindFirstChild(name)
			if instance then
				instance:Destroy()
			end
		end

		local entranceTarget = (dungeonId == "Sunforged") and Vector3.new(0, 5, -1300) or Vector3.new(0, 5, -285)
		local targetCF = CFrame.new(entranceTarget)
		for _, p in players do
			if p.Character then
				p.Character:PivotTo(targetCF)
				local hrp = p.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.AssemblyAngularVelocity = Vector3.zero
				end
				Net.Get("TeleportClient"):FireClient(p, targetCF)
			end
		end

		DungeonSessionService.Start(dungeonId, memberUserIds)
		return
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

	local teleportOk, teleportErr = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, teleportOptions)
	end)
	if not teleportOk then
		warn("DungeonEntryService: TeleportAsync to dungeon failed", teleportErr)
	end
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
