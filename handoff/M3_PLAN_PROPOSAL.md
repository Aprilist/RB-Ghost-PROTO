# M3 Persistence/Hardening — ข้อเสนอแผนและใบงาน

ร่างโดย Claude 27 ต.ค. 2026 | สถานะ: **ข้อเสนอ รอ Director ตอบคำถามข้อ 2 และ Codex รับ contract ข้อ 5** | อ้างอิง TECHNICAL_ARCHITECTURE "Data และ persistence", CONTRACTS (ProfileV1/SessionState), DEC-006, DEC-007, ACCEPTANCE (M3)

ไฟล์นี้เป็นข้อเสนอของ Claude ไม่แก้เอกสารที่ Codex เป็นเจ้าของ M2 ยังเหลือข้อที่ Director ต้องรันเอง (ข้อ 2, 3, 5, 6 ใน `docs/qa/M2G_ACCEPTANCE.md`) แต่ M3-A ข้างล่างไม่แตะ gameplay จึงเริ่มคู่กันได้

## 1. เป้าหมาย M3

ออกจากเกมแล้วเข้าใหม่ เลเวล, EXP, เหรียญ, แก่นวิญญาณ, ดาบ+ผนึก, เควสต์ และ checkpoint ต้องกลับมาเหมือนเดิม ข้อมูลไม่หายเมื่อ DataStore ล่ม และสอง server เขียนทับกันไม่ได้ ข้อ M3 ใน ACCEPTANCE ทั้ง 7 ข้อจับคู่กับงานดังนี้

| ข้อ ACCEPTANCE M3 | งาน |
|---|---|
| reconnect แล้ว level/inventory/seal/quests/checkpoint กลับถูก | DataStore adapter + **บันทึก checkpointId จริง** (ตอนนี้ `PlayerService` ตั้งแค่ `RespawnLocation` ยังไม่เขียนลง profile) |
| gauge/active transform ไม่คงข้าม session | อยู่ใน SessionState อยู่แล้ว ไม่ save · เพิ่ม test ว่า envelope ไม่มี field เหล่านี้ |
| load fail แล้วไม่เขียน default ทับ | สร้าง default **เฉพาะตอน key ไม่มีจริง** (`UpdateAsync` ได้ nil) ถ้า call error ห้ามเขียน |
| สอง session ใช้ profile พร้อมกันไม่ได้; stale owner ไม่ทับ | session lease + fencing token ใน envelope |
| duplicate save/retry, queue ordering, migration, shutdown | save queue ต่อผู้เล่น, migration ทีละขั้น, `BindToClose` |
| งบ network/memory/frame time ผู้เล่นเต็ม server | **DEC-007 เปลี่ยนเป็น 12 คน** แต่ ACCEPTANCE ยังเขียน 8 ให้ Codex ปรับข้อความ · ต้องมี clients จริง |
| touch จริง ระบุรุ่น | Director ใช้มือถือจริง (Claude ทำแทนไม่ได้) |

**นอกขอบเขต:** ระบบใหม่ด้าน gameplay, ร้าน, trading, การจัด HUD ทั้งชุด (รอระบบครบ), publish สาธารณะ

## 2. คำถามให้ Director ตัดสิน (มีค่าแนะนำ)

| # | คำถาม | ค่าแนะนำ | เหตุผล |
|---|---|---|---|
| Q1 | ใช้ place ไหนทดสอบ DataStore | publish เป็น **place ทดสอบส่วนตัวแยก** แล้วเปิด Game Settings → Security → Enable Studio Access to API Services | DataStore ใช้ใน Studio ได้เฉพาะ place ที่ publish แล้ว และ ARCHITECTURE ห้ามเขียน store ของ production ระหว่างพัฒนา |
| Q2 | ยอมให้ progress ย้อนได้นานเท่าไรถ้า server ล่มกลางเกม | **autosave ทุก 60 วิ** (ย้อนได้ไม่เกินราว 1 นาที) | ARCHITECTURE ให้ 60–120 วิ ค่าต่ำสุดเสียงบน DataStore เพิ่มแค่เล็กน้อยที่ 12 คน |
| Q3 | ถ้า server เสีย lease ระหว่างเล่น (มีอีก server แย่ง profile) | หยุดให้รางวัลทันที แสดงข้อความแล้ว **kick พร้อมบอกให้เข้าใหม่** | ปลอดภัยกว่าเล่นต่อแบบที่ save ไม่ได้ |

## 3. การออกแบบ

**Envelope ใน DataStore (ฝั่ง server เท่านั้น ไม่ส่ง client):**

```
key   = "u_<UserId>"   store = "SpiritWardProfile_<env>"   (env = "dev" ใน place ทดสอบ)
value = { envelopeVersion = 1,
          profile = ProfileV1,
          session = { jobId, token, leaseUntil } | nil,
          savedAt }
```

**Lease/fencing:**
- Load = `UpdateAsync` ที่ตรวจ `session`: ว่าง, หมดอายุ (`leaseUntil < now`) หรือเป็นของ jobId เดิม → เขียน token ใหม่ (GUID ต่อการเข้าเกม) แล้วรับ profile ถ้ามี server อื่นถืออยู่ → คืนค่าเดิม (ไม่เขียน) แล้วรอ retry แบบจำกัด
- ทุก save = `UpdateAsync` ที่ **เขียนเฉพาะเมื่อ token ใน store ตรงของเรา** ถ้าไม่ตรง → ถือว่าเสีย lease ไม่เขียน (ข้อ Q3)
- lease 5 นาที ต่ออายุทุก autosave · ออกเกม = save + ล้าง `session` · callback ทั้งหมดไม่มี side effect ไม่ yield ตาม ARCHITECTURE กฎ lease แยกเป็น module pure (`LeaseRules`) เพื่อเขียน test ได้

