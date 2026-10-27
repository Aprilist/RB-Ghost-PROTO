# M2 Vertical Slice — ข้อเสนอแผนและใบงานชุดแรก

ร่างโดย Claude 27 ต.ค. 2026 | สถานะ: **ข้อเสนอ รอ Director ดูและ Codex รับเข้า contracts** | อ้างอิง GAME_DESIGN v0.2, PRODUCTION_PLAN v0.3, CONTRACTS v0.2, ACCEPTANCE (M2)

ไฟล์นี้เป็นข้อเสนอของ Claude ไม่แก้เอกสารที่ Codex เป็นเจ้าของ (GAME_DESIGN, CONTRACTS, DECISIONS, PRODUCTION_PLAN) จุดที่ต้องเปลี่ยน contract ระบุไว้ท้ายไฟล์

## 1. เป้าหมาย M2

ผู้เล่นใหม่เข้าเกม → รับเควสต์ที่หมู่บ้าน → ผ่านป่าม่านหมอก → ศาลเจ้าร้าง → ใส่ผนึกให้ดาบ → ปราบบอส "ผู้เฝ้าโคมดับ" จบ 5 เควสต์ได้โดยไม่ใช้ command (ACCEPTANCE M2 ข้อแรก)

| สิ่งที่ต้องมี (GDD/Plan) | จำนวน |
|---|---|
| หมู่บ้าน safe hub | 1 (หมู่บ้านโคมสุดท้าย) |
| พื้นที่ล่า | 2 (ป่าม่านหมอก, ศาลเจ้าร้าง) |
| ศัตรูธรรมดา | 4 (lantern_wisp มีแล้ว + root_shade, bell_moth, shrine_guard) |
| บอส | 1 (extinguished_keeper, 3 ท่า, encounter arena) |
| เควสต์ | 5 (q01_meet_keeper → q05_defeat_keeper) |
| อาวุธ / ผนึก | training_blade 1 / ember, ward |
| UI | HUD + quest tracker + หน้าผนึก + dialogue, desktop และ touch |

**นอกขอบเขต M2:** save/load จริง (เป็น M3 ตาม PRODUCTION_PLAN; M2 ใช้ memory state และป้าย progress resets ต่อ), อาชีพที่ 2–3, trading, ร้าน Robux, publish

## 2. คำถามให้ Director ตัดสิน (มีค่าแนะนำ)

| # | คำถาม | ค่าแนะนำ | เหตุผล |
|---|---|---|---|
| Q1 | ลานศาลเจ้าจาก VB-01 ใช้เป็นอะไร | เป็นลานหน้าของ "ศาลเจ้าร้าง" และวางลาน boss หลังศาลหลัก | ใช้งานภาพที่ผ่านแล้ว ไม่ทำซ้ำ |
| Q2 | มี EXP/เลเวลใน M2 ไหม | มี เลเวล 1–5 ใน slice (cap 10 เป็นของ alpha) | GDD ให้ EXP เป็นรางวัลหลัก ผู้เล่นควรเห็นความก้าวหน้า |
| Q3 | เหรียญ (coins) ใช้ทำอะไรใน M2 | เก็บและแสดงเท่านั้น ยังไม่มีร้าน | ผนึกใช้ essence ตาม GDD ร้านค้าไม่อยู่ใน slice |

**คำตอบ Director (27 ต.ค. 2026):** Q1 ลานศาลเจ้าเป็น **ลานบอส** · Q2 **มีเลเวลไว้เทส** (cap 5) · Q3 เหรียญ **แสดงอย่างเดียว** ไปก่อน

## 3. แบ่งเป็น batch

แต่ละ batch ส่ง source + test ที่รันได้ + รายการให้ Director กด Play แบบเดียวกับ P1/VB-01

