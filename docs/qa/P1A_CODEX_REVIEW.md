# P1-A — Codex review และ Studio smoke test

วันที่ 27 ตุลาคม 2026 | ผู้ตรวจ: Codex | source: Claude P1-A ใน working tree (ยังไม่ commit)

## ผลตรวจรับ

**Desktop technical smoke test ผ่านส่วนที่ทดสอบด้านล่าง แต่ P1-A ยังไม่ผ่าน gate เต็ม** ต้องตรวจ touch layout/gestures และให้ Director ประเมินการควบคุม/ภาพจริงก่อน ไม่มีการแก้ runtime code ในรอบ review นี้ เพราะยังไม่พบ defect ที่ยืนยันได้จากการทดสอบที่ทำ

Studio เป้าหมาย: Place1, ID `1c9ed7c3-c0a2-4d69-986a-699fb363770a` ผู้ใช้ยืนยันให้ใช้ทดสอบแล้ว ตรวจพบเปิด Play อยู่ จึงหยุดแล้วเริ่ม Play ใหม่ โค้ดทั้ง 11 scripts/modules ใน Edit DataModel ตรงกับไฟล์ local หลัง normalize line endings ไม่ต้องเขียนทับหรือซิงก์โค้ดเพิ่ม

## เครื่องมือและ build

- ดาวน์โหลด binary จาก official GitHub releases: Rojo v7.7.1 และ Luau 0.744 ไว้ใน `%LOCALAPPDATA%/SpiritWard/tools` ไม่แก้ PATH ของระบบ
- `luau-compile --null` ผ่าน 11 ไฟล์ เป็น syntax/bytecode compilation **ไม่ใช่** Roblox-aware strict type analysis
- `rojo build default.project.json` ผ่าน ได้ `%LOCALAPPDATA%/SpiritWard/builds/SpiritWard-P1A.rbxlx`
- ยังไม่ได้ติดตั้ง plugin หรือเริ่ม live Rojo serve ในรอบ review นี้ ไม่อ้างว่า live sync ผ่าน

## ผลรันจริงใน Play Solo

| การตรวจ | ผลจริง | สถานะ |
|---|---|---|
| Server/client bootstrap | มี startup log ทั้งสองฝั่ง ไม่มี exception ของ P1-A | ผ่าน |
| Scene | namespace มี 67 descendants; enemy spawn tags 3 จุด | ผ่าน |
| Initial spawn/HP | PlayerSpawn ตำแหน่งประมาณ (0, 4.606, 38), HP 100 | ผ่าน |
| Banner | ข้อความ PROTOTYPE — progress resets อยู่ใน PlayerGui | ผ่านเชิง state; ภาพจริงรอ Director |
| Camera config | Classic, Zoom occlusion, min/max 6/32 | ผ่าน |
| Ramp orientation | raycast ที่ X=10.5→17.5, Z=18 ได้ผิวสูง Y=1.3125→5.6875 ต่อกับ tier Y=6 | ผ่าน; ทางลาดไม่กลับทิศ |
| เดินขึ้นชั้นสูง | ใช้ character navigation เดินผ่านทางลาดถึงประมาณ (28.294, 9.606, 18.001) | ผ่าน |
| Checkpoint touch | เดินไปแผ่น checkpoint แล้ว RespawnLocation เปลี่ยนเป็น Checkpoint | ผ่าน |
| Death/respawn | ตั้ง Humanoid.Health=0 ฝั่ง server; เกิดใหม่ที่ checkpoint ประมาณ 4.36 วินาทีรวมเวลาโหลดตัว, HP 100 | ผ่าน |
| Camera collision | ยืนด้านเหนือ TestWall; ตั้งกล้องอีกฝั่งกำแพง; กล้อง Zoom กลับด้านเดียวกับผู้เล่นที่ Z≈-6.663 เมื่อ wall center Z=-6 | ผ่านสถานการณ์นี้ |
| Keyboard actions | ส่ง E/Q/R แล้ว ActionEcho เป็น cast_skill/dash/transform ตามลำดับ | ผ่าน |
| Mouse basic attack | ส่ง left click แล้ว ActionEcho เป็น basic_attack | ผ่าน |
| Jump | ส่ง Space; root สูงขึ้นประมาณ 7.53 studs | ผ่าน |

ปุ่ม combat ขณะนี้แสดงข้อความเท่านั้นตาม scope P1-A ไม่ได้ทดสอบว่าฟัน/พุ่ง/แปลงทำงานจริง

## ข้อจำกัดและสิ่งที่ยังไม่ตรวจ

- Device emulator และ touch จริง: ยังไม่ทดสอบ การที่ CAS bind สำเร็จไม่พิสูจน์ว่าปุ่มไม่ซ้อนกันหรือ gesture ไม่แย่งกัน
- 2 clients/gamepad/character rig หลายรูปแบบ: ยังไม่ทดสอบในรอบนี้
- ภาพ capture ผ่าน Studio MCP ได้ HUD แต่ world เป็นพื้นขาว จึงใช้ภาพนั้นรับรองแสง/ภาพ/การจัดฉากไม่ได้ ยังไม่สรุปว่าเป็นข้อผิดพลาดจาก scene ต้องให้ Director ดู viewport จริง
- Output มี warning `rbxassetid://203785492` ว่า asset type ไม่ตรง ไม่มี asset ID นี้ใน source P1-A ที่ตรวจ จึงยังระบุสาเหตุไม่ได้ ไม่แก้ asset/ตัวละครของผู้ใช้โดยเดา
- เดินผ่าน ramp/checkpoint ตรวจด้วย character navigation; ความรู้สึก WASD/เมาส์ต้องให้ Director เล่นเอง
- ไม่มี reward/save/anti-cheat tests ใน P1-A เพราะระบบยังไม่ implement

## การส่งต่องาน

1. Director ลองเดิน หมุนกล้อง และดูฉากใน Place1 ที่เปิด Play รออยู่แล้ว ไม่ต้องติดตั้ง Rojo เพื่อทำรอบทดลองนี้
2. Claude ตรวจ mobile layout ใน emulator และบันทึกผลจริง โดยเฉพาะปุ่มสี่ตัวกับ jump/camera gesture; ปรับตำแหน่งหากทับกัน
3. เมื่อ P1-A gate ครบ จึงเริ่ม P1-B ตามใบงานเดิม หลังส่ง batch Codex จะตรวจ source ใหม่อีกครั้ง

ยังไม่ publish, ไม่ commit และไม่ถือว่าอนุมัติภาพ production
