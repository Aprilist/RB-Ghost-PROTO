# P1 Results — Spirit Ward playable prototype

สถานะ: **P1-E local validation และ mobile simulator/2-client tests รันแล้ว** (27 ต.ค. 2026) ดู P1E_CODEX_REVIEW.md และ evidence/P1E_RUNTIME.json; มือถือจริง/latency สูงยังไม่ผ่าน

## สภาพแวดล้อม (เติมตอนทดสอบ)

| รายการ | ค่า |
|---|---|
| Roblox Studio version | engine 0.744.0.7441077 |
| Rojo CLI / plugin | CLI 7.7.1 build ผ่าน; plugin ตามรายงาน Claude |
| Place | Place1; Play Solo 1 player และ Server + 2 clients (P1-E) |
| Device ที่ใช้ทดสอบ touch | iPhone XR landscape simulator (801×413); เครื่องจริงยังไม่ทดสอบ |
| ผู้ทดสอบ | Codex ผ่าน Studio MCP; Director feedback ยังว่าง |

## ผลทดสอบ

ผล: ✅ ผ่านตามวิธีที่ระบุ · ◐ ตรวจบางส่วน/ใช้ fixture · ❌ ไม่ผ่าน · ⏳ ยังไม่รัน

### P1-A Movement + camera

| # | ทดสอบ | คาดหวัง | ผล |
|---|---|---|---|
| A1 | กด Play | Output มี `[SpiritWard] P1 server started` และ `P1 client started` ไม่มี error สีแดง | ◐ bootstrap ผ่าน ไม่มี P1 exception; มี asset-type warning เดิม |
| A2 | เกิด | อยู่บนแผ่นฟ้าทางใต้ของลาน เห็นป้าย PROTOTYPE, HUD มุมซ้ายบน, คาตานะในมือ | ◐ พบ HUD/state และ Katana 3 parts; ภาพรอ Director |
| A3 | เดิน/กระโดด/ขึ้นทางลาดไป low tier | ขึ้นได้ ไม่ติด | ◐ รอบ P1-A ผ่าน; ไม่เดินซ้ำในรอบนี้ |
| A4 | ยืนชิด test wall แล้วหมุนกล้อง | กล้องซูมเข้าหลบกำแพง ไม่ทะลุ | ◐ รอบ P1-A ผ่านหนึ่งสถานการณ์; รอบนี้ยังไม่ตรวจซ้ำ |
| A5 | เดินผ่านแผ่นอำพันทางตะวันตก แล้ว Reset | เกิดที่ checkpoint ใน ~3 วินาที | ◐ checkpoint ผ่านรอบ P1-A; death/respawn ใหม่ผ่าน |
| A6 | Device emulator: ลากกล้องด้วยนิ้ว แล้วกดปุ่ม ฟัน/วิชา/พุ่ง/แปลง | ปุ่มทำงาน กล้องไม่หมุนตอนกดปุ่ม ปุ่มไม่บังจอยสติก | ✅ iPhone XR simulator: ปรับปุ่ม 2×2 แล้วแตะครบ กล้องแยกจากปุ่ม; ยังไม่ทดสอบ multitouch/เครื่องจริง |

### P1-B Combat + enemy

