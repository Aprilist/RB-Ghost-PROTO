--!strict
-- Pure quest rules (M2-D) over the ProfileV1 `quests` map
-- (questId → {status, progress}; docs/CONTRACTS.md). No Instances, no
-- services. The server (QuestService) is the only caller that changes a live
-- map, inside ProfileService.Mutate; the client only reads it to draw the
-- tracker and the "!" / "?" over a quest giver.
--
-- Lifecycle: (absent) → active → ready → claimed.
--   Start   needs the prerequisite claimed; starts at progress 0.
--   Record  counts an objective event into every active quest it matches;
--           reaching targetCount makes the quest ready. Progress never
--           passes targetCount, ready/claimed quests ignore events.
--   Claim   ready → claimed, once. Rewards are paid by the caller in the
--           same mutation.

local Quests = require(script.Parent.Parent.Definitions.Quests)

export type QuestStatus = "active" | "ready" | "claimed"
export type QuestRecord = { status: QuestStatus, progress: number }
export type QuestMap = { [string]: QuestRecord }
export type Catalog = { [string]: Quests.QuestDef }

export type StartCode = "OK" | "UNKNOWN" | "STARTED" | "PREREQUISITE"
export type ClaimCode = "OK" | "UNKNOWN" | "QUEST_NOT_READY" | "ALREADY_CLAIMED"

local QuestRules = {}

QuestRules.Catalog = Quests :: Catalog

-- Quest ids in story order (q01 … q05: the ids sort in that order).
function QuestRules.Order(catalog: Catalog?): { string }
	local ids = {}
	for id in catalog or QuestRules.Catalog do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function QuestRules.CanStart(quests: QuestMap, questId: string, catalog: Catalog?): StartCode
	local def = (catalog or QuestRules.Catalog)[questId]
	if not def then
		return "UNKNOWN"
	end
	if quests[questId] ~= nil then
		return "STARTED"
	end
	local pre = def.prerequisiteQuestId
	if pre then
		local record = quests[pre]
		if not record or record.status ~= "claimed" then
			return "PREREQUISITE"
		end
	end
	return "OK"
end

function QuestRules.Start(quests: QuestMap, questId: string, catalog: Catalog?): StartCode
	local code = QuestRules.CanStart(quests, questId, catalog)
	if code == "OK" then
		quests[questId] = { status = "active", progress = 0 }
	end
	return code
end

-- Starts every quest with no prerequisite (q01 on first join). Returns ids started.
function QuestRules.AutoStart(quests: QuestMap, catalog: Catalog?): { string }
	local started = {}
	local cat = catalog or QuestRules.Catalog
	for _, id in QuestRules.Order(cat) do
		if cat[id].prerequisiteQuestId == nil and QuestRules.Start(quests, id, cat) == "OK" then
			table.insert(started, id)
		end
	end
	return started
end

local function matches(def: Quests.QuestDef, objectiveType: string, targetId: string): boolean
	return def.objectiveType == objectiveType and (def.targetId == targetId or def.targetId == "any")
end

-- True if an objective event would move any active quest. Lets the server
-- skip a profile mutation (and a revision bump) for events nobody needs.
function QuestRules.Wants(quests: QuestMap, objectiveType: string, targetId: string, catalog: Catalog?): boolean
	local cat = catalog or QuestRules.Catalog
	for id, record in quests do
		local def = cat[id]
		if def and record.status == "active" and matches(def, objectiveType, targetId) then
			return true
		end
	end
	return false
end

-- True if an active talk quest wants this NPC (a new player's q01): the
-- client shows "!" over them so the first step is easy to find.
function QuestRules.WantsTalk(quests: QuestMap, npcId: string, catalog: Catalog?): boolean
	return QuestRules.Wants(quests, "talk", npcId, catalog)
end

-- Counts `amount` of an objective event. Returns the ids that changed and
-- the ids that became ready.
function QuestRules.Record(quests: QuestMap, objectiveType: string, targetId: string, amount: number, catalog: Catalog?): ({ string }, { string })
	local changed, nowReady = {}, {}
	if amount <= 0 or amount ~= amount then
		return changed, nowReady
	end
	local cat = catalog or QuestRules.Catalog
	for _, id in QuestRules.Order(cat) do
		local record = quests[id]
		local def = cat[id]
		if record and record.status == "active" and matches(def, objectiveType, targetId) then
			record.progress = math.min(def.targetCount, record.progress + math.floor(amount))
			table.insert(changed, id)
			if record.progress >= def.targetCount then
				record.status = "ready"
				table.insert(nowReady, id)
			end
		end
	end
	return changed, nowReady
end

function QuestRules.CanClaim(quests: QuestMap, questId: string, catalog: Catalog?): ClaimCode
	if (catalog or QuestRules.Catalog)[questId] == nil then
		return "UNKNOWN"
	end
	local record = quests[questId]
	if record and record.status == "claimed" then
		return "ALREADY_CLAIMED"
	end
	if not record or record.status ~= "ready" then
		return "QUEST_NOT_READY"
	end
	return "OK"
end

function QuestRules.Claim(quests: QuestMap, questId: string, catalog: Catalog?): ClaimCode
	local code = QuestRules.CanClaim(quests, questId, catalog)
	if code == "OK" then
		quests[questId].status = "claimed"
	end
	return code
end

-- First quest of `giverNpcId`, in story order, whose record has `status`.
function QuestRules.FirstWithStatus(quests: QuestMap, giverNpcId: string, status: QuestStatus, catalog: Catalog?): string?
	local cat = catalog or QuestRules.Catalog
	for _, id in QuestRules.Order(cat) do
		local record = quests[id]
		if cat[id].giverNpcId == giverNpcId and record and record.status == status then
			return id
		end
	end
	return nil
end

-- First quest of `giverNpcId` that could be started now.
function QuestRules.NextToStart(quests: QuestMap, giverNpcId: string, catalog: Catalog?): string?
	local cat = catalog or QuestRules.Catalog
	for _, id in QuestRules.Order(cat) do
		if cat[id].giverNpcId == giverNpcId and QuestRules.CanStart(quests, id, cat) == "OK" then
			return id
		end
	end
	return nil
end

-- What a quest giver has for this player, for dialogue and the marker over
-- their head: "claim" a ready quest, "offer" a new one, "waiting" on an
-- active one, or "none".
export type GiverState = "claim" | "offer" | "waiting" | "none"

function QuestRules.GiverState(quests: QuestMap, giverNpcId: string, catalog: Catalog?): (GiverState, string?)
	local ready = QuestRules.FirstWithStatus(quests, giverNpcId, "ready", catalog)
	if ready then
		return "claim", ready
	end
	local nextId = QuestRules.NextToStart(quests, giverNpcId, catalog)
	if nextId then
		return "offer", nextId
	end
	local active = QuestRules.FirstWithStatus(quests, giverNpcId, "active", catalog)
	if active then
		return "waiting", active
	end
	return "none", nil
end

return QuestRules
