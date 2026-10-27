--!strict
-- DataStore ProfileStore (M3-B). Same Update(key, transform) shape as
-- MemoryStore, backed by UpdateAsync. The transform must not yield or have
-- side effects (UpdateAsync may run it more than once). Waits briefly for
-- request budget so a burst queues instead of throttling into errors.

local DataStoreService = game:GetService("DataStoreService")

local DataStoreStore = {}
DataStoreStore.__index = DataStoreStore

local BUDGET_WAIT_SEC = 10

export type DataStoreStore = typeof(setmetatable({} :: { store: DataStore }, DataStoreStore))

-- Errors (no API access, unpublished place) are returned, not thrown.
function DataStoreStore.new(name: string): (DataStoreStore?, string?)
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, name)
	if not ok then
		return nil, tostring(store)
	end
	return setmetatable({ store = store }, DataStoreStore), nil
end

-- One cheap read to find out at start whether this server may use DataStores.
function DataStoreStore.Probe(self: DataStoreStore): (boolean, string?)
	local ok, err = pcall(self.store.GetAsync, self.store, "probe")
	return ok, if ok then nil else tostring(err)
end

function DataStoreStore.Update(self: DataStoreStore, key: string, transform: (any) -> any): (boolean, string?)
	local waited = 0
	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1 and waited < BUDGET_WAIT_SEC do
		waited += task.wait(0.5)
	end
	local ok, err = pcall(self.store.UpdateAsync, self.store, key, function(stored)
		return transform(stored)
	end)
	return ok, if ok then nil else tostring(err)
end

return DataStoreStore
