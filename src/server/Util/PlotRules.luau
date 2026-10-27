--!strict
-- Pure house-plot assignment (M2-B). Plots are numbered 1..count; a joining
-- player takes the lowest free plot and keeps it until they leave. A player
-- never holds two plots; with every plot taken the player gets none.

export type Plots = { [number]: number? } -- plot index → owner userId

local PlotRules = {}

function PlotRules.Find(plots: Plots, userId: number, count: number): number?
	for i = 1, count do
		if plots[i] == userId then
			return i
		end
	end
	return nil
end

function PlotRules.Assign(plots: Plots, userId: number, count: number): number?
	local existing = PlotRules.Find(plots, userId, count)
	if existing then
		return existing
	end
	for i = 1, count do
		if plots[i] == nil then
			plots[i] = userId
			return i
		end
	end
	return nil
end

function PlotRules.Release(plots: Plots, userId: number, count: number): number?
	local i = PlotRules.Find(plots, userId, count)
	if i then
		plots[i] = nil
	end
	return i
end

return PlotRules
