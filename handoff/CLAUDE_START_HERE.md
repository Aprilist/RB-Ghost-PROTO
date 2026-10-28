# Claude handoff — สถานะล่าสุด 28 ต.ค. 2026

ทีมคือ Claude + Director (DEC-015) Claude ดูแลทั้ง implementation, spec, contracts, review และ integration

ทำแล้วถึง M4-E (branch `m2d-quests-npcs`, commit ล่าสุด M4-E):

- M3 persistence: ผลอยู่ใน `docs/qa/M3D_ACCEPTANCE.md` และ `docs/qa/M2G_ACCEPTANCE.md` ส่วนที่เหลือต้องใช้ Director (มือถือจริง, 12 คนบน server จริง, บอสหลายคนจนล้ม)
- M4 อาชีพ + สกิล (สเปกใน `docs/GAME_DESIGN.md` หัวข้อ "ระบบสกิล"):
  - สามอาชีพ ซามูไร/นินจา/องเมียวจิ (id blade/shade/talisman) เลือกครั้งเดียวตอนเข้าเกมครั้งแรก เปลี่ยนไม่ได้ เลเวลตัน 20 ได้ 2 แต้มสกิลต่อเลเวล (profile schema v2)
  - อาชีพละ 5 สกิลบนแถบปุ่ม 1–5 ใช้ SP มีระดับ 1–5 หน้าต่างสกิลกด K
  - อาชีพละ 2 สกิลติดตัว (passive) เพิ่มดาเมจ/HP/SP
  - เขตยันต์ตรึงศัตรูทั่วไปได้จริง 2.5 วิ บอสไม่ติด
- test ใน Studio ผ่าน 162/162 (รันเองตอน Play ดูใน Output)

ต่อบนเครื่องใหม่:

1. `git pull` branch `m2d-quests-npcs`
2. `.mcp.json` อยู่ใน repo แล้ว ใช้ Roblox Studio MCP ที่ `%LOCALAPPDATA%\Roblox\mcp.bat` ต้องเปิด Studio และเปิดปลั๊กอิน MCP ของ Studio ก่อน
3. เปิด place `SpiritWard Test` (134965985305218) จาก Roblox ใน Studio (ไฟล์ place ไม่อยู่ใน git)
4. ไม่มี Rojo: รัน `python tools/studio_sync_server.py` ไว้ แล้วสั่ง body ของ `tools/studio_sync.luau` ใน Edit datamodel ผ่าน MCP โค้ดใน Studio จะตรงกับ repo (เปิด HttpEnabled เฉพาะตอนดึง แล้วคืนค่าทันที ตาม Director)
5. ถ้า sync แจ้งว่ามีสคริปต์ชื่อซ้ำ ให้ลบตัวเก่าใน Studio ก่อน (เคยเกิดกับ Classes/ClassService)

งานค้าง (ถาม Director ก่อนเลือก):

- เขตยันต์วางวงไกล 14 studs รัศมี 8 จึงไม่โดนศัตรูที่อยู่ชิดตัว (ใกล้กว่าราว 6 studs) ควรปรับ
- เติมสกิลให้ครบ 8–10 ตัวต่ออาชีพ, การกระเด็น, ผูกปุ่มเอง, อาชีพขั้นสอง, ภาพ/ท่าของแต่ละอาชีพ
- ปรับสมดุล SP: สกิลถูก ๆ อย่างคุไนเงาใช้ได้ไม่จำกัด
- หน้าต่างสกิล 7 แถวอาจล้นจอมือถือ (จัด HUD ทีหลังตาม Director)
- ยังไม่ได้กดคีย์ 1–5/K จริงและดูเอฟเฟกต์บนจอด้วยตา (เทสผ่าน remote ตรง)

เซฟเทสของ Director (u_1985961773 ใน store dev) เป็นนินจา Lv3 คุไนระดับ 2 แต้มเหลือ 2 ถ้าต้องเปลี่ยนเพื่อเทส ให้สำรองก่อนและคืนให้ตรงเดิม

place ทดสอบ DataStore: `SpiritWard Test` (134965985305218, private) store `SpiritWardProfile_dev` · ห้ามย้อน jitter credit ที่มีเพดาน, touch layout 2×2 หรือ SpiritWardRemotes (DEC-012 ถึง DEC-014)

---
ข้อความด้านล่างเป็นประวัติใบงานก่อนหน้า ห้ามทำซ้ำโดยไม่ดูสถานะล่าสุด

# Claude — เริ่ม P1 playable prototype

สถานะล่าสุด: Claude ส่ง P1-A/B/C และชุดทดสอบ D แล้ว ผู้ตรวจรอบนั้นรัน Play Solo subset และแก้ remotes แล้ว อ่าน `docs/qa/P1D_CODEX_REVIEW.md` ข้อความเริ่มงานเดิมเก็บเป็นประวัติ ห้ามสร้าง P1 ใหม่ทับของเดิม

## ข้อความส่งต่อรอบปัจจุบัน

