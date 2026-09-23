-- src/StarterPlayer/StarterPlayerScripts/Controllers/DungeonPortalController.lua
-- Attaches a ProximityPrompt to the "RockhidePortal" Part in Workspace (hub only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)

local DungeonPortalController = {}

function DungeonPortalController.Start()
	-- Hub-only: hub and dungeon servers are the SAME published place --
	-- there is only one shared Workspace, distinguished at runtime purely by
	-- teleportData.isDungeon (mirroring Main.server.lua's own check), so
	-- RockhidePortal existing in Workspace can't be used to tell them apart
	-- (it's saved into the one shared place, present on every server
	-- instance regardless of type). Checking teleportData first means this
	-- never even attempts the portal lookup on a dungeon server.
	-- TeleportService:GetLocalPlayerTeleportData(), not
	-- Player:GetJoinData().TeleportData -- the latter's TeleportData can be
	-- withheld client-side for security reasons, which silently broke this
	-- exact check elsewhere in this project.
	if ReplicatedStorage:GetAttribute("IsDungeon") == true then
		return
	end
	local teleportData = TeleportService:GetLocalPlayerTeleportData()
	if teleportData and teleportData.isDungeon then
		return
	end

	-- Run the (possibly blocking) portal lookup on its own thread so that a
	-- delay here doesn't delay Main.client.lua's synchronous calls into the
	-- controllers that run after this one.
	-- Connect Rockhide Portal (Tier 1)
	task.spawn(function()
		local portalPart = workspace:WaitForChild("RockhidePortal")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter Rockhide's Dungeon (Tier 1)"
		prompt.ObjectText = "Dungeon Portal"
		prompt.HoldDuration = 0.5
		prompt.RequiresLineOfSight = false
		prompt.Parent = portalPart

		prompt.Triggered:Connect(function()
			Net.Get("RequestEnterDungeon"):FireServer("Rockhide")
		end)
	end)

	-- Connect Sunforged Citadel Portal (Tier 2)
	task.spawn(function()
		local sunPortalPart = workspace:WaitForChild("SunforgedPortal")
		local sunPrompt = Instance.new("ProximityPrompt")
		sunPrompt.ActionText = "Enter Sunforged Citadel (Tier 2)"
		sunPrompt.ObjectText = "Solar Portal"
		sunPrompt.HoldDuration = 0.5
		sunPrompt.RequiresLineOfSight = false
		sunPrompt.Parent = sunPortalPart

		sunPrompt.Triggered:Connect(function()
			Net.Get("RequestEnterDungeon"):FireServer("Sunforged")
		end)
	end)
end


return DungeonPortalController
