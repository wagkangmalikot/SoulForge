-- src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryUIController.lua
-- Dedicated Inventory & Backpack UI for Soulforge.
-- Displays ONLY owned equipment, currently equipped loadout, set bonus status,
-- and the materials/reagents pouch. Does NOT display crafting/forge recipes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local EquipmentData = require(ReplicatedStorage.Shared.Data.Equipment)
local ItemIconHelper = require(ReplicatedStorage.Shared.UI.ItemIconHelper)

local InventoryUIController = {}

-- ============================================================================
-- STATE & CACHE
-- ============================================================================

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local mainModal: Frame
local isOpen = false

local cachedClassId: string = "Mage"
local cachedCraftingMaterials: {[string]: number} = {}
local cachedStoredEquipment: {string} = {}
local cachedEquippedEquipment: {[string]: string} = {
	Weapon = "ApprenticeStaff",
	Head = "ApprenticeHood",
	Body = "ApprenticeRobe",
	Arms = "ApprenticeBracers",
	Feet = "ApprenticeBoots",
}

local selectedItemId: string? = nil
local activeTab: string = "Equipment" -- "Equipment" | "Materials"

-- ============================================================================
-- THEME & PALETTE
-- ============================================================================

local THEME = {
	bgDark       = Color3.fromRGB(12, 10, 8),
	panelBg      = Color3.fromRGB(20, 16, 12),
	panelInner   = Color3.fromRGB(26, 20, 14),
	rowBg        = Color3.fromRGB(32, 25, 17),
	rowBgAlt     = Color3.fromRGB(24, 18, 12),
	rowSelected  = Color3.fromRGB(56, 38, 16),
	borderDim    = Color3.fromRGB(65, 48, 26),
	borderBright = Color3.fromRGB(220, 140, 35),

	amberBright  = Color3.fromRGB(255, 180, 50),
	amberDim     = Color3.fromRGB(150, 90, 20),

	textWhite    = Color3.fromRGB(242, 230, 210),
	textSilver   = Color3.fromRGB(180, 165, 135),
	textDim      = Color3.fromRGB(115, 100, 75),

	green        = Color3.fromRGB(80, 215, 95),
	greenDark    = Color3.fromRGB(25, 65, 30),
	red          = Color3.fromRGB(225, 75, 70),
	cyan         = Color3.fromRGB(85, 190, 255),
	cyanDark     = Color3.fromRGB(20, 45, 65),
}

local RARITY_COLOR = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(80, 210, 95),
	Rare      = Color3.fromRGB(90, 180, 255),
	Epic      = Color3.fromRGB(190, 105, 255),
	Legendary = Color3.fromRGB(255, 210, 50),
}

local SLOT_ORDER = { "Weapon", "Head", "Body", "Arms", "Feet" }

-- ============================================================================
-- HELPER BUILDERS
-- ============================================================================

