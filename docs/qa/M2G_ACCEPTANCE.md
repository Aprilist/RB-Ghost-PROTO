# M2-G ACCEPTANCE M2 — ตารางตรวจและผลรัน

ร่างโดย Claude 27 ต.ค. 2026 | ใช้คู่กับ `docs/ACCEPTANCE.md` หัวข้อ M2 ตารางนี้บอกว่าแต่ละข้อ **มีอะไรรองรับแล้ว** และ **ต้องรันอะไรจึงจะติ๊กได้** ไม่มีข้อไหนถือว่าผ่านจนมีผลรันจริงตามหัวข้อ "รายงานผล" ใน ACCEPTANCE

สถานะ: `unverified` = เขียนโค้ด/test แล้ว ยังไม่เคยรัน · `partial` = Director ลองบางส่วนแล้ว · `blocked` = ทำไม่ได้จนกว่าจะมีสิ่งที่ระบุ

| # | ข้อใน ACCEPTANCE M2 | รองรับในโค้ด | ผลรันที่มี | สถานะ | ต้องทำอะไรจึงติ๊กได้ |
|---|---|---|---|---|---|
| 1 | ผู้เล่นใหม่ทำ 5 quests จนจบบอสได้โดยไม่ใช้ command | q01–q05 ครบ ลูกศรนำทาง `QuestGuide` ชี้ทุกขั้น ผนึกที่ช่างตีดาบ บอสที่ลานศาลเจ้า | Director บอกว่า "ผนึกผ่าน" (M2-E) ส่วน q01–q03 และบอสยังไม่มีผลที่แจ้ง | partial | Director เล่นใหม่ตั้งแต่เข้าเกมถึงรับรางวัล q05 โดยไม่ใช้ Command Bar บันทึกจุดที่หลง |
| 2 | seal 2 แบบมีผลต่างกัน และแสดงต้นทุนก่อนยืนยัน | ember (ไฟลุก) ≠ ward (โล่), เมนูแสดงราคา และ **เพิ่มขั้นยืนยันราคาแล้ว** (กดครั้งแรกขึ้นราคา กดซ้ำจึงหัก) | M2-E: "ผนึกผ่าน" (ก่อนเพิ่มขั้นยืนยัน) · **รันจริง 27 ต.ค. (Claude ผ่าน MCP):** กดครั้งแรกขึ้นราคา ไม่ส่ง request ไม่หักเงิน ดูหัวข้อ "ผลรันผ่าน Studio MCP" | partial | ขั้นยืนยันราคาผ่านแล้ว เหลือ Director ดูผลต่างของ ember/ward ระหว่างเล่น (ข้อ 1) |
| 3 | essence ไม่ติดลบ; duplicate request ไม่หักหรือ grant ซ้ำ | `SealRules.Apply` ตรวจและหักใน Mutate เดียว, ledger ของรางวัลศัตรู/บอส, `ProfileRules.Validate` กันติดลบ | test ทั้ง 3 ชุดผ่านใน Studio · ยิง apply_seal ซ้ำ 9 ครั้งจาก client ตอนแก่นวิญญาณ 0: ปฏิเสธทุกครั้ง แก่นวิญญาณคงที่ | partial | **ยังไม่ได้ยิงซ้ำตอนมีแก่นวิญญาณ ≥ 30** (เส้นทางหักเงินจริง) ทำตามขั้น A ด้านล่างตอนเล่นถึง q04 |
| 4 | quest one-time claim ซ้ำไม่ได้; prerequisites ทำงาน | `QuestRules` (pure), `claim_quest` จ่ายใน Mutate เดียวกับที่ mark claimed | `QuestRulesTest` 11/11 ผ่าน · ยิง claim_quest q01 ซ้ำ 9 ครั้ง: OK ครั้งเดียว เหรียญ +5 ครั้งเดียว · รับ q02/q03 ก่อนพร้อม → `QUEST_NOT_READY` | **ผ่าน (มีหลักฐาน)** | — |
| 5 | boss 1/2/8 participants; all-dead reset; late join กติกาถูกต้อง | `EncounterService` + `BossService` ตัวกรองสมาชิก reset 5 วิ | `BossRulesTest` / `EncounterRulesTest` (เฉพาะกฎ pure) | unverified / **blocked** บางส่วน | 1 คนเล่นเองได้ · 2 คนต้องมี client ที่สอง (Studio Test → Local Server + 2 Players) · 8 คนต้องมี 8 clients หรือเครื่องที่พอ ห้ามใช้ mock player |
| 6 | รางวัลผู้ตาย/ออกพื้นที่/ดาเมจต่ำกว่าเกณฑ์ตรง contract | `EncounterRules.Payout` + `pay()` | `EncounterRulesTest` ข้อ payout | unverified | ต้องมี 2 clients: ตายก่อนบอสล้ม, เดินออกลาน, ตีน้อยกว่า 150 ดาเมจ แล้วดูว่าไม่ได้รางวัล |
| 7 | HUD desktop และ touch ไม่บังท่าเตือน; loading/error มีทางออก | HUD มุมซ้ายบน, ตัวติดตามเควส, เมนูผนึก/บทพูดกลางจอ, แถบบอสกลางบน | P1-E: touch layout บน iPhone XR simulator (ก่อนมี HUD ของ M2) | unverified | ลอง desktop และ touch (emulator ได้ แต่ระบุว่า emulator) ดูว่าเมนูผนึก/แถบบอส/ตัวติดตามไม่ทับปุ่มและวงเตือน · ข้อความเชื่อมต่อไม่ได้มีอยู่แล้ว (`PrototypeBannerController`) |

