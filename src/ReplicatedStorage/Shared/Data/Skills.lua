-- src/ReplicatedStorage/Shared/Data/Skills.lua
-- Definitive skills registry for all classes (Tank: Juggernaut/Bulwark; Mage: Pyromancy/Frostweave/ArcaneMastery).
--
-- effectType drives how CombatService.onCastSkill resolves what a skill actually does:
--   tauntAoe      - taunts every enemy within range (Taunt)
--   damage        - single-target instant damage
--   aoeDamage     - instant damage to every enemy within range
--   selfHeal      - restores the caster's own health (IronWill)
--   dotDamage     - single-target instant damage + follow-up damage-over-time ticks
--   aoeDotDamage  - aoeDamage + follow-up damage-over-time ticks on every enemy hit
-- GuardStance/FortressAura/ArcaneBarrier are buffSelf/buffParty -- intentionally unhandled by any dispatch
-- branch in CombatService (see that file's comment); they were already no-ops before this
-- effectType field existed, this just labels the gap instead of hiding it in a name check.
--
-- tauntsOnHit = true marks a single-target damage skill that also taunts on hit (ProvokingStrike).
-- slowPercent   = N  requests a slow of N% on the hit enemy (broadcast via enemy.onSlowed if supported).
-- burnTicks / burnTickDamage — fire DoT fields (reuses dotTicks / dotTickDamage under the hood).
-- armorShred    = N  reduces the target's effective armour by N% for the next hit.
-- shieldAmount  = N  the HP-absorption shield granted by ArcaneBarrier.
-- consumesShield = true  ArcaneSurge: adds bonus damage if caster's ArcaneBarrier shield is active.
return {
	-- ── BASE STARTING SKILL (Tank) ───────────────────────────────────────────
	Taunt = {
		id = "Taunt",
		displayName = "Taunt",
		branch = "Base",
		tier = 0,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/taunt_icon.png",
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
		range = 24,
		damage = 16,
		effectType = "damage",
		description = "Charge forward and drive your shield into the enemy with crushing force, dealing 16 damage and staggering them.",
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
		cooldown = 2.5,
		range = 35,
		damage = 14,
		effectType = "damage",
		slowPercent = 15,
		description = "A crackling bolt of raw arcane energy that deals 14 damage and briefly slows the target by 15%.",
	},

	-- ── PYROMANCY BRANCH (Explosive Single-Target & Area Fire Damage) ────────
	Firebolt = {
		id = "Firebolt",
		displayName = "Firebolt",
		branch = "Pyromancy",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/firebolt_icon.png",
		cooldown = 4,
		range = 28,
		damage = 22,
		effectType = "dotDamage",
		dotTickDamage = 4,
		dotTicks = 2,
		dotInterval = 1.5,
		burnTicks = 2,
		burnTickDamage = 4,
		description = "Hurl a searing bolt of flame, dealing 22 burst damage then burning the target for 4 damage over 2 ticks (3s).",
	},

	Fireball = {
		id = "Fireball",
		displayName = "Fireball",
		branch = "Pyromancy",
		tier = 2,
		prerequisite = "Firebolt",
		icon = "rbxasset://textures/Soulforge/fireball_icon.png",
		cooldown = 8,
		range = 28,
		damage = 34,
		effectType = "damage",
		description = "Launch a roaring ball of fire that explodes on impact, dealing 34 burst damage to a single target.",
	},

	Meteor = {
		id = "Meteor",
		displayName = "Meteor",
		branch = "Pyromancy",
		tier = 3,
		prerequisite = "Fireball",
		icon = "rbxasset://textures/Soulforge/meteor_icon.png",
		cooldown = 14,
		range = 22,
		damage = 42,
		effectType = "aoeDotDamage",
		dotTickDamage = 6,
		dotTicks = 3,
		dotInterval = 1.5,
		burnTicks = 3,
		burnTickDamage = 6,
		description = "Call down a blazing meteor, dealing 42 AoE damage to all nearby enemies, then scorching each for 6 damage over 3 ticks (4.5s).",
	},

	-- ── FROSTWEAVE BRANCH (Sustained Frost Damage-Over-Time & Slows) ─────────
	Frostbolt = {
		id = "Frostbolt",
		displayName = "Frostbolt",
		branch = "Frostweave",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/frostbolt_icon.png",
		cooldown = 5,
		range = 28,
		damage = 13,
		effectType = "dotDamage",
		dotTickDamage = 4,
		dotTicks = 3,
		dotInterval = 1.5,
		slowPercent = 20,
		description = "A shard of ice that deals 13 damage on impact and slows the target 20%, then 4 damage per tick over the next 3 ticks (4.5s).",
	},

	IceLance = {
		id = "IceLance",
		displayName = "Ice Lance",
		branch = "Frostweave",
		tier = 2,
		prerequisite = "Frostbolt",
		icon = "rbxasset://textures/Soulforge/ice_lance_icon.png",
		cooldown = 9,
		range = 28,
		damage = 18,
		effectType = "dotDamage",
		dotTickDamage = 5,
		dotTicks = 3,
		dotInterval = 1.5,
		slowPercent = 30,
		armorShred = 10,
		description = "A piercing lance of ice that deals 18 damage, slows 30%, shreds 10% armour, then 5 damage per tick over the next 3 ticks (4.5s).",
	},

	Blizzard = {
		id = "Blizzard",
		displayName = "Blizzard",
		branch = "Frostweave",
		tier = 3,
		prerequisite = "IceLance",
		icon = "rbxasset://textures/Soulforge/blizzard_icon.png",
		cooldown = 16,
		range = 22,
		damage = 22,
		effectType = "aoeDotDamage",
		dotTickDamage = 5,
		dotTicks = 4,
		dotInterval = 1.5,
		slowPercent = 40,
		description = "Summon a raging blizzard, dealing 22 AoE damage and slowing all nearby enemies by 40%, then 5 damage per tick over 4 ticks (6s) to each.",
	},

	-- ── ARCANE MASTERY BRANCH (Barriers, Burst Damage & Arcane Control) ──────
	ArcaneBarrier = {
		id = "ArcaneBarrier",
		displayName = "Arcane Barrier",
		branch = "ArcaneMastery",
		tier = 1,
		prerequisite = nil,
		icon = "rbxasset://textures/Soulforge/arcane_barrier_icon.png",
		cooldown = 20,
		range = 0,
		damage = 0,
		duration = 6,
		shieldAmount = 40,
		effectType = "buffSelf",
		description = "Crystallize arcane energy into a protective barrier, absorbing up to 40 damage for 6 seconds. Empowers your next Arcane Surge.",
	},

	ArcaneSurge = {
		id = "ArcaneSurge",
		displayName = "Arcane Surge",
		branch = "ArcaneMastery",
		tier = 2,
		prerequisite = "ArcaneBarrier",
		icon = "rbxasset://textures/Soulforge/arcane_surge_icon.png",
		cooldown = 10,
		range = 32,
		damage = 28,
		effectType = "damage",
		consumesShield = true,
		description = "Release a focused surge of arcane force dealing 28 damage. If Arcane Barrier is active, it is consumed for +8 bonus damage and a devastating knockback.",
	},

	ArcaneNova = {
		id = "ArcaneNova",
		displayName = "Arcane Nova",
		branch = "ArcaneMastery",
		tier = 3,
		prerequisite = "ArcaneSurge",
		icon = "rbxasset://textures/Soulforge/arcane_nova_icon.png",
		cooldown = 18,
		range = 22,
		damage = 38,
		effectType = "aoeDamage",
		slowPercent = 35,
		description = "Detonate a nova of raw arcane energy, dealing 38 AoE damage to all nearby enemies and slowing them by 35% as the shockwave tears through reality.",
	},
}
