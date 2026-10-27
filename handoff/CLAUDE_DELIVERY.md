# Claude delivery report

> Codex latest: P1-E local validation รันแล้ว 15/15 pure tests, runtime negatives, mobile simulator และ 2 clients ตาม docs/qa/P1E_CODEX_REVIEW.md Codex แก้ bounded jitter credit กับ touch layout เพิ่ม รายงานเดิมด้านล่างเป็นประวัติ ณ ตอน Claude ส่ง source

> **Codex update 27 ต.ค. 2026:** รัน build และ Play Solo subset แล้ว ดู `docs/qa/P1D_CODEX_REVIEW.md` และผล raw ใน `docs/qa/evidence/P1D_RUNTIME.json` ข้อความ “ยังไม่รัน” ด้านล่างเป็นรายงานต้นฉบับตอน Claude ส่งงาน ไม่ใช่สถานะล่าสุด Codex แก้ remotes เป็น `SpiritWardRemotes` ที่ไม่ลบของผู้ใช้แล้ว ยังเหลือ dash movement validation, multiplayer/touch และ Director feedback ก่อนปิด P1

> **Claude update 27 ต.ค. 2026:** server movement authority ของ dash ทดสอบใน Studio แล้ว E1–E9, A6 (iPhone XR simulator) และ D1–D4 (2 clients จริง) ผ่าน ระหว่างทดสอบแก้ jitter credit และ layout ปุ่มมือถือ (ดู "ผลทดสอบใน Studio" ด้านล่างและ `docs/qa/P1E_CODEX_REVIEW.md`) ที่ยังเปิดอยู่คือการตัดสินด้านความรู้สึก/ภาพของ Director และมือถือจริง

สถานะต้นฉบับ: **P1-A ถึง P1-C ส่ง source แล้ว; P1-D เตรียมชุดทดสอบแล้ว รอผู้ใช้เล่นจริงใน Studio** (27 ต.ค. 2026) ยังไม่มีการรันใน Studio จึงยังไม่ผ่าน gate ใด ผู้ใช้สั่งเริ่ม P1-B และ P1-C ก่อนรายงานผล runtime ของ batch ก่อนหน้า

## รอบปัจจุบัน — M2-B หมู่บ้าน ป่า Mistwood และนาฬิกาโลก

ทิศทางจาก Director (27 ต.ค. 2026): หมู่บ้านศูนย์รวมแบบ Shirakawa-go ผังวงกลมตามสเก็ตช์ (ต้นไม้ศักดิ์สิทธิ์กลาง แผงขายรอบต้น ถนนวงแหวน บ้านผู้เล่นลาน 80×94 รอบนอกไว้โชว์ผีที่จับได้ราว 10 ตัว บ้าน NPC แซม) มีแปลงบ้านผู้เล่นเท่าจำนวนคนในเซิร์ฟ, ร้านค้า/ร้านตีบวก, ลาน VB-01 เป็นลานบอส, ฤดูละ 10 วันในเกม = 2 ชั่วโมงจริง รอบนี้ภาพเฉพาะฤดูใบไม้ร่วง รายละเอียดและรายการ Play ใน `docs/qa/M2B_RESULTS.md`

**New files**
- `src/shared/Definitions/World.luau`: ผังโลก (ประตูลาน, ป่า, หมู่บ้านวงกลม: รัศมีต้นไม้/ลาน/แผง/ถนนวงแหวน, 8 แปลงคำนวณจากมุม, บ้าน NPC, นา, ป่าเล็ก) + `OnRing` + ค่านาฬิกา
- `src/shared/Util/WorldClock.luau` (pure): ชั่วโมง/วัน/ฤดู/ปีจากเวลา UTC
- `src/server/Util/PlotRules.luau` (pure): จอง/คืนแปลงบ้าน
- `src/server/Scene/Kit.luau`, `Village.luau`, `Mistwood.luau`, `Regions.luau`, `Sky.luau`
- `src/server/Services/WorldClockService.luau`, `PlotService.luau`
- `src/server/Tests/WorldClockTest.luau`, `PlotRulesTest.luau`, `WorldLayoutTest.luau`
- `docs/qa/M2B_RESULTS.md`

**Changed files**
- `src/server/Scene/ShrineCourtyard.luau`: ช่องประตูใต้ (กำแพงหิน/โคม/ไผ่ไม่ขวาง; rng ยังเดินลำดับเดิมเพื่อให้ decor ส่วนอื่นเหมือนเดิม)
- `src/server/Services/SceneService.luau`: **collision เปลี่ยน** `BoundSouth` → `BoundSouthWest` + `BoundSouthEast` (เว้นช่อง 12 studs), เรียก `Regions.Build`, spawn หลักเป็น `VillageSpawn`
- `src/server/Scene/Regions.luau`: FarGround ขยายเป็น 1200×760 ให้ครอบหมู่บ้านขนาดใหม่
- `src/server/Util/Geometry.luau`: collision params รวม `Regions/*/Collision` และ `Plots/*/Owned/Collision`
- `src/shared/Definitions/Zones.luau`: `village`, `mistwood` มี volume จริง และ `draft = false`
- `src/server/Bootstrap.server.luau`: wiring `WorldClockService`, `PlotService` + รัน test ใหม่
- `src/client/Controllers/HUDController.luau`: แถวเวลา/ฤดู (panel สูง 156)
- `src/server/Tests/SceneLayoutTest.luau`: ค่าคาดหวังของกำแพงใต้ 2 ชิ้น

