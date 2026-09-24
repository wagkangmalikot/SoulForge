-- src/ReplicatedStorage/Shared/Data/Bosses/Solarius.lua
return {
	id = "Solarius",
	displayName = "Solarius, Sunforged Colossus",
	dungeonTier = 2,
	level = 30,
	maxHealth = 2250, -- tuned for Tier 2 endgame party / level 5-30 hardcore retry loop
	phases = {
		-- Phase 1: 100% → 61% HP — Solar Might & Sweeping Cleaves
		{
			hpThreshold = 1.0,
			attackPool = {
				"Solarius_RadiantSlash",
				"Solarius_SolarSmite",
				"Solarius_SweepingCleave",
			},
			attackIntervalRange = {2.6, 3.8},
		},
		-- Phase 2: 60% → 26% HP — Daybreak & Tracking Solar Beams
		{
			hpThreshold = 0.60,
			attackPool = {
				"Solarius_RadiantSlash",
				"Solarius_SolarSmite",
				"Solarius_Sunburst",
				"Solarius_BlindingAura",
			},
			attackIntervalRange = {2.0, 3.0},
			telegraphTimeMultiplier = 0.80,
		},
		-- Phase 3: 25% HP — Supernova Enrage: Unchecked Celestial Radiance
		{
			hpThreshold = 0.25,
			attackPool = {
				"Solarius_RadiantSlash",
				"Solarius_SolarSmite",
				"Solarius_Sunburst",
				"Solarius_BlindingAura",
				"Solarius_Supernova",
			},
			attackIntervalRange = {1.4, 2.4},
			telegraphTimeMultiplier = 0.70,
		},
	},
	phaseTransition = {
		{ duration = 2.0, hpThreshold = 0.60 },
		{ duration = 3.0, hpThreshold = 0.25 }, -- Celestial roar & solar flare
	},
}

