--!strict
-- Pure decision logic for server movement authority (no Roblox services),
-- so it can be exercised by MovementRulesTest without players.
--
-- The client owns its character physics, so the server samples the root
-- position and accepts it only when it is explainable by walking, or by a
-- dash the server accepted. Anything else is reconciled: the character is
-- put back at the last accepted ("anchor") position.
--
-- Position updates and the dash request travel on different channels, so a
-- legit predicted dash can be seen before its request lands. Unexplained
-- travel is therefore held as "pending" for a short grace and reconciled
-- unless an accepted dash explains it. Wall crossing and travel no dash could
-- explain are reconciled at once.

export type Params = {
	speedTolerance: number, -- multiplier on WalkSpeed
	slackStuds: number, -- jitter allowance per check
	pendingGraceSec: number, -- wait for a dash request to explain a jump
	dashDistance: number,
	dashWindowSec: number, -- dash duration + latency grace
}

export type Dash = {
	origin: Vector3,
	direction: Vector3, -- flat unit vector the server validated
	maxDistance: number, -- server clear distance along the dash direction
	startedAt: number,
	endsAt: number,
}

export type Tracker = {
	anchor: Vector3,
	anchorAt: number,
	pendingSince: number?,
	dash: Dash?,
	walkCreditStuds: number?, -- finite jitter reserve; never refill it on every accepted sample
}

export type Verdict = "accept" | "hold" | "reconcile"

-- pathClear(from, to) must return false when Collision geometry separates them.
export type PathClear = (Vector3, Vector3) -> boolean

local MovementRules = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
end

function MovementRules.NewTracker(position: Vector3, now: number): Tracker
	return { anchor = position, anchorAt = now, pendingSince = nil, dash = nil }
end

-- Start an accepted dash from the last accepted position. If unexplained
-- travel was pending, the dash window starts when that travel was first seen.
function MovementRules.BeginDash(tracker: Tracker, direction: Vector3, maxDistance: number, now: number, params: Params)
	local seenAt = tracker.pendingSince or now
	tracker.dash = {
		origin = tracker.anchor,
		direction = direction,
		maxDistance = maxDistance,
		-- Walking allowance counts from the anchor sample, covering the walk
		-- between the last accepted position and the moment the dash began.
		startedAt = tracker.anchorAt,
		endsAt = seenAt + params.dashWindowSec,
	}
	tracker.pendingSince = nil
end

-- Evaluate one sample. Mutates the tracker; returns the verdict and, for
-- "reconcile", the position to restore.
function MovementRules.Evaluate(
	tracker: Tracker,
	position: Vector3,
	now: number,
	walkSpeed: number,
	params: Params,
	pathClear: PathClear
): (Verdict, Vector3?)
	local credit = tracker.walkCreditStuds or params.slackStuds
	local dash = tracker.dash
	if dash then
		-- Along the dash: up to the server's clear distance plus walking.
		-- Sideways: walking only. Both measured from the last accepted position.
		local walkAllowance = walkSpeed * math.max(0, now - dash.startedAt) * params.speedTolerance + credit
		local offset = Vector3.new(position.X - dash.origin.X, 0, position.Z - dash.origin.Z)
		local along = offset:Dot(dash.direction)
		local sideways = (offset - dash.direction * along).Magnitude
		local tooFar = along > dash.maxDistance + walkAllowance or along < -walkAllowance or sideways > walkAllowance
		if tooFar or not pathClear(dash.origin, position) then
			local restore = dash.origin
			tracker.dash = nil
			tracker.anchor, tracker.anchorAt, tracker.pendingSince = restore, now, nil
			return "reconcile", restore
		end
		if now >= dash.endsAt then
			local walkedBeyondDash = math.max(0, flatDistance(dash.origin, position) - dash.maxDistance)
			tracker.walkCreditStuds = math.clamp(walkAllowance - walkedBeyondDash, 0, params.slackStuds)
			tracker.dash = nil
			tracker.anchor, tracker.anchorAt = position, now
		end
		return "accept", nil
	end

	if not pathClear(tracker.anchor, position) then
		local restore = tracker.anchor
		tracker.anchorAt, tracker.pendingSince = now, nil
		return "reconcile", restore
	end

	local elapsed = math.max(0, now - tracker.anchorAt)
	local walkBudget = walkSpeed * elapsed * params.speedTolerance + credit
	local distance = flatDistance(tracker.anchor, position)

	-- Once travel is unexplained it stays latched: later walking time never
	-- excuses it, only an accepted dash does (so a rejected dash is undone).
	local pendingSince = tracker.pendingSince
	if pendingSince == nil then
		if distance <= walkBudget then
			tracker.walkCreditStuds = math.clamp(walkBudget - distance, 0, params.slackStuds)
			tracker.anchor, tracker.anchorAt = position, now
			return "accept", nil
		end
		pendingSince = now
		tracker.pendingSince = now
	end
	if distance > params.dashDistance + walkBudget or now - pendingSince > params.pendingGraceSec then
		local restore = tracker.anchor
		tracker.anchorAt, tracker.pendingSince = now, nil
		return "reconcile", restore
	end
	return "hold", nil
end

return MovementRules
