--!strict
-- One list of things player attacks can hit (M2-F): the normal enemies plus
-- the boss while a fight is on. CombatService strikes and SealService burns
-- go through this so neither needs to know which kind of target they hit;
-- damage is routed to the service that owns that runtime id.

type Record = { id: string, body: BasePart, bodyRadius: number }

type Enemies = {
	GetAlive: () -> { Record },
	Damage: (string, number, Player) -> boolean,
	Root: (string, number) -> (),
}

type Boss = {
	Owns: (string) -> boolean,
	GetTargets: () -> { Record },
	Damage: (string, number, Player) -> boolean,
}

local TargetService = {}

local enemies: Enemies
local boss: Boss

function TargetService.GetAlive(): { Record }
	local list: { Record } = {}
	for _, enemy in enemies.GetAlive() do
		table.insert(list, { id = enemy.id, body = enemy.body, bodyRadius = enemy.bodyRadius })
	end
	for _, target in boss.GetTargets() do
		table.insert(list, target)
	end
	return list
end

function TargetService.Damage(id: string, amount: number, attacker: Player): boolean
	if boss.Owns(id) then
		return boss.Damage(id, amount, attacker)
	end
	return enemies.Damage(id, amount, attacker)
end

-- Holds a normal enemy in place (onmyoji seal, M4-E). Bosses are immune.
function TargetService.Root(id: string, seconds: number)
	if not boss.Owns(id) then
		enemies.Root(id, seconds)
	end
end

function TargetService.Init(deps: { Enemies: Enemies, Boss: Boss })
	enemies = deps.Enemies
	boss = deps.Boss
end

return TargetService