## ผลรันจริงที่มี: Output ตอนกด Play (Director ส่ง 27 ต.ค. 2026 เวลา 21:23)

Build ตอนนั้นคือ M2-F (commit `f4e77b2`) **ก่อนเพิ่มขั้นยืนยันราคาในเมนูผนึก** ตรวจจาก Output ที่คุณส่งมา ไม่ใช่จากการที่ผมรันเอง

| ผล | รายละเอียด |
|---|---|
| server เริ่มได้ | ข้อความ `M2-F server started` ไม่มี error สีแดง |
| client เริ่มได้ | `P1 client started: network ready` |
| test ผ่านทั้งหมด | Movement 15, SceneLayout 7, Catalog 9, ProfileRules 10, RewardRules 8, WorldClock 8, PlotRules 4, EnemyAttackRules 9, QuestRules 11, QuestWorld 6, SealRules 12, BossRules 10, EncounterRules 8 |
| **test ตก 1 ข้อ** | `WorldLayoutTest` "Mistwood path and village roads are clear of solids": ชี้ `Regions.Collision.VillageSouth` เป็นของบนถนนหมู่บ้าน |
| warning เดิม | `rbxassetid://203785492` asset type ไม่ตรง (พบตั้งแต่ P1-A ไม่มี ID นี้ใน source ยังระบุสาเหตุไม่ได้) |

**สาเหตุ test ที่ตก:** `VillageSouth` คือกำแพงล่องหนปลายสุดของโลก (z = 1040.5) ที่ตั้งใจพาดปลายถนนทางเหนือซึ่งหยุดที่ torii ที่ผูกเชือกปิดไว้ ตัว test ข้ามกำแพงล่องหนได้เฉพาะชื่อที่มีคำว่า `Bound` แต่ `Regions.luau` ตั้งชื่อกำแพงเป็น `VillageSouth`, `MistwoodWest` ฯลฯ จึงถูกนับเป็นของวางบนถนน นี่เป็นความไม่ตรงกันระหว่างชื่อกับ test ตั้งแต่ M2-B ไม่ใช่ผลของ M2-D/E/F และไม่มีผลต่อการเล่น แก้ที่ test (`isBound` รู้จักกำแพงล่องหนชื่อ `Village…`/`Mistwood…` ด้วย) **ยังไม่ได้รันซ้ำ**

ผลนี้ทำให้ข้อ 3 และ 4 ด้านบนขยับ: test แบบ pure ของ quest, seal, boss และ encounter **ผ่านจริงใน Studio แล้ว** (ยังไม่ครอบคลุมการยิง remote ซ้ำจริงและ 2 clients)

## ผลรันผ่าน Studio MCP (Claude รันเอง 27 ต.ค. 2026, build `f00e077`)

Studio เชื่อม rojo อยู่แล้ว ตรวจว่า `WorldLayoutTest` ใน Studio มี `isBound` ฉบับแก้ก่อนกด Play ผู้เล่น 1 คน (Play solo) โปรไฟล์โหมด memory

**Test ทั้ง 14 ชุดผ่าน 128/128 ไม่มี error สีแดง:** Movement 15, SceneLayout 7, Catalog 9, ProfileRules 10, RewardRules 8, WorldClock 8, PlotRules 4, **WorldLayout 11/11** (รวม "Mistwood path and village roads are clear of solids" 918 solids), EnemyAttackRules 9, QuestRules 11, QuestWorld 6, SealRules 12, BossRules 10, EncounterRules 8 · warning `rbxassetid://203785492` ยังอยู่เหมือนเดิม

**claim_quest ซ้ำ (ข้อ 4)** เดินไปหาผู้ดูแลศาล คุยจน q01 = ready แล้วยิง `ActionRequest` เองจาก client:

| ส่ง | ผล | เหรียญ/EXP |
|---|---|---|
| 5 ครั้งรวด requestId ต่างกัน | dupA1 `OK`, dupA2 `ALREADY_CLAIMED`, dupA3–5 `RATE_LIMITED` | 0→5 / 0→10 ครั้งเดียว |
| requestId `dupA1` ซ้ำ (ห่าง 1.5 วิ) | ตอบผลเดิมจาก cache `OK` ไม่รัน handler ซ้ำ ไม่มี snapshot ใหม่ | คงที่ 5 |
| 3 ครั้ง ห่างกัน 1.2 วิ requestId ใหม่ | `ALREADY_CLAIMED` ทุกครั้ง | คงที่ 5 |
| q03 (ยังไม่เริ่ม), q02 (active ยังไม่ครบ) | `QUEST_NOT_READY` ทั้งคู่ | คงที่ |

