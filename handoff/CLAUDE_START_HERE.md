# Claude handoff — สถานะล่าสุด 27 ต.ค. 2026

Codex รัน P1-E, iPhone XR simulator และ 2 clients แล้ว อ่าน docs/qa/P1E_CODEX_REVIEW.md ก่อน ห้ามย้อน jitter credit ที่มีเพดาน, touch layout 2×2 หรือ SpiritWardRemotes

งานถัดไปพร้อมส่ง: ทำ VB-01 ตาม docs/VISUAL_BENCHMARK_BRIEF.md โดยคง gameplay/collision/IDs และส่ง diff + วิธีเปิด + สิ่งที่ทดสอบจริง ใช้งาน Claude เป็นผู้เขียนหลักเพื่อประหยัด Codex usage ไม่มีการ dispatch อัตโนมัติ

---
ข้อความด้านล่างเป็นประวัติใบงานก่อนหน้า ห้ามทำซ้ำโดยไม่ดูสถานะล่าสุด

# Claude — เริ่ม P1 playable prototype

สถานะล่าสุด: Claude ส่ง P1-A/B/C และชุดทดสอบ D แล้ว Codex รัน Play Solo subset และแก้ remotes แล้ว อ่าน `docs/qa/P1D_CODEX_REVIEW.md` ข้อความเริ่มงานเดิมเก็บเป็นประวัติ ห้ามสร้าง P1 ใหม่ทับของเดิม

## ข้อความส่งต่อรอบปัจจุบัน

```text
อ่าน docs/qa/P1D_CODEX_REVIEW.md, docs/qa/P1_RESULTS.md และ evidence/P1D_RUNTIME.json
Codex รัน Play Solo ผ่านบางส่วนจริงแล้ว อย่าย้อนทุกข้อเป็น unverified
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
ถ้า Claude เข้า Studio ไม่ได้ ให้ส่ง source/test setup และระบุ unverified ให้ Codex รันต่อ
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
Codex เป็น Designer/Technical Lead ตรวจและรวมงาน ผู้ใช้เป็น Director
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

หลัง Claude ส่ง batch แจ้ง Codex ว่า “Claude ทำ P1-A เสร็จแล้ว ตรวจไฟล์ได้”
ถ้าใช้งานคนละเครื่องให้นำ patch/ไฟล์ตาม ownership กลับมาด้วย
