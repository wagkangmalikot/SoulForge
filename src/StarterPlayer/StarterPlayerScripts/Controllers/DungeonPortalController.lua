-- src/StarterPlayer/StarterPlayerScripts/Controllers/DungeonPortalController.lua
-- Attaches a ProximityPrompt to the "RockhidePortal" Part in Workspace (hub only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local DungeonPortalController = {}

function DungeonPortalController.Start()
	local player = Players.LocalPlayer

	-- Hub-only: hub and dungeon servers are the SAME published place --
	-- there is only one shared Workspace, distinguished at runtime purely by
	-- teleportData.isDungeon (mirroring Main.server.lua's own check), so
	-- RockhidePortal existing in Workspace can't be used to tell them apart
	-- (it's saved into the one shared place, present on every server
	-- instance regardless of type). Checking teleportData first means this
	-- never even attempts the portal lookup on a dungeon server.
	local teleportData = player:GetJoinData().TeleportData
	if teleportData and teleportData.isDungeon then
		return
	end

	-- Run the (possibly blocking) portal lookup on its own thread so that a
	-- delay here doesn't delay Main.client.lua's synchronous calls into the
	-- controllers that run after this one.
	task.spawn(function()
		local portalPart = workspace:WaitForChild("RockhidePortal", 5)
		if not portalPart then
			-- Shouldn't happen on a real hub server, but guard against a
			-- still-replicating Part rather than erroring on a nil Parent below.
			warn("DungeonPortalController: RockhidePortal not found on hub server within 5s")
			return
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter Rockhide's Dungeon"
		prompt.HoldDuration = 0.5
		prompt.Parent = portalPart

		prompt.Triggered:Connect(function()
			Net.Get("RequestEnterDungeon"):FireServer("Rockhide")
		end)
	end)
end

return DungeonPortalController
