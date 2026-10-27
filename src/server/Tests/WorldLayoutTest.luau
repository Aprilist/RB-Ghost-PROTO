--!strict
-- M2-B world checks: village plots round the ring road, regions' decor flags, clear paths, the
-- courtyard camera band, spawns/checkpoints, zone coverage and a budget.
-- Needs the world built (Play, or SceneService.Build() in Edit):
--   require(game.ServerScriptService.Server.Tests.WorldLayoutTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = ReplicatedStorage.Shared.Definitions
local Project = require(Definitions.Project)
local Prototype = require(Definitions.Prototype)
local World = require(Definitions.World)
local Zones = require(Definitions.Zones)
local Mistwood = require(script.Parent.Parent.Scene.Mistwood)
local ShrineCourtyard = require(script.Parent.Parent.Scene.ShrineCourtyard)
local Village = require(script.Parent.Parent.Scene.Village)

local V, M = World.Village, World.Mistwood
local FLOOR_Y = Prototype.Arena.FloorTopY
local MAX_REGION_PARTS = 7000
local MAX_REGION_LIGHTS = 32

local function regions(): Instance?
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	return root and root:FindFirstChild("Regions")
end

local function inCollision(p: Instance): boolean
	local node = p.Parent
	while node and node.Name ~= "Regions" do
		if node.Name == "Collision" then
			return true
		end
		node = node.Parent
	end
	return false
end

local function inMarkers(p: Instance): boolean
	local node = p.Parent
	while node and node.Name ~= "Regions" do
		if node.Name == "Markers" then
			return true
		end
		node = node.Parent
	end
	return false
end

local function parts(): { BasePart }
	local list = {}
	local r = regions()
	if r then
		for _, d in r:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	return list
end

-- World AABB of a part (X/Z half extents, top Y).
local function extents(p: BasePart): (number, number, number)
	local cf, s = p.CFrame, p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local hx = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z
	local hz = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	local top = cf.Position.Y + math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z
	return hx, hz, top
end

local function zoneAt(pos: Vector3): string?
	local ids = {}
	for id in Zones do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		for _, v in Zones[id].volumes do
			local o = pos - v.center
			if math.abs(o.X) <= v.size.X / 2 and math.abs(o.Y) <= v.size.Y / 2 and math.abs(o.Z) <= v.size.Z / 2 then
				return id
			end
		end
	end
	return nil
end

-- Invisible outer walls from Scene/Regions (MistwoodWest, VillageSouth, …) and
-- the courtyard's own bounds. VillageSouth runs across the end of the north
-- road on purpose: the road stops at a roped-off torii, the wall is the world's edge.
local function isBound(p: BasePart): boolean
	if p.Transparency < 1 then
		return false
	end
	return string.find(p.Name, "Bound") ~= nil or string.match(p.Name, "^Village%u") ~= nil or string.match(p.Name, "^Mistwood%u") ~= nil
end

-- X/Z corners of plot `plot` (fence line).
local function plotCorners(plot: World.Plot): { Vector3 }
	local cf = Village.PlotFrame(plot)
	local hx, hz = V.plotSize.x / 2, V.plotSize.z / 2
	local out = {}
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		table.insert(out, (cf * CFrame.new(c[1] * hx, 0, c[2] * hz)).Position)
	end
	return out
end

-- Separating-axis test for two convex X/Z quads.
local function quadsOverlap(a: { Vector3 }, b: { Vector3 }): boolean
	for _, poly in { a, b } do
		for i = 1, #poly do
			local p, q = poly[i], poly[i % #poly + 1]
			local nx, nz = -(q.Z - p.Z), q.X - p.X
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, v in a do
				local d = v.X * nx + v.Z * nz
				aMin, aMax = math.min(aMin, d), math.max(aMax, d)
			end
			for _, v in b do
				local d = v.X * nx + v.Z * nz
				bMin, bMax = math.min(bMin, d), math.max(bMax, d)
			end
			if aMax <= bMin or bMax <= aMin then
				return false
			end
		end
	end
	return true
end

-- Distance from (x, z) to the plot's rectangle (0 inside).
local function distToPlot(plot: World.Plot, x: number, z: number): number
	local local_ = Village.PlotFrame(plot):PointToObjectSpace(Vector3.new(x, 0, z))
	local dx = math.max(math.abs(local_.X) - V.plotSize.x / 2, 0)
	local dz = math.max(math.abs(local_.Z) - V.plotSize.z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "one plot per player slot, all built",
		run = function()
			local r = regions()
			local plots = r and r:FindFirstChild("Village") and (r :: any).Village:FindFirstChild("Plots")
			local want = math.min(#V.plots, Project.TargetPlayersPerServer)
			if #V.plots < Project.TargetPlayersPerServer then
				return false, string.format("%d plots for %d players", #V.plots, Project.TargetPlayersPerServer)
			end
			local count = if plots then #plots:GetChildren() else 0
			return count == #V.plots and want == Project.TargetPlayersPerServer, string.format("%d plots", count)
		end,
	},
	{
		name = "plots ring the ring road, gates on the road, clear of roads, each other and the NPCs",
		run = function()
			local quads = {}
			for i, p in V.plots do
				quads[i] = plotCorners(p)
				for _, c in quads[i] do
					if c.X < V.minX or c.X > V.maxX or c.Z < V.minZ or c.Z > V.maxZ then
						return false, "plot " .. i .. " outside the village"
					end
				end
				-- The gate opens onto a road: its centre is within a few studs of one.
				local gate = (Village.PlotFrame(p) * CFrame.new(0, 0, -V.plotSize.z / 2)).Position
				if Village.DistanceToRoad(gate.X, gate.Z) > 8 then
					return false, "plot " .. i .. " gate is not on a road"
				end
			end
			for i = 1, #quads do
				for j = i + 1, #quads do
					if quadsOverlap(quads[i], quads[j]) then
						return false, string.format("plots %d and %d overlap", i, j)
					end
				end
			end
			-- No road runs into a plot (sampled every 2 studs along each road).
			for _, road in V.roads do
				local pts = road.points
				for k = 1, #pts - 1 do
					local a, b = pts[k], pts[k + 1]
					local steps = math.max(1, math.ceil(math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2) / 2))
					for t = 0, steps do
						local x, z = a.x + (b.x - a.x) * t / steps, a.z + (b.z - a.z) * t / steps
						for i, p in V.plots do
							if distToPlot(p, x, z) < road.halfWidth then
								return false, string.format("%s runs into plot %d", road.name, i)
							end
						end
					end
				end
			end
			-- Things that must stay outside every plot, with their radius.
			local keepOut: { { name: string, x: number, z: number, r: number } } = {
				{ name = "keeper shrine", x = V.keeperShrine.x, z = V.keeperShrine.z, r = 10 },
				{ name = "spawn", x = V.spawn.x, z = V.spawn.z, r = 4 },
				{ name = "grove cottage", x = Village.GroveCottageX(), z = V.grove.z, r = 14 },
				{ name = "pond", x = V.pond.x, z = V.pond.z, r = V.pond.radius },
			}
			for k, h in V.npcHouses do
				table.insert(keepOut, { name = "NPC house " .. k, x = h.x, z = h.z, r = 10 })
			end
			for i, p in V.plots do
				for _, k in keepOut do
					if distToPlot(p, k.x, k.z) < k.r then
						return false, string.format("plot %d overlaps %s", i, k.name)
					end
				end
			end
			return true, string.format("%d plots, yard %dx%d", #V.plots, V.plotSize.x, V.plotSize.z)
		end,
	},
	{
		name = "every plot gate is a short walk from the spawn",
		run = function()
			-- Straight-line bound; the avenue and lanes keep the real walk close to it.
			local far = 0
			for _, p in V.plots do
				local gate = (Village.PlotFrame(p) * CFrame.new(0, 0, -V.plotSize.z / 2)).Position
				far = math.max(far, math.sqrt((gate.X - V.spawn.x) ^ 2 + (gate.Z - V.spawn.z) ^ 2))
			end
			-- Ring village (27 Oct 2026): was 350 with six houses a row.
			return far <= 240, string.format("farthest gate %.0f studs", far)
		end,
	},
	{
		name = "region decor never collides, queries or touches",
		run = function()
			local n = 0
			for _, p in parts() do
				if not inCollision(p) and not inMarkers(p) then
					n += 1
					if p.CanCollide or p.CanQuery or p.CanTouch then
						return false, p:GetFullName()
					end
				end
			end
			return n > 0, string.format("%d decor parts", n)
		end,
	},
	{
		name = "nothing tall in the courtyard camera band",
		run = function()
			local ring = ShrineCourtyard.TallRingStuds
			for _, p in parts() do
				local hx, hz, top = extents(p)
				local pos = p.Position
				if top > FLOOR_Y + ShrineCourtyard.LowEdgeMaxHeight and not isBound(p) then
					-- Inside the box |x| < ring, z < ring around the courtyard?
					if math.abs(pos.X) - hx < ring and pos.Z - hz < ring then
						return false, string.format("%s at %.0f,%.0f", p:GetFullName(), pos.X, pos.Z)
					end
				end
			end
			return true, nil
		end,
	},
	{
		name = "Mistwood path and village roads are clear of solids",
		run = function()
			local r = regions()
			if not r then
				return false, "world not built"
			end
			local checked = 0
			for _, p in parts() do
				if inCollision(p) and p.Name ~= "Ground" and not isBound(p) then
					local hx, hz, top = extents(p)
					local pos = p.Position
					if top > FLOOR_Y + 0.5 then
						checked += 1
						-- Round-ish solids (trunks, posts): the near edge must stay off the path.
						local radius = math.min(hx, hz)
						if pos.Z > M.minZ and pos.Z < M.maxZ and Mistwood.DistanceToPath(pos.X, pos.Z) - radius < M.pathHalfWidth then
							return false, "on the path: " .. p:GetFullName()
						end
						if pos.Z >= V.minZ then
							-- Long rails at an angle (ring plots): sample along the long
							-- side instead of one AABB circle that would cover the road.
							local cf, s = p.CFrame, p.Size / 2
							local long = if s.X >= s.Z then cf.RightVector * s.X else cf.LookVector * s.Z
							local thin = math.min(s.X, s.Z)
							local n = math.max(1, math.ceil(long.Magnitude / math.max(thin, 1)))
							for k = -n, n do
								local q = pos + long * (k / n)
								if Village.DistanceToRoad(q.X, q.Z) - thin < 0 then
									return false, "on a village road: " .. p:GetFullName()
								end
							end
						end
					end
				end
			end
			return checked > 0, string.format("%d solids checked", checked)
		end,
	},
	{
		name = "village spawn and checkpoints are in their zones",
		run = function()
			local r = regions()
			local spawn = r and r:FindFirstChild("VillageSpawn", true)
			local gate = r and r:FindFirstChild("MistwoodGate", true)
			if not spawn or not spawn:IsA("SpawnLocation") or not gate or not gate:IsA("SpawnLocation") then
				return false, "missing VillageSpawn or MistwoodGate"
			end
			local a = zoneAt(spawn.Position + Vector3.new(0, 3, 0))
			local b = zoneAt(gate.Position + Vector3.new(0, 3, 0))
			return a == "last_lantern_village" and b == "mistwood", tostring(a) .. "/" .. tostring(b)
		end,
	},
	{
		name = "zones cover the whole walk: courtyard → corridor → forest → village",
		run = function()
			local y = FLOOR_Y + 3
			local samples = {
				{ Vector3.new(0, y, 0), "p1_arena" },
				{ Vector3.new(0, y, 80), "mistwood" },
				{ Vector3.new(-30, y, 214), "mistwood" },
				{ Vector3.new(0, y, 446), "last_lantern_village" },
				{ Vector3.new(0, y, 830), "last_lantern_village" },
				{ Vector3.new(-186, y, 590), "last_lantern_village" },
			}
			for _, s in samples do
				local got = zoneAt(s[1] :: Vector3)
				if got ~= s[2] then
					return false, string.format("%s → %s, expected %s", tostring(s[1]), tostring(got), s[2] :: string)
				end
			end
			-- Every path point sits in some zone.
			for _, pt in M.path do
				if zoneAt(Vector3.new(pt.x, y, pt.z)) == nil then
					return false, string.format("path point %d,%d has no zone", pt.x, pt.z)
				end
			end
			return true, nil
		end,
	},
	{
		name = "courtyard gate is open, the rest of the south side is closed",
		run = function()
			local root = workspace:FindFirstChild(Prototype.WorldNamespace)
			local collision = root and root:FindFirstChild("Collision")
			local w = collision and collision:FindFirstChild("BoundSouthWest")
			local e = collision and collision:FindFirstChild("BoundSouthEast")
			if not w or not e or not w:IsA("BasePart") or not e:IsA("BasePart") then
				return false, "south bounds missing"
			end
			local half = Prototype.Arena.SizeStuds / 2
			local gate = World.CourtyardGateHalfWidth
			local wEdge = w.Position.X + w.Size.X / 2
			local eEdge = e.Position.X - e.Size.X / 2
			local wFar = w.Position.X - w.Size.X / 2
			local eFar = e.Position.X + e.Size.X / 2
			return math.abs(wEdge + gate) < 0.01 and math.abs(eEdge - gate) < 0.01 and math.abs(wFar + half) < 0.01 and math.abs(eFar - half) < 0.01,
				string.format("gap %.1f..%.1f", wEdge, eEdge)
		end,
	},
	{
		name = "courtyard decor leaves the Mistwood corridor open",
		run = function()
			local root = workspace:FindFirstChild(Prototype.WorldNamespace)
			local decor = root and root:FindFirstChild("Decor")
			if not decor then
				return false, "no courtyard Decor"
			end
			for _, p in decor:GetDescendants() do
				if p:IsA("BasePart") then
					local hx, hz, top = extents(p)
					local pos = p.Position
					if top > FLOOR_Y + ShrineCourtyard.LowEdgeMaxHeight and math.abs(pos.X) - hx < M.corridorHalfWidth and pos.Z + hz > M.minZ and pos.Z - hz < M.corridorEndZ then
						return false, p:GetFullName()
					end
				end
			end
			return true, nil
		end,
	},
	{
		name = "region budget (parts, lights)",
		run = function()
			local list = parts()
			local lights = 0
			local r = regions()
			if r then
				for _, d in r:GetDescendants() do
					if d:IsA("Light") then
						lights += 1
					end
				end
			end
			return #list <= MAX_REGION_PARTS and lights <= MAX_REGION_LIGHTS, string.format("%d parts, %d lights", #list, lights)
		end,
	},
}

local WorldLayoutTest = {}

function WorldLayoutTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[WorldLayoutTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[WorldLayoutTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[WorldLayoutTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return WorldLayoutTest
