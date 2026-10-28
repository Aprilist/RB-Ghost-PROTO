--!strict
-- M2-A catalog checks: Prototype still exposes the Director-tested P1 numbers
-- now that it reads them from the catalogs, and every catalog entry is
-- complete and points at things that exist.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.CatalogTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = ReplicatedStorage.Shared.Definitions
local EnemyModels = require(script.Parent.Parent.Enemies.Models)
local Classes = require(Definitions.Classes)
local Enemies = require(Definitions.Enemies)
local Items = require(Definitions.Items)
local Progression = require(Definitions.Progression)
local Project = require(Definitions.Project)
local Prototype = require(Definitions.Prototype)
local Quests = require(Definitions.Quests)
local Seals = require(Definitions.Seals)
local Skills = require(Definitions.Skills)
local World = require(Definitions.World)
local Zones = require(Definitions.Zones)

-- P1 values as shipped and playtested; change only with a reviewed balance change.
local P1_VALUES: { { any } } = {
	{ "Player.MaxHp", Prototype.Player.MaxHp, 100 },
	{ "Combat.BasicDamage", Prototype.Combat.BasicDamage, 20 },
	{ "Combat.BasicIntervalSec", Prototype.Combat.BasicIntervalSec, 0.5 },
	{ "Combat.BasicReachStuds", Prototype.Combat.BasicReachStuds, 7 },
	{ "Combat.BasicArcDeg", Prototype.Combat.BasicArcDeg, 100 },
	{ "Skill.Id", Prototype.Skill.Id, "blade_sweep" },
	{ "Skill.Damage", Prototype.Skill.Damage, 30 },
	{ "Skill.CooldownSec", Prototype.Skill.CooldownSec, 5 },
	{ "Skill.ReachStuds", Prototype.Skill.ReachStuds, 7 },
	{ "Skill.ArcDeg", Prototype.Skill.ArcDeg, 160 },
	{ "Enemy.Id", Prototype.Enemy.Id, "lantern_wisp" },
	{ "Enemy.MaxHp", Prototype.Enemy.MaxHp, 60 },
	{ "Enemy.AttackDamage", Prototype.Enemy.AttackDamage, 10 },
	{ "Enemy.TelegraphSec", Prototype.Enemy.TelegraphSec, 0.8 },
	{ "Enemy.RecoverSec", Prototype.Enemy.RecoverSec, 1 },
	{ "Enemy.RespawnSec", Prototype.Enemy.RespawnSec, 8 },
	{ "Enemy.MaxAlive", Prototype.Enemy.MaxAlive, 3 },
	{ "Enemy.AttackRangeStuds", Prototype.Enemy.AttackRangeStuds, 5 },
	{ "Enemy.AttackHitRangeStuds", Prototype.Enemy.AttackHitRangeStuds, 6.5 },
	{ "Enemy.DetectionRangeStuds", Prototype.Enemy.DetectionRangeStuds, 30 },
	{ "Enemy.LeashStuds", Prototype.Enemy.LeashStuds, 25 },
	{ "Enemy.MoveSpeedStudsSec", Prototype.Enemy.MoveSpeedStudsSec, 8 },
	{ "Enemy.HoverHeightStuds", Prototype.Enemy.HoverHeightStuds, 3 },
	{ "Enemy.BodyRadiusStuds", Prototype.Enemy.BodyRadiusStuds, 1.5 },
	{ "Enemy.AiTickSec", Prototype.Enemy.AiTickSec, 0.1 },
	{ "Spirit.GaugePerDefeat", Prototype.Spirit.GaugePerDefeat, 10 },
	{ "Spirit.EssencePerDefeat", Prototype.Spirit.EssencePerDefeat, 5 },
	{ "Spirit.TransformAttackDamage", Prototype.Spirit.TransformAttackDamage, 25 },
	{ "Spirit.TransformAttackReachStuds", Prototype.Spirit.TransformAttackReachStuds, 10 },
	{ "Spirit.TransformAttackArcDeg", Prototype.Spirit.TransformAttackArcDeg, 90 },
	{ "Spirit.GaugeMax", Prototype.Spirit.GaugeMax, Project.SpiritGaugeMax },
}

