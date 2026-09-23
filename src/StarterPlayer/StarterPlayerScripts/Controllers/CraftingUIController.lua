-- src/StarterPlayer/StarterPlayerScripts/Controllers/CraftingUIController.lua
-- Monster Hunter-style Crafting UI for Soulforge Armory.
-- Allows crafting individual gear pieces: Weapon, Head, Body, Arms, Feet.
-- Displays Set Bonus progress (e.g. 3/5 pieces) and activates when all 5 are equipped.
-- Stashes future sets (e.g. Sunforged) until released.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local EquipmentData = require(ReplicatedStorage.Shared.Data.Equipment)
local ItemIconHelper = require(ReplicatedStorage.Shared.UI.ItemIconHelper)

local CraftingUIController = {}

-- ============================================================================
-- STATE
-- ============================================================================

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local mainFrame: Frame
local isOpen = false

-- Live player inventory & equipment cache
local cachedCraftingMaterials: {[string]: number} = {}
local cachedStoredEquipment: {string} = {}
local cachedEquippedEquipment: {[string]: string} = {
	Weapon = "StandardSword",
	Head = "StandardHelm",
	Body = "StandardChest",
	Arms = "StandardArms",
	Feet = "StandardFeet",
}

-- Currently selected set & piece
local selectedSetId: string = "Rockhide"
local selectedPieceId: string = "RockhideFang"
local hasManuallySelectedSet = false
local updateSetTabsFunc: (() -> ())? = nil

-- ============================================================================
-- THEME & PALETTE
-- ============================================================================

