-- src/StarterPlayer/StarterPlayerScripts/Controllers/LevelUpUIController.lua
-- Attaches a ProximityPrompt to the "LevelUpShrine" Part in Workspace
-- (hub only, spec section 9a).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local LevelUpUIController = {}

-- Duplicated from LevelUpService.lua's server-authoritative formula, for
-- DISPLAY only (so the panel can show "next level costs N EXP" before the
-- player commits) -- same precedent as HUDController duplicating Skills.lua's
-- cooldown values for its own display. The server is still the only real gate.
local function expCostForLevel(level: number): number
	return level * 50
end

function LevelUpUIController.Start()
	local player = Players.LocalPlayer

	-- Hub-only: hub and dungeon servers are the SAME published place -- there
	-- is only one shared Workspace, distinguished at runtime purely by
	-- teleportData.isDungeon (mirroring Main.server.lua's own check), so
	-- LevelUpShrine existing in Workspace can't be used to tell them apart
	-- (it's saved into the one shared place, present on every server
	-- instance regardless of type) -- same fix as CharacterCreationController
	-- and DungeonPortalController.
	local teleportData = player:GetJoinData().TeleportData
	if teleportData and teleportData.isDungeon then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	local currentLevel = 1
	local currentEXP = 0

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LevelUpUI"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Sized/positioned with scale for both axes (not the plan's literal fixed
	-- pixel offsets) so the panel compresses proportionally instead of
	-- overflowing on short viewports -- same reasoning as Task 6's
	-- CharacterCreationController fix. The stakes here are lower (this panel
	-- is small, on-demand, and has its own close button -- not a mandatory
	-- blocking first screen), but scale-based sizing costs nothing extra and
	-- avoids the same class of overlap on mobile-landscape (~400-450px tall).
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 320, 0.5, 0)
	panel.Position = UDim2.new(0.5, -160, 0.2, 0)
	panel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.14)
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -20, 0.55, 0)
	infoLabel.Position = UDim2.new(0, 10, 0.06, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.new(1, 1, 1)
	infoLabel.TextWrapped = true
	infoLabel.TextScaled = true
	infoLabel.Parent = panel

	local confirmButton = Instance.new("TextButton")
	confirmButton.AnchorPoint = Vector2.new(0.5, 1)
	confirmButton.Size = UDim2.new(0, 200, 0.22, 0)
	confirmButton.Position = UDim2.new(0.5, 0, 1, -10)
	confirmButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.3)
	confirmButton.TextColor3 = Color3.new(1, 1, 1)
	confirmButton.TextScaled = true
	confirmButton.Text = "Level Up"
	confirmButton.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 24, 0, 24)
	closeButton.Position = UDim2.new(1, -30, 0, 6)
	closeButton.BackgroundColor3 = Color3.new(0.3, 0.1, 0.1)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.Parent = panel

	local function refreshLabel()
		local cost = expCostForLevel(currentLevel)
		infoLabel.Text = ("Level %d\nNext level costs %d EXP\nYou have %d EXP"):format(currentLevel, cost, currentEXP)
	end

	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(level, unspentEXP)
		currentLevel = level
		currentEXP = unspentEXP
		refreshLabel()
	end)

	-- Deliberately NOT debounced, unlike CharacterCreationController's Confirm
	-- button. That debounce exists because a single character-creation
	-- submission should never be resent while a result is pending. Here, spec
	-- 9a explicitly allows repeated level-ups in one visit ("repeatable in one
	-- visit if they have enough banked EXP for multiple levels"), so a player
	-- clicking Level Up several times in a row -- each click after the
	-- previous CharacterDataChanged update raised the displayed level/cost --
	-- is the intended, valid flow, not spam to suppress. The server is still
	-- the sole gate: a click that arrives after EXP is already spent is a
	-- silent no-op in LevelUpService, so there's no correctness risk in
	-- letting clicks fire freely.
	confirmButton.Activated:Connect(function()
		Net.Get("RequestLevelUp"):FireServer()
	end)

	closeButton.Activated:Connect(function()
		screenGui.Enabled = false
	end)

	-- Run on its own thread, same reasoning as DungeonPortalController: a
	-- delay here must not delay Main.client.lua's synchronous calls into
	-- whichever controllers run after this one.
	task.spawn(function()
		local shrine = workspace:WaitForChild("LevelUpShrine", 5)
		if not shrine then
			-- Shouldn't happen on a real hub server (the teleportData check
			-- above already excluded dungeon servers) -- guard against a
			-- still-replicating Part rather than erroring on a nil Parent below.
			warn("LevelUpUIController: LevelUpShrine not found on hub server within 5s")
			return
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Level Up"
		prompt.HoldDuration = 0.5
		prompt.Parent = shrine

		prompt.Triggered:Connect(function()
			refreshLabel()
			screenGui.Enabled = true
		end)
	end)
end

return LevelUpUIController