| Batch | เนื้อหา | ต้องให้ Director ลอง | ขึ้นกับ |
|---|---|---|---|
| **M2-A Foundation** (ส่ง source แล้ว 27 ต.ค., ดู `docs/qa/M2A_RESULTS.md`) | catalog ข้อมูล (enemy/skill/quest/zone/item/seal) ตาม schema ใน CONTRACTS, memory profile แบบ ProfileV1, RewardService แยก EXP/coins/essence + level, zone framework (หลายพื้นที่ใน place เดียว, checkpoint ต่อ zone) | แทบไม่มี: loop เดิมต้องเล่นได้เหมือนเดิม + HUD แสดงเลเวล/EXP | Codex รับ schema |
| M2-B World greybox | หมู่บ้าน (ผู้ดูแลศาล, ศาลผนึก), ป่าม่านหมอก, ศาลเจ้าร้าง (ต่อจาก VB-01), ทางเชื่อม/landmark | เดินทั้งเส้นทาง กล้องไม่ติด รู้ทางไปต่อ | M2-A |
| M2-C ศัตรูใหม่ 3 ชนิด | root_shade (เตี้ย กว้าง ตีแรงช้า), bell_moth (เร็ว บินวน), shrine_guard (สูง ยันต์รอบแขน); AI อ้อมสิ่งกีดขวางด้วย waypoint | อ่านท่าเตือนแต่ละตัวออก ความยากพอดี | M2-A, M2-B |
| **M2-D เควสต์ + NPC** (ส่ง source แล้ว 27 ต.ค., ดู `docs/qa/M2D_RESULTS.md`) | QuestService จาก domain events, claim_quest, dialogue, quest tracker | ทำ q01–q04 ได้เองโดยไม่ต้องบอก | M2-A, M2-B |
| M2-E อาวุธ + ผนึก | InventoryService, apply_seal ที่ศาล, ember (burn ไม่ซ้อน), ward (shield มี cooldown), หน้ายืนยันราคา | ผนึกสองแบบรู้สึกต่างกัน | DEC-008 ต้องปิดก่อน |
| M2-F บอส | extinguished_keeper 3 ท่า, encounter arena (เปิดรับ/ล็อก/reset 5 วิ), รางวัลเกณฑ์ 5% | สู้ 2–4 นาที solo ไม่ยาก/ง่ายเกิน | M2-C |
| M2-G Integration | ACCEPTANCE M2 ทุกข้อ, 1/2/8 ผู้เล่น, touch, รายงานผล | เล่นจบทั้ง slice | ทุก batch |

## 4. ใบงาน batch แรก — M2-A Foundation

**ทำไมเริ่มที่นี่:** ทุก batch ถัดไปต้องอ่านค่าจาก catalog และให้รางวัลผ่าน RewardService ถ้าเริ่มสร้างแผนที่หรือศัตรูก่อน จะต้องรื้อค่าที่ฝังใน Prototype.luau ทีหลัง

### 4.1 Definitions catalog (`src/shared/Definitions/`)
- `Enemies.luau`, `Skills.luau`, `Quests.luau`, `Zones.luau`, `Items.luau`, `Seals.luau`, `Progression.luau` ใช้ field ตาม "Definition schema" ใน CONTRACTS ไม่เปลี่ยนชื่อ field
- ค่าของ lantern_wisp / blade_sweep / ตัวเลขต่อสู้เดิมย้ายจาก `Prototype.luau` มาอยู่ catalog โดยค่าเท่าเดิมทุกตัว; `Prototype.luau` เหลือเฉพาะค่าที่เป็นของต้นแบบ (label, arena) และอ้าง catalog แทนการซ้ำ
- ศัตรู/เควสต์ที่ยังไม่ implement ใส่ค่าเริ่มต้นพร้อมป้าย `draft = true` ให้ Codex ปรับ
- test: ทุก ID เป็น snake_case, อ้างอิงข้ามกันครบ (quest → enemy/zone), ตัวเลข finite และอยู่ในช่วง

### 4.2 Memory profile (`src/server/Services/ProfileService.luau`)
- ProfileV1 ใน memory (ไม่มี DataStore) ตาม field ใน CONTRACTS: level, xp, coins, essence, inventory (training_blade), equippedWeaponId, quests, checkpointId
- mutation ผ่าน queue เดียวต่อผู้เล่น, revision เพิ่มทุก mutation, ค่าตาม range (level 1–10, currency 0–1,000,000, overflow ไม่ grant แบบเงียบ)
- โครง adapter เผื่อ M3: interface load/save แยก ตัว memory adapter ติดป้ายโหมดทดสอบ