```text
อ่าน docs/qa/P1D_CODEX_REVIEW.md, docs/qa/P1_RESULTS.md และ evidence/P1D_RUNTIME.json
ผู้ตรวจรัน Play Solo ผ่านบางส่วนจริงแล้ว อย่าย้อนทุกข้อเป็น unverified
Director ทดลองแล้วแจ้งว่า “ผมเทสแล้วปกติดี” วันที่ 27 ต.ค. 2026
เดินหน้างานเทคนิคด้านล่างได้ ไม่ต้องรอถาม Director ซ้ำ
ผลนี้ไม่ใช่การยืนยันว่าทดสอบมือถือหรือ 2 clients แล้ว
รักษา remote fix: SpiritWardRemotes + OwnedBy=SpiritWard และ reuse/preserve เดิม

งาน implementation ถัดไป: ปิดช่องว่าง dash movement authority ตาม architecture
ปัจจุบัน server คิด clear distance แต่ใช้แค่ FX ส่วน client ขยับด้วย LinearVelocity
ให้ server บังคับระยะ/เส้นทาง/เวลา และ reconcile การเคลื่อนที่ที่ถูกปฏิเสธจริง
ห้ามแก้เพียง client หรือใช้ collision ของ client เป็นหลักฐานว่า server enforce แล้ว
ถ้าจำเป็นต้องเพิ่ม field ใน ActionResult/combat_fx ให้เสนอ schema ก่อนแก้ contract
เขียน negative tests สำหรับ client เคลื่อนเกินระยะ/ผิด cooldown/ผ่านกำแพง

ต่อด้วย mobile layout/gesture และ 2-client validation ตามตารางเดิม
ถ้า Claude เข้า Studio ไม่ได้ ให้ส่ง source/test setup และระบุ unverified จนกว่าจะรันได้
อย่าใช้ mock player แทน 2 clients หรืออ้างภาพผ่านจาก MCP capture ที่ไม่แสดง world
ไม่เพิ่มระบบใหม่ ไม่ publish ปิด P1 เมื่อ dash validation และผลทดสอบที่เหลือครบ
Director feedback ภาพรวมรับแล้ว หากแก้พฤติกรรมจนต่างจากเดิมค่อยขอให้ลองเฉพาะส่วนที่เปลี่ยน
```

## ข้อความเริ่มงานเดิม (อ้างอิงเท่านั้น)

เปิด Claude Code ในโฟลเดอร์ C:\Users\shint\Documents\ChatGPT\Roblox Game แล้ววางข้อความนี้:

```text
เริ่มทำ P1 playable prototype ของ Project Spirit Ward ใน repository นี้

อ่าน AGENTS.md, CLAUDE.md, README.md และเอกสารต่อไปนี้:
- docs/PROTOTYPE_BRIEF.md เป็นใบงานหลัก
- docs/PRODUCTION_PLAN.md ฉบับ v0.3 เป็น ownership/task board ปัจจุบัน
- docs/GAME_DESIGN.md, docs/ART_DIRECTION.md
- docs/TECHNICAL_ARCHITECTURE.md, docs/CONTRACTS.md, docs/DECISIONS.md

คุณเป็น Lead Programmer ทำ implementation ทั้ง client/server ตาม scope P1
มีผู้ตรวจแยกเป็น Designer/Technical Lead (ก่อน DEC-015) ผู้ใช้เป็น Director
กล้องยืนยันแล้ว: 3D บุคคลที่สาม ธีมญี่ปุ่นแฟนตาซี

ลงมือสร้างโค้ดจริง ไม่ตอบเพียงแผน เริ่ม P1-A แล้วเดินหน้า P1-B/C/D ตาม gate
ส่งเป็น batch ที่ตรวจได้ หากรัน Studio ไม่ได้ระบุ unverified และ blocker จริง
สามารถทำ source/setup ส่วนอิสระต่อได้โดยไม่อ้างว่าผ่าน runtime gate

เป้าหมาย: ลาน styled greybox หนึ่งแห่ง นักดาบคาตานะ ผีโคมหนึ่งชนิด
เดิน กระโดด พุ่ง ฟัน ดูดวิญญาณ แปลงร่าง HUD และ desktop/touch
ใช้ไฟ/สี/โทริอิชิ้นส่วนพื้นฐานสื่อญี่ปุ่น ไม่ผลิตโมเดลรายละเอียดสูงตอนนี้

รายละเอียดและตัวเลขตาม PROTOTYPE_BRIEF.md
- server ตัดสิน damage/reward/gauge ใช้ remotes และ directions ตาม contracts
- orb เป็นภาพของ reward ห้าม client ขอ grant ซ้ำ
- memory state เท่านั้น ติดป้าย progress resets ไม่มี DataStore ใน P1
- สร้าง src/shared/Definitions/Prototype.luau และ types ตาม ownership ได้
- เรื่อง apply_seal/persistence ใน contract ยังไม่อยู่ P1 จึงไม่ต้องรอ
- สร้างสนามใน namespace SpiritWardPrototype แบบทำซ้ำได้
- ห้ามล้าง Workspace หรือแตะ work/ ห้าม publish
- ตรวจเครื่องมือ sync ที่มี แล้วเลือกเพียงวิธีเดียว บันทึก setup และเสนอ DEC-002
- ถ้าจำเป็นต้องเปลี่ยน contract ให้เขียน handoff/P1_CONTRACT_PROPOSALS.md
  ไม่เปลี่ยน contract/Project.luau เงียบ ๆ

ส่ง docs/qa/P1_RESULTS.md และ handoff/CLAUDE_DELIVERY.md
ระบุ changed files, วิธีเปิดเล่น, tests ที่รันจริง, tests ที่ยังไม่ได้รัน และ known issues
อย่าอ้างว่าผ่าน multiplayer/touch/Studio หากไม่ได้ทดสอบจริง
```

หลังส่ง batch บันทึกผลใน docs/qa/ ให้ Director อ่าน
ถ้าใช้งานคนละเครื่องให้นำ patch/ไฟล์ตาม ownership กลับมาด้วย
