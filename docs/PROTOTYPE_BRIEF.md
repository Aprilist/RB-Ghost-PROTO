# P1 — Playable combat prototype

วันที่ 27 ตุลาคม 2026 | Design/review/implementation: Claude (DEC-015) | Director: ผู้ใช้

## เป้าหมายตรวจรับ

ผู้ใช้เปิดฉากทดลอง 3D บุคคลที่สาม เดิน/กระโดด/พุ่ง ฟันคาตานะใส่ผีโคม ดูดวิญญาณจนแปลงร่าง แล้วกลับสู้ต่อได้ ทั้ง desktop และ touch นี่เป็น prototype สำหรับหาความสนุก ไม่ใช่ vertical slice ที่มีระบบครบ

## งานภาพที่ทำตอนนี้

ใช้ styled greybox: พื้นลานหินเรียบ ฉากหลังคราม โคมไฟสีอำพัน โทริอิประกอบจากชิ้นส่วนพื้นฐานหนึ่งชุด ผีโคมทรงง่าย และคาตานะ placeholder การฟันมีเอฟเฟกต์สั้น เสียงชั่วคราวที่มีสิทธิ์ใช้ และ hit feedback สื่อว่าโจมตีโดนได้

ต้องแยกส่วนตกแต่งออกจาก collision/hitbox ใช้ manifest บันทึกว่าเป็น placeholder ทุก asset เปลี่ยนภาพภายหลังโดยไม่แก้ reward/combat logic ไม่ใช้ mesh generation หรือสร้าง asset รายละเอียดสูงก่อนเล่น core loop ผ่าน

ไม่ต้องมีหมู่บ้านเต็ม ป่าเต็ม บอส เควสต์ ระบบคลาสหลายอาชีพ seal upgrade, persistence หรือร้านค้า P1 ใช้ state ใน memory เท่านั้นและติดป้าย “PROTOTYPE — progress resets” ชัด

## สนามทดลอง

- ลานประมาณ 100 × 100 studs พื้นต่างระดับเตี้ยหนึ่งจุด กำแพงทดสอบหนึ่งชุด และที่กำบังหนึ่งชิ้น
- spawn ผู้เล่น, checkpoint, enemy spawn 3 จุด; จำกัดผีเกิดพร้อมกัน 3 ตัว
- องค์ประกอบญี่ปุ่นอยู่ขอบลาน ไม่บังกล้องหรือกินเวลาเดินไปต่อสู้
- สร้าง scene ใน namespace `SpiritWardPrototype` อย่าง idempotent ไม่ล้าง Workspace หรือแก้งานผู้ใช้ที่อื่น
- มีวิธีสร้าง scene ซ้ำจาก source/setup script ที่ตรวจได้; ไม่พึ่ง manual changes ที่ไม่มีบันทึก

## ค่าทดลองตั้งต้น

| ค่า | ค่าเริ่ม | เหตุผล |
|---|---|---|
| Player HP | 100 | ทดสอบตาย/เกิดใหม่ง่าย |
| Enemy HP | 60 | ตายใน 3 hit เมื่อ damage 20 |
| Basic damage / interval | 20 / 0.5 sec | จังหวะอ่านง่ายก่อนเพิ่ม combo modifiers |
| Basic reach | 7 studs | ตรวจซ้ำกับ animation/ขนาดตัว |
| Blade skill | sweep, damage 30, cooldown 5 sec | ทดลองความต่างจาก basic |
| Dash | 12 studs / cooldown 1.5 sec | ไม่มี invulnerability และไม่ผ่านกำแพง |
| Enemy attack | damage 10, telegraph 0.8 sec, recovery 1 sec | เปิดช่องให้หลบ |
| Gauge per defeat | 10 | 10 defeats ได้แปลงร่างหนึ่งครั้ง |
| Transform | gauge 100, duration 12 sec | ระหว่าง active ไม่เพิ่ม gauge |
| Transform attack | คลื่นสั้น, reach 10 studs, damage 25 | ภาพและระยะต่าง แต่ใช้ pipeline ตรวจ hit เดิม |
| Respawn | enemy 8 sec, player 3 sec | ตาม shared contracts |

ค่าทั้งหมดใส่ `src/shared/Definitions/Prototype.luau` โดย Claude เป็นผู้สร้าง ห้ามฝังซ้ำใน UI ตัวเลขเป็น hypothesis ต้องปรับหลังผู้ใช้ทดลอง

## ลำดับส่งงาน

### P1-A — Foundation + movement

