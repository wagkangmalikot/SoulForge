-- src/StarterPlayer/StarterPlayerScripts/Controllers/ShopUIController.lua
-- Hub-only shop panel: lists the 3 health potion tiers, lets the player buy
-- them with Gold. Opened via a ProximityPrompt on the ShopkeeperStall
-- (HubMapService), same pattern as LevelUpUIController's shrine prompt.
-- Server owns Gold/Consumables truth (ShopService.lua); this is a dumb
-- renderer that reacts to ShopResult/ConsumablesSynced.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local ConsumablesData = require(ReplicatedStorage.Shared.Data.Consumables)
local ItemIconHelper = require(ReplicatedStorage.Shared.UI.ItemIconHelper)

local ShopUIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local mainFrame: Frame
local isOpen = false
local statusLabel: TextLabel

local cachedConsumables: {[string]: number} = {}
local ownedLabels: {[string]: TextLabel} = {}

local THEME = {
	bgDark       = Color3.fromRGB(12, 10, 8),
	panelBg      = Color3.fromRGB(20, 16, 12),
	panelInner   = Color3.fromRGB(27, 21, 15),
	rowBg        = Color3.fromRGB(34, 26, 18),
	borderDim    = Color3.fromRGB(70, 50, 25),
	borderBright = Color3.fromRGB(220, 135, 35),
	amberBright  = Color3.fromRGB(255, 175, 45),
	textWhite    = Color3.fromRGB(242, 230, 210),
	textSilver   = Color3.fromRGB(180, 165, 135),
	textDim      = Color3.fromRGB(115, 100, 75),
	green        = Color3.fromRGB(80, 215, 95),
	greenDark    = Color3.fromRGB(25, 65, 30),
	red          = Color3.fromRGB(235, 75, 55),
}

local POTION_ORDER = {"MinorHealthPotion", "HealthPotion", "GreaterHealthPotion"}

local function makeCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function showStatus(msg: string, success: boolean)
	if not statusLabel then return end
	statusLabel.Text = msg
	statusLabel.TextColor3 = success and THEME.green or THEME.red
	task.delay(4, function()
		if statusLabel and statusLabel.Parent then
			statusLabel.Text = ""
		end
	end)
end

local function buildRow(parent: Instance, itemId: string, layoutOrder: number): Frame?
	local item = ConsumablesData[itemId]
	if not item then
		warn(("ShopUIController: unknown itemId %q in POTION_ORDER"):format(tostring(itemId)))
		return nil
	end

	local row = Instance.new("Frame")
	row.Name = "Row_" .. itemId
	row.Size = UDim2.new(1, 0, 0, 84)
	row.BackgroundColor3 = THEME.rowBg
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	makeCorner(row, 6)
	makeStroke(row, THEME.borderDim, 1)
	row.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, -12, 0, 26)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.displayName
	nameLabel.TextColor3 = THEME.textWhite
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.5, -12, 0, 40)
	descLabel.Position = UDim2.new(0, 12, 0, 34)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = item.description
	descLabel.TextColor3 = THEME.textSilver
	descLabel.TextSize = 13
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = row

	local ownedLabel = Instance.new("TextLabel")
	ownedLabel.Size = UDim2.new(0, 84, 0, 20)
	ownedLabel.Position = UDim2.new(1, -234, 0, 8)
	ownedLabel.BackgroundTransparency = 1
	ownedLabel.Font = Enum.Font.GothamBold
	ownedLabel.Text = "Owned: 0"
	ownedLabel.TextColor3 = THEME.textDim
	ownedLabel.TextSize = 13
	ownedLabel.TextXAlignment = Enum.TextXAlignment.Right
	ownedLabel.Parent = row
	ownedLabels[itemId] = ownedLabel

	local buyBtn = Instance.new("TextButton")
	buyBtn.Name = "BuyBtn"
	buyBtn.Size = UDim2.new(0, 130, 0, 44)
	buyBtn.Position = UDim2.new(1, -142, 0.5, -22)
	buyBtn.BackgroundColor3 = THEME.greenDark
	buyBtn.BorderSizePixel = 0
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.Text = ("Buy - %d G"):format(item.price)
	buyBtn.TextColor3 = THEME.green
	buyBtn.TextSize = 15
	makeCorner(buyBtn, 6)
	makeStroke(buyBtn, THEME.green, 1)
	buyBtn.Parent = row

	buyBtn.Activated:Connect(function()
		Net.Get("RequestBuyPotion"):FireServer(itemId)
	end)

	return row
end

local function refreshOwnedLabels()
	for itemId, label in ownedLabels do
		label.Text = ("Owned: %d"):format(cachedConsumables[itemId] or 0)
	end
end

