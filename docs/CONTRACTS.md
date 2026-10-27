# Shared Contracts v0.2

สถานะ: draft baseline; ไฟล์ types (`src/shared/Types/Contracts.luau`) ต้องตรงกับเอกสารนี้ · M3 persistence รับเข้าแล้ว 28 ต.ค. 2026

## IDs และข้อมูล

stable IDs เป็น lowercase snake_case ไม่ใช้ชื่อภาษาไทยเป็น key:

- class: blade (ซามูไร), shade (นินจา), talisman (องเมียวจิ) — ชื่อที่ผู้เล่นเห็นอยู่ใน `Definitions/Classes.luau`; cast_skill ต้องเป็นสกิล E ของอาชีพปัจจุบัน
- enemy: lantern_wisp, root_shade, bell_moth, shrine_guard
- boss: extinguished_keeper
- zone: last_lantern_village, mistwood, abandoned_shrine
- seal: ember, ward
- item เริ่มต้น: training_blade
- quest: q01_meet_keeper ถึง q05_defeat_keeper

`Definitions/Project.luau` เก็บ defaults ที่มีแล้ว ส่วน catalog ศัตรู/สกิล/เควสต์จะเพิ่มใน CD-01/CD-04 โดยอิงเอกสาร Claude; ยังไม่สร้าง data runtime ซ้ำสองแห่ง

ProfileV1 (persistent, schemaVersion 2): schemaVersion, revision, userId, classId, level, xp, coins, essence, inventory, equippedWeaponId, quests, checkpointId, tutorialCompleted, classChosen, skillPoints, skills

- v2 (M4): `classChosen` false จนกว่าจะเลือกอาชีพครั้งเดียว; `skillPoints` 0–1000 ได้ 2 ต่อเลเวลอัป; `skills` เป็น map skillId → ระดับ 1–20 · migration v1→v2 ตั้ง classChosen = false, skillPoints = (level−1)×2, skills = {} · PublicOwnProfile ส่ง classChosen และ skillPoints

- inventory เป็น map ของ unique itemInstanceId → {definitionId, upgradeLevel, sealId?}; equippedWeaponId อ้าง instance ID
- quests เป็น map ของ questId → {status, progress}; status = active/ready/claimed
- ทุก number ต้อง finite และอยู่ใน range; level 1–20 (Director 28 ต.ค. 2026), coins/essence 0–1,000,000; overflow ไม่ grant แบบเงียบ
- xp เป็น EXP ภายในเลเวลปัจจุบัน ใช้ curve หักทีละขั้นเมื่อเพิ่มเลเวล ที่ cap คง xp = 0
- revision ใช้เพิ่มทุก authoritative mutation ไม่ใช่ schemaVersion
- session metadata/fencing อยู่ใน record envelope ฝั่ง server ไม่ส่ง client
- checkpointId คือ attribute `CheckpointId` ของ SpawnLocation ที่ tag `Checkpoint` ไม่ใช้ชื่อ model เป็น key; id ที่ไม่มีในฉากถูกข้ามตอนเข้าเกม

Profile record (M3, server เท่านั้น): DataStore key `u_<UserId>`, store `SpiritWardProfile_<env>` (place ทดสอบใช้ `dev`)

```
{ envelopeVersion = 1, profile = ProfileV1, session = { jobId, token, leaseUntil } | nil, savedAt }
```

- `envelopeVersion` แยกจาก `ProfileV1.schemaVersion`; record ที่ใหม่กว่าที่ server รู้จักถูกปฏิเสธ ไม่ลดเวอร์ชัน
- lease 300 วินาที ต่ออายุทุก autosave (60 วินาที); token ใหม่ต่อการเข้าเกม; save เขียนเฉพาะเมื่อ token ตรง ไม่ตรง = `lease_lost` → server หยุดให้รางวัลแล้ว kick พร้อมข้อความ
- server อื่นถือ lease ที่ยังไม่หมด → ไม่เขียนอะไร retry แบบจำกัด; สร้าง default เฉพาะ key ที่ไม่มีจริง ไม่ใช่ตอน call error
- ออกเกม/`BindToClose` = save + ล้าง `session`
- โหลดไม่ได้: `profileReady = false`, `ready` ตอบ `NOT_READY` (ไม่มี state event แยก) client แสดงข้อความค้างให้ออกแล้วเข้าใหม่

