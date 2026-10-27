--!strict
-- One-command runtime QA for server movement authority (P1-E).
-- Not required by gameplay. During Play, switch the Command Bar to Client
-- and run:
--   require(game.Players.LocalPlayer.PlayerScripts.Client.Tests.MovementQa).Run()
-- It walks, then tries cheats (teleport, wall crossing, dash during
-- cooldown) and one legit dash, printing "[QA] PASS/FAIL" lines and a summary.
-- Takes about 20 seconds; keep hands off the keyboard while it runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)

local MovementQa = {}

local player = Players.LocalPlayer :: Player
local results: { [string]: string } = {}
local counter = 0

local function root(): BasePart
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart") :: BasePart
end

local function corrections(): number
	return (player:GetAttribute("MovementCorrections") :: number?) or 0
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function send(action: string, payload: { [string]: any }): string
	counter += 1
	local id = "qa-move-" .. counter .. "-" .. math.floor(os.clock() * 1000)
	local remotes = ReplicatedStorage:WaitForChild(Contracts.RemoteFolderName)
	;(remotes:WaitForChild(Contracts.ActionRequestName) :: RemoteEvent):FireServer({
		requestId = id,
		action = action,
		payload = payload,
	})
	return id
end

local function check(name: string, ok: boolean, detail: string)
	local line = string.format("[QA] %s %s — %s", if ok then "PASS" else "FAIL", name, detail)
	if ok then
		print(line)
	else
		warn(line)
	end
	table.insert(results, (if ok then "PASS " else "FAIL ") .. name)
end

-- Same planar dash the real client uses, for the legit-dash case.
local function predictDash(r: BasePart, dir: Vector3)
	local speed = Prototype.Dash.DistanceStuds / Prototype.Dash.DurationSec
	local attachment = Instance.new("Attachment")
	attachment.Parent = r
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	velocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	velocity.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	velocity.MaxForce = 1e6
	velocity.Parent = r
	task.wait(Prototype.Dash.DurationSec)
	velocity:Destroy()
	attachment:Destroy()
	r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
end

function MovementQa.Run()
	table.clear(results)
	print("[QA] Movement QA start — do not move until it finishes (~20 s)")
	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid

	-- 1. Legit walk to the south side of the test wall (X=-18, Z=-2). Must not be corrected.
	local r = root()
	local before = corrections()
	local target = Vector3.new(-18, r.Position.Y, -2)
	humanoid:MoveTo(target)
	local reached = false
	local conn = humanoid.MoveToFinished:Connect(function(ok)
		reached = ok
	end)
	local started = os.clock()
	while not reached and os.clock() - started < 10 do
		task.wait(0.1)
	end
	conn:Disconnect()
	task.wait(0.6)
	check("walk", reached and corrections() == before,
		string.format("reached=%s corrections %d→%d", tostring(reached), before, corrections()))

	-- 2. Teleport 20 studs east (open ground). Must be pulled back.
	r = root()
	local origin = r.Position
	before = corrections()
	r.CFrame += Vector3.new(20, 0, 0)
	task.wait(1)
	check("teleport", corrections() > before and flat(root().Position, origin) < 4,
		string.format("corrections %d→%d, %.1f studs from start", before, corrections(), flat(root().Position, origin)))

	-- 3. Step through the test wall (Z=-6) to Z=-9. Must be pulled back to Z > -6.
	task.wait(0.5)
	r = root()
	before = corrections()
	r.CFrame = CFrame.new(r.Position.X, r.Position.Y, -9)
	task.wait(1)
	check("wall", corrections() > before and root().Position.Z > -6,
		string.format("corrections %d→%d, Z=%.1f", before, corrections(), root().Position.Z))

	-- 4. Dash during cooldown: first request is OK, second (0.8 s later) is
	-- rejected, and the client moves anyway. Must be pulled back.
	task.wait(0.5)
	send("dash", { moveDirection = Vector3.new(0, 0, 1) })
	task.wait(0.8)
	r = root()
	origin = r.Position
	before = corrections()
	send("dash", { moveDirection = Vector3.new(0, 0, 1) })
	r.CFrame += Vector3.new(0, 0, 10)
	task.wait(1.2)
	check("dash during cooldown", corrections() > before and flat(root().Position, origin) < 4,
		string.format("corrections %d→%d, %.1f studs from start", before, corrections(), flat(root().Position, origin)))

	-- 5. Legit dash after cooldown, south into open ground. Must NOT be corrected and must travel.
	task.wait(Prototype.Dash.CooldownSec + 0.3)
	r = root()
	origin = r.Position
	before = corrections()
	local dir = Vector3.new(0, 0, 1)
	send("dash", { moveDirection = dir })
	predictDash(r, dir)
	task.wait(1)
	local moved = flat(root().Position, origin)
	check("legit dash", corrections() == before and moved > 8,
		string.format("corrections %d→%d, moved %.1f studs", before, corrections(), moved))

	local failed = 0
	for _, line in results do
		if string.sub(line, 1, 4) == "FAIL" then
			failed += 1
		end
	end
	print(string.format("[QA] SUMMARY %d/%d passed | %s", #results - failed, #results, table.concat(results, " | ")))
end

return MovementQa