**เมนูผนึก (ข้อ 2)** ที่ช่างตีดาบ แก่นวิญญาณ 0 คลิกเมาส์จริงที่ปุ่ม "ผนึก" ของผนึกถ่านไฟ:
- ครั้งแรก: ปุ่มเปลี่ยนเป็น `ยืนยัน -30` ข้อความ "ใช้แก่นวิญญาณ 30 … กดปุ่มอีกครั้งเพื่อยืนยัน" **ไม่มี ActionResult ใหม่ (ไม่ส่ง apply_seal)** แก่นวิญญาณยัง 0
- ครั้งที่สอง: ส่ง apply_seal ได้ `INSUFFICIENT_ESSENCE` ตามคาด
- พบข้อความซ้ำคำ: "ผนึก**ผนึก**ถ่านไฟ" (format ต่อ "ผนึก" หน้า `displayNameTH` ที่ขึ้นต้นด้วย "ผนึก" อยู่แล้ว) ไม่กระทบกติกา · แก้แล้วเป็น "ใช้แก่นวิญญาณ 30 เพื่อผนึกถ่านไฟ …" (ยังไม่ได้รันซ้ำใน Studio)

**apply_seal ซ้ำ (ข้อ 3)** แก่นวิญญาณ 0: 6 ครั้งรวด → 2 `INSUFFICIENT_ESSENCE` + 4 `RATE_LIMITED`; 3 ครั้งห่าง 1.2 วิ → `INSUFFICIENT_ESSENCE` ทั้งหมด ไม่มี snapshot ใหม่ (dry run ไม่แตะโปรไฟล์) แก่นวิญญาณคงที่ 0 ไม่ติดลบ · **ข้อจำกัด:** ยังไม่ได้ทดสอบตอนมีเงินพอ ซึ่งเป็นเส้นทางที่หักเงินจริง (server ใน Studio เป็นคนละ VM กับ Command Bar ของ MCP จึงเติมแก่นวิญญาณให้ไม่ได้โดยไม่แก้โค้ดเกม และไม่ได้ farm ศัตรูอัตโนมัติ)

### ขั้น A: ยิง apply_seal ซ้ำตอนมีเงิน (Director ทำตอนเล่นถึง q04, ~2 นาที)

1. เล่นจนแก่นวิญญาณ ≥ 30 ยืนข้างช่างตีดาบ จดค่าแก่นวิญญาณใน HUD
2. ระหว่าง Play สลับ Command Bar ไปที่ **Client** แล้วรัน:
   `local r=game.ReplicatedStorage.SpiritWardRemotes; for _,c in r:GetChildren() do if c.Name:lower():find("request") then for i=1,3 do c:FireServer({requestId="qa"..i,action="apply_seal",payload={itemInstanceId="w1",sealId="ember"}}) task.wait(1) end end end`
3. ผ่านเมื่อ: แก่นวิญญาณลด 30 **ครั้งเดียว** ดาบติดผนึกถ่านไฟ ครั้งที่ 2–3 ไม่หักเพิ่ม (server ตอบ `ALREADY_SEALED`)

## สิ่งที่ผมตรวจเองได้ตอนนี้ และผล

| ตรวจ | ผล |
|---|---|
| `rojo build` ของโปรเจกต์ | ผ่าน (หลัง M2-E และ M2-F) ตรวจแค่โครงไฟล์และชื่อสคริปต์ ไม่ใช่ Luau |
| compile / type-check / รัน test | ไม่มี `luau` บนเครื่อง แต่รันผ่าน Studio MCP ได้แล้ว (หัวข้อด้านบน) |

## ลำดับที่แนะนำให้ Director รัน (ใช้ Studio ประมาณ 30–40 นาที)

1. ~~กด Play ก๊อป Output~~ ทำแล้วผ่าน MCP (128/128)
2. เล่น q01 → q05 (ทำขั้น A ตอนถึง q04) ตามปกติ ไม่ใช้ Command Bar (ข้อ 1, 2, 7) พร้อมแจ้งว่าตรงไหนไม่รู้จะไปทางไหน
3. Studio → Test → Local Server, 2 Players (ข้อ 5, 6): ตายก่อนบอสล้ม / มาสาย / ตีน้อยกว่า 5%
4. touch emulator (ข้อ 7) แล้วค่อยหาเครื่องมือถือจริงเมื่อพร้อม (ยังไม่ใช่ข้อบังคับของ M2 แต่ ACCEPTANCE M3 ต้องใช้)

ผมไม่ได้ติ๊กข้อใดใน `docs/ACCEPTANCE.md` เพราะยังไม่มีผลรันจริงตามเกณฑ์ ถ้าได้ Output หรือผลจาก Studio จะอัปเดตตารางนี้ตามหลักฐาน