**Validation performed (นอก Studio)**
- `luau-compile` ผ่านทุกไฟล์, ตรวจ global ที่ไม่ประกาศด้วย `luau-ast` ไม่พบ
- mock headless 0 fail: เดิม 5 ชุดผ่านเท่าเดิม + WorldClockTest 8/8, PlotRulesTest 4/4, WorldLayoutTest 10/10; mutation 6 จุดถูกจับ; integration แปลงบ้าน (เข้า/ออก/คนถัดไป), กลางวัน/กลางคืน และชุด M2-A ให้ผลเท่าเดิม

**ยังไม่ได้ทดสอบ:** Studio จริง, strict type-check, หน้าตาแสงตอนเปลี่ยนเวลา, กล้องในหมู่บ้าน/ป่า, 2 clients, มือถือ, performance

**ต้องให้ Codex รับ (ข้อเสนอ ไม่ได้แก้ docs ของ Codex):**
- schema `Definitions/World.luau` และ `Util/WorldClock.luau` (นาฬิกาจาก UTC, `EpochUnix`, `BuiltSeasons`)
- workspace attributes `SpiritWardSeason`, `SpiritWardVisualSeason`; tag `SpiritWardNightGlow`, `SpiritWardNightLight`
- โซน `village`/`mistwood` เลิก draft, checkpoint ใหม่ `village_shrine`, `mistwood_gate`, SpawnId `village_start`
- การเปลี่ยน collision กำแพงใต้ของลาน (ประตูสู่ป่า)
- บ้านผู้เล่นยังไม่ persist (รอ M2-E / DEC-008); ข้อมูลการแต่งบ้านและผีที่จับได้ต้องมี field ใน ProfileV1 ภายหลัง

## รอบก่อน — M2-A Foundation (catalog, profile, reward, level, zone)

Director ตอบคำถามแผน M2 (27 ต.ค. 2026): ลานศาลเจ้า VB-01 เป็นลานบอส, มีเลเวลไว้เทส (cap 5), เหรียญแสดงอย่างเดียว รายละเอียดและผลทดสอบอยู่ใน `docs/qa/M2A_RESULTS.md`

**New files**
- `src/shared/Definitions/`: `Enemies.luau`, `Items.luau`, `Skills.luau`, `Seals.luau`, `Zones.luau`, `Quests.luau`, `Progression.luau` (ศัตรู/เควสต์/ผนึก/โซนที่ยังไม่ทำติด `draft = true`)
- `src/server/Util/ProfileRules.luau`, `src/server/Util/RewardRules.luau` (pure)
- `src/server/Services/ProfileService.luau` (ProfileV1 ใน memory), `RewardService.luau`, `ZoneService.luau`
- `src/server/Tests/CatalogTest.luau`, `ProfileRulesTest.luau`, `RewardRulesTest.luau`
- `docs/qa/M2A_RESULTS.md`

**Changed files**
- `src/shared/Definitions/Prototype.luau`: key เดิม ค่ามาจาก catalog (ค่าเท่า P1 ล็อกด้วย CatalogTest)
- `src/shared/Definitions/VisualPalette.luau`: เพิ่ม `LevelUp`
- `src/shared/Types/Contracts.luau`, `Examples.luau`: `PublicOwnProfile` เพิ่ม `level, xp, xpToNext?, coins` (เพิ่มอย่างเดียว)
- `src/server/Services/PlayerStateService.luau`: snapshot อ่าน profile, HP สูงสุดตามเลเวล, ไม่เก็บ essence เองแล้ว
- `src/server/Services/SpiritService.luau`: เหลือแค่ transform; **แก้บั๊ก** `clearAura` ที่หายไปใน VB-01 batch 2 (error ตอนหมดเวลาแปลงร่าง/ตาย)
- `src/server/Services/EnemyService.luau`: `Defeat` เพิ่ม `definitionId`
- `src/server/Bootstrap.server.luau`: wiring service ใหม่ + รัน test ใหม่ใน Studio
- `src/client/Controllers/HUDController.luau`: เลเวล, แถบ EXP, เหรียญ (panel สูง 136)
- `src/client/Controllers/EffectsController.luau`: FX `level_up`

**Validation performed (นอก Studio)**
- `luau-compile` ผ่านทุกไฟล์, ตรวจ global ที่ไม่ประกาศด้วย `luau-ast` ไม่พบ
- mock headless: MovementRulesTest 15/15, SceneLayoutTest 7/7, CatalogTest 7/7, ProfileRulesTest 10/10, RewardRulesTest 8/8; mutation 3 จุดถูกจับได้; integration ของ profile/reward/level/transform ผ่าน (ตารางใน M2A_RESULTS)

**Director ทดสอบใน Studio:** "ผ่านครับ" (27 ต.ค. 2026) ตาม M1–M6 ใน `docs/qa/M2A_RESULTS.md`

