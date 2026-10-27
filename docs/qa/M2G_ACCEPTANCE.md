# M2-G ACCEPTANCE M2 — ตารางตรวจ (ยังไม่ใช่ผลทดสอบ)

ร่างโดย Claude 27 ต.ค. 2026 | ใช้คู่กับ `docs/ACCEPTANCE.md` หัวข้อ M2 ตารางนี้บอกว่าแต่ละข้อ **มีอะไรรองรับแล้ว** และ **ต้องรันอะไรจึงจะติ๊กได้** ไม่มีข้อไหนถือว่าผ่านจนมีผลรันจริงตามหัวข้อ "รายงานผล" ใน ACCEPTANCE

สถานะ: `unverified` = เขียนโค้ด/test แล้ว ยังไม่เคยรัน · `partial` = Director ลองบางส่วนแล้ว · `blocked` = ทำไม่ได้จนกว่าจะมีสิ่งที่ระบุ

| # | ข้อใน ACCEPTANCE M2 | รองรับในโค้ด | ผลรันที่มี | สถานะ | ต้องทำอะไรจึงติ๊กได้ |
|---|---|---|---|---|---|
| 1 | ผู้เล่นใหม่ทำ 5 quests จนจบบอสได้โดยไม่ใช้ command | q01–q05 ครบ ลูกศรนำทาง `QuestGuide` ชี้ทุกขั้น ผนึกที่ช่างตีดาบ บอสที่ลานศาลเจ้า | Director บอกว่า "ผนึกผ่าน" (M2-E) ส่วน q01–q03 และบอสยังไม่มีผลที่แจ้ง | partial | Director เล่นใหม่ตั้งแต่เข้าเกมถึงรับรางวัล q05 โดยไม่ใช้ Command Bar บันทึกจุดที่หลง |
| 2 | seal 2 แบบมีผลต่างกัน และแสดงต้นทุนก่อนยืนยัน | ember (ไฟลุก) ≠ ward (โล่), เมนูแสดงราคา และ **เพิ่มขั้นยืนยันราคาแล้ว** (กดครั้งแรกขึ้นราคา กดซ้ำจึงหัก) | M2-E: "ผนึกผ่าน" (ก่อนเพิ่มขั้นยืนยัน) | partial | Director ลองเมนูใหม่: กดครั้งแรกต้องไม่หักเงิน |
| 3 | essence ไม่ติดลบ; duplicate request ไม่หักหรือ grant ซ้ำ | `SealRules.Apply` ตรวจและหักใน Mutate เดียว, ledger ของรางวัลศัตรู/บอส, `ProfileRules.Validate` กันติดลบ | `SealRulesTest` / `ProfileRulesTest` / `RewardRulesTest` (เขียนแล้ว ยังไม่เห็นผลรัน) | unverified | กด Play ดู Output ว่าทุก test passed · ทดสอบส่ง apply_seal ซ้ำจริงต้องมี client ที่ยิง remote เอง (ยังไม่มี harness) |
| 4 | quest one-time claim ซ้ำไม่ได้; prerequisites ทำงาน | `QuestRules` (pure), `claim_quest` จ่ายใน Mutate เดียวกับที่ mark claimed | `QuestRulesTest` 11 ข้อ (ยังไม่เห็นผลรัน) | unverified | กด Play ดู test · ทดลองกดรับรางวัลเควสเดิมซ้ำใน Studio |
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

## สิ่งที่ผมตรวจเองได้ตอนนี้ และผล

| ตรวจ | ผล |
|---|---|
| `rojo build` ของโปรเจกต์ | ผ่าน (หลัง M2-E และ M2-F) ตรวจแค่โครงไฟล์และชื่อสคริปต์ ไม่ใช่ Luau |
| compile / type-check / รัน test | **ทำไม่ได้**: เครื่องนี้ไม่มี `luau` ต้องกด Play ใน Studio |

## ลำดับที่แนะนำให้ Director รัน (ใช้ Studio ประมาณ 30–40 นาที)

1. `rojo serve` → Studio เชื่อม → กด Play → ก๊อป Output ทั้งหมดมาให้ผม (ข้อ 3, 4 และ error ของทุก batch)
2. เล่น q01 → q05 ตามปกติ ไม่ใช้ Command Bar (ข้อ 1, 2, 7) พร้อมแจ้งว่าตรงไหนไม่รู้จะไปทางไหน
3. Studio → Test → Local Server, 2 Players (ข้อ 5, 6): ตายก่อนบอสล้ม / มาสาย / ตีน้อยกว่า 5%
4. touch emulator (ข้อ 7) แล้วค่อยหาเครื่องมือถือจริงเมื่อพร้อม (ยังไม่ใช่ข้อบังคับของ M2 แต่ ACCEPTANCE M3 ต้องใช้)

ผมไม่ได้ติ๊กข้อใดใน `docs/ACCEPTANCE.md` เพราะยังไม่มีผลรันจริงตามเกณฑ์ ถ้าได้ Output หรือผลจาก Studio จะอัปเดตตารางนี้ตามหลักฐาน
