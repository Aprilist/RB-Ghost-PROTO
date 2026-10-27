# ตั้งค่าเครื่องที่บ้าน (Spirit Ward / RB-Ghost-PROTO)

1. **ติดตั้ง Git** จาก https://git-scm.com/download/win (กด Next ตามค่าเริ่มต้นได้)
2. **Clone โค้ด** เปิด PowerShell แล้วพิมพ์
   ```
   cd $HOME\Documents
   git clone https://github.com/Aprilist/RB-Ghost-PROTO.git "Roblox Game"
   cd "Roblox Game"
   ```
3. **ติดตั้ง Roblox Studio** จาก https://create.roblox.com แล้วล็อกอินบัญชีเดิม
4. **ติดตั้ง Rojo 7.7.1**
   - ดาวน์โหลด `rojo-7.7.1-windows-x86_64.zip` จาก https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1
   - แตกไฟล์ `rojo.exe` ไว้ที่ `C:\Tools\rojo\`
   - ตรวจ: `C:\Tools\rojo\rojo.exe --version` ต้องขึ้น 7.7.1
5. **ติดตั้ง plugin Rojo ใน Studio**: `C:\Tools\rojo\rojo.exe plugin install` แล้วปิดเปิด Studio ใหม่
6. **เปิด live sync** (ทุกครั้งที่ทำงาน)
   ```
   cd "$HOME\Documents\Roblox Game"
   C:\Tools\rojo\rojo.exe serve
   ```
   ปล่อยหน้าต่างไว้ แล้วใน Studio เปิด place แบบ **Baseplate** → Plugins → Rojo → **Connect** (localhost:34872)
   ตรวจว่ามี `ReplicatedStorage/Shared`, `ServerScriptService/Server`, `StarterPlayer/StarterPlayerScripts/Client`
7. **ตั้ง Max Players = 12**: Home → Game Settings → Places (หรือ File → Game Settings) → Max Players = 12 แล้ว Save
   (ต้อง Publish place ก่อนจึงตั้งค่านี้ได้)
8. กด **Play (F5)** ฉากจะสร้างที่ `Workspace/SpiritWardPrototype`

## ทำงานต่อสลับเครื่อง
- ก่อนเริ่มงาน: `git pull`
- เลิกงาน: `git add -A` → `git commit -m "ข้อความ"` → `git push`
- อย่าแก้สคริปต์ใน Studio ตอนต่อ Rojo อยู่ เพราะ Rojo จะเขียนทับ ให้แก้ไฟล์ใน `src/` แทน
