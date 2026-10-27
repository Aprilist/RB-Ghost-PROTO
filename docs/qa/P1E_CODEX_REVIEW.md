# P1-E — Movement, mobile simulator และ 2 clients

วันที่ 27 ตุลาคม 2026 | Codex review | Local Studio engine 0.744

## สถานะ

ตรวจขอบเขต E1–E9 ใน local Studio แล้ว พร้อม A6 บน iPhone XR simulator และ D1–D4 บน server + 2 clients จริง รายละเอียดเงื่อนไขแต่ละกรณีอยู่ด้านล่าง ผ่านสำหรับการเดินหน้าทำ visual benchmark ของต้นแบบ ไม่ใช่การรับรอง production anti-cheat, latency สูง หรือมือถือจริง

Director เคยทดลอง core loop แล้วรายงานว่า “ปกติดี” ก่อนรอบนี้ ไม่มีการอ้างว่าผู้ใช้ได้ลองค่า/ปุ่มที่ปรับใหม่แล้ว

## จุดที่ Codex แก้เพิ่ม

### 1. ระยะเผื่อเดินถูกแจกใหม่ทุก sample

ก่อนแก้ สูตร `walkSpeed × elapsed × 1.3 + 2.5` รีเซ็ต anchor ทุกครั้งที่ยอมรับ ทำให้ pure simulation ที่เดิน 28 studs/sec ผ่านทั้ง 12 samples ทั้งที่เพดานอัตราต่อเนื่องที่ตั้งใจคือ 16 × 1.3 = 20.8

เปลี่ยน `MovementRules.Tracker` ให้มี `walkCreditStuds` เป็น jitter reserve ที่มีเพดาน ใช้ไปตามระยะที่เดินและเติมตามเวลาจริง ไม่แจก slack ใหม่ทุก sample รวมการใช้เครดิตเมื่อจบ dash ด้วย

เพิ่ม regression tests: sustained speed 28 ต้อง reconcile และ network burst ภายในเครดิตต้องผ่าน ชุดเดิม 13/13 ผ่านก่อนแก้ ชุดหลังแก้ 15/15 ผ่านใน Play Server บน Studio

ไฟล์: `src/server/Util/MovementRules.luau`, `src/server/Tests/MovementRulesTest.luau`

### 2. ปุ่มฟันล้นจอในมือถือจำลอง

เปิด iPhone XR landscape simulator จริง พบ default CAS layout วางปุ่มฟันต่ำจนขอบเครื่องบังบางส่วน ปรับเป็นกลุ่ม 2×2 ภายใน action frame โดยใช้ตำแหน่งจาก `Prototype.Input` แล้ว `ContextActionService:SetPosition()`

ไฟล์: `src/shared/Definitions/Prototype.luau`, `src/client/Controllers/InputController.luau`

หลังแก้เห็นปุ่มทั้งสี่ครบ ไม่ทับ joystick/jump ใน viewport ที่ตรวจ แตะฟัน/วิชา/พุ่งได้ OK และแปลงร่างได้ NOT_READY เมื่อ gauge ว่างตามกติกา กล้องไม่หมุนตามการแตะ (look-vector dot ≈ 1); ลากในพื้นที่โลกแล้วกล้องเปลี่ยนทิศ (dot ≈ 0.99989) ยังไม่ได้ตรวจ simultaneous multitouch หรือมือถือจริง

## ตารางผล

