# M2-A Foundation — ผลทดสอบและรายการให้ Director ลอง

ร่างโดย Claude 27 ต.ค. 2026 | สถานะ: **ผ่าน — Director กด Play แล้วตอบ "ผ่านครับ" (27 ต.ค. 2026)**

## สิ่งที่ทำใน batch นี้

| ส่วน | สรุป |
|---|---|
| Catalog | `Definitions/` เพิ่ม Enemies, Items, Skills, Seals, Zones, Quests, Progression; ค่า lantern_wisp / training_blade / blade_basic / blade_sweep / guardian_wave เท่า P1 ทุกตัว; ศัตรูใหม่ 3 ตัว, เควสต์ 5 อัน, ผนึก 2 แบบ, โซนจริง 3 โซน ติดป้าย `draft = true` |
| Prototype.luau | key เดิมทั้งหมด แต่ค่าต่อสู้/ศัตรู/รางวัลอ่านจาก catalog (ดาเมจ = baseDamage × damageMultiplier: 20 / 30 / 25) |
| Profile | `ProfileService` เก็บ ProfileV1 ใน memory (ป้าย `Mode = "memory"`, warn ใน Output) ทุกการเปลี่ยนผ่าน `Mutate`: เพิ่ม revision, ตรวจ `ProfileRules.Validate`, ค่าผิดกฎถูก rollback, ไม่ re-entrant |
| Reward | `RewardService` ย้ายมาจาก SpiritService: ledger enemyRuntimeId + userId เดิม, ต้อง alive + ภายใน 120 studs + อยู่ zone เดียวกับศัตรู + zone นั้นให้รางวัล; ให้ EXP / เหรียญ / แก่นวิญญาณ (profile) และเกจ (session, ไม่เพิ่มตอนแปลงร่าง) |
| Level | cap 5 (Director 27 ต.ค.), EXP ต่อเลเวล 30 / 60 / 100 / 150, HP สูงสุด 100 / 110 / 120 / 130 / 140; เลเวลอัปเพิ่ม HP ปัจจุบันเท่าส่วนที่เพิ่ม; ที่ cap xp = 0 |
| Zone | `ZoneService` สร้างกล่องโปร่งใส ไม่ชน/ไม่ query/ไม่ touch ใน `SpiritWardPrototype/Zones` (tag `Zone`, attribute `ZoneId`) ครอบลาน 100×100 เป็น `p1_arena`; ไม่แตะ Collision / Markers |
| HUD | แถวบน `Lv N` + แถบ EXP (หรือ `EXP MAX`), แถวเงิน: แก่นวิญญาณ + เหรียญ (แสดงอย่างเดียว ตาม Director); ข้อมูลจาก snapshot เท่านั้น |
| FX | `level_up`: วงทองสองชั้น + เสาแสง และข้อความ "เลเวลอัป!" เฉพาะเจ้าของ |
| Bug fix | VB-01 batch 2 ลบฟังก์ชัน `clearAura` ใน SpiritService โดยไม่ตั้งใจ ทำให้ error ตอนหมดเวลาแปลงร่างและตอนตาย (ออร่า/หน้ากากค้าง) แก้คืนแล้ว และเพิ่มการตรวจ global ที่ไม่ได้ประกาศในขั้นตอนตรวจของ Claude |

## ผลทดสอบนอก Studio (Claude, 27 ต.ค. 2026)

- `luau-compile` ผ่านทุกไฟล์ใน `src/`; ทุกไฟล์มี `--!strict`
- ตรวจ global ที่ไม่ได้ประกาศด้วย `luau-ast`: ไม่พบ (ก่อนแก้พบ `clearAura` ใน SpiritService)
- mock headless (Roblox API จำลอง):
  - MovementRulesTest 15/15, SceneLayoutTest 7/7, CatalogTest 7/7, ProfileRulesTest 10/10, RewardRulesTest 8/8
  - mutation check: เปลี่ยน maxHp ผี 60→61, ปิดการตั้ง xp = 0 ที่ cap, ปิดการเช็คระยะรางวัล → test ที่ตรงกันล้มทั้ง 3
  - integration (Profile + PlayerState + Spirit + Reward + Zone จริง, network/enemy จำลอง):

