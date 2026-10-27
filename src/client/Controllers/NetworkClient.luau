--!strict
-- Client side of the contract transport. Sends ActionRequests with unique
-- requestIds, routes ActionResults, drops stale snapshots by revision and
-- sends `ready` (with bounded retry) to get the initial snapshot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)

local NetworkClient = {}

local actionRequest: RemoteEvent? = nil
local counter = 0
local latestRevision = -1
local latestSnapshot: Contracts.SnapshotEvent? = nil
local resultListeners: { (Contracts.ActionResult, string) -> () } = {}
local snapshotListeners: { (Contracts.SnapshotEvent) -> () } = {}
local fxListeners: { (Contracts.CombatFxEvent) -> () } = {}
local pendingActions: { [string]: string } = {}
local readyOk = false

function NetworkClient.Send(action: Contracts.ActionName, payload: { [string]: any }): string?
	local remote = actionRequest
	if not remote then
		return nil
	end
	counter += 1
	local requestId = tostring((Players.LocalPlayer :: Player).UserId) .. "-" .. counter
	pendingActions[requestId] = action
	remote:FireServer({ requestId = requestId, action = action, payload = payload })
	return requestId
end

function NetworkClient.OnResult(callback: (Contracts.ActionResult, string) -> ())
	table.insert(resultListeners, callback)
end

function NetworkClient.OnSnapshot(callback: (Contracts.SnapshotEvent) -> ())
	table.insert(snapshotListeners, callback)
	if latestSnapshot then
		task.spawn(callback, latestSnapshot)
	end
end

function NetworkClient.OnFx(callback: (Contracts.CombatFxEvent) -> ())
	table.insert(fxListeners, callback)
end

function NetworkClient.GetSnapshot(): Contracts.SnapshotEvent?
	return latestSnapshot
end

local function onResult(result: Contracts.ActionResult)
	local action = pendingActions[result.requestId] or "?"
	pendingActions[result.requestId] = nil
	if action == "ready" and result.ok then
		readyOk = true
	end
	for _, callback in resultListeners do
		task.spawn(callback, result, action)
	end
end

local function onState(event: Contracts.StateEvent)
	if event.kind == "snapshot" then
		if event.revision <= latestRevision then
			return -- stale or duplicate
		end
		latestRevision = event.revision
		latestSnapshot = event
		for _, callback in snapshotListeners do
			task.spawn(callback, event)
		end
	elseif event.kind == "combat_fx" then
		for _, callback in fxListeners do
			task.spawn(callback, event)
		end
	end
end

-- Returns false when the server could not be reached; the caller shows it.
function NetworkClient.Start(): boolean
	local folder = ReplicatedStorage:WaitForChild(Contracts.RemoteFolderName, 15)
	if not folder then
		return false
	end
	local request = folder:WaitForChild(Contracts.ActionRequestName, 5) :: RemoteEvent?
	local result = folder:WaitForChild(Contracts.ActionResultName, 5) :: RemoteEvent?
	local state = folder:WaitForChild(Contracts.StateEventName, 5) :: RemoteEvent?
	if not (request and result and state) then
		return false
	end
	actionRequest = request
	result.OnClientEvent:Connect(onResult)
	state.OnClientEvent:Connect(onState)

	for _ = 1, 5 do
		NetworkClient.Send("ready", {})
		local started = os.clock()
		while not readyOk and os.clock() - started < 3 do
			task.wait(0.1)
		end
		if readyOk then
			return true
		end
	end
	return false
end

return NetworkClient
