-- src/ReplicatedStorage/Shared/Data/Bosses/Rockhide.lua
return {
	id = "Rockhide",
	displayName = "Rockhide",
	dungeonTier = 1,
	maxHealth = 300, -- tuned for this slice's single-Tank playtest; revisit with real stats later
	phases = {
		-- Phase 1: 100% → 51% HP — standard aggro
		{
			hpThreshold = 1.0,
			attackPool = {"Rockhide_ArmSweep", "Rockhide_OverheadSlam", "Rockhide_SweepingBackhand"},
			attackIntervalRange = {3.5, 5.5},
		},
		-- Phase 2: 50% → 26% HP — faster + new moves
		{
			hpThreshold = 0.5,
			attackPool = {
				"Rockhide_ArmSweep",
				"Rockhide_OverheadSlam",
				"Rockhide_SweepingBackhand",
				"Rockhide_GroundPound",
				"Rockhide_StoneCharge",
				"Rockhide_BoulderBarrage",
			},
			attackIntervalRange = {2.8, 4.2},
			telegraphTimeMultiplier = 0.85,
		},
		-- Phase 3: 25% HP — Enrage, all attacks, brutal speed
		{
			hpThreshold = 0.25,
			attackPool = {
				"Rockhide_ArmSweep",
				"Rockhide_OverheadSlam",
				"Rockhide_GroundPound",
				"Rockhide_StoneCharge",
				"Rockhide_SeismicSlam",
				"Rockhide_BoulderBarrage",
			},
			attackIntervalRange = {2, 3.5},
			telegraphTimeMultiplier = 0.75,
		},
	},
	phaseTransition = {
		{ duration = 2.0, hpThreshold = 0.5 },
		{ duration = 2.5, hpThreshold = 0.25 }, -- longer enrage roar
	},
}