| # | ทดสอบ | คาดหวัง | ผล |
|---|---|---|---|
| B1 | เข้าใกล้ผีโคม | ลอยเข้าหา ก่อนตีตัวเป็นสีส้ม + วงบนพื้นกะพริบ + เสียงเตือน | ◐ มี telegraph/attack events; ภาพ/เสียงรอ Director |
| B2 | ถอยออกนอกวงระหว่างเตือน | ไม่โดน damage | ✅ Director ถอยหลบได้ (27 ต.ค.) |
| B3 | ยืนในวงจนจบเตือน | HP -10, จอแดงแวบ | ◐ HP 100→90 และ player_hit event; ภาพจอแดงยังไม่รับรอง |
| B4 | คลิกซ้าย 3 ครั้งใส่ผี | เส้นฟัน 3 แบบ, spark ตอนโดน, ผีตายใน 3 hit | ◐ ส่ง remote จริง HP 60→40→20→0; retry ไม่ตีซ้ำ; รูปแบบภาพรอตรวจ |
| B5 | ฟันอากาศ (ไม่มีผีด้านหน้า) | ไม่มีผีตัวไหนเสีย HP | ◐ geometry helper ปฏิเสธเป้าหมายหลังตัว/นอกระยะ |
| B6 | ยืนหลัง test wall ฟันผีอีกฝั่ง | ไม่โดน | ◐ geometry helper wall=false; ยังไม่เล่นกรณีผีหลัง wall จริง |
| B7 | ยืนใต้ low tier ฟันผีบนชั้น | ไม่โดน | ◐ geometry helper height=false; ยังไม่เล่นกรณีนี้จริง |
| B8 | กด E แล้วกดซ้ำทันที | ครั้งแรก sweep ออก ครั้งสองขึ้น "ยังติดคูลดาวน์" HUD นับถอยหลัง 5 วิ | ◐ real remote ได้ OK แล้ว COOLDOWN; HUD countdown ยังไม่ประเมิน |
| B9 | กด Q พุ่งไปหากำแพง | ไม่ทะลุ, cooldown 1.5 วิ | ✅ กด Q จริงหยุดที่ Z≈-8.018 หน้า wall; server movement guard ยังขาด |
| B10 | ผีตาย | หายไป เกิดใหม่จุดเดิมหลัง ~8 วินาที ไม่เกิน 3 ตัวพร้อมกัน | ◐ พบ runtime IDs ใหม่และจำนวน 3; ไม่วัดเวลา 8 วิอย่างเจาะจง |
| B11 | ปล่อยให้ผีตีจนตาย | เกิดใหม่ใน 3 วินาที cooldown ไม่ถูกรีเซ็ต | ◐ force death/respawn ผ่าน และ cooldown key คงอยู่; ไม่รอศัตรูตีจนตายใน test นี้ |
| B12 | สคริปต์ invalid payload (ด้านล่าง) | ทุกข้อได้ code ตามคาด | ✅ 9 invalid cases รวม zero/Infinity ได้ INVALID_PAYLOAD |
| B13 | สคริปต์ spam (ด้านล่าง) | มี RATE_LIMITED และผีไม่ตายเร็วกว่าปกติ | ◐ 30 requests: OK 1/COOLDOWN 5/RATE_LIMITED 24; TTK ระหว่าง spam ยังไม่วัด |

### P1-C Soul + transform + HUD

| # | ทดสอบ | คาดหวัง | ผล |
|---|---|---|---|
| C1 | ฆ่าผี 1 ตัว | orb ลอยเข้าตัว, วิญญาณ +10, แก่นวิญญาณ +5 ครั้งเดียว | ◐ kill จริง +10/+5 ครั้งเดียว และ soul_orb event; ภาพรอตรวจ |
| C2 | ฆ่าครบ 10 ตัว (หรือใช้ทางลัด) | "พร้อมแปลงร่าง — กด R" กะพริบ | ✅ Director ฆ่าครบ 10 ตัวและแปลงร่างได้จริง (27 ต.ค.); รอบก่อน Codex ใช้ fixture gauge 90 |
| C3 | กด R ก่อนเกจเต็ม | "เกจวิญญาณยังไม่เต็ม" | ◐ real remote ได้ NOT_READY; ข้อความ UI ยังไม่ตรวจ |
| C4 | กด R ตอนเต็ม | ตัวเรืองแสง, ฟันเป็นคลื่นยาว, HUD นับ 12 วิ แล้วกลับร่าง | ◐ seeded full gauge: aura/wave/12s expiry ผ่าน; visual feel รอ Director |
| C5 | ฆ่าผีระหว่างแปลงร่าง | ได้แก่นวิญญาณ แต่เกจไม่เพิ่ม | ✅ active kill essence +5 แต่ gauge คง 0; wave damage 25 |
| C6 | ตายระหว่างแปลงร่าง | เกจ = 0, ร่างและแสงหายทันที | ✅ force death ล้าง aura/gauge/transform; respawn HP100 |
| C7 | สคริปต์ duplicate requestId (ด้านล่าง) | ได้ผลเดิมซ้ำ ไม่ได้รางวัลเพิ่ม | ◐ duplicate transform/basic คืนผลเดิม; ไม่ replay lethal request ใน test นี้ |

### P1-D Multiplayer

ทดสอบด้วย Test → Clients and Servers → 2 players

