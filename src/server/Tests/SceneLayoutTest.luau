--!strict
-- Regression tests for the arena build (VB-01 visual pass).
-- Visual work must not move gameplay geometry, so Collision and Markers are
-- compared against the P1 layout, and every Decor part is checked to be
-- non-colliding and to respect the camera band rule from ShrineCourtyard.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.SceneLayoutTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local ShrineCourtyard = require(script.Parent.Parent.Scene.ShrineCourtyard)

local HALF = Prototype.Arena.SizeStuds / 2
local FLOOR_Y = Prototype.Arena.FloorTopY
-- Lights are the main per-frame cost of the dressing on mobile.
local MAX_DECOR_LIGHTS = 24
local MAX_DECOR_PARTS = 2500
-- Tall landmarks that stand in the camera band on purpose: their heights match
-- the P1 collision proxies (torii, six lanterns) or the lantern avenue, which
-- stays below the camera's sight line.
local CAMERA_BAND_EXEMPT: { [string]: boolean } = { Torii = true, StoneLantern = true }
-- Dressing (attribute Dresses = collider name) may overhang its collider by
-- at most this much sideways and above, e.g. the test wall's tiled cap.
local DRESS_MARGIN_SIDE = 1
local DRESS_MARGIN_TOP = 1.5

-- P1 layout fingerprint: name, class, size, position, right/up vectors, collide.
-- Generated from the P1 SceneService before VB-01; update only with a
-- reviewed collision change (M2-B: south gate).
local EXPECTED_COLLISION = {
	"BoundEast Part 1,30,100 50.5,16,0 1,0,0 0,1,0 true 1",
	"BoundNorth Part 100,30,1 0,16,-50.5 1,0,0 0,1,0 true 1",
	-- M2-B (reviewed): south bound split for the gate to Mistwood (gate half-width 6).
	"BoundSouthEast Part 44,30,1 28,16,50.5 1,0,0 0,1,0 true 1",
	"BoundSouthWest Part 44,30,1 -28,16,50.5 1,0,0 0,1,0 true 1",
	"BoundWest Part 1,30,100 -50.5,16,0 1,0,0 0,1,0 true 1",
	"Cover Part 6,4,2 10,3,-16 1,0,0 0,1,0 true 0",
	"Floor Part 100,1,100 0,0.5,0 1,0,0 0,1,0 true 0",
	"LanternProxy Part 2,5.7,2 -40,3.85,-44 1,0,0 0,1,0 true 1",
	"LanternProxy Part 2,5.7,2 -40,3.85,44 1,0,0 0,1,0 true 1",
	"LanternProxy Part 2,5.7,2 -46,3.85,0 1,0,0 0,1,0 true 1",
	"LanternProxy Part 2,5.7,2 40,3.85,-44 1,0,0 0,1,0 true 1",
	"LanternProxy Part 2,5.7,2 40,3.85,44 1,0,0 0,1,0 true 1",
	"LanternProxy Part 2,5.7,2 46,3.85,-10 1,0,0 0,1,0 true 1",
	"LowTier Part 20,5,16 28,3.5,18 1,0,0 0,1,0 true 0",
	"LowTierRamp WedgePart 12,5,8 14,3.5,18 0,0,-1 0,1,0 true 0",
	"TestWall Part 24,10,1.5 -18,6,-6 1,0,0 0,1,0 true 0",
	"ToriiPillarProxy Part 1.6,14,1.6 -7,8,-47 1,0,0 0,1,0 true 1",
	"ToriiPillarProxy Part 1.6,14,1.6 7,8,-47 1,0,0 0,1,0 true 1",
}

local EXPECTED_MARKERS = {
	"Checkpoint SpawnLocation 6,0.2,6 -36,1.1,20 1,0,0 0,1,0 false 0.5",
	"EnemySpawn1 Part 2,0.2,2 -26,1.1,-26 1,0,0 0,1,0 false 0.6",
	"EnemySpawn2 Part 2,0.2,2 22,1.1,-28 1,0,0 0,1,0 false 0.6",
	"EnemySpawn3 Part 2,0.2,2 30,6.1,18 1,0,0 0,1,0 false 0.6",
	"PlayerSpawn SpawnLocation 6,0.2,6 0,1.1,38 1,0,0 0,1,0 false 0.5",
}

local function num(n: number): string
	local r = math.floor(n * 1000 + 0.5) / 1000
	if math.abs(r) < 0.0005 then
		r = 0
	end
	return string.format("%g", r)
end

local function vec(v: Vector3): string
	return num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z)
end

local function fingerprint(folder: Instance): { string }
	local rows = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			local cf = child.CFrame
			table.insert(
				rows,
				table.concat({
					child.Name,
					child.ClassName,
					vec(child.Size),
					vec(cf.Position),
					vec(cf.RightVector),
					vec(cf.UpVector),
					tostring(child.CanCollide),
					num(child.Transparency),
				}, " ")
			)
		else
			table.insert(rows, child.Name .. " " .. child.ClassName)
		end
	end
	table.sort(rows)
	return rows
end

