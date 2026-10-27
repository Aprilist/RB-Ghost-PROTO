--!strict
-- Pure boss rules (M2-F): attack geometry, the move rotation, ring spot
-- placement, arena bounds and damage with the opening bonus. No Instances and
-- no services, so tests run them directly. All checks are flat (X/Z);
-- BossService adds the height band. Same idea as EnemyAttackRules: the area
-- is fixed when the telegraph starts and the hit at the end checks that area.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Definitions.Bosses)

local BossRules = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Point inside the sector in front of `origin` (flat). `dir` is a flat unit vector.
function BossRules.InArc(origin: Vector3, dir: Vector3, point: Vector3, reach: number, arcDeg: number): boolean
	local offset = flat(point - origin)
	local dist = offset.Magnitude
	if dist > reach then
		return false
	end
	if dist < 1e-3 then
		return true
	end
	return offset.Unit:Dot(dir) >= math.cos(math.rad(arcDeg / 2))
end

function BossRules.InCircle(center: Vector3, point: Vector3, radius: number): boolean
	return flat(point - center).Magnitude <= radius
end

-- The move at `index` (1-based, wraps) and the index after it.
function BossRules.NextMove(sequence: { Bosses.MoveId }, index: number): (Bosses.MoveId, number)
	local count = #sequence
	local i = ((index - 1) % count) + 1
	return sequence[i], (i % count) + 1
end

function BossRules.InArena(point: Vector3, def: Bosses.BossDef): boolean
	return math.abs(point.X - def.arenaCenterX) <= def.arenaHalfStuds and math.abs(point.Z - def.arenaCenterZ) <= def.arenaHalfStuds
end

-- Pulls a point inside the arena square, `margin` studs from the walls.
function BossRules.Clamp(point: Vector3, def: Bosses.BossDef, margin: number): Vector3
	local half = def.arenaHalfStuds - margin
	return Vector3.new(
		math.clamp(point.X, def.arenaCenterX - half, def.arenaCenterX + half),
		point.Y,
		math.clamp(point.Z, def.arenaCenterZ - half, def.arenaCenterZ + half)
	)
end

-- Where the ring move puts its circles: first on the given player positions
-- (flat, at most `count`), then the rest spread evenly round the first
-- position (or the arena centre when nobody is there). Always inside the arena.
function BossRules.RingSpots(targets: { Vector3 }, def: Bosses.BossDef): { Vector3 }
	local ring = def.ring
	local spots: { Vector3 } = {}
	for i = 1, math.min(ring.spots, #targets) do
		table.insert(spots, BossRules.Clamp(flat(targets[i]), def, ring.radiusStuds))
	end
	local anchor = if #targets > 0 then flat(targets[1]) else Vector3.new(def.arenaCenterX, 0, def.arenaCenterZ)
	local k = 0
	while #spots < ring.spots do
		local angle = k * (2 * math.pi / ring.spots)
		table.insert(spots, BossRules.Clamp(anchor + Vector3.new(math.cos(angle), 0, math.sin(angle)) * ring.spreadStuds, def, ring.radiusStuds))
		k += 1
	end
	return spots
end

-- Where `count` summoned helpers appear round the boss (flat, inside the arena).
function BossRules.SummonSpots(center: Vector3, count: number, def: Bosses.BossDef): { Vector3 }
	local spots: { Vector3 } = {}
	for i = 1, count do
		local angle = (i - 0.5) * (2 * math.pi / count) + math.pi / 2
		table.insert(spots, BossRules.Clamp(flat(center) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * def.summon.spreadStuds, def, 2))
	end
	return spots
end

-- Damage the boss actually takes from `amount`: multiplied while open, never
-- more than the HP left. Returns the new HP and the damage applied.
function BossRules.ApplyDamage(hp: number, amount: number, windowOpen: boolean, openMultiplier: number): (number, number)
	if amount <= 0 or hp <= 0 then
		return hp, 0
	end
	local scaled = if windowOpen then amount * openMultiplier else amount
	local applied = math.min(hp, scaled)
	return hp - applied, applied
end

-- Reward share rule: a participant who dealt at least `fraction` of the
-- boss's max HP qualifies (docs/CONTRACTS.md: 5%).
function BossRules.Qualifies(damageDealt: number, maxHp: number, fraction: number): boolean
	return damageDealt >= maxHp * fraction
end

return BossRules