| ขั้น | ผล |
|---|---|
| เริ่ม | Lv1, EXP 0/30, HP 100/100 |
| โดนตี 25 แล้วฆ่า 3 ตัว | Lv2, EXP 0/60, HP 85/110 (Humanoid ตามด้วย), เหรียญ 6, แก่น 15, เกจ 30; FX soul_orb ×3 + level_up ×1 |
| ส่ง defeat ซ้ำ ID เดิม | ไม่ได้รางวัล ไม่มี snapshot ใหม่ |
| ผู้เล่นอยู่นอก zone / contributor ไม่ใช่ผู้เล่น / ผู้เล่นตาย | ไม่ได้รางวัล |
| ฆ่าครบ 10 ตัว → แปลงร่าง | `OK`, มีออร่า + หน้ากาก; ฆ่าระหว่างแปลงร่างได้ EXP/เหรียญ แต่เกจไม่เพิ่ม |
| ตายระหว่างแปลงร่าง | ออร่าและหน้ากากถูกลบ ไม่มี error |
| ฆ่ารวมจนถึง cap | Lv5, EXP 0 (xpToNext = nil), HP 140/140, level_up รวม 4 ครั้ง |

**ยังไม่ได้ตรวจ:** strict type-check (luau-lsp ใช้ในเครื่องนี้ไม่ได้), 2 clients, มือถือ, หน้าตา HUD ที่ความละเอียดต่าง ๆ (Studio ผ่านตาม Director ด้านล่าง; Director ตอบรวมคำเดียว ไม่ได้แยกรายข้อ)

## Director ลองใน Studio (ประมาณ 5 นาที)

| # | ทำ | ควรเห็น | ผล |
|---|---|---|---|
| M1 | กด Play ดู Output | `[MovementRulesTest] 15 passed, 0 failed`, `[SceneLayoutTest] 7 passed`, `[CatalogTest] 7 passed`, `[ProfileRulesTest] 10 passed`, `[RewardRulesTest] 8 passed`, warn `memory mode` 1 บรรทัด, ไม่มี error สีแดง | ผ่าน (Director 27 ต.ค.) |
| M2 | เล่น loop เดิม: ฟัน, E, Q, ฆ่าผี | ดาเมจ/ระยะ/ความเร็วเหมือนเดิม ผี 60 HP ตายด้วยฟันปกติ 3 ครั้ง, orb ลอยเข้าตัว เกจ +10 | ผ่าน (Director 27 ต.ค.) |
| M3 | ดู HUD มุมซ้ายบน | `Lv 1` + แถบ EXP 0/30, แถว แก่นวิญญาณ / เหรียญ ไม่ทับกัน ไม่บังปุ่มมือถือ | ผ่าน (Director 27 ต.ค.) |
| M4 | ฆ่าผี 3 ตัว | ตัวละ EXP +10 เหรียญ +2 แก่น +5; ตัวที่ 3 เลเวลอัป: วงทอง + "เลเวลอัป!", `Lv 2`, HP สูงสุด 110 | ผ่าน (Director 27 ต.ค.) |
| M5 | แปลงร่าง (เกจเต็ม กด R) ปล่อยให้หมดเวลา และอีกรอบให้ตายระหว่างแปลงร่าง | ออร่า + หน้ากากหายทั้งสองกรณี ไม่มี error ใน Output | ผ่าน (Director 27 ต.ค.) |
| M6 | (เลือกทำ) ฆ่าต่อถึง Lv5 (~34 ตัว) | `EXP MAX`, HP 140, EXP ไม่เพิ่มต่อ | ข้อเลือก ไม่ได้ยืนยันแยก |

## ข้อเสนอ/สมมติฐานที่ต้องให้ Codex รับ

- `PublicOwnProfile` ใน `Types/Contracts.luau` ตอนนี้เป็น `classId, level, xp, xpToNext?, coins, essence` (เพิ่มอย่างเดียว ไม่ลบ field เดิม) ยังไม่ส่ง `equippedWeaponId` / `quests` จนกว่า M2-D/M2-E จะใช้
- schema ใหม่ Progression / Zone (เพิ่ม `volumes`) / Item / Seal และ field เสริม `tuning`, `draft` ของ Enemy และ `arcDeg` ของ Skill ตาม `handoff/M2_PLAN_PROPOSAL.md`
- effect ใหม่ใน combat_fx: `level_up` (เป็นภาพเท่านั้น)
- โซนยังไม่บันทึก `checkpointId` ลง profile ตอนเดินเข้า (ยังมี zone เดียว); จะต่อใน M2-B
- ยังไม่แยก adapter load/save ตาม 4.2 ของแผน: memory mode เป็น service เดียวไปก่อน จะแยกเมื่อเริ่ม persistence (M3) หรือ DEC-008
