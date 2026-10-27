# Rojo setup (P1, Windows)

วิธี sync ที่เสนอสำหรับ DEC-002: **Rojo** ใช้ `default.project.json` ที่มีอยู่แล้ว ไฟล์ใน `src/` เป็นแหล่งโค้ดเดียว ห้ามแก้สคริปต์เดียวกันใน Studio ระหว่างเชื่อม Rojo เพราะ Rojo จะเขียนทับ

## สถานะหลัง Codex ตรวจ 27 ตุลาคม 2026

- Codex รับ Rojo เป็นวิธี sync ตาม DEC-002 แล้ว
- มี Rojo 7.7.1 CLI ที่ `%LOCALAPPDATA%\SpiritWard\tools\rojo-7.7.1\rojo.exe` และ build ผ่านแล้ว
- ไฟล์ build ทดสอบ: `%LOCALAPPDATA%\SpiritWard\builds\SpiritWard-P1A.rbxlx`
- โค้ดใน Place1 ตรงกับ local ตอนตรวจ และรัน Play Solo ผ่าน desktop smoke test ไม่ต้องติดตั้งใหม่เพื่อทดลองรอบนี้
- ยังไม่ได้ตรวจการติดตั้ง Studio plugin/live serve ในรอบ review; ขั้นตอนด้านล่างเป็นคู่มือสำหรับตั้ง live sync ในรอบถัดไป
- ผลและรายการที่ยังไม่ทดสอบอยู่ใน `docs/qa/P1A_CODEX_REVIEW.md`

## ติดตั้งครั้งเดียว

1. ดาวน์โหลด Rojo 7.x สำหรับ Windows จาก https://github.com/rojo-rbx/rojo/releases (ไฟล์ `rojo-7.x.x-windows-x86_64.zip`) แตกไฟล์ `rojo.exe` ไว้ที่ไหนก็ได้ เช่น `C:\Tools\rojo\`
2. เปิด PowerShell แล้วตรวจ: `C:\Tools\rojo\rojo.exe --version`
3. ติดตั้ง plugin ใน Studio: `C:\Tools\rojo\rojo.exe plugin install` (หรือติดตั้ง "Rojo" จาก Creator Store ใน Studio)
4. ปิดแล้วเปิด Roblox Studio ใหม่ จะเห็นแท็บ/ปุ่ม Rojo ใน Plugins

## ใช้งานทุกครั้ง

1. PowerShell:
   ```
   cd "C:\Users\shint\Documents\ChatGPT\Roblox Game"
   C:\Tools\rojo\rojo.exe serve
   ```
   ปล่อยหน้าต่างนี้เปิดไว้
2. Studio: เปิด place ใหม่จากแม่แบบ **Baseplate** (หรือ place ทดสอบของคุณ) → Plugins → Rojo → **Connect** (localhost:34872)
3. ตรวจว่ามี `ReplicatedStorage/Shared`, `ServerScriptService/Server`, `StarterPlayer/StarterPlayerScripts/Client`
4. กด **Play** (F5) ฉากจะถูกสร้างที่ `Workspace/SpiritWardPrototype` ตอนเริ่มเกม

## สร้างฉากใน Edit mode (ไม่บังคับ)

ถ้าอยากเห็นลานโดยไม่กด Play ให้วางใน Command Bar ของ Studio:

```lua
require(game.ServerScriptService.Server.Services.SceneService).Build()
```

รันซ้ำได้ จะลบและสร้างใหม่เฉพาะ `Workspace/SpiritWardPrototype` กับ `Lighting/SpiritWardPrototypeAtmosphere` เท่านั้น (คำสั่งนี้ปรับค่า Lighting เช่นเวลาและสีแสงด้วย) ถ้ากด Play หลังจากนั้น server จะสร้างฉากใหม่ทับอีกครั้งตามปกติ

## ทดสอบ 2 clients (ใช้ใน P1-B ขึ้นไป)

Studio → แท็บ Test → Clients and Servers → เลือก 2 players → Start

## ทดสอบ touch

Studio → แท็บ Test → Device emulator เลือกมือถือ แล้ว Play (ยังต้องทดสอบบนเครื่องจริงก่อนอ้างว่าผ่าน)