### 4.3 RewardService
- แยกจาก SpiritService: EXP/coins/essence/gauge ต่อ kill อ่านจาก Enemies catalog, ledger enemyRuntimeId + userId เดิม
- level up ตาม Progression curve (ค่าแนะนำ Q2: cap 5 ใน slice), HP สูงสุดปรับตามเลเวล
- SpiritService เหลือแค่ transform lifecycle

### 4.4 Zone framework
- tag `Zone` + attribute `ZoneId` บนพื้นที่, checkpoint ผูก zone, reward ตรวจ "อยู่ใน zone" ตาม contract
- ลาน P1 กลายเป็น zone ทดสอบ `p1_arena` ชั่วคราว จน M2-B สร้างพื้นที่จริง

### 4.5 HUD
- เพิ่มเลเวลและแถบ EXP ใต้แถบเดิม, เหรียญข้าง essence ข้อมูลมาจาก snapshot เท่านั้น

### 4.6 Test และหลักฐาน
- pure tests ใหม่: CatalogTest, ProfileRulesTest (range/overflow/revision/queue), RewardLedgerTest (kill เดียวไม่ grant ซ้ำ, ไม่ grant คนตาย/นอกระยะ, level up ข้ามขั้น)
- รันใน Studio อัตโนมัติแบบ MovementRulesTest และรันนอก Studio ด้วย mock headless ก่อนส่ง
- regression: SceneLayoutTest, MovementRulesTest ต้องผ่านเหมือนเดิม; QA payload scripts ของ P1 ยังใช้ได้

### 4.7 Director ลองเมื่อส่ง (ประมาณ 3 นาที)
1. กด Play: Output ทุก test ผ่าน
2. เล่น loop เดิม: ฟัน ผีตาย orb เกจ แปลงร่าง เหมือนเดิม
3. HUD ขึ้นเลเวล/EXP/เหรียญ ฆ่าผีแล้วเพิ่ม เลเวลอัปแล้ว HP สูงสุดเพิ่ม

## 5. Contract proposals ที่ต้องให้ Codex รับก่อนเริ่มเขียน M2-A

1. **PublicOwnProfile** ขยายจาก P1 (`classId, essence`) เป็น `level, xp, xpToNext, coins, essence, equippedWeaponId, quests` (ไม่ส่ง inventory ทั้งหมดจนถึง M2-E)
2. **Progression schema** (ใหม่): `levelCap, xpCurve[], maxHpByLevel[]` อยู่ใน `Definitions/Progression.luau`
3. **Zone schema** (ใหม่): `id, displayNameTH, kind (hub/hunt/boss), checkpointId, rewardEligible`
4. **Item / Seal schema** (ใหม่ สำหรับ M2-E แต่ร่างไว้ตอนนี้): Item `id, slot, baseDamage`; Seal `id, displayNameTH, essenceCost, effect params`
5. DEC-008 (expected weapon state ของ apply_seal) ยังต้องปิดก่อน M2-E ไม่กระทบ M2-A

ถ้า Codex ยังไม่ว่างรับ contract ผมเริ่ม 4.1–4.3 ได้โดยไม่แตะ shape ของ remotes เพราะ snapshot field ใหม่เป็นการเพิ่ม ไม่ลบของเดิม แต่จะระบุใน delivery ว่ารอรับ contract

## 6. ข้อเสนอเพิ่ม: หมู่บ้านศูนย์รวม บ้านผู้เล่น จับผี และฤดูกาล (Director 27 ต.ค. 2026)

Director เสนอหลัง M2-A ผ่าน ส่วนนี้ยังเป็นข้อเสนอ ต้องให้ Codex รับเข้า GAME_DESIGN / CONTRACTS / PRODUCTION_PLAN ก่อน implement ส่วนที่เกิน M2

