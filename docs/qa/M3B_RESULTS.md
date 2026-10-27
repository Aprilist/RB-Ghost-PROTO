# M3-B DataStore adapter — ผลส่งงาน

Claude 27 ต.ค. 2026 | แผน: `handoff/M3_PLAN_PROPOSAL.md` (Director ใช้ค่าแนะนำ Q1–Q3) | **สถานะ: รันแล้วทั้ง memory และ datastore mode — ข้อ 2–6 ผ่าน, M3-C ข้อความโหลดไม่ได้ผ่าน**

## ผลรัน 27 ต.ค. 2026 (Play solo ผ่าน Studio MCP, place ยังไม่ publish `PlaceId=0`)

- source ใน Studio ตรงกับ repo (ขนาดไฟล์ที่แก้ใน M3-A/B ตรงทุกไฟล์)
- Output: `[ProfileService] memory mode: progress resets when the server closes (unpublished place)` — เลือก memory ถูกต้องสำหรับ place ที่ยังไม่ publish ไม่มี error
- test ทั้งหมด **141/141 ผ่าน** (PersistenceTest 14/14)
- เดินผ่าน checkpoint `mistwood_gate` → `RespawnLocation` เปลี่ยนตาม (การเขียน `checkpointId` ลงโปรไฟล์และการเกิดที่ checkpoint ตอนเข้าใหม่ ยังพิสูจน์ไม่ได้ใน solo — ต้องข้อ 3)

## ผลรัน datastore 27 ต.ค. 2026 (place ทดสอบ `SpiritWard Test` 134965985305218, API access เปิด)

- ข้อ 2 ผ่าน: `[ProfileService] datastore mode: SpiritWardProfile_dev ok`, test 141/141
- เข้าเกม: record `u_<UserId>` ถูกสร้าง มี `session` (lease 300 วิ) · envelope มีแค่ `envelopeVersion, profile, savedAt, session` ไม่มี gauge/transform/hp (ข้อ 4 ส่วนข้อมูล)
- autosave 60 วิ: `checkpointId`, เควสต์ q01 active ถูกเขียน และ `leaseUntil` ต่ออายุ
- หยุด Play (`BindToClose`): save ล่าสุดแล้ว `session` หายจาก record (release)
- **บั๊กที่เจอและแก้แล้ว:** จุดเกิดตอนเข้า (`VillageSpawn`) เป็น checkpoint `village_shrine` เอง ตัวละครเกิดแล้ว Touched ทันที → เขียนทับ `checkpointId` ก่อน PlayerService จะย้ายไป checkpoint ที่บันทึกไว้ ผล: เข้าใหม่เกิดหมู่บ้านทุกครั้งและเสีย checkpoint เดิม · แก้ `PlayerService`: ไม่รับการแตะ checkpoint จนกว่าการเลือกจุดเกิดตอนเข้าจะเสร็จ (`placed`)
- หลังแก้: บันทึก `mistwood_gate` → Play ใหม่เกิดที่ `mistwood_gate` (z=336) · เดินไปแตะ `village_shrine` → ออก → record เป็น `village_shrine`, `session=nil`
- ข้อ 5 (จำลอง): เขียน `session` ของ server อื่น (`fake-other-server`, lease ยังไม่หมด) ลง record แล้ว Play → `load failed ... held` หลัง retry, client `ready failed` (ยังไม่มีข้อความบนจอ รอ M3-C) · record ไม่ถูกแตะทั้งตอนโหลดและตอนหยุด (rev 4, session เดิม) · ล้าง lease ปลอมหลังทดสอบ
- ข้อ 5 (สอง session จริง) ผ่าน: Director เข้าเกมจากแอป Roblox (server จริง jobId `e177547e…`, publish รวมการแก้ `placed` แล้ว) → Studio Play ได้ `held` ×2, record ไม่ถูกแตะทั้งตอนโหลดและตอนหยุด (rev 4, token เดิม) · Director เดินแตะ `mistwood_gate` แล้วออก → server จริง save + release (`session=null`, rev 5, `checkpointId=mistwood_gate`) · Studio Play ใหม่โหลดได้ทันที (ไม่มี load failed) และเกิดที่ `mistwood_gate`
- ข้อ 6 ผ่าน: ปิด API access บน place ที่ publish แล้ว → `[ProfileService] memory mode: ... (502: ... Studio access to APIs is not allowed.)` (warn), โหลดโปรไฟล์ได้ ไม่มี `ready failed`, test 142/142 (มีเพิ่มมาหนึ่งข้อจากงานอื่น) · มีบรรทัดแดง `DataStoreService: StudioAccessToApisNotAllowed` หนึ่งบรรทัด เป็น log ของ engine เองตอน probe (`GetAsync` อยู่ใน pcall) ไม่ใช่ script error
- ข้อ 3 ส่วนค่าจากการสู้ + lease หมดอายุ ผ่าน: เขียนค่าลง record (Lv 3, xp 5, เหรียญ 40, แก่นวิญญาณ 30, ผนึก ember, q01 claimed, q02 2/5) พร้อม `session` ของ `dead-server` ที่หมดอายุแล้ว → Play ยึด lease ได้ทันที (`session.jobId=studio`), HUD แสดงตรงทุกช่อง, เกจ 0, เกิดที่ `mistwood_gate` · หยุด → ค่าเดิมครบ `session=nil` (ค่าถูกเขียนตรงเข้า store ไม่ได้มาจากการสู้จริง ทางบันทึกเป็น `Mutate` เดียวกับ checkpoint/เควสต์ที่ผ่านแล้ว)
- M3-C ผ่าน: lease ของ server อื่นยังไม่หมดอายุ → client ขึ้นข้อความค้าง "โหลดข้อมูลตัวละครไม่ได้ ออกแล้วเข้าใหม่อีกครั้ง" (ใช้ code `NOT_READY` เดิม ไม่ต้องมี `profile_status`, `handoff/M3_CONTRACT_PROPOSALS.md` ข้อ 5) · ล้าง lease ปลอมหลังทดสอบ
- ข้อสังเกต: ป้าย "PROTOTYPE — progress resets" ยังขึ้นใน datastore mode ซึ่งไม่จริงแล้ว
- ยังไม่ได้ทดสอบ: server ล่มจริงกลางเกม (ย้อนได้ไม่เกิน 1 รอบ autosave), perf 12 คน, touch จริง (M3-D)

