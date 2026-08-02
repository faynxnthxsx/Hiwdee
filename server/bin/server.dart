import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// เซิร์ฟเวอร์ที่มีหน้าที่เดียว: ถือ secret key ไว้สร้าง charge
///
/// มีเพราะ secret key อยู่ในแอป Flutter ไม่ได้ — โค้ดฝั่งไคลเอนต์ถอดดูได้เสมอ
/// ไม่ว่าจะเป็น Web (ไฟล์ JS เปิดอ่านได้) หรือมือถือ (แกะ APK ได้)
///
/// รัน:
/// ```
/// dart pub get
/// OPN_SECRET_KEY=skey_test_xxxxx dart run bin/server.dart
/// ```
/// บน PowerShell:
/// ```
/// $env:OPN_SECRET_KEY="skey_test_xxxxx"; dart run bin/server.dart
/// ```

const _omiseChargesUrl = 'https://api.omise.co/charges';

/// ยอดที่ถูกต้องของแต่ละออเดอร์
///
/// ของจริงต้องอ่านจากฐานข้อมูล — ใส่ไว้ในหน่วยความจำเพราะ scaffold นี้
/// ยังไม่มี DB ร่วมกับแอป ดู [_resolveAmount] สำหรับกรณีที่หาไม่เจอ
final _orderAmounts = <String, int>{};

/// หายอดที่จะเก็บจริง
///
/// **กติกาข้อสำคัญที่สุดของงานนี้: อย่าเชื่อยอดที่ไคลเอนต์ส่งมา**
/// ผู้ใช้แก้ค่าก่อนส่งได้เสมอ ถ้าเชื่อตรงๆ ใครก็จ่าย 1 บาทแทน 15,000 ได้
///
/// scaffold นี้ยังไม่มี DB ร่วมกับแอป จึงยอมถอยไปใช้ค่าจากไคลเอนต์
/// แต่ **ตะโกนเตือนทุกครั้ง** เพื่อไม่ให้เผลอเอาขึ้นของจริงทั้งอย่างนี้
int? _resolveAmount(String orderId, Object? clientAmount) {
  final known = _orderAmounts[orderId];
  if (known != null) return known;

  if (clientAmount is! int || clientAmount <= 0) return null;

  stderr.writeln(
    '⚠️  ใช้ยอดจากไคลเอนต์สำหรับออเดอร์ $orderId ($clientAmount สตางค์)\n'
    '    ห้ามทำแบบนี้บนของจริง — ต้องอ่านยอดจากฐานข้อมูลฝั่งเซิร์ฟเวอร์',
  );
  return clientAmount;
}

Future<Response> _createCharge(Request req) async {
  final secretKey = Platform.environment['OPN_SECRET_KEY'];
  if (secretKey == null || secretKey.isEmpty) {
    return _json(500, {'message': 'เซิร์ฟเวอร์ยังไม่ได้ตั้ง OPN_SECRET_KEY'});
  }
  if (!secretKey.startsWith('skey_')) {
    return _json(500, {
      'message': 'OPN_SECRET_KEY ไม่ใช่ secret key — ต้องขึ้นต้นด้วย skey_',
    });
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  } on Object {
    return _json(400, {'message': 'อ่าน request body ไม่ได้'});
  }

  final orderId = body['orderId'] as String?;
  if (orderId == null || orderId.isEmpty) {
    return _json(400, {'message': 'ไม่ได้ระบุ orderId'});
  }

  final amount = _resolveAmount(orderId, body['amount']);
  if (amount == null) {
    return _json(400, {'message': 'ยอดชำระไม่ถูกต้อง'});
  }

  final token = body['token'] as String?;
  final method = body['method'] as String?;

  if (method == 'card' && (token == null || token.isEmpty)) {
    return _json(400, {'message': 'จ่ายด้วยบัตรต้องมี token'});
  }

  final auth = base64Encode(utf8.encode('$secretKey:'));
  final res = await http.post(
    Uri.parse(_omiseChargesUrl),
    headers: {'Authorization': 'Basic $auth'},
    body: {
      'amount': amount.toString(),
      'currency': 'THB',
      'card': ?token,
      if (method == 'promptPay') 'source[type]': 'promptpay',
      'metadata[orderId]': orderId,
    },
  );

  final charge = jsonDecode(res.body);
  if (charge is! Map<String, dynamic>) {
    return _json(502, {'message': 'Opn ตอบกลับมาในรูปแบบที่อ่านไม่ออก'});
  }

  if (res.statusCode >= 400) {
    return _json(res.statusCode, {
      'message': charge['message'] as String? ?? 'สร้าง charge ไม่สำเร็จ',
    });
  }

  stdout.writeln(
    '✓ ${charge['status']} · ${charge['id']} · $amount สตางค์ · $orderId',
  );

  return _json(200, {
    'id': charge['id'],
    'status': charge['status'],
    'amount': charge['amount'],
    'failureMessage': charge['failure_message'],
    'qrImageUrl': _qrUrlOf(charge),
  });
}

/// QR ของพร้อมเพย์ฝังลึกอยู่ในโครงสร้าง source ของ Omise
String? _qrUrlOf(Map<String, dynamic> charge) {
  final source = charge['source'];
  if (source is! Map<String, dynamic>) return null;
  final code = source['scannable_code'];
  if (code is! Map<String, dynamic>) return null;
  final image = code['image'];
  if (image is! Map<String, dynamic>) return null;
  return image['download_uri'] as String?;
}

Response _json(int status, Map<String, dynamic> body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

/// Flutter Web รันคนละพอร์ตกับเซิร์ฟเวอร์ เบราว์เซอร์จึงบล็อกถ้าไม่มี CORS
///
/// เปิดกว้างแบบนี้ได้เฉพาะตอน dev — ของจริงต้องระบุ origin ให้ชัด
Middleware _devCors() => (handler) => (req) async {
      const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      };

      if (req.method == 'OPTIONS') return Response.ok(null, headers: headers);

      final res = await handler(req);
      return res.change(headers: headers);
    };

void main() async {
  final router = Router()
    ..post('/charges', _createCharge)
    ..get('/health', (Request _) => _json(200, {'ok': true}));

  final handler =
      const Pipeline().addMiddleware(_devCors()).addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  await io.serve(handler, 'localhost', port);

  final hasKey = Platform.environment['OPN_SECRET_KEY']?.isNotEmpty ?? false;
  stdout.writeln('พร้อมที่ http://localhost:$port');
  stdout.writeln(
    hasKey
        ? 'อ่าน OPN_SECRET_KEY เรียบร้อย'
        : '⚠️  ยังไม่ได้ตั้ง OPN_SECRET_KEY — เรียก /charges แล้วจะได้ 500',
  );
}