local THEME = {
	bgDark       = Color3.fromRGB(12, 10, 8),
	panelBg      = Color3.fromRGB(20, 16, 12),
	panelInner   = Color3.fromRGB(27, 21, 15),
	rowBg        = Color3.fromRGB(34, 26, 18),
	rowBgAlt     = Color3.fromRGB(24, 18, 12),
	rowSelected  = Color3.fromRGB(56, 38, 16),
	borderDim    = Color3.fromRGB(70, 50, 25),
	borderBright = Color3.fromRGB(220, 135, 35),

	amberBright  = Color3.fromRGB(255, 175, 45),
	amberDim     = Color3.fromRGB(150, 90, 20),
	emberNeon    = Color3.fromRGB(255, 100, 25),

	textWhite    = Color3.fromRGB(242, 230, 210),
	textSilver   = Color3.fromRGB(180, 165, 135),
	textDim      = Color3.fromRGB(115, 100, 75),
	textDark     = Color3.fromRGB(75, 62, 45),

	green        = Color3.fromRGB(80, 215, 95),
	greenDark    = Color3.fromRGB(25, 65, 30),
	red          = Color3.fromRGB(235, 75, 55),
	redDark      = Color3.fromRGB(65, 20, 15),
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
-- INVENTORY & SET HELPERS
-- ============================================================================

local function isItemOwned(itemId: string): boolean
	for _, id in ipairs(cachedStoredEquipment) do
		if id == itemId then return true end
	end
	return false
end

local function isItemEquipped(itemId: string): boolean
	for _, equippedId in pairs(cachedEquippedEquipment) do
		if equippedId == itemId then return true end
	end
	return false
end

local function canCraftItem(itemId: string): boolean
	local item = EquipmentData.Items[itemId]
	if not item or item.stashed or not item.crafting then return false end
	for matId, needed in pairs(item.crafting.materials or {}) do
		local have = cachedCraftingMaterials[matId] or 0
		if have < needed then return false end
	end
	return true
end

local function getEquippedPieceCount(setId: string): (number, number)
	local setData = EquipmentData.Sets[setId]
	if not setData or not setData.pieces then return 0, 0 end
	local count = 0
	for _, pieceId in ipairs(setData.pieces) do
		if isItemEquipped(pieceId) then
			count += 1
		end
	end
	return count, #setData.pieces
end

-- ============================================================================
-- UI REFERENCES
-- ============================================================================

local piecesListFrame: ScrollingFrame
local detailContainer: Frame
local setBonusBanner: Frame
local setBonusStatusText: TextLabel
local setBonusPipsContainer: Frame
local actionButton: TextButton
local actionButtonLabel: TextLabel
local statusLabel: TextLabel

-- ============================================================================
-- DETAIL PANEL VIEW
-- ============================================================================

local function renderDetailPanel(itemId: string)
	if not detailContainer then return end
	detailContainer:ClearAllChildren()

	local item = EquipmentData.Items[itemId]
	if not item then return end

	local owned = isItemOwned(itemId)
	local equipped = isItemEquipped(itemId)
	local canForge = not owned and canCraftItem(itemId)
	local rarityColor = RARITY_COLOR[item.rarity or "Common"] or THEME.textWhite

	-- ── 1. ITEM TITLE & HEADER CARD ───────────────────────────────────────
	local headerCard = Instance.new("Frame")
	headerCard.Name = "HeaderCard"
	headerCard.Size = UDim2.new(1, 0, 0, 74)
	headerCard.Position = UDim2.new(0, 0, 0, 0)
	headerCard.BackgroundColor3 = THEME.panelInner
	headerCard.BorderSizePixel = 0
	makeCorner(headerCard, 6)
	makeStroke(headerCard, THEME.borderDim, 1)
	makeGradient(headerCard, Color3.fromRGB(36, 28, 18), THEME.panelInner, 90)
	headerCard.Parent = detailContainer

	-- Accent bar on the left edge
	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(0, 4, 1, 0)
	accentBar.BackgroundColor3 = rarityColor
	accentBar.BorderSizePixel = 0
	makeCorner(accentBar, 2)
	accentBar.Parent = headerCard

	-- Item Icon Artwork Tile
	local detailIcon = ItemIconHelper.CreateItemIcon(headerCard, itemId, UDim2.new(0, 56, 0, 56), true)
	detailIcon.Position = UDim2.new(0, 14, 0.5, -28)

	-- Slot Badge (e.g. "[ WEAPON PIECE ]")
	local slotBadge = Instance.new("TextLabel")
	slotBadge.Text = string.format("[ %s PIECE ]", string.upper(item.slot))
	slotBadge.TextColor3 = THEME.amberBright
	slotBadge.TextSize = 14
	slotBadge.Font = Enum.Font.GothamBold
	slotBadge.BackgroundTransparency = 1
	slotBadge.TextXAlignment = Enum.TextXAlignment.Left
	slotBadge.Position = UDim2.new(0, 78, 0, 8)
	slotBadge.Size = UDim2.new(0.6, 0, 0, 18)
	slotBadge.Parent = headerCard

	-- Item Display Name
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = item.displayName or item.id
	titleLabel.TextColor3 = THEME.textWhite
	titleLabel.TextSize = 21
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Position = UDim2.new(0, 78, 0, 27)
	titleLabel.Size = UDim2.new(0.65, 0, 0, 24)
	titleLabel.Parent = headerCard

	-- Tier & Rarity subtitle
	local subLabel = Instance.new("TextLabel")
	subLabel.Text = string.format("Tier %d  ·  %s", item.tier or 1, string.upper(item.rarity or "Common"))
	subLabel.TextColor3 = rarityColor
	subLabel.TextSize = 14
	subLabel.Font = Enum.Font.GothamSemibold
	subLabel.BackgroundTransparency = 1
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Position = UDim2.new(0, 78, 0, 53)
	subLabel.Size = UDim2.new(0.6, 0, 0, 18)
	subLabel.Parent = headerCard

	-- Ownership Status Pill
	local pillBg = equipped and THEME.amberDim or (owned and THEME.greenDark or (canForge and THEME.cyanDark or THEME.panelBg))
	local pillBorder = equipped and THEME.amberBright or (owned and THEME.green or (canForge and THEME.cyan or THEME.borderDim))
	local pillText = equipped and "EQUIPPED" or (owned and "OWNED" or (canForge and "READY TO FORGE" or "LOCKED"))
	local pillTextColor = equipped and THEME.textWhite or (owned and THEME.green or (canForge and THEME.cyan or THEME.textDim))

	local statusPill = Instance.new("Frame")
	statusPill.Size = UDim2.new(0, 120, 0, 28)
	statusPill.Position = UDim2.new(1, -128, 0, 10)
	statusPill.BackgroundColor3 = pillBg
	statusPill.BorderSizePixel = 0
	makeCorner(statusPill, 4)
	makeStroke(statusPill, pillBorder, 1)
	statusPill.Parent = headerCard

	local pillLabel = Instance.new("TextLabel")
	pillLabel.Text = pillText
	pillLabel.TextColor3 = pillTextColor
	pillLabel.TextSize = 13.5
	pillLabel.Font = Enum.Font.GothamBold
	pillLabel.BackgroundTransparency = 1
	pillLabel.Size = UDim2.new(1, 0, 1, 0)
	pillLabel.Parent = statusPill

	-- ── 2. SCROLLABLE DETAILS: STATS + MATERIALS + LORE ────────────────────
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "DetailsScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -82)
	scrollFrame.Position = UDim2.new(0, 0, 0, 80)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 3
	scrollFrame.ScrollBarImageColor3 = THEME.amberDim
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.Parent = detailContainer

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 10)
	contentLayout.Parent = scrollFrame

	-- Item Description / Lore
	if item.description and item.description ~= "" then
		local descFrame = Instance.new("Frame")
		descFrame.Size = UDim2.new(1, -4, 0, 0)
		descFrame.AutomaticSize = Enum.AutomaticSize.Y
		descFrame.BackgroundColor3 = THEME.rowBgAlt
		descFrame.BorderSizePixel = 0
		descFrame.LayoutOrder = 1
		makeCorner(descFrame, 4)
		makePadding(descFrame, 8, 8, 10, 10)
		descFrame.Parent = scrollFrame

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
		descText.Parent = descFrame
	end

	-- ── 3. STATS SECTION ───────────────────────────────────────────────────
	local statsSection = Instance.new("Frame")
	statsSection.Size = UDim2.new(1, -4, 0, 0)
	statsSection.AutomaticSize = Enum.AutomaticSize.Y
	statsSection.BackgroundColor3 = THEME.panelInner
	statsSection.BorderSizePixel = 0
	statsSection.LayoutOrder = 2
	makeCorner(statsSection, 6)
	makeStroke(statsSection, THEME.borderDim, 1)
	makePadding(statsSection, 8, 8, 8, 8)
	statsSection.Parent = scrollFrame

	local statsHeader = Instance.new("TextLabel")
	statsHeader.Text = "ITEM ATTRIBUTES"
	statsHeader.TextColor3 = THEME.amberBright
	statsHeader.TextSize = 14.5
	statsHeader.Font = Enum.Font.GothamBold
	statsHeader.BackgroundTransparency = 1
	statsHeader.TextXAlignment = Enum.TextXAlignment.Left
	statsHeader.Size = UDim2.new(1, 0, 0, 24)
	statsHeader.Parent = statsSection

	local statsList = Instance.new("UIListLayout")
	statsList.SortOrder = Enum.SortOrder.LayoutOrder
	statsList.Padding = UDim.new(0, 3)
	statsList.Parent = statsSection

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

	local statOrder = 1
	for statKey, statVal in pairs(item.stats or {}) do
		local statRow = Instance.new("Frame")
		statRow.Size = UDim2.new(1, 0, 0, 30)
		statRow.BackgroundColor3 = (statOrder % 2 == 0) and THEME.rowBg or THEME.rowBgAlt
		statRow.BorderSizePixel = 0
		statRow.LayoutOrder = statOrder + 1
		makeCorner(statRow, 3)
		makePadding(statRow, 0, 0, 8, 8)
		statRow.Parent = statsSection

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Text = statLabels[statKey] or statKey
		nameLbl.TextColor3 = THEME.textSilver
		nameLbl.TextSize = 14
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Size = UDim2.new(0.65, 0, 1, 0)
		nameLbl.Parent = statRow

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
		valLbl.Parent = statRow

		statOrder += 1
	end

	-- ── 4. MATERIALS REQUIRED SECTION ─────────────────────────────────────
	if item.crafting and item.crafting.materials then
		local matsSection = Instance.new("Frame")
		matsSection.Size = UDim2.new(1, -4, 0, 0)
		matsSection.AutomaticSize = Enum.AutomaticSize.Y
		matsSection.BackgroundColor3 = THEME.panelInner
		matsSection.BorderSizePixel = 0
		matsSection.LayoutOrder = 3
		makeCorner(matsSection, 6)
		makeStroke(matsSection, THEME.borderDim, 1)
		makePadding(matsSection, 8, 8, 8, 8)
		matsSection.Parent = scrollFrame

		local matsHeader = Instance.new("TextLabel")
		matsHeader.Text = "CRAFTING REAGENTS"
		matsHeader.TextColor3 = THEME.amberBright
		matsHeader.TextSize = 14.5
		matsHeader.Font = Enum.Font.GothamBold
		matsHeader.BackgroundTransparency = 1
		matsHeader.TextXAlignment = Enum.TextXAlignment.Left
		matsHeader.Size = UDim2.new(1, 0, 0, 24)
		matsHeader.Parent = matsSection

		local matsList = Instance.new("UIListLayout")
		matsList.SortOrder = Enum.SortOrder.LayoutOrder
		matsList.Padding = UDim.new(0, 4)
		matsList.Parent = matsSection

		local matOrder = 1
		for matId, needed in pairs(item.crafting.materials) do
			local have = cachedCraftingMaterials[matId] or 0
			local enough = have >= needed
			local matDef = EquipmentData.Materials[matId]
			local matName = matDef and matDef.displayName or matId
			local matColor = RARITY_COLOR[matDef and matDef.rarity or "Common"] or THEME.textWhite

			local matRow = Instance.new("Frame")
			matRow.Size = UDim2.new(1, 0, 0, 46)
			matRow.BackgroundColor3 = enough and Color3.fromRGB(18, 30, 20) or Color3.fromRGB(32, 18, 16)
			matRow.BorderSizePixel = 0
			matRow.LayoutOrder = matOrder + 1
			makeCorner(matRow, 4)
			makeStroke(matRow, enough and Color3.fromRGB(35, 75, 40) or Color3.fromRGB(75, 25, 20), 1)
			makePadding(matRow, 0, 0, 8, 8)
			matRow.Parent = matsSection

			-- Procedural Material Icon
			local iconTile = ItemIconHelper.CreateMaterialIcon(matRow, matId, UDim2.new(0, 32, 0, 32))
			iconTile.Position = UDim2.new(0, 0, 0.5, -16)

			-- Material Name
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Text = matName
			nameLbl.TextColor3 = matColor
			nameLbl.TextSize = 15
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.BackgroundTransparency = 1
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Position = UDim2.new(0, 40, 0, 2)
			nameLbl.Size = UDim2.new(0.6, 0, 0, 22)
			nameLbl.Parent = matRow

			-- Fragment note
			local hintLbl = Instance.new("TextLabel")
			hintLbl.Text = (matId == "RockhideFragment") and "Obtained from Rockhide Boss Arena" or "Smelted / Refined Reagent"
			hintLbl.TextColor3 = THEME.textDim
			hintLbl.TextSize = 13
			hintLbl.Font = Enum.Font.Gotham
			hintLbl.BackgroundTransparency = 1
			hintLbl.TextXAlignment = Enum.TextXAlignment.Left
			hintLbl.Position = UDim2.new(0, 40, 0, 24)
			hintLbl.Size = UDim2.new(0.6, 0, 0, 18)
			hintLbl.Parent = matRow

			-- Have / Need Pill (Big & clear)
			local countPill = Instance.new("Frame")
			countPill.Size = UDim2.new(0, 80, 0, 28)
			countPill.Position = UDim2.new(1, -80, 0.5, -14)
			countPill.BackgroundColor3 = enough and THEME.greenDark or THEME.redDark
			countPill.BorderSizePixel = 0
			makeCorner(countPill, 4)
			makeStroke(countPill, enough and THEME.green or THEME.red, 1)
			countPill.Parent = matRow

			local countText = Instance.new("TextLabel")
			countText.Text = string.format("%d / %d", have, needed)
			countText.TextColor3 = enough and THEME.green or THEME.red
			countText.TextSize = 14
			countText.Font = Enum.Font.GothamBold
			countText.BackgroundTransparency = 1
			countText.Size = UDim2.new(1, 0, 1, 0)
			countText.Parent = countPill

			matOrder += 1
		end
	end

	-- ── 5. UPDATE BOTTOM ACTION BUTTON ─────────────────────────────────────
	if actionButton and actionButtonLabel then
		if equipped then
			actionButton.Active = false
			actionButton.BackgroundColor3 = THEME.panelBg
			actionButtonLabel.Text = "CURRENTLY EQUIPPED"
			actionButtonLabel.TextColor3 = THEME.textDim
		elseif owned then
			actionButton.Active = true
			actionButton.BackgroundColor3 = THEME.greenDark
			actionButtonLabel.Text = string.format("EQUIP %s", string.upper(item.slot))
			actionButtonLabel.TextColor3 = THEME.green
		elseif canForge then
			actionButton.Active = true
			actionButton.BackgroundColor3 = THEME.amberDim
			actionButtonLabel.Text = string.format("FORGE %s", string.upper(item.slot))
			actionButtonLabel.TextColor3 = THEME.amberBright
		else
			actionButton.Active = false
			actionButton.BackgroundColor3 = Color3.fromRGB(35, 20, 15)
			actionButtonLabel.Text = "INSUFFICIENT REAGENTS"
			actionButtonLabel.TextColor3 = THEME.red
		end
	end
