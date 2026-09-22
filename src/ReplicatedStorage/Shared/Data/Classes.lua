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
		baseHealth = 80,
		startingSkills = {"ArcaneBolt"},
		branches = {
			Pyromancy = {
				name = "Pyromancy",
				description = "Explosive single-target and area fire damage, high risk-reward burst.",
				skills = {"Firebolt", "Fireball", "Meteor"},
			},
			Frostweave = {
				name = "Frostweave",
				description = "Sustained frost damage that lingers on enemies after the initial strike.",
				skills = {"Frostbolt", "IceLance", "Blizzard"},
			},
		},
	},

	Healer = {
		name = "Healer",
		baseHealth = 90,
		startingSkills = {"Mend"},
		branches = {
			Mending = {
				name = "Mending",
				description = "Focused single-target healing that scales from a quick touch to a powerful restoration.",
				skills = {"SoothingLight", "RadiantMend", "DivineRestoration"},
			},
			Sanctuary = {
				name = "Sanctuary",
				description = "Area healing that keeps the whole party topped up, building to a party-wide burst.",
				skills = {"SacredCircle", "HealingRain", "Sanctuary"},
			},
		},
	},
}
