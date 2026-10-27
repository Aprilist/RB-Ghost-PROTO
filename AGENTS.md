# กติกาการทำงาน Project Spirit Ward

- อ่าน README, docs/GAME_DESIGN.md, docs/CONTRACTS.md และ docs/PRODUCTION_PLAN.md ก่อนเริ่มงาน
- อยู่ใน phase และ task ที่ได้รับมอบหมาย ไม่เพิ่มระบบนอก scope เอง
- รักษา `work/` และไฟล์ที่ผู้ใช้มีอยู่ ห้ามลบหรือย้ายเพื่อจัดโครงใหม่
- ใช้ Luau และ `--!strict` ในโค้ดใหม่ หลีกเลี่ยง dependency จนมีเหตุผลชัดเจน
- Server ตัดสิน damage, rewards, inventory, progression และ save; client ส่ง intent
- แก้ contract ได้เมื่อแก้ไฟล์ types ให้ตรงกันในงานเดียวกัน · การเปลี่ยน decision หรือเกณฑ์ acceptance ต้องถาม Director ก่อน แล้วบันทึกใน docs/DECISIONS.md
- ค่าตัวเลขเกมอยู่ใน definitions/config ไม่ฝังซ้ำใน UI หรือ Services
- ส่งมอบพร้อมรายชื่อไฟล์ วิธีทดสอบ ผลจริง และข้อจำกัด แยกสิ่งที่ตรวจแล้วกับสิ่งที่ยังไม่ได้รัน
- ใช้แผนที่และ asset ที่สร้างเองหรือมีสิทธิ์ใช้งาน ลงที่มาใน asset manifest
- ไม่ commit secret, local API config หรือไฟล์บัญชีผู้ใช้
- ทีมคือ Claude + Director (DEC-015) ไม่ใช้ Codex แล้ว ชื่อ Codex ในเอกสารเก่าเป็นประวัติ