end

-- ============================================================================
-- SET BONUS BANNER UPDATE
-- ============================================================================

local function updateSetBonusBanner()
	if not setBonusBanner then return end
	local setData = EquipmentData.Sets[selectedSetId]
	if not setData then return end

	local equippedCount, totalPieces = getEquippedPieceCount(selectedSetId)
	local isBonusActive = (equippedCount == totalPieces and totalPieces > 0)

	-- Clear old pips
	if setBonusPipsContainer then
		setBonusPipsContainer:ClearAllChildren()
		for i = 1, totalPieces do
			local pieceId = setData.pieces[i]
			local isThisPieceEquipped = isItemEquipped(pieceId)
			local pip = Instance.new("Frame")
			pip.Size = UDim2.new(0, 22, 0, 22)
			pip.BackgroundColor3 = isThisPieceEquipped and THEME.amberBright or THEME.panelBg
			pip.BorderSizePixel = 0
			makeCorner(pip, 3)
			makeStroke(pip, isThisPieceEquipped and THEME.borderBright or THEME.borderDim, 1)

			local pieceItem = EquipmentData.Items[pieceId]
			local slotChar = pieceItem and string.sub(pieceItem.slot, 1, 1) or tostring(i)
			local pipIcon = Instance.new("TextLabel")
			pipIcon.Text = slotChar
			pipIcon.Font = Enum.Font.GothamBold
			pipIcon.TextSize = 12.5
			pipIcon.TextColor3 = isThisPieceEquipped and THEME.bgDark or THEME.textDim
			pipIcon.BackgroundTransparency = 1
			pipIcon.Size = UDim2.new(1, 0, 1, 0)
			pipIcon.Parent = pip

			pip.Parent = setBonusPipsContainer
		end
	end

	if setBonusStatusText then
		if isBonusActive then
			setBonusStatusText.Text = string.format("SET EFFECT ACTIVE (%d/%d): %s — %s", equippedCount, totalPieces, setData.setBonus, setData.setBonusDesc or "")
			setBonusStatusText.TextColor3 = THEME.amberBright
		else
			setBonusStatusText.Text = string.format("SET BONUS (%d/%d): %s — %s", equippedCount, totalPieces, setData.setBonus or "None", setData.setBonusDesc or "")
			setBonusStatusText.TextColor3 = THEME.textSilver
		end
	end
