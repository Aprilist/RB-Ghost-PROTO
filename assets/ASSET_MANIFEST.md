# Asset manifest

สถานะ: ยังไม่มี production asset นำเข้า ใช้ greybox ใน M0/M1

ธีม: ญี่ปุ่นแฟนตาซี, กล้อง 3D บุคคลที่สาม อ้างอิง `docs/ART_DIRECTION.md` ก่อนสร้าง asset; hero_blade ใช้คาตานะ, environment เป็นหมู่บ้านไม้/ป่าไผ่/ศาลเจ้าร้าง ทุกโมเดลต้องตรวจจากมุมกล้องรอบตัว

| Logical ID | ประเภท | ระยะ | เจ้าของ/ที่มา | Roblox asset ID | สถานะ |
|---|---|---|---|---|---|
| hero_blade | character/animations | M1 | TBD | TBD | planned |
| lantern_wisp | enemy | M1 | TBD | TBD | planned |
| guardian_form | transformation/VFX | M1 | TBD | TBD | planned |
| mistwood_set | environment | M2 | TBD | TBD | planned |
| shrine_set | environment | M2 | TBD | TBD | planned |
| extinguished_keeper | boss/animations | M2 | TBD | TBD | planned |

ทุก asset ที่รับเข้าให้เพิ่ม source/license หรือข้อมูลการสร้างเอง, dimensions/pivot, collision, animation IDs และผู้ตรวจ หลีกเลี่ยงฝัง script ที่ไม่ผ่าน review ใน model

## P1 placeholders (styled greybox)

ทุกชิ้นสร้างจาก Part พื้นฐานในโค้ด `src/server/Services/SceneService.luau` ไม่มี mesh, texture หรือเสียงนำเข้า ส่วนตกแต่งอยู่ใน `Workspace/SpiritWardPrototype/Decor` (CanCollide/CanQuery/CanTouch ปิด, attribute `Placeholder = true`) และ collision อยู่ใน `.../Collision` แยกกัน เปลี่ยนภาพได้โดยไม่แตะ collision หรือ markers

| Logical ID | ประเภท | ระยะ | เจ้าของ/ที่มา | Roblox asset ID | สถานะ |
|---|---|---|---|---|---|
| p1_arena_floor | environment greybox | P1 | สร้างเองในโค้ด (Claude) | none | placeholder |
| p1_low_tier_ramp | environment greybox | P1 | สร้างเองในโค้ด (Claude) | none | placeholder |
| p1_test_wall_cover | environment greybox | P1 | สร้างเองในโค้ด (Claude) | none | placeholder |
| p1_torii | decor, primitive parts | P1 | สร้างเองในโค้ด (Claude) | none | placeholder |
| p1_stone_lantern | decor + PointLight | P1 | สร้างเองในโค้ด (Claude) | none | placeholder |
| p1_atmosphere | lighting | P1 | สร้างเองในโค้ด (Claude) | none | placeholder |
| p1_katana | weapon visual, primitive parts | P1 | สร้างเองในโค้ด `PlayerService.luau` (Claude); ไม่มี collision/query | none | placeholder |
| p1_lantern_wisp | enemy, primitive parts + BillboardGui HP | P1 | สร้างเองในโค้ด `EnemyService.luau` (Claude) | none | placeholder |
| p1_combat_fx | neon fade parts | P1 | สร้างเองในโค้ด `EffectsController.luau` (Claude) | none | placeholder |
| p1_sfx_builtin | เสียง swordslash, swordlunge, electronicpingshort | P1 | เสียง built-in ของ Roblox client (`rbxasset://sounds/...`) ใช้ทดสอบเท่านั้น ต้องแทนก่อน publish | none | placeholder |
| p1_guardian_form | transform visual: Highlight + PointLight | P1 | สร้างเองในโค้ด `SpiritService.luau` (Claude) | none | placeholder |
| p1_soul_orb | neon ball fx | P1 | สร้างเองในโค้ด `EffectsController.luau` (Claude) | none | placeholder |
| p1_hud | ScreenGui | P1 | สร้างเองในโค้ด `HUDController.luau` (Claude) | none | placeholder |

## VB-01 shrine courtyard (visual benchmark batch 1)

ทุกชิ้นสร้างเองในโค้ด `src/server/Scene/ShrineCourtyard.luau` (Claude) จาก Part/WedgePart/Cylinder และ SpecialMesh ทรง Sphere ไม่มี mesh, texture, decal หรือเสียงนำเข้า อยู่ใน `Workspace/SpiritWardPrototype/Decor` ทั้งหมด CanCollide/CanQuery/CanTouch ปิด attribute `Placeholder = true`; ผิวที่หุ้ม collider มี attribute `Dresses = <ชื่อ collider>` สร้างซ้ำได้แบบ deterministic (seed คงที่)

