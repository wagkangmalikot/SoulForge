-- src/StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
-- Renders the player HP bar, boss HP bar, and telegraph ground indicators.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local function makeBar(name: string, position: UDim2, color: Color3): (Frame, Frame)
	local background = Instance.new("Frame")
	background.Name = name
	background.Size = UDim2.new(0, 300, 0, 24)
	background.Position = position
	background.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	background.Parent = screenGui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.Parent = background

	return background, fill
end

local _, playerHealthFill = makeBar("PlayerHealth", UDim2.new(0, 20, 1, -50), Color3.new(0.2, 0.9, 0.2))
local _, bossHealthFill   = makeBar("BossHealth",   UDim2.new(0.5, -150, 0, 20), Color3.new(0.9, 0.2, 0.2))

Net.Get("HealthChanged").OnClientEvent:Connect(function(userId, current, max)
	if userId == player.UserId then
		playerHealthFill.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0)
	end
end)

Net.Get("BossStateChanged").OnClientEvent:Connect(function(_bossId, _phaseIndex, current, max)
	bossHealthFill.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0)
end)

-- Telegraph: spawn a flat cylinder on the ground at the attack's target position
-- that vanishes once the telegraphTime expires and the hit lands.
Net.Get("TelegraphAttack").OnClientEvent:Connect(function(attackId, position, telegraphTime)
	local indicator = Instance.new("Part")
	indicator.Name = "TelegraphIndicator_" .. attackId
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(0.2, 16, 16)
	indicator.Orientation = Vector3.new(0, 0, 90)
	indicator.Position = position
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.Color = Color3.new(1, 0.6, 0)
	indicator.Transparency = 0.5
	indicator.Parent = workspace

	task.delay(telegraphTime, function()
		indicator:Destroy()
	end)
end)