end

-- ============================================================================
-- PIECES LIST VIEW (LEFT PANEL)
-- ============================================================================

local function renderPiecesList()
	if not piecesListFrame then return end
	piecesListFrame:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = piecesListFrame

	local setData = EquipmentData.Sets[selectedSetId]
	if not setData or not setData.pieces then return end

	for index, pieceId in ipairs(setData.pieces) do
		local item = EquipmentData.Items[pieceId]
		if not item or item.stashed then continue end

		local owned = isItemOwned(pieceId)
		local equipped = isItemEquipped(pieceId)
		local canForge = not owned and canCraftItem(pieceId)
		local isSelected = (selectedPieceId == pieceId)
		local rarityColor = RARITY_COLOR[item.rarity or "Common"] or THEME.textWhite

		local cardBg = isSelected and THEME.rowSelected or (equipped and Color3.fromRGB(35, 26, 15) or THEME.rowBg)

		local card = Instance.new("TextButton")
		card.Name = "PieceCard_" .. pieceId
		card.Size = UDim2.new(1, -4, 0, 62)
		card.BackgroundColor3 = cardBg
		card.BorderSizePixel = 0
		card.Text = ""
		card.LayoutOrder = index
		makeCorner(card, 5)

		if isSelected then
			makeStroke(card, THEME.borderBright, 2)
		else
			makeStroke(card, equipped and THEME.borderBright or THEME.borderDim, 1)
		end

		-- Procedural Vector Item Icon
		local iconTile = ItemIconHelper.CreateItemIcon(card, pieceId, UDim2.new(0, 42, 0, 42), isSelected)
		iconTile.Position = UDim2.new(0, 8, 0.5, -21)

		-- Item name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text = item.displayName or item.id
		nameLabel.TextColor3 = isSelected and THEME.amberBright or THEME.textWhite
		nameLabel.TextSize = 15.5
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Position = UDim2.new(0, 56, 0, 8)
		nameLabel.Size = UDim2.new(1, -148, 0, 22)
		nameLabel.Parent = card

		-- Slot & Rarity subtitle
		local subLabel = Instance.new("TextLabel")
		subLabel.Text = string.format("%s · Tier %d %s", string.upper(item.slot), item.tier or 1, item.rarity or "Common")
		subLabel.TextColor3 = rarityColor
		subLabel.TextSize = 13.5
		subLabel.Font = Enum.Font.Gotham
		subLabel.BackgroundTransparency = 1
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.Position = UDim2.new(0, 56, 0, 32)
		subLabel.Size = UDim2.new(1, -148, 0, 18)
		subLabel.Parent = card

		-- State Pill (EQUIPPED / OWNED / READY / LOCKED)
		local pillBg = equipped and THEME.amberDim or (owned and THEME.greenDark or (canForge and THEME.cyanDark or THEME.panelBg))
		local pillBorder = equipped and THEME.amberBright or (owned and THEME.green or (canForge and THEME.cyan or THEME.borderDim))
		local pillText = equipped and "EQUIPPED" or (owned and "OWNED" or (canForge and "READY" or "LOCKED"))
		local pillColor = equipped and THEME.amberBright or (owned and THEME.green or (canForge and THEME.cyan or THEME.textDim))

		local statePill = Instance.new("Frame")
		statePill.Size = UDim2.new(0, 82, 0, 24)
		statePill.Position = UDim2.new(1, -88, 0.5, -12)
		statePill.BackgroundColor3 = pillBg
		statePill.BorderSizePixel = 0
		makeCorner(statePill, 4)
		makeStroke(statePill, pillBorder, 1)
		statePill.Parent = card

		local stateLabel = Instance.new("TextLabel")
		stateLabel.Text = pillText
		stateLabel.TextColor3 = pillColor
		stateLabel.TextSize = 13
		stateLabel.Font = Enum.Font.GothamBold
		stateLabel.BackgroundTransparency = 1
		stateLabel.Size = UDim2.new(1, 0, 1, 0)
		stateLabel.Parent = statePill

		card.MouseButton1Click:Connect(function()
			selectedPieceId = pieceId
			renderPiecesList()
			renderDetailPanel(pieceId)
		end)

		card.Parent = piecesListFrame
	end