**ยังไม่ได้ทดสอบ:** strict type-check, 2 clients, มือถือ

**ต้องให้ Codex รับ:** PublicOwnProfile ที่ขยาย, schema Progression/Zone/Item/Seal + field เสริม (`tuning`, `draft`, `arcDeg`, `volumes`), effect `level_up` (ดู `handoff/M2_PLAN_PROPOSAL.md` ข้อ 5)

## รอบก่อน — VB-01 batch 2 (คาตานะ ผีโคม ชุดสีเอฟเฟกต์)

Director ดู batch 1 ใน Studio แล้วบอกว่า "สวยดีครับ ผมชอบ" (27 ต.ค. 2026) batch นี้ทำภาพตัวละคร/ศัตรู/เอฟเฟกต์ต่อ ไม่แตะ hitbox, ระยะ, damage, cooldown, contracts หรือ `Prototype.luau`

**Changed files**
- `src/shared/Definitions/VisualPalette.luau` (ใหม่): ชุดสีกลางของ actor/FX ใช้ทั้ง server และ client (ไม่มีค่า gameplay)
- `src/server/Services/PlayerService.luau`: คาตานะ benchmark 15 ชิ้น (ด้ามพันผ้า, เมนุกิ, สึบะกลม, ฮาบากิ, ใบโค้งเล็กน้อย 2 ท่อน, เส้นคมเรืองจาง ๆ, ปลายคิสซากิ) + ฝักดาบเปล่าที่สะโพกซ้าย 4 ชิ้น; แกน/ตำแหน่งด้ามเดิม ทุกชิ้น massless ไม่ชน/ไม่ query/ไม่ touch
- `src/server/Services/EnemyService.luau`: ผีโคม benchmark 18 ชิ้น (โคมกระดาษวงรี, ซี่ไม้ไผ่ 5 เส้น, ขอบไม้, ตาเรือง, ปาก+ลิ้น, เปลวบน, หางวิญญาณ); `Body` ยังเป็น PrimaryPart ตั้งตรงที่ AI/CombatService/HP bar ใช้ วงเตือนเปลี่ยนเป็นขอบแดงสว่าง + พื้นในแดงเข้ม (เพิ่ม field `ringFill` ใน type ภายใน `Enemy`) ขนาดตาม `AttackHitRangeStuds` เดิม
- `src/server/Services/SpiritService.luau`: ร่างผู้พิทักษ์เพิ่มหน้ากากขาวตาเรืองครามและลายอาคม เชื่อมกับ Head; ลบพร้อม Highlight เมื่อหมดเวลา/ตาย (แก้ไขภายหลัง: รอบนี้ลบ `clearAura` ไปโดยไม่ตั้งใจ จึงลบไม่สำเร็จและ error จนแก้ใน M2-A)
- `src/client/Controllers/EffectsController.luau`: ใช้ VisualPalette; slash มีเส้นแกนขาว, orb วิญญาณสีเดียวกับเกจ HUD, ศัตรูตายเป็น ember; เอฟเฟกต์ผู้เล่นเริ่มโปร่งกว่าเดิม และตอนแปลงร่างเปลี่ยนจากลูกบอลทึบ 14 studs เป็นวงพื้น + เสาแสง เพื่อไม่บังวงเตือน
- `src/server/Tests/SceneLayoutTest.luau`: เพิ่มเคส "actor visuals never collide, query or touch" (ผี + Katana/Saya/GuardianMask ของผู้เล่นที่มีตัวละครอยู่ตอนรัน)

**Validation performed (นอก Studio)**
- `luau-compile` ผ่านทุกไฟล์
- mock headless: สร้างตัวละครจำลอง R15 ให้ PlayerService ติดดาบ, EnemyService เกิดผี 3 ตัว, SpiritService แปลงร่างได้ `OK`; ได้ katana 15 / saya 4 / mask 6 ชิ้น, ผีตัวละ 18 ชิ้น PrimaryPart = Body; SceneLayoutTest 7/7 ผ่าน (ตรวจ actor 79 parts)
- preview three.js ใช้ดูรูปทรงเท่านั้น

**ยังไม่ได้ทดสอบ:** ตำแหน่งดาบ/ฝัก/หน้ากากบน avatar จริง (R15 ขนาดต่าง ๆ, R6), ท่าทาง/ความสว่างใน Studio, 2 clients, มือถือ ดู `docs/qa/VB01_RESULTS.md` หัวข้อ batch 2

## รอบก่อน — VB-01 ลานศาลเจ้า batch 1 (ฉาก + แสง)

ตาม `docs/VISUAL_BENCHMARK_BRIEF.md` ทำเฉพาะ Decor และแสงของลานเดิม ไม่แตะ collision, markers, movement/network contracts หรือค่าใน `Prototype.luau`

