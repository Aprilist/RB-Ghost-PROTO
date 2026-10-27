# Production Plan — Codex + Claude v0.3

วันที่ 27 ตุลาคม 2026 สถานะล่าสุด: P1-E local review, iPhone XR simulator และ 2 clients รันแล้ว ดู [P1-E Review](qa/P1E_CODEX_REVIEW.md) พร้อมเดินหน้าภาพตัวอย่างตาม [VB-01](VISUAL_BENCHMARK_BRIEF.md); real mobile/latency/public hardening ยังเป็น backlog

## บทบาท

- ผู้ใช้: Game Director กำหนดภาพเกม ทดลองเล่น และตัดสินใจประสบการณ์
- Codex: Game Designer + Technical Lead ออกสเปก ตรวจ architecture/contracts ตรวจโค้ด รวมงาน และตีความ feedback
- Claude: Lead Programmer รับ implementation ทั้ง client/server พร้อม UI, gameplay, setup และรายงานทดสอบ

แนวทางคือให้ Claude รับงานโค้ดส่วนใหญ่ประมาณ 80% โดยไม่ใช้สัดส่วนนี้เป็นการรับรองราคา usage หรือเวลาเสร็จ Codex ไม่แก้โค้ดใน batch ที่ Claude กำลังทำพร้อมกัน

แผนฉบับนี้แทน task board CL-01 ถึง CL-06 และ CD-01 ถึง CD-05 รุ่นก่อน งาน catalog ทั้งเกมพักไว้จน prototype สนุกและเล่นได้

## เจ้าของไฟล์ระหว่าง P1

