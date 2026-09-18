-- src/ReplicatedStorage/Shared/Data/Skills.lua
-- Definitive skills registry for all classes (Tank: Juggernaut/Bulwark; Mage: Pyromancy/Frostweave).
--
-- effectType drives how CombatService.onCastSkill resolves what a skill actually does:
--   tauntAoe      - taunts every enemy within range (Taunt)
--   damage        - single-target instant damage (ProvokingStrike, ShieldBash, ArcaneBolt, Firebolt, Fireball)
--   aoeDamage     - instant damage to every enemy within range (Earthshaker, Meteor)
--   selfHeal      - restores the caster's own health (IronWill)
--   dotDamage     - single-target instant damage + follow-up damage-over-time ticks (Frostbolt, IceLance)
--   aoeDotDamage  - aoeDamage + follow-up damage-over-time ticks on every enemy hit (Blizzard)
-- GuardStance/FortressAura are buffSelf/buffParty -- intentionally unhandled by any dispatch
-- branch in CombatService (see that file's comment); they were already no-ops before this
-- effectType field existed, this just labels the gap instead of hiding it in a name check.
--
-- tauntsOnHit = true marks a single-target damage skill that also taunts on hit (ProvokingStrike).
return {
	-- ── BASE STARTING SKILL (Tank) ───────────────────────────────────────────
	Taunt = {
		id = "Taunt",
		displayName = "Taunt",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/taunt_icon.png", -- Realistic dark-fantasy warcry icon (or rbxassetid://<id>)
		cooldown = 12,
		range = 30,
		damage = 0,
		effectType = "tauntAoe",
		description = "Unleash an enraged battle cry, taunting all enemies within 30 studs and forcing their aggro onto you.",
	},

	-- ── JUGGERNAUT BRANCH (Offense, Heavy Threat, & Crowd Control) ───────────
	ProvokingStrike = {
		id = "ProvokingStrike",
		displayName = "Provoking Strike",
		branch = "Juggernaut",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/provoking_strike_icon.png",
		cooldown = 4,
		range = 14,
		damage = 14,
		effectType = "damage",
		tauntsOnHit = true,
		description = "A vicious heavy slash that inflicts 14 damage and generates 3x bonus threat.",
	},

	ShieldBash = {
		id = "ShieldBash",
		displayName = "Shield Bash",
		branch = "Juggernaut",
		tier = 2,
		prerequisite = "ProvokingStrike",
		icon = "rbxasset://textures/Soulforge/shield_bash_icon.png",
		cooldown = 8,
		range = 14,
		damage = 16,
		effectType = "damage",
		description = "Drive your shield into the enemy with crushing force, dealing 16 damage and staggering them.",
	},

	Earthshaker = {
		id = "Earthshaker",
		displayName = "Earthshaker",
		branch = "Juggernaut",
		tier = 3,
		prerequisite = "ShieldBash",
		icon = "rbxasset://textures/Soulforge/earthshaker_icon.png",
		cooldown = 14,
		range = 16,
		damage = 24,
		effectType = "aoeDamage",
		description = "Leap into the air and smash your weapon into the earth, sending a shockwave that deals 24 AoE damage to all nearby enemies.",
	},

	-- ── BULWARK BRANCH (Defense, Sustain, & Party Protection) ─────────────────
	GuardStance = {
		id = "GuardStance",
		displayName = "Guard Stance",
		branch = "Bulwark",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/guard_stance_icon.png",
		cooldown = 18,
		range = 0,
		damage = 0,
		duration = 6,
		effectType = "buffSelf",
		description = "Lock into a stalwart defensive posture, reducing all incoming damage by 50% for 6 seconds.",
	},

	IronWill = {
		id = "IronWill",
		displayName = "Iron Will",
		branch = "Bulwark",
		tier = 2,
		prerequisite = "GuardStance",
		icon = "rbxasset://textures/Soulforge/iron_will_icon.png",
		cooldown = 22,
		range = 0,
		damage = 0,
		healAmount = 40,
		effectType = "selfHeal",
		description = "Channel unbreakable resolve to immediately restore 40 Health and cleanse negative effects.",
	},

	FortressAura = {
		id = "FortressAura",
		displayName = "Fortress Aura",
		branch = "Bulwark",
		tier = 3,
		prerequisite = "IronWill",
		icon = "rbxasset://textures/Soulforge/fortress_aura_icon.png",
		cooldown = 28,
		range = 0,
		damage = 0,
		duration = 8,
		effectType = "buffParty",
		description = "Project an impenetrable defensive barrier, granting yourself and all nearby party members 30% damage reduction for 8 seconds.",
	},

	-- ── BASE STARTING SKILL (Mage) ───────────────────────────────────────────
	ArcaneBolt = {
		id = "ArcaneBolt",
		displayName = "Arcane Bolt",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/arcane_bolt_icon.png",
		cooldown = 3,
		range = 30,
		damage = 10,
		effectType = "damage",
		description = "A basic bolt of raw arcane energy, dealing 10 damage.",
	},

	-- ── PYROMANCY BRANCH (Explosive Single-Target & Area Fire Damage) ────────
	Firebolt = {
		id = "Firebolt",
		displayName = "Firebolt",
		branch = "Pyromancy",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/firebolt_icon.png",
		cooldown = 5,
		range = 25,
		damage = 18,
		effectType = "damage",
		description = "Hurl a searing bolt of flame, dealing 18 burst damage.",
	},

	Fireball = {
		id = "Fireball",
		displayName = "Fireball",
		branch = "Pyromancy",
		tier = 2,
		prerequisite = "Firebolt",
		icon = "rbxasset://textures/Soulforge/fireball_icon.png",
		cooldown = 9,
		range = 25,
		damage = 26,
		effectType = "damage",
		description = "Launch a roaring ball of fire, dealing 26 burst damage.",
	},

	Meteor = {
		id = "Meteor",
		displayName = "Meteor",
		branch = "Pyromancy",
		tier = 3,
		prerequisite = "Fireball",
		icon = "rbxasset://textures/Soulforge/meteor_icon.png",
		cooldown = 16,
		range = 20,
		damage = 30,
		effectType = "aoeDamage",
		description = "Call down a blazing meteor, dealing 30 AoE damage to all nearby enemies.",
	},

	-- ── FROSTWEAVE BRANCH (Sustained Frost Damage-Over-Time) ─────────────────
	Frostbolt = {
		id = "Frostbolt",
		displayName = "Frostbolt",
		branch = "Frostweave",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/frostbolt_icon.png",
		cooldown = 5,
		range = 25,
		damage = 10,
		effectType = "dotDamage",
		dotTickDamage = 3,
		dotTicks = 3,
		dotInterval = 1.5,
		description = "A shard of ice that deals 10 damage on impact, then 3 damage per tick over the next 3 ticks (4.5s).",
	},

	IceLance = {
		id = "IceLance",
		displayName = "Ice Lance",
		branch = "Frostweave",
		tier = 2,
		prerequisite = "Frostbolt",
		icon = "rbxasset://textures/Soulforge/ice_lance_icon.png",
		cooldown = 9,
		range = 25,
		damage = 14,
		effectType = "dotDamage",
		dotTickDamage = 4,
		dotTicks = 3,
		dotInterval = 1.5,
		description = "A piercing lance of ice that deals 14 damage on impact, then 4 damage per tick over the next 3 ticks (4.5s).",
	},

	Blizzard = {
		id = "Blizzard",
		displayName = "Blizzard",
		branch = "Frostweave",
		tier = 3,
		prerequisite = "IceLance",
		icon = "rbxasset://textures/Soulforge/blizzard_icon.png",
		cooldown = 16,
		range = 20,
		damage = 16,
		effectType = "aoeDotDamage",
		dotTickDamage = 4,
		dotTicks = 3,
		dotInterval = 1.5,
		description = "Summon a raging blizzard, dealing 16 AoE damage to all nearby enemies, then 4 damage per tick over the next 3 ticks (4.5s) to each.",
	},
}
