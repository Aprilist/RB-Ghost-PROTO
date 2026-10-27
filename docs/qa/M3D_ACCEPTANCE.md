# M3-D ACCEPTANCE M3 — ตารางตรวจและผลรัน

Claude 27 ต.ค. 2026 | ใช้คู่กับ `docs/ACCEPTANCE.md` หัวข้อ M3 · build `04175e3` (branch `m2d-quests-npcs`) · รายละเอียดขั้นตอนและค่าที่อ่านจาก DataStore อยู่ใน `docs/qa/M3B_RESULTS.md`

**Environment:** Roblox Studio บน Windows 11, place ทดสอบ `SpiritWard Test` (134965985305218, private), store `SpiritWardProfile_dev`, Play solo ผ่าน Studio MCP · ข้อ 4 ใช้ server จริงจากแอป Roblox (Director เข้าเกม) · หลักฐาน = record ที่อ่านด้วย `GetAsync` ตรงจาก DataStore และ Output

| # | ข้อ ACCEPTANCE M3 | ขั้นตอน | คาด | ได้ | ผล |
|---|---|---|---|---|---|
| 1 | reconnect แล้ว level, inventory, seal, quests, checkpoint กลับถูก | (ก) แตะ `mistwood_gate` → หยุด → Play ใหม่ · (ข) เขียน Lv 3/xp 5/เหรียญ 40/แก่น 30/ผนึก ember/q01 claimed/q02 2/5 ลง record → Play → อ่าน HUD → หยุด → อ่าน record | เกิดที่ checkpoint, HUD ตรง, record ไม่เปลี่ยน | (ก) **ครั้งแรกตก**: เกิดที่หมู่บ้าน record ถูกเขียนทับเป็น `village_shrine` (จุดเกิดตอนเข้าเป็น checkpoint เอง) แก้ใน `e769a94` แล้วรันซ้ำ: เกิดที่ z=336 `mistwood_gate` · (ข) HUD `Lv 3`, `EXP 5 / 100`, `แก่นวิญญาณ 30`, `เหรียญ 40`, `ผนึก: ผนึกถ่านไฟ`, q02 `2/5` · หลังหยุดค่าเดิมครบ `session=nil` | **ผ่าน** (ค่า (ข) เขียนเข้า store ตรง ไม่ได้มาจากการสู้จริง ทางบันทึกเป็น `Mutate` เดียวกับ (ก)) |
| 2 | gauge/active transform ไม่คงข้าม session | อ่าน envelope ใน store · HUD หลังเข้าใหม่ | ไม่มี field session state, เกจ 0 | envelope มีแค่ `envelopeVersion, profile, savedAt, session` · `วิญญาณ 0 / 100` · `PersistenceTest` ข้อ 11 | **ผ่าน** |
| 3 | จำลอง load fail แล้วไม่เขียน default ทับ record | (ก) `PersistenceTest` ข้อ 6–8 (MemoryStore `failNext`) · (ข) lease ของ server อื่นยังไม่หมด → Play → หยุด | ไม่เขียนอะไร, client มีทางออก | (ก) 3/3 ผ่าน · (ข) `load failed ... held`, record rev/token เดิมทั้งตอนโหลดและตอนหยุด, client ขึ้น "โหลดข้อมูลตัวละครไม่ได้ ออกแล้วเข้าใหม่อีกครั้ง" | **ผ่าน** (DataStore ล่มกลาง request จริงจำลองใน Studio ไม่ได้ ส่วนนั้นพิสูจน์ด้วย fake เท่านั้น) |
| 4 | สอง session ใช้ profile พร้อมกันไม่ได้; stale owner ไม่ทับ | Director อยู่ในเกมจากแอป (jobId `e177547e…`) → Studio Play → หยุด → Director แตะ `mistwood_gate` แล้วออก → Studio Play · stale owner: `PersistenceTest` ข้อ 3 · lease หมดอายุ: `session` ของ `dead-server` หมดแล้ว → Play | Studio ได้ held ไม่แตะ record; ออกแล้ว release; lease หมดอายุยึดได้ | Studio `held` ×2, record rev 4 token เดิม · server จริงออก → rev 5 `session=null` `mistwood_gate` · Studio โหลดได้ทันที · lease หมดอายุ → `session.jobId=studio` · stale save → `lease_lost` | **ผ่าน** |
| 5 | duplicate save/retry, queue ordering, migration, shutdown | `PersistenceTest` ข้อ 9–10, 12–14 · หยุด Play (`BindToClose`) | รวม save, retry ตาม delay, migration ทีละขั้น, ปิดแล้ว save + release | test ผ่านทุกข้อ (142/142 ทั้งชุด) · หยุด Play แล้ว `savedAt` ใหม่ + `session` หาย ทุกรอบ | **ผ่าน** (shutdown ทดสอบกับผู้เล่น 1 คน) |
| 6 | งบ network, memory, frame time ใน scene ผู้เล่นเต็ม | ค่าฐาน Play solo 20 วิ เดินเข้าป่า (ศัตรู 12 ตัว) | — | server heartbeat เฉลี่ย 16.67 ms แย่สุด 19.1 ms · client frame เฉลี่ย 16.66 ms แย่สุด 27.5 ms · server ส่ง 41 KB/s · memory/receive ของ Play solo ใช้ไม่ได้ (server กับ client อยู่ process เดียว) | **partial** 5 คนผ่านทั้งเดินและสู้ (ดู "ผล Local Server 5 คน") · 8/12 คนยังไม่ได้วัด · ข้อความ ACCEPTANCE ยังเขียน 8 คน DEC-007 เป็น 12 รอ Codex |
| 7 | touch จริง ระบุรุ่นเครื่อง | — | — | M2-G วัดใน Device Simulator เท่านั้น | **blocked** ต้องมือถือจริงของ Director |

