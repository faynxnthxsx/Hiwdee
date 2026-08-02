# ต่อระบบรับชำระเงินจริง (Opn Payments)

แอปทำงานได้เลยโดยไม่ต้องมี key — จะใช้ `MockPaymentGateway` ที่จำลองทั้งเคสสำเร็จ
และเคสล้มเหลว เอกสารนี้สำหรับตอนที่อยากต่อของจริงใน sandbox

---

## ทำไมต้องมีเซิร์ฟเวอร์

Opn มี key สองตัว และมีแค่ตัวเดียวที่อยู่ในแอปได้

| Key | หน้าที่ | อยู่ในแอปได้ไหม |
|---|---|---|
| `pkey_test_...` | แลกเลขบัตรเป็น token | ได้ |
| `skey_test_...` | สร้าง charge / คืนเงิน / ดูรายการ | **ไม่ได้เด็ดขาด** |

โค้ดฝั่งไคลเอนต์ถอดดูได้เสมอ ไม่ว่าจะซ่อนดีแค่ไหน — Flutter Web คือไฟล์ JS
ที่เปิดอ่านได้ ส่วนแอปมือถือก็แกะ APK ได้ ใครได้ secret key ไปก็สั่งตัดเงิน
หรือคืนเงินในนามคุณได้ทันที

ข้อดีของการแบ่งแบบนี้คือ **เลขบัตรจริงไม่เคยผ่านเซิร์ฟเวอร์ของคุณ** —
แอปยิงตรงไป `vault.omise.co` ทำให้ขอบเขตที่ต้องดูแลตาม PCI-DSS แคบลงมาก

---

## ขั้นตอน

### 1. เอา key มา

