-- src/StarterPlayer/StarterPlayerScripts/Controllers/DownedUIController.lua
-- Shows a "DOWNED" overlay when this player is downed, a revive-progress bar
-- for any player being revived, and the dungeon result (victory / wipe) screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local DownedUIController = {}

function DownedUIController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DownedUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- "DOWNED" label shown to the local player when they go down.
	local downedLabel = Instance.new("TextLabel")
	downedLabel.Size = UDim2.new(0, 420, 0, 50)
	downedLabel.Position = UDim2.new(0.5, -210, 0.3, 0)
	downedLabel.BackgroundTransparency = 1
	downedLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
	downedLabel.TextScaled = true
	downedLabel.Visible = false
	downedLabel.Parent = screenGui

	-- Revive-progress bar: shows globally for all players so everyone can see who
	-- is being revived and how close they are.
	local reviveBarBackground = Instance.new("Frame")
	reviveBarBackground.Name = "ReviveBar"
	reviveBarBackground.Size = UDim2.new(0, 300, 0, 20)
	reviveBarBackground.Position = UDim2.new(0.5, -150, 0.4, 0)
	reviveBarBackground.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	reviveBarBackground.Visible = false
	reviveBarBackground.Parent = screenGui

	local reviveBarFill = Instance.new("Frame")
	reviveBarFill.Name = "Fill"
	reviveBarFill.Size = UDim2.new(0, 0, 1, 0)
	reviveBarFill.BackgroundColor3 = Color3.new(0.3, 0.8, 1)
	reviveBarFill.Parent = reviveBarBackground

	local reviveLabel = Instance.new("TextLabel")
	reviveLabel.Size = UDim2.new(1, 0, 1, 0)
	reviveLabel.BackgroundTransparency = 1
	reviveLabel.TextColor3 = Color3.new(1, 1, 1)
	reviveLabel.TextScaled = true
	reviveLabel.Text = ""
	reviveLabel.Parent = reviveBarBackground

	-- Victory / wipe result overlay (reuses the downedLabel slot for simplicity).
	local resultLabel = Instance.new("TextLabel")
	resultLabel.Size = UDim2.new(0, 500, 0, 60)
	resultLabel.Position = UDim2.new(0.5, -250, 0.45, 0)
	resultLabel.BackgroundTransparency = 1
	resultLabel.TextColor3 = Color3.new(1, 1, 0.4)
	resultLabel.TextScaled = true
	resultLabel.Visible = false
	resultLabel.Parent = screenGui

	-- ── Event wiring ───────────────────────────────────────────────────────────

	Net.Get("PlayerDowned").OnClientEvent:Connect(function(userId)
		if userId == player.UserId then
			downedLabel.Text = "DOWNED — wait for a revive or bleed out"
			downedLabel.Visible = true
		end
	end)

	Net.Get("PlayerRevived").OnClientEvent:Connect(function(userId)
		if userId == player.UserId then
			downedLabel.Visible = false
		end
		-- Clear the revive bar once the channel finishes.
		reviveBarBackground.Visible = false
	end)

	Net.Get("ReviveProgress").OnClientEvent:Connect(function(reviverUserId, downedUserId, progress)
		if progress <= 0 then
			reviveBarBackground.Visible = false
			return
		end

		-- Show progress for every pair of (reviver, downed) regardless of who the
		-- local player is — this lets everyone track ongoing revives.
		local reviverName: string
		local downedName: string
		do
			local ok1, n1 = pcall(Players.GetNameFromUserIdAsync, Players, reviverUserId)
			reviverName = ok1 and n1 or tostring(reviverUserId)
			local ok2, n2 = pcall(Players.GetNameFromUserIdAsync, Players, downedUserId)
			downedName = ok2 and n2 or tostring(downedUserId)
		end

		reviveBarFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
		reviveLabel.Text = ("%s reviving %s"):format(reviverName, downedName)
		reviveBarBackground.Visible = true
	end)

	Net.Get("DungeonResult").OnClientEvent:Connect(function(result, expEarned)
		-- Hide downed overlay if it was showing when the session ended.
		downedLabel.Visible = false
		reviveBarBackground.Visible = false

		resultLabel.Text = result == "victory"
			and ("VICTORY! +" .. expEarned .. " EXP — returning to hub…")
			or "WIPED — returning to hub…"
		resultLabel.Visible = true
	end)
end

return DownedUIController
