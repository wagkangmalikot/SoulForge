-- src/ServerScriptService/Services/CraftingService.lua
-- Handles the crafting system: validates recipes, deducts materials from player inventory,
-- adds crafted individual gear pieces to StoredEquipment, and syncs all equipment state back to the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EquipmentData = require(ReplicatedStorage.Shared.Data.Equipment)

local CraftingService = {}

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Returns true if the player has enough materials for the given recipe.
local function hasEnoughMaterials(craftingMaterials: {[string]: number}, recipe: {[string]: number}): (boolean, string?)
	for materialId, requiredAmount in pairs(recipe) do
		local owned = craftingMaterials[materialId] or 0
		if owned < requiredAmount then
			local matDef = EquipmentData.Materials[materialId]
			local matName = matDef and matDef.displayName or materialId
			return false, ("Not enough %s (have %d, need %d)"):format(matName, owned, requiredAmount)
		end
	end
	return true, nil
end

--- Deducts materials from player's crafting materials (kept unlimited for testing).
local function deductMaterials(craftingMaterials: {[string]: number}, recipe: {[string]: number})
	for materialId, _ in pairs(recipe) do
		craftingMaterials[materialId] = 99999
	end
end

--- Returns true if the player already owns the given itemId.
local function alreadyOwnsItem(storedEquipment: {string}, itemId: string): boolean
	for _, ownedId in ipairs(storedEquipment) do
		if ownedId == itemId then
			return true
		end
	end
	return false
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Syncs equipment state to client after any crafting or equipping action.
function CraftingService.SyncEquipmentToClient(player: Player, charData: {})
	local isMage = (charData and charData.ClassId == "Mage")
	Net.Get("EquipmentDataChanged"):FireClient(
		player,
		charData.EquippedEquipment or {
			Weapon = isMage and "ApprenticeStaff" or "StandardSword",
			Head = isMage and "ApprenticeHood" or "StandardHelm",
			Body = isMage and "ApprenticeRobe" or "StandardChest",
			Arms = isMage and "ApprenticeBracers" or "StandardArms",
			Feet = isMage and "ApprenticeBoots" or "StandardFeet",
		},
		charData.StoredEquipment or {},
		charData.CraftingMaterials or {}
	)
end

-- ============================================================================
-- START (hooks up remote event listeners)
-- ============================================================================

function CraftingService.Start()
	-- Handles individual piece crafting requests from client UI
	Net.Get("RequestCraftItem").OnServerEvent:Connect(function(player: Player, itemId: string)
		local profile = PlayerDataService.GetProfile(player)
		local charData = profile and profile.Data.Character
		if not charData then
			Net.Get("CraftingResult"):FireClient(player, false, "Character data not found.", nil, nil)
			return
		end

		-- Validate the item exists and is craftable (not stashed)
		local item = EquipmentData.Items[itemId]
		if not item or item.stashed or not item.crafting then
			Net.Get("CraftingResult"):FireClient(player, false, ("Item cannot be crafted: %q"):format(tostring(itemId)), nil, nil)
			return
		end

		-- Check if player already owns this item
		local storedEquipment = charData.StoredEquipment or {}
		if alreadyOwnsItem(storedEquipment, itemId) then
			Net.Get("CraftingResult"):FireClient(player, false, "You already own the " .. item.displayName .. ".", nil, nil)
			return
		end

		-- Validate player level if specified
		local levelRequired = item.crafting.levelRequired or 1
		local currentLevel = charData.Level or 1
		if currentLevel < levelRequired then
			Net.Get("CraftingResult"):FireClient(player, false, ("Requires Level %d (You are Level %d)"):format(levelRequired, currentLevel), nil, nil)
			return
		end

		-- Validate materials
		local recipe = item.crafting.materials or {}
		local craftingMaterials = charData.CraftingMaterials or {}
		local canCraft, failReason = hasEnoughMaterials(craftingMaterials, recipe)
		if not canCraft then
			Net.Get("CraftingResult"):FireClient(player, false, failReason, nil, nil)
			return
		end

		-- Deduct materials and grant the item
		deductMaterials(craftingMaterials, recipe)
		charData.CraftingMaterials = craftingMaterials

		table.insert(storedEquipment, itemId)
		charData.StoredEquipment = storedEquipment

		-- Fire success back to client with updated inventory
		Net.Get("CraftingResult"):FireClient(
			player,
			true,
			("Forged: %s!"):format(item.displayName),
			storedEquipment,
			craftingMaterials
		)

		-- Also fire EquipmentDataChanged to refresh any other equipment-aware UI
		CraftingService.SyncEquipmentToClient(player, charData)

		print(("[CraftingService] %s crafted item %q (%s)"):format(player.Name, itemId, item.displayName))
	end)

	print("[CraftingService] Started.")
end

return CraftingService
