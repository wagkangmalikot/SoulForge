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

	-- Not yet reachable through character creation or the skill tree UI (both still
	-- hardcode Tank) -- see docs/superpowers/specs/2026-09-18-mage-class-design.md's
	-- "sub-project 2" for that follow-up work. Playable today only via a manual
	-- ClassId/UnlockedSkills override on a test profile.
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
}