## ผล Local Server 5 คน (28 ต.ค. 2026, build `89f4ca6`)

Studio → Test → Local Server + 5 players บนเครื่องเดียว (Director เปิด) วัดผ่าน Studio MCP ทั้ง 6 หน้าต่าง · ทุกคนเข้า datastore mode (UserId -1…-5) ไม่มี error · ทั้ง 5 คนเดินจากหมู่บ้าน (z 496) เข้าป่า (z 124–281) พร้อมกัน

| ที่วัด | หมู่บ้าน (ยืนนิ่ง) 25 วิ | ในป่า 20 วิ |
|---|---|---|
| server heartbeat เฉลี่ย / แย่สุด | 16.68 / 35.4 ms | 16.67 / 20.0 ms |
| server ส่งรวม เฉลี่ย / peak | 40.5 / 44.2 KB/s | 44.8 / 50.7 KB/s (≈ 9 KB/s ต่อคน) |
| server memory | 290 → 321 MB | 443 MB |
| instance บน server | 62,437 | — |

- **server ไม่ตึง:** heartbeat ไม่หลุด 60 Hz เลย มีแค่ spike 35 ms ครั้งเดียวตอนวัดในหมู่บ้าน
- **network:** ค่าส่งรวมแทบไม่เพิ่มตามจำนวนคน (คนเดียว 41 KB/s, 5 คน 45 KB/s) ค่า 41 KB/s ตอนเล่นคนเดียวจึงเป็นค่าคงที่ของ world ไม่ได้คิดต่อคน
- **memory server โต 290 → 443 MB** ตอนผู้เล่นกระจายเข้าป่า ยังไม่รู้ว่าหยุดโตที่เท่าไร ต้องดูนานกว่านี้
- **ฝั่ง client ใช้ตัวเลขไม่ได้:** 6 หน้าต่างอยู่บนเครื่องเดียว หน้าต่างที่ไม่ได้ focus ถูกจำกัดราว 15 fps (frame ≈ 66 ms) และ `DataReceiveKbps` ใน client ของ Studio อ่านได้ 0
### ระหว่างสู้ และ memory ระยะยาว (ชุดเดิม 5 คน)

Bot ทดสอบรันในทั้ง 5 client 90 วิ: วิ่งหาศัตรูที่ใกล้สุดในป่า ส่ง `basic_attack` ผ่าน remote จริงทุก 0.4 วิเมื่ออยู่ในระยะ และ `cast_skill` ทุก 3 วิ (bot อยู่ใน scratchpad ไม่ได้เข้า repo)

