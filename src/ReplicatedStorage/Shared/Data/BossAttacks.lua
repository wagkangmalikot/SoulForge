-- src/ReplicatedStorage/Shared/Data/BossAttacks.lua
return {
	Rockhide_ArmSweep = {
		telegraphTime = 1.1,
		radius = 14,
		damage = 12,
		type = "Sweep", -- normal horizontal arm sweep
	},
	Rockhide_OverheadSlam = {
		telegraphTime = 1.8,
		radius = 12,
		damage = 18,
		type = "TargetedAoe", -- telegraphed at target's location
	},
	Rockhide_SweepingBackhand = {
		telegraphTime = 2.0,
		radius = 16,
		damage = 15,
		type = "Cleave", -- telegraphed in front of boss
	},
	Rockhide_GroundPound = {
		telegraphTime = 2.5,
		radius = 24,
		damage = 24,
		type = "Pound", -- massive shockwave centered on boss
	},
	-- NEW: Phase 2+ attacks
	Rockhide_StoneCharge = {
		telegraphTime = 1.4,
		radius = 8,
		damage = 22,
		type = "Charge", -- boss lunges forward toward target
		chargeDistance = 28, -- studs the boss closes per charge
	},
	Rockhide_SeismicSlam = {
		telegraphTime = 3.0,
		radius = 32,
		damage = 30,
		type = "Pound", -- wide screen-shaking mega AOE
		isEnrage = true,
	},
	Rockhide_BoulderBarrage = {
		telegraphTime = 2.2,
		radius = 10,
		damage = 14,
		type = "TargetedAoe", -- rapid multi-hit on random players
		hitCount = 3, -- fires 3 individual impact waves
	},
}
