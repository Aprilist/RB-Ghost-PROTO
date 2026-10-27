# Acceptance checklist

สถานะทุกข้อเริ่มต้น: ยังไม่รันทดสอบ ใช้ checklist นี้กับ milestone ไม่ใช่กล่าวว่าระบบพร้อมแล้ว

## M0

- [x] ผู้ใช้เลือกกล้อง 3D บุคคลที่สาม (DEC-001); เป็น decision ไม่ใช่ผลทดสอบ runtime
- [ ] เลือก sync DEC-002
- [ ] Contract/types/runtime examples ใช้ field และ IDs ตรงกัน
- [ ] เปิด greybox ใน Studio ไม่มี error จาก bootstrap
- [ ] โครง Services/Controllers แยก server/client ชัด
- [ ] ทำ mock snapshot ได้โดยไม่สัมผัส production DataStore

## M1

- [ ] เดินอิสระ X/Z กระโดด dash และโจมตีด้วย keyboard และ touch
- [ ] หมุน/ซูมกล้องได้ ไม่ทะลุผนัง; ลากกล้องไม่แย่ง input กับปุ่มมือถือ
- [ ] ท่าเตือนผีอ่านได้จากหลายมุม; ศัตรูนอกระยะ/หลังผนัง/คนละชั้นไม่โดนผิดเงื่อนไข
- [ ] soft aim ไม่เลือกเป้าหมายหลังผนังหรือเพิ่มระยะ; zero/NaN/Infinity directions ถูกปฏิเสธ
- [ ] dash ไม่ผ่านกำแพง และ AI อ้อมสิ่งกีดขวางใน greybox ได้
- [ ] หนึ่ง death ให้ reward หนึ่งครั้งต่อผู้มีสิทธิ์ ไม่มี last-hit stealing
- [ ] gauge 100 เปิด transform; หมดเวลา/ตายแล้วคืน state ถูกต้อง
- [ ] spam transform/basic_attack และ payload ผิด type ไม่เพิ่มพลัง/เงิน
- [ ] ตายแล้ว checkpoint ทำงาน ไม่มี enemy หรือ connection ค้างจากรอบก่อน

## M2

- [x] ผู้เล่นใหม่ทำ 5 quests จนจบบอสได้โดยไม่ใช้ command (Director เล่นจบ 27 ต.ค. 2026; ผลใน `docs/qa/M2G_ACCEPTANCE.md`)
- [ ] seal 2 แบบมีผลต่างกันและแสดงต้นทุนก่อนยืนยัน
- [ ] essence ไม่ติดลบ; duplicate request ไม่หักหรือ grant ซ้ำ
- [x] quest one-time claim ซ้ำไม่ได้; prerequisites ทำงาน (ยิง claim_quest ซ้ำจาก client ผ่าน Studio MCP 27 ต.ค. 2026; ผลใน `docs/qa/M2G_ACCEPTANCE.md`)
- [ ] boss 1/2/8 participants; all-dead reset; late join กติกาถูกต้อง
- [ ] รางวัลผู้ตาย/ออกพื้นที่/ทำ damage ต่ำกว่าเกณฑ์ตรง contract
- [x] HUD จอ desktop และ touch ไม่บังท่าเตือน; loading/error มีทางออก (Studio + Device Simulator ผ่าน MCP 27 ต.ค. 2026 ยังไม่ใช่มือถือจริง; ผลใน `docs/qa/M2G_ACCEPTANCE.md`; ผ่านสำหรับ HUD ชุด M2 เท่านั้น จัด layout จริงตอนระบบครบ)

## M3

- [ ] reconnect แล้ว level, inventory, seal, quests และ checkpoint กลับถูกต้อง
- [ ] gauge/active transform ไม่คงข้าม session
- [ ] จำลอง load fail แล้วไม่เขียน default ทับ record
- [ ] สอง session ใช้ profile พร้อมกันไม่ได้; stale owner save ไม่ทับใหม่
- [ ] duplicate save/retry, queue ordering, migration และ shutdown ผ่าน
- [ ] ตรวจงบ network, memory, frame time ใน scene ผู้เล่น 12 คน (DEC-007)
- [ ] ทดสอบ touch จริง ระบุรุ่นเครื่อง/ผล; emulator อย่างเดียวไม่พออ้าง mobile ผ่าน

## รายงานผล

แต่ละข้อบันทึก build/commit, environment, steps, expected, actual, pass/fail และหลักฐาน ห้ามใช้รายการ checklist แทนผลทดสอบจริง
