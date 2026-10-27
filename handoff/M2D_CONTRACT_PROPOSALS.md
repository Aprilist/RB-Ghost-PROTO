# M2-D — ส่วนที่เพิ่มเข้า contract (ข้อเสนอ)

ร่างโดย Claude 27 ต.ค. 2026 | สถานะ: **ใช้ในโค้ด M2-D แล้ว รอรับเข้า docs/CONTRACTS.md** ทุกข้อเป็นการ "เพิ่ม" ไม่ลบหรือเปลี่ยนชื่อของเดิม

## 1. action `claim_quest`

มีในตาราง contract อยู่แล้ว (`{questId}`, 2/sec burst 2) M2-D เปิดใช้จริง พร้อมเงื่อนไข server เพิ่มหนึ่งข้อ

| เงื่อนไข | code ที่ตอบ |
|---|---|
| questId ไม่อยู่ใน catalog | INVALID_PAYLOAD |
| ยังไม่ ready | QUEST_NOT_READY |
| claim ไปแล้ว | ALREADY_CLAIMED |
| ตายอยู่ | DEAD |
| **ใหม่:** อยู่ห่างผู้ให้เควสเกิน talkRange + 6 studs | OUT_OF_RANGE |

รางวัล (EXP, coins, essence) จ่ายใน `ProfileService.Mutate` ครั้งเดียวกับที่เปลี่ยนสถานะเป็น claimed จึงไม่จ่ายซ้ำแม้ requestId cache หมดอายุ

## 2. PublicOwnProfile เพิ่ม `quests`

`quests: { [questId]: { status: "active" | "ready" | "claimed", progress: number } }` เป็นสำเนาของ ProfileV1.quests ทั้งก้อน (มีอยู่ในข้อเสนอ M2 plan ข้อ 5.1 แล้ว)

## 3. StateEvent kind ใหม่ 2 แบบ (ส่งเฉพาะเจ้าของ)

- `dialogue`: `{kind, npcId, speakerTH, lines: {string}, questId?, claimQuestId?}` บทพูดของ NPC ถ้ามี `claimQuestId` client แสดงปุ่ม "รับรางวัล" ที่ส่ง claim_quest
- `notice`: `{kind, textTH}` ข้อความสั้น เช่น เก็บเศษม่าน 2/3, เควสสำเร็จ

## 4. Quest schema เพิ่ม 2 field

- `giverNpcId` ผู้ให้และผู้จ่ายรางวัลเควส (อ้าง Definitions/Npcs)
- `objectiveTH` ข้อความหนึ่งบรรทัดสำหรับตัวติดตามเควส

## 5. NPC schema (ใหม่, `Definitions/Npcs.luau`)

`id, displayNameTH, x, z, angle, talkRangeStuds, robeColor, idleLinesTH` ตำแหน่งคำนวณจาก `World.Village` (ศาลผู้ดูแลและแผงขาย 4 แผง)

## 6. การคุยและการเก็บของไม่ใช้ remote ใหม่

ใช้ `ProximityPrompt` ฝั่ง server (ปุ่ม F เพราะ E เป็นวิชา) แล้ว server ตรวจระยะ, alive และ cooldown 0.4 วินาทีเอง ไม่เพิ่ม action ใหม่ในตาราง contract

## 7. objective ที่รอ batch อื่น

`QuestService.Record(player, "apply_seal", sealId)` ให้ M2-E เรียกหลังผนึกสำเร็จ และ `QuestService.Record(player, "defeat_boss", bossId)` ให้ M2-F เรียกเมื่อบอสตายสำหรับผู้มีสิทธิ์รับรางวัล