**Changed files**
- `src/server/Scene/ShrineCourtyard.luau` (ใหม่): สร้างภาพทั้งหมดด้วย Part พื้นฐาน ไม่มี asset นำเข้า; โทริอิแบบเมียวจิน + เชือกชิเมนาวะ, โคมหิน 12 ต้น (6 ต้นเดิมที่มี proxy + ทางโคม 6 ต้นนอกลาน), พื้นกรวด, ทางเดินหินกลาง (sandō) จาก spawn ผ่านโทริอิถึงศาลหลัก, หินก้าวไป checkpoint/ทางลาด, กำแพงหินเตี้ย + โคมเล็ก, พุ่มไม้, รั้วแดง, ป่าไผ่, ศาลหลัก (honden), ต้นสน, ภูเขาไกล และหุ้มผิว test wall/low tier/ramp/cover ด้วย decor
- `src/server/Services/SceneService.luau`: proxies ของโทริอิ/โคมสร้างเหมือนเดิมทุกค่า แค่เปลี่ยนภาพไปเรียก ShrineCourtyard; แสง dusk ใหม่ (warm lantern + cool fill) และเพิ่ม `SpiritWardPrototypeBloom`, `SpiritWardPrototypeGrade` แบบแทนที่ของตัวเองเท่านั้น
- `src/server/Tests/SceneLayoutTest.luau` (ใหม่) และ `src/server/Bootstrap.server.luau`: รัน test นี้อัตโนมัติตอน Play ใน Studio ต่อจาก MovementRulesTest
- `assets/ASSET_MANIFEST.md`, `docs/qa/VB01_RESULTS.md` (ใหม่), ไฟล์นี้

**กฎกล้อง:** กล้องมาตรฐานของ Roblox ไม่หลบ part ที่ CanCollide ปิด ของตกแต่งที่สูงเกิน 3.5 studs จึงต้องอยู่ห่างขอบลานอย่างน้อย `Camera.MaxZoomStuds + 4` (36 studs) ยกเว้นโทริอิ/โคมหินที่สูงเท่า proxy เดิม และผิวที่หุ้ม collider (collider ยังทึบและยังบังกล้องตามเดิม) กฎนี้ตรวจใน SceneLayoutTest

**Validation performed (นอก Studio)**
- `luau-compile` ทุกไฟล์ใน `src/` ผ่าน (syntax เท่านั้น ไม่ได้ type-check แบบ strict กับ Roblox definitions)
- รัน `SceneService.Build()` จริงบน mock Roblox แบบ headless: SceneLayoutTest 6/6 ผ่าน (collision 17 รายการ + markers 5 รายการตรงกับ P1 ทุกค่า, decor 1,439 parts ไม่ชน/ไม่ query/ไม่ touch, กฎกล้อง, dressing ไม่ยื่นเกิน collider, 21 PointLights) และ Build ซ้ำแล้ว Lighting ยังมีของเรา 3 ชิ้นเท่าเดิม
- mutation test: ขยับ TestWall 1 stud, ใส่ decor ที่ชนได้, ใส่เสาสูงในแถบกล้อง → test จับได้ครบ
- ภาพ preview จาก three.js ใช้ตรวจ layout เท่านั้น แสง/วัสดุไม่ตรงกับ Roblox

**ยังไม่ได้ทดสอบ:** ทุกอย่างใน Studio (ภาพจริง, แสงบนตัวละคร/ดาบ, FPS, iPhone XR, loop เดิม) ดูรายการใน `docs/qa/VB01_RESULTS.md`

**ยังไม่ทำใน batch นี้ (batch 2):** คาตานะและผีโคมแบบ benchmark, ชุดสี slash/hit/soul/transform, ร่างผู้พิทักษ์ (หน้ากาก/ลายอาคม)

## รอบก่อน — dash movement authority

**ปัญหาเดิม:** server คำนวณ clear distance ไว้แค่ FX ส่วน client เคลื่อนจริงด้วย LinearVelocity การหยุดที่กำแพงจึงพิสูจน์แค่ physics ฝั่ง client

**ที่ทำ:**
- `src/server/Util/MovementRules.luau` (ใหม่, pure logic): tracker ต่อผู้เล่นมี anchor = ตำแหน่งล่าสุดที่ server ยอมรับ แต่ละ sample ต้องเป็น (ก) เดินภายใน WalkSpeed × 1.3 + 2.5 studs ต่อรอบ และไม่ข้าม Collision หรือ (ข) อยู่ใน dash ที่ server รับแล้ว: ระยะตามทิศ ≤ clear distance ของ server + การเดิน, ระยะออกด้านข้าง ≤ การเดิน, ภายในหน้าต่าง DurationSec + 0.4 วินาที, เส้นทางจาก origin ไม่ข้าม Collision
- การเคลื่อนที่ที่อธิบายไม่ได้ถูก latch เป็น pending รอ dash request ได้ 0.4 วินาที (เพราะตำแหน่งจาก physics อาจมาถึงก่อน remote) ถ้าไม่มี dash ที่ server รับ เช่น ติด cooldown หรือ rate limit จะ reconcile แน่นอน เวลาเดินที่ผ่านไปภายหลังไม่ล้าง latch ส่วนการข้ามกำแพงหรือระยะที่ dash เดียวอธิบายไม่ได้จะ reconcile ทันที
- `Geometry.PathClear`: block เมื่อ probe ระดับ root และ probe ที่ยกขึ้น 3 studs ชน Collision ทั้งคู่ เพื่อไม่ให้การขึ้น low tier/กระโดดข้าม cover ถูกนับเป็นทะลุกำแพง
- `src/server/Services/MovementService.luau` (ใหม่): sample root ทุก 0.25 วินาที ใช้ WalkSpeed ฝั่ง server, reconcile ด้วย `PivotTo` กลับ anchor + ล้าง velocity, นับ `Player:GetAttribute("MovementCorrections")`, ล้าง tracker เมื่อ CharacterAdded เพื่อเชื่อ spawn ของ server
- `CombatService.dash`: หลังผ่าน alive/cooldown เรียก `MovementService.BeginDash(player, dir)` ซึ่งคิด clear distance จาก anchor ของ server (ไม่ใช่ตำแหน่งที่ client รายงานล่าสุด) และใช้ค่านั้นกับ FX
- ค่าใหม่ใน `Prototype.Movement` ทั้งหมด
- **ไม่เปลี่ยน contract**: ไม่ต้องเพิ่ม field ใน ActionResult/combat_fx เพราะการ reconcile ส่งผ่านตำแหน่งตัวละครที่ replicate อยู่แล้ว จึงไม่มี `P1_CONTRACT_PROPOSALS.md`

