-- src/ReplicatedStorage/Shared/Data/Equipment.lua
-- Equipment Item Registry for Soulforge.
-- Items are individual gear pieces (Weapon / Head / Body / Arms / Feet).
-- Sets group pieces together and grant a Set Bonus when all pieces are equipped.
-- STASHED sets are kept for future use but hidden from crafting UI.

local Equipment = {

	-- ── GEAR SLOT KEYS ─────────────────────────────────────────────────────
	-- Slot = "Weapon" | "Head" | "Body" | "Arms" | "Feet"

	-- ── ITEMS ──────────────────────────────────────────────────────────────
	Items = {

		-- ── Standard (Tier 1 — Starter, not craftable) ─────────────────────
		StandardSword = {
			id = "StandardSword",
			setId = "Standard",
			displayName = "Iron Sword",
			slot = "Weapon",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/standard_sword_icon.png",
			description = "A standard-issue forged iron arming sword. Balanced, durable, reliable.",
			stats = {
				physicalDamage = 12,
				attackSpeed    = 1.0,
				criticalChance = 0.05,
			},
		},
		StandardHelm = {
			id = "StandardHelm",
			setId = "Standard",
			displayName = "Iron Helm",
			slot = "Head",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/standard_helm_icon.png",
			description = "A basic iron combat helmet offering minimal protection.",
			stats = { armor = 4, magicResist = 2 },
		},
		StandardChest = {
			id = "StandardChest",
			setId = "Standard",
			displayName = "Iron Chestplate",
			slot = "Body",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/standard_chest_icon.png",
			description = "A riveted iron chestplate — the backbone of any adventurer's kit.",
			stats = { armor = 8, maxHPBonus = 10 },
		},
		StandardArms = {
			id = "StandardArms",
			setId = "Standard",
			displayName = "Iron Vambraces",
			slot = "Arms",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/standard_arms_icon.png",
			description = "Solid iron forearm guards reinforced at the elbow joint.",
			stats = { armor = 3, blockChance = 0.05 },
		},
		StandardFeet = {
			id = "StandardFeet",
			setId = "Standard",
			displayName = "Iron Sabatons",
			slot = "Feet",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/standard_feet_icon.png",
			description = "Heavy iron foot guards providing stable footing on dungeon floors.",
			stats = { armor = 3, movementSpeed = 0 },
		},

		-- ── Apprentice (Tier 1 — Mage Starter, not craftable) ──────────────
		ApprenticeStaff = {
			id = "ApprenticeStaff",
			setId = "Apprentice",
			displayName = "Apprentice Staff",
			slot = "Weapon",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/apprentice_staff_icon.png",
			description = "A polished oak staff crowned with a focused arcane focus crystal. Channels raw celestial energy.",
			stats = {
				magicDamage    = 14,
				attackSpeed    = 1.0,
				criticalChance = 0.05,
				attackRange    = 35,
			},
		},
		ApprenticeHood = {
			id = "ApprenticeHood",
			setId = "Apprentice",
			displayName = "Apprentice Hood",
			slot = "Head",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/apprentice_hood_icon.png",
			description = "A cowl of woven indigo wool that shields the caster's mind and sharpens arcane senses.",
			stats = { armor = 2, magicResist = 5, maxHPBonus = 5 },
		},
		ApprenticeRobe = {
			id = "ApprenticeRobe",
			setId = "Apprentice",
			displayName = "Apprentice Robe",
			slot = "Body",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/apprentice_robe_icon.png",
			description = "Flowing linen scholar robes inscribed with subtle warding glyphs along the inner hem.",
			stats = { armor = 4, magicResist = 8, maxHPBonus = 10 },
		},
		ApprenticeBracers = {
			id = "ApprenticeBracers",
			setId = "Apprentice",
			displayName = "Apprentice Bracers",
			slot = "Arms",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/apprentice_bracers_icon.png",
			description = "Soft leather wrist wraps with runic stitching that stabilize magical flow during casting.",
			stats = { armor = 2, magicResist = 4, spellAmp = 0.05 },
		},
		ApprenticeBoots = {
			id = "ApprenticeBoots",
			setId = "Apprentice",
			displayName = "Apprentice Boots",
			slot = "Feet",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/apprentice_boots_icon.png",
			description = "Supple leather traveling boots enchanted with feather-step charms for swift positioning.",
			stats = { armor = 2, magicResist = 3, movementSpeed = 0 },
		},

		-- ── Rockhide (Tier 2 — Boss Fragment Gear, craftable) ──────────────
		RockhideFang = {
			id = "RockhideFang",
			setId = "Rockhide",
			displayName = "Rockhide Warlord's Fang",
			slot = "Weapon",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_fang_icon.png",
			description = "A brutal greatsword hewn from Rockhide's volcanic stone hide. The jagged basalt blade pulses with seismic energy.",
			stats = {
				physicalDamage        = 26,
				attackSpeed           = 0.95,
				criticalChance        = 0.10,
				bonusDamageUnder50Pct = 0.20,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 5.0,
				materials     = {
					RockhideFragment = 8,
					IronIngot        = 4,
					LeatherStrap     = 2,
				},
			},
		},

		RockhideHelm = {
			id = "RockhideHelm",
			setId = "Rockhide",
			displayName = "Rockhide Warlord's Helm",
			slot = "Head",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_helm_icon.png",
			description = "A stone-hewn war helm carved from Rockhide's carapace with sweeping wyvern horns and a molten magma visor.",
			stats = {
				armor       = 14,
				magicResist = 8,
				maxHPBonus  = 20,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 4.0,
				materials     = {
					RockhideFragment = 4,
					IronIngot        = 3,
					LeatherStrap     = 1,
				},
			},
		},

		RockhideChest = {
			id = "RockhideChest",
			setId = "Rockhide",
			displayName = "Rockhide Warlord's Chest",
			slot = "Body",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_chest_icon.png",
			description = "A 3-tiered scalloped stone cuirass forged from Rockhide's dorsal hide, anchored with a glowing volcanic heart core.",
			stats = {
				armor           = 26,
				maxHPBonus      = 40,
				damageReduction = 0.10,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 6.0,
				materials     = {
					RockhideFragment = 7,
					IronIngot        = 5,
					LeatherStrap     = 3,
					OakTimber        = 2,
				},
			},
		},

		RockhideArms = {
			id = "RockhideArms",
			setId = "Rockhide",
			displayName = "Rockhide Warlord's Vambraces",
			slot = "Arms",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_arms_icon.png",
			description = "Spiked behemoth pauldrons paired with heavy basalt forearm vambraces and parrying talons.",
			stats = {
				armor           = 12,
				blockChance     = 0.15,
				maxHPBonus      = 15,
				damageReduction = 0.05,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 4.0,
				materials     = {
					RockhideFragment = 4,
					IronIngot        = 3,
					LeatherStrap     = 2,
				},
			},
		},

		RockhideFeet = {
			id = "RockhideFeet",
			setId = "Rockhide",
			displayName = "Rockhide Warlord's Sabatons",
			slot = "Feet",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_feet_icon.png",
			description = "Articulated basalt greaves armed with three-claw wyvern talons and subterranean tremor soles.",
			stats = {
				armor         = 10,
				movementSpeed = 0,
				maxHPBonus    = 15,
				tenacity      = 0.15,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 4.0,
				materials     = {
					RockhideFragment = 3,
					IronIngot        = 3,
					OakTimber        = 1,
				},
			},
		},

		-- ── Rockhide Geomancer (Tier 2 Mage — Boss Fragment Gear, craftable) ──
		RockhideStaff = {
			id = "RockhideStaff",
			setId = "RockhideMage",
			displayName = "Earthcaller's Basalt Staff",
			slot = "Weapon",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_staff_icon.png",
			description = "A petrified ancient timber staff bound with jagged volcanic basalt and crowned with an incandescent pulsing magma core.",
			stats = {
				magicDamage           = 28,
				attackSpeed           = 0.95,
				criticalChance        = 0.10,
				attackRange           = 35,
				bonusDamageUnder50Pct = 0.20,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 5.0,
				materials     = {
					RockhideFragment = 8,
					OakTimber        = 4,
					LeatherStrap     = 2,
				},
			},
		},
		RockhideCowl = {
			id = "RockhideCowl",
			setId = "RockhideMage",
			displayName = "Geomancer's Basalt Cowl",
			slot = "Head",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_cowl_icon.png",
			description = "A heavy hood interwoven with flexible stone-hide mesh and socketed with glowing obsidian ember facets.",
			stats = {
				armor       = 5,
				magicResist = 12,
				maxHPBonus  = 15,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 4.0,
				materials     = {
					RockhideFragment = 4,
					LeatherStrap     = 3,
					OakTimber        = 2,
				},
			},
		},
		RockhideRobes = {
			id = "RockhideRobes",
			setId = "RockhideMage",
			displayName = "Earthcaller's Robes",
			slot = "Body",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_robes_icon.png",
			description = "Heavy volcanic leather vestments draped with a rugged basalt shoulder mantle and pulsing tectonic filaments.",
			stats = {
				armor       = 10,
				magicResist = 18,
				maxHPBonus  = 25,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 6.0,
				materials     = {
					RockhideFragment = 10,
					LeatherStrap     = 5,
					IronIngot        = 2,
				},
			},
		},
		RockhideWraps = {
			id = "RockhideWraps",
			setId = "RockhideMage",
			displayName = "Tremor-Bound Wraps",
			slot = "Arms",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_wraps_icon.png",
			description = "Drake-hide wraps embedded with polished rock shards that vibrate in resonance with subterranean magic.",
			stats = {
				armor       = 4,
				magicResist = 8,
				spellAmp    = 0.10,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 3.5,
				materials     = {
					RockhideFragment = 3,
					LeatherStrap     = 3,
					IronIngot        = 1,
				},
			},
		},
		RockhideStriders = {
			id = "RockhideStriders",
			setId = "RockhideMage",
			displayName = "Earthstrider Treads",
			slot = "Feet",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_striders_icon.png",
			description = "Sturdy basalt-soled boots lined with insulating dragon-hide, maintaining firm footing atop trembling ground.",
			stats = {
				armor         = 5,
				magicResist   = 7,
				movementSpeed = 1,
			},
			crafting = {
				levelRequired = 2,
				craftTime     = 3.5,
				materials     = {
					RockhideFragment = 3,
					LeatherStrap     = 4,
					OakTimber        = 1,
				},
			},
		},

		-- ── STASHED: Sunforged (Tier 3 — Legendary, future content) ────────
		-- These items are kept for future implementation.
		-- Do NOT expose in crafting UI until released.
		SunforgedSword = {
			id = "SunforgedSword",
			setId = "Sunforged",
			displayName = "Sunforged Runic Greatsword",
			slot = "Weapon",
			tier = 3,
			rarity = "Legendary",
			
			description = "A masterwork greatsword forged in celestial solar flame, inscribed with ancient luminous runes.",
			stats = {
				physicalDamage = 32,
				holyDamage     = 12,
				attackSpeed    = 1.15,
				criticalChance = 0.12,
			},
			crafting = {
				levelRequired = 3,
				craftTime     = 8.0,
				materials     = { IronIngot = 12, SunstoneCore = 1, AncientRune = 3 },
			},
		},
		SunforgedHelm = {
			id = "SunforgedHelm",
			setId = "Sunforged",
			displayName = "Sunforged Crown",
			slot = "Head",
			tier = 3,
			rarity = "Legendary",
			
			description = "A radiant golden crown that channels celestial energy.",
			stats = { armor = 24, magicResist = 18, maxHPBonus = 40 },
			crafting = { levelRequired = 3, craftTime = 8.0, materials = { IronIngot = 10, SunstoneCore = 1, AncientRune = 2 } },
		},
		SunforgedChest = {
			id = "SunforgedChest",
			setId = "Sunforged",
			displayName = "Sunforged Aegis Plate",
			slot = "Body",
			tier = 3,
			rarity = "Legendary",
			
			description = "A brilliant golden chestplate inscribed with solar seals.",
			stats = { armor = 45, maxHPBonus = 80, damageReduction = 0.20 },
			crafting = { levelRequired = 3, craftTime = 10.0, materials = { IronIngot = 15, SunstoneCore = 2, AncientRune = 3 } },
		},
		SunforgedArms = {
			id = "SunforgedArms",
			setId = "Sunforged",
			displayName = "Sunforged Gauntlets",
			slot = "Arms",
			tier = 3,
			rarity = "Legendary",
			
			description = "Radiant golden gauntlets that pulse with holy light.",
			stats = { armor = 18, blockChance = 0.25, damageReduction = 0.10 },
			crafting = { levelRequired = 3, craftTime = 8.0, materials = { IronIngot = 10, SunstoneCore = 1, AncientRune = 2 } },
		},
		SunforgedFeet = {
			id = "SunforgedFeet",
			setId = "Sunforged",
			displayName = "Sunforged Sabatons",
			slot = "Feet",
			tier = 3,
			rarity = "Legendary",
			
			description = "Golden armored boots that leave radiant footprints.",
			stats = { armor = 16, movementSpeed = 0.10, maxHPBonus = 25 },
			crafting = { levelRequired = 3, craftTime = 8.0, materials = { IronIngot = 8, SunstoneCore = 1, AncientRune = 2 } },
		},
	},

		SunforgedStaff = {
			id = "SunforgedStaff",
			setId = "SunforgedMage",
			displayName = "Solarius Solar Scepter",
			slot = "Weapon",
			tier = 3,
			rarity = "Legendary",
			description = "A golden celestial staff crowned with an eternal solar prism, projecting scorching beams of light.",
			stats = {
				magicDamage    = 34,
				holyDamage     = 14,
				spellAmp       = 0.18,
				criticalChance = 0.10,
			},
			crafting = {
				levelRequired = 3,
				craftTime     = 8.0,
				materials     = { OakTimber = 8, SunstoneCore = 1, AncientRune = 3 },
			},
		},
		SunforgedHood = {
			id = "SunforgedHood",
			setId = "SunforgedMage",
			displayName = "Sunforged Halo Cowl",
			slot = "Head",
			tier = 3,
			rarity = "Legendary",
			description = "An ivory and gold silk cowl featuring a floating golden halo of solar radiance.",
			stats = { armor = 12, magicResist = 28, maxHPBonus = 35 },
			crafting = { levelRequired = 3, craftTime = 8.0, materials = { LeatherStrap = 6, SunstoneCore = 1, AncientRune = 2 } },
		},
		SunforgedRobes = {
			id = "SunforgedRobes",
			setId = "SunforgedMage",
			displayName = "Sunforged Celestial Vestments",
			slot = "Body",
			tier = 3,
			rarity = "Legendary",
			description = "Flowing solar-threaded silk vestments trimmed in sacred gold and inlaid with sunstone gems.",
			stats = { armor = 20, magicResist = 42, maxHPBonus = 60, spellAmp = 0.12 },
			crafting = { levelRequired = 3, craftTime = 10.0, materials = { LeatherStrap = 8, SunstoneCore = 2, AncientRune = 3 } },
		},
		SunforgedWraps = {
			id = "SunforgedWraps",
			setId = "SunforgedMage",
			displayName = "Sunforged Solar Cuffs",
			slot = "Arms",
			tier = 3,
			rarity = "Legendary",
			description = "Brilliant golden bracers inscribed with solar runes that empower spellcasting.",
			stats = { armor = 10, magicResist = 18, spellAmp = 0.15 },
			crafting = { levelRequired = 3, craftTime = 8.0, materials = { IronIngot = 6, SunstoneCore = 1, AncientRune = 2 } },
		},
		SunforgedSlippers = {
			id = "SunforgedSlippers",
			setId = "SunforgedMage",
			displayName = "Sunforged Dawn Treads",
			slot = "Feet",
			tier = 3,
			rarity = "Legendary",
			description = "Silken boots lined with sunstone dust, elevating the wearer slightly above the ground.",
			stats = { armor = 10, magicResist = 16, movementSpeed = 2, maxHPBonus = 20 },
			crafting = { levelRequired = 3, craftTime = 8.0, materials = { LeatherStrap = 6, SunstoneCore = 1, AncientRune = 2 } },
		},
	-- ── CRAFTING MATERIALS ─────────────────────────────────────────────────
	Materials = {
		IronIngot = {
			id = "IronIngot",
			displayName = "Iron Ingot",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/iron_ingot_icon.png",
			description = "Refined iron smelted from dungeon ore veins. Core metal for forging.",
			maxStack = 99,
		},
		OakTimber = {
			id = "OakTimber",
			displayName = "Oak Timber",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/oak_timber_icon.png",
			description = "Dense weathered hardwood for crafting shield cores and hafts.",
			maxStack = 99,
		},
		LeatherStrap = {
			id = "LeatherStrap",
			displayName = "Leather Strap",
			tier = 1,
			rarity = "Common",
			icon = "rbxasset://textures/Soulforge/leather_strap_icon.png",
			description = "Treated leather band for grip wrapping and armor lining.",
			maxStack = 99,
		},
		SunstoneCore = {
			id = "SunstoneCore",
			displayName = "Sunstone Core",
			tier = 3,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_fragment_icon.png",
			description = "A celestial crystal radiating warm solar embers. (Future crafting material)",
			maxStack = 20,
		},
		AncientRune = {
			id = "AncientRune",
			displayName = "Ancient Rune",
			tier = 3,
			rarity = "Epic",
			icon = "rbxasset://textures/Soulforge/rockhide_fragment_icon.png",
			description = "A carved stone fragment humming with forgotten runic magic. (Future crafting material)",
			maxStack = 20,
		},
		RockhideFragment = {
			id = "RockhideFragment",
			displayName = "Rockhide Fragment",
			tier = 2,
			rarity = "Rare",
			icon = "rbxasset://textures/Soulforge/rockhide_fragment_icon.png",
			description = "A jagged shard of Rockhide's stone hide, warm with seismic energy. Earned from the boss chamber.",
			maxStack = 99,
		},
	},

	-- ── SETS ───────────────────────────────────────────────────────────────
	-- Sets group pieces together. Set Bonus activates when ALL pieces are equipped.
	Sets = {
		Standard = {
			id          = "Standard",
			displayName = "Adventurer's Standard Set",
			classId     = "Tank",
			tier        = 1,
			bossOrigin  = nil,
			stashed     = false,
			pieces      = { "StandardSword", "StandardHelm", "StandardChest", "StandardArms", "StandardFeet" },
			setBonus    = nil, -- no set bonus for starter gear
		},
		Apprentice = {
			id          = "Apprentice",
			displayName = "Apprentice Arcanist Set",
			classId     = "Mage",
			tier        = 1,
			bossOrigin  = nil,
			stashed     = false,
			pieces      = { "ApprenticeStaff", "ApprenticeHood", "ApprenticeRobe", "ApprenticeBracers", "ApprenticeBoots" },
			setBonus    = nil, -- no set bonus for starter gear
		},
		Rockhide = {
			id          = "Rockhide",
			displayName = "Rockhide Warlord Set",
			classId     = "Tank",
			tier        = 2,
			rarity      = "Rare",
			bossOrigin  = "Rockhide",
			stashed     = false,
			pieces      = { "RockhideFang", "RockhideHelm", "RockhideChest", "RockhideArms", "RockhideFeet" },
			setBonus    = "Seismic Fury",
			setBonusDesc = "+20% damage dealt when HP is below 50%.",
		},
		RockhideMage = {
			id          = "RockhideMage",
			displayName = "Rockhide Geomancer Set",
			classId     = "Mage",
			tier        = 2,
			rarity      = "Rare",
			bossOrigin  = "Rockhide",
			stashed     = false,
			pieces      = { "RockhideStaff", "RockhideCowl", "RockhideRobes", "RockhideWraps", "RockhideStriders" },
			setBonus    = "Geomantic Surge",
			setBonusDesc = "+20% damage dealt when HP is below 50%.",
		},
		Sunforged = {
			id          = "Sunforged",
			displayName = "Sunforged Relic Set",
			classId     = "Tank",
			tier        = 3,
			rarity      = "Legendary",
			bossOrigin  = "Sunforged",
			stashed     = false,
			pieces      = { "SunforgedSword", "SunforgedHelm", "SunforgedChest", "SunforgedArms", "SunforgedFeet" },
			setBonus    = "Solar Ascension",
			setBonusDesc = "+20% holy damage and regenerate 1% HP per second.",
		},
		SunforgedMage = {
			id          = "SunforgedMage",
			displayName = "Sunforged Radiant Set",
			classId     = "Mage",
			tier        = 3,
			rarity      = "Legendary",
			bossOrigin  = "Sunforged",
			stashed     = false,
			pieces      = { "SunforgedStaff", "SunforgedHood", "SunforgedRobes", "SunforgedWraps", "SunforgedSlippers" },
			setBonus    = "Supernova Radiance",
			setBonusDesc = "+25% spell damage and casting skills releases a holy shockwave.",
		},
	},
}

