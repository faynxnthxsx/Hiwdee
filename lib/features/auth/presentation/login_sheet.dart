import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// แผ่นล็อกอินแบบเด้งขึ้นมา — ใช้ตอนผู้ใช้ที่ยังไม่ล็อกอินกดปุ่มที่ต้องยืนยันตัวตน
/// ปิดแล้วผู้ใช้ยังอยู่หน้าเดิม ไม่หลุด flow (แบบ Shopee/Lazada)
class LoginSheet extends ConsumerStatefulWidget {
  const LoginSheet({super.key, this.reason});

  /// ข้อความบอกว่าทำไมต้องล็อกอิน เช่น "เข้าสู่ระบบเพื่อสั่งหิ้ว"
  final String? reason;

  @override
  ConsumerState<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<LoginSheet> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  _Step _step = _Step.phone;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _phoneValid =>
      RegExp(r'^0\d{9}$').hasMatch(_phoneCtrl.text.replaceAll('-', ''));

  Future<void> _sendOtp() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .requestOtp(_phoneCtrl.text);
    if (ok && mounted) setState(() => _step = _Step.otp);
  }

  Future<void> _verify() async {
    final ok = await ref.read(authControllerProvider.notifier).verifyOtp(
          phone: _phoneCtrl.text,
          otp: _otpCtrl.text,
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _register() async {
    final ok = await ref.read(authControllerProvider.notifier).register(
          phone: _phoneCtrl.text,
          displayName: _nameCtrl.text.trim(),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
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
          Text(
            switch (_step) {
              _Step.phone => 'เข้าสู่ระบบ / สมัครสมาชิก',
              _Step.otp => 'ยืนยันรหัส OTP',
              _Step.name => 'ตั้งชื่อที่จะแสดง',
            },
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            switch (_step) {
              _Step.phone =>
                widget.reason ?? 'ใส่เบอร์มือถือเพื่อรับรหัสยืนยัน',
              _Step.otp => 'ส่งรหัส 6 หลักไปที่ ${_phoneCtrl.text} แล้ว',
              _Step.name => 'ชื่อนี้จะแสดงให้อีกฝ่ายเห็นตอนติดต่อกัน',
            },
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ..._buildStepFields(),
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    auth.error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.isBusy ? null : _onPrimaryPressed,
            child: auth.isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(switch (_step) {
                    _Step.phone => 'ขอรหัส OTP',
                    _Step.otp => 'ยืนยัน',
                    _Step.name => 'เริ่มใช้งาน',
                  }),
          ),
          const SizedBox(height: 12),
          if (_step == _Step.phone)
            const Text(
              'ดูข้อมูลได้โดยไม่ต้องเข้าสู่ระบบ — '
              'เข้าสู่ระบบเฉพาะตอนสั่งหิ้วหรือรับหิ้วเท่านั้น',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
            )
          else
            TextButton(
              onPressed: () => setState(() => _step = _Step.phone),
              child: const Text('เปลี่ยนเบอร์'),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildStepFields() {
    switch (_step) {
      case _Step.phone:
        return [
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '08X-XXX-XXXX',
              counterText: '',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
        ];
      case _Step.otp:
        return [
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              setState(() {});
              if (v.length == 6) _verify();
            },
            decoration: const InputDecoration(counterText: ''),
          ),
          const SizedBox(height: 8),
          const Text(
            'โหมดทดลอง: ใส่ ${MockAuthRepository.demoOtp}',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
        ];
      case _Step.name:
        return [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'เช่น ฝ้าย',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ];
    }
  }

  void _onPrimaryPressed() {
    switch (_step) {
      case _Step.phone:
        if (_phoneValid) _sendOtp();
      case _Step.otp:
        if (_otpCtrl.text.length == 6) _verify();
      case _Step.name:
        if (_nameCtrl.text.trim().isNotEmpty) _register();
    }
  }
}

enum _Step { phone, otp, name }