### 6.1 ภาพหมู่บ้าน
- อ้างอิงหมู่บ้านแบบชิราคาวะโกะ (Director ส่งรูป 3 รูป: ใบไม้แดง, หิมะกลางคืนไฟหน้าต่าง, นาเขียว) หลังคามุงฟางทรงสามเหลี่ยมชัน (gassho-zukuri) ตัวบ้านไม้เข้ม ฉากหลังป่าสน นาขั้นบันได ทางเดินคดเคี้ยว
- ใช้กับ `last_lantern_village` เป็น hub กลาง: ร้านค้า, ร้านตีบวก (อัปเกรด/ผนึก), ศาลผู้ดูแล, แปลงบ้านผู้เล่น

### 6.2 บ้านผู้เล่น
- แปลงบ้านเท่าจำนวนผู้เล่นสูงสุดต่อเซิร์ฟ (`Project.TargetPlayersPerServer` = 8) แปลงว่างแสดงเป็นแปลงล็อก
- ผู้เล่นเข้าเซิร์ฟ → ได้แปลงว่าง → บ้านที่ตนแต่งไว้และผีที่จับได้โผล่ขึ้น; ออก → แปลงกลับเป็นล็อก
- ผีที่จับได้ลอยอยู่ในลานบ้าน (Director ข้อ 2) เป็นภาพเท่านั้น ไม่มี hitbox
- การจำของแต่ง/ผีข้ามรอบเล่นต้องมี persistence (DataStore, M3 ตาม PRODUCTION_PLAN) ใน M2 ทำได้แค่แปลงล็อก/ปลดล็อก + บ้านตั้งต้น

### 6.3 จับผีด้วยยันต์
- ผีต้องอ่อนแรงก่อน (HP ต่ำกว่าเกณฑ์) แล้วปายันต์; ถ้าไม่จับก็ฆ่าได้ตามปกติ (Director ข้อ 1)
- บอสจับได้แต่ยาก: มีโอกาสปายันต์ 2–3 ครั้งต่อการสู้หนึ่งรอบ (Director ข้อ 3)
- ข้อเสนอ: ยันต์ซื้อด้วยเหรียญ (ให้เหรียญมีที่ใช้), โอกาสสำเร็จขึ้นกับ HP ที่เหลือ, server ตัดสินผลทั้งหมด, action ใหม่ `throw_talisman {enemyRuntimeId?, aimDirection}` ใช้ ledger แบบเดียวกับ reward เพื่อกันจับซ้ำ
- ยังต้องตัดสิน: จับแล้วได้ EXP/เหรียญเท่าฆ่าไหม, ผีซ้ำทำอะไร, เพดานจำนวนที่โชว์ในลาน

### 6.4 ฤดูกาลและกลางวัน/กลางคืน
- คำนวณจากเวลาจริง UTC ให้ทุกเซิร์ฟอยู่ฤดูเดียวกัน ฤดูละ 10 วันในเกม (Director ข้อ 4)
- ค่าแนะนำ: 1 วันในเกม = 20 นาทีจริง → ฤดูละ ~3 ชม. 20 นาที, ครบปี ~13 ชม. (รอ Director เลือก)
- M2 ทำวงจรวัน/คืน + ตัวนับฤดู แต่สร้างภาพเฉพาะฤดูใบไม้แดง; ฤดูอื่นเพิ่มทีละฤดูในรอบงานภาพ (หิมะบนหลังคา, นาเขียว, ซากุระ)

### 6.5 ลำดับที่เสนอ
| Batch | เนื้อหา |
|---|---|
| M2-B (ปรับ) | ผังหมู่บ้าน greybox ตามรูป: แปลงบ้าน 8 แปลง (ล็อก/ปลดล็อกเมื่อมีคนเข้า), ร้านค้า/ร้านตีบวก/ศาลเป็นตึกเปล่า, ป่าม่านหมอก, ทางไปลานบอส; วงจรวัน/คืน + ตัวนับฤดู (ภาพฤดูใบไม้แดง) |
| ภายหลัง (เสนอ M3 คู่กับ persistence) | จับผีด้วยยันต์, ผีลอยในลานบ้าน, แต่งบ้าน, ร้านจริง, ภาพฤดูอื่น |
