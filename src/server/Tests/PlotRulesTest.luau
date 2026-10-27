--!strict
-- PlotRules tests (pure): lowest free plot, one plot per player, release.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.PlotRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local PlotRules = require(script.Parent.Parent.Util.PlotRules)

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "players take the lowest free plot in join order",
		run = function()
			local plots = {}
			local a = PlotRules.Assign(plots, 11, 8)
			local b = PlotRules.Assign(plots, 22, 8)
			return a == 1 and b == 2, nil
		end,
	},
	{
		name = "a player never holds two plots",
		run = function()
			local plots = {}
			PlotRules.Assign(plots, 11, 8)
			local again = PlotRules.Assign(plots, 11, 8)
			return again == 1 and plots[2] == nil, nil
		end,
	},
	{
		name = "leaving frees the plot for the next player",
		run = function()
			local plots = {}
			PlotRules.Assign(plots, 11, 8)
			PlotRules.Assign(plots, 22, 8)
			local freed = PlotRules.Release(plots, 11, 8)
			local c = PlotRules.Assign(plots, 33, 8)
			return freed == 1 and c == 1 and PlotRules.Find(plots, 22, 8) == 2, nil
		end,
	},
	{
		name = "full server gives no plot; unknown release is a no-op",
		run = function()
			local plots = {}
			for i = 1, 8 do
				PlotRules.Assign(plots, 100 + i, 8)
			end
			local extra = PlotRules.Assign(plots, 999, 8)
			local none = PlotRules.Release(plots, 555, 8)
			return extra == nil and none == nil, nil
		end,
	},
}

local PlotRulesTest = {}

function PlotRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[PlotRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[PlotRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[PlotRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return PlotRulesTest