**Negative tests:**
- `src/server/Tests/MovementRulesTest.luau`: 13 กรณี (9 negative: teleport, dash ที่ถูกปฏิเสธ, dash เกินระยะ, dash เกิน clear distance ที่กำแพง, dash ออกด้านข้าง, เดินทะลุกำแพง, dash ทะลุกำแพง, speed hack 2x, dash ซ้อน) รันใน Studio ด้วย `require(game.ServerScriptService.Server.Tests.MovementRulesTest).Run()`
- `docs/qa/P1_RESULTS.md` หัวข้อ P1-E: E1–E9 พร้อมสคริปต์ client Command Bar สำหรับ teleport, dash ช่วง cooldown, ข้ามกำแพง, speed hack และกรณี false positive (ทางลาด/low tier/cover/2 clients)

**ผลทดสอบใน Studio (27 ต.ค. 2026):** MovementRulesTest 15/15; เดิน/กระโดด/ทางลาด/พุ่งปกติไม่ถูกดึงกลับ; teleport 20, dash ช่วง cooldown, ข้ามกำแพง, speed 40 และ 28 ถูกดึงกลับ; 2 clients พุ่งไม่ถูกดึงกลับ การ reconcile ด้วย `PivotTo` ทำให้ตัวกลับจริงบน client

**แก้ระหว่างทดสอบ:**
- `MovementRules`: เดิมแจก slack 2.5 studs ใหม่ทุก sample ทำให้เดิน 28 studs/วิ ได้ต่อเนื่อง เปลี่ยนเป็น `walkCreditStuds` ที่มีเพดาน ใช้ไปตามระยะและเติมตามเวลา (DEC-013) เพิ่ม test เป็น 15 กรณี
- `InputController` + `Prototype.Input`: ปุ่มฟันล้นขอบจอใน iPhone XR จัดปุ่มเป็นกลุ่ม 2×2 ด้วย `ContextActionService:SetPosition()` (DEC-014)
- เพิ่ม `src/client/Tests/MovementQa.luau` และ `tools/SELF_TEST.md` ให้ผู้ใช้รัน QA การเคลื่อนที่เองด้วยคำสั่งเดียว; Bootstrap รัน MovementRulesTest เองตอน Play ใน Studio

**ความเสี่ยงที่รู้:**
- ค่าความทน (1.3×, 2.5 studs, 0.4 วินาที) ตั้งจากการคำนวณ ไม่ได้วัดกับ latency จริง network สะดุดนานอาจทำให้ถูกดึงกลับ (rubber-band) ผิดจังหวะ ถ้าพบบ่อยใน 2 clients ให้ขยับ `SlackStuds`/`PendingGraceSec` ก่อนแก้ logic
- ทะลุ cover (สูง 4) ด้วย noclip จะไม่ถูกจับ เพราะ probe ที่ยกขึ้นผ่านเหนือ cover ตั้งใจแลกกับการไม่จับผิดตอนกระโดด
- ไม่ตรวจแกน Y (กระโดด/ตก) ใน P1
- ยังไม่ตรวจ teleport-ตี-กลับ ระหว่าง sample (combat อาจใช้ตำแหน่ง pending) ต้องปิดก่อนเปิดให้คนนอกเล่น

**Mobile layout/gesture และ 2 clients:** A6 ผ่านบน iPhone XR simulator แนวนอน (ปุ่มครบ 4 ปุ่ม, แตะปุ่มกล้องไม่หมุน, ลากฉากกล้องหมุน) และ D1–D4 + E9 ผ่านบน server + 2 clients จริง ยังไม่ทดสอบมือถือจริง, portrait, multitouch พร้อมกัน


## Tasks completed

### P1-A Foundation + movement (source only)