end

-- ============================================================================
-- FULL UI BUILDER
-- ============================================================================

local function buildUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CraftingUI"
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
		CraftingUIController.Close()
	end)

	-- Main Modal Frame (920 × 600)
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainModal"
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Size = UDim2.new(0, 940, 0, 600)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 18)
	mainFrame.BackgroundColor3 = THEME.bgDark
	mainFrame.BorderSizePixel = 0
	mainFrame.ZIndex = 10
	makeCorner(mainFrame, 8)
	makeStroke(mainFrame, THEME.borderBright, 2)
	makeGradient(mainFrame, Color3.fromRGB(24, 18, 12), THEME.bgDark, 90)
	mainFrame.Parent = screenGui

	local modalScale = Instance.new("UIScale")
	modalScale.Name = "ModalScale"
	modalScale.Parent = mainFrame

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

	-- ── HEADER ────────────────────────────────────────────────────────────
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BackgroundColor3 = Color3.fromRGB(18, 14, 8)
	header.BorderSizePixel = 0
	header.ZIndex = 11
	makeCorner(header, 8)
	makeGradient(header, Color3.fromRGB(45, 30, 12), Color3.fromRGB(18, 14, 8), 90)

	-- Amber accent line beneath header
	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, 0, 0, 2)
	headerLine.Position = UDim2.new(0, 0, 1, -2)
	headerLine.BackgroundColor3 = THEME.borderBright
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Text = "SOULFORGE FORGE  ·  ROCKHIDE CRAFTING"
	headerTitle.TextColor3 = THEME.amberBright
	headerTitle.TextSize = 22
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.BackgroundTransparency = 1
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Position = UDim2.new(0, 16, 0, 6)
	headerTitle.Size = UDim2.new(0.55, 0, 0, 26)
	headerTitle.Parent = header

	local headerSubtitle = Instance.new("TextLabel")
	headerSubtitle.Text = "Forge boss weapons and armor pieces from collected fragments"
	headerSubtitle.TextColor3 = THEME.textSilver
	headerSubtitle.TextSize = 14.5
	headerSubtitle.Font = Enum.Font.GothamMedium
	headerSubtitle.BackgroundTransparency = 1
	headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	headerSubtitle.Position = UDim2.new(0, 16, 0, 32)
	headerSubtitle.Size = UDim2.new(0.55, 0, 0, 20)
	headerSubtitle.Parent = header

	-- Gold display pill
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
		CraftingUIController.Close()
	end)

	header.Parent = mainFrame

	-- ── SET BONUS BANNER (Top of content) ──────────────────────────────────
	setBonusBanner = Instance.new("Frame")
	setBonusBanner.Name = "SetBonusBanner"
	setBonusBanner.Size = UDim2.new(1, -20, 0, 48)
	setBonusBanner.Position = UDim2.new(0, 10, 0, 64)
	setBonusBanner.BackgroundColor3 = Color3.fromRGB(28, 20, 10)
	setBonusBanner.BorderSizePixel = 0
	setBonusBanner.ZIndex = 11
	makeCorner(setBonusBanner, 6)
	makeStroke(setBonusBanner, THEME.borderDim, 1)
	makeGradient(setBonusBanner, Color3.fromRGB(38, 26, 12), Color3.fromRGB(22, 16, 8), 90)

	setBonusStatusText = Instance.new("TextLabel")
	setBonusStatusText.Name = "StatusText"
	setBonusStatusText.Text = "SET BONUS: Loading..."
	setBonusStatusText.TextColor3 = THEME.textSilver
	setBonusStatusText.TextSize = 13.5
	setBonusStatusText.Font = Enum.Font.GothamBold
	setBonusStatusText.BackgroundTransparency = 1
	setBonusStatusText.TextXAlignment = Enum.TextXAlignment.Left
	setBonusStatusText.Position = UDim2.new(0, 12, 0, 0)
	setBonusStatusText.Size = UDim2.new(1, -140, 1, 0)
	setBonusStatusText.Parent = setBonusBanner

	-- Pips container on right (showing 5 slots)
	setBonusPipsContainer = Instance.new("Frame")
	setBonusPipsContainer.Name = "PipsContainer"
	setBonusPipsContainer.Size = UDim2.new(0, 135, 1, 0)
	setBonusPipsContainer.Position = UDim2.new(1, -145, 0, 0)
	setBonusPipsContainer.BackgroundTransparency = 1
	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection = Enum.FillDirection.Horizontal
	pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipLayout.Padding = UDim.new(0, 4)
	pipLayout.Parent = setBonusPipsContainer
	setBonusPipsContainer.Parent = setBonusBanner

	setBonusBanner.Parent = mainFrame

	-- ── BODY: LEFT PANEL (PIECE SELECTOR) + RIGHT PANEL (DETAILS) ──────────
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -20, 1, -178)
	body.Position = UDim2.new(0, 10, 0, 118)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ZIndex = 11
	body.Parent = mainFrame

	-- Left Panel: Pieces list (340px)
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0, 340, 1, 0)
	leftPanel.BackgroundColor3 = THEME.panelBg
	leftPanel.BorderSizePixel = 0
	makeCorner(leftPanel, 6)
	makeStroke(leftPanel, THEME.borderDim, 1)

	local leftHeader = Instance.new("Frame")
	leftHeader.Name = "SetTabsHeader"
	leftHeader.Size = UDim2.new(1, 0, 0, 72)
	leftHeader.BackgroundColor3 = THEME.panelInner
	leftHeader.BorderSizePixel = 0
	makeCorner(leftHeader, 6)

	-- Row 1: Tier 2 (Rockhide)
	local rockhideTab = Instance.new("TextButton")
	rockhideTab.Name = "RockhideTankTab"
	rockhideTab.Size = UDim2.new(0.5, -5, 0, 30)
	rockhideTab.Position = UDim2.new(0, 3, 0, 3)
	rockhideTab.BackgroundColor3 = (selectedSetId == "Rockhide") and THEME.rowSelected or THEME.panelBg
	rockhideTab.Text = "🛡️ WARLORD [T2]"
	rockhideTab.Font = Enum.Font.GothamBold
	rockhideTab.TextSize = 11.5
	rockhideTab.TextColor3 = (selectedSetId == "Rockhide") and THEME.amberBright or THEME.textDim
	rockhideTab.BorderSizePixel = 0
	makeCorner(rockhideTab, 4)
	local rockhideStroke = makeStroke(rockhideTab, (selectedSetId == "Rockhide") and THEME.borderBright or THEME.borderDim, 1)
	rockhideTab.Parent = leftHeader

	local rockhideMageTab = Instance.new("TextButton")
	rockhideMageTab.Name = "RockhideMageTab"
	rockhideMageTab.Size = UDim2.new(0.5, -5, 0, 30)
	rockhideMageTab.Position = UDim2.new(0.5, 2, 0, 3)
	rockhideMageTab.BackgroundColor3 = (selectedSetId == "RockhideMage") and THEME.rowSelected or THEME.panelBg
	rockhideMageTab.Text = "🔮 GEOMANCER [T2]"
	rockhideMageTab.Font = Enum.Font.GothamBold
	rockhideMageTab.TextSize = 11.5
	rockhideMageTab.TextColor3 = (selectedSetId == "RockhideMage") and THEME.amberBright or THEME.textDim
	rockhideMageTab.BorderSizePixel = 0
	makeCorner(rockhideMageTab, 4)
	local rockhideMageStroke = makeStroke(rockhideMageTab, (selectedSetId == "RockhideMage") and THEME.borderBright or THEME.borderDim, 1)
	rockhideMageTab.Parent = leftHeader

	-- Row 2: Tier 3 (Sunforged)
	local sunforgedTab = Instance.new("TextButton")
	sunforgedTab.Name = "SunforgedTankTab"
	sunforgedTab.Size = UDim2.new(0.5, -5, 0, 30)
	sunforgedTab.Position = UDim2.new(0, 3, 0, 37)
	sunforgedTab.BackgroundColor3 = (selectedSetId == "Sunforged") and THEME.rowSelected or THEME.panelBg
	sunforgedTab.Text = "☀️ SUNFORGED [T3]"
	sunforgedTab.Font = Enum.Font.GothamBold
	sunforgedTab.TextSize = 11.5
	sunforgedTab.TextColor3 = (selectedSetId == "Sunforged") and THEME.amberBright or THEME.textDim
	sunforgedTab.BorderSizePixel = 0
	makeCorner(sunforgedTab, 4)
	local sunforgedStroke = makeStroke(sunforgedTab, (selectedSetId == "Sunforged") and THEME.borderBright or THEME.borderDim, 1)
	sunforgedTab.Parent = leftHeader

	local sunforgedMageTab = Instance.new("TextButton")
	sunforgedMageTab.Name = "SunforgedMageTab"
	sunforgedMageTab.Size = UDim2.new(0.5, -5, 0, 30)
	sunforgedMageTab.Position = UDim2.new(0.5, 2, 0, 37)
	sunforgedMageTab.BackgroundColor3 = (selectedSetId == "SunforgedMage") and THEME.rowSelected or THEME.panelBg
	sunforgedMageTab.Text = "✨ RADIANT [T3]"
	sunforgedMageTab.Font = Enum.Font.GothamBold
	sunforgedMageTab.TextSize = 11.5
	sunforgedMageTab.TextColor3 = (selectedSetId == "SunforgedMage") and THEME.amberBright or THEME.textDim
	sunforgedMageTab.BorderSizePixel = 0
	makeCorner(sunforgedMageTab, 4)
	local sunforgedMageStroke = makeStroke(sunforgedMageTab, (selectedSetId == "SunforgedMage") and THEME.borderBright or THEME.borderDim, 1)
	sunforgedMageTab.Parent = leftHeader

	local function updateSetTabs()
		local isRTank = (selectedSetId == "Rockhide")
		rockhideTab.BackgroundColor3 = isRTank and THEME.rowSelected or THEME.panelBg
		rockhideTab.TextColor3 = isRTank and THEME.amberBright or THEME.textDim
		rockhideStroke.Color = isRTank and THEME.borderBright or THEME.borderDim

		local isRMage = (selectedSetId == "RockhideMage")
		rockhideMageTab.BackgroundColor3 = isRMage and THEME.rowSelected or THEME.panelBg
		rockhideMageTab.TextColor3 = isRMage and THEME.amberBright or THEME.textDim
		rockhideMageStroke.Color = isRMage and THEME.borderBright or THEME.borderDim

		local isSTank = (selectedSetId == "Sunforged")
		sunforgedTab.BackgroundColor3 = isSTank and THEME.rowSelected or THEME.panelBg
		sunforgedTab.TextColor3 = isSTank and THEME.amberBright or THEME.textDim
		sunforgedStroke.Color = isSTank and THEME.borderBright or THEME.borderDim

		local isSMage = (selectedSetId == "SunforgedMage")
		sunforgedMageTab.BackgroundColor3 = isSMage and THEME.rowSelected or THEME.panelBg
		sunforgedMageTab.TextColor3 = isSMage and THEME.amberBright or THEME.textDim
		sunforgedMageStroke.Color = isSMage and THEME.borderBright or THEME.borderDim
	end
	updateSetTabsFunc = updateSetTabs

	rockhideTab.Activated:Connect(function()
		hasManuallySelectedSet = true
		if selectedSetId == "Rockhide" then return end
		selectedSetId = "Rockhide"
		selectedPieceId = "RockhideFang"
		updateSetTabs()
		updateSetBonusBanner()
		renderPiecesList()
		renderDetailPanel(selectedPieceId)
	end)

	rockhideMageTab.Activated:Connect(function()
		hasManuallySelectedSet = true
		if selectedSetId == "RockhideMage" then return end
		selectedSetId = "RockhideMage"
		selectedPieceId = "RockhideStaff"
		updateSetTabs()
		updateSetBonusBanner()
		renderPiecesList()
		renderDetailPanel(selectedPieceId)
	end)

	sunforgedTab.Activated:Connect(function()
		hasManuallySelectedSet = true
		if selectedSetId == "Sunforged" then return end
		selectedSetId = "Sunforged"
		selectedPieceId = "SunforgedSword"
		updateSetTabs()
		updateSetBonusBanner()
		renderPiecesList()
		renderDetailPanel(selectedPieceId)
	end)

	sunforgedMageTab.Activated:Connect(function()
		hasManuallySelectedSet = true
		if selectedSetId == "SunforgedMage" then return end
		selectedSetId = "SunforgedMage"
		selectedPieceId = "SunforgedStaff"
		updateSetTabs()
		updateSetBonusBanner()
		renderPiecesList()
		renderDetailPanel(selectedPieceId)
	end)

	leftHeader.Parent = leftPanel

	piecesListFrame = Instance.new("ScrollingFrame")
	piecesListFrame.Name = "PiecesScroll"
	piecesListFrame.Size = UDim2.new(1, -12, 1, -84)
	piecesListFrame.Position = UDim2.new(0, 6, 0, 78)
	piecesListFrame.BackgroundTransparency = 1
	piecesListFrame.BorderSizePixel = 0
	piecesListFrame.ScrollBarThickness = 3
	piecesListFrame.ScrollBarImageColor3 = THEME.amberDim
	piecesListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	piecesListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	piecesListFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	piecesListFrame.Parent = leftPanel

	leftPanel.Parent = body

	-- Right Panel: Item Details (fluid width)
	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "RightPanel"
	rightPanel.Size = UDim2.new(1, -350, 1, 0)
	rightPanel.Position = UDim2.new(0, 350, 0, 0)
	rightPanel.BackgroundColor3 = THEME.panelBg
	rightPanel.BorderSizePixel = 0
	makeCorner(rightPanel, 6)
	makeStroke(rightPanel, THEME.borderDim, 1)
	makePadding(rightPanel, 8, 8, 8, 8)

	detailContainer = Instance.new("Frame")
	detailContainer.Name = "DetailContainer"
	detailContainer.Size = UDim2.new(1, 0, 1, 0)
	detailContainer.BackgroundTransparency = 1
	detailContainer.Parent = rightPanel

	rightPanel.Parent = body

	-- ── FOOTER BAR ─────────────────────────────────────────────────────────
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Size = UDim2.new(1, -20, 0, 48)
	footer.Position = UDim2.new(0, 10, 1, -54)
	footer.BackgroundColor3 = THEME.panelBg
	footer.BorderSizePixel = 0
	footer.ZIndex = 11
	makeCorner(footer, 6)
	makeStroke(footer, THEME.borderDim, 1)

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Text = ""
	statusLabel.TextColor3 = THEME.green
	statusLabel.TextSize = 15
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Position = UDim2.new(0, 16, 0, 0)
	statusLabel.Size = UDim2.new(0.6, 0, 1, 0)
	statusLabel.Parent = footer

	actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Size = UDim2.new(0, 240, 0, 44)
	actionButton.Position = UDim2.new(1, -248, 0.5, -22)
	actionButton.BackgroundColor3 = THEME.amberDim
	actionButton.BorderSizePixel = 0
	actionButton.Text = ""
	makeCorner(actionButton, 6)
	makeStroke(actionButton, THEME.borderBright, 1)

	actionButtonLabel = Instance.new("TextLabel")
	actionButtonLabel.Text = "FORGE PIECE"
	actionButtonLabel.TextColor3 = THEME.amberBright
	actionButtonLabel.TextSize = 16.5
	actionButtonLabel.Font = Enum.Font.GothamBold
	actionButtonLabel.BackgroundTransparency = 1
	actionButtonLabel.Size = UDim2.new(1, 0, 1, 0)
	actionButtonLabel.Parent = actionButton

	actionButton.MouseButton1Click:Connect(function()
		if not selectedPieceId or not actionButton.Active then return end

		local item = EquipmentData.Items[selectedPieceId]
		if not item then return end

		if isItemOwned(selectedPieceId) then
			-- Already owned: Equip action
			Net.Get("RequestEquipEquipment"):FireServer(selectedPieceId)
		else
			-- Craft action
			actionButton.Active = false
			actionButton.BackgroundColor3 = THEME.panelBg
			actionButtonLabel.Text = "FORGING..."
			actionButtonLabel.TextColor3 = THEME.textDim

			Net.Get("RequestCraftItem"):FireServer(selectedPieceId)
		end
	end)

	actionButton.Parent = footer
	footer.Parent = mainFrame
