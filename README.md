# Project Spirit Ward — หมู่บ้านม่านวิญญาณ

ชื่อทำงานสำหรับเกม Roblox แนวนักปราบโยไค ธีมญี่ปุ่นแฟนตาซี มุมมอง 3D บุคคลที่สาม ได้แรงบันดาลใจด้านจังหวะเล่นและการเติบโตจาก Ghost Online ใช้โลก ตัวละคร ภาพ เสียง และวิชาที่สร้างขึ้นใหม่

สถานะ: **วางแผนและสร้างโครงโปรเจกต์** วันที่ 27 ตุลาคม 2026 ยังไม่มี gameplay ที่เล่นได้ ยังไม่ได้เชื่อมเข้า Studio หรือทดสอบในเกม

## เริ่มอ่าน

1. [Game Design Document](docs/GAME_DESIGN.md) — เกมคืออะไร เล่นอย่างไร และขอบเขตแต่ละระยะ
2. [Technical Architecture](docs/TECHNICAL_ARCHITECTURE.md) — โครง Roblox และความรับผิดชอบแต่ละระบบ
3. [Contracts](docs/CONTRACTS.md) — รูปข้อมูลและข้อตกลงที่ Codex กับ Claude ใช้ร่วมกัน
4. [Production Plan](docs/PRODUCTION_PLAN.md) — ลำดับงาน ผู้รับผิดชอบ และเกณฑ์ส่งมอบ
5. [Claude handoff](handoff/CLAUDE_START_HERE.md) — ข้อความพร้อมส่งให้ Claude
6. [Acceptance checklist](docs/ACCEPTANCE.md) — วิธีตรวจงานก่อนถือว่าเสร็จ
7. [Decision log](docs/DECISIONS.md) — สมมติฐานและเรื่องที่รอผู้ใช้เลือก
8. [Japanese Theme Direction](docs/ART_DIRECTION.md) — ธีมโลก ตัวละคร ฉาก และแนวทางผลิต asset
9. [Playable Prototype Brief](docs/PROTOTYPE_BRIEF.md) — ใบงาน P1 ที่ Claude เริ่มเขียนโค้ดได้ทันที

## โครงไฟล์

```text
docs/                 เอกสารออกแบบ สถาปัตยกรรม และแผนผลิต
  content/            คอนเทนต์ที่ Claude จะออกแบบ
  ui/                 UX และ UI ที่ Claude จะออกแบบ
  qa/                 กรณีทดสอบที่ Claude จะออกแบบ
handoff/              ชุดส่งต่องานและรายงานผล
src/
  shared/             ข้อมูลและชนิดข้อมูลที่ทั้งสองฝั่งใช้
  server/             ระบบที่เซิร์ฟเวอร์เป็นผู้ตัดสิน
    Services/
  client/             กล้อง อินพุต UI และเอฟเฟกต์
    Controllers/
assets/               รายการและข้อกำหนด asset
default.project.json  แผนผัง sync ด้วย Rojo แบบเลือกใช้
AGENTS.md             กติกาสำหรับ Codex และ agent อื่น
CLAUDE.md             จุดเริ่มสำหรับ Claude
work/                 งานเดิมของผู้ใช้ ไม่อยู่ในขอบเขต scaffold
```

## ใช้กับ Roblox Studio

โค้ดต้นฉบับอยู่ใน `src/`; `default.project.json` กำหนดตำแหน่งใน DataModel สำหรับ Rojo หากเลือกใช้ ยังไม่ได้ติดตั้งหรือรัน Rojo ในรอบนี้

- `src/shared` → `ReplicatedStorage/Shared`
- `src/server` → `ServerScriptService/Server`
- `src/client` → `StarterPlayer/StarterPlayerScripts/Client`
- แผนที่และโมเดลสร้างใน Studio; ลงทะเบียน asset ใน `assets/ASSET_MANIFEST.md`
- ก่อนเริ่ม implementation เลือกวิธี sync เพียงวิธีเดียวและบันทึกใน decision log ห้ามให้ Studio และไฟล์ local แข่งกันเขียนสคริปต์เดียวกัน
- สคริปต์ bootstrap ปัจจุบันเพียงแสดงข้อความ ไม่ได้โหลด Services หรือ Controllers โดยอัตโนมัติ

การเริ่มเกมจริงต้องผ่าน M0 ใน production plan ก่อน ไม่ publish อัตโนมัติจาก scaffold นี้