-- ── HELPERS ────────────────────────────────────────────────────────────────

--- Returns the set that an itemId belongs to, or nil.
function Equipment.GetSetForItem(itemId: string)
	local item = Equipment.Items[itemId]
	if not item then return nil end
	return Equipment.Sets[item.setId]
end

--- Returns the class required to equip an item ("Tank", "Mage"), or nil if unrestricted.
function Equipment.GetItemClass(itemId: string): string?
	local item = Equipment.Items[itemId]
	if not item then return nil end
	if item.classId then return item.classId end
	local setData = Equipment.Sets[item.setId]
	return setData and setData.classId or nil
end

--- Returns how many of a set's pieces the player has equipped, given their loadout.
--- loadout = { Weapon=itemId, Head=itemId, Body=itemId, Arms=itemId, Feet=itemId }
function Equipment.CountEquippedSetPieces(setId: string, loadout: {[string]: string}): (number, number)
	local setData = Equipment.Sets[setId]
	if not setData or not setData.pieces then return 0, 0 end
	local total = #setData.pieces
	local equipped = 0
	for _, pieceId in ipairs(setData.pieces) do
		local pieceItem = Equipment.Items[pieceId]
		if pieceItem then
			local slotEquipped = loadout[pieceItem.slot]
			if slotEquipped == pieceId then
				equipped += 1
			end
		end
	end
	return equipped, total
end

--- Returns true if all pieces of a set are equipped (set bonus active).
function Equipment.IsSetBonusActive(setId: string, loadout: {[string]: string}): boolean
	local e, t = Equipment.CountEquippedSetPieces(setId, loadout)
	return e == t and t > 0
end

return Equipment