end

-- ============================================================================
-- OPEN / CLOSE MODAL
-- ============================================================================

function CraftingUIController.Open()
	if isOpen then return end
	isOpen = true
	screenGui.Enabled = true

	if not hasManuallySelectedSet then
		local isMage = false
		if cachedEquippedEquipment and cachedEquippedEquipment.Weapon then
			local eq = EquipmentData.Items[cachedEquippedEquipment.Weapon]
			if eq and eq.archetype == "Mage" then
				isMage = true
			end
		end
		if isMage then
			selectedSetId = "RockhideMage"
			selectedPieceId = "RockhideStaff"
		else
			selectedSetId = "Rockhide"
			selectedPieceId = "RockhideFang"
		end
		if updateSetTabsFunc then
			updateSetTabsFunc()
		end
	end

	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 32)
	mainFrame.BackgroundTransparency = 1
	TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 18),
		BackgroundTransparency = 0,
	}):Play()

	updateSetBonusBanner()
	renderPiecesList()
	renderDetailPanel(selectedPieceId)
end

function CraftingUIController.Toggle()
	if not screenGui then return end
	if isOpen then
		CraftingUIController.Close()
	else
		CraftingUIController.Open()
	end
end

function CraftingUIController.Close()
	if not isOpen then return end
	isOpen = false

	local tween = TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.5, 32),
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		screenGui.Enabled = false
	end)
