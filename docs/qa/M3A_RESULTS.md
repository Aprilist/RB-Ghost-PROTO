# M3-A Rules + fake store — ผลส่งงาน

Claude 27 ต.ค. 2026 | แผน: `handoff/M3_PLAN_PROPOSAL.md` (Director ใช้ค่าแนะนำ Q1–Q3) | **สถานะ: รันใน Studio แล้ว 27 ต.ค. 2026 — `[PersistenceTest] 14 passed, 0 failed`, test ทั้งหมด 141/141 ผ่าน** (Play solo ผ่าน Studio MCP; regression เล่นด้วยมือข้อ 3 ด้านล่างยังไม่ได้ทำ)

## ไฟล์ที่เปลี่ยน

| ไฟล์ | อะไร |
|---|---|
| `src/server/Util/LeaseRules.luau` (ใหม่) | transform แบบ pure สำหรับ UpdateAsync: `Acquire` (สร้าง default เฉพาะ key ที่ไม่มีจริง, ไม่แย่ง lease ที่ยังไม่หมดอายุของ server อื่น, ไม่เขียนทับ record ที่เสีย/ใหม่กว่า) และ `Save` (เขียนเฉพาะเมื่อ token ตรง, `release` ล้าง session) lease 300 วิ |
| `src/server/Util/ProfileMigrations.luau` (ใหม่) | ไล่ step ทีละเวอร์ชัน ปฏิเสธเวอร์ชันที่ใหม่กว่า, ช่องว่างของ step และ schemaVersion ที่ไม่ใช่จำนวนเต็ม แล้ว `ProfileRules.Validate` ใน pcall (ข้อมูลที่เก็บไว้ไว้ใจรูปร่างไม่ได้) ตอนนี้ยังไม่มี step จริง (v1) |
| `src/server/Util/MemoryStore.luau` (ใหม่) | store รูปเดียวกับ DataStore adapter ที่จะทำใน M3-B: `Update(key, transform)` ทำ deep copy เข้า/ออก และมี `failNext` จำลอง DataStore ล่ม |
| `src/server/Util/ProfileStorage.luau` (ใหม่) | `Load`/`Save` หนึ่งครั้งต่อการเรียก store ตรวจว่า `userId` ใน record ตรงกับ key |
| `src/server/Util/SaveQueue.luau` (ใหม่) | หนึ่ง save ต่อ key ในเวลาเดียวกัน request ที่มาระหว่างนั้นรวมเป็น save ถัดไปของค่าล่าสุด retry 1/2/4 วิ ถ้าเป็น `lease_lost` จะหยุดทันที ส่วน release ค้างไว้จน worker จบ |
| `src/server/Services/ProfileService.luau` | โหลด/บันทึกผ่าน store + lease, เก็บ record ตาม UserId, ตอนออกจะ save + release, กันการเรียก `Load` ซ้อนกันตอน join (ไม่ให้เกิด token ที่สอง), รอให้ save ตอนออกเสร็จก่อนโหลดใหม่ถ้า rejoin server เดิม · `Load` คืน `nil` เมื่อโหลดไม่ได้ |
| `src/server/Services/PlayerStateService.luau` | ถ้าโหลดโปรไฟล์ไม่ได้ `profileReady = false` (`ready` ตอบ `NOT_READY`) แทนการ error |
| `src/server/Services/QuestService.luau` | type ของ `Load` เป็น optional |
| `src/server/Tests/PersistenceTest.luau` (ใหม่), `Bootstrap.server.luau` | test 14 ข้อ รันอัตโนมัติตอน Play ใน Studio |

## พฤติกรรมที่เปลี่ยนให้ผู้เล่นเห็น

- โหมด memory ยังเหมือนเดิมทุกอย่าง ยกเว้น **ออกแล้วเข้า server เดิมใหม่ ความคืบหน้ายังอยู่** (ก่อนหน้านี้หายทันที) ความคืบหน้าจะหายเมื่อปิด server · ข้อความใน Output เปลี่ยนเป็น "progress resets when the server closes" ส่วนป้ายบนจอ "PROTOTYPE — progress resets" ยังคงเดิม

## Test (`PersistenceTest`, ยังไม่ได้รัน)

สร้าง ProfileStorage สองตัวบน MemoryStore ตัวเดียวแทนสอง server **พิสูจน์ได้แค่กฎ ไม่ใช่พฤติกรรมของ Roblox DataStore** (เป็นของ M3-B/D)

1. เข้าครั้งแรกได้โปรไฟล์ที่ valid และได้ lease
2. NEG server ที่สองแย่ง lease ที่ยังไม่หมดอายุไม่ได้ และไม่เขียนอะไร
3. NEG server เดิมที่ lease หมดอายุไปแล้ว save ทับ server ใหม่ไม่ได้ (`lease_lost`)
4. เข้า server เดิมใหม่ได้ lease ของตัวเองคืน
5. release ตอนออก แล้ว server อื่นโหลดได้ทันที ค่า level/xp/coins/essence/ผนึก/เควส/checkpoint ตรง
6. NEG โหลด error แล้วไม่เขียน default (key ที่ไม่มียังไม่มีต่อไป)
7. NEG โหลด error แล้ว record เดิมไม่ถูกแตะ
8. NEG record เสีย (ไม่ใช่ table, ไม่มี profile, userId ผิด, ค่าผิดกฎ, รูปร่างผิด) ถูกปฏิเสธและไม่ถูกเขียนทับ
9. NEG envelope/schema ที่ใหม่กว่าถูกปฏิเสธ ไม่ถูกลดเวอร์ชัน
10. migration ไล่ทีละขั้น ช่องว่างของ step / ใหม่กว่า / ค่าขยะถูกปฏิเสธ
11. envelope ไม่มี gauge/transform/hp/cooldowns และมีแค่ 4 field
12. SaveQueue: request รัว ๆ ระหว่างที่ save ช้า → save รอบเดียวด้วยค่าล่าสุด (คาด `1,6`)
13. SaveQueue: error แล้ว retry ตาม delay, `lease_lost` หยุดทันที, retry หมดแล้วเลิก
14. SaveQueue: release ที่ขอระหว่าง save ถูกใช้ในรอบถัดไป

## วิธีรัน (Director หรือ Claude รอบถัดไป)

1. `rojo serve` แล้ว sync เข้า Studio
2. กด Play (solo) ดู Output: `[PersistenceTest] 14 passed, 0 failed` และ test เดิมยังผ่าน 128/128
3. regression สั้น ๆ: เข้าเกม, เก็บ EXP/เหรียญ, ทำ q01 ต้องเหมือนเดิม

## ยังไม่ได้ทำ / ต่อใน M3-B

DataStore adapter, ตรวจ `GetRequestBudgetForRequestType`, autosave 60 วิ (ซึ่งต่ออายุ lease ด้วย ตอนนี้ lease ต่ออายุแค่ตอน save), `BindToClose`, เขียน checkpointId ลงโปรไฟล์, kick เมื่อเสีย lease (Q3 ตอนนี้แค่ warn), ข้อความ loading/load_failed ฝั่ง client (M3-C, รอ contract `profile_status`) · envelope ยังรอ Codex รับเข้า contract ก่อน merge