| # | ทดสอบ | คาดหวัง | ผล |
|---|---|---|---|
| D1 | ทั้งสอง client | เห็นผีตำแหน่งเดียวกัน และเห็นเส้นฟัน/คลื่นของอีกฝ่าย | ✅ 2 clients จริง: IDs/XZ ตรงและได้ FX events ชุดเดียวกัน; Y ต่างตามเวลา hover |
| D2 | ทั้งสองตีผีตัวเดียวกันจนตาย | ทั้งคู่ได้ +10/+5 คนละครั้ง ไม่ซ้ำ | ✅ ทั้งคู่ได้ gauge10/essence5 คนละครั้ง; ใช้ runtime HP fixture กันตายระหว่างสลับหน้าต่าง |
| D3 | คนหนึ่งตาย อีกคนเล่นต่อ | HUD ของแต่ละคนแยกกัน ไม่ปน | ✅ Player1 ตาย/gauge0 แต่ Player2 ยัง alive/gauge10 |
| D4 | ผีเลือกตีคนที่ใกล้กว่า | ไล่คนใกล้สุด | ✅ 16 samples nearest=Player2 และ chase dot เป็นบวกเมื่อขยับ |

### P1-E Dash / movement authority (เพิ่มรอบ Claude 27 ต.ค. หลัง Codex review)

Server ใช้ `MovementService` + `MovementRules` สุ่มตำแหน่ง root ทุก 0.25 วินาที ยอมรับเฉพาะการเดินภายใน WalkSpeed × 1.3 (+ เครดิต jitter สะสมได้ไม่เกิน 2.5 studs ไม่แจกใหม่ทุก sample ตาม DEC-013) หรือ dash ที่ server รับแล้ว (ระยะตาม clear distance ของ server, ทิศตามที่ validate, ภายในหน้าต่าง 0.58 วินาที, ไม่ผ่าน Collision) นอกนั้นดึงตัวกลับตำแหน่งล่าสุดที่ยอมรับ และนับใน attribute `MovementCorrections` ของ Player

| # | ทดสอบ | คาดหวัง | ผล |
|---|---|---|---|
| E1 | `MovementRulesTest.Run()` (รันเองตอน Play ใน Studio) | 15 PASS, 0 FAIL | ✅ 15 passed / 0 failed ใน Play Server หลัง Codex แก้ jitter credit |
| E2 | กด Q พุ่งปกติในที่โล่ง 5 ครั้ง (รอ cooldown) | `MovementCorrections` ไม่เพิ่ม ไม่มีการกระตุก | ✅ Q ปกติ 5 ครั้งข้ามรอบทดสอบ ไม่มี corrections; หลังแก้ระยะประมาณ11.91–12.20 |
| E3 | กด Q ใส่ test wall | หยุดหน้ากำแพง `MovementCorrections` ไม่เพิ่ม | ✅ Q ชน wall หยุดด้านเดิม corrections2→2 |
| E4 | NEG teleport 20 studs ฝั่ง client | ถูกดึงกลับภายใน ~0.3 วินาที, corrections +1 | ✅ คืนตำแหน่งคลาด≈0.000062 studs, corrections+1; ไม่วัดเกณฑ์เวลา0.3วิ |
| E5 | NEG dash ระหว่าง cooldown แล้วขยับ 10 studs | ได้ COOLDOWN และถูกดึงกลับภายใน ~0.7 วินาที | ✅ OK→COOLDOWN แล้วขยับผิดถูกดึงกลับ; ไม่วัดเกณฑ์เวลา0.7วิ |
| E6 | NEG ข้าม test wall ฝั่ง client | ถูกดึงกลับฝั่งเดิม | ✅ กลับฝั่งเดิม corrections2→3 |
| E7 | NEG speed hack WalkSpeed 40 ฝั่ง client แล้วเดิน | ถูกดึงกลับซ้ำ ๆ | ✅ speed40 corrections3→6; หลัง fix speed28 corrections0→2 |
| E8 | เดินขึ้นทางลาด/กระโดดขึ้น low tier/กระโดดข้าม cover | ไม่ถูกดึงกลับ (false positive) | ✅ ramp/กระโดดขึ้นtier/ข้ามcover ไม่มี correction เพิ่ม |
| E9 | 2 clients ต่างคนต่าง dash | corrections ของแต่ละคนไม่เพิ่ม | ✅ Server + Player1/Player2 จริง กดQได้ corrections0ทั้งคู่ |

```lua
-- E1: server Command Bar (Edit หรือ Play)
require(game.ServerScriptService.Server.Tests.MovementRulesTest).Run()
```

```lua
-- E2–E7: client Command Bar ระหว่าง Play (ต้องติดตั้ง _G.qaSend ด้านล่างก่อนสำหรับ E5)
local lp = game.Players.LocalPlayer
lp:GetAttributeChangedSignal("MovementCorrections"):Connect(function()
	print("[QA] MovementCorrections =", lp:GetAttribute("MovementCorrections"), lp.Character.HumanoidRootPart.Position)
end)
_G.root = function() return lp.Character.HumanoidRootPart end
```

