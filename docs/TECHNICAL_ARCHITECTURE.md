# Technical Architecture v0.2

## แหล่งความจริง

Luau source ใน `src/` เป็นแหล่งโค้ดหลัก Roblox Studio เป็นแหล่งแผนที่/โมเดลก่อนตั้ง asset pipeline เต็มรูปแบบ ห้ามซ่อน business logic ในโมเดล map

`ReplicatedStorage/Shared` เก็บ public definitions/types; ไม่ใส่ข้อมูลลับหรือ profile ของผู้เล่นทั้งหมด client อ่านค่าต่อสู้เพื่อแสดงผลได้ แต่ไม่มีสิทธิ์ยืนยันผล

## ระบบที่วางแผนไว้

| Server service | หน้าที่ | Dependency หลัก |
|---|---|---|
| PlayerDataService | load, migration, session ownership, save, release | DataStore adapter |
| PlayerStateService | HP, gauge, cooldown, alive/ready state | profile, definitions |
| CombatService | validate intent, hit geometry, damage, contribution | state, enemy, definitions |
| EnemyService | spawn, AI, death, respawn, encounter membership | combat/state |
| RewardService | grant ครั้งเดียวต่อ kill, currency/EXP | profile/state |
| SpiritService | gauge และ transform lifecycle | state/combat |
| InventoryService | item ID และ equipped weapon | profile/definitions |
| UpgradeService | validate shrine, cost, ผนึก, atomic mutation | inventory/profile |
| QuestService | progress จาก server domain events, claim | reward/profile |
| NetworkService | remote creation, validation, rate limits, response | service handlers |

ตารางเป็นแผน ไม่ใช่ modules ที่สร้างแล้ว หลีกเลี่ยง framework/DI container สำหรับต้นแบบ Bootstrap ใช้ require และ dependency injection แบบ explicit สร้าง service ทั้งหมด → Init dependencies → Start ตามลำดับ ห้าม require วนกัน

Server ส่ง domain event เช่น EnemyDefeated ให้ reward/quest ผ่าน coordinator หรือ signal ภายใน server ไม่ใช้ remote วนกลับมาทำ business logic

| Client controller | หน้าที่ | เจ้าของ implementation |
|---|---|---|
| InputController | keyboard/touch → canonical actions | Claude |
| CameraController | follow, boundaries, reduce shake | Claude |
| CombatController | prediction ภาพ/animation, reconcile | Claude |
| HUDController | snapshot, HP/gauge/cooldown | Claude |
| QuestController | tracker และการขอ claim | Claude |
| EffectsController | orb, hit, transform และ cleanup | Claude |

Client เริ่มเมื่อ remotes พร้อมและ initial snapshot สำเร็จ UI แสดง loading/failure แทนการค้าง WaitForChild ไม่สิ้นสุด Controllers ไม่แก้ currency หรือสร้างรางวัลเอง

## โลกและการเคลื่อนที่

Workspace/World เป็น authored map; Workspace/Runtime เป็นของเกิดระหว่างเล่น Tags ที่ตกลง: EnemySpawn, Checkpoint, Shrine, CameraBounds, BossEntrance แต่ละจุดมี stable attribute ID ไม่ใช้ชื่อ model เป็น database key

3D บุคคลที่สาม: เดินบน X/Z กระโดดแนว Y กล้องหมุน/ซูมและหลบ geometry; server ตรวจระยะ ความต่างระดับ สิ่งกีดขวาง ความเร็วที่ผิดปกติ และตำแหน่งก่อน damage แม้ client มี network ownership ของตัวละคร Melee ใช้ volume ด้านหน้าตาม aimDirection และนิยามอาวุธ พร้อม line-of-sight check; dash ตรวจเส้นทางไม่ให้ข้ามผนัง

Client คำนวณ aimDirection จากทิศกล้องบนพื้นและ soft aim ภายใน cone ตาม config; server ตรวจ finite/unit vector และใช้ตัวละครจริงเป็นจุดเริ่ม ไม่รับ hit position หรือ damage ที่ client ยืนยัน ศัตรูบนชั้นอื่นหรือหลังผนังไม่ติด soft aim การเดินหลบสิ่งกีดขวางของ AI ใช้ waypoint/pathfinding ตามความจำเป็นของแผนที่ ต้องทดสอบ navmesh ใน greybox

## Data และ persistence

แยก memory adapter สำหรับ Studio offline กับ persistence adapter สำหรับ private test environment เห็นป้ายโหมดทดสอบชัด อย่าเปิดเขียน production store ระหว่างพัฒนา

profile ใช้หนึ่ง key ต่อ UserId; UpdateAsync callback ไม่มี side effects และไม่ yield ใช้ session lease/fencing token ที่ออกแบบและทดสอบก่อนใช้หลายเซิร์ฟเวอร์ ห้ามถือว่า UpdateAsync อย่างเดียวป้องกัน stale session ได้

Load ล้มเหลว: ไม่สร้าง default แล้ว save ทับข้อมูลเดิม ผู้เล่นค้างใน loading พร้อม retry แบบจำกัดและข้อความให้กลับเข้าใหม่ ถ้าเสีย lease ให้หยุด progression และออกจาก session อย่างควบคุม

mutation ต่อผู้เล่นผ่าน queue เดียว; upgrade หักต้นทุนและแก้ weapon ใน mutation เดียว autosave แบบทยอย ประมาณ 60–120 วินาที พร้อม retry/backoff ตาม budget, save on leave และ shutdown แบบ best effort การล่มก่อน save อาจ rollback ระยะสั้น ต้องระบุในการทดสอบก่อนเปิดสาธารณะ

## ความปลอดภัยและประสิทธิภาพ

ตรวจ types, finite numbers, enum, length, whitelist IDs, ownership, cooldown, distance และ player readiness server-side ทุกครั้ง ไม่รับ damage/reward/price จาก client กำหนด rate limit ราย action ตาม contracts

ส่ง profile snapshot เฉพาะเจ้าของ; คนอื่นเห็นเฉพาะ public combat effects ใช้ enemy updates ตามพื้นที่เมื่อจำเป็น ไม่ส่ง full world ทุก frame AI ใช้ tick เป็นช่วงและมีเพดาน spawn ทดสอบ load จริงก่อนเลือกความถี่ขั้นสุดท้าย

เริ่มต้นเป้าหมาย playtest: desktop 60 FPS / mobile 30 FPS ในพื้นที่ slice เป็น target ไม่ใช่รับรอง performance เก็บจำนวน enemies, network traffic, memory และ frame time ตอนทดสอบ 8 clients

## อ้างอิงที่ตรวจวันที่ 27 ตุลาคม 2026

- [Client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- [Remote events](https://create.roblox.com/docs/scripting/events/remote)
- [Data stores](https://create.roblox.com/docs/cloud-services/data-stores)
- [External tooling และ sync](https://create.roblox.com/docs/projects/external-tools)

ความเห็นเรื่อง service decomposition, 3D targeting, task ownership และตัวเลขเป็นการออกแบบของโปรเจกต์นี้
