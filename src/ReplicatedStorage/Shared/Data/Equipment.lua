-- src/ReplicatedStorage/Shared/Data/Equipment.lua
-- Equipment and Crafting Item Registry for Soulforge.
-- Stores item definitions, tiers, base stats, and crafting recipes for future crafting systems.

local Equipment = {
	-- -- EQUIPMENT SETS & ITEMS ------------------------------------------------
	Items = {
		-- -- Standard Tier 1 (Regular / Standard Adventurer Gear) --------------
		StandardSword = {
			id = "StandardSword",
			setId = "Standard",
			displayName = "Adventurer's Iron Sword",
			slot = "Weapon",
			tier = 1,
			rarity = "Common",
			description = "A standard-issue forged iron arming sword. Balanced, durable, and reliable for fledgling warriors venturing into dungeons.",
			stats = {
				physicalDamage = 12,
				attackSpeed = 1.0,
				criticalChance = 0.05,
			},
			crafting = {
				levelRequired = 1,
				craftTime = 2.0,
				materials = {
					IronIngot = 3,
					LeatherStrap = 1,
				},
			},
		},

		StandardShield = {
			id = "StandardShield",
			setId = "Standard",
			displayName = "Oak & Iron Round Shield",
			slot = "Shield",
			tier = 1,
			rarity = "Common",
			description = "A sturdy oak wood round shield reinforced with a riveted iron perimeter rim and central boss dome.",
			stats = {
				armor = 10,
				blockChance = 0.15,
				parryWindow = 0.35,
			},
			crafting = {
				levelRequired = 1,
				craftTime = 2.0,
				materials = {
					OakTimber = 4,
					IronIngot = 2,
				},
			},
		},

		-- -- Sunforged Tier 3 (Legendary Holy Relic Gear) -----------------------
		SunforgedSword = {
			id = "SunforgedSword",
			setId = "Sunforged",
			displayName = "Sunforged Runic Greatsword",
			slot = "Weapon",
			tier = 3,
			rarity = "Legendary",
			description = "A masterwork greatsword forged in celestial solar flame, inscribed with ancient luminous runes that channel searing holy power.",
			stats = {
				physicalDamage = 32,
				holyDamage = 12,
				attackSpeed = 1.15,
				criticalChance = 0.12,
			},
			crafting = {
				levelRequired = 3,
				craftTime = 8.0,
				baseEquipment = "StandardSword",
				materials = {
					IronIngot = 12,
					SunstoneCore = 1,
					AncientRune = 3,
				},
			},
		},

		SunforgedShield = {
			id = "SunforgedShield",
			setId = "Sunforged",
			displayName = "Lionheart Aegis Bulwark",
			slot = "Shield",
			tier = 3,
			rarity = "Legendary",
			description = "A fortress-grade kite shield adorned with golden heraldry, corner studs, and an inner glowing Aegis Soul Core that deflects lethal blows.",
			stats = {
				armor = 28,
				blockChance = 0.35,
				damageReduction = 0.20,
				parryWindow = 0.50,
			},
			crafting = {
				levelRequired = 3,
				craftTime = 8.0,
				baseEquipment = "StandardShield",
				materials = {
					IronIngot = 10,
					SunstoneCore = 1,
					AncientRune = 2,
				},
			},
		},
	},

	-- -- CRAFTING REAGENTS & INGREDIENTS --------------------------------------
	Materials = {
		IronIngot = {
			id = "IronIngot",
			displayName = "Iron Ingot",
			tier = 1,
			rarity = "Common",
			description = "Refined iron smelted from dungeon ore veins. Fundamental metal for forging weapons and armor rims.",
			maxStack = 99,
		},
		OakTimber = {
			id = "OakTimber",
			displayName = "Oak Timber",
			tier = 1,
			rarity = "Common",
			description = "Dense weathered hardwood seasoned for making durable round shields, bowstaves, and tool hafts.",
			maxStack = 99,
		},
		LeatherStrap = {
			id = "LeatherStrap",
			displayName = "Leather Strap",
			tier = 1,
			rarity = "Common",
			description = "Treated leather band used for weapon handle wrapping, forearm braces, and armor clasps.",
			maxStack = 99,
		},
		SunstoneCore = {
			id = "SunstoneCore",
			displayName = "Sunstone Core",
			tier = 3,
			rarity = "Rare",
			description = "A concentrated celestial crystal found deep within the boss arena ruins. Radiates warm solar embers.",
			maxStack = 20,
		},
		AncientRune = {
			id = "AncientRune",
			displayName = "Ancient Rune",
			tier = 3,
			rarity = "Epic",
			description = "A carved stone fragment humming with forgotten runic magic. Infuses weapons with holy luminous fuller channels.",
			maxStack = 20,
		},
		RockhideFragment = {
			id = "RockhideFragment",
			displayName = "Rockhide Fragment",
			tier = 3,
			rarity = "Rare",
			description = "A jagged shard of Rockhide's stone hide, still warm with residual seismic energy. Earned only by braving the boss chamber.",
			maxStack = 99,
		},
	},

	-- -- SET PRESETS ---------------------------------------------------------
	Sets = {
		Standard = {
			id = "Standard",
			displayName = "Adventurer's Standard Set",
			tier = 1,
			weaponId = "StandardSword",
			shieldId = "StandardShield",
		},
		Sunforged = {
			id = "Sunforged",
			displayName = "Sunforged Relic Set",
			tier = 3,
			weaponId = "SunforgedSword",
			shieldId = "SunforgedShield",
		},
	},
}

return Equipment
