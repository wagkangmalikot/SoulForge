-- src/ReplicatedStorage/Shared/Data/Consumables.lua
-- Definitive consumables registry. Currently health potions only -- no mana
-- potions, since the game has no mana/resource system (skills are
-- cooldown-gated, not resource-gated). See docs/superpowers/specs/2026-09-24-hub-shop-design.md.
--
-- healPercent restores that fraction of the user's CURRENT MaxHealth (so it
-- scales with class -- a Tank's Greater Health Potion heals more raw HP than
-- a Mage's), applied by ShopService.RequestUsePotion.
return {
	MinorHealthPotion = {
		id = "MinorHealthPotion",
		displayName = "Minor Health Potion",
		icon = "rbxasset://textures/Soulforge/minor_health_potion_icon.png",
		description = "A watered-down restorative. Heals 25% of max health.",
		healPercent = 0.25,
		price = 20,
		tier = 1,
	},
	HealthPotion = {
		id = "HealthPotion",
		displayName = "Health Potion",
		icon = "rbxasset://textures/Soulforge/health_potion_icon.png",
		description = "A proper alchemical brew. Heals 50% of max health.",
		healPercent = 0.50,
		price = 50,
		tier = 2,
	},
	GreaterHealthPotion = {
		id = "GreaterHealthPotion",
		displayName = "Greater Health Potion",
		icon = "rbxasset://textures/Soulforge/greater_health_potion_icon.png",
		description = "A masterwork elixir. Fully restores health.",
		healPercent = 1.00,
		price = 120,
		tier = 3,
	},
}