SessionState (ไม่ save): hp/maxHp, spiritGauge, transformEndsAt, cooldowns, alive, profileReady, encounterId และตำแหน่ง runtime ใช้ server clock สำหรับ endsAt; client แสดงผ่านเวลาที่ sync กับ server

## Transport

ReplicatedStorage/SpiritWardRemotes มี RemoteEvent สามตัวที่ server สร้าง ใช้ attribute OwnedBy=SpiritWard บน folder/events; reuse เฉพาะของโปรเจกต์ ถ้าชื่อชนของที่ไม่ได้เป็นเจ้าของให้หยุดพร้อม error และเก็บของเดิม ห้ามลบ ReplicatedStorage/Remotes ของผู้ใช้:

1. ActionRequest (client → server): `{requestId, action, payload}`
2. ActionResult (server → เจ้าของ): `{requestId, ok, code, revision}`
3. StateEvent (server → client): discriminated payload ตาม kind

requestId เป็น string จำกัด 64 bytes; payload ห้ามส่ง arbitrary nested table; validate เฉพาะ schema ที่ action นั้นอนุญาต cooldown ของ action ไม่แทน network rate limit

| action | payload | เงื่อนไข server | rate limit ตั้งต้น |
|---|---|---|---|
| ready | {} | profileReady; initial snapshot; retry ได้ | 1/sec burst 2 |
| basic_attack | {sequence: integer, aimDirection: Vector3} | alive, range/height/line of sight, cadence; server หา targets | 6/sec burst 6 |
| cast_skill | {skillId, aimDirection: Vector3} | class owns skill, cooldown, state, geometry | 5/sec burst 5 |
| dash | {moveDirection: Vector3} | alive, cooldown, movement state, clear path | 3/sec burst 3 |
| transform | {} | gauge = 100, not active, alive | 1/sec burst 2 |
| apply_seal | {itemInstanceId, sealId} | ownership, shrine distance, essence | 2/sec burst 2 |
| claim_quest | {questId} | ready; never previously claimed | 2/sec burst 2 |
| choose_class | {classId} | class มีอยู่และเปิดแล้ว (`NOT_OWNED` ถ้ายังไม่เปิด), alive, `classChosen` ต้องเป็น false ไม่งั้น `CLASS_LOCKED`; ตั้ง classId + classChosen ผ่าน Mutate ครั้งเดียว ใช้ได้ทุกที่ (M4, Director 28 ต.ค. 2026: เลือกแล้วเปลี่ยนไม่ได้) | 2/sec burst 2 |

ActionResult codes: OK, NOT_READY, INVALID_PAYLOAD, RATE_LIMITED, COOLDOWN, DEAD, OUT_OF_RANGE, NOT_OWNED, INSUFFICIENT_ESSENCE, QUEST_NOT_READY, ALREADY_CLAIMED, ALREADY_SEALED, CAP_REACHED, CLASS_LOCKED, INTERNAL_ERROR

Direction contract: รับเฉพาะ Vector3 ที่ finite ทุกแกน, abs(Y) <= 0.01 และ magnitude อยู่ใน [0.99, 1.01] จากนั้น server project ลง X/Z และ normalize อีกครั้ง ปฏิเสธ zero/NaN/Infinity; ผู้เล่นสามารถหมุนโจมตีได้อิสระใน 3D แต่ server ยังบังคับ cadence, range, height และ line of sight ไม่รับ client origin/target list การช่วยเล็งไม่เพิ่มระยะโจมตี

