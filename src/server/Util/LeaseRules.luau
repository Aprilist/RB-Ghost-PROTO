--!strict
-- Session lease and fencing for the stored profile envelope (M3-A, pure).
-- Each function is an UpdateAsync transform: given the stored value it
-- returns the value to write, or nil to write nothing, plus an outcome.
-- No side effects and no yields, so they are safe inside UpdateAsync and
-- testable without a DataStore. The envelope is server-only (CONTRACTS:
-- session metadata/fencing never goes to the client).

local LeaseRules = {}

LeaseRules.EnvelopeVersion = 1
LeaseRules.LeaseSec = 300 -- renewed by every save; autosave runs well inside it

export type Session = { jobId: string, token: string, leaseUntil: number }
export type Envelope = {
	envelopeVersion: number,
	profile: any,
	session: Session?,
	savedAt: number,
}

export type AcquireOutcome = "created" | "acquired" | "held" | "too_new" | "bad_record" | "bad_profile"
export type SaveOutcome = "saved" | "lease_lost"

-- Takes the lease for this server. A missing key (stored == nil) is the
-- only case that creates a default profile; a broken or unknown record is
-- never overwritten. `migrate` returns the usable profile or nil.
function LeaseRules.Acquire(
	stored: any,
	jobId: string,
	token: string,
	now: number,
	newProfile: () -> any,
	migrate: (any) -> (any?, string?)
): (Envelope?, AcquireOutcome, string?)
	local session = { jobId = jobId, token = token, leaseUntil = now + LeaseRules.LeaseSec }
	if stored == nil then
		return { envelopeVersion = LeaseRules.EnvelopeVersion, profile = newProfile(), session = session, savedAt = now },
			"created"
	end
	if type(stored) ~= "table" or type(stored.envelopeVersion) ~= "number" or type(stored.profile) ~= "table" then
		return nil, "bad_record"
	end
	if stored.envelopeVersion > LeaseRules.EnvelopeVersion then
		return nil, "too_new"
	end
	local held = stored.session
	if type(held) == "table" and type(held.leaseUntil) == "number" and held.leaseUntil > now and held.jobId ~= jobId then
		return nil, "held"
	end
	local profile, err = migrate(stored.profile)
	if profile == nil then
		return nil, if err == "too_new" then "too_new" else "bad_profile", err
	end
	return { envelopeVersion = LeaseRules.EnvelopeVersion, profile = profile, session = session, savedAt = stored.savedAt },
		"acquired"
end

-- Writes `profile` only while this server still holds the lease (fencing by
-- token, not by revision). release = true clears the session on leave.
function LeaseRules.Save(stored: any, token: string, profile: any, now: number, release: boolean): (Envelope?, SaveOutcome)
	local held = type(stored) == "table" and stored.session
	if type(held) ~= "table" or held.token ~= token then
		return nil, "lease_lost"
	end
	return {
		envelopeVersion = LeaseRules.EnvelopeVersion,
		profile = profile,
		session = if release then nil else { jobId = held.jobId, token = token, leaseUntil = now + LeaseRules.LeaseSec },
		savedAt = now,
	},
		"saved"
end

return LeaseRules
