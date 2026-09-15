-- src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
-- Hub-only pre-spawn UI (spec section 2b): every joiner sees an intro title
-- card first, then either the first-timer creation screen or the returning-
-- player Load/Create New choice, depending on what the server decides via
-- ShowCharacterCreation / ShowCharacterChoice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local CharacterCreationController = {}

function CharacterCreationController.Start()
	-- IMPORTANT: everything in this synchronous section -- building the
	-- ScreenGui, wiring every button, and connecting the
	-- ShowCharacterCreation / ShowCharacterChoice / CharacterAdded listeners
	-- -- must run with zero yields, before the task.spawn below. Roblox
	-- RemoteEvents do not buffer a fire that happens before a listener
	-- connects; the server's handlePlayer always yields at least once (on
	-- PlayerDataService.WaitForProfile) before firing ShowCharacterCreation/
	-- ShowCharacterChoice, but there's no guarantee that yield outlasts the
	-- workspace:WaitForChild hub-detection check below, which can itself
	-- genuinely yield if RockhidePortal hasn't replicated yet. If the
	-- server's fire happened to land while this client were still inside
	-- that WaitForChild, connecting the listener afterward would silently
	-- drop it, leaving the player stuck on a permanently blank screen. By
	-- connecting these listeners first, before any yield anywhere in this
	-- script, a server-fired event can never be missed.
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterCreation"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false -- flipped true only once hub-detection (below) confirms this isn't a dungeon server
	screenGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0.05, 0.05, 0.08)
	background.BorderSizePixel = 0
	background.Parent = screenGui

	-- ── Intro title card ─────────────────────────────────────────────────
	local introFrame = Instance.new("Frame")
	introFrame.Size = UDim2.new(1, 0, 1, 0)
	introFrame.BackgroundTransparency = 1
	introFrame.Parent = background

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0, 600, 0.14, 0)
	titleLabel.Position = UDim2.new(0.5, -300, 0.38, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "SOULFORGE"
	titleLabel.TextTransparency = 1
	titleLabel.Parent = introFrame

	local pressPrompt = Instance.new("TextLabel")
	pressPrompt.Size = UDim2.new(0, 400, 0.06, 0)
	pressPrompt.Position = UDim2.new(0.5, -200, 0.55, 0)
	pressPrompt.BackgroundTransparency = 1
	pressPrompt.TextColor3 = Color3.new(1, 1, 1)
	pressPrompt.TextTransparency = 1
	pressPrompt.TextScaled = true
	pressPrompt.Font = Enum.Font.Gotham
	pressPrompt.Text = "Press anything to continue"
	pressPrompt.Parent = introFrame

	-- ── Create screen (first-timer) ────────────────────────────────────
	local createFrame = Instance.new("Frame")
	createFrame.Size = UDim2.new(1, 0, 1, 0)
	createFrame.BackgroundTransparency = 1
	createFrame.Visible = false
	createFrame.Parent = background

	local createTitle = Instance.new("TextLabel")
	createTitle.Size = UDim2.new(0, 500, 0.10, 0)
	createTitle.Position = UDim2.new(0.5, -250, 0.08, 0)
	createTitle.BackgroundTransparency = 1
	createTitle.TextColor3 = Color3.new(1, 1, 1)
	createTitle.TextScaled = true
	createTitle.Font = Enum.Font.GothamBold
	createTitle.Text = "Create Your Character"
	createTitle.Parent = createFrame

	-- Tank class card -- the only selectable option for this slice (spec 2a/2b).
	local classCard = Instance.new("Frame")
	classCard.Size = UDim2.new(0, 200, 0.34, 0)
	classCard.Position = UDim2.new(0.5, -100, 0.22, 0)
	classCard.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
	classCard.Parent = createFrame

	local classCorner = Instance.new("UICorner")
	classCorner.CornerRadius = UDim.new(0, 10)
	classCorner.Parent = classCard

	local classLabel = Instance.new("TextLabel")
	classLabel.Size = UDim2.new(1, 0, 0.18, 0)
	classLabel.Position = UDim2.new(0, 0, 0.04, 0)
	classLabel.BackgroundTransparency = 1
	classLabel.TextColor3 = Color3.new(1, 1, 1)
	classLabel.TextScaled = true
	classLabel.Font = Enum.Font.GothamBold
	classLabel.Text = "Tank"
	classLabel.Parent = classCard

	local classDesc = Instance.new("TextLabel")
	classDesc.Size = UDim2.new(1, -20, 0.70, 0)
	classDesc.Position = UDim2.new(0, 10, 0.26, 0)
	classDesc.BackgroundTransparency = 1
	classDesc.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	classDesc.TextWrapped = true
	classDesc.TextScaled = true
	classDesc.Text = "Frontline, holds threat. Starts knowing Taunt."
	classDesc.Parent = classCard

	local playingAsLabel = Instance.new("TextLabel")
	playingAsLabel.Size = UDim2.new(0, 400, 0.05, 0)
	playingAsLabel.Position = UDim2.new(0.5, -200, 0.60, 0)
	playingAsLabel.BackgroundTransparency = 1
	playingAsLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	playingAsLabel.TextScaled = true
	playingAsLabel.Text = ("Playing as %s"):format(player.DisplayName)
	playingAsLabel.Parent = createFrame

	local beginButton = Instance.new("TextButton")
	beginButton.Size = UDim2.new(0, 200, 0.09, 0)
	beginButton.Position = UDim2.new(0.5, -100, 0.70, 0)
	beginButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.3)
	beginButton.TextColor3 = Color3.new(1, 1, 1)
	beginButton.TextScaled = true
	beginButton.Text = "Begin"
	beginButton.Parent = createFrame

	beginButton.Activated:Connect(function()
		-- Debounced purely to prevent a double-fire racing LoadCharacter()
		-- on the server -- there's no validation left that can reject
		-- this (name/class are no longer player input), so there's no
		-- failure path to re-enable it for.
		beginButton.Active = false
		beginButton.AutoButtonColor = false
		beginButton.BackgroundColor3 = Color3.new(0.15, 0.35, 0.2)
		Net.Get("SubmitCharacterCreation"):FireServer()
	end)

	-- ── Choice screen (returning player) ───────────────────────────────
	local choiceFrame = Instance.new("Frame")
	choiceFrame.Size = UDim2.new(1, 0, 1, 0)
	choiceFrame.BackgroundTransparency = 1
	choiceFrame.Visible = false
	choiceFrame.Parent = background

	local welcomeLabel = Instance.new("TextLabel")
	welcomeLabel.Size = UDim2.new(0, 500, 0.08, 0)
	welcomeLabel.Position = UDim2.new(0.5, -250, 0.32, 0)
	welcomeLabel.BackgroundTransparency = 1
	welcomeLabel.TextColor3 = Color3.new(1, 1, 1)
	welcomeLabel.TextScaled = true
	welcomeLabel.Font = Enum.Font.GothamBold
	welcomeLabel.Text = ("Welcome back, %s"):format(player.DisplayName)
	welcomeLabel.Parent = choiceFrame

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(0, 400, 0.05, 0)
	levelLabel.Position = UDim2.new(0.5, -200, 0.40, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	levelLabel.TextScaled = true
	levelLabel.Text = ""
	levelLabel.Parent = choiceFrame

	local continueButton = Instance.new("TextButton")
	continueButton.Size = UDim2.new(0, 200, 0.09, 0)
	continueButton.Position = UDim2.new(0.5, -220, 0.52, 0)
	continueButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.3)
	continueButton.TextColor3 = Color3.new(1, 1, 1)
	continueButton.TextScaled = true
	continueButton.Text = "Continue"
	continueButton.Parent = choiceFrame

	local createNewButton = Instance.new("TextButton")
	createNewButton.Size = UDim2.new(0, 200, 0.09, 0)
	createNewButton.Position = UDim2.new(0.5, 20, 0.52, 0)
	createNewButton.BackgroundColor3 = Color3.new(0.6, 0.25, 0.25)
	createNewButton.TextColor3 = Color3.new(1, 1, 1)
	createNewButton.TextScaled = true
	createNewButton.Text = "Create New"
	createNewButton.Parent = choiceFrame

	continueButton.Activated:Connect(function()
		continueButton.Active = false
		createNewButton.Active = false
		continueButton.AutoButtonColor = false
		continueButton.BackgroundColor3 = Color3.new(0.15, 0.35, 0.2)
		createNewButton.AutoButtonColor = false
		createNewButton.BackgroundColor3 = Color3.new(0.4, 0.15, 0.15)
		Net.Get("RequestLoadCharacter"):FireServer()
	end)

	-- ── Overwrite confirmation (reachable only from Create New) ────────
	local confirmFrame = Instance.new("Frame")
	confirmFrame.Size = UDim2.new(1, 0, 1, 0)
	confirmFrame.BackgroundTransparency = 1
	confirmFrame.Visible = false
	confirmFrame.Parent = background

	local warningLabel = Instance.new("TextLabel")
	warningLabel.Size = UDim2.new(0, 500, 0.14, 0)
	warningLabel.Position = UDim2.new(0.5, -250, 0.34, 0)
	warningLabel.BackgroundTransparency = 1
	warningLabel.TextColor3 = Color3.new(1, 0.5, 0.5)
	warningLabel.TextWrapped = true
	warningLabel.TextScaled = true
	warningLabel.Font = Enum.Font.GothamBold
	warningLabel.Text = ""
	warningLabel.Parent = confirmFrame

	local cancelButton = Instance.new("TextButton")
	cancelButton.Size = UDim2.new(0, 200, 0.09, 0)
	cancelButton.Position = UDim2.new(0.5, -220, 0.54, 0)
	cancelButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
	cancelButton.TextColor3 = Color3.new(1, 1, 1)
	cancelButton.TextScaled = true
	cancelButton.Text = "Cancel"
	cancelButton.Parent = confirmFrame

	local deleteButton = Instance.new("TextButton")
	deleteButton.Size = UDim2.new(0, 220, 0.09, 0)
	deleteButton.Position = UDim2.new(0.5, 20, 0.54, 0)
	deleteButton.BackgroundColor3 = Color3.new(0.6, 0.25, 0.25)
	deleteButton.TextColor3 = Color3.new(1, 1, 1)
	deleteButton.TextScaled = true
	deleteButton.Text = "Delete & Start Over"
	deleteButton.Parent = confirmFrame

	local pendingLevel = 1 -- set from ShowCharacterChoice before the choice screen can show

	createNewButton.Activated:Connect(function()
		warningLabel.Text = ("This will permanently delete your Level %d Tank and all progress."):format(pendingLevel)
		choiceFrame.Visible = false
		confirmFrame.Visible = true
	end)

	cancelButton.Activated:Connect(function()
		confirmFrame.Visible = false
		choiceFrame.Visible = true
	end)

	deleteButton.Activated:Connect(function()
		-- Debounced the same way beginButton/continueButton are: prevents
		-- a double-fire racing LoadCharacter() on the server.
		cancelButton.Active = false
		deleteButton.Active = false
		cancelButton.AutoButtonColor = false
		deleteButton.AutoButtonColor = false
		cancelButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
		deleteButton.BackgroundColor3 = Color3.new(0.4, 0.15, 0.15)
		Net.Get("RequestCreateNewCharacter"):FireServer()
	end)

	-- ── Loading state (intro dismissed before the server has decided) ──
	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Size = UDim2.new(0, 300, 0.06, 0)
	loadingLabel.Position = UDim2.new(0.5, -150, 0.46, 0)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	loadingLabel.TextScaled = true
	loadingLabel.Text = "Loading..."
	loadingLabel.Visible = false
	loadingLabel.Parent = background

	-- ── State machine tying intro dismissal to whichever screen the
	-- server decided on. The server's profile load can easily take longer
	-- than it takes a player to press a key, so these two events -- intro
	-- dismissal and the server's decision -- can arrive in either order;
	-- whichever is second is what actually shows the next screen.
	local introDismissed = false
	local pendingScreen = nil -- "creation" | "choice"

	local function showPendingScreen()
		if not introDismissed or not pendingScreen then
			return
		end
		loadingLabel.Visible = false
		if pendingScreen == "creation" then
			createFrame.Visible = true
		elseif pendingScreen == "choice" then
			levelLabel.Text = ("Level %d Tank"):format(pendingLevel)
			choiceFrame.Visible = true
		end
	end

	local inputConnection
	local function dismissIntro()
		if introDismissed then
			return
		end
		introDismissed = true
		if inputConnection then
			inputConnection:Disconnect()
		end
		introFrame.Visible = false
		if pendingScreen then
			showPendingScreen()
		else
			loadingLabel.Visible = true
		end
	end

	-- These three connections are the whole point of the synchronous
	-- section above: they must be live before workspace:WaitForChild
	-- (below) gets a chance to yield, or a server fire during that yield
	-- would be silently dropped.
	Net.Get("ShowCharacterCreation").OnClientEvent:Connect(function()
		pendingScreen = "creation"
		showPendingScreen()
	end)

	Net.Get("ShowCharacterChoice").OnClientEvent:Connect(function(level: number)
		pendingScreen = "choice"
		pendingLevel = level
		showPendingScreen()
	end)

	-- The server's LoadCharacter() call (from any of the three actions
	-- above) is what fires this -- using it instead of a dedicated
	-- "success" remote means all three paths hide the UI the same way,
	-- with no per-action bookkeeping needed here.
	player.CharacterAdded:Connect(function()
		screenGui.Enabled = false
	end)

	-- Run hub-detection on its own thread so a dungeon server's 5-second
	-- timeout below doesn't delay Main.client.lua's synchronous calls into
	-- the controllers that run after this one. This whole flow is hub-only:
	-- a dungeon server never places RockhidePortal, the same signal
	-- DungeonPortalController already uses to detect this, reused here so
	-- the intro card never flashes on a dungeon server. Only the
	-- hub-detection check and the things that depend on knowing "this is a
	-- hub" (enabling the ScreenGui, starting the intro tweens, and
	-- listening for the input that dismisses the intro) live in here --
	-- everything else had to be connected synchronously above (see the
	-- comment at the top of Start()).
	task.spawn(function()
		local portalPart = workspace:WaitForChild("RockhidePortal", 5)
		if not portalPart then
			-- Dungeon server -- no character-entry flow here. The ScreenGui
			-- built above stays Enabled = false forever, which is harmless:
			-- CharacterCreationService never runs on a dungeon server, so
			-- none of the remotes connected above ever fire.
			return
		end

		screenGui.Enabled = true -- shows immediately: the intro needs no server round-trip

		TweenService:Create(
			titleLabel,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		):Play()
		TweenService:Create(
			pressPrompt,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0.3 }
		):Play()

		inputConnection = UserInputService.InputBegan:Connect(function(_input, gameProcessed)
			if gameProcessed then
				return
			end
			dismissIntro()
		end)
	end)
end

return CharacterCreationController