- ตัวเลข P1 ทั้งหมดอยู่ใน `src/shared/Definitions/Prototype.luau`
- Types ตาม CONTRACTS v0.2 subset ที่ P1 ใช้ และตัวอย่าง packet
- `SceneService.Build()` สร้าง `Workspace/SpiritWardPrototype` แบบ idempotent: ลาน 100×100, low tier สูง 5 studs + ทางลาด, test wall, cover, ขอบล่องหน, โทริอิ 1 ชุด + โคมหิน 6 ต้นที่ขอบลาน, spawn, checkpoint, enemy spawn 3 จุด (หนึ่งจุดอยู่บน low tier)
- กล้องมาตรฐาน Roblox, zoom 6–32, occlusion แบบ Zoom; input desktop/gamepad/touch ผ่าน ContextActionService; ป้าย PROTOTYPE

### P1-B Combat + enemy (source only)

- **NetworkService**: สร้าง `ReplicatedStorage/Remotes` (ActionRequest/ActionResult/StateEvent) ตรวจ requestId ≤ 64 bytes, action whitelist, rate limit token bucket ตามตาราง contract, dedupe cache 120 วินาที (retry เดิมคืนผลเดิม, id เดิม payload ต่าง = INVALID_PAYLOAD), payload schema ต่อ action (key เกิน/ขาด/ผิดชนิด = INVALID_PAYLOAD), direction ตาม contract (finite, |Y| ≤ 0.01, magnitude 0.99–1.01 แล้ว normalize บน X/Z) และ handler error = INTERNAL_ERROR
- **PlayerStateService**: HP/alive/cooldowns/gauge ใน memory, snapshot เฉพาะเจ้าของพร้อม revision เป็น server session counter, `ready` ส่ง snapshot แรก, ตายล้าง gauge/transform แต่ไม่ล้าง cooldown, ปิด regen ของ Humanoid เพื่อไม่ให้ HP เพี้ยน
- **EnemyService**: ผีโคม 3 ตัว (spawn ละตัว, max 3), ไล่ผู้เล่นในระยะ 30 และ leash 25, หยุดเมื่อชนกำแพง, telegraph 0.8 วินาที (ตัวเปลี่ยนสี + วงบนพื้นกะพริบ + เสียง), ตรวจ hit ตอนจบ telegraph (ระยะ 6.5, height, line of sight) damage 10, recovery 1 วินาที, ตายครั้งเดียวต่อ runtime ID, เกิดใหม่ 8 วินาทีด้วย ID ใหม่, เก็บรายชื่อผู้ทำ damage และส่ง `OnDefeated` สำหรับ P1-C
- **CombatService**: basic 3 จังหวะ (damage 20, cadence 0.5 วินาที โดย server ยอมให้เร็วสุด 85% เผื่อ latency), skill `blade_sweep` (damage 30, arc 160°, cooldown 5 วินาที), dash (cooldown 1.5 วินาที) hit หาจากตำแหน่งตัวละครจริงบน server: ระยะถึงผิวศัตรู, arc หน้าทิศเล็ง, height ≤ 4 studs, line of sight เฉพาะ `Collision/` ไม่รับ target/damage/ตำแหน่งจาก client
- **Client**: NetworkClient (ready retry 5 ครั้ง, ทิ้ง snapshot เก่า), CombatController (combo 3 จังหวะ, soft aim cone 35° ไม่เพิ่มระยะ, หมุนตัวตามทิศ, dash ด้วย LinearVelocity 0.18 วินาที, ข้อความเมื่อถูกปฏิเสธ), EffectsController (เส้นฟัน 3 แบบ, วง sweep, spark ตอนโดน, จอแดงเมื่อโดนตี, เอฟเฟกต์ผีตาย, เสียง built-in)
- คาตานะ placeholder ติดมือ ไม่มี collision

### P1-C Soul + transformation + HUD (source only)

- **SpiritService**: รับ `EnemyDefeated` จาก death transition ครั้งเดียวของ EnemyService; ledger key `enemyRuntimeId:userId` ทำเครื่องหมายก่อน grant จึงไม่ได้รางวัลซ้ำ; ให้เฉพาะผู้ที่ทำ damage, ยัง alive และอยู่ในระยะ 120 studs (ไม่สน last hit) ได้ gauge +10 (ไม่เพิ่มระหว่างแปลงร่าง, cap 100) และ essence +5
- **transform**: ต้อง alive, gauge = 100, ไม่ได้แปลงอยู่ ใช้ gauge หมด, อยู่ 12 วินาทีตามเวลา server แล้วจบเอง; ตายระหว่างแปลงล้าง gauge/ร่าง/aura ทันที ไม่มีทางได้เวลาค้าง
- ระหว่างแปลงร่าง basic attack กลายเป็นคลื่นสั้น reach 10, damage 25, arc 90° ผ่าน `Geometry.InSector` เดิม (เช็กความสูงและกำแพงเหมือนเดิม)
- ภาพร่างผู้พิทักษ์: Highlight สีคราม-ขาว + แสงรอบตัว (placeholder) เห็นทุกคน
- **HUD** มุมซ้ายบน: HP, เกจวิญญาณ/เวลาแปลงร่างที่เหลือ, แก่นวิญญาณ, cooldown วิชา/พุ่ง, ข้อความ "พร้อมแปลงร่าง — กด R" กะพริบ และสถานะตาย อ่านจาก snapshot อย่างเดียว ไม่มีตัวเลขเกมฝังใน UI
- **Orb วิญญาณ** ลอยจากผีไปหาผู้ได้รางวัลเป็นภาพของ grant ที่เกิดแล้วเท่านั้น client ไม่มีทางขอรางวัล

