--!strict
-- In-memory ProfileStore (M3-A). Same shape as the DataStore adapter
-- (M3-B): Update(key, transform) runs transform on a copy of the stored value
-- and writes what it returns, nil meaning write nothing. Values are deep
-- copied in and out, like DataStore serialization, so callers never alias
-- stored data. One instance shared by two ProfileStorage objects plays two
-- servers; failNext makes the next calls error, like a DataStore outage.

export type Store = {
	Update: (self: any, key: string, transform: (any) -> any) -> (boolean, string?),
}

local MemoryStore = {}
MemoryStore.__index = MemoryStore

export type MemoryStore = typeof(setmetatable({} :: { data: { [string]: any }, failNext: number }, MemoryStore))

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

function MemoryStore.new(): MemoryStore
	return setmetatable({ data = {}, failNext = 0 }, MemoryStore)
end

function MemoryStore.Update(self: MemoryStore, key: string, transform: (any) -> any): (boolean, string?)
	if self.failNext > 0 then
		self.failNext -= 1
		return false, "injected failure"
	end
	local ran, result = pcall(transform, deepCopy(self.data[key]))
	if not ran then
		return false, tostring(result)
	end
	if result ~= nil then
		self.data[key] = deepCopy(result)
	end
	return true, nil
end

return MemoryStore