local function makeCorner(parent, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function makeStroke(parent, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function makeGradient(parent, colorA: Color3, colorB: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(colorA, colorB)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

local function makePadding(parent, top: number, bottom: number, left: number, right: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top)
	p.PaddingBottom = UDim.new(0, bottom)
	p.PaddingLeft = UDim.new(0, left)
	p.PaddingRight = UDim.new(0, right)
	p.Parent = parent
	return p
end

-- ============================================================================
-- UI REFERENCES
-- ============================================================================

local loadoutSlotsContainer: Frame
local setBonusText: TextLabel
local setBonusPips: Frame
local itemsScroll: ScrollingFrame
local detailViewContainer: Frame
local tabEquipBtn: TextButton
local tabMatsBtn: TextButton
local equipActionButton: TextButton
local equipActionLabel: TextLabel

-- ============================================================================
-- HELPERS
-- ============================================================================

local function isEquipped(itemId: string): boolean
	for _, id in pairs(cachedEquippedEquipment) do
		if id == itemId then return true end
	end
	return false
end

local function getEquippedCountForSet(setId: string): (number, number)
	local setData = EquipmentData.Sets[setId]
	if not setData or not setData.pieces then return 0, 0 end
	local count = 0
	for _, pieceId in ipairs(setData.pieces) do
		if isEquipped(pieceId) then count += 1 end
	end
	return count, #setData.pieces
end

-- ============================================================================
-- RENDER DETAIL VIEW
-- ============================================================================

local function renderDetailView(itemId: string?)
	if not detailViewContainer then return end
	detailViewContainer:ClearAllChildren()

	if not itemId then
		local placeholder = Instance.new("TextLabel")
		placeholder.Text = "Select an item from your bag to inspect"
		placeholder.TextColor3 = THEME.textDim
		placeholder.TextSize = 15
		placeholder.Font = Enum.Font.GothamMedium
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.new(1, 0, 1, 0)
		placeholder.Parent = detailViewContainer
		if equipActionButton then equipActionButton.Visible = false end
		return
	end

	local item = EquipmentData.Items[itemId]
	if not item then return end

	local equipped = isEquipped(itemId)
	local rarityColor = RARITY_COLOR[item.rarity or "Common"] or THEME.textWhite

	-- Header Card
	local hdr = Instance.new("Frame")
	hdr.Size = UDim2.new(1, 0, 0, 78)
	hdr.BackgroundColor3 = THEME.panelInner
	hdr.BorderSizePixel = 0
	makeCorner(hdr, 6)
	makeStroke(hdr, THEME.borderDim, 1)
	makeGradient(hdr, Color3.fromRGB(36, 28, 18), THEME.panelInner, 90)
	hdr.Parent = detailViewContainer

	local sideAccent = Instance.new("Frame")
	sideAccent.Size = UDim2.new(0, 4, 1, 0)
	sideAccent.BackgroundColor3 = rarityColor
	sideAccent.BorderSizePixel = 0
	makeCorner(sideAccent, 2)
	sideAccent.Parent = hdr

	-- Item Artwork Tile
	local detailIcon = ItemIconHelper.CreateItemIcon(hdr, itemId, UDim2.new(0, 58, 0, 58), true)
	detailIcon.Position = UDim2.new(0, 10, 0.5, -29)

	local slotTag = Instance.new("TextLabel")
	slotTag.Text = string.format("[ %s SLOT ]", string.upper(item.slot))
	slotTag.TextColor3 = THEME.amberBright
	slotTag.TextSize = 14
	slotTag.Font = Enum.Font.GothamBold
	slotTag.BackgroundTransparency = 1
	slotTag.TextXAlignment = Enum.TextXAlignment.Left
	slotTag.Position = UDim2.new(0, 76, 0, 7)
	slotTag.Size = UDim2.new(0.6, 0, 0, 18)
	slotTag.Parent = hdr

	local title = Instance.new("TextLabel")
	title.Text = item.displayName or item.id
	title.TextColor3 = THEME.textWhite
	title.TextSize = 21
	title.Font = Enum.Font.GothamBold
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.new(0, 76, 0, 27)
	title.Size = UDim2.new(0.65, 0, 0, 24)
	title.Parent = hdr

	local sub = Instance.new("TextLabel")
	sub.Text = string.format("Tier %d  ·  %s", item.tier or 1, string.upper(item.rarity or "Common"))
	sub.TextColor3 = rarityColor
	sub.TextSize = 14
	sub.Font = Enum.Font.GothamSemibold
	sub.BackgroundTransparency = 1
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Position = UDim2.new(0, 76, 0, 53)
	sub.Size = UDim2.new(0.6, 0, 0, 18)
	sub.Parent = hdr

	-- Status Badge
	local statusBadge = Instance.new("Frame")
	statusBadge.Size = UDim2.new(0, 100, 0, 28)
	statusBadge.Position = UDim2.new(1, -108, 0, 10)
	statusBadge.BackgroundColor3 = equipped and THEME.amberDim or THEME.greenDark
	statusBadge.BorderSizePixel = 0
	makeCorner(statusBadge, 4)
	makeStroke(statusBadge, equipped and THEME.amberBright or THEME.green, 1)
	statusBadge.Parent = hdr

	local badgeText = Instance.new("TextLabel")
	badgeText.Text = equipped and "EQUIPPED" or "IN BAG"
	badgeText.TextColor3 = equipped and THEME.amberBright or THEME.green
	badgeText.TextSize = 13.5
	badgeText.Font = Enum.Font.GothamBold
	badgeText.BackgroundTransparency = 1
	badgeText.Size = UDim2.new(1, 0, 1, 0)
	badgeText.Parent = statusBadge

	-- Scrollable Content (Description + Attributes)
	local detailsScroll = Instance.new("ScrollingFrame")
	detailsScroll.Size = UDim2.new(1, 0, 1, -132)
	detailsScroll.Position = UDim2.new(0, 0, 0, 84)
	detailsScroll.BackgroundTransparency = 1
	detailsScroll.BorderSizePixel = 0
	detailsScroll.ScrollBarThickness = 3
	detailsScroll.ScrollBarImageColor3 = THEME.amberDim
	detailsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	detailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detailsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	detailsScroll.Parent = detailViewContainer

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = detailsScroll

	-- Description box
	if item.description and item.description ~= "" then
		local descBox = Instance.new("Frame")
		descBox.Size = UDim2.new(1, -4, 0, 0)
		descBox.AutomaticSize = Enum.AutomaticSize.Y
		descBox.BackgroundColor3 = THEME.rowBgAlt
		descBox.BorderSizePixel = 0
		descBox.LayoutOrder = 1
		makeCorner(descBox, 4)
		makePadding(descBox, 8, 8, 10, 10)
		descBox.Parent = detailsScroll

		local descText = Instance.new("TextLabel")
		descText.Text = "“ " .. item.description .. " ”"
		descText.TextColor3 = THEME.textSilver
		descText.TextSize = 14.5
		descText.Font = Enum.Font.Gotham
		descText.BackgroundTransparency = 1
		descText.TextXAlignment = Enum.TextXAlignment.Left
		descText.TextWrapped = true
		descText.Size = UDim2.new(1, 0, 0, 0)
		descText.AutomaticSize = Enum.AutomaticSize.Y
		descText.Parent = descBox
	end

	-- Stats Card
	local statsCard = Instance.new("Frame")
	statsCard.Size = UDim2.new(1, -4, 0, 0)
	statsCard.AutomaticSize = Enum.AutomaticSize.Y
	statsCard.BackgroundColor3 = THEME.panelInner
	statsCard.BorderSizePixel = 0
	statsCard.LayoutOrder = 2
	makeCorner(statsCard, 6)
	makeStroke(statsCard, THEME.borderDim, 1)
	makePadding(statsCard, 8, 8, 8, 8)
	statsCard.Parent = detailsScroll

	local statsTitle = Instance.new("TextLabel")
	statsTitle.Text = "ITEM ATTRIBUTES"
	statsTitle.TextColor3 = THEME.amberBright
	statsTitle.TextSize = 14.5
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.BackgroundTransparency = 1
	statsTitle.TextXAlignment = Enum.TextXAlignment.Left
	statsTitle.Size = UDim2.new(1, 0, 0, 24)
	statsTitle.Parent = statsCard

	local statsList = Instance.new("UIListLayout")
	statsList.SortOrder = Enum.SortOrder.LayoutOrder
	statsList.Padding = UDim.new(0, 3)
	statsList.Parent = statsCard

	local statLabels = {
		physicalDamage        = "Physical Damage",
		attackSpeed           = "Attack Speed",
		criticalChance        = "Critical Chance",
		bonusDamageUnder50Pct = "Low HP Bonus",
		armor                 = "Armor Rating",
		magicResist           = "Magic Resistance",
		maxHPBonus            = "Max HP Bonus",
		blockChance           = "Shield Block Chance",
		damageReduction       = "Damage Mitigation",
		parryWindow           = "Parry Timing Window",
		movementSpeed         = "Movement Speed Mod",
	}

	local statIndex = 1
	for statKey, statVal in pairs(item.stats or {}) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = (statIndex % 2 == 0) and THEME.rowBg or THEME.rowBgAlt
		row.BorderSizePixel = 0
		row.LayoutOrder = statIndex + 1
		makeCorner(row, 3)
		makePadding(row, 0, 0, 8, 8)
		row.Parent = statsCard

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Text = statLabels[statKey] or statKey
		nameLbl.TextColor3 = THEME.textSilver
		nameLbl.TextSize = 14
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Size = UDim2.new(0.65, 0, 1, 0)
		nameLbl.Parent = row

		local valStr = tostring(statVal)
		if statKey == "criticalChance" or statKey == "blockChance" or statKey == "damageReduction" or statKey == "bonusDamageUnder50Pct" then
			valStr = "+" .. math.floor(statVal * 100) .. "%"
		elseif statKey == "movementSpeed" then
			valStr = (statVal >= 0 and "+" or "") .. math.floor(statVal * 100) .. "%"
		elseif statKey == "parryWindow" then
			valStr = string.format("%.2fs", statVal)
		elseif statKey == "attackSpeed" then
			valStr = string.format("%.2fx", statVal)
		elseif statKey == "maxHPBonus" then
			valStr = "+" .. tostring(statVal) .. " HP"
		else
			valStr = "+" .. tostring(statVal)
		end

		local valLbl = Instance.new("TextLabel")
		valLbl.Text = valStr
		valLbl.TextColor3 = THEME.amberBright
		valLbl.TextSize = 15
		valLbl.Font = Enum.Font.GothamBold
		valLbl.BackgroundTransparency = 1
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.Size = UDim2.new(0.35, 0, 1, 0)
		valLbl.Position = UDim2.new(0.65, 0, 0, 0)
		valLbl.Parent = row

		statIndex += 1
	end

	-- Equip Button at bottom
	if equipActionButton and equipActionLabel then
		equipActionButton.Visible = true
		local itemClass = EquipmentData.GetItemClass(itemId)
		local isClassMismatch = itemClass and (itemClass ~= cachedClassId)

		if equipped then
			equipActionButton.Active = false
			equipActionButton.BackgroundColor3 = THEME.panelInner
			equipActionLabel.Text = "CURRENTLY EQUIPPED"
			equipActionLabel.TextColor3 = THEME.textDim
		elseif isClassMismatch then
			equipActionButton.Active = false
			equipActionButton.BackgroundColor3 = THEME.panelInner
			equipActionLabel.Text = string.format("REQUIRES %s CLASS", string.upper(itemClass))
			equipActionLabel.TextColor3 = THEME.red
		else
			equipActionButton.Active = true
			equipActionButton.BackgroundColor3 = THEME.greenDark
			equipActionLabel.Text = string.format("EQUIP TO %s", string.upper(item.slot))
			equipActionLabel.TextColor3 = THEME.green
		end
	end
end

-- ============================================================================
-- RENDER ITEMS LIST (MIDDLE COLUMN)
-- ============================================================================

local function renderItemsList()
	if not itemsScroll then return end
	itemsScroll:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = itemsScroll

	if activeTab == "Equipment" then
		local ownedList = {}
		for _, itemId in ipairs(cachedStoredEquipment) do
			local item = EquipmentData.Items[itemId]
			if item and not item.stashed then
				table.insert(ownedList, { id = itemId, item = item })
			end
		end

		if #ownedList == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Text = "Your equipment bag is empty.\nForge items at the Soulforge Armory!"
			emptyLabel.TextColor3 = THEME.textDim
			emptyLabel.TextSize = 14
			emptyLabel.Font = Enum.Font.Gotham
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Size = UDim2.new(1, 0, 0, 80)
			emptyLabel.Parent = itemsScroll
			return
		end

		for orderIndex, entry in ipairs(ownedList) do
			local itemId = entry.id
			local item = entry.item
			local equipped = isEquipped(itemId)
			local isSelected = (selectedItemId == itemId)
			local rarityColor = RARITY_COLOR[item.rarity or "Common"] or THEME.textWhite

			local card = Instance.new("TextButton")
			card.Name = "BagItem_" .. itemId
			card.Size = UDim2.new(1, -4, 0, 62)
			card.BackgroundColor3 = isSelected and THEME.rowSelected or (equipped and Color3.fromRGB(34, 26, 16) or THEME.rowBg)
			card.BorderSizePixel = 0
			card.Text = ""
			card.LayoutOrder = orderIndex
			makeCorner(card, 5)

			if isSelected then
				makeStroke(card, THEME.borderBright, 2)
			else
				makeStroke(card, equipped and THEME.borderBright or THEME.borderDim, 1)
			end

			-- Procedural Vector Item Icon
			local iconTile = ItemIconHelper.CreateItemIcon(card, itemId, UDim2.new(0, 42, 0, 42), isSelected)
			iconTile.Position = UDim2.new(0, 8, 0.5, -21)

			-- Name
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Text = item.displayName or item.id
			nameLabel.TextColor3 = isSelected and THEME.amberBright or THEME.textWhite
			nameLabel.TextSize = 15.5
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.BackgroundTransparency = 1
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Position = UDim2.new(0, 56, 0, 8)
			nameLabel.Size = UDim2.new(1, -125, 0, 22)
			nameLabel.Parent = card

			-- Subtitle
			local subLabel = Instance.new("TextLabel")
			subLabel.Text = string.format("%s · Tier %d", string.upper(item.slot), item.tier or 1)
			subLabel.TextColor3 = rarityColor
			subLabel.TextSize = 13.5
			subLabel.Font = Enum.Font.GothamMedium
			subLabel.BackgroundTransparency = 1
			subLabel.TextXAlignment = Enum.TextXAlignment.Left
			subLabel.Position = UDim2.new(0, 56, 0, 32)
			subLabel.Size = UDim2.new(1, -125, 0, 18)
			subLabel.Parent = card

			-- Badge
			if equipped then
				local badge = Instance.new("Frame")
				badge.Size = UDim2.new(0, 72, 0, 22)
				badge.Position = UDim2.new(1, -78, 0.5, -11)
				badge.BackgroundColor3 = THEME.amberDim
				badge.BorderSizePixel = 0
				makeCorner(badge, 4)
				makeStroke(badge, THEME.amberBright, 1)

				local badgeTxt = Instance.new("TextLabel")
				badgeTxt.Text = "EQUIPPED"
				badgeTxt.TextColor3 = THEME.amberBright
				badgeTxt.TextSize = 12.5
				badgeTxt.Font = Enum.Font.GothamBold
				badgeTxt.BackgroundTransparency = 1
				badgeTxt.Size = UDim2.new(1, 0, 1, 0)
				badgeTxt.Parent = badge
				badge.Parent = card
			end

			card.MouseButton1Click:Connect(function()
				selectedItemId = itemId
				renderItemsList()
				renderDetailView(itemId)
			end)

			card.Parent = itemsScroll
		end

	elseif activeTab == "Materials" then
		-- Render materials bag
		local matOrder = 1
		for matId, matDef in pairs(EquipmentData.Materials) do
			local count = cachedCraftingMaterials[matId] or 0
			local matColor = RARITY_COLOR[matDef.rarity or "Common"] or THEME.textWhite

			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -4, 0, 58)
			card.BackgroundColor3 = THEME.rowBg
			card.BorderSizePixel = 0
			card.LayoutOrder = matOrder
			makeCorner(card, 5)
			makeStroke(card, THEME.borderDim, 1)

			local iconTile = ItemIconHelper.CreateMaterialIcon(card, matId, UDim2.new(0, 40, 0, 40))
			iconTile.Position = UDim2.new(0, 8, 0.5, -20)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Text = matDef.displayName or matId
			nameLabel.TextColor3 = matColor
			nameLabel.TextSize = 15.5
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.BackgroundTransparency = 1
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Position = UDim2.new(0, 54, 0, 7)
			nameLabel.Size = UDim2.new(1, -135, 0, 22)
			nameLabel.Parent = card

			local descLabel = Instance.new("TextLabel")
			descLabel.Text = matDef.description or ""
			descLabel.TextColor3 = THEME.textDim
			descLabel.TextSize = 13.5
			descLabel.Font = Enum.Font.Gotham
			descLabel.BackgroundTransparency = 1
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.TextTruncate = Enum.TextTruncate.AtEnd
			descLabel.Position = UDim2.new(0, 54, 0, 30)
			descLabel.Size = UDim2.new(1, -135, 0, 20)
			descLabel.Parent = card

			-- Count pill
			local countPill = Instance.new("Frame")
			countPill.Size = UDim2.new(0, 76, 0, 26)
			countPill.Position = UDim2.new(1, -82, 0.5, -13)
			countPill.BackgroundColor3 = THEME.panelInner
			countPill.BorderSizePixel = 0
			makeCorner(countPill, 4)
			makeStroke(countPill, THEME.borderBright, 1)

			local countText = Instance.new("TextLabel")
			countText.Text = string.format("x %s", tostring(count))
			countText.TextColor3 = THEME.amberBright
			countText.TextSize = 14
			countText.Font = Enum.Font.GothamBold
			countText.BackgroundTransparency = 1
			countText.Size = UDim2.new(1, 0, 1, 0)
			countText.Parent = countPill
			countPill.Parent = card

			card.Parent = itemsScroll
			matOrder += 1
		end
	end
end

-- ============================================================================
-- RENDER EQUIPPED LOADOUT (LEFT COLUMN)
-- ============================================================================

local function renderLoadoutSlots()
	if not loadoutSlotsContainer then return end
	loadoutSlotsContainer:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = loadoutSlotsContainer

	for orderIndex, slotName in ipairs(SLOT_ORDER) do
		local equippedItemId = cachedEquippedEquipment[slotName]
		local item = equippedItemId and EquipmentData.Items[equippedItemId]

		local card = Instance.new("TextButton")
		card.Size = UDim2.new(1, 0, 0, 56)
		card.BackgroundColor3 = item and Color3.fromRGB(38, 28, 16) or THEME.panelInner
		card.BorderSizePixel = 0
		card.Text = ""
		card.LayoutOrder = orderIndex
		makeCorner(card, 5)
		makeStroke(card, item and THEME.borderBright or THEME.borderDim, item and 1.8 or 1)

		local iconTile = equippedItemId and ItemIconHelper.CreateItemIcon(card, equippedItemId, UDim2.new(0, 40, 0, 40), true) or ItemIconHelper.CreateSlotIcon(card, slotName, UDim2.new(0, 40, 0, 40), false)
		iconTile.Position = UDim2.new(0, 8, 0.5, -20)

		local slotTitle = Instance.new("TextLabel")
		slotTitle.Text = string.upper(slotName)
		slotTitle.TextColor3 = THEME.amberBright
		slotTitle.TextSize = 13.5
		slotTitle.Font = Enum.Font.GothamBold
		slotTitle.BackgroundTransparency = 1
		slotTitle.TextXAlignment = Enum.TextXAlignment.Left
		slotTitle.Position = UDim2.new(0, 54, 0, 6)
		slotTitle.Size = UDim2.new(1, -95, 0, 16)
		slotTitle.Parent = card

		local itemNameLabel = Instance.new("TextLabel")
		itemNameLabel.Text = item and (item.displayName or item.id) or "(Empty)"
		itemNameLabel.TextColor3 = item and THEME.textWhite or THEME.textDim
		itemNameLabel.TextSize = 14.5
		itemNameLabel.Font = Enum.Font.GothamBold
		itemNameLabel.BackgroundTransparency = 1
		itemNameLabel.TextXAlignment = Enum.TextXAlignment.Left
		itemNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		itemNameLabel.Position = UDim2.new(0, 54, 0, 26)
		itemNameLabel.Size = UDim2.new(1, -62, 0, 22)
		itemNameLabel.Parent = card

		if item then
			local eqBadge = Instance.new("Frame")
			eqBadge.Size = UDim2.new(0, 32, 0, 20)
			eqBadge.Position = UDim2.new(1, -38, 0, 6)
			eqBadge.BackgroundColor3 = THEME.amberDim
			eqBadge.BorderSizePixel = 0
			makeCorner(eqBadge, 4)
			makeStroke(eqBadge, THEME.amberBright, 1)

			local eqLbl = Instance.new("TextLabel")
			eqLbl.Text = "✓"
			eqLbl.TextColor3 = THEME.amberBright
			eqLbl.TextSize = 14
			eqLbl.Font = Enum.Font.GothamBold
			eqLbl.BackgroundTransparency = 1
			eqLbl.Size = UDim2.new(1, 0, 1, 0)
			eqLbl.Parent = eqBadge
			eqBadge.Parent = card

			card.MouseButton1Click:Connect(function()
				selectedItemId = equippedItemId
				renderItemsList()
				renderDetailView(equippedItemId)
			end)
		end

		card.Parent = loadoutSlotsContainer
	end

	-- Update Set Bonus (check RockhideMage if Mage or wields staff, otherwise Rockhide)
	local isMage = (cachedClassId == "Mage") or (cachedEquippedEquipment.Weapon == "ApprenticeStaff" or cachedEquippedEquipment.Weapon == "RockhideStaff")
	local activeSetId = isMage and "RockhideMage" or "Rockhide"
	local activeSet = EquipmentData.Sets[activeSetId] or EquipmentData.Sets["Rockhide"]

	local setEquippedCount, totalPieces = getEquippedCountForSet(activeSetId)
	local isActive = (setEquippedCount == totalPieces and totalPieces > 0)

	if setBonusPips then
		setBonusPips:ClearAllChildren()
		for i = 1, totalPieces do
			local pieceId = activeSet.pieces[i]
			local isPieceOn = isEquipped(pieceId)
			local pip = Instance.new("Frame")
			pip.Size = UDim2.new(0, 24, 0, 24)
			pip.BackgroundColor3 = isPieceOn and (isMage and Color3.fromRGB(85, 190, 255) or THEME.amberBright) or THEME.panelBg
			pip.BorderSizePixel = 0
			makeCorner(pip, 3)
			makeStroke(pip, isPieceOn and (isMage and Color3.fromRGB(130, 215, 255) or THEME.borderBright) or THEME.borderDim, 1)

			local pieceItem = EquipmentData.Items[pieceId]
			local slotChar = pieceItem and string.sub(pieceItem.slot, 1, 1) or tostring(i)
			local pipTxt = Instance.new("TextLabel")
			pipTxt.Text = slotChar
			pipTxt.TextColor3 = isPieceOn and THEME.bgDark or THEME.textDim
			pipTxt.Font = Enum.Font.GothamBold
			pipTxt.TextSize = 13.5
			pipTxt.BackgroundTransparency = 1
			pipTxt.Size = UDim2.new(1, 0, 1, 0)
			pipTxt.Parent = pip
			pip.Parent = setBonusPips
		end
	end

	if setBonusText then
		setBonusText.TextSize = 14
		if isActive then
			setBonusText.Text = string.format("%s ACTIVE (%d/%d): %s", string.upper(activeSet.setBonus or "SET BONUS"), setEquippedCount, totalPieces, activeSet.setBonusDesc or "+20% damage")
			setBonusText.TextColor3 = isMage and Color3.fromRGB(85, 190, 255) or THEME.amberBright
		else
			setBonusText.Text = string.format("%s (%d/%d): %s (Equip all %d pieces)", activeSet.displayName, setEquippedCount, totalPieces, activeSet.setBonus or "Set Bonus", totalPieces)
			setBonusText.TextColor3 = THEME.textSilver
		end
	end
end

-- ============================================================================
-- FULL UI BUILDER
-- ============================================================================

local function buildUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Dim background backdrop
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
		InventoryUIController.Close()
	end)

	-- Main Modal Frame (940 × 600) with responsive auto-scaling
	mainModal = Instance.new("Frame")
	mainModal.Name = "MainModal"
	mainModal.AnchorPoint = Vector2.new(0.5, 0.5)
	mainModal.Size = UDim2.new(0, 940, 0, 600)
	mainModal.Position = UDim2.new(0.5, 0, 0.5, 18)
	mainModal.BackgroundColor3 = THEME.bgDark
	mainModal.BorderSizePixel = 0
	mainModal.ZIndex = 10
	makeCorner(mainModal, 8)
	makeStroke(mainModal, THEME.borderBright, 2)
	makeGradient(mainModal, Color3.fromRGB(24, 18, 12), THEME.bgDark, 90)
	mainModal.Parent = screenGui

	local modalScale = Instance.new("UIScale")
	modalScale.Name = "ModalScale"
	modalScale.Parent = mainModal

	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vp = camera.ViewportSize
		if vp.X <= 0 or vp.Y <= 0 then return end
		local scaleX = (vp.X * 0.94) / 940
		local scaleY = (vp.Y * 0.88) / 600
		local targetScale = math.min(scaleX, scaleY)
		modalScale.Scale = math.clamp(targetScale, 0.78, 1.35)
	end

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = workspace.CurrentCamera
		if c then
			c:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		updateScale()
	end

	-- ── 1. HEADER ──────────────────────────────────────────────────────────
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BackgroundColor3 = Color3.fromRGB(18, 14, 8)
	header.BorderSizePixel = 0
	header.ZIndex = 11
	makeCorner(header, 8)
	makeGradient(header, Color3.fromRGB(45, 30, 12), Color3.fromRGB(18, 14, 8), 90)

	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, 0, 0, 2)
	headerLine.Position = UDim2.new(0, 1, -2)
	headerLine.BackgroundColor3 = THEME.borderBright
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Text = "ADVENTURER'S INVENTORY & GEAR"
	headerTitle.TextColor3 = THEME.amberBright
	headerTitle.TextSize = 22
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.BackgroundTransparency = 1
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Position = UDim2.new(0, 16, 0, 6)
	headerTitle.Size = UDim2.new(0.55, 0, 0, 26)
	headerTitle.Parent = header

	local headerSubtitle = Instance.new("TextLabel")
	headerSubtitle.Text = "View owned weapons, armor loadouts, and crafting reagents bag"
	headerSubtitle.TextColor3 = THEME.textSilver
	headerSubtitle.TextSize = 14.5
	headerSubtitle.Font = Enum.Font.GothamMedium
	headerSubtitle.BackgroundTransparency = 1
	headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	headerSubtitle.Position = UDim2.new(0, 16, 0, 32)
	headerSubtitle.Size = UDim2.new(0.55, 0, 0, 20)
	headerSubtitle.Parent = header

	-- Gold Pill
	local goldPill = Instance.new("Frame")
	goldPill.Name = "GoldPill"
	goldPill.Size = UDim2.new(0, 180, 0, 36)
	goldPill.Position = UDim2.new(1, -232, 0.5, -18)
	goldPill.BackgroundColor3 = THEME.panelBg
	goldPill.BorderSizePixel = 0
	makeCorner(goldPill, 5)
	makeStroke(goldPill, THEME.borderBright, 1)

	local coinIcon = ItemIconHelper.CreateGoldCoinIcon(goldPill, UDim2.new(0, 22, 0, 22))
	coinIcon.Position = UDim2.new(0, 8, 0.5, -11)

	local goldLabel = Instance.new("TextLabel")
	goldLabel.Text = "9,999,999 GOLD"
	goldLabel.TextColor3 = THEME.amberBright
	goldLabel.TextSize = 14.5
	goldLabel.Font = Enum.Font.GothamBold
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Position = UDim2.new(0, 36, 0, 0)
	goldLabel.Size = UDim2.new(1, -40, 1, 0)
	goldLabel.Parent = goldPill
	goldPill.Parent = header

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Text = "X"
	closeBtn.TextColor3 = THEME.textSilver
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Size = UDim2.new(0, 38, 0, 34)
	closeBtn.Position = UDim2.new(1, -46, 0.5, -17)
	closeBtn.BackgroundColor3 = THEME.panelBg
	closeBtn.BorderSizePixel = 0
	makeCorner(closeBtn, 5)
	makeStroke(closeBtn, THEME.borderDim, 1)
	closeBtn.Parent = header
	closeBtn.MouseButton1Click:Connect(function()
		InventoryUIController.Close()
	end)

	header.Parent = mainModal

	-- ── 2. BODY LAYOUT ─────────────────────────────────────────────────────
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -20, 1, -76)
	body.Position = UDim2.new(0, 10, 0, 66)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ZIndex = 11
	body.Parent = mainModal

	-- Left Column: Equipped Loadout + Set Bonus (268px wide)
	local leftCol = Instance.new("Frame")
	leftCol.Name = "LeftLoadout"
	leftCol.Size = UDim2.new(0, 268, 1, 0)
	leftCol.BackgroundColor3 = THEME.panelBg
	leftCol.BorderSizePixel = 0
	makeCorner(leftCol, 6)
	makeStroke(leftCol, THEME.borderDim, 1)

	local leftHeader = Instance.new("Frame")
	leftHeader.Size = UDim2.new(1, 0, 0, 34)
	leftHeader.BackgroundColor3 = THEME.panelInner
	leftHeader.BorderSizePixel = 0
	makeCorner(leftHeader, 6)

	local leftTitle = Instance.new("TextLabel")
	leftTitle.Text = "  EQUIPPED LOADOUT"
	leftTitle.TextColor3 = THEME.amberBright
	leftTitle.TextSize = 14.5
	leftTitle.Font = Enum.Font.GothamBold
	leftTitle.BackgroundTransparency = 1
	leftTitle.TextXAlignment = Enum.TextXAlignment.Left
	leftTitle.Size = UDim2.new(1, 0, 1, 0)
	leftTitle.Parent = leftHeader
	leftHeader.Parent = leftCol

	loadoutSlotsContainer = Instance.new("Frame")
	loadoutSlotsContainer.Name = "Slots"
	loadoutSlotsContainer.Size = UDim2.new(1, -12, 0, 275)
	loadoutSlotsContainer.Position = UDim2.new(0, 6, 0, 36)
	loadoutSlotsContainer.BackgroundTransparency = 1
	loadoutSlotsContainer.Parent = leftCol

	-- Set Bonus Box inside Left Column
	local setBonusCard = Instance.new("Frame")
	setBonusCard.Name = "SetBonusCard"
	setBonusCard.Size = UDim2.new(1, -12, 1, -322)
	setBonusCard.Position = UDim2.new(0, 6, 0, 316)
	setBonusCard.BackgroundColor3 = THEME.panelInner
	setBonusCard.BorderSizePixel = 0
	makeCorner(setBonusCard, 6)
	makeStroke(setBonusCard, THEME.borderDim, 1)
	makePadding(setBonusCard, 6, 6, 6, 6)

	setBonusText = Instance.new("TextLabel")
	setBonusText.Name = "BonusText"
	setBonusText.Text = "Set Bonus: (0/5)"
	setBonusText.TextColor3 = THEME.textSilver
	setBonusText.TextSize = 12.5
	setBonusText.Font = Enum.Font.GothamBold
	setBonusText.BackgroundTransparency = 1
	setBonusText.TextXAlignment = Enum.TextXAlignment.Left
	setBonusText.TextWrapped = true
	setBonusText.Size = UDim2.new(1, 0, 0, 52)
	setBonusText.Position = UDim2.new(0, 0, 0, 0)
	setBonusText.Parent = setBonusCard

	setBonusPips = Instance.new("Frame")
	setBonusPips.Name = "Pips"
	setBonusPips.Size = UDim2.new(1, 0, 0, 24)
	setBonusPips.Position = UDim2.new(0, 0, 1, -26)
	setBonusPips.BackgroundTransparency = 1
	local pipsLayout = Instance.new("UIListLayout")
	pipsLayout.FillDirection = Enum.FillDirection.Horizontal
	pipsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pipsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipsLayout.Padding = UDim.new(0, 6)
	pipsLayout.Parent = setBonusPips
	setBonusPips.Parent = setBonusCard

	setBonusCard.Parent = leftCol
	leftCol.Parent = body

	-- Middle Column: Bag Items / Materials Pouch (318px wide)
	local midCol = Instance.new("Frame")
	midCol.Name = "MiddleBag"
	midCol.Size = UDim2.new(0, 318, 1, 0)
	midCol.Position = UDim2.new(0, 276, 0, 0)
	midCol.BackgroundColor3 = THEME.panelBg
	midCol.BorderSizePixel = 0
	makeCorner(midCol, 6)
	makeStroke(midCol, THEME.borderDim, 1)

	-- Tabs at top of Middle Column
	local tabsHeader = Instance.new("Frame")
	tabsHeader.Size = UDim2.new(1, 0, 0, 36)
	tabsHeader.BackgroundColor3 = THEME.panelInner
	tabsHeader.BorderSizePixel = 0
	makeCorner(tabsHeader, 6)

	tabEquipBtn = Instance.new("TextButton")
	tabEquipBtn.Name = "TabEquip"
	tabEquipBtn.Size = UDim2.new(0.5, -2, 1, 0)
	tabEquipBtn.Position = UDim2.new(0, 2, 0, 0)
	tabEquipBtn.BackgroundColor3 = (activeTab == "Equipment") and THEME.amberDim or Color3.fromRGB(0,0,0)
	tabEquipBtn.BackgroundTransparency = (activeTab == "Equipment") and 0 or 1
	tabEquipBtn.Text = "GEAR"
	tabEquipBtn.TextColor3 = (activeTab == "Equipment") and THEME.amberBright or THEME.textSilver
	tabEquipBtn.Font = Enum.Font.GothamBold
	tabEquipBtn.TextSize = 15
	makeCorner(tabEquipBtn, 4)
	tabEquipBtn.Parent = tabsHeader

	tabMatsBtn = Instance.new("TextButton")
	tabMatsBtn.Name = "TabMats"
	tabMatsBtn.Size = UDim2.new(0.5, -2, 1, 0)
	tabMatsBtn.Position = UDim2.new(0.5, 0, 0, 0)
	tabMatsBtn.BackgroundColor3 = (activeTab == "Materials") and THEME.amberDim or Color3.fromRGB(0,0,0)
	tabMatsBtn.BackgroundTransparency = (activeTab == "Materials") and 0 or 1
	tabMatsBtn.Text = "POUCH"
	tabMatsBtn.TextColor3 = (activeTab == "Materials") and THEME.amberBright or THEME.textSilver
	tabMatsBtn.Font = Enum.Font.GothamBold
	tabMatsBtn.TextSize = 15
	makeCorner(tabMatsBtn, 4)
	tabMatsBtn.Parent = tabsHeader

	tabEquipBtn.MouseButton1Click:Connect(function()
		activeTab = "Equipment"
		tabEquipBtn.BackgroundTransparency = 0
		tabEquipBtn.BackgroundColor3 = THEME.amberDim
		tabEquipBtn.TextColor3 = THEME.amberBright
		tabMatsBtn.BackgroundTransparency = 1
		tabMatsBtn.TextColor3 = THEME.textSilver
		renderItemsList()
	end)

	tabMatsBtn.MouseButton1Click:Connect(function()
		activeTab = "Materials"
		tabMatsBtn.BackgroundTransparency = 0
		tabMatsBtn.BackgroundColor3 = THEME.amberDim
		tabMatsBtn.TextColor3 = THEME.amberBright
		tabEquipBtn.BackgroundTransparency = 1
		tabEquipBtn.TextColor3 = THEME.textSilver
		renderItemsList()
		renderDetailView(nil)
	end)

	tabsHeader.Parent = midCol

	itemsScroll = Instance.new("ScrollingFrame")
	itemsScroll.Name = "ItemsScroll"
	itemsScroll.Size = UDim2.new(1, -12, 1, -48)
	itemsScroll.Position = UDim2.new(0, 6, 0, 42)
	itemsScroll.BackgroundTransparency = 1
	itemsScroll.BorderSizePixel = 0
	itemsScroll.ScrollBarThickness = 3
	itemsScroll.ScrollBarImageColor3 = THEME.amberDim
	itemsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	itemsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	itemsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	itemsScroll.Parent = midCol

	midCol.Parent = body

	-- Right Column: Item Inspection & Equip Action (fluid width)
	local rightCol = Instance.new("Frame")
	rightCol.Name = "RightInspect"
	rightCol.Size = UDim2.new(1, -602, 1, 0)
	rightCol.Position = UDim2.new(0, 602, 0, 0)
	rightCol.BackgroundColor3 = THEME.panelBg
	rightCol.BorderSizePixel = 0
	makeCorner(rightCol, 6)
	makeStroke(rightCol, THEME.borderDim, 1)
	makePadding(rightCol, 8, 8, 8, 8)

	detailViewContainer = Instance.new("Frame")
	detailViewContainer.Name = "DetailContainer"
	detailViewContainer.Size = UDim2.new(1, 0, 1, -56)
	detailViewContainer.BackgroundTransparency = 1
	detailViewContainer.Parent = rightCol

	-- Equip CTA button at bottom of Right Column
	equipActionButton = Instance.new("TextButton")
	equipActionButton.Name = "EquipButton"
	equipActionButton.Size = UDim2.new(1, 0, 0, 46)
	equipActionButton.Position = UDim2.new(0, 0, 1, -48)
	equipActionButton.BackgroundColor3 = THEME.greenDark
	equipActionButton.BorderSizePixel = 0
	equipActionButton.Text = ""
	equipActionButton.Visible = false
	makeCorner(equipActionButton, 6)
	makeStroke(equipActionButton, THEME.green, 1)

	equipActionLabel = Instance.new("TextLabel")
	equipActionLabel.Text = "EQUIP PIECE"
	equipActionLabel.TextColor3 = THEME.green
	equipActionLabel.TextSize = 16.5
	equipActionLabel.Font = Enum.Font.GothamBold
	equipActionLabel.BackgroundTransparency = 1
	equipActionLabel.Size = UDim2.new(1, 0, 1, 0)
	equipActionLabel.Parent = equipActionButton

	equipActionButton.MouseButton1Click:Connect(function()
		if selectedItemId and equipActionButton.Active then
			Net.Get("RequestEquipEquipment"):FireServer(selectedItemId)
		end
	end)

	equipActionButton.Parent = rightCol
	rightCol.Parent = body
