--!strict
-- Server movement authority for P1. Samples each live character's root on a
-- fixed interval and applies MovementRules: walking within speed tolerance or
-- an accepted dash (distance, path and time window set by the server) is
-- accepted; anything else is reconciled by moving the character back to the
-- last accepted position. Corrections are counted on the Player attribute
-- `MovementCorrections` so tests and QA can observe them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Geometry = require(script.Parent.Parent.Util.Geometry)
local MovementRules = require(script.Parent.Parent.Util.MovementRules)

local M = Prototype.Movement

local PARAMS: MovementRules.Params = {
	speedTolerance = M.SpeedTolerance,
	slackStuds = M.SlackStuds,
	pendingGraceSec = M.PendingGraceSec,
	dashDistance = Prototype.Dash.DistanceStuds,
	dashWindowSec = Prototype.Dash.DurationSec + M.DashLatencyGraceSec,
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
}

local MovementService = {}

local playerState: PlayerState
local trackers: { [Player]: MovementRules.Tracker } = {}

local function now(): number
	return os.clock()
end

local function reconcile(player: Player, root: BasePart, restore: Vector3)
	local character = player.Character
	if not character then
		return
	end
	-- Keep the current facing; only position is corrected.
	local offset = restore - root.Position
	character:PivotTo(character:GetPivot() + offset)
	root.AssemblyLinearVelocity = Vector3.zero
	player:SetAttribute("MovementCorrections", (player:GetAttribute("MovementCorrections") or 0) + 1)
end

local function step()
	local t = now()
	for _, player in Players:GetPlayers() do
		local root = playerState.IsAlive(player) and playerState.GetRoot(player)
		local tracker = trackers[player]
		if not root then
			continue
		end
		if not tracker then
			trackers[player] = MovementRules.NewTracker(root.Position, t)
			continue
		end
		local character = player.Character :: Model
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		-- Server-side WalkSpeed; a client-side change does not replicate.
		local walkSpeed = humanoid and humanoid.WalkSpeed or 16
		local verdict, restore = MovementRules.Evaluate(tracker, root.Position, t, walkSpeed, PARAMS, Geometry.PathClear)
		if verdict == "reconcile" and restore then
			reconcile(player, root, restore)
		end
	end
end

-- Called by CombatService once a dash request passes alive/cooldown checks.
-- Returns the distance the server allows along `dir` from the last accepted
-- position (walls shorten it).
function MovementService.BeginDash(player: Player, dir: Vector3): number
	local tracker = trackers[player]
	local root = playerState.GetRoot(player)
	if not tracker then
		if not root then
			return 0
		end
		tracker = MovementRules.NewTracker(root.Position, now())
		trackers[player] = tracker
	end
	local maxDistance = Geometry.ClearDistance(tracker.anchor, dir, Prototype.Dash.DistanceStuds, M.DashProbeRadiusStuds)
	MovementRules.BeginDash(tracker, dir, maxDistance, now(), PARAMS)
	return maxDistance
end

-- Anchor position the server currently trusts (for FX and tests).
function MovementService.GetAnchor(player: Player): Vector3?
	local tracker = trackers[player]
	return tracker and tracker.anchor
end

function MovementService.Init(deps: { PlayerState: PlayerState })
	playerState = deps.PlayerState
end

function MovementService.Start()
	local function watch(player: Player)
		player:SetAttribute("MovementCorrections", 0)
		player.CharacterAdded:Connect(function()
			-- Server spawns are trusted: drop the old anchor now so the next
			-- sample starts a fresh tracker at the spawn position.
			trackers[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		trackers[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(M.CheckIntervalSec)
			step()
		end
	end)
end

return MovementService