requestId dedupe cache per player TTL 120 sec; identical retries คืนผลเดิม ถ้า ID เดิมแต่ payload ต่างให้ reject domain state ยังต้องป้องกัน claim/upgrade ซ้ำแม้ cache หมดอายุ Upgrade duplicate intent ใช้ expected weapon state/revision ที่ CD-01 จะตรึงก่อน implementation

StateEvent kinds:

- snapshot: `{kind, revision, profile: PublicOwnProfile, session: PublicOwnSession}` ส่งเฉพาะเจ้าของหลัง ready และหลัง authoritative mutation ใน slice
- combat_fx: `{kind, eventId, actorUserId?, enemyId?, effectId, position}` ส่งภาพเฉพาะผู้ใกล้เหตุการณ์ ไม่แนบ profile
- encounter: `{kind, encounterId, state, endsAt?}` ส่งผู้เข้าร่วม
- class_menu: `{kind, npcId, speakerTH}` ส่งเฉพาะผู้ที่กด prompt ครูฝึก เปิดเมนูเลือกอาชีพ (M4)

snapshot รวมข้อมูลที่ UI ต้องใช้ทั้งหมดใน slice; client ทิ้ง snapshot revision ที่ต่ำกว่าล่าสุด ส่วน session-only changes ใช้ revision เพิ่มด้วยเพื่อรักษาลำดับเดียวกัน ห้ามใช้ revision ของ persisted profile เป็น session fencing token

Client มี local adapter รับ transport เพื่อทำ mock snapshot ได้ แต่ mock ต้องระบุโหมดและห้ามอ้างว่าเชื่อม server สำเร็จ

## Combat, rewards และ death

- Client sequence ใช้ correlate animation ไม่ใช่หลักฐานว่าตีโดน Server คำนวณ 3D hit volume ตามอาวุธ/aimDirection/ตำแหน่งที่ตรวจแล้ว พร้อมความต่างระดับและสิ่งกีดขวาง ไม่ทำ rewind ใน prototype
- Enemy runtime ID ไม่ซ้ำใน lifetime ของ server; reward ledger key = enemyRuntimeId + userId
- ศัตรูทั่วไป: reward ส่วนตัวแก่ผู้ที่ทำ damage อย่างน้อย 1 และยัง alive/อยู่ใน zone ภายในระยะ 120 studs ตอนตาย ไม่สน last hit
- บอส: สมาชิก encounter ที่ยัง alive และทำ damage รวมอย่างน้อย 5% max HP ได้ reward เต็มของตน คนตาย/ออก encounter ไม่มี reward รอบนั้น ยังไม่มี revive
- Enemy death ใช้ transition ครั้งเดียว RewardService ledger ทำเครื่องหมายใน transaction/queue เดียวกับ grant ก่อนปล่อย event ต่อ
- death ผู้เล่นล้าง gauge/transform; เกิด checkpoint 3 วินาที; cooldown ไม่ reset เพื่อใช้หลบข้อจำกัด
- all boss participants dead/left → reset HP/state/adds หลัง 5 วินาที; normal enemies respawn 8 วินาทีหลังตายและไม่ซ้ำ runtime ID
- reward/save ไม่รับประกันข้าม server crash ก่อน persistence; no trading ใน scope นี้

## Definition schema ที่ Claude ออกแบบใน Markdown

Enemy: id, displayNameTH, zoneId, level, maxHp, contact/attackDamage, telegraphSec, recoverSec, attackRangeStuds, detectionRangeStuds, moveSpeedStudsSec, respawnSec, xpReward, coinReward, essenceReward, gaugeReward, behaviorNotes

Skill: id, classId, displayNameTH, cooldownSec, rangeStuds, hitShape, damageMultiplier, windupSec, recoverySec, effectNotes

Quest: id, titleTH, prerequisiteQuestId?, objectiveType, targetId, targetCount, rewardXp, rewardCoins, rewardEssence, dialogueStart, dialogueComplete, repeatable

หากค่าใหม่จำเป็นให้เสนอใน decision log อย่าเปลี่ยน field name เงียบ ๆ