**Load ล้มเหลว:** ผู้เล่นอยู่ในสถานะ `profileReady = false` (มี field นี้อยู่แล้ว) action ทั้งหมดตอบ `NOT_READY` ตามเดิม retry 3 ครั้งแบบ backoff แล้วแสดงข้อความค้าง "โหลดข้อมูลไม่ได้ ออกแล้วเข้าใหม่" **ไม่สร้าง default ไม่เขียนอะไร**

**Migration:** `ProfileMigrations[n]` แปลง v(n) → v(n+1) ทีละขั้นแล้ว `ProfileRules.Validate` ถ้า schemaVersion ใน store **สูงกว่า** ที่ server รู้จัก (server เก่ากว่า) → ปฏิเสธ load ห้ามลดเวอร์ชัน

**Save queue:** หนึ่ง save ที่กำลังส่งต่อผู้เล่น ระหว่างนั้นถ้ามี mutation ใหม่ให้ตั้ง dirty แล้ว save ซ้ำรอบเดียวหลังรอบก่อนเสร็จ (รวมเป็นครั้งเดียว ลำดับไม่สลับ) · ตรวจ `GetRequestBudgetForRequestType` ก่อนส่ง · retry backoff 1/2/4 วิ · `Mutate` ยังเป็นทางเดียวที่แก้ profile ตามเดิม

**Shutdown:** `BindToClose` save + release ทุกคนพร้อมกัน รอไม่เกิน 25 วิ

**Adapter:** `ProfileStore` interface เดียว มี 3 ตัว: `MemoryStore` (โหมดปัจจุบัน, ใช้ใน Studio ที่ไม่ได้ publish, ป้าย "progress resets" ต่อ), `DataStoreStore` (place ทดสอบ), `FakeStore` (ใน test จำลอง error/latency/สอง server) เลือก adapter ตอนเริ่ม server และพิมพ์โหมดลง Output ทุกครั้ง

## 4. แบ่งเป็น batch

| Batch | เนื้อหา | ทดสอบ | ต้องมีอะไร |
|---|---|---|---|
| **M3-A Rules + fake store** | `LeaseRules`, `ProfileMigrations`, save queue, `ProfileStore` interface + `MemoryStore`/`FakeStore`, ย้าย ProfileService ไปใช้ store (พฤติกรรมเล่นเหมือนเดิม) | pure tests: แย่ง lease, lease หมดอายุ, stale token ไม่เขียน, load error ไม่เขียน default, migration, schema สูงกว่าถูกปฏิเสธ, dirty coalesce, retry ordering, envelope ไม่มี gauge/transform · regression 128 tests เดิม | ไม่ต้องรอใคร (Codex รับ envelope ข้อ 5 ก่อน merge) |
| M3-B DataStore adapter | `DataStoreStore`, autosave 60 วิ, save on leave, `BindToClose`, บันทึก checkpointId + spawn ที่ checkpoint ตอนเข้า | ใน place ทดสอบ: เข้า-ออก-เข้าใหม่ ค่าทุกช่องตรง · เปิด 2 Studio/Team Test แย่ง profile เดียว | Q1 |
| M3-C Failure UX | สถานะ loading / load ไม่ได้ / เสีย lease ฝั่ง client พร้อมข้อความทางออก | บังคับ FakeStore ให้ error ใน Studio แล้วดูข้อความ · ข้อความไม่ล้นบนจอ A06 | contract ข้อ 5 |
| M3-D Acceptance | รันข้อ M3 ทั้งหมด บันทึกตามหัวข้อ "รายงานผล" | reconnect, load fail, two sessions, shutdown; perf 12 คนและ touch จริงเป็นส่วนของ Director | clients จริง, มือถือจริง |

## 5. สิ่งที่ต้องให้ Codex รับเข้า contract

1. **Envelope** ตามข้อ 3 (server-only, ตรงกับ CONTRACTS "session metadata/fencing อยู่ใน record envelope") ขอตรึงชื่อ field และ `envelopeVersion` แยกจาก `ProfileV1.schemaVersion`
2. **สถานะโปรไฟล์ไปหา client:** ขอเพิ่ม state event `kind = "profile_status"`, `status = "loading" | "load_failed" | "lease_lost"`, `messageTH` ส่งเฉพาะเจ้าของ ไม่มีข้อมูล profile (เลือกได้อีกทางคือใช้ `notice` ที่มีอยู่ แต่ notice หายเอง ไม่เหมาะกับข้อความที่ต้องค้าง)
3. **DEC-006** ขยับจาก memory adapter เป็น "memory ใน Studio ที่ไม่ publish, DataStore เฉพาะ place ทดสอบ" และ **ACCEPTANCE M3 ข้อ perf** เปลี่ยน 8 → 12 คนตาม DEC-007
4. ยืนยันว่า checkpointId เก็บเป็น stable attribute ID ของ Checkpoint (ARCHITECTURE: ไม่ใช้ชื่อ model เป็น key)

## 6. ความเสี่ยงที่รู้แล้ว

- DataStore ของ Studio ใช้ quota ร่วมกับ place จริง ถ้าใช้ place เดียวกับที่จะ publish อาจเขียนข้อมูลทดสอบปน จึงแนะนำ place แยก (Q1)
- `UpdateAsync` ใน Studio ไม่จำลองการล่มกลาง request ได้ เคสนี้จึงพิสูจน์ด้วย FakeStore เท่านั้น และต้องระบุในรายงานว่าเป็น fake
- server crash ก่อน autosave ทำให้ย้อนได้สูงสุด 1 รอบ autosave (CONTRACTS ระบุว่ายอมรับได้ก่อนเปิดสาธารณะ ต้องเขียนลงผลทดสอบ)