เลือกวิธี sync และบันทึก DEC-002 ตรวจว่ามีเครื่องมือก่อนติดตั้งอะไร หากยัง sync ไม่ได้ ให้ส่ง setup ที่ทำซ้ำได้และระบุ blocker จริง ออกแบบ snapshot/types ของ P1 ให้ตรง contracts สร้าง scene, กล้องบุคคลที่สามและ input desktop/touch ใช้การควบคุมมาตรฐานได้หากเพียงพอ ไม่สร้างระบบเดินใหม่โดยไม่มีเหตุผล

ผ่านเมื่อเดิน/กระโดด/หมุนกล้องในลานได้ มี camera collision และจอมือถือไม่แย่ง camera gesture กับปุ่มต่อสู้ ตรวจ play mode ก่อนส่ง P1-B หากไม่มี Studio ให้ระบุ unverified และส่ง source ต่อได้เฉพาะส่วนที่ไม่ต้องอ้างว่าผ่าน gate

### P1-B — Combat + enemy

เขียน Enemy/Combat/Network/PlayerState services และ client animation/feedback ผีมี telegraph, attack, death และ respawn Server คำนวณ hit/rewards ทิศโจมตีตรวจ Vector3, ระยะ, height และ line of sight ไม่รับ damage จาก client ทำ basic combo ภาพสามจังหวะและ skill sweep หนึ่งวิชา

ผ่านเมื่อโดน/ไม่โดนสอดคล้องกับท่า ไม่ตีทะลุกำแพงหรือคนละชั้น ทดสอบ spam/invalid payload และ multiplayer อย่างน้อย 2 clients

### P1-C — Soul + transformation + HUD

gauge และ essence มาจาก server death ครั้งเดียว orb เป็นภาพ HUD แสดง HP/gauge/cooldown; transform พร้อมเอฟเฟกต์และท่าโจมตีคลื่นสั้นตามเวลา Talisman/shade, full inventory และ save ไม่มีใน P1

ผ่านเมื่อ 10 defeats เปิด transform ได้ จบใน 12 วินาที ตายล้าง gauge/range effect และไม่รับรางวัลซ้ำจาก duplicated death/request

### P1-D — Integration + report

เล่นครบ loop, ทดสอบเกิดใหม่/กล้องหลังผนัง/soft aim/2 clients/touch แก้ blockers สร้าง `docs/qa/P1_RESULTS.md` และเติม `handoff/CLAUDE_DELIVERY.md` แยก implemented, tested และ unverified ระบุวิธีเปิดฉากและสิ่งที่ Director ควรทดลองภายใน 5 นาที

## ขอบเขต contracts ที่ใช้ใน P1

ใช้ ready/basic_attack/cast_skill/dash/transform และ snapshot/combat_fx ตาม `docs/CONTRACTS.md`; claim_quest/apply_seal/profile lease ยังไม่ implement จึงไม่ต้องรอ DEC-008

P1 snapshot revision เป็น server session counter เพิ่มเมื่อส่ง authoritative state ใหม่; client ทิ้ง snapshot เก่า Progress reset เมื่อออก ไม่ใช้ persistent revision/fencing token ใน prototype กรณี profile ค่อยตรึงใน milestone persistence

Claude สร้าง `src/shared/Types` และตัวอย่าง packet สำหรับ P1 ได้ตาม contract หากต้องเปลี่ยน shape ให้เขียน `handoff/P1_CONTRACT_PROPOSALS.md` อธิบายผลกระทบก่อนเปลี่ยน dependent code ไม่ยกระบบ persistence เกินจำเป็นเพื่อทำ P1

## Director playtest

ขอ feedback 4 ข้อ: กล้องสบายหรือไม่, เดิน/พุ่งคุมได้หรือไม่, ฟันรู้สึกโดนหรือไม่, แปลงร่างแล้วอยากใช้ต่อหรือไม่ ถ้า core loop ยังไม่สนุกให้แก้ก่อนผลิตงานภาพละเอียด

## เงื่อนไขเริ่มทำภาพจริง

กล้อง ระยะอาวุธ ขนาดตัวละคร ขนาดลาน และจังหวะโจมตีผ่าน playtest ผู้ใช้แล้ว จากนั้น polish เพียงลานหนึ่งมุม ตัวละครหนึ่งชุด ศัตรูหนึ่งชนิด และท่าแปลงหนึ่งแบบเพื่อเป็น visual benchmark ก่อนผลิตทั้งโลก
