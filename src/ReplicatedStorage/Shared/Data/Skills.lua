-- src/ReplicatedStorage/Shared/Data/Skills.lua
-- damageFormula is intentionally a flat number for this vertical slice; the
-- full stat-scaling formula (spec section 2) is deferred to a later plan.
return {
	ShieldBash = {
		cooldown = 8,
		range = 8,
		damage = 8,
	},
	GuardStance = {
		cooldown = 20,
		range = 0,
		damage = 0,
	},
	ProvokingStrike = {
		cooldown = 4,
		range = 8,
		damage = 12,
	},
	Taunt = {
		cooldown = 12,
		range = 30,
		damage = 0,
	},
}
