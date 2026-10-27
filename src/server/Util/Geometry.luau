--!strict
-- Shared server hit geometry. Only Collision folders (the courtyard's and the
-- regions') block sight or movement, so decor never changes combat results.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)

local Geometry = {}

-- Collision folders: the courtyard's plus every region's (M2-B), including
-- the ones inside owned house plots.
local function collisionParams(): RaycastParams?
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	local collision = root and root:FindFirstChild("Collision")
	if not root or not collision then
		return nil
	end
	local folders: { Instance } = { collision }
	-- Known spots only (not GetDescendants): this runs on every hit and
	-- movement check.
	local regions = root:FindFirstChild("Regions")
	if regions then
		for _, child in regions:GetChildren() do
			local c = if child.Name == "Collision" then child else child:FindFirstChild("Collision")
			if c then
				table.insert(folders, c)
			end
			local plots = child:FindFirstChild("Plots")
			if plots then
				for _, plot in plots:GetChildren() do
					local owned = plot:FindFirstChild("Owned")
					local oc = owned and owned:FindFirstChild("Collision")
					if oc then
						table.insert(folders, oc)
					end
				end
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = folders
	return params
end

function Geometry.Flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- True when nothing in Collision sits between the two points.
function Geometry.LineOfSight(from: Vector3, to: Vector3): boolean
	local params = collisionParams()
	if not params then
		return true
	end
	return workspace:Raycast(from, to - from, params) == nil
end

-- Movement path check: blocked only when a probe at root height AND a probe
-- lifted above low ledges both hit Collision, so stepping/jumping onto the
-- low tier or over cover is not mistaken for passing through a wall.
function Geometry.PathClear(from: Vector3, to: Vector3): boolean
	if (to - from).Magnitude < 0.05 then
		return true
	end
	if Geometry.LineOfSight(from, to) then
		return true
	end
	local lift = Vector3.new(0, Prototype.Movement.WallProbeLiftStuds, 0)
	return Geometry.LineOfSight(from + lift, to + lift)
end

-- Distance a body of `radius` can travel from `from` along `dir` before hitting Collision.
function Geometry.ClearDistance(from: Vector3, dir: Vector3, distance: number, radius: number): number
	local params = collisionParams()
	if not params then
		return distance
	end
	local hit = workspace:Spherecast(from, radius, dir * distance, params)
	if not hit then
		return distance
	end
	return math.max(0, hit.Distance - 0.1)
end

-- Target inside a flat sector in front of `origin` (reach measured to the
-- target surface), within the height band and with clear line of sight.
function Geometry.InSector(
	origin: Vector3,
	aim: Vector3,
	target: Vector3,
	reach: number,
	arcDeg: number,
	targetRadius: number
): boolean
	if math.abs(target.Y - origin.Y) > Prototype.Combat.MaxHeightDiffStuds then
		return false
	end
	local offset = Geometry.Flat(target - origin)
	local dist = offset.Magnitude
	if dist > reach + targetRadius then
		return false
	end
	if dist > 1e-3 then
		local cos = offset.Unit:Dot(aim)
		if cos < math.cos(math.rad(arcDeg / 2)) then
			return false
		end
	end
	return Geometry.LineOfSight(origin, target)
end

return Geometry
