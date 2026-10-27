--!strict
-- Creates/reuses only project-owned ReplicatedStorage/SpiritWardRemotes.
-- Never destroys a pre-existing remote folder or unrelated instances.
-- Gates every ActionRequest:
-- shape → action whitelist → rate limit → requestId dedupe → payload schema
-- → handler. Handlers return a ResultCode; the client never sends damage,
-- targets or positions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)

type ResultCode = Contracts.ResultCode
type Handler = (player: Player, payload: { [string]: any }) -> ResultCode
type FieldKind = "integer" | "direction" | "string"

-- Allowed payload keys per action; anything else is INVALID_PAYLOAD.
local SCHEMAS: { [string]: { [string]: FieldKind } } = {
	ready = {},
	basic_attack = { sequence = "integer", aimDirection = "direction" },
	cast_skill = { skillId = "string", aimDirection = "direction" },
	dash = { moveDirection = "direction" },
	transform = {},
	claim_quest = { questId = "string" },
	apply_seal = { itemInstanceId = "string", sealId = "string" },
	choose_class = { classId = "string" },
}

type Bucket = { tokens: number, at: number }
type CacheEntry = { key: string, result: Contracts.ActionResult, expires: number }

local NetworkService = {}

local actionRequest: RemoteEvent
local actionResult: RemoteEvent
local stateEvent: RemoteEvent
local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { [string]: Bucket } } = {}
local caches: { [Player]: { [string]: CacheEntry } } = {}
local getRevision: (Player) -> number = function()
	return 0
end

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- Contract: finite, |Y| <= 0.01, magnitude in [0.99, 1.01]; returned flat and re-normalised.
function NetworkService.ValidateDirection(v: any): Vector3?
	if typeof(v) ~= "Vector3" then
		return nil
	end
	if not (isFinite(v.X) and isFinite(v.Y) and isFinite(v.Z)) then
		return nil
	end
	if math.abs(v.Y) > Contracts.DirectionMaxAbsY then
		return nil
	end
	local m = v.Magnitude
	if m < Contracts.DirectionMinMagnitude or m > Contracts.DirectionMaxMagnitude then
		return nil
	end
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	return flat.Unit
end

local function checkField(kind: FieldKind, value: any): boolean
	if kind == "integer" then
		return type(value) == "number" and isFinite(value) and value == math.floor(value) and math.abs(value) < 2 ^ 31
	elseif kind == "string" then
		return type(value) == "string" and #value <= 32
	else
		return NetworkService.ValidateDirection(value) ~= nil
	end
end

local function validatePayload(action: string, payload: any): boolean
	local schema = SCHEMAS[action]
	if type(payload) ~= "table" then
		return false
	end
	for key, value in payload do
		local kind = type(key) == "string" and schema[key]
		if not kind or not checkField(kind, value) then
			return false
		end
	end
	for key in schema do
		if payload[key] == nil then
			return false
		end
	end
	return true
end

-- Deterministic key so identical retries match and changed payloads do not.
local function payloadKey(action: string, payload: { [string]: any }): string
	local keys = {}
	for key in payload do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = { action }
	for _, key in keys do
		table.insert(parts, key .. "=" .. tostring(payload[key]))
	end
	return table.concat(parts, ";")
end

local function takeToken(player: Player, action: string): boolean
	local limit = Contracts.RateLimits[action]
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[action]
	if not bucket then
		bucket = { tokens = limit.burst, at = now }
		perPlayer[action] = bucket
	end
	bucket.tokens = math.min(limit.burst, bucket.tokens + (now - bucket.at) * limit.perSec)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function reply(player: Player, requestId: string, code: ResultCode): Contracts.ActionResult
	local result: Contracts.ActionResult = {
		requestId = requestId,
		ok = code == "OK",
		code = code,
		revision = getRevision(player),
	}
	actionResult:FireClient(player, result)
	return result
end

