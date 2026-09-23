-- src/ReplicatedStorage/Shared/Data/Bosses/Solarius.lua
return {
	id = "Solarius",
	displayName = "Solarius, Sunforged Colossus",
	dungeonTier = 2,
	maxHealth = 750, -- tuned for Tier 2 party playtest (Level 5-10)
	phases = {
		-- Phase 1: 100% → 61% HP — Solar Might & Sweeping Cleaves
		{
			hpThreshold = 1.0,
			attackPool = {
				"Solarius_RadiantSlash",
				"Solarius_SolarSmite",
				"Solarius_SweepingCleave",
			},
			attackIntervalRange = {3.2, 5.0},
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
			attackIntervalRange = {2.5, 3.8},
			telegraphTimeMultiplier = 0.85,
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
			attackIntervalRange = {1.8, 3.0},
			telegraphTimeMultiplier = 0.75,
		},
	},
	phaseTransition = {
		{ duration = 2.0, hpThreshold = 0.60 },
		{ duration = 3.0, hpThreshold = 0.25 }, -- Celestial roar & solar flare
	},
}