### P1-D Integration + report (เตรียมแล้ว ยังไม่ได้รัน)

- `docs/qa/P1_RESULTS.md`: ตารางทดสอบ A/B/C/D ทุกแถวสถานะ ⏳, สคริปต์ Command Bar สำหรับ invalid payload, spam และ duplicate requestId, ช่อง 4 คำถาม Director
- ทบทวนโค้ดทั้ง loop ด้วยตาอีกรอบก่อนส่ง ไม่พบจุดที่ต้องแก้ก่อนเล่น
- **ยังขาด**: ผลเล่นจริง, 2 clients, touch, การแก้ blocker ที่จะเจอจากการรันครั้งแรก ส่วนนี้ต้องให้ผู้ใช้เล่นแล้วส่งผล/error กลับมา

## สรุปสถานะ

| ส่วน | Implemented | Tested | Unverified |
|---|---|---|---|
| Scene, spawn, checkpoint | ✅ | ✅ Codex Play Solo + Director | — |
| กล้อง + input desktop/touch | ✅ | ✅ desktop (Director โอเค) + iPhone XR simulator (A6) | มือถือจริง |
| Network validate/rate limit/dedupe | ✅ | ✅ B12, ◐ B13/C7 | TTK ระหว่าง spam |
| Combat + enemy AI | ✅ | ✅ B1–B13 + Director (ฟันโอเค, หลบได้) | B6/B7 ในฉากจริง |
| Soul reward + transform + HUD | ✅ | ✅ C1–C7 + Director ฆ่าครบ 10 และแปลงร่าง | — |
| Multiplayer 2 clients | ไม่มีโค้ดเฉพาะ (ใช้ระบบเดียวกัน) | ✅ D1–D4 + E9 (Studio 2 clients) | performance 8 players |
| Server movement authority (dash) | ✅ | ✅ E1–E9 + Director (บั๊กเด้งขึ้นฟ้าแก้แล้ว) | latency จริง, แกน Y, cover เตี้ย |

## Files changed

- `src/shared/Definitions/Prototype.luau` (ใหม่)
- `src/shared/Types/Contracts.luau`, `src/shared/Types/Examples.luau` (ใหม่)
- `src/server/Bootstrap.server.luau` (แทน scaffold)
- `src/server/Util/Geometry.luau` (ใหม่; รอบปัจจุบันเพิ่ม `PathClear`)
- `src/server/Util/MovementRules.luau`, `src/server/Services/MovementService.luau`, `src/server/Tests/MovementRulesTest.luau` (ใหม่, รอบปัจจุบัน)
- `src/server/Services/SceneService.luau`, `NetworkService.luau`, `PlayerStateService.luau`, `PlayerService.luau`, `EnemyService.luau`, `CombatService.luau`, `SpiritService.luau` (ใหม่)
- `src/client/Bootstrap.client.luau` (แทน scaffold)
- `src/client/Controllers/NetworkClient.luau`, `CameraController.luau`, `InputController.luau`, `CombatController.luau`, `EffectsController.luau`, `HUDController.luau`, `PrototypeBannerController.luau` (ใหม่)
- `tools/ROJO_SETUP.md` (ใหม่)
- `docs/qa/P1_RESULTS.md` (ใหม่)
- `assets/ASSET_MANIFEST.md` (เพิ่มตาราง placeholder P1)
- `handoff/CLAUDE_DELIVERY.md` (ไฟล์นี้)

ไม่แก้ `default.project.json`, `Project.luau`, `docs/*` ของ Codex หรือ `work/`

## Validation performed

- อ่านโค้ดตรวจเทียบ brief/contracts ด้วยตนเอง
- **ยังไม่ได้**: compile/analyze Luau (เครื่องมือ Luau ใช้ในเครื่อง Claude ไม่ได้), เปิด Studio, Play, 2 clients, spam/invalid payload, device emulator หรือมือถือจริง ทุกข้อจึงเป็น unverified

## วิธีเปิดเล่น

ทำตาม `tools/ROJO_SETUP.md` แล้วกด Play ใน Studio

## Director ลองใน 5 นาที

