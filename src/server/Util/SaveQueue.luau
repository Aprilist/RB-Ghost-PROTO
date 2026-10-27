--!strict
-- One save in flight per key (M3-A). A request while a save runs only marks
-- the key dirty, so any burst of changes becomes one more save of the latest
-- profile, in order. `run` reads the current profile itself and returns
-- "saved", "lease_lost" or "error"; errors retry after each delay, then give
-- up until the next request. Once release is asked for it sticks until the
-- worker finishes.

local SaveQueue = {}
SaveQueue.__index = SaveQueue

type Run = (key: any, release: boolean) -> string

export type SaveQueue = typeof(setmetatable(
	{} :: {
		run: Run,
		delays: { number },
		wait: (number) -> (),
		busy: { [any]: boolean },
		dirty: { [any]: boolean },
		release: { [any]: boolean },
	},
	SaveQueue
))

function SaveQueue.new(run: Run, delays: { number }, wait: ((number) -> ())?): SaveQueue
	return setmetatable({
		run = run,
		delays = delays,
		wait = wait or function(sec: number)
			task.wait(sec)
		end,
		busy = {},
		dirty = {},
		release = {},
	}, SaveQueue)
end

function SaveQueue.Request(self: SaveQueue, key: any, release: boolean?)
	if release then
		self.release[key] = true
	end
	if self.busy[key] then
		self.dirty[key] = true
		return
	end
	self.busy[key] = true
	task.spawn(function()
		repeat
			self.dirty[key] = nil
			local rel = self.release[key] == true
			local ran, outcome = pcall(self.run, key, rel)
			local attempt = 0
			while (not ran or outcome == "error") and attempt < #self.delays do
				attempt += 1
				self.wait(self.delays[attempt])
				ran, outcome = pcall(self.run, key, rel)
			end
			if not ran or outcome ~= "saved" then
				-- lease lost or out of retries: stop; the next request starts over
				self.dirty[key] = nil
			end
		until not self.dirty[key]
		self.busy[key] = nil
		self.release[key] = nil
	end)
end

function SaveQueue.Busy(self: SaveQueue, key: any): boolean
	return self.busy[key] == true
end

return SaveQueue
