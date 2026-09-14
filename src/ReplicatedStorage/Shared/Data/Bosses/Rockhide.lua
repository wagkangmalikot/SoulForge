-- src/ReplicatedStorage/Shared/Data/Bosses/Rockhide.lua
return {
	id = "Rockhide",
	displayName = "Rockhide",
	dungeonTier = 1,
	maxHealth = 300, -- tuned for this slice's single-Tank playtest; revisit with real stats later
	phases = {
		{
			hpThreshold = 1.0,
			attackPool = {"Rockhide_OverheadSlam", "Rockhide_SweepingBackhand"},
			attackIntervalRange = {4, 6},
		},
		{
			hpThreshold = 0.5,
			attackPool = {"Rockhide_OverheadSlam", "Rockhide_SweepingBackhand", "Rockhide_GroundPound"},
			attackIntervalRange = {3.5, 5},
			telegraphTimeMultiplier = 0.85,
		},
	},
	phaseTransition = {
		{ duration = 2, hpThreshold = 0.5 },
	},
}
