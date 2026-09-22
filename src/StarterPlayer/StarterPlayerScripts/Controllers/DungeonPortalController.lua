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
	task.spawn(function()
		-- No timeout: the checks above already confirm this is a hub server, where
		-- HubMapService.BuildHub() unconditionally creates RockhidePortal, so it will
		-- always eventually exist -- a 5s cutoff here was observed to sometimes lose
		-- that race against BuildHub()'s replication, silently leaving this player
		-- with no way to ever enter the dungeon. This thread doesn't block anything
		-- else, so waiting indefinitely is safe.
		local portalPart = workspace:WaitForChild("RockhidePortal")

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter Rockhide's Dungeon"
		prompt.HoldDuration = 0.5
		-- The portal's own decorative rings/runes sit directly between the camera
		-- and this prompt's part from a normal over-the-shoulder angle, and Roblox's
		-- line-of-sight raycast doesn't exclude sibling decoration (only the
		-- character and the prompt's own parent) -- so with the default
		-- RequiresLineOfSight = true, the prompt never shows and never triggers.
		prompt.RequiresLineOfSight = false
		prompt.Parent = portalPart

		prompt.Triggered:Connect(function()
			Net.Get("RequestEnterDungeon"):FireServer("Rockhide")
		end)
	end)
end

return DungeonPortalController
