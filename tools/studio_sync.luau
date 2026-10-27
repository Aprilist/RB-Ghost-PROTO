-- Pull src/ into the open place (Edit mode, Studio command bar or MCP).
-- Needs tools/studio_sync_server.py running. Turns HttpEnabled on only for
-- the pull and restores it after (Director 28 Oct 2026). Creates missing
-- scripts/folders, rewrites Source only where it differs, never deletes.
-- Returns a summary line.

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34873"

local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, result = pcall(function()
	local manifest = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "/manifest", true))
	local changed, created, same = {}, {}, 0
	for _, entry in manifest do
		local parent: Instance = game:GetService(entry.path[1])
		for i = 2, #entry.path - 1 do
			local child = parent:FindFirstChild(entry.path[i])
			if not child then
				child = Instance.new("Folder")
				child.Name = entry.path[i]
				child.Parent = parent
			end
			parent = child
		end
		local name = entry.path[#entry.path]
		-- Two scripts with one name: require() may pick either, so stop and say so.
		local count = 0
		for _, child in parent:GetChildren() do
			if child.Name == name then
				count += 1
			end
		end
		if count > 1 then
			error(entry.file .. ": " .. count .. " instances named " .. name .. " in Studio; remove the stale one")
		end
		local target: any = parent:FindFirstChild(name)
		if target and target.ClassName ~= entry.class then
			error(entry.file .. " is a " .. target.ClassName .. " in Studio, expected " .. entry.class)
		end
		local source = HttpService:GetAsync(BASE .. "/file/" .. entry.file, true)
		if not target then
			target = Instance.new(entry.class)
			target.Name = name
			target.Source = source
			target.Parent = parent
			table.insert(created, entry.file)
		elseif target.Source ~= source then
			target.Source = source
			table.insert(changed, entry.file)
		else
			same += 1
		end
	end
	return string.format("synced: %d changed, %d created, %d unchanged\nchanged: %s\ncreated: %s", #changed, #created, same, table.concat(changed, ", "), table.concat(created, ", "))
end)
HttpService.HttpEnabled = wasEnabled
return if ok then result else "sync failed: " .. tostring(result)
