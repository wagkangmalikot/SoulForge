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

	-- ── SOLARIUS, SUNFORGED COLOSSUS (Tier 2 Boss, Lv. 5-30+) ───────────────────
	Solarius_RadiantSlash = {
		telegraphTime = 1.1,
		radius = 16,
		damage = 38,
		type = "Cleave", -- sweeping golden arc
	},
	Solarius_SweepingCleave = {
		telegraphTime = 1.4,
		radius = 18,
		damage = 44,
		type = "Sweep",
	},
	Solarius_SolarSmite = {
		telegraphTime = 1.6,
		radius = 15,
		damage = 56,
		type = "TargetedAoe", -- solar pillar from above
	},
	Solarius_Sunburst = {
		telegraphTime = 2.0,
		radius = 14,
		damage = 42,
		type = "TargetedAoe", -- multi-target tracking sun rays
		hitCount = 3,
	},
	Solarius_BlindingAura = {
		telegraphTime = 1.8,
		radius = 30,
		damage = 50,
		type = "Pound", -- massive radial solar shockwave
	},
	Solarius_Supernova = {
		telegraphTime = 3.6,
		radius = 60,
		damage = 110,
		type = "Pound", -- lethal room-wide solar detonation; take cover behind outer pillars!
		isEnrage = true,
	},
}


