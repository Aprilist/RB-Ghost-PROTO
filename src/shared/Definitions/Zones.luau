--!strict
-- Zone catalog (M2-A). Schema proposed in handoff/M2_PLAN_PROPOSAL.md.
-- p1_arena is the current VB-01 courtyard; per Director (27 Oct 2026) it
-- becomes the abandoned_shrine boss arena in M2-F. M2-B adds the village and
-- Mistwood volumes (layout in Definitions/World).

export type ZoneKind = "hub" | "hunt" | "boss" | "test"

-- Axis-aligned boxes in world space; ZoneService builds one invisible,
-- non-colliding part per box. Draft zones have none until their map exists.
export type Volume = { center: Vector3, size: Vector3 }

export type ZoneDef = {
	id: string,
	displayNameTH: string,
	kind: ZoneKind,
	checkpointId: string?,
	rewardEligible: boolean,
	volumes: { Volume },
	draft: boolean,
}

local Zones: { [string]: ZoneDef } = {
	p1_arena = {
		id = "p1_arena",
		displayNameTH = "ลานทดสอบ",
		kind = "test",
		checkpointId = "p1_checkpoint",
		rewardEligible = true,
		-- The walled 100×100 courtyard (inside the bound walls), floor to wall top.
		volumes = { { center = Vector3.new(0, 16, 0), size = Vector3.new(100, 30, 100) } },
		draft = false,
	},
	last_lantern_village = {
		id = "last_lantern_village",
		displayNameTH = "หมู่บ้านโคมสุดท้าย",
		kind = "hub",
		checkpointId = "village_shrine",
		rewardEligible = false,
		-- World.Village bounds (M2-B).
		volumes = { { center = Vector3.new(0, 31, 600), size = Vector3.new(560, 60, 500) } },
		draft = false,
	},
	mistwood = {
		id = "mistwood",
		displayNameTH = "ป่าม่านหมอก",
		kind = "hunt",
		checkpointId = "mistwood_gate",
		rewardEligible = true,
		-- World.Mistwood: the walled corridor from the courtyard gate, then the forest.
		volumes = {
			{ center = Vector3.new(0, 31, 87), size = Vector3.new(19, 60, 74) },
			{ center = Vector3.new(0, 31, 237), size = Vector3.new(200, 60, 226) },
		},
		draft = false,
	},
	abandoned_shrine = {
		id = "abandoned_shrine",
		displayNameTH = "ศาลเจ้าร้าง",
		kind = "boss",
		checkpointId = "shrine_steps",
		rewardEligible = true,
		volumes = {},
		draft = true,
	},
}

return Zones