```lua
-- E4: teleport 20 studs ไปทางเหนือ
local r = _G.root(); print("before", r.Position); r.CFrame += Vector3.new(0, 0, -20)
task.wait(1); print("after", _G.root().Position)
```

```lua
-- E5: dash แรก OK แล้ว dash ที่สองช่วง cooldown พร้อมขยับเอง 10 studs
_G.qaSend("e5-a", "dash", {moveDirection = Vector3.new(1, 0, 0)})
task.wait(0.8)
_G.qaSend("e5-b", "dash", {moveDirection = Vector3.new(1, 0, 0)})
local r = _G.root(); r.CFrame += Vector3.new(10, 0, 0)
task.wait(1.2); print("after", _G.root().Position)
```

```lua
-- E6: ยืนใกล้ test wall ด้านใต้ (เช่น X=-18, Z≈-4) แล้วข้ามไปอีกฝั่ง
local r = _G.root(); r.CFrame = CFrame.new(-18, r.Position.Y, -4)
task.wait(1)
r = _G.root(); r.CFrame = CFrame.new(-18, r.Position.Y, -8.5)
task.wait(1); print("after", _G.root().Position) -- ควรกลับมาฝั่ง Z > -6
```

หมายเหตุ E6: การวาง CFrame ครั้งแรก (ไป X=-18, Z=-4) อาจถูกนับเป็น correction ด้วยถ้าไกลเกิน ให้ดูเฉพาะผลหลังบรรทัดที่สอง หรือเดินไปจุดนั้นเองก่อน

```lua
-- E7: speed hack ฝั่ง client แล้วกดเดินค้าง 3 วินาที จากนั้นคืนค่า
local lp = game.Players.LocalPlayer; lp.Character.Humanoid.WalkSpeed = 40
-- ...เดิน... แล้ว:
-- lp.Character.Humanoid.WalkSpeed = 16
```

## สคริปต์ทดสอบ payload (Studio Command Bar)

ระหว่าง Play ให้สลับ Command Bar เป็นฝั่ง **Client** (แท็บ Test → ปุ่ม Current: Client/Server) แล้ววางทีละชุด ผลจะพิมพ์ใน Output

```lua
-- ติดตั้งตัวพิมพ์ผลครั้งเดียว
local R = game.ReplicatedStorage.SpiritWardRemotes
R.ActionResult.OnClientEvent:Connect(function(r) print("[QA]", r.requestId, r.code) end)
local function send(id, action, payload) R.ActionRequest:FireServer({requestId = id, action = action, payload = payload}) end
_G.qaSend = send
```

```lua
-- Invalid payload: ทุกบรรทัดควรได้ INVALID_PAYLOAD
local send = _G.qaSend
send("qa-1", "basic_attack", {sequence = 1, aimDirection = Vector3.new(0, 1, 0)})        -- Y เกิน
send("qa-2", "basic_attack", {sequence = 1, aimDirection = Vector3.new(5, 0, 0)})        -- magnitude ผิด
send("qa-3", "basic_attack", {sequence = 1, aimDirection = Vector3.new(0/0, 0, 1)})      -- NaN
send("qa-4", "basic_attack", {sequence = 1, aimDirection = Vector3.new(0, 0, -1), damage = 999}) -- key เกิน
send("qa-5", "dash", {moveDirection = "north"})                                          -- ชนิดผิด
send("qa-6", "give_reward", {})                                                          -- action ไม่มี
send("qa-7", "basic_attack", {sequence = 9, aimDirection = Vector3.new(0, 0, -1)})       -- sequence เกิน
```

```lua
-- Spam: ยิง 30 ครั้งรวด ควรเห็น RATE_LIMITED/COOLDOWN มาก และ OK แค่ไม่กี่ครั้ง
for i = 1, 30 do _G.qaSend("spam-" .. i, "basic_attack", {sequence = 1, aimDirection = Vector3.new(0, 0, -1)}) end
```

```lua
-- Duplicate: id เดิม payload เดิม → ผลเดิม; id เดิม payload ต่าง → INVALID_PAYLOAD
_G.qaSend("dup-1", "transform", {})
task.wait(1.5)
_G.qaSend("dup-1", "transform", {})
_G.qaSend("dup-1", "dash", {moveDirection = Vector3.new(1, 0, 0)})
```

## Director playtest (4 คำถามจาก brief)

