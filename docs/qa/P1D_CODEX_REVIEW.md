# P1-D — Codex runtime review

27 ตุลาคม 2026 | Place1 | Play Solo, 1 player | Studio engine 0.744.0.7441077

อัปเดตหลังรายงาน: Director ทดลองแล้วแจ้งว่า “ผมเทสแล้วปกติดี” รับผลเล่นภาพรวมแล้ว ข้อความรอ Director ในผลเดิมด้านล่างเป็นสถานะก่อนคำตอบนี้ ยังไม่มีหลักฐานเพิ่มเรื่อง 2 clients หรือ touch

## ผลสรุป

P1-A/B/C มี source และรัน gameplay loop ส่วนสำคัญได้จริงแล้ว P1-D ยังไม่ปิด: เหลือ multiplayer 2 clients, touch และ Director feedback นอกจากนี้ server movement validation ของ dash ยังขาดตามที่ Claude รายงาน ไม่ถือว่าผ่านข้อนี้จากการพุ่งชนกำแพงได้ใน client ปกติ

## การแก้โค้ดในรอบ Codex

พบ `NetworkService.Init()` ลบ `ReplicatedStorage/Remotes` เดิมทั้งโฟลเดอร์ แก้ให้ใช้ `SpiritWardRemotes` และ attribute `OwnedBy=SpiritWard` บน folder/events, reuse ของโปรเจกต์ และหยุดพร้อม error หากชื่อชนของที่ไม่ได้เป็นเจ้าของ โดยไม่ลบของเดิม

แก้ runtime สองไฟล์: `src/shared/Types/Contracts.luau`, `src/server/Services/NetworkService.luau` ปรับเอกสาร contracts และ QA Command Bar ให้ใช้ชื่อใหม่ด้วย ไม่มีการเปลี่ยน tuning การต่อสู้

Regression test ใน Play: สร้าง legacy Remotes พร้อม sentinel ชั่วคราว เรียก Init สองครั้ง พบ legacy/sentinel, project folder และ RemoteEvent instance เดิมยังอยู่ครบ จากนั้นล้าง sentinel/legacy ที่ test สร้างเอง ไม่ลบของผู้ใช้

## ผลจริง

| ระบบ | หลักฐาน |
|---|---|
| Compilation/build | Luau compile 21 files ผ่าน; Rojo 7.7.1 build ผ่าน ได้ `%LOCALAPPDATA%/SpiritWard/builds/SpiritWard-P1D.rbxlx` |
| Startup | log server/client สำเร็จ; 3 enemy models; snapshot และ HUD มี HP 100/gauge 0/essence 0; Katana มี 3 parts |
| Invalid payload | 9 กรณี: Y, magnitude, NaN, extra damage, wrong type, unknown action, sequence range, zero vector, Infinity → INVALID_PAYLOAD ทุกกรณี |
| Spam | 30 requests ใน burst เดียว → OK 1, COOLDOWN 5, RATE_LIMITED 24; fixture อยู่ห่างศัตรูจึงไม่ได้พิสูจน์ TTK ในช่วง spam |
| Retry | transform id เดิมคืน NOT_READY เดิม; id เดิมเปลี่ยน action เป็น dash → INVALID_PAYLOAD |
| Basic hit/dedup | enemy HP 60→40→40→20→0; คำขอครั้งที่สองเป็น retry ของ hit แรก จึงไม่ตีซ้ำ |
| Reward | หลัง kill จริง gauge 10 และ essence 5; soul_orb event หนึ่งครั้ง ไม่มี client request ขอ reward |
| Enemy attack | มี telegraph/attack/player_hit events และ HP ผู้เล่น 100→90 ระหว่างการต่อสู้จริง |
| Geometry | เรียก helper กับพิกัดในแผนที่จริง: clear target=true; wall, height, behind, out-of-range=false; เป็น geometry check ไม่ใช่การเล่นทุกสถานการณ์ B5–B7 |
| Skill cooldown | คำขอสองครั้งติด: OK แล้ว COOLDOWN |
| Dash wall | กด Q ผ่าน input จริงที่ (-18,4.6,-10) หันเข้ากำแพง Z=-6; หยุดที่ประมาณ Z=-8.018 ไม่ผ่านกำแพงในกรณีนี้ |
| Full gauge boundary | ใช้ fixture ตั้ง gauge 90 แล้ว kill จริง +10 จนเต็ม 100; ไม่ใช่ natural ten-kill progression |
| Transform | จาก gauge 100 ได้ OK, gauge 0, มี aura และ wave event |
| Expiry | แยกทดสอบที่ safe spawn: HP คง 100; transformEndsAt หายและ aura ถูกลบเมื่อครบ 12 วินาที ตรวจซ้ำที่ประมาณ 12.95 วินาที |
| Active kill | ใช้ full-gauge fixture; wave damage 25 ทำ HP enemy 60→35→10→0; essence 10→15 แต่ gauge ยัง 0 ระหว่างแปลง |
| Death while transformed | ตั้ง HP=0 บน server; aura ของร่างเก่าหาย เกิดใหม่ HP 100/gauge 0/ไม่มี transform; skill cooldown key ยังคงอยู่ใน snapshot |