local function onRequest(player: Player, request: any)
	if type(request) ~= "table" then
		return
	end
	local requestId = request.requestId
	local action = request.action
	if type(requestId) ~= "string" or #requestId == 0 or #requestId > Contracts.MaxRequestIdBytes then
		return -- cannot address a reply without a valid id
	end
	if type(action) ~= "string" or SCHEMAS[action] == nil then
		reply(player, requestId, "INVALID_PAYLOAD")
		return
	end
	if not takeToken(player, action) then
		reply(player, requestId, "RATE_LIMITED")
		return
	end

	local payload = request.payload
	if not validatePayload(action, payload) then
		reply(player, requestId, "INVALID_PAYLOAD")
		return
	end

	local now = os.clock()
	local cache = caches[player]
	if not cache then
		cache = {}
		caches[player] = cache
	end
	local key = payloadKey(action, payload)
	local cached = cache[requestId]
	if cached and cached.expires > now then
		if cached.key == key then
			actionResult:FireClient(player, cached.result)
		else
			reply(player, requestId, "INVALID_PAYLOAD")
		end
		return
	end

	local handler = handlers[action]
	local code: ResultCode = "NOT_READY"
	if handler then
		local ok, handled = pcall(handler, player, payload)
		if ok then
			code = handled
		else
			warn("[SpiritWard] handler error", action, handled)
			code = "INTERNAL_ERROR"
		end
	end
	cache[requestId] = {
		key = key,
		result = reply(player, requestId, code),
		expires = now + Contracts.RequestCacheTtlSec,
	}
end

local function pruneCaches()
	local now = os.clock()
	for _, cache in caches do
		for id, entry in cache do
			if entry.expires <= now then
				cache[id] = nil
			end
		end
	end
end

function NetworkService.Handle(action: string, handler: Handler)
	assert(SCHEMAS[action], "unknown action " .. action)
	handlers[action] = handler
end

function NetworkService.SetRevisionSource(source: (Player) -> number)
	getRevision = source
end

function NetworkService.SendState(player: Player, event: Contracts.StateEvent)
	stateEvent:FireClient(player, event)
end

-- combat_fx goes only to players near the event.
function NetworkService.BroadcastFx(event: Contracts.CombatFxEvent, radius: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - event.position).Magnitude <= radius then
			stateEvent:FireClient(player, event)
		end
	end
end

local fxCounter = 0

function NetworkService.EmitFx(effectId: string, position: Vector3, actorUserId: number?, enemyId: string?)
	fxCounter += 1
	NetworkService.BroadcastFx({
		kind = "combat_fx",
		eventId = "fx-" .. fxCounter,
		actorUserId = actorUserId,
		enemyId = enemyId,
		effectId = effectId,
		position = position,
	}, Prototype.Combat.FxRadiusStuds)
end

function NetworkService.Init()
	local existing = ReplicatedStorage:FindFirstChild(Contracts.RemoteFolderName)
	local folder: Folder
	if existing then
		assert(existing:IsA("Folder") and existing:GetAttribute("OwnedBy") == "SpiritWard",
			"SpiritWardRemotes name collision: existing instance was preserved")
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = Contracts.RemoteFolderName
		folder:SetAttribute("OwnedBy", "SpiritWard")
	end
	local function ensureRemote(name: string): RemoteEvent
		local child = folder:FindFirstChild(name)
		if child then
			assert(child:IsA("RemoteEvent") and child:GetAttribute("OwnedBy") == "SpiritWard",
				"Remote name collision preserved: " .. name)
			return child :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote:SetAttribute("OwnedBy", "SpiritWard")
		remote.Parent = folder
		return remote
	end
	actionRequest = ensureRemote(Contracts.ActionRequestName)
	actionResult = ensureRemote(Contracts.ActionResultName)
	stateEvent = ensureRemote(Contracts.StateEventName)
	if not folder.Parent then
		folder.Parent = ReplicatedStorage
	end
end

function NetworkService.Start()
	actionRequest.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		caches[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			pruneCaches()
		end
	end)
end

return NetworkService