## ไฟล์ที่เปลี่ยน

| ไฟล์ | อะไร |
|---|---|
| `src/server/Util/DataStoreStore.luau` (ใหม่) | `Update(key, transform)` รูปเดียวกับ MemoryStore ใช้ `UpdateAsync` ใน pcall · รอ `GetRequestBudgetForRequestType(UpdateAsync)` ได้สูงสุด 10 วิ ก่อนส่ง · `Probe()` อ่านครั้งเดียวตอนเริ่มเพื่อดูว่า server นี้ใช้ DataStore ได้ไหม |
| `src/server/Services/ProfileService.luau` | เลือก store ตอน `Init`: place ที่ยังไม่ publish ใน Studio → memory · probe ผ่าน → datastore (`SpiritWardProfile_dev`) · probe ไม่ผ่านใน Studio (ปิด API access) → memory พร้อม warn บอกเหตุผล · **server จริงไม่ถอยไป memory เด็ดขาด** (load จะล้มแบบปิด ไม่แจกโปรไฟล์ใหม่) · retry load 1/2/4 วิ เฉพาะ `error`/`held` · autosave ทุก 60 วิ (ต่ออายุ lease ไปด้วย) · `BindToClose` save + release ทุกคน รอไม่เกิน 25 วิ · เสีย lease → หยุดให้รางวัลทันที แล้ว kick พร้อมข้อความไทย (Q3) |
| `src/server/Services/PlayerService.luau` | แตะ checkpoint → เขียน `checkpointId` (ค่า attribute `CheckpointId`) ลงโปรไฟล์ผ่าน `Mutate` · เข้าเกม → ถ้าโปรไฟล์มี checkpoint ที่ไม่ใช่จุดเริ่มต้นและมีอยู่จริงในฉาก จะเกิดที่นั่น (id ที่ไม่รู้จักถูกข้าม) |
| `src/server/Bootstrap.server.luau` | ส่ง `Profiles` ให้ PlayerService · ข้อความเริ่ม server บอกโหมด store |

## วิธีทดสอบ (ต้องทำใน place ทดสอบที่ publish แล้ว, Q1)

1. Publish เป็น place ทดสอบส่วนตัว → Game Settings → Security → เปิด **Enable Studio Access to API Services**
2. กด Play: Output ต้องมี `[ProfileService] datastore mode: SpiritWardProfile_dev ok` และ test เดิม 141/141 ยังผ่าน
3. **reconnect:** เก็บ EXP/เหรียญ, ทำ q01, ใส่ผนึก, เดินไปแตะ checkpoint หมู่บ้าน → หยุด → Play ใหม่ → level/xp/เหรียญ/แก่นวิญญาณ/ผนึก/เควสต์ตรง และเกิดที่ checkpoint หมู่บ้าน
4. **gauge/transform ไม่คงข้าม session:** แปลงร่างแล้วหยุด → Play ใหม่ เกจเป็น 0
5. **two sessions:** Team Test หรือสอง Studio บน place เดียวกัน เข้า account เดียวกันตอนอีกฝั่งยังเล่นอยู่ → ฝั่งที่สองโหลดไม่ได้ (`held`, `ready` ตอบ `NOT_READY`) หลัง retry
6. **API access ปิด:** Output ต้องเป็น memory mode พร้อมเหตุผล ไม่ error

## ยังไม่ได้ทำ

- ฝั่ง client: ข้อความ loading / load_failed / lease_lost (M3-C, รอ Codex รับ `profile_status`) ตอนนี้ผู้เล่นที่โหลดไม่ได้จะค้างที่ `NOT_READY` โดยไม่มีข้อความ
- ชื่อ store production (ตอนนี้ใช้ `_dev` ตัวเดียว ต้องตั้งก่อน publish สาธารณะ)
- autosave ส่งทุกคนทุก 60 วิ แม้โปรไฟล์ไม่เปลี่ยน (ตั้งใจ เพื่อต่ออายุ lease) ที่ 12 คนใช้ราว 12 UpdateAsync/นาที ต่ำกว่างบมาก
- test อัตโนมัติของ DataStoreStore ไม่มี เพราะพิสูจน์ได้เฉพาะกับ DataStore จริง (ข้อ 2–6 ข้างบน)