ผล raw อยู่ใน [P1D_RUNTIME.json](evidence/P1D_RUNTIME.json) เป็น tool responses จากรอบนี้ บาง test ใช้ fixture เฉพาะ Play environment ไม่แก้ค่า gauge/damage ใน source

## วิธีทดสอบและข้อจำกัด

- ส่ง intent ผ่าน RemoteEvent จริงจาก Client ตรวจ ActionResult, StateEvent และ enemy attributes; ไม่เรียก combat handler โดยตรงแทน network tests
- การอ่าน state ด้วย command-bar require ครั้งแรกไม่เห็น module cache ของ live gameplay จึงไม่นำค่าที่ว่างนั้นมาสรุปว่าระบบเสีย Fixture ใช้ Script ชั่วคราวใน server runtime และลบทันทีหลังทำงาน
- ไม่ใช้ผล expiry รอบแรกที่ผู้เล่นอาจตาย/เกิดใหม่ระหว่างรอ; ผลที่รายงานมาจากรอบ safe spawn ที่ HP คง 100 ตลอด
- ไม่มี strict Roblox-aware type analysis, mobile emulator/device, gamepad, 2-client หรือ visual/feel sign-off
- รางวัล 10 kills ตามการเล่นจริงยังไม่ตรวจครบ ใช้ boundary fixture ตรวจระบบแปลงร่างเพื่อประหยัดเวลาทดสอบเท่านั้น
- มี asset-type warning ของ `rbxassetid://203785492` เช่นเดียวกับรอบ P1-A; ไม่มี asset ID นี้ใน source P1 ที่อ่าน สาเหตุยังไม่ยืนยัน ไม่มี P1 script exception ใน Output รอบนี้
- namespace ทดสอบถูกล้างแล้ว ผู้เล่นถูก reset ที่จุดเริ่ม HP 100, gauge 0, essence 0 สำหรับ Director; Place1 เปิด Play รออยู่

## งานต่อให้ Claude

1. อ่านผลนี้ก่อน ไม่รีเซ็ตทุกแถวเป็น unverified และไม่ย้อน namespace กลับเป็น Remotes
2. เพิ่ม server validation สำหรับการเคลื่อนที่ dash: ขณะนี้ clear distance คำนวณเพียง FX แต่ client เป็นผู้เคลื่อนจริง การหยุดด้วย collision อย่างเดียวไม่พิสูจน์ authoritative distance/speed enforcement
3. ทดสอบและแก้ mobile layout/gesture และ 2 clients ตามตารางเดิม หากเครื่องมือ Claude ไม่มี Studio ให้ส่ง implementation/test setup พร้อมระบุ unverified และให้ Codex รันต่อ
4. AI ยังหยุดเมื่อพบกำแพงและอาจลอยพ้นขอบ low tier; ให้ระบุเป็นข้อจำกัด prototype หรือแก้ตามสเปกก่อนเพิ่มแผนที่ที่ซับซ้อน ไม่ถือว่า pathfinding ผ่านแล้ว
5. ให้ Director ประเมินกล้อง การควบคุม น้ำหนักฟัน และความรู้สึกแปลงร่างก่อนปิด P1

ไม่ได้ publish และไม่ได้ commit รอบนี้