end

-- ============================================================================
-- STATUS NOTIFICATION
-- ============================================================================

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

-- ============================================================================
-- START & EVENT LISTENERS
-- ============================================================================

function CraftingUIController.Start()
	buildUI()

	-- Server requests opening crafting UI (via Forge ProximityPrompt)
	Net.Get("OpenCraftingUI").OnClientEvent:Connect(function()
		CraftingUIController.Open()
	end)

	-- Server reports result of crafting an item
	Net.Get("CraftingResult").OnClientEvent:Connect(function(success: boolean, message: string, newStored: {string}?, newMats: {[string]: number}?)
		if newStored then cachedStoredEquipment = newStored end
		if newMats then cachedCraftingMaterials = newMats end

		showStatus(message, success)

		if isOpen then
			updateSetBonusBanner()
			renderPiecesList()
			renderDetailPanel(selectedPieceId)
		end
	end)

	-- Sync equipped gear & materials whenever changed
	Net.Get("EquipmentDataChanged").OnClientEvent:Connect(function(equippedTable: {[string]: string}, storedList: {string}, materialsMap: {[string]: number})
		if equippedTable and type(equippedTable) == "table" then
			cachedEquippedEquipment = equippedTable
			if not hasManuallySelectedSet and equippedTable.Weapon then
				local eq = EquipmentData.Items[equippedTable.Weapon]
				if eq and eq.archetype == "Mage" then
					selectedSetId = "RockhideMage"
					selectedPieceId = "RockhideStaff"
				elseif eq and eq.archetype == "Tank" then
					selectedSetId = "Rockhide"
					selectedPieceId = "RockhideFang"
				end
				if updateSetTabsFunc then
					updateSetTabsFunc()
				end
			end
		end
		if storedList and type(storedList) == "table" then
			cachedStoredEquipment = storedList
		end
		if materialsMap and type(materialsMap) == "table" then
			cachedCraftingMaterials = materialsMap
		end

		if isOpen then
			updateSetBonusBanner()
			renderPiecesList()
			renderDetailPanel(selectedPieceId)
		end
	end)

	Net.Get("CharacterDataChanged").OnClientEvent:Connect(function(_level: number, _unspentEXP: number, classId: string?)
		if classId and not hasManuallySelectedSet then
			if classId == "Mage" then
				selectedSetId = "RockhideMage"
				selectedPieceId = "RockhideStaff"
			else
				selectedSetId = "Rockhide"
				selectedPieceId = "RockhideFang"
			end
			if updateSetTabsFunc then
				updateSetTabsFunc()
			end
			if isOpen then
				updateSetBonusBanner()
				renderPiecesList()
				renderDetailPanel(selectedPieceId)
			end
		end
	end)
end

return CraftingUIController