| Logical ID | ประเภท | ระยะ | เจ้าของ/ที่มา | Roblox asset ID | สถานะ |
|---|---|---|---|---|---|
| vb01_torii | decor (myōjin torii, shimenawa, shide) | VB-01 | สร้างเองในโค้ด (Claude); collision = ToriiPillarProxy เดิม | none | benchmark draft |
| vb01_stone_lantern | decor + PointLight | VB-01 | สร้างเองในโค้ด (Claude); collision = LanternProxy เดิม 6 ต้น, อีก 6 ต้นอยู่นอกลาน | none | benchmark draft |
| vb01_ground | gravel overlay, sandō flagstones, tobiishi, moss, outer ground | VB-01 | สร้างเองในโค้ด (Claude) | none | benchmark draft |
| vb01_garden_edge | stone wall, wall lamps, shrubs, red fence (นอก bounds, สูงไม่เกิน 3.5) | VB-01 | สร้างเองในโค้ด (Claude) | none | benchmark draft |
| vb01_backdrop | bamboo grove, honden, sugi, distant peaks (ห่างขอบลาน ≥ 36 studs) | VB-01 | สร้างเองในโค้ด (Claude) | none | benchmark draft |
| vb01_dressing | หุ้มผิว TestWall (tsuiji-bei), LowTier, LowTierRamp, Cover | VB-01 | สร้างเองในโค้ด (Claude); ไม่เปลี่ยน collider | none | benchmark draft |
| vb01_lighting | Lighting props, Atmosphere, Bloom, ColorCorrection ชื่อ `SpiritWardPrototype*` | VB-01 | สร้างเองในโค้ด `SceneService.luau` (Claude) | none | benchmark draft |

## VB-01 actors and FX (visual benchmark batch 2)

สร้างเองในโค้ดทั้งหมด (Claude) จาก Part/WedgePart/Cylinder/SpecialMesh Sphere ไม่มี mesh, texture หรือเสียงนำเข้า สีจาก `src/shared/Definitions/VisualPalette.luau`

| Logical ID | ประเภท | ระยะ | เจ้าของ/ที่มา | Roblox asset ID | สถานะ |
|---|---|---|---|---|---|
| vb01_katana | weapon visual 15 parts, welded to RightHand; ไม่มี collision/query/touch | VB-01 | `PlayerService.luau` (Claude) แทน p1_katana | none | benchmark draft |
| vb01_saya | empty scabbard 4 parts, welded to LowerTorso/Torso | VB-01 | `PlayerService.luau` (Claude) | none | benchmark draft |
| vb01_lantern_wisp | enemy visual 18 parts + telegraph rim/fill | VB-01 | `EnemyService.luau` (Claude) แทน p1_lantern_wisp; hit/AI ใช้ Body เดิม | none | benchmark draft |
| vb01_guardian_mask | transform visual 6 parts welded to Head + Highlight + PointLight | VB-01 | `SpiritService.luau` (Claude) ต่อจาก p1_guardian_form | none | benchmark draft |
| vb01_combat_fx | slash core, soul orb halo, transform ring/column, ember death | VB-01 | `EffectsController.luau` (Claude) แทน p1_combat_fx/p1_soul_orb | none | benchmark draft |

## M2-C Mistwood enemies

สร้างเองในโค้ด `src/server/Enemies/Models.luau` (Claude) จาก Part/Cylinder/SpecialMesh Sphere ไม่มี mesh, texture หรือเสียงนำเข้า สีจาก `VisualPalette.luau` ทุกชิ้นไม่มี collision/query/touch; AI และการโดนตีใช้ `Body` (PrimaryPart) อย่างเดียว ป้ายเตือนบนพื้นสร้างใน `EnemyService.luau` ตามรูปทรงท่าโจมตี ผีโคม (vb01_lantern_wisp) ย้ายมาไฟล์นี้โดยหน้าตาเหมือนเดิม

| Logical ID | ประเภท | ระยะ | เจ้าของ/ที่มา | Roblox asset ID | สถานะ |
|---|---|---|---|---|---|
| m2c_hitodama | enemy visual 10 parts + PointLight, ป้ายเตือนแถบตรง | M2-C | `Enemies/Models.luau` (Claude) | none | greybox |
| m2c_kodama | enemy visual 13 parts + PointLight, ป้ายเตือนวงรอบตัว | M2-C | `Enemies/Models.luau` (Claude) | none | greybox |
| m2c_karakasa | enemy visual 20 parts, ป้ายเตือนวงตรงจุดลง | M2-C | `Enemies/Models.luau` (Claude) | none | greybox |
