# Decision log

วันที่เริ่ม 27 ตุลาคม 2026

| ID | เรื่อง | ค่าเริ่มต้น/ข้อเสนอ | สถานะ | ผลกระทบ |
|---|---|---|---|---|
| DEC-001 | มุมกล้อง | 3D บุคคลที่สาม เดิน X/Z กระโดด Y | confirmed by user 27 ต.ค. 2026 | directional combat, soft aim, camera collision, 3D arenas และ touch camera |
| DEC-002 | วิธี sync | เลือก Rojo 7; source ใน src เป็นแหล่งหลัก | Codex รับข้อเสนอ Claude; Rojo 7.7.1 build ผ่าน 27 ต.ค. 2026 | live serve/plugin ยังไม่ตรวจในรอบนี้; Studio source ที่มีอยู่ตรง local 11 ไฟล์ |
| DEC-003 | ชื่อเกม | Project Spirit Ward / หมู่บ้านม่านวิญญาณ | working title | เปลี่ยนได้ก่อน branding/publication |
| DEC-004 | scope | 1 class prototype → 3 classes alpha | baseline proposal | ลดความเสี่ยงของ combat ก่อนผลิตคอนเทนต์ |
| DEC-005 | ทีม | Claude content/UX/client; Codex server/contracts/integration | baseline proposal ตามคำขอแบ่งงาน | พร้อมส่ง batch แรก แต่ยังไม่มี Claude run |
| DEC-006 | persistence | server-owned profile + memory adapter ระหว่าง prototype | baseline proposal | schema/lease ต้องตรึงใน CD-01; persistence ผ่าน M3 |
| DEC-007 | roster/จำนวนคน | 12 คนต่อ server (เดิม 8; ผู้ใช้เลือก 27 ต.ค. 2026 ให้บ้านผู้เล่น 12 หลังตามผังหมู่บ้านใหม่); 1 shared boss arena | confirmed by user 27 ต.ค. 2026, awaiting playtest | ต้องตั้ง Max Players ใน Game Settings เป็น 12; enemy count, boss eligibility และ performance ต้องดูใหม่ |
| DEC-008 | duplicate upgrade | เพิ่ม expected weapon state/revision ให้ apply_seal | pending CD-01 | ต้องปิดก่อน implementation; cache อย่างเดียวไม่พอ |
| DEC-009 | ธีม | ญี่ปุ่น | confirmed by user 27 ต.ค. 2026 | โลก/อาชีพ/asset ใช้ญี่ปุ่นแฟนตาซี รายละเอียด art เป็นข้อเสนอ v0.2 |
| DEC-010 | งานโค้ดหลัก | Claude เป็น Lead Programmer ทั้ง client/server; Codex design/technical review/integration | ปรับตามบทสนทนาแบ่งงานและคำสั่งเริ่มงาน | ownership/task board รุ่นเก่าถูกแทนที่โดยแผนปัจจุบัน |
| DEC-011 | ระดับภาพ P1 | styled greybox: รูปทรงเรียบ สี/แสงสื่อญี่ปุ่น; polish หลัง core loop ผ่าน | implementation choice ของ Codex เพื่อคุมงานแก้ซ้ำ | ยังไม่ผลิตโมเดล/animation รายละเอียดสูง |
| DEC-012 | Remote namespace | SpiritWardRemotes + OwnedBy=SpiritWard; reuse owned instances, preserve collisions | Codex แก้และรัน regression ผ่าน 27 ต.ค. 2026 | ไม่ลบ Remotes เดิมของ place; QA scripts ใช้ namespace ใหม่ |
| DEC-013 | Jitter allowance | จำกัดเป็น walk credit ที่มีเพดาน แทนแจก slack ใหม่ทุก sample | Codex แก้หลังพบ pure simulation speed28 ผ่านต่อเนื่อง; tests15/15 | รักษาความทน jitter แต่ไม่สะสมระยะเดินเกินจาก sampling |
| DEC-014 | Touch action layout | CAS action buttons 2×2 ตาม Prototype.Input | Codex ตรวจ iPhone XR แล้วแก้ปุ่มฟันล้นจอ | ผ่าน simulator landscape หนึ่งขนาด; มือถือจริงยังไม่รับรอง |

คำว่า baseline proposal คือค่าที่ใช้เดินหน้าออกแบบได้ตามขอบเขตที่ผู้ใช้มอบหมาย ไม่ใช่การยืนยันว่าได้ playtest หรือผู้ใช้เลือกค่าทุกข้อแล้ว
