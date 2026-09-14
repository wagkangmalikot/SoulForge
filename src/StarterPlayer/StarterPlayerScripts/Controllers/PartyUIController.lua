-- src/StarterPlayer/StarterPlayerScripts/Controllers/PartyUIController.lua
-- Party panel: "Create Party" button, member list, and a tappable Accept/Decline
-- invite UI (works on mobile — no console commands needed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartyUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ── Create Party button ────────────────────────────────────────────────────

local createButton = Instance.new("TextButton")
createButton.Text = "Create Party"
createButton.Size = UDim2.new(0, 160, 0, 44)
createButton.Position = UDim2.new(0, 16, 0, 56)  -- below the safe-area notch
createButton.Font = Enum.Font.GothamBold
createButton.TextSize = 16
createButton.TextColor3 = Color3.new(1, 1, 1)
createButton.BackgroundColor3 = Color3.new(0.18, 0.45, 0.85)
createButton.Parent = screenGui

local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 8)
cc.Parent = createButton

createButton.Activated:Connect(function()
	Net.Get("PartyCreate"):FireServer()
end)

-- ── Party status label ─────────────────────────────────────────────────────

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(0, 260, 0, 80)
statusLabel.Position = UDim2.new(0, 16, 0, 108)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.TextSize = 15
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "No party"
statusLabel.Parent = screenGui

-- ── Invite modal (hidden until an invite arrives) ──────────────────────────
-- Modal sits center-screen so it's thumb-reachable on both orientations.

local inviteModal = Instance.new("Frame")
inviteModal.Name = "InviteModal"
inviteModal.Size = UDim2.new(0, 320, 0, 160)
inviteModal.Position = UDim2.new(0.5, -160, 0.35, 0)
inviteModal.BackgroundColor3 = Color3.new(0.12, 0.12, 0.16)
inviteModal.Visible = false
inviteModal.ZIndex = 10
inviteModal.Parent = screenGui

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 12)
mc.Parent = inviteModal

local inviteText = Instance.new("TextLabel")
inviteText.Name = "InviteText"
inviteText.Size = UDim2.new(1, -24, 0, 70)
inviteText.Position = UDim2.new(0, 12, 0, 12)
inviteText.BackgroundTransparency = 1
inviteText.TextColor3 = Color3.new(1, 1, 1)
inviteText.TextWrapped = true
inviteText.TextSize = 17
inviteText.Font = Enum.Font.Gotham
inviteText.Text = ""
inviteText.ZIndex = 10
inviteText.Parent = inviteModal

-- Accept button
local acceptBtn = Instance.new("TextButton")
acceptBtn.Size = UDim2.new(0, 130, 0, 48)
acceptBtn.Position = UDim2.new(0, 12, 1, -60)
acceptBtn.Text = "✓  Accept"
acceptBtn.Font = Enum.Font.GothamBold
acceptBtn.TextSize = 18
acceptBtn.TextColor3 = Color3.new(1, 1, 1)
acceptBtn.BackgroundColor3 = Color3.new(0.18, 0.72, 0.32)
acceptBtn.ZIndex = 11
acceptBtn.Parent = inviteModal

local ac = Instance.new("UICorner")
ac.CornerRadius = UDim.new(0, 8)
ac.Parent = acceptBtn

-- Decline button
local declineBtn = Instance.new("TextButton")
declineBtn.Size = UDim2.new(0, 130, 0, 48)
declineBtn.Position = UDim2.new(1, -142, 1, -60)
declineBtn.Text = "✗  Decline"
declineBtn.Font = Enum.Font.GothamBold
declineBtn.TextSize = 18
declineBtn.TextColor3 = Color3.new(1, 1, 1)
declineBtn.BackgroundColor3 = Color3.new(0.75, 0.18, 0.18)
declineBtn.ZIndex = 11
declineBtn.Parent = inviteModal

local dc = Instance.new("UICorner")
dc.CornerRadius = UDim.new(0, 8)
dc.Parent = declineBtn

local function dismissModal()
	inviteModal.Visible = false
	inviteText.Text = ""
end

acceptBtn.Activated:Connect(function()
	Net.Get("PartyInviteResponse"):FireServer(true)
	dismissModal()
end)

declineBtn.Activated:Connect(function()
	Net.Get("PartyInviteResponse"):FireServer(false)
	dismissModal()
end)

-- ── Event wiring ───────────────────────────────────────────────────────────

Net.Get("PartyUpdated").OnClientEvent:Connect(function(_partyId, leaderUserId, memberUserIds)
	-- Resolve display names (yields, but that's fine — we're in an event callback
	-- on the client, not blocking any server path).
	local names = {}
	for _, userId in memberUserIds do
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
	local displayName = ok and name or tostring(inviterUserId)
	inviteText.Text = displayName .. " invited you to their party!"
	inviteModal.Visible = true
end)
