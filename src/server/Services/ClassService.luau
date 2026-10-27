--!strict
-- Class pick (M4). Director 28 Oct 2026: the class is picked once, on first
-- join, and cannot be changed back (ClassRules). The client opens the class
-- menu by itself while the snapshot says classChosen = false; the trainer
-- NPC opens the same menu (StateEvent "class_menu") to show the classes.
-- choose_class works anywhere while the class is not yet chosen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)
local ClassRules = require(script.Parent.Parent.Util.ClassRules)
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

local ClassService = {}

local network: Network
local profiles: Profiles
local playerState: PlayerState

function ClassService.OpenMenu(player: Player)
	local trainer = Npcs[Classes.StationNpcId]
	if not trainer or not playerState.IsAlive(player) then
		return
	end
	network.SendState(player, { kind = "class_menu", npcId = trainer.id, speakerTH = trainer.displayNameTH })
end

local function chooseClass(player: Player, payload: { [string]: any }): ResultCode
	local classId = payload.classId :: string
	local profile = profiles.Get(player)
	if not profile then
		return "NOT_READY"
	end
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	-- Dry run first so a refused pick never bumps the profile revision.
	local dry = ClassRules.Choose(ProfileRules.Clone(profile), classId)
	if dry ~= "OK" then
		return dry :: ResultCode
	end
	local code: ClassRules.ChooseCode = "INVALID_PAYLOAD"
	if not profiles.Mutate(player, function(p)
		code = ClassRules.Choose(p, classId)
	end) then
		return "INTERNAL_ERROR"
	end
	if code == "OK" then
		local class = Classes.Get(classId) :: Classes.ClassDef
		network.SendState(player, { kind = "notice", textTH = "คุณเป็น" .. class.displayNameTH .. "แล้ว" })
	end
	return code :: ResultCode
end

function ClassService.Init(deps: { Network: Network, Profiles: Profiles, PlayerState: PlayerState })
	network = deps.Network
	profiles = deps.Profiles
	playerState = deps.PlayerState
end

function ClassService.Start()
	network.Handle("choose_class", chooseClass)
end

return ClassService
