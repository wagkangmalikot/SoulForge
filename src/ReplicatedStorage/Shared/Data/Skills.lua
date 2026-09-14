-- src/ReplicatedStorage/Shared/Data/Skills.lua
-- damageFormula is intentionally a flat number for this vertical slice; the
-- full stat-scaling formula (spec section 2) is deferred to a later plan.
-- unlockLevel: the minimum Character.Level required to cast this skill (spec
-- section 2b) -- enforced server-side in CombatService.onCastSkill.
return {
	ShieldBash = {
		cooldown = 8,
		range = 8,
		damage = 8,
		unlockLevel = 2,
	},
	GuardStance = {
		cooldown = 20,
		range = 0,
		damage = 0,
		unlockLevel = 4,
	},
	ProvokingStrike = {
		cooldown = 4,
		range = 8,
		damage = 12,
		unlockLevel = 3,
	},
	Taunt = {
		cooldown = 12,
		range = 30,
		damage = 0,
		unlockLevel = 1,
	},
}
