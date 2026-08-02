import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/payment_providers.dart';
import '../domain/payment_gateway.dart';

/// หน้าจ่ายเงินของออเดอร์
///
/// คืน true เมื่อจ่ายสำเร็จ ผู้เรียกค่อยเดินสถานะออเดอร์ต่อ
/// แยกความรับผิดชอบไว้แบบนี้เพื่อให้ "จ่ายเงิน" กับ "เปลี่ยนสถานะ" ไม่ปนกัน
class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({
    super.key,
    required this.orderId,
    required this.amountTHB,
  });

  final String orderId;
  final double amountTHB;

  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required double amountTHB,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      backgroundColor: Colors.white,
      builder: (_) => PaymentSheet(orderId: orderId, amountTHB: amountTHB),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();

  PaymentMethod _method = PaymentMethod.promptPay;
  bool _busy = false;
  String? _error;
  PaymentPending? _pending;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    super.dispose();
  }

  /// "12/28" → (12, 2028)
  (int month, int year)? get _expiry {
    final parts = _expiryCtrl.text.split('/');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0].trim());
    final y = int.tryParse(parts[1].trim());
    if (m == null || y == null) return null;
    return (m, y < 100 ? 2000 + y : y);
  }

  CardDetails? get _card {
    final exp = _expiry;
    if (exp == null) return null;
    return CardDetails(
      name: _nameCtrl.text,
      number: _numberCtrl.text,
      expiryMonth: exp.$1,
      expiryYear: exp.$2,
      securityCode: _cvcCtrl.text,
    );
  }

  bool get _canPay {
    if (_busy) return false;
    if (_method == PaymentMethod.promptPay) return true;
    return _card?.isComplete ?? false;
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(paymentGatewayProvider).charge(
          orderId: widget.orderId,
          amountTHB: widget.amountTHB,
          method: _method,
          card: _method == PaymentMethod.card ? _card : null,
        );

    if (!mounted) return;

    switch (result) {
      case PaymentSuccess():
        Navigator.of(context).pop(true);
      case PaymentPending():
        setState(() {
          _busy = false;
          _pending = result;
        });
      case PaymentFailure(:final message):
        setState(() {
          _busy = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(paymentGatewayProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'ชำระเงินเข้าระบบ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'ระบบถือเงินไว้จนกว่าคุณจะกดยืนยันรับของ',
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _amountBox(),
            if (gateway.isSimulated) ...[
              const SizedBox(height: 10),
              _simulatedBanner(gateway.displayName),
            ],
            const SizedBox(height: 18),
            if (_pending != null)
              _pendingView(_pending!)
            else ...[
              _methodPicker(),
              if (_method == PaymentMethod.card) ...[
                const SizedBox(height: 16),
                ..._cardFields(gateway.isSimulated),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorRow(_error!),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _canPay ? _pay : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('จ่าย ${Fmt.baht(widget.amountTHB)}'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('ยังไม่จ่ายตอนนี้'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _amountBox() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brandSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Text(
              'ยอดที่ต้องชำระ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              Fmt.baht(widget.amountTHB),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      );

  Widget _simulatedBanner(String name) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.science_outlined,
                size: 17, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$name — เงินไม่ถูกตัดจริง',
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
            ),
          ],
        ),
      );

  Widget _methodPicker() => Column(
        children: [
          for (final m in PaymentMethod.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() {
                  _method = m;
                  _error = null;
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _method == m ? AppColors.brandSoft : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _method == m ? AppColors.brand : AppColors.line,
                      width: _method == m ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m == PaymentMethod.promptPay
                            ? Icons.qr_code_2
                            : Icons.credit_card,
                        size: 22,
                        color: _method == m
                            ? AppColors.brand
                            : AppColors.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.description,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_method == m)
                        const Icon(Icons.check_circle,
                            size: 20, color: AppColors.brand),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

  List<Widget> _cardFields(bool simulated) => [
        if (simulated)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'บัตรทดสอบ: 4242 4242 4242 4242 · '
              'ลงท้าย 0002 = ถูกปฏิเสธ · 0003 = วงเงินไม่พอ',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'ชื่อบนบัตร',
            hintText: 'FAI NANTHASA',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _numberCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(19),
            _CardNumberFormatter(),
          ],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'เลขบัตร',
            hintText: '4242 4242 4242 4242',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'วันหมดอายุ',
                  hintText: 'MM/YY',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cvcCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'CVC',
                  hintText: '123',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.inkMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'เลขบัตรถูกส่งตรงไปผู้ให้บริการรับชำระเงิน '
                'ไม่ผ่านและไม่ถูกเก็บบนเซิร์ฟเวอร์ของเรา',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ];

  Widget _pendingView(PaymentPending pending) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                if (pending.qrImageUrl != null)
                  Image.network(
                    pending.qrImageUrl!,
                    height: 180,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.qr_code_2, size: 120),
                  )
                else
                  const Icon(Icons.qr_code_2,
                      size: 120, color: AppColors.ink),
                const SizedBox(height: 12),
                Text(
                  pending.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ของจริงต้องรอ webhook จากฝั่ง gateway ไม่ใช่ให้ผู้ใช้กดเอง
          // ปุ่มนี้มีไว้เพื่อให้เดิน flow ต่อได้ตอนยังไม่มี backend
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ฉันจ่ายแล้ว'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
        ],
      );

  Widget _errorRow(String message) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}

/// ใส่เว้นวรรคทุก 4 หลักระหว่างพิมพ์ ให้อ่านง่ายเหมือนบัตรจริง
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
