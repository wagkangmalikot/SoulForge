-- src/ServerScriptService/Services/ShopService.lua
-- Handles the Hub shop: validates and processes potion purchases (Gold ->
-- Consumables) and potion use (Consumables -> health restored). Mirrors
-- CraftingService.lua's split: this file owns Gold/Consumables truth and
-- validation, client UI is a dumb renderer reacting to ShopResult/PotionUseResult.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RespawnService = require(script.Parent.RespawnService)
local ConsumablesData = require(ReplicatedStorage.Shared.Data.Consumables)

local ShopService = {}

-- userId -> last potion-use os.clock() timestamp. Server-tracked so a client
-- can't bypass the cooldown by skipping its own local cooldown check -- same
-- pattern as CombatService's lastCastAt.
local lastPotionUseAt: {[number]: number} = {}

local POTION_USE_COOLDOWN = 12 -- seconds; matches Taunt's cooldown scale so it can't trivialize combat

-- ============================================================================
-- START (hooks up remote event listeners)
-- ============================================================================

function ShopService.Start()
	-- Handles a purchase request from the Shop UI.
	Net.Get("RequestBuyPotion").OnServerEvent:Connect(function(player: Player, itemId: string)
		local profile = PlayerDataService.GetProfile(player)
		local charData = profile and profile.Data.Character
		if not charData then
			Net.Get("ShopResult"):FireClient(player, false, "Character data not found.", nil)
			return
		end

		local item = ConsumablesData[itemId]
		if not item then
			Net.Get("ShopResult"):FireClient(player, false, ("Unknown item: %q"):format(tostring(itemId)), nil)
			return
		end

		local gold = charData.Gold or 0
		if gold < item.price then
			Net.Get("ShopResult"):FireClient(player, false, ("Not enough Gold (have %d, need %d)"):format(gold, item.price), nil)
			return
		end

		charData.Gold = gold - item.price
		charData.Consumables = charData.Consumables or {}
		charData.Consumables[itemId] = (charData.Consumables[itemId] or 0) + 1

		Net.Get("ShopResult"):FireClient(player, true, ("Purchased: %s!"):format(item.displayName), charData.Consumables)

		print(("[ShopService] %s bought %q for %d Gold"):format(player.Name, itemId, item.price))
	end)

	-- Handles a drink-potion request from the HUD quick-use slot.
	Net.Get("RequestUsePotion").OnServerEvent:Connect(function(player: Player, itemId: string)
		local profile = PlayerDataService.GetProfile(player)
		local charData = profile and profile.Data.Character
		if not charData then
			Net.Get("PotionUseResult"):FireClient(player, false, "Character data not found.", nil)
			return
		end

		local item = ConsumablesData[itemId]
		if not item then
			Net.Get("PotionUseResult"):FireClient(player, false, ("Unknown item: %q"):format(tostring(itemId)), nil)
			return
		end

		local owned = (charData.Consumables and charData.Consumables[itemId]) or 0
		if owned <= 0 then
			Net.Get("PotionUseResult"):FireClient(player, false, "You don't own any " .. item.displayName .. ".", nil)
			return
		end

		if RespawnService.IsPlayerDowned(player.UserId) then
			Net.Get("PotionUseResult"):FireClient(player, false, "Can't drink a potion while downed.", nil)
			return
		end

		local now = os.clock()
		local lastUse = lastPotionUseAt[player.UserId]
		if lastUse and (now - lastUse) < POTION_USE_COOLDOWN then
			Net.Get("PotionUseResult"):FireClient(player, false, "Potion is on cooldown.", nil)
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			Net.Get("PotionUseResult"):FireClient(player, false, "No character to heal.", nil)
			return
		end

		if humanoid.Health >= humanoid.MaxHealth then
			Net.Get("PotionUseResult"):FireClient(player, false, "Already at full health.", nil)
			return
		end

		lastPotionUseAt[player.UserId] = now
		charData.Consumables[itemId] = owned - 1

		local healAmount = math.floor(humanoid.MaxHealth * item.healPercent)
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
		Net.Get("HealthChanged"):FireAllClients(player.UserId, humanoid.Health, humanoid.MaxHealth)

		Net.Get("PotionUseResult"):FireClient(player, true, ("Drank %s (+%d HP)."):format(item.displayName, healAmount), charData.Consumables)

		print(("[ShopService] %s used %q"):format(player.Name, itemId))
	end)

	-- Handles the HUD/Shop UI's initial owned-potion-counts request on load.
	Net.Get("RequestConsumablesSync").OnServerEvent:Connect(function(player: Player)
		local profile = PlayerDataService.GetProfile(player)
		local charData = profile and profile.Data.Character
		Net.Get("ConsumablesSynced"):FireClient(player, (charData and charData.Consumables) or {})
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastPotionUseAt[player.UserId] = nil
	end)

	print("[ShopService] Started.")
end

return ShopService
