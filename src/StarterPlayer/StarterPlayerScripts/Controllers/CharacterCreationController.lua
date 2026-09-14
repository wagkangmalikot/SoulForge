-- src/StarterPlayer/StarterPlayerScripts/Controllers/CharacterCreationController.lua
-- Full-screen character creation UI (spec section 2b), shown only when the
-- server tells this client to via ShowCharacterCreation (i.e. only for a
-- profile that hasn't completed creation yet -- a returning player never
-- sees this).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local CharacterCreationController = {}

local MIN_NAME_LENGTH = 3
local MAX_NAME_LENGTH = 20

function CharacterCreationController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterCreation"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0.05, 0.05, 0.08)
	background.BorderSizePixel = 0
	background.Parent = screenGui

	-- All vertical (Y) positions/sizes below are scale-only (no pixel offset) so
	-- the whole layout compresses proportionally on short viewports -- notably
	-- mobile-landscape (~400-450px tall, a supported orientation per this
	-- project's mobile-support work) -- instead of overlapping the way a mix of
	-- scale positions and fixed-pixel heights would. X stays offset-based since
	-- only viewport height is the tight constraint here.
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 500, 0.10, 0)
	title.Position = UDim2.new(0.5, -250, 0.05, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Text = "Create Your Character"
	title.Parent = background

	-- Tank class card -- the only selectable option for this slice (spec 2a/2b).
	local classCard = Instance.new("Frame")
	classCard.Size = UDim2.new(0, 200, 0.34, 0)
	classCard.Position = UDim2.new(0.5, -100, 0.19, 0)
	classCard.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
	classCard.Parent = background

	local classCorner = Instance.new("UICorner")
	classCorner.CornerRadius = UDim.new(0, 10)
	classCorner.Parent = classCard

	-- Sized/positioned relative to classCard itself (scale is relative to the
	-- parent frame, not the screen), so these stay proportional to the card no
	-- matter how tall the card ends up being on a given viewport.
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

	local nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.new(0, 300, 0.07, 0)
	nameBox.Position = UDim2.new(0.5, -150, 0.56, 0)
	nameBox.PlaceholderText = "Enter your character's name"
	nameBox.Text = ""
	nameBox.ClearTextOnFocus = false
	nameBox.TextScaled = true
	nameBox.Parent = background

	local errorLabel = Instance.new("TextLabel")
	errorLabel.Size = UDim2.new(0, 400, 0.05, 0)
	errorLabel.Position = UDim2.new(0.5, -200, 0.65, 0)
	errorLabel.BackgroundTransparency = 1
	errorLabel.TextColor3 = Color3.new(1, 0.4, 0.4)
	errorLabel.TextScaled = true
	errorLabel.Text = ""
	errorLabel.Parent = background

	local confirmButton = Instance.new("TextButton")
	confirmButton.Size = UDim2.new(0, 200, 0.09, 0)
	confirmButton.Position = UDim2.new(0.5, -100, 0.73, 0)
	confirmButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.3)
	confirmButton.TextColor3 = Color3.new(1, 1, 1)
	confirmButton.TextScaled = true
	confirmButton.Text = "Confirm"
	confirmButton.Parent = background

	confirmButton.Activated:Connect(function()
		local name = nameBox.Text
		-- Client-side check is purely for immediate feedback; the server
		-- re-validates length and runs its own moderation filter (spec 2b) --
		-- this can never be trusted as the real gate.
		if #name < MIN_NAME_LENGTH or #name > MAX_NAME_LENGTH then
			errorLabel.Text = ("Name must be %d-%d characters."):format(MIN_NAME_LENGTH, MAX_NAME_LENGTH)
			return
		end
		errorLabel.Text = ""
		-- Debounce: the server already guards against duplicate submissions
		-- (Task 3's `submitting` flag), but disabling here avoids wastefully
		-- re-firing the remote on every extra tap while waiting for a result,
		-- and gives the player a clearer "this is processing" signal.
		confirmButton.Active = false
		confirmButton.AutoButtonColor = false
		confirmButton.BackgroundColor3 = Color3.new(0.15, 0.35, 0.2)
		Net.Get("SubmitCharacterCreation"):FireServer(name)
	end)

	-- Assumes ShowCharacterCreation cannot fire before this listener connects:
	-- every controller in Main.client.lua (including this one) starts and
	-- connects synchronously with no yields, so this connection is live before
	-- any server round-trip -- including PlayerDataService.WaitForProfile,
	-- which always yields at least once -- could complete. If a future change
	-- to PlayerDataService's load path introduces an instant/cached fast path
	-- that could fire this remote before the client finishes connecting
	-- listeners, this assumption breaks and a new joiner could be silently
	-- softlocked with CharacterAutoLoads = false and no creation screen.
	Net.Get("ShowCharacterCreation").OnClientEvent:Connect(function()
		screenGui.Enabled = true
	end)

	Net.Get("CharacterCreationResult").OnClientEvent:Connect(function(success, errorMessage)
		if success then
			screenGui.Enabled = false
			-- Left disabled: the screen is about to hide, so there's nothing
			-- left to re-enable it for.
		else
			errorLabel.Text = errorMessage or "Something went wrong. Try again."
			-- Re-enable so the player can correct the name and retry.
			confirmButton.Active = true
			confirmButton.AutoButtonColor = true
			confirmButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.3)
		end
	end)
end

return CharacterCreationController