local function buildUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.ZIndex = 9
	backdrop.Parent = screenGui
	backdrop.MouseButton1Click:Connect(function()
		ShopUIController.Close()
	end)

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainModal"
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Size = UDim2.new(0, 560, 0, 420)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.BackgroundColor3 = THEME.bgDark
	mainFrame.BorderSizePixel = 0
	mainFrame.ZIndex = 10
	makeCorner(mainFrame, 8)
	makeStroke(mainFrame, THEME.borderBright, 2)
	mainFrame.Parent = screenGui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 54)
	header.BackgroundColor3 = THEME.panelBg
	header.BorderSizePixel = 0
	makeCorner(header, 8)
	header.Parent = mainFrame

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Text = "🧪 SHOPKEEPER"
	headerTitle.TextColor3 = THEME.amberBright
	headerTitle.TextSize = 22
	headerTitle.Font = Enum.Font.GothamBlack
	headerTitle.BackgroundTransparency = 1
	headerTitle.Position = UDim2.new(0, 16, 0, 0)
	headerTitle.Size = UDim2.new(0.6, 0, 1, 0)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Parent = header

	local goldPill = Instance.new("Frame")
	goldPill.Size = UDim2.new(0, 160, 0, 34)
	goldPill.Position = UDim2.new(1, -216, 0.5, -17)
	goldPill.BackgroundColor3 = THEME.panelInner
	goldPill.BorderSizePixel = 0
	makeCorner(goldPill, 6)
	makeStroke(goldPill, THEME.borderBright, 1)
	local coinIcon = ItemIconHelper.CreateGoldCoinIcon(goldPill, UDim2.new(0, 22, 0, 22))
	coinIcon.Position = UDim2.new(0, 6, 0.5, -11)
	local goldLabel = Instance.new("TextLabel")
	goldLabel.Text = "9,999,999 GOLD"
	goldLabel.TextColor3 = THEME.amberBright
	goldLabel.TextSize = 14
	goldLabel.Font = Enum.Font.GothamBold
	goldLabel.BackgroundTransparency = 1
	goldLabel.Position = UDim2.new(0, 34, 0, 0)
	goldLabel.Size = UDim2.new(1, -38, 1, 0)
	goldLabel.Parent = goldPill
	goldPill.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.TextColor3 = THEME.textWhite
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0.5, -18)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.BorderSizePixel = 0
	makeCorner(closeBtn, 6)
	closeBtn.Parent = header
	closeBtn.Activated:Connect(function()
		ShopUIController.Close()
	end)

	local rowsList = Instance.new("UIListLayout")
	rowsList.Padding = UDim.new(0, 10)
	rowsList.SortOrder = Enum.SortOrder.LayoutOrder

	local rowsContainer = Instance.new("Frame")
	rowsContainer.Size = UDim2.new(1, -32, 1, -100)
	rowsContainer.Position = UDim2.new(0, 16, 0, 62)
	rowsContainer.BackgroundTransparency = 1
	rowsList.Parent = rowsContainer
	rowsContainer.Parent = mainFrame

	for i, itemId in POTION_ORDER do
		buildRow(rowsContainer, itemId, i)
	end

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -32, 0, 24)
	statusLabel.Position = UDim2.new(0, 16, 1, -32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = ""
	statusLabel.TextSize = 14
	statusLabel.Parent = mainFrame

	refreshOwnedLabels()
end

function ShopUIController.Open()
	if isOpen then return end
	isOpen = true
	screenGui.Enabled = true
	Net.Get("RequestConsumablesSync"):FireServer()
	refreshOwnedLabels()
end

function ShopUIController.Toggle()
	if not screenGui then return end
	if isOpen then
		ShopUIController.Close()
	else
		ShopUIController.Open()
	end
end

function ShopUIController.Close()
	if not isOpen then return end
	isOpen = false
	screenGui.Enabled = false
end

function ShopUIController.Start()
	-- Hub-only check (same pattern as DungeonPortalController/LevelUpUIController)
	if ReplicatedStorage:GetAttribute("IsDungeon") == true then
		return
	end
	local teleportData = TeleportService:GetLocalPlayerTeleportData()
	if teleportData and teleportData.isDungeon then
		return
	end

	buildUI()

	Net.Get("ShopResult").OnClientEvent:Connect(function(success: boolean, message: string, newConsumables: {[string]: number}?)
		if newConsumables then
			cachedConsumables = newConsumables
			refreshOwnedLabels()
		end
		showStatus(message, success)
	end)

	Net.Get("ConsumablesSynced").OnClientEvent:Connect(function(consumables: {[string]: number})
		cachedConsumables = consumables or {}
		refreshOwnedLabels()
	end)

	Net.Get("RequestConsumablesSync"):FireServer()

	task.spawn(function()
		local stallPart = workspace:WaitForChild("ShopkeeperStall", 5)
		if not stallPart then
			warn("ShopUIController: ShopkeeperStall not found on hub server within 5s")
			return
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Browse Wares"
		prompt.ObjectText = "Shopkeeper"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.Parent = stallPart

		prompt.Triggered:Connect(function()
			ShopUIController.Open()
		end)
	end)
end

return ShopUIController