local function positive(n: any): boolean
	return type(n) == "number" and n == n and n > 0 and n < math.huge
end

local function nonNegative(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end

local function snake(id: string): boolean
	return string.match(id, "^[a-z][a-z0-9_]*$") ~= nil
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "Prototype keeps every P1 value",
		run = function()
			for _, row in P1_VALUES do
				if row[2] ~= row[3] then
					return false, string.format("%s = %s, expected %s", row[1], tostring(row[2]), tostring(row[3]))
				end
			end
			return true, string.format("%d values", #P1_VALUES)
		end,
	},
	{
		name = "every catalog ID is snake_case and matches its key",
		run = function()
			local catalogs: { [string]: { [string]: any } } = {
				Enemies = Enemies,
				Items = Items,
				Quests = Quests,
				Seals = Seals,
				Skills = Skills,
				Zones = Zones,
			}
			local count = 0
			for catalog, entries in catalogs do
				for key, entry in entries do
					count += 1
					if not snake(key) or entry.id ~= key then
						return false, catalog .. "." .. key
					end
				end
			end
			return true, string.format("%d entries", count)
		end,
	},
	{
		name = "enemies are complete and live in known zones",
		run = function()
			for id, e in Enemies do
				if e.id ~= id or Zones[e.zoneId] == nil then
					return false, id .. " id/zone"
				end
				for _, n in { e.maxHp, e.attackDamage, e.telegraphSec, e.recoverSec, e.attackRangeStuds, e.detectionRangeStuds, e.moveSpeedStudsSec, e.respawnSec, e.tuning.attackHitRangeStuds, e.tuning.leashStuds, e.tuning.bodyRadiusStuds, e.tuning.maxAlive, e.tuning.aiTickSec } do
					if not positive(n) then
						return false, id .. " has a non-positive tuning value"
					end
				end
				for _, n in { e.xpReward, e.coinReward, e.essenceReward, e.gaugeReward, e.tuning.hoverHeightStuds } do
					if not nonNegative(n) then
						return false, id .. " has a negative reward"
					end
				end
				-- The hit check must reach at least as far as the telegraph start.
				if e.tuning.attackHitRangeStuds < e.attackRangeStuds then
					return false, id .. " hit range shorter than attack range"
				end
			end
			return true, nil
		end,
	},
	{
		name = "enemy attack shapes and spawn groups are usable (M2-C)",
		run = function()
			local shapes = { burst = true, charge = true, leap = true, lunge = true }
			for id, e in Enemies do
				local t = e.tuning
				if not shapes[t.attackShape] then
					return false, id .. " shape " .. tostring(t.attackShape)
				end
				if t.attackShape ~= "burst" and not positive(t.attackWidthStuds) then
					return false, id .. " needs attackWidthStuds"
				end
				if t.groupSize < 1 or t.groupSize % 1 ~= 0 or t.groupSize > t.maxAlive or t.maxAlive % 1 ~= 0 then
					return false, id .. " groupSize/maxAlive"
				end
				-- One AI loop runs every live type at the P1 tick.
				if not e.draft and t.aiTickSec ~= Prototype.Enemy.AiTickSec then
					return false, id .. " aiTickSec"
				end
				if not e.draft and not EnemyModels.Has(id) then
					return false, id .. " has no model"
				end
			end
			return true, nil
		end,
	},
	{
		name = "Mistwood spawns name live Mistwood enemies, leash inside the zone",
		run = function()
			local count = 0
			for i, s in World.Mistwood.enemySpawns do
				local e = Enemies[s.enemy]
				if not e or e.draft or e.zoneId ~= "mistwood" then
					return false, "spawn " .. i .. " " .. tostring(s.enemy)
				end
				-- The whole leash circle (plus the group spread) must be inside a
				-- Mistwood volume box, so every kill there can pay out.
				local reach = e.tuning.leashStuds + 3
				local inside = false
				for _, v in Zones.mistwood.volumes do
					local half = v.size / 2
					if
						s.x - reach >= v.center.X - half.X
						and s.x + reach <= v.center.X + half.X
						and s.z - reach >= v.center.Z - half.Z
						and s.z + reach <= v.center.Z + half.Z
					then
						inside = true
					end
				end
				if not inside then
					return false, "spawn " .. i .. " leash leaves the zone"
				end
				count += 1
			end
			return count > 0, string.format("%d spawns", count)
		end,
	},
	{
		name = "skills and items are complete",
		run = function()
			for id, s in Skills do
				if s.id ~= id or Classes.Get(s.classId) == nil then
					return false, id
				end
				local passive = s.hitShape == "passive"
				local damaging = s.hitShape ~= "buff" and s.hitShape ~= "heal" and not passive
				local shapeOk = if passive
					then s.passiveStat ~= nil and positive(s.passivePerRank or 0)
					elseif s.hitShape == "line"
					then positive(s.widthStuds or 0) and positive(s.rangeStuds)
					elseif s.hitShape == "circle" then positive(s.radiusStuds or 0) and s.rangeStuds >= 0
					elseif s.hitShape == "buff" then (s.buffMult or 0) > 1 and positive(s.buffSec or 0)
					elseif s.hitShape == "heal" then (s.healFraction or 0) > 0 and (s.healFraction or 0) <= 1
					else s.arcDeg > 0 and s.arcDeg <= 360 and positive(s.rangeStuds)
				local rankOk = s.unlockLevel >= 1 and s.maxRank >= 1 and s.spCost >= 0
				if not ((passive or positive(s.cooldownSec)) and (not damaging or positive(s.damageMultiplier))) or not shapeOk or not rankOk then
					return false, id .. " values"
				end
			end
			for id, item in Items do
				if item.id ~= id or not positive(item.baseDamage) then
					return false, id
				end
			end
			return Items[Progression.StartingWeaponId] ~= nil, "starting weapon " .. Progression.StartingWeaponId
		end,
	},
	{
		name = "level curve fits the cap",
		run = function()
			local cap = Progression.LevelCap
			if cap < 1 or cap > Project.AlphaLevelCap then
				return false, "LevelCap " .. cap
			end
			if #Progression.XpToNext ~= cap - 1 or #Progression.MaxHpByLevel ~= cap then
				return false, "curve length"
			end
			for i, xp in Progression.XpToNext do
				if not positive(xp) or (i > 1 and xp <= Progression.XpToNext[i - 1]) then
					return false, "XpToNext[" .. i .. "]"
				end
			end
			for i, hp in Progression.MaxHpByLevel do
				if not positive(hp) or (i > 1 and hp < Progression.MaxHpByLevel[i - 1]) then
					return false, "MaxHpByLevel[" .. i .. "]"
				end
			end
			return true, string.format("cap %d", cap)
		end,
	},
	{
		name = "zones: live zones have volumes and checkpoints",
		run = function()
			for id, z in Zones do
				if z.id ~= id then
					return false, id
				end
				if not z.draft and (#z.volumes == 0 or z.checkpointId == nil) then
					return false, id .. " has no volume/checkpoint"
				end
				for _, v in z.volumes do
					if v.size.X <= 0 or v.size.Y <= 0 or v.size.Z <= 0 then
						return false, id .. " volume size"
					end
				end
			end
			return true, nil
		end,
	},
	{
		name = "quests and seals point at real things",
		run = function()
			for id, q in Quests do
				if q.id ~= id or not positive(q.targetCount) then
					return false, id
				end
				if q.prerequisiteQuestId and Quests[q.prerequisiteQuestId] == nil then
					return false, id .. " prerequisite"
				end
				if q.objectiveType == "defeat" and Enemies[q.targetId] == nil then
					return false, id .. " target " .. q.targetId
				end
			end
			for id, seal in Seals do
				if seal.id ~= id or not positive(seal.essenceCost) then
					return false, id
				end
			end
			return true, nil
		end,
	},
}

local CatalogTest = {}

function CatalogTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[CatalogTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[CatalogTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[CatalogTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return CatalogTest