| ที่วัด | ผล |
|---|---|
| server heartbeat 60 วิระหว่างสู้ | เฉลี่ย 16.67 ms แย่สุด 21.9 ms, **เฟรมเกิน 25 ms: 0/3639** |
| server ส่งรวม | เฉลี่ย 30.4 KB/s peak 40.0 KB/s |
| การสู้เกิดจริง | ศัตรู 12 → 7 ตัว, ผู้เล่น 4/5 คนเสีย HP (100–112/120) · Player1 ส่ง 49 action: OK 33, COOLDOWN 16 (bot ตีเร็วกว่า cooldown จึงถูกปฏิเสธตามกฎ) ได้ EXP/เหรียญ/แก่นวิญญาณ, เกจเต็ม 100 |
| memory server (MB) | ก่อนสู้ 466 → ระหว่างสู้ทุก 10 วิ 312, 316, 318, 319, 321, 326 → หลังสู้ทุก 15 วิ 328, 351, 354, 363, 366, 367, 368, 370 · ศัตรูเกิดครบ 12 |
| instance บน server | 62,437 คงที่ตลอด |

- **memory ไม่ใช่ leak ของ instance:** จำนวน instance ไม่เพิ่มเลย และ memory ลดจาก 466 เหลือ 312 MB เองโดยไม่ได้ทำอะไร เป็นรูปฟันเลื่อยของ garbage collection อยู่ในช่วง 290–466 MB · ยังไม่ได้ดูนานกว่า ~10 นาที ถ้าจะยืนยันต้องเปิด server ทิ้งไว้ ≥ 30 นาทีแล้วดูว่าจุดต่ำสุดหลังแต่ละรอบยังคงที่ไหม
- **ยังไม่ได้วัด:** 8/12 คน และฝั่ง client บนเครื่องจริง

### memory server ระยะยาว (Local Server 3 คน, 28 ต.ค. 2026)

เก็บทุก 30 วิ ระหว่างรอบบอสด้วย bot 2 รอบ (ดู `M2G_ACCEPTANCE.md`) · MB / instance:

`30s 908/60293 · 60s 693 · 90s 653 · 120s 624 · 150s 649 · 180s 681 · 210s 647 · 240s 671 · 270s 682 · 300s 683 · 330s 685 · 360s 690/60359 · 390s 618 · 420s 627 · 450s 632 · 480s 635/60293`

ต่อจนครบ 30 นาที (bot หยุดตั้งแต่นาทีที่ ~5 ผู้เล่น 3 คนยืนนิ่งที่จุดเกิด ศัตรูเกิดใหม่ตามรอบ):

`510s 569 · 660s 578 · 780s 583 · 810s 450 · 960s 460 · 1081s 466 · 1111s 348 · 1201s 356 · 1291s 440 · 1411s 490 · 1531s 543 · 1651s 540 · 1801s 541 · 1831s 542/60359`

| ช่วง | ต่ำสุด | สูงสุด |
|---|---|---|
| 0–8 นาที | 618 | 690 (ไม่นับ 908 ตอนโหลด) |
| 8–13 นาที | 569 | 583 |
| 13–18 นาที | 450 | 466 |
| 18–30 นาที | 348 | 544 |

- **ไม่พบ leak ใน 30 นาที:** memory ลดลงเองเป็นรอบ ๆ (690 → 583 → 466 → 348) ค่าต่ำสุดของแต่ละรอบต่ำลงเรื่อย ๆ ไม่ไต่ขึ้น ช่วงท้าย 25–30 นาทีนิ่งที่ 540–544 MB · instance คงที่ 60,260–60,371 ตลอด (ขึ้นลงตามศัตรูที่เกิดใหม่)
- ค่าสัมบูรณ์ต่างจากรอบ 5 คน (290–466) เพราะเป็นคนละ process ของ Local Server ใช้ดูแนวโน้มในรอบเดียวกันเท่านั้น
- ทดสอบตอนผู้เล่นยืนนิ่งเป็นส่วนใหญ่ ยังไม่ได้ทดสอบเล่นต่อเนื่อง 30 นาที

## ที่ต้องทำต่อเพื่อปิดข้อ 6–7

- **ข้อ 6:** วัดซ้ำตอนสู้ และที่ 8 คน (Local Server ได้สูงสุด 8 บนเครื่องเดียว) · 12 คนจริงต้องเข้าจากหลายเครื่องบน server จริง แล้วดู Developer Console (F9 → Server → Memory/Network) · ตาม memory server ว่าหยุดโตไหม
- **ข้อ 7:** เปิดเกมบนมือถือจริง (เกม private เข้าได้ด้วยบัญชีเจ้าของ) จดรุ่นเครื่อง แล้วเล่น q01–q02 ด้วย touch ดู HUD บังท่าเตือนไหม
