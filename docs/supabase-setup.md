# ต่อ Supabase

แอปทำงานได้ครบทุก flow โดยไม่ต้องมี Supabase — ใช้ repository ในหน่วยความจำ
เอกสารนี้สำหรับตอนอยากให้แชทเด้งข้ามเครื่องจริงและรูปไม่หายเมื่อรีเฟรช

---

## key ตัวไหนอยู่ตรงไหน

| Key | หน้าที่ | อยู่ในแอปได้ไหม |
|---|---|---|
| **anon / publishable** | ยิงเข้า API ผ่าน RLS | **ได้ โดยตั้งใจ** |
| **service_role** | ข้ามผ่าน RLS ทั้งหมด | **ไม่ได้เด็ดขาด** |

anon key ถูกออกแบบมาให้เปิดเผยได้ — ความปลอดภัยไม่ได้มาจากการซ่อน key
แต่มาจาก **RLS** ที่บังคับกฎรายแถวในฐานข้อมูล

> ตารางที่ลืมเปิด RLS = เปิดให้ทั้งโลกอ่านและเขียน
> ทุกตารางใน `supabase/migrations/0001_init.sql` เปิดไว้หมดแล้ว
> ถ้าเพิ่มตารางใหม่ อย่าลืม `enable row level security`

ถ้าเผลอเอา `service_role` มาใส่ แอปจะไม่ยอมต่อและ assert บอกวิธีแก้ให้

---

## ขั้นตอน

### 1. สร้างโปรเจกต์

[supabase.com](https://supabase.com) → New project

ฟรี ไม่ต้องผูกบัตร ไม่ต้องมีบริษัท — **ทำได้เลยตอนอายุ 19**

### 2. รัน migration

Dashboard → **SQL Editor** → New query → วางทั้งไฟล์ `supabase/migrations/0001_init.sql` → **Run**

จะได้ตาราง `profiles` `requests` `bids` `orders` `order_events` `messages`
พร้อม RLS ครบทุกตัว และถัง Storage ชื่อ `order-media`

### 3. เอา key มาใส่

Dashboard → **Settings → API** → คัดลอก **Project URL** กับ **anon public**

ใส่ใน `env.json` (ถูก gitignore ไว้แล้ว) ต่อจากของ Opn:

```json
{
  "OPN_PUBLIC_KEY": "pkey_test_xxxxx",
  "PAYMENT_API_BASE": "http://localhost:8080",

  "SUPABASE_URL": "https://xxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJI..."
}
```

### 4. รัน

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

เปิดห้องแชทแล้วดูมุมขวาบน — ขึ้น **"เรียลไทม์"** แปลว่าต่อติดแล้ว
ถ้าขึ้น **"ออฟไลน์"** แปลว่ายังใช้ repository ในหน่วยความจำอยู่

---

## ที่ต่อไว้แล้ว กับที่ยังไม่ได้ต่อ

| ส่วน | สถานะ |
|---|---|
| แชท | ✅ ต่อ Realtime แล้ว เปลี่ยนอัตโนมัติเมื่อมี key |
| อัปโหลดรูป | ✅ ต่อ Storage แล้ว |
| ล็อกอิน · ที่อยู่ · คำขอ · ข้อเสนอ · ออเดอร์ | ⏳ ยังใช้ในหน่วยความจำ + `shared_preferences` |

schema ของส่วนที่ยังไม่ต่อ **มีอยู่ครบแล้ว** ใน migration ที่รันไป
งานที่เหลือคือเขียน repository ใหม่ตาม interface เดิม แล้วสลับใน provider —
`presentation/` ไม่ต้องแก้เลย ซึ่งเป็นเหตุผลที่แยกชั้นไว้ตั้งแต่แรก

ตัวอย่างรูปแบบที่ใช้ได้เลย ดู `SupabaseChatRepository` คู่กับ
`MemoryChatRepository` แล้วดูวิธีสลับใน `chat_providers.dart`

---

## เรื่องที่ต้องรู้

**ล็อกอินตอนนี้เป็นของปลอม** — `MockAuthRepository` ไม่ได้สร้าง `auth.users`
จริงใน Supabase ดังนั้น `auth.uid()` จะเป็น null และ RLS จะบล็อกทุกอย่าง
ถ้าจะใช้ตารางที่ต้องยืนยันตัวตน ต้องย้ายไป `supabase.auth.signInWithOtp()` ก่อน

แชทกับ Storage ยังทำงานได้เพราะ policy อ่านเปิดกว้าง แต่การ **เขียน**
จะติด RLS จนกว่าจะมีผู้ใช้จริง — ถ้าอยากลองเขียนก่อนย้าย auth
ให้ปิด RLS ชั่วคราวเฉพาะตอน dev แล้ว **อย่าลืมเปิดคืน**

**สิทธิ์แอดมินอยู่ผิดที่โดยตั้งใจ** — ตอนนี้ `AppUser.isAdmin` เป็นค่าที่
ไคลเอนต์ถืออยู่ ซึ่งของจริงปลอมได้ ในฐานข้อมูลมี trigger `lock_admin_flag`
กันไม่ให้ผู้ใช้ยกระดับตัวเองแล้ว แต่การตัดสินใจว่าใครเห็นหน้าแอดมิน
ต้องย้ายไปอ่านจาก `profiles.is_admin` ผ่าน RLS แทน

**ข้อความและหลักฐานแก้ไม่ได้** — ตาราง `messages` กับถัง Storage
ไม่มี policy สำหรับ update/delete โดยตั้งใจ เพราะเป็นหลักฐานตอนเกิดข้อพิพาท
ถ้าแก้ย้อนหลังได้ก็ไม่ใช่หลักฐาน
