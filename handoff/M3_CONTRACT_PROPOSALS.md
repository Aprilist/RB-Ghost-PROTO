# M3 — ขอ Codex รับเข้า contract (สั้น ตอบรับ/แก้ได้ทีละข้อ)

**รับเข้าแล้ว 28 ต.ค. 2026 (DEC-015: ไม่ใช้ Codex แล้ว):** ข้อ 1, 4, 5 → `docs/CONTRACTS.md` · ข้อ 2 → DEC-006 · ข้อ 3 → `docs/ACCEPTANCE.md` M3 ไฟล์นี้เก็บเป็นประวัติ

Claude 27 ต.ค. 2026 | สถานะเดิม: **ใช้ในโค้ดแล้ว (commit e769a94 + M3-C) ทดสอบบน place ทดสอบแล้ว** ทุกข้อเป็นการเพิ่ม ไม่เปลี่ยน remote/payload ที่ client เห็น · รายละเอียดเต็มใน `handoff/M3_PLAN_PROPOSAL.md` ข้อ 3

| # | ขอรับ | ที่ทำในโค้ด |
|---|---|---|
| 1 | **Envelope ใน DataStore (server เท่านั้น)** | key `u_<UserId>`, store `SpiritWardProfile_dev` · `{ envelopeVersion = 1, profile = ProfileV1, session = { jobId, token, leaseUntil } \| nil, savedAt }` · `envelopeVersion` แยกจาก `ProfileV1.schemaVersion` · lease 300 วิ ต่ออายุทุก autosave 60 วิ |
| 2 | **DEC-006** เปลี่ยนเป็น: memory เฉพาะ Studio ที่ place ยังไม่ publish หรือปิด API access · DataStore ใน place ที่ publish แล้ว · server จริงไม่ถอยไป memory | `ProfileService.Init` |
| 3 | **ACCEPTANCE M3 ข้อ perf** 8 → 12 คน ตาม DEC-007 | — |
| 4 | **checkpointId** = attribute `CheckpointId` ของ SpawnLocation ที่ tag `Checkpoint` (ไม่ใช้ชื่อ model) | `PlayerService` |
| 5 | **ไม่เพิ่ม `profile_status`** (ถอนข้อเสนอเดิม): โหลดไม่ได้ → `ready` ตอบ `NOT_READY` (code เดิม) แล้ว client ขึ้นข้อความค้าง "โหลดข้อมูลตัวละครไม่ได้ ออกแล้วเข้าใหม่อีกครั้ง" · เสีย lease → kick พร้อมข้อความไทย (Director Q3) | `NetworkClient`, `Bootstrap.client` |

ถ้าไม่ตอบ Claude จะถือว่าข้อ 1, 4, 5 ใช้ได้ตามโค้ด ข้อ 2–3 เป็นเอกสารของ Codex Claude ไม่แก้เอง
