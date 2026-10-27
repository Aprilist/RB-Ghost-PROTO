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
| 6 | งบ network, memory, frame time ใน scene ผู้เล่นเต็ม | ค่าฐาน Play solo 20 วิ เดินเข้าป่า (ศัตรู 12 ตัว) | — | server heartbeat เฉลี่ย 16.67 ms แย่สุด 19.1 ms · client frame เฉลี่ย 16.66 ms แย่สุด 27.5 ms · server ส่ง 41 KB/s · memory/receive ของ Play solo ใช้ไม่ได้ (server กับ client อยู่ process เดียว) | **blocked** ต้องมีหลาย client (ดูข้างล่าง) · ข้อความ ACCEPTANCE ยังเขียน 8 คน DEC-007 เป็น 12 รอ Codex |
| 7 | touch จริง ระบุรุ่นเครื่อง | — | — | M2-G วัดใน Device Simulator เท่านั้น | **blocked** ต้องมือถือจริงของ Director |

## ที่ต้องทำต่อเพื่อปิดข้อ 6–7

- **ข้อ 6:** Studio → Test → Clients and Servers → Local Server + N players (ได้สูงสุด 8 บนเครื่องเดียว) วัดฝั่ง server ด้วย Developer Console (F9 → Memory/Network, Server) · 12 คนจริงต้องเข้าจากหลายเครื่องบน server จริง · ข้อสังเกต: 41 KB/s ต่อผู้เล่นคนเดียวถือว่าสูง ต้องดูว่าโตตามจำนวนผู้เล่นแค่ไหน
- **ข้อ 7:** เปิดเกมบนมือถือจริง (เกม private เข้าได้ด้วยบัญชีเจ้าของ) จดรุ่นเครื่อง แล้วเล่น q01–q02 ด้วย touch ดู HUD บังท่าเตือนไหม
