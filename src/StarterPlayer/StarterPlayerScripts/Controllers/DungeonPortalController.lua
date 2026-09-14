-- src/StarterPlayer/StarterPlayerScripts/Controllers/DungeonPortalController.lua
-- Attaches a ProximityPrompt to the "RockhidePortal" Part in Workspace (hub only).
-- On dungeon servers this Part won't exist, so the script exits early.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local DungeonPortalController = {}

function DungeonPortalController.Start()
	-- WaitForChild with a short timeout: if the part doesn't exist within 5 seconds
	-- this is a dungeon server and there is nothing for this controller to do.
	local portalPart = workspace:WaitForChild("RockhidePortal", 5)
	if not portalPart then
		-- Dungeon server (no portal placed here) — exit silently.
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter Rockhide's Dungeon"
	prompt.HoldDuration = 0.5
	prompt.Parent = portalPart

	prompt.Triggered:Connect(function()
		Net.Get("RequestEnterDungeon"):FireServer("Rockhide")
	end)
end

return DungeonPortalController