| พื้นที่ | เจ้าของ |
|---|---|
| docs/GAME_DESIGN.md, TECHNICAL_ARCHITECTURE.md, CONTRACTS.md, DECISIONS.md, PROTOTYPE_BRIEF.md | Codex; Claude เสนอการเปลี่ยนแยก |
| src/server/**, src/client/** | Claude implementation; Codex review หลังส่ง batch |
| src/shared/Definitions/Prototype.luau, src/shared/Types/** | Claude ตาม contract |
| src/shared/Definitions/Project.luau | Codex; Claude เสนอ diff หากจำเป็น |
| default.project.json, tools/** | Claude สำหรับ setup/sync โดยรักษางานผู้ใช้ |
| docs/content/**, docs/ui/**, docs/qa/** | Claude ภายใน scope P1 |
| assets/ASSET_MANIFEST.md | Claude ลงทะเบียน placeholder; Codex review |
| handoff/CLAUDE_DELIVERY.md, handoff/P1_CONTRACT_PROPOSALS.md | Claude |
| work/** | งานผู้ใช้ ไม่แก้ใน P1 |

## ชุดงานแรก

อ่านรายละเอียดใน [Prototype Brief](PROTOTYPE_BRIEF.md) เป็นใบงานหลัก ส่งเป็น batch เพื่อให้ตรวจและแก้ได้ก่อนสะสมงานต่อ

| ID | เจ้าของ | งาน | Dependency | สถานะ |
|---|---|---|---|---|
| P1-A | Claude; Codex review | sync, greybox, types, camera/movement desktop/touch | baseline v0.3; เลือก sync จากเครื่องมือที่มี | desktop และ Director ภาพรวมผ่าน; iPhone XR simulator ผ่านตามขอบเขตรายงาน |
| P1-B | Claude; Codex review | authoritative combat/enemy และ client feedback | P1-A runtime verified | local combat/network และ movement sampling ทดสอบแล้ว; hardening ตามข้อจำกัดใน P1-E |
| P1-C | Claude; Codex review | soul/transform/HUD | P1-B runtime verified | reward/transform/expiry/death tested; full natural progression ยังไม่ตรวจ |
| P1-D | Claude + Codex | multiplayer/touch integration และรายงาน | P1-C | Play Solo, iPhone XR simulator และ 2 clients ผ่านตามขอบเขต P1-E |
| REVIEW-P1 | Codex | review diffs/contracts, รับผลทดสอบ และสรุปให้ Director | ส่งแต่ละ batch | P1-E review พร้อม jitter-credit/mobile-layout fixes ส่งแล้ว |
| PLAY-P1 | ผู้ใช้ | ลองกล้อง/เดิน/ฟันจริง/แปลงร่าง | P1 loop เล่นได้ | ทดลองแล้วรายงานว่าปกติดี 27 ต.ค. 2026; ไม่ใช่ checklist sign-off ทุกข้อ |

Claude ไม่ต้องหยุดขออนุญาตในแต่ละ routine step แต่ต้องไม่อ้างว่า gate ผ่านถ้าไม่ได้ทดสอบจริง ถ้า Studio ไม่พร้อมให้ทำ source/setup ที่ไม่พึ่ง gate ต่อได้พร้อมระบุ unverified ไม่สร้างระบบใหม่เพิ่มเพื่อหลบ blocker

## Milestones ถัดไป

| Gate | ผลส่งมอบ | เงื่อนไข |
|---|---|---|
| P1 prototype | 1 class, 1 enemy type, movement/combat/soul/transform | Director ทดลองและเห็น core loop |
| Visual benchmark | ลานมุมหนึ่ง ตัวละคร/ศัตรู/transform อย่างละหนึ่ง | จังหวะต่อสู้และกล้องนิ่งแล้ว |
| M2 vertical slice | hub 1, zones 2, enemies 4, boss 1, quests 5, seals 2 | ใช้ P1 เป็นฐานและผ่าน review |
| M3 persistence/hardening | save/load, session ownership, failure UX | ผ่าน reconnect/duplicate/stale-session tests |
| M4 closed alpha | 3 classes, tutorial iteration, playtest | Director รับรองสำหรับวงทดสอบ |

P1 ไม่มี DataStore, trading, monetization หรือ publish ใช้ memory state และแสดงว่า progress reset ห้ามใช้ prototype adapter แล้วอ้างว่าผ่าน acceptance ของ persistence

## ทำงานร่วมกัน

ใช้ workspace เดียวกันได้เมื่อไม่แก้ไฟล์เดียวกันพร้อมกัน ห้ามสลับ branch ที่อีกฝ่ายใช้อยู่ ถ้าแยก clone/worktree ให้ส่ง patch/branch ไม่ส่งโฟลเดอร์ทับทั้งชุด

ส่ง Claude ด้วย handoff/CLAUDE_START_HERE.md เมื่อมีผลให้บอก Codex ว่า batch ใดเสร็จ Codex อ่านไฟล์และตรวจได้โดยไม่ต้องส่งประวัติแชตทั้งหมด แต่ต้องแจ้งหากผลอยู่คนละเครื่อง

ทุก batch ระบุ changed files, implemented behavior, exact run steps, environment, tested/unverified, known issues และภาพ/วิดีโอเมื่อจับได้จริง ไม่ต้องสร้างเอกสารยาวแทนโค้ดที่ได้รับมอบหมาย

## คิวถัดไป

VB-01: Claude ทำลานศาลเจ้าญี่ปุ่นตัวอย่างตาม docs/VISUAL_BENCHMARK_BRIEF.md สถานะพร้อมส่ง ยังไม่ได้เริ่ม Codex ตรวจเฉพาะ diff และภาพหลักก่อนทดสอบเฉพาะจุดที่เปลี่ยน

แนวทางประหยัด usage ตามคำถามผู้ใช้: Claude รับ implementation/test setup ส่วนใหญ่ Codex อ่านเฉพาะ diff กับรายงาน หลีกเลี่ยง reread ทั้งโปรเจกต์และ UI sessions ยาว ทดสอบซ้ำเฉพาะเมื่อมีการเปลี่ยน/บั๊ก/ข้อกังวลจริง