end

-- ============================================================================
-- OPEN / CLOSE / TOGGLE
-- ============================================================================

function InventoryUIController.Open()
	if isOpen then return end
	isOpen = true
	screenGui.Enabled = true

	mainModal.Position = UDim2.new(0.5, 0, 0.5, 32)
	mainModal.BackgroundTransparency = 1
	TweenService:Create(mainModal, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 18),
		BackgroundTransparency = 0,
	}):Play()

	-- If no item selected, default to currently equipped Weapon or first loadout item
	if not selectedItemId then
		selectedItemId = cachedEquippedEquipment["Weapon"]
		if not selectedItemId then
			for _, sName in ipairs(SLOT_ORDER) do
				if cachedEquippedEquipment[sName] then
					selectedItemId = cachedEquippedEquipment[sName]
					break
				end
			end
		end
		if not selectedItemId and #cachedStoredEquipment > 0 then
			selectedItemId = cachedStoredEquipment[1]
		end
	end

	renderLoadoutSlots()
	renderItemsList()
	renderDetailView(selectedItemId)
end

function InventoryUIController.Close()
	if not isOpen then return end
	isOpen = false

	local tween = TweenService:Create(mainModal, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.5, 32),
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		screenGui.Enabled = false
	end)
end

function InventoryUIController.Toggle()
	if isOpen then
		InventoryUIController.Close()
	else
		InventoryUIController.Open()
	end
end

-- ============================================================================
-- START & EVENT LISTENERS
-- ============================================================================

function InventoryUIController.Start()
	buildUI()

	-- Synchronize equipment and materials
	Net.Get("EquipmentDataChanged").OnClientEvent:Connect(function(equippedTable, storedList, materialsMap)
		if equippedTable and type(equippedTable) == "table" then
			cachedEquippedEquipment = equippedTable
		end
		if storedList and type(storedList) == "table" then
			cachedStoredEquipment = storedList
		end
		if materialsMap and type(materialsMap) == "table" then
			cachedCraftingMaterials = materialsMap
		end

		if isOpen then
			renderLoadoutSlots()
			renderItemsList()
			renderDetailView(selectedItemId)
		end
	end)

	-- Synchronize character class
	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(_level: number, _unspentEXP: number, classId: string?)
		if classId and type(classId) == "string" then
			cachedClassId = classId
			if isOpen then
				renderLoadoutSlots()
				renderItemsList()
				renderDetailView(selectedItemId)
			end
		end
	end)
end

return InventoryUIController