1. เกิดทางใต้ของลาน เห็นป้าย PROTOTYPE และคาตานะในมือ
2. เดิน/กระโดด/ขึ้นทางลาดไปบน low tier; ชิด test wall แล้วหมุนกล้อง กล้องไม่ควรทะลุกำแพง
3. เดินหาผีโคม: มันควรลอยเข้ามา, ตัวเปลี่ยนเป็นสีส้มพร้อมวงบนพื้นก่อนตี, ถอยออกนอกวงทันควรไม่โดน
4. คลิกซ้ายฟัน 3 ครั้งติด ผีควรตายใน 3 hit มี spark และหลอด HP ลด ผีเกิดใหม่หลัง 8 วินาที
5. กด E (sweep) แล้วกดซ้ำทันที ควรขึ้น "ยังติดคูลดาวน์"
6. กด Q (dash) ไปทางกำแพง ไม่ควรทะลุ
7. ยืนหลัง test wall แล้วฟันผีที่อยู่อีกฝั่ง ไม่ควรโดน; ยืนใต้ low tier แล้วฟันผีบนชั้น ไม่ควรโดน
8. ปล่อยให้ผีตีจนตาย ควรเกิดใหม่ที่ spawn หรือ checkpoint ล่าสุดใน 3 วินาที
9. ฆ่าผีแล้วดู orb ลอยเข้าตัว เกจวิญญาณ +10 และแก่นวิญญาณ +5 ทุกตัว
10. ครบ 10 ตัวจะขึ้น "พร้อมแปลงร่าง — กด R" กด R แล้วตัวเรืองแสง ฟันเป็นคลื่นยาวขึ้น ดูเวลานับถอยหลัง 12 วินาทีแล้วกลับร่างเดิม
11. ลองตายระหว่างแปลงร่าง เกจและร่างต้องหายทันที
12. Test → Clients and Servers 2 players: ทั้งสองเห็นผีตัวเดียวกัน ตีผีตัวเดียวกันแล้วได้รางวัลทั้งคู่ ไม่ซ้ำ
13. ส่ง error ใน Output (ถ้ามี) กลับมา

ทางลัดทดสอบ: ลดเวลาเก็บ 10 ตัวได้ชั่วคราวโดยแก้ `Spirit.GaugePerDefeat` ใน `Prototype.luau` เป็น 50 แล้วอย่าลืมคืนค่า

## Assumptions and proposed contract changes

- **DEC-002 (เสนอ):** Rojo 7 กับ `default.project.json` เดิม; สคริปต์แก้ใน `src/` เท่านั้น Codex บันทึกใน `docs/DECISIONS.md` เมื่อเห็นชอบ
- ฉากสร้างตอน server เริ่ม ไม่บันทึกลง place file; ปรับ `Lighting` และเพิ่ม Atmosphere ของตัวเอง
- **Dash**: client ยังเคลื่อนตัวเพื่อความลื่น แต่ server เป็นผู้กำหนดระยะ/ทิศ/เส้นทาง/เวลา และ reconcile ผ่าน MovementService (รอบหลัง Codex review)
- `PublicOwnProfile` ใน P1 มีแค่ `classId`, `essence` (subset ของ ProfileV1); transform ที่ gauge ไม่เต็มหรือแปลงอยู่แล้วตอบ NOT_READY เพราะ contract ไม่มี code เฉพาะ
- essence ต่อ kill = 5 และ arc คลื่น 90° เป็นค่าที่ Claude ตั้งเอง brief ไม่ได้ระบุ
- field ใหม่ใน `Prototype.luau` นอกตาราง brief (arc, cadence tolerance, detection/leash/speed/hover ของผี ฯลฯ) เป็นค่าเริ่มต้องปรับหลัง playtest
- ไม่มีข้อเสนอเปลี่ยน contract shape ใน batch นี้

## Known issues and next handoff

- ทิศของทางลาด (WedgePart) และตำแหน่งคาตานะในมือยังไม่ได้ตรวจในฉาก
- ไม่มี animation asset ท่าฟันเป็นเอฟเฟกต์ placeholder ล้วน
- ผีบน low tier ลอยออกนอกขอบชั้นได้ภายใน leash (ลอยกลางอากาศ) ยังไม่มี pathfinding
- เสียงเป็น built-in ของ Roblox ต้องแทนก่อน publish
- ~~`NetworkService` ลบ `Remotes` เดิม~~ Codex แก้แล้วเป็น `SpiritWardRemotes` + `OwnedBy=SpiritWard`
- ร่างผู้พิทักษ์ใช้แค่ Highlight ยังไม่มีหน้ากาก/ลายอาคมตาม art direction
- ~~ถัดไป: Codex รัน E1–E9, A6, D1–D4 ใน Studio~~ ผ่านแล้ว 27 ต.ค. 2026
- Director (27 ต.ค.): 4 คำถามโอเคทุกข้อ, ภาพ/เสียงรับได้, ถอยหลบวงเตือน ฆ่าครบ 10 ตัว และแปลงร่างได้จริง
- ~~บั๊กพุ่งชนกำแพงแล้วเด้งขึ้นฟ้า~~ แก้ใน `CombatController.dash` (หยุดหน้ากำแพงด้วย spherecast, MaxForce ตามมวล, ตัดความเร็วขึ้นที่ dash สร้าง) Director ลองโค้ดใหม่แล้วยืนยันว่าหายจริง 27 ต.ค.
- **P1 ปิดแล้ว 27 ต.ค. 2026** ที่เหลือเป็น backlog ก่อน public testing
- ยังไม่รัน: B6/B7 ในฉากจริง, มือถือจริง, performance 8 players (รายการเต็มใน `docs/qa/P1_RESULTS.md` หัวข้อ "ยังไม่ได้ทดสอบ")
