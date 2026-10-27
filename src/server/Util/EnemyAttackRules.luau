--!strict
-- Pure enemy attack geometry (M2-C). At the start of a telegraph the server
-- fixes a Plan from the enemy and its target; the warning shows that plan and
-- the hit at the end checks the same plan, so what players see is what hits.
-- All checks are flat (X/Z); EnemyService adds the height band and line of
-- sight. Shapes are described in Definitions/Enemies (AttackShape).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enemies = require(ReplicatedStorage.Shared.Definitions.Enemies)

export type Plan = {
	shape: Enemies.AttackShape,
	origin: Vector3, -- enemy body position when the telegraph started
	dir: Vector3, -- flat unit vector toward the target
	length: number, -- line length (charge, lunge) or jump distance (leap)
	width: number, -- line width (charge, lunge)
	radius: number, -- circle radius (burst round origin, leap round center)
	center: Vector3, -- burst: origin; leap: landing; lines: the far end
}

-- How far a body may travel from `origin` along `dir` (flat unit) for
-- `distance`; the service passes walls and the leash in here.
export type ClearFn = (origin: Vector3, dir: Vector3, distance: number) -> number

local EnemyAttackRules = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Distance from `origin` along flat unit `dir` that stays inside the circle
-- of `radius` round `center` (0 when already outside it).
function EnemyAttackRules.DistanceInsideCircle(origin: Vector3, dir: Vector3, center: Vector3, radius: number): number
	local o = flat(origin - center)
	local b = o:Dot(dir)
	local c = o:Dot(o) - radius * radius
	if c > 0 then
		return 0
	end
	-- Inside: t² + 2bt + c = 0 has one positive root.
	return -b + math.sqrt(b * b - c)
end

function EnemyAttackRules.Plan(def: Enemies.EnemyDef, origin: Vector3, target: Vector3, clear: ClearFn): Plan
	local t = def.tuning
	local offset = flat(target - origin)
	local dir = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.new(0, 0, -1)
	local shape = t.attackShape
	if shape == "burst" then
		return { shape = shape, origin = origin, dir = dir, length = 0, width = 0, radius = t.attackHitRangeStuds, center = origin }
	elseif shape == "leap" then
		local wanted = math.min(offset.Magnitude, t.attackHitRangeStuds)
		local length = math.clamp(clear(origin, dir, wanted), 0, wanted)
		return { shape = shape, origin = origin, dir = dir, length = length, width = 0, radius = t.attackWidthStuds, center = origin + dir * length }
	end
	-- charge / lunge: a fixed-length line, cut short by walls (and the leash for charge).
	local length = math.clamp(clear(origin, dir, t.attackHitRangeStuds), 0, t.attackHitRangeStuds)
	return { shape = shape, origin = origin, dir = dir, length = length, width = t.attackWidthStuds, radius = 0, center = origin + dir * length }
end

-- True when a point (a player's root) is inside the plan's hit area.
function EnemyAttackRules.Hits(plan: Plan, point: Vector3): boolean
	if plan.shape == "burst" or plan.shape == "leap" then
		return flat(point - plan.center).Magnitude <= plan.radius
	end
	local rel = flat(point - plan.origin)
	local along = rel:Dot(plan.dir)
	local across = (rel - plan.dir * along).Magnitude
	return along >= 0 and along <= plan.length and across <= plan.width / 2
end

-- Where the enemy stands after the attack, or nil when it stays put.
function EnemyAttackRules.EndPosition(plan: Plan): Vector3?
	if plan.shape == "charge" or plan.shape == "leap" then
		return plan.center
	end
	return nil
end

return EnemyAttackRules
