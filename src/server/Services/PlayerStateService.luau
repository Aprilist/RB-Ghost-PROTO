--!strict
-- In-memory session state per player. Owns HP, alive, cooldowns, gauge
-- fields and the snapshot revision; level/EXP/coins/essence live in the
-- profile (ProfileService) and are copied into each snapshot. Max HP follows
-- the profile level. The Humanoid mirrors this HP; it is not the source of truth.
-- M4: SP (stored as value + time, regenerates lazily, SkillRules) and one
-- damage buff from buff skills.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)
local SealRules = require(script.Parent.Parent.Util.SealRules)
local SkillRules = require(ReplicatedStorage.Shared.Util.SkillRules)

export type State = {
	hp: number,
	maxHp: number,
	alive: boolean,
	spiritGauge: number,
	transformEndsAt: number?,
	cooldowns: { [string]: number },
	profileReady: boolean,
	revision: number,
	shieldHp: number, -- M2-E ward shield; session only
	shieldEndsAt: number?,
	sp: number, -- M4: SP when spAt was set; regenerates from there
	spAt: number,
	maxSp: number,
	buffMult: number, -- M4 buff skills: damage multiplier until buffEndsAt
	buffEndsAt: number?,
}

type Network = {
	SendState: (Player, Contracts.StateEvent) -> (),
	SetRevisionSource: ((Player) -> number) -> (),
	Handle: (string, (Player, { [string]: any }) -> Contracts.ResultCode) -> (),
}

type Profiles = {
	Load: (Player) -> ProfileRules.ProfileV1?,
	Get: (Player) -> ProfileRules.ProfileV1?,
	OnChanged: ((Player, ProfileRules.ProfileV1) -> ()) -> (),
}

local PlayerStateService = {}

local network: Network
local profiles: Profiles
local states: { [Player]: State } = {}
local sessionRevision = 0
local diedListeners: { (Player) -> () } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function PlayerStateService.Get(player: Player): State?
	return states[player]
end