local function sameRows(actual: { string }, expected: { string }): (boolean, string?)
	local want = table.clone(expected)
	table.sort(want)
	if #actual ~= #want then
		return false, string.format("count %d, expected %d", #actual, #want)
	end
	for i, row in actual do
		if row ~= want[i] then
			return false, "got '" .. row .. "' expected '" .. want[i] .. "'"
		end
	end
	return true, nil
end

-- Horizontal half-extents of a part's world AABB.
local function halfXZ(p: BasePart): (number, number)
	local cf, s = p.CFrame, p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local hx = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z
	local hz = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	return hx, hz
end

local function topY(p: BasePart): number
	local cf, s = p.CFrame, p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return cf.Position.Y + math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z
end

local function exemptLandmark(p: Instance, decor: Instance): boolean
	if p:GetAttribute("Dresses") ~= nil then
		return true -- checked against its collider in its own case
	end
	local node = p.Parent
	while node and node ~= decor do
		if node:IsA("Model") and CAMERA_BAND_EXEMPT[node.Name] then
			return true
		end
		node = node.Parent
	end
	return false
end

local function arena(): (Instance?, Instance?, Instance?)
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	if not root then
		return nil, nil, nil
	end
	return root:FindFirstChild("Collision"), root:FindFirstChild("Markers"), root:FindFirstChild("Decor")
end

local function decorParts(): { BasePart }
	local _, _, decor = arena()
	local parts = {}
	if decor then
		for _, d in decor:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	end
	return parts
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "collision layout unchanged from P1",
		run = function()
			local collision = arena()
			if not collision then
				return false, "no Collision folder (build the arena first)"
			end
			return sameRows(fingerprint(collision), EXPECTED_COLLISION)
		end,
	},
	{
		name = "markers unchanged from P1",
		run = function()
			local _, markers = arena()
			if not markers then
				return false, "no Markers folder"
			end
			return sameRows(fingerprint(markers), EXPECTED_MARKERS)
		end,
	},
	{
		name = "decor never collides, queries or touches",
		run = function()
			local parts = decorParts()
			if #parts == 0 then
				return false, "no Decor parts"
			end
			for _, p in parts do
				if p.CanCollide or p.CanQuery or p.CanTouch then
					return false, p:GetFullName()
				end
			end
			return true, nil
		end,
	},
	{
		name = "tall decor stays out of the camera band",
		run = function()
			local _, _, decor = arena()
			local band = ShrineCourtyard.TallRingStuds - HALF
			for _, p in decorParts() do
				if topY(p) > FLOOR_Y + ShrineCourtyard.LowEdgeMaxHeight and not exemptLandmark(p, decor :: Instance) then
					local hx, hz = halfXZ(p)
					local pos = p.Position
					local outside = math.max(math.abs(pos.X) - hx, math.abs(pos.Z) - hz) - HALF
					if outside < band then
						return false, string.format("%s is %.1f studs outside the bounds, needs %.1f", p:GetFullName(), outside, band)
					end
				end
			end
			return true, nil
		end,
	},
	{
		name = "dressing hugs its collider",
		run = function()
			local collision, _, decor = arena()
			if not collision or not decor then
				return false, "arena not built"
			end
			local count = 0
			for _, p in decorParts() do
				local target = p:GetAttribute("Dresses")
				if target ~= nil then
					count += 1
					local c = collision:FindFirstChild(target :: string)
					if not c or not c:IsA("BasePart") then
						return false, p:GetFullName() .. " dresses missing collider " .. tostring(target)
					end
					local phx, phz = halfXZ(p)
					local chx, chz = halfXZ(c)
					local dp, dc = p.Position, c.Position
					local sideOut = math.max(
						math.abs(dp.X - dc.X) + phx - chx,
						math.abs(dp.Z - dc.Z) + phz - chz
					)
					local topOut = topY(p) - topY(c)
					if sideOut > DRESS_MARGIN_SIDE or topOut > DRESS_MARGIN_TOP then
						return false, string.format("%s overhangs %s by %.2f side / %.2f top", p:GetFullName(), c.Name, sideOut, topOut)
					end
				end
			end
			return count > 0, string.format("%d dressing parts", count)
		end,
	},
	{
		-- Katana, scabbard, guardian mask and wisp dressing must never block
		-- movement, hit queries or touches (hits come from the root/body only).
		name = "actor visuals never collide, query or touch",
		run = function()
			local roots: { Instance } = {}
			local arenaRoot = workspace:FindFirstChild(Prototype.WorldNamespace)
			local runtime = arenaRoot and arenaRoot:FindFirstChild("Runtime")
			if runtime then
				table.insert(roots, runtime)
			end
			for _, player in game:GetService("Players"):GetPlayers() do
				local character = player.Character
				if character then
					for _, name in { "Katana", "Saya", "GuardianMask" } do
						local m = character:FindFirstChild(name)
						if m then
							table.insert(roots, m)
						end
					end
				end
			end
			local checked = 0
			for _, r in roots do
				for _, d in r:GetDescendants() do
					if d:IsA("BasePart") then
						checked += 1
						if d.CanCollide or d.CanQuery or d.CanTouch then
							return false, d:GetFullName()
						end
					end
				end
			end
			return true, string.format("%d parts checked", checked)
		end,
	},
	{
		name = "decor budget (parts, lights)",
		run = function()
			local parts = decorParts()
			local lights = 0
			for _, p in parts do
				for _, c in p:GetChildren() do
					if c:IsA("Light") then
						lights += 1
					end
				end
			end
			local detail = string.format("%d parts, %d lights", #parts, lights)
			return #parts <= MAX_DECOR_PARTS and lights <= MAX_DECOR_LIGHTS, detail
		end,
	},
}

local SceneLayoutTest = {}

function SceneLayoutTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[SceneLayoutTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[SceneLayoutTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[SceneLayoutTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

-- Exposed so the expected tables can be regenerated after a reviewed change.
SceneLayoutTest.Fingerprint = fingerprint

return SceneLayoutTest
