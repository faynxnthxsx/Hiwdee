# ตั้งค่าล็อกอิน Google · Facebook · เบอร์โทร

แอปรองรับสามทาง โดยสลับอัตโนมัติ: ไม่ได้ต่อ Supabase → ใช้ตัวปลอม
(OTP `123456`) ต่อแล้ว → ใช้ของจริง

| วิธี | ใช้ได้เมื่อไหร่ | ค่าใช้จ่าย |
|---|---|---|
| **Google** | ตั้งค่า ~10 นาที แล้วใช้ได้เลย | ฟรี |
| **Facebook** | ใช้ได้ทันทีแต่**เฉพาะบัญชีคุณเอง** จนกว่าจะผ่าน App Review | ฟรี |
| **เบอร์โทร** | ต้องผูก SMS provider ก่อน | จ่ายต่อ SMS |

---

## ก่อนอื่น — ตั้ง Redirect URL

Supabase → **Authentication → URL Configuration**

- **Site URL**: `http://localhost:5000`
- **Redirect URLs**: เพิ่ม `http://localhost:5000` ด้วย

ถ้าไม่ตั้ง ล็อกอินเสร็จแล้วจะเด้งไปหน้าอื่นหรือขึ้น error

> พอ deploy จริงต้องเพิ่ม URL ของโดเมนจริงเข้าไปอีกอัน

---

## Google

### 1. สร้าง OAuth client

[console.cloud.google.com](https://console.cloud.google.com) → สร้างโปรเจกต์

**APIs & Services → OAuth consent screen**
- User Type: **External**
- กรอกชื่อแอป อีเมลติดต่อ แล้ว Save
- ปล่อยไว้ที่โหมด **Testing** ก็ใช้ได้ แต่ต้องเพิ่มอีเมลตัวเองใน **Test users**

**APIs & Services → Credentials → Create Credentials → OAuth client ID**
- Application type: **Web application**
- Authorized redirect URIs ใส่:
  ```
  https://fxnaswqbtwpvzakvgqpw.supabase.co/auth/v1/callback
  ```
  (เอา URL โปรเจกต์คุณจาก Supabase → Settings → API)

จะได้ **Client ID** กับ **Client Secret**

### 2. เปิดใน Supabase

**Authentication → Providers → Google** → เปิด → วาง Client ID กับ Secret → Save

เสร็จแล้วกดปุ่ม "ดำเนินการต่อด้วย Google" ในแอปได้เลย

---

## Facebook

### 1. สร้างแอป

[developers.facebook.com](https://developers.facebook.com) → My Apps → Create App
- Use case: **Authenticate and request data from users with Facebook Login**
- ใส่ชื่อแอปกับอีเมล

**Facebook Login → Settings → Valid OAuth Redirect URIs**
```
https://fxnaswqbtwpvzakvgqpw.supabase.co/auth/v1/callback
```

**App settings → Basic** → คัดลอก **App ID** กับ **App Secret**

### 2. เปิดใน Supabase

**Authentication → Providers → Facebook** → เปิด → วาง App ID กับ Secret → Save

### ข้อจำกัดที่ต้องรู้

แอปใหม่จะอยู่ใน **Development mode** ซึ่ง **ล็อกอินได้เฉพาะบัญชีที่เป็น
Admin / Developer / Tester ของแอปนั้น** — คนอื่นจะขึ้น error

จะให้คนทั่วไปใช้ได้ต้องส่ง **App Review** ขอ permission `public_profile`
กับ `email` และ Meta อาจขอ **Business Verification** เพิ่ม
ซึ่งใช้เวลาหลายวันถึงหลายสัปดาห์

> ระหว่างนี้เพิ่มเพื่อนที่อยากให้ทดสอบเข้าไปใน **Roles → Testers** ได้

---

## เบอร์โทร + OTP

Supabase **ไม่ได้ส่ง SMS ให้** ต้องผูกผู้ให้บริการเอง

**Authentication → Providers → Phone** → เปิด → เลือก provider
(Twilio, MessageBird, Vonage, Textlocal)

ต้นทุนคร่าวๆ: Twilio คิดต่อข้อความ และการส่งเข้าเบอร์ไทยต้องลงทะเบียน
**sender ID** กับผู้ให้บริการในไทยก่อน ไม่งั้นข้อความอาจไม่ถึง

**ถ้ายังไม่ได้ผูก** แอปจะจับ error แล้วขึ้นข้อความว่า
*"ยังส่ง SMS ไม่ได้ เพราะยังไม่ได้ผูกผู้ให้บริการ SMS — ลองใช้ Google
หรือ Facebook แทนไปก่อน"* แทนที่จะโชว์ error ดิบของ Supabase

### รูปแบบเบอร์

Supabase ต้องการ E.164 (`+66812345678`) แต่ผู้ใช้ไทยพิมพ์ `0812345678`
`SupabaseAuthRepository._toE164` แปลงให้อัตโนมัติแล้ว

---

## ตรวจว่าใช้ของจริงอยู่หรือเปล่า

เปิดห้องแชท ดูมุมขวาบน — **"เรียลไทม์"** = ต่อ Supabase อยู่

หรือดู log ตอนรัน จะขึ้น `***** Supabase init completed *****`

---

## หลังล็อกอินสำเร็จแล้วเกิดอะไรขึ้น

1. Supabase สร้างแถวใน `auth.users` ให้เอง
2. แอป upsert เข้า `public.profiles` (id, ชื่อ, เบอร์, รูป)
3. `auth.uid()` มีค่าแล้ว → **RLS เริ่มทำงาน** → เขียนแชทและอัปโหลดรูปได้

ข้อ 3 คือเหตุผลทั้งหมดของงานนี้ ก่อนหน้านี้ `auth.uid()` เป็น null
RLS จึงบล็อกการเขียนทุกอย่าง

> `is_admin` ตั้งจากไคลเอนต์ไม่ได้ — ฐานข้อมูลมี trigger `lock_admin_flag`
> กันไว้ ต้องไปเปิดใน SQL Editor เอง:
> ```sql
> update public.profiles set is_admin = true where id = 'ใส่ uuid';
> ```