function PlayerStateService.GetRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerStateService.IsAlive(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.alive and PlayerStateService.GetRoot(player) ~= nil
end

function PlayerStateService.CooldownReady(player: Player, key: string): boolean
	local state = states[player]
	local endsAt = state and state.cooldowns[key]
	return endsAt == nil or now() >= endsAt
end

function PlayerStateService.StartCooldown(player: Player, key: string, seconds: number)
	local state = states[player]
	if state then
		state.cooldowns[key] = now() + seconds
	end
end

function PlayerStateService.IsTransformed(player: Player): boolean
	local state = states[player]
	local endsAt = state and state.transformEndsAt
	return endsAt ~= nil and now() < endsAt
end

function PlayerStateService.Revision(player: Player): number
	local state = states[player]
	return state and state.revision or 0
end

-- Bump the server-session revision and push the owner's snapshot.
function PlayerStateService.Commit(player: Player)
	local state = states[player]
	local profile = profiles.Get(player)
	if not state or not profile then
		return
	end
	sessionRevision += 1
	state.revision = sessionRevision
	local cooldowns = table.clone(state.cooldowns)
	local quests = {}
	for id, record in profile.quests do
		quests[id] = { status = record.status, progress = record.progress }
	end
	network.SendState(player, {
		kind = "snapshot",
		revision = state.revision,
		profile = {
			classId = profile.classId,
			classChosen = profile.classChosen,
			skillPoints = profile.skillPoints,
			skills = table.clone(profile.skills),
			level = profile.level,
			xp = profile.xp,
			xpToNext = ProfileRules.XpToNext(profile.level),
			coins = profile.coins,
			essence = profile.essence,
			quests = quests,
			equippedWeaponId = profile.equippedWeaponId,
			equippedSealId = SealRules.EquippedSealId(profile),
		},
		session = {
			hp = state.hp,
			maxHp = state.maxHp,
			alive = state.alive,
			spiritGauge = state.spiritGauge,
			transformEndsAt = state.transformEndsAt,
			cooldowns = cooldowns,
			profileReady = state.profileReady,
			shieldHp = SealRules.ShieldNow(state.shieldHp, state.shieldEndsAt, now()),
			shieldEndsAt = state.shieldEndsAt,
			sp = state.sp,
			spAt = state.spAt,
			maxSp = state.maxSp,
			buffEndsAt = if state.buffEndsAt and now() < state.buffEndsAt then state.buffEndsAt else nil,
		},
	})
end

-- M4 SP: current value with regeneration.
function PlayerStateService.SpNow(player: Player): number
	local state = states[player]
	return if state then SkillRules.SpAt(state.sp, state.spAt, state.maxSp, now()) else 0
end

-- Takes `cost` SP if there is enough; false (and nothing taken) otherwise.
function PlayerStateService.SpendSp(player: Player, cost: number): boolean
	local state = states[player]
	if not state then
		return false
	end
	local sp = SkillRules.SpAt(state.sp, state.spAt, state.maxSp, now())
	if sp < cost then
		return false
	end
	state.sp = sp - cost
	state.spAt = now()
	return true
end

-- Heals up to max HP (M4 heal skill).
function PlayerStateService.Heal(player: Player, amount: number)
	local state = states[player]
	if not state or not state.alive or amount <= 0 then
		return
	end
	state.hp = math.min(state.maxHp, state.hp + amount)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = state.hp
	end
	PlayerStateService.Commit(player)
end

-- One damage buff at a time; a new one replaces the old (M4 buff skills).
function PlayerStateService.GrantDamageBuff(player: Player, mult: number, seconds: number)
	local state = states[player]
	if not state or not state.alive or mult <= 1 or seconds <= 0 then
		return
	end
	state.buffMult = mult
	state.buffEndsAt = now() + seconds
	PlayerStateService.Commit(player)
end

function PlayerStateService.DamageMult(player: Player): number
	local state = states[player]
	if state and state.buffEndsAt and now() < state.buffEndsAt then
		return state.buffMult
	end
	return 1
end

-- Ward seal: sets the shield pool (replaces any current one) for `seconds`.
function PlayerStateService.GrantShield(player: Player, hp: number, seconds: number)
	local state = states[player]
	if not state or not state.alive or hp <= 0 or seconds <= 0 then
		return
	end
	state.shieldHp = hp
	state.shieldEndsAt = now() + seconds
	PlayerStateService.Commit(player)
end

function PlayerStateService.Damage(player: Player, amount: number)
	local state = states[player]
	if not state or not state.alive or amount <= 0 then
		return
	end
	-- The shield eats damage first; only what gets through reduces HP.
	state.shieldHp, state.shieldEndsAt, amount = SealRules.Absorb(state.shieldHp, state.shieldEndsAt, now(), amount)
	if amount <= 0 then
		PlayerStateService.Commit(player)
		return
	end
	state.hp = math.max(0, state.hp - amount)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = state.hp -- reaching 0 fires Died, handled below
	end
	PlayerStateService.Commit(player)
end

function PlayerStateService.OnDied(callback: (Player) -> ())
	table.insert(diedListeners, callback)
end

local function onDied(player: Player)
	local state = states[player]
	if not state or not state.alive then
		return
	end
	state.alive = false
	state.hp = 0
	-- Death clears gauge and transform; cooldowns are kept (contract).
	state.spiritGauge = 0
	state.transformEndsAt = nil
	state.shieldHp = 0
	state.shieldEndsAt = nil
	state.buffEndsAt = nil
	PlayerStateService.Commit(player)
	for _, callback in diedListeners do
		task.spawn(callback, player)
	end
end

local function onCharacter(player: Player, character: Model)
	local state = states[player]
	if not state then
		return
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- Default regen would drift from server HP.
	local function dropRegen(child: Instance)
		if child.Name == "Health" and child:IsA("Script") then
			child:Destroy()
		end
	end
	for _, child in character:GetChildren() do
		dropRegen(child)
	end
	character.ChildAdded:Connect(dropRegen)
	humanoid.MaxHealth = state.maxHp
	humanoid.Health = state.maxHp
	state.hp = state.maxHp
	state.alive = true
	state.shieldHp = 0
	state.shieldEndsAt = nil
	state.sp = state.maxSp
	state.spAt = now()
	humanoid.Died:Connect(function()
		onDied(player)
	end)
	PlayerStateService.Commit(player)
end

-- Max HP and SP from level plus learned passives (M4-E).
local function maxStats(profile: ProfileRules.ProfileV1?): (number, number)
	if not profile then
		return ProfileRules.MaxHp(1), SkillRules.MaxSp(1)
	end
	local hp = math.floor(ProfileRules.MaxHp(profile.level) * (1 + SkillRules.Bonus(profile, "maxHpPct")) + 0.5)
	return hp, SkillRules.MaxSp(profile.level) + SkillRules.Bonus(profile, "maxSpFlat")
end

-- A level-up raises max HP and heals by the same amount, so the bar never
-- looks emptier after levelling. Every profile change pushes a snapshot.
local function onProfileChanged(player: Player, profile: ProfileRules.ProfileV1)
	local state = states[player]
	if not state then
		return
	end
	local maxHp, maxSp = maxStats(profile)
	if maxHp ~= state.maxHp then
		if state.alive then
			state.hp = math.clamp(state.hp + maxHp - state.maxHp, 1, maxHp)
		end
		state.maxHp = maxHp
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and state.alive then
			humanoid.MaxHealth = maxHp
			humanoid.Health = state.hp
		end
	end
	if maxSp ~= state.maxSp then
		state.sp = math.min(maxSp, SkillRules.SpAt(state.sp, state.spAt, state.maxSp, now()) + maxSp - state.maxSp)
		state.spAt = now()
		state.maxSp = maxSp
	end
	PlayerStateService.Commit(player)
end

local function onPlayer(player: Player)
	local profile = profiles.Load(player)
	-- No profile (load failed): stay not-ready so `ready` answers NOT_READY.
	local maxHp, maxSp = maxStats(profile)
	states[player] = {
		hp = maxHp,
		maxHp = maxHp,
		alive = false,
		spiritGauge = 0,
		transformEndsAt = nil,
		cooldowns = {},
		profileReady = profile ~= nil,
		revision = 0,
		shieldHp = 0,
		shieldEndsAt = nil,
		sp = maxSp,
		spAt = now(),
		maxSp = maxSp,
		buffMult = 1,
		buffEndsAt = nil,
	}
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function PlayerStateService.Init(deps: { Network: Network, Profiles: Profiles })
	network = deps.Network
	profiles = deps.Profiles
	network.SetRevisionSource(PlayerStateService.Revision)
	profiles.OnChanged(onProfileChanged)
end

function PlayerStateService.Start()
	-- ready: client asks for its initial snapshot (retry-safe).
	network.Handle("ready", function(player)
		local state = states[player]
		if not state or not state.profileReady then
			return "NOT_READY"
		end
		task.defer(PlayerStateService.Commit, player)
		return "OK"
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return PlayerStateService
