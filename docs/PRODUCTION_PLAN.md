# Production Plan — Claude + Director v0.4

28 ตุลาคม 2026: ทีมเหลือ Claude กับ Director (DEC-015) ตารางงาน P1 ด้านล่างเป็นประวัติ ผลล่าสุดของ M2/M3 อยู่ใน `docs/qa/M2G_ACCEPTANCE.md` และ `docs/qa/M3D_ACCEPTANCE.md`

วันที่ 27 ตุลาคม 2026 สถานะตอนนั้น: P1-E local review, iPhone XR simulator และ 2 clients รันแล้ว ดู [P1-E Review](qa/P1E_CODEX_REVIEW.md) พร้อมเดินหน้าภาพตัวอย่างตาม [VB-01](VISUAL_BENCHMARK_BRIEF.md); real mobile/latency/public hardening ยังเป็น backlog

## บทบาท

- ผู้ใช้: Game Director กำหนดภาพเกม ทดลองเล่น และตัดสินใจประสบการณ์
- Claude: Lead Programmer + Technical Lead รับ implementation ทั้ง client/server, UI, gameplay, setup, รายงานทดสอบ และดูแลสเปก architecture/contracts, review และ integration

แผนฉบับนี้แทน task board CL-01 ถึง CL-06 และ CD-01 ถึง CD-05 รุ่นก่อน งาน catalog ทั้งเกมพักไว้จน prototype สนุกและเล่นได้

## เจ้าของไฟล์ระหว่าง P1

| พื้นที่ | เจ้าของ |
|---|---|
| docs/GAME_DESIGN.md, TECHNICAL_ARCHITECTURE.md, CONTRACTS.md, DECISIONS.md, PROTOTYPE_BRIEF.md | Claude; เปลี่ยน decision หรือเกณฑ์ acceptance ต้องถาม Director ก่อน |
| src/server/**, src/client/** | Claude |
| src/shared/Definitions/Prototype.luau, src/shared/Types/** | Claude ตาม contract |
| src/shared/Definitions/Project.luau | Claude |
| default.project.json, tools/** | Claude สำหรับ setup/sync โดยรักษางานผู้ใช้ |
| docs/content/**, docs/ui/**, docs/qa/** | Claude ภายใน scope P1 |
| assets/ASSET_MANIFEST.md | Claude |
| handoff/CLAUDE_DELIVERY.md, handoff/P1_CONTRACT_PROPOSALS.md | Claude |
| work/** | งานผู้ใช้ ไม่แก้ใน P1 |

## ชุดงานแรก

อ่านรายละเอียดใน [Prototype Brief](PROTOTYPE_BRIEF.md) เป็นใบงานหลัก ส่งเป็น batch เพื่อให้ตรวจและแก้ได้ก่อนสะสมงานต่อ

| ID | เจ้าของ | งาน | Dependency | สถานะ |
|---|---|---|---|---|
| P1-A | Claude; ผู้ตรวจ review | sync, greybox, types, camera/movement desktop/touch | baseline v0.3; เลือก sync จากเครื่องมือที่มี | desktop และ Director ภาพรวมผ่าน; iPhone XR simulator ผ่านตามขอบเขตรายงาน |
| P1-B | Claude; ผู้ตรวจ review | authoritative combat/enemy และ client feedback | P1-A runtime verified | local combat/network และ movement sampling ทดสอบแล้ว; hardening ตามข้อจำกัดใน P1-E |
| P1-C | Claude; ผู้ตรวจ review | soul/transform/HUD | P1-B runtime verified | reward/transform/expiry/death tested; full natural progression ยังไม่ตรวจ |
| P1-D | Claude + ผู้ตรวจ | multiplayer/touch integration และรายงาน | P1-C | Play Solo, iPhone XR simulator และ 2 clients ผ่านตามขอบเขต P1-E |
| REVIEW-P1 | ผู้ตรวจ (ก่อน DEC-015) | review diffs/contracts, รับผลทดสอบ และสรุปให้ Director | ส่งแต่ละ batch | P1-E review พร้อม jitter-credit/mobile-layout fixes ส่งแล้ว |
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

หลาย session ของ Claude ใช้ workspace เดียวกันได้เมื่อไม่แก้ไฟล์เดียวกันพร้อมกัน ห้ามสลับ branch ที่อีก session ใช้อยู่ ถ้าแยก clone/worktree ให้ส่ง patch/branch ไม่ส่งโฟลเดอร์ทับทั้งชุด

session ใหม่เริ่มที่ handoff/CLAUDE_START_HERE.md ผลแต่ละ batch บันทึกใน docs/qa/ เพื่อให้ Director และ session ถัดไปอ่านได้โดยไม่ต้องย้อนประวัติแชต

ทุก batch ระบุ changed files, implemented behavior, exact run steps, environment, tested/unverified, known issues และภาพ/วิดีโอเมื่อจับได้จริง ไม่ต้องสร้างเอกสารยาวแทนโค้ดที่ได้รับมอบหมาย

## คิวถัดไป

M3 persistence ผ่านข้อที่ Claude ทดสอบได้ (`docs/qa/M3D_ACCEPTANCE.md`) ที่เหลือต้องใช้ Director: touch บนมือถือจริง, perf 12 คนบน server จริง และบอสหลายคนจนล้มเพื่อตรวจการจ่ายรางวัล (`docs/qa/M2G_ACCEPTANCE.md` ข้อ 5–6) · งานถัดไป Director เลือก

แนวทางประหยัด usage: ทดสอบซ้ำเฉพาะเมื่อมีการเปลี่ยน/บั๊ก/ข้อกังวลจริง หลีกเลี่ยงการอ่านทั้งโปรเจกต์ซ้ำ
