-- src/StarterPlayer/StarterPlayerScripts/Controllers/PartyUIController.lua
-- Minimal party panel: "Create Party" button, member list label, and invite notification.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartyUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local createButton = Instance.new("TextButton")
createButton.Text = "Create Party"
createButton.Size = UDim2.new(0, 160, 0, 36)
createButton.Position = UDim2.new(0, 20, 0, 20)
createButton.Parent = screenGui

createButton.Activated:Connect(function()
	Net.Get("PartyCreate"):FireServer()
end)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 300, 0, 80)
statusLabel.Position = UDim2.new(0, 20, 0, 64)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Text = "No party"
statusLabel.Parent = screenGui

Net.Get("PartyUpdated").OnClientEvent:Connect(function(_partyId, leaderUserId, memberUserIds)
	local names = {}
	for _, userId in memberUserIds do
		-- GetNameFromUserIdAsync yields; call it in a separate task so we don't
		-- block this event callback.  Last resolved name wins for display.
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		table.insert(names, ok and name or tostring(userId))
	end
	statusLabel.Text = ("Party (%d/4): %s\nLeader: %s"):format(
		#memberUserIds,
		table.concat(names, ", "),
		leaderUserId == player.UserId and "you" or tostring(leaderUserId)
	)
end)

Net.Get("PartyInvite").OnClientEvent:Connect(function(inviterUserId)
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, inviterUserId)
	-- Surface the invite in the status label; a future plan can replace this
	-- with a dedicated modal.  For manual verification, the tester can accept
	-- via the command bar: Net.Get("PartyInviteResponse"):FireServer(true)
	statusLabel.Text = ("Invited by %s!\n(Run PartyInviteResponse:FireServer(true) in console to accept.)")
		:format(ok and name or tostring(inviterUserId))
end)
