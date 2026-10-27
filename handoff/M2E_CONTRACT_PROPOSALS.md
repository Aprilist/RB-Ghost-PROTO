# M2-E — ส่วนที่เพิ่มเข้า contract (ข้อเสนอ)

ร่างโดย Claude 27 ต.ค. 2026 | สถานะ: **ใช้ในโค้ด M2-E แล้ว รอ Codex รับเข้า docs/CONTRACTS.md** ทุกข้อเป็นการ "เพิ่ม" ไม่ลบหรือเปลี่ยนชื่อของเดิม

## 1. ข้อเสนอปิด DEC-008 (duplicate apply_seal)

DEC-008 ขอให้เพิ่ม expected weapon state/revision ใน apply_seal เสนอทางที่ **ไม่ต้องเพิ่ม field ใน payload**:

- server ตรวจ "ดาบเล่มนี้ติดผนึกนี้อยู่แล้ว" และหักแก่นวิญญาณใน `ProfileService.Mutate` ครั้งเดียวกัน (`SealRules.Apply`)
- ส่งซ้ำ (retry, replay, requestId cache หมดอายุ) จึงได้ `ALREADY_SEALED` และไม่หักซ้ำ เพราะสถานะของดาบเป็นตัวกัน ไม่ใช่ cache
- ใช้ได้เพราะผนึกเป็นการตั้งค่าไม่ใช่ตัวนับ (ผนึกเดิมซ้ำไม่มีความหมาย) ถ้าภายหลังมี "อัปเกรดขั้น" ที่ซ้ำได้ ค่อยกลับมาเพิ่ม expected state ตอนนั้น

Codex ตัดสินว่ารับหรือยังต้องการ field `expectedUpgradeLevel`/revision

## 2. action `apply_seal`

มีในตาราง contract อยู่แล้ว (`{itemInstanceId, sealId}`, 2/sec burst 2) M2-E เปิดใช้จริง

| ลำดับตรวจ | code ที่ตอบ |
|---|---|
| sealId ไม่อยู่ใน catalog | INVALID_PAYLOAD |
| ตายอยู่ | DEAD |
| อยู่ห่างผู้ผนึก (ช่างตีดาบ `npc_smith`) เกิน talkRange + 6 studs | OUT_OF_RANGE |
| itemInstanceId ไม่อยู่ใน inventory หรือไม่ใช่อาวุธ | NOT_OWNED |
| ดาบติดผนึกนี้อยู่แล้ว | **ALREADY_SEALED (ใหม่)** |
| แก่นวิญญาณไม่พอ | INSUFFICIENT_ESSENCE |

## 3. ResultCode ใหม่ `ALREADY_SEALED`

ใช้เมื่อ apply_seal ซ้ำกับผนึกที่ติดอยู่ ไม่ใช้ INVALID_PAYLOAD เพราะผู้เล่นต้องเห็นข้อความที่ต่างกัน

## 4. PublicOwnProfile เพิ่ม 2 field

- `equippedWeaponId: string` (instance id ที่ client ส่งใน apply_seal)
- `equippedSealId: string?` (ผนึกบนอาวุธที่ถือ)

## 5. PublicOwnSession เพิ่ม 2 field

- `shieldHp: number` (0 = ไม่มีโล่) และ `shieldEndsAt: number?` (server clock) สำหรับผนึกปราการ ค่าเป็น session ไม่บันทึก

## 6. StateEvent kind ใหม่ `seal_menu`

`{kind, npcId, speakerTH}` ส่งเฉพาะเจ้าของเมื่อใช้ ProximityPrompt ที่ช่างตีดาบ client วาดเมนูจาก `Definitions/Seals` และ snapshot ล่าสุด

## 7. combat_fx effectId ใหม่ (เป็นภาพเท่านั้น)

`burn`, `ward_shield`, `seal_apply`

## 8. กติกาที่ตั้งเป็นค่าเริ่มต้น (ขอ Codex/Director ยืนยัน)

- เปลี่ยนผนึกต้องจ่ายราคาของผนึกใหม่อีกครั้ง และผนึกเก่าหลุด (หนึ่งอาวุธหนึ่งผนึก) GDD บอก "เปลี่ยนผนึกเริ่มต้นไม่เสียผนึกเก่า" แต่ ProfileV1 เก็บ `sealId` เดียวต่ออาวุธ จึงยังไม่มีที่เก็บผนึกที่เคยซื้อ ถ้าต้องการให้สลับฟรีต้องเพิ่ม field ใน ProfileV1
- ember นับ basic attack ที่โดนศัตรูอย่างน้อย 1 ตัวเป็น 1 ครั้ง (ไม่นับวิชา E) ครบ 3 ครั้งติดไฟทุกตัวที่โดนในครั้งนั้น ไฟไม่ซ้อนและไม่ต่ออายุ
- ward นับวิญญาณที่ reward จ่ายให้ผู้เล่นจริง ครบ 3 ได้โล่ 25 HP นาน 8 วินาที คูลดาวน์ 15 วินาทีนับจากได้โล่ วิญญาณช่วงคูลดาวน์ไม่นับ ตายหรือเปลี่ยนผนึกล้างตัวนับและโล่
