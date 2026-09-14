-- src/ReplicatedStorage/Shared/Data/BossAttacks.lua
-- Note: the full spec models `hitboxType` as `AOECircle`/`MovingHitbox` with distinct shapes;
-- this slice simplifies every attack to a radius-based circle check centered on the boss for
-- the first implementation pass (a real swept-arc hitbox for `SweepingBackhand` is a follow-up
-- refinement, not a blocker to proving the phase/telegraph/damage pipeline).
return {
	Rockhide_OverheadSlam = {
		telegraphTime = 2.0,
		radius = 8,
		damage = 15,
	},
	Rockhide_SweepingBackhand = {
		telegraphTime = 2.5,
		radius = 12,
		damage = 12,
	},
	Rockhide_GroundPound = {
		telegraphTime = 3.0,
		radius = 16,
		damage = 21,
	},
}