สมัครที่ [opn.ooo](https://www.opn.ooo) → เข้า Dashboard → **Keys**
เลือกโหมด **Test** จะได้ `pkey_test_...` กับ `skey_test_...`

โหมด test ไม่ต้องมีบริษัท ไม่ต้องส่งเอกสาร ใช้แค่อีเมล

### 2. รันเซิร์ฟเวอร์เล็กๆ

ต้องมี endpoint เดียวคือ `POST /charges`

<details>
<summary>ตัวอย่างด้วย Dart + shelf (โฟลเดอร์แยกจากแอป)</summary>

```dart
// bin/server.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// อ่านจาก environment ไม่ใช่ฝังในโค้ด
final secretKey = Platform.environment['OPN_SECRET_KEY']!;

/// ของจริงต้องอ่านยอดจากฐานข้อมูล ไม่ใช่เชื่อค่าที่ไคลเอนต์ส่งมา
final orderAmounts = <String, int>{};

Future<Response> createCharge(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final orderId = body['orderId'] as String;

  // ห้ามใช้ body['amount'] ตรงๆ — ผู้ใช้แก้ค่าก่อนส่งได้
  final amount = orderAmounts[orderId];
  if (amount == null) {
    return Response.notFound(jsonEncode({'message': 'ไม่พบออเดอร์นี้'}));
  }

  final auth = base64Encode(utf8.encode('$secretKey:'));
  final res = await http.post(
    Uri.parse('https://api.omise.co/charges'),
    headers: {'Authorization': 'Basic $auth'},
    body: {
      'amount': amount.toString(),
      'currency': 'THB',
      if (body['token'] != null) 'card': body['token'] as String,
      if (body['method'] == 'promptPay') 'source[type]': 'promptpay',
      'metadata[orderId]': orderId,
    },
  );

  final charge = jsonDecode(res.body) as Map<String, dynamic>;

  return Response.ok(
    jsonEncode({
      'id': charge['id'],
      'status': charge['status'],
      'amount': charge['amount'],
      'failureMessage': charge['failure_message'],
      'qrImageUrl': charge['source']?['scannable_code']?['image']?['download_uri'],
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

void main() async {
  final router = Router()..post('/charges', createCharge);

  // ตอน dev เท่านั้น — ของจริงต้องจำกัด origin
  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  await io.serve(handler, 'localhost', 8080);
  print('พร้อมที่ http://localhost:8080');
}
```

รันด้วย:
```bash
OPN_SECRET_KEY=skey_test_xxxxx dart run bin/server.dart
```

</details>

### 3. เอา key ใส่ที่ไหน

**key คนละตัวไปคนละที่ อย่าสลับกัน**

| Key | ที่อยู่ | เข้า git ไหม |
|---|---|---|
| `pkey_test_...` | `env.json` ในโปรเจกต์ | ไม่ (gitignore แล้ว) |
| `skey_test_...` | environment variable ของเซิร์ฟเวอร์ | ไม่ |

ก๊อปแม่แบบมาแล้วใส่ค่า:

```bash
cp env.example.json env.json
```

```json
{
  "OPN_PUBLIC_KEY": "pkey_test_5xxxxxxxxxxxxxxxx",
  "PAYMENT_API_BASE": "http://localhost:8080"
}
```

> **ห้ามใส่ `skey_` ใน `env.json`** — ทุกค่าในไฟล์นี้ถูกคอมไพล์ฝังเข้าไปในแอป
> ใครเปิด DevTools ก็เห็น

ฝั่งเซิร์ฟเวอร์ใส่ผ่าน environment แทน ไม่ต้องมีไฟล์:

```bash
OPN_SECRET_KEY=skey_test_xxxxx dart run bin/server.dart
```

### 4. รันแอป

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

ไม่มี `env.json` หรือค่าว่าง → แอปกลับไปใช้ตัวจำลองเองอัตโนมัติ
(`PaymentConfig.isLive`) ไม่พังและยังเล่นได้ครบ

<details>
<summary>ตั้งใน Android Studio / IntelliJ ให้กด Run ได้เลย</summary>

**Run → Edit Configurations → Additional run args**

```
--dart-define-from-file=env.json
```

</details>

<details>
<summary>ตั้งใน VS Code</summary>

`.vscode/launch.json`

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "HiewDee (ต่อ Opn)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file=env.json"]
    }
  ]
}
```

</details>

---

## บัตรทดสอบ

| เลขบัตร | ผลลัพธ์ |
|---|---|
| `4242 4242 4242 4242` | สำเร็จ |
| ลงท้าย `0002` | ถูกปฏิเสธ |
| ลงท้าย `0003` | วงเงินไม่พอ |

ใส่วันหมดอายุเป็นอนาคตอะไรก็ได้ CVC สามหลักอะไรก็ได้

---

## สามข้อที่ห้ามลืมตอนขึ้นของจริง

**1. อย่าเชื่อยอดที่ไคลเอนต์ส่งมา**
เซิร์ฟเวอร์ต้องเปิดออเดอร์ในฐานข้อมูลแล้วคิดยอดใหม่เอง ไม่งั้นผู้ใช้แก้เป็น 1 บาทได้

**2. พร้อมเพย์ต้องรอ webhook**
ปุ่ม "ฉันจ่ายแล้ว" ในแอปมีไว้เดิน flow ตอน dev เท่านั้น ของจริงต้องให้ Opn
ยิง webhook มาบอกว่า charge สำเร็จ แล้วเซิร์ฟเวอร์ค่อยเปลี่ยนสถานะออเดอร์
ถ้าเชื่อปุ่มฝั่งผู้ใช้ ใครก็กดผ่านได้โดยไม่ต้องจ่าย

**3. ยอดเป็นสตางค์**
`toSatang()` ใน `payment_gateway.dart` จัดการให้แล้ว ฝั่งเซิร์ฟเวอร์ก็ต้องคิดหน่วย
เดียวกัน ส่ง `1250` ทั้งที่ตั้งใจเก็บ ฿1,250 จะกลายเป็นเก็บจริง ฿12.50

---

## เรื่องกฎหมายที่ต้องรู้ก่อนรับเงินจริง

การถือเงินลูกค้าไว้ก่อนแล้วค่อยจ่ายให้อีกฝ่าย เข้าข่าย
**พ.ร.บ. ระบบการชำระเงิน พ.ศ. 2560** (กำกับโดย ธปท.) และอาจเข้าข่าย
**พ.ร.บ. การดูแลผลประโยชน์ของคู่สัญญา พ.ศ. 2551** ซึ่งกำหนดให้ผู้ทำหน้าที่
escrow ต้องได้รับอนุญาต

ทางที่มาร์เก็ตเพลสส่วนใหญ่ใช้คือ **ไม่ถือเงินเอง** — ให้ gateway ที่มีใบอนุญาต
เป็นคนถือ แล้วแพลตฟอร์มแค่สั่งว่าปล่อยเงินเมื่อไหร่ ซึ่งตรงกับที่
`FundingMethod.platformDirect` ออกแบบไว้อยู่แล้ว

เอกสารนี้ไม่ใช่คำแนะนำทางกฎหมาย ก่อนรับเงินจริงควรตรวจกับ
[bot.or.th](https://www.bot.or.th) และปรึกษาทนาย