27 ตุลาคม 2026 — ผู้ใช้รายงานว่า **“ผมเทสแล้วปกติดี”** รับผลทดลองเล่นภาพรวมรอบนี้ ไม่มีปัญหาที่ผู้ใช้รายงาน ไม่อนุมานว่าได้ตรวจทุกแถว ทดสอบมือถือ หรือเล่น 2 clients แล้ว คำถามเฉพาะด้านล่างยังไม่มีคะแนนแยกรายข้อ และไม่จำเป็นต้องถามซ้ำเพื่อเดินหน้างานที่ค้าง

| คำถาม | คำตอบผู้ใช้ |
|---|---|
| กล้องสบายหรือไม่ | โอเค |
| เดิน/พุ่งคุมได้หรือไม่ | โอเค; พุ่งชนกำแพงเด้งขึ้นฟ้านาน ๆ ครั้ง แก้แล้ว Director ยืนยันว่าหาย |
| ฟันรู้สึกโดนหรือไม่ | โอเค |
| แปลงร่างแล้วอยากใช้ต่อหรือไม่ | โอเค |

## Blockers ที่พบ / แก้แล้ว

Codex แก้การลบ Remotes เดิมแล้ว ใช้ SpiritWardRemotes; regression reuse/preservation ผ่าน Director ทดลองแล้วรายงานว่าปกติดี ยังเหลือ server dash movement validation, 2 clients และ touch ดู P1D_CODEX_REVIEW.md

Claude (รอบหลัง review): เพิ่ม server movement authority ตาม P1-E

รอบทดสอบ P1-E ใน Studio (27 ต.ค. 2026, รายละเอียดใน P1E_CODEX_REVIEW.md): E1–E9, A6 และ D1–D4 ผ่าน ระหว่างทดสอบแก้ 2 จุด
- เครดิต jitter ถูกแจกใหม่ทุก sample ทำให้เดินเร็ว 28 ได้ต่อเนื่อง → เปลี่ยนเป็นเครดิตมีเพดาน (DEC-013), tests 13 → 15
- ปุ่มฟันล้นขอบจอใน iPhone XR → จัดปุ่มเป็นกลุ่ม 2×2 ตาม `Prototype.Input` (DEC-014)

## ยังไม่ได้ทดสอบ / ยังไม่ปิด

- **Director (27 ต.ค.):** ตอบ 4 คำถามแล้ว โอเคทุกข้อ ภาพ/เสียงรับได้ ถอยหลบวงเตือนได้ ฆ่าครบ 10 ตัวและแปลงร่างได้จริง
- **บั๊กพุ่งเด้งขึ้นฟ้า (แก้แล้ว):** client ใช้ LinearVelocity MaxForce 1e6 ดันเข้ากำแพงตลอด 0.18 วิ แกน Y ไม่ถูกคุม แก้ใน `CombatController`: spherecast หา clear distance ก่อนพุ่ง (กติกาเดียวกับ server) แล้วหยุดหน้ากำแพง, MaxForce ตามมวลตัว, ตัดความเร็วขึ้นที่ dash สร้างเอง รอบแรกที่ Director ลอง ไฟล์ในเครื่องยังเป็นโค้ดเดิม จึงไม่นับ; รอบสองหลังเขียนไฟล์ใหม่และตรวจแล้ว Director ยืนยันว่าหายจริง (27 ต.ค.)
- **การเล่นจริงที่ยังไม่รัน:** B6/B7 ฟันผีหลังกำแพง/บนชั้นในฉากจริง, B10 วัดเวลาเกิดใหม่ 8 วิ
- **มือถือจริง:** ทดสอบแค่ simulator แนวนอนขนาดเดียว ยังไม่มี portrait, จอหลายสัดส่วน, multitouch พร้อมกัน, gamepad
- **ข้อจำกัด movement ที่ยอมรับเฉพาะต้นแบบ:** ไม่ตรวจแกน Y, noclip ผ่าน cover เตี้ยไม่ถูกจับ, ยังไม่ทดสอบ latency/packet loss จริง, ยังไม่ตรวจ teleport-ตี-กลับ ระหว่าง sample ต้องปิดก่อนเปิดให้คนนอกเล่น
- **Performance 8 players:** ยังไม่ทดสอบ


อัปเดต Codex รอบ P1-E: local movement tests, iPhone XR simulator และ server + 2 clients ผ่านตามขอบเขตใน P1E_CODEX_REVIEW.md แก้ finite jitter credit และปุ่มฟันล้นจอแล้ว ไม่ถือเป็น production security หรือมือถือจริงผ่าน
