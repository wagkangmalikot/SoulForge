-- src/StarterPlayer/StarterPlayerScripts/Controllers/PartyUIController.lua
-- Party panel: "Create Party" button, member list, and a tappable Accept/Decline
-- invite UI (works on mobile — no console commands needed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local PartyUIController = {}

function PartyUIController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PartyUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false -- Respects Roblox topbar safely across all screen resolutions
	screenGui.DisplayOrder = 10
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Find HUD TopLeftContainer so Party UI elements scale and position harmoniously below PlayerUnitFrame
	local hudGui = playerGui:WaitForChild("HUD", 5)
	local topLeftContainer: Instance = screenGui
	if hudGui then
		local tl = hudGui:WaitForChild("TopLeftContainer", 5)
		if tl then
			topLeftContainer = tl
		end
	end

	-- ── State tracking & Visibility Logic ──────────────────────────────────────
	local currentPartyId: number? = nil
	local currentLeaderId: number? = nil
	local currentMemberUserIds: {number} = {}

	local function hasCurrentParty(): boolean
		if currentPartyId and #currentMemberUserIds > 0 then
			local myId = player.UserId
			for _, mId in currentMemberUserIds do
				if mId == myId then
					return true
				end
			end
		end
		return false
	end

	-- ── Create Party button ────────────────────────────────────────────────────
	-- Positioned at Y = 114 (safely below PlayerUnitFrame which ends at Y = 106, with 8px margin)
	local createButton = Instance.new("TextButton")
	createButton.Name = "CreatePartyButton"
	createButton.Text = "🛡️  Create Party"
	createButton.Size = UDim2.new(0, 168, 0, 40)
	createButton.Position = UDim2.new(0, 16, 0, 114)
	createButton.Font = Enum.Font.GothamBold
	createButton.TextSize = 15
	createButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	createButton.TextStrokeColor3 = Color3.fromRGB(10, 15, 25)
	createButton.TextStrokeTransparency = 0.3
	createButton.BackgroundColor3 = Color3.fromRGB(28, 75, 170)
	createButton.BorderSizePixel = 0
	createButton.Parent = topLeftContainer

	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 7)
	cc.Parent = createButton

	local cg = Instance.new("UIGradient")
	cg.Rotation = 45
	cg.Color = ColorSequence.new(Color3.fromRGB(38, 105, 225), Color3.fromRGB(18, 52, 130))
	cg.Parent = createButton

	local cs = Instance.new("UIStroke")
	cs.Color = Color3.fromRGB(215, 175, 70)
	cs.Thickness = 1.4
	cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cs.Parent = createButton

	local createDebounce = false
	createButton.Activated:Connect(function()
		if createDebounce or hasCurrentParty() then return end
		createDebounce = true
		TweenService:Create(createButton, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 160, 0, 36)
		}):Play()
		task.delay(0.08, function()
			if createButton and createButton.Parent then
				TweenService:Create(createButton, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, 168, 0, 40)
				}):Play()
			end
		end)
		Net.Get("PartyCreate"):FireServer()
		task.delay(1, function() createDebounce = false end)
	end)

	-- ── Party status card (Active when in a party) ─────────────────────────────
	-- Positioned at Y = 114 with width 280 (matching PlayerUnitFrame width)
	local partyCard = Instance.new("Frame")
	partyCard.Name = "PartyCard"
	partyCard.Size = UDim2.new(0, 280, 0, 52)
	partyCard.Position = UDim2.new(0, 16, 0, 114)
	partyCard.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	partyCard.BackgroundTransparency = 0.15
	partyCard.BorderSizePixel = 0
	partyCard.Visible = false
	partyCard.Parent = topLeftContainer

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = partyCard

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(180, 145, 60)
	cardStroke.Thickness = 1.2
	cardStroke.Parent = partyCard

	local cardGrad = Instance.new("UIGradient")
	cardGrad.Rotation = 45
	cardGrad.Color = ColorSequence.new(Color3.fromRGB(26, 32, 46), Color3.fromRGB(14, 18, 26))
	cardGrad.Parent = partyCard

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "PartyTitle"
	titleLabel.Size = UDim2.new(1, -84, 0, 22)
	titleLabel.Position = UDim2.new(0, 10, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14.5
	titleLabel.Text = "🛡️ PARTY (1/4)"
	titleLabel.Parent = partyCard

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -84, 0, 20)
	statusLabel.Position = UDim2.new(0, 10, 0, 26)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(195, 205, 220)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.TextSize = 13.5
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Text = ""
	statusLabel.Parent = partyCard

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeavePartyButton"
	leaveBtn.Size = UDim2.new(0, 72, 0, 32)
	leaveBtn.Position = UDim2.new(1, -80, 0.5, -16)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
	leaveBtn.BorderSizePixel = 0
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.TextSize = 13.5
	leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.Text = "Leave"
	leaveBtn.Parent = partyCard

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 6)
	leaveCorner.Parent = leaveBtn

	local leaveStroke = Instance.new("UIStroke")
	leaveStroke.Color = Color3.fromRGB(220, 90, 90)
	leaveStroke.Thickness = 1
	leaveStroke.Parent = leaveBtn

	leaveBtn.Activated:Connect(function()
		Net.Get("PartyLeave"):FireServer()
	end)

	local function isInsideDungeon(): boolean
		if ReplicatedStorage:GetAttribute("IsDungeon") == true then
			return true
		end
		if workspace:FindFirstChild("RockhideArena") then
			return true
		end
		return false
	end

	local function updateUI()
		local inDungeon = isInsideDungeon()
		local inParty = hasCurrentParty()

		if inParty then
			createButton.Visible = false
			partyCard.Visible = true

			local names = {}
			for _, userId in currentMemberUserIds do
				if userId ~= player.UserId then
					local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
					table.insert(names, ok and name or tostring(userId))
				end
			end

			local isLeader = (currentLeaderId == player.UserId)
			local leaderText = isLeader and "You (Leader)" or "Member"
			if not isLeader and currentLeaderId then
				local ok, lName = pcall(Players.GetNameFromUserIdAsync, Players, currentLeaderId)
				leaderText = "Leader: " .. (ok and lName or tostring(currentLeaderId))
			end

			titleLabel.Text = ("🛡️ PARTY (%d/4) • %s"):format(#currentMemberUserIds, leaderText)
			if #names > 0 then
				statusLabel.Text = table.concat(names, ", ")
			else
				statusLabel.Text = "Solo party (waiting for members)"
			end
		else
			partyCard.Visible = false
			statusLabel.Text = ""

			if inDungeon then
				createButton.Visible = false
			else
				createButton.Visible = true
			end
		end
	end

	-- Initial state checks
	updateUI()
	task.defer(updateUI)
	task.delay(0.5, updateUI)
	task.delay(1.5, updateUI)

	ReplicatedStorage:GetAttributeChangedSignal("IsDungeon"):Connect(updateUI)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "RockhideArena" then
			task.defer(updateUI)
		end
	end)

	Net.Get("DungeonObjectiveChanged").OnClientEvent:Connect(function()
		updateUI()
	end)

	-- ── Invite modal (hidden until an invite arrives) ──────────────────────────
	-- Modal sits center-screen so it's thumb-reachable on both orientations.

	local inviteModal = Instance.new("Frame")
	inviteModal.Name = "InviteModal"
	inviteModal.Size = UDim2.new(0, 340, 0, 164)
	inviteModal.Position = UDim2.new(0.5, -170, 0.35, 0)
	inviteModal.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	inviteModal.BorderSizePixel = 0
	inviteModal.Visible = false
	inviteModal.ZIndex = 10
	inviteModal.Parent = screenGui

	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(0, 10)
	mc.Parent = inviteModal

	local mg = Instance.new("UIGradient")
	mg.Rotation = 45
	mg.Color = ColorSequence.new(Color3.fromRGB(26, 32, 44), Color3.fromRGB(14, 18, 26))
	mg.Parent = inviteModal

	local ms = Instance.new("UIStroke")
	ms.Color = Color3.fromRGB(215, 175, 75)
	ms.Thickness = 1.8
	ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ms.Parent = inviteModal

	local inviteText = Instance.new("TextLabel")
	inviteText.Name = "InviteText"
	inviteText.Size = UDim2.new(1, -24, 0, 68)
	inviteText.Position = UDim2.new(0, 12, 0, 12)
	inviteText.BackgroundTransparency = 1
	inviteText.TextColor3 = Color3.fromRGB(245, 245, 250)
	inviteText.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	inviteText.TextStrokeTransparency = 0.3
	inviteText.TextWrapped = true
	inviteText.TextSize = 16
	inviteText.Font = Enum.Font.GothamBold
	inviteText.Text = ""
	inviteText.ZIndex = 10
	inviteText.Parent = inviteModal

	-- Accept button
	local acceptBtn = Instance.new("TextButton")
	acceptBtn.Size = UDim2.new(0, 140, 0, 46)
	acceptBtn.Position = UDim2.new(0, 16, 1, -60)
	acceptBtn.Text = "✓  Accept"
	acceptBtn.Font = Enum.Font.GothamBold
	acceptBtn.TextSize = 16
	acceptBtn.TextColor3 = Color3.new(1, 1, 1)
	acceptBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 95)
	acceptBtn.BorderSizePixel = 0
	acceptBtn.ZIndex = 11
	acceptBtn.Parent = inviteModal

	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 8)
	ac.Parent = acceptBtn

	local ag = Instance.new("UIGradient")
	ag.Rotation = 45
	ag.Color = ColorSequence.new(Color3.fromRGB(50, 210, 115), Color3.fromRGB(25, 140, 70))
	ag.Parent = acceptBtn

	local as = Instance.new("UIStroke")
	as.Color = Color3.fromRGB(120, 245, 165)
	as.Thickness = 1.4
	as.Parent = acceptBtn

	-- Decline button
	local declineBtn = Instance.new("TextButton")
	declineBtn.Size = UDim2.new(0, 140, 0, 46)
	declineBtn.Position = UDim2.new(1, -156, 1, -60)
	declineBtn.Text = "✗  Decline"
	declineBtn.Font = Enum.Font.GothamBold
	declineBtn.TextSize = 16
	declineBtn.TextColor3 = Color3.new(1, 1, 1)
	declineBtn.BackgroundColor3 = Color3.fromRGB(205, 45, 45)
	declineBtn.BorderSizePixel = 0
	declineBtn.ZIndex = 11
	declineBtn.Parent = inviteModal

	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(0, 8)
	dc.Parent = declineBtn

	local dg = Instance.new("UIGradient")
	dg.Rotation = 45
	dg.Color = ColorSequence.new(Color3.fromRGB(235, 65, 65), Color3.fromRGB(150, 20, 25))
	dg.Parent = declineBtn

	local ds = Instance.new("UIStroke")
	ds.Color = Color3.fromRGB(255, 110, 110)
	ds.Thickness = 1.4
	ds.Parent = declineBtn

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

	Net.Get("PartyUpdated").OnClientEvent:Connect(function(partyId, leaderUserId, memberUserIds)
		currentPartyId = partyId
		currentLeaderId = leaderUserId
		currentMemberUserIds = memberUserIds or {}
		updateUI()
	end)

	Net.Get("PartyInvite").OnClientEvent:Connect(function(inviterUserId)
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, inviterUserId)
		local displayName = ok and name or tostring(inviterUserId)
		inviteText.Text = displayName .. " invited you to their party!"
		inviteModal.Visible = true
	end)

	-- ── Character Lifecycle and Login/PartyUI Visibility Sync ────────────────
	local function checkVisibility()
		local charCreationGui = playerGui:FindFirstChild("CharacterCreation")
		local isCreating = charCreationGui and charCreationGui:IsA("ScreenGui") and charCreationGui.Enabled
		local hasChar = player.Character and player.Character.Parent ~= nil
		screenGui.Enabled = (hasChar and not isCreating) == true
	end

	player.CharacterAdded:Connect(function()
		local charCreationGui = playerGui:FindFirstChild("CharacterCreation")
		local isCreating = charCreationGui and charCreationGui:IsA("ScreenGui") and charCreationGui.Enabled
		screenGui.Enabled = not isCreating
	end)

	player.CharacterRemoving:Connect(function()
		screenGui.Enabled = false
	end)

	checkVisibility()

	task.spawn(function()
		local charCreationGui = playerGui:WaitForChild("CharacterCreation", 5)
		if charCreationGui and charCreationGui:IsA("ScreenGui") then
			charCreationGui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if charCreationGui.Enabled then
					screenGui.Enabled = false
				else
					if player.Character and player.Character.Parent then
						screenGui.Enabled = true
					end
				end
			end)
			checkVisibility()
		end
	end)
end

return PartyUIController
