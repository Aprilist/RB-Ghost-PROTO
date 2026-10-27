--!strict
-- Class change at the trainer NPC (M4). The NPC opens the class menu
-- (StateEvent "class_menu"); the client answers with choose_class. The
-- server re-checks alive, range and that the class is open, then changes
-- profile.classId through Mutate. Free and repeatable for now (try before
-- choosing); E-skill cooldowns are per skill id, so switching cannot skip one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)

type ResultCode = Contracts.ResultCode

type Network = {
	Handle: (string, (Player, { [string]: any }) -> ResultCode) -> (),
	SendState: (Player, any) -> (),
}

type Profiles = {
	Get: (Player) -> ProfileRules.ProfileV1?,
	Mutate: (Player, (ProfileRules.ProfileV1) -> ()) -> boolean,
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
}

type Quests = {
	InRange: (Player, Npcs.NpcDef, number) -> boolean,
}

local ClassService = {}

local network: Network
local profiles: Profiles
local playerState: PlayerState
local quests: Quests

function ClassService.OpenMenu(player: Player)
	local trainer = Npcs[Classes.StationNpcId]
	if not trainer or not playerState.IsAlive(player) then
		return
	end
	network.SendState(player, { kind = "class_menu", npcId = trainer.id, speakerTH = trainer.displayNameTH })
end

local function chooseClass(player: Player, payload: { [string]: any }): ResultCode
	local class = Classes.Get(payload.classId :: string)
	if not class then
		return "INVALID_PAYLOAD"
	end
	if not class.available then
		return "NOT_OWNED"
	end
	local profile = profiles.Get(player)
	if not profile then
		return "NOT_READY"
	end
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	local trainer = Npcs[Classes.StationNpcId]
	if not trainer or not quests.InRange(player, trainer, 2) then
		return "OUT_OF_RANGE"
	end
	if profile.classId == class.id then
		return "OK"
	end
	if not profiles.Mutate(player, function(p)
		p.classId = class.id
	end) then
		return "INTERNAL_ERROR"
	end
	network.SendState(player, { kind = "notice", textTH = "เปลี่ยนเป็น" .. class.displayNameTH .. "แล้ว" })
	return "OK"
end

function ClassService.Init(deps: { Network: Network, Profiles: Profiles, PlayerState: PlayerState, Quests: Quests })
	network = deps.Network
	profiles = deps.Profiles
	playerState = deps.PlayerState
	quests = deps.Quests
end

function ClassService.Start()
	network.Handle("choose_class", chooseClass)
end

return ClassService