| ID | ผลและขอบเขต |
|---|---|
| E1 | 15 passed, 0 failed ใน Play Server; เป็น pure logic tests ไม่แทน runtime |
| E2 | Q ในพื้นที่โล่ง: 3 ครั้งก่อนแก้และ 2 ครั้งหลังแก้เครดิต ระยะประมาณ 11.91–12.20 studs, corrections 0; อีก 2 clients และ mobile simulator ก็ dash ได้ |
| E3 | Q เข้ากำแพงหลังแก้: หยุดที่ Z≈-4.098 ด้านใต้ wall center Z=-6; corrections คง 2→2 |
| E4 | client teleport 20 studs: ถูกคืนตำแหน่งคลาดต้นทางประมาณ 0.000062 studs, corrections 0→1; อ่านผลที่ 1.2 วินาที ไม่รับรอง threshold ~0.3 วินาที |
| E5 | dash request แรก OK, ครั้งที่สองใน cooldown ได้ COOLDOWN; client ขยับเอง 10 studs แล้วถูกดึงกลับ, corrections 1→2; ไม่ได้วัด upper bound ~0.7 วินาที |
| E6 | client ข้าม TestWall: กลับฝั่งเดิม, corrections 2→3 |
| E7 | client WalkSpeed 40 แล้วกดเดิน 3 วิ: corrections 3→6; หลังเครดิต fix ทดสอบ speed 28 อีกครั้งได้ corrections 0→2 |
| E8 | เดินขึ้น ramp หลังแก้: corrections 0; กระโดดข้าม cover: 0→0; กระโดดจาก ramp ขึ้น low tier ถึง (26.216,9.606,17.535): 2→2 |
| E9 | server แยก + Player1/Player2 จริง แต่ละ client กด Q: corrections 0 ทั้งสอง |
| A6 | iPhone XR landscape simulator: touch=true, viewport 801×413, เห็น/แตะปุ่มครบและกล้องแยกจากปุ่มหลังปรับ layout; ยังไม่มี physical-device test |
| D1 | ทั้งสอง client มี enemy runtime IDs และ X/Z เดียวกัน (Y hover ต่างตามเวลาอ่าน); ได้ slash/hit/orb FX event IDs ชุดเดียวกัน |
| D2 | Player2 ทำ damage 40, Player1 ทำ final20 ให้ผีตัวเดียวกัน ทั้งคู่ได้ gauge10/essence5 คนละครั้ง; ไม่ใช้ mock players |
| D3 | บังคับ Player1 ตาย: snapshot ของ Player1 alive=false/HP0/gauge0 แต่ Player2 ยัง alive และ gauge10/essence5; state ไม่ปน |
| D4 | เมื่อ Player2 ใกล้ผีและ Player1 อยู่ spawn: 16 samples เลือก Player2 เป็น nearest; ช่วง chase มี movement dot เข้าหา Player2 เป็นบวกทุก sample ที่ขยับ |

หลักฐาน raw: [P1E_RUNTIME.json](evidence/P1E_RUNTIME.json) ส่วนตัวเลข pure reproduction ก่อนแก้บันทึกในคำอธิบายนี้ด้วย

## Fixtures และการทำความสะอาด

- ช่วงทดสอบ 2 clients ครั้งแรก Player1 ตายระหว่างสลับหน้าต่าง ทำให้การตีครั้งนั้นไม่เข้าเป้า ไม่นับเป็นผล D2
- รอบ D2/D3 ที่ใช้สรุป ตั้ง maxHp/HP=10000 ใน memory ฝั่ง server ชั่วคราวเพื่อกันการตายระหว่างสลับเครื่องมือ ไม่เปลี่ยน production tuning, damage หรือ reward ใน source
- ทดสอบผ่าน remotes จริงและ state ของจริง ไม่ใช้ mock player แทน multiplayer
- ใช้ computer-use skill สำหรับ Studio Device Simulator และเมนู Server and Clients จากนั้นใช้ Studio MCP ตรวจ state
- End Session ปิด server/clients ที่เปิดเพิ่มแล้ว เหลือ Place1 เดิม เปิด Play แบบ desktop, HP100, corrections0 และไม่มี QA fixture ค้างข้าม session
- Rojo build ผ่าน ได้ `%LOCALAPPDATA%/SpiritWard/builds/SpiritWard-P1E.rbxlx`; syntax compile 24 files ผ่านก่อนรอบทดสอบหลัก ไม่ใช่ strict type analysis
- ไม่ commit และไม่ publish

## ข้อจำกัดที่ยอมรับเฉพาะต้นแบบ

- Movement ยังใช้ client-owned physics และ server sampling ไม่ใช่การจำลอง physics ทั้งหมดบน server
- ยังไม่ตรวจ Y และมีข้อจำกัดกับ cover เตี้ยตามรายงาน Claude; ไม่ถือว่าป้องกัน flight/noclip ทุกแบบ
- speed tolerance/jitter/grace ยังไม่ได้ทดสอบ WAN latency และ packet loss
- ยังไม่ทดสอบกรณี teleport-attack-return ระหว่าง samples หรือยืนยัน combat ตัดสิทธิ์ตำแหน่ง pending ทุกกรณี ต้องพิจารณาก่อนเปิดให้คนนอก
- มือถือจริง/portrait/หลายสัดส่วนจอ/gamepad และ performance 8 players ยังไม่ผ่าน
- ยังมี warning avatar asset type เดิม; ไม่มี P1 script exception ที่พบในรอบหลัก

งานต้นแบบเดินหน้าภาพตัวอย่างได้โดยคงข้อจำกัดเหล่านี้ใน backlog ก่อน public testing
