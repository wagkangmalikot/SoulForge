-- src/ReplicatedStorage/Shared/Data/Classes.lua
return {
	Tank = {
		name = "Tank",
		baseHealth = 150,
		startingSkills = {"Taunt"},
		branches = {
			Juggernaut = {
				name = "Juggernaut",
				description = "Offensive powerhouse focusing on high-threat strikes, shield impacts, and earthshaking AoE crowd control.",
				skills = {"ProvokingStrike", "ShieldBash", "Earthshaker"},
			},
			Bulwark = {
				name = "Bulwark",
				description = "Stalwart guardian specializing in damage mitigation, instant self-recovery, and defensive party auras.",
				skills = {"GuardStance", "IronWill", "FortressAura"},
			},
		},
	},

	Mage = {
		name = "Mage",
		baseHealth = 90,
		startingSkills = {"ArcaneBolt"},
		branches = {
			Pyromancy = {
				name = "Pyromancy",
				description = "Explosive single-target and area fire damage with burning DoTs — high risk, devastating reward.",
				skills = {"Firebolt", "Fireball", "Meteor"},
			},
			Frostweave = {
				name = "Frostweave",
				description = "Sustained frost damage that slows and shreds enemy armour, lingering long after the initial strike.",
				skills = {"Frostbolt", "IceLance", "Blizzard"},
			},
			ArcaneMastery = {
				name = "Arcane Mastery",
				description = "Defensive barriers, arcane burst damage, and reality-warping AoE control — the scholar's ultimate toolkit.",
				skills = {"ArcaneBarrier", "ArcaneSurge", "ArcaneNova"},
			},
		},
	},
}
