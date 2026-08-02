import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/photo_picker.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/chat_providers.dart';
import '../../chat/domain/message.dart';

/// อัปหลักฐานการซื้อ — สลิปและรูปสินค้า
///
/// **บังคับถ่ายจากกล้องเท่านั้น** ตามมาตรการใน `FundingPolicy.controls`
/// รูปจากแกลเลอรีอาจเป็นรูปที่โหลดมาจากเน็ตหรือของออเดอร์อื่น
/// ซึ่งทำให้คำว่า "หลักฐาน" ไม่มีความหมาย
///
/// รูปถูกส่งเข้าห้องแชทของออเดอร์ด้วย เพื่อให้มีเส้นเวลาเดียวที่ทั้งผู้ฝาก
/// และแอดมินย้อนดูได้ตอนเกิดข้อพิพาท
class ProofUploadSheet extends ConsumerStatefulWidget {
  const ProofUploadSheet({super.key, required this.orderId});

  final String orderId;

  static Future<bool?> show(BuildContext context, String orderId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => ProofUploadSheet(orderId: orderId),
    );
  }

  @override
  ConsumerState<ProofUploadSheet> createState() => _ProofUploadSheetState();
}

class _ProofUploadSheetState extends ConsumerState<ProofUploadSheet> {
  final _shots = <_Slot, PickedPhoto>{};
  bool _busy = false;
  String? _error;

  bool get _complete => _Slot.values.every(_shots.containsKey);

  Future<void> _capture(_Slot slot) async {
    setState(() => _error = null);
    try {
      final photo = await PhotoPicker.captureEvidence();
      if (photo == null || !mounted) return;
      setState(() => _shots[slot] = photo);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = 'เปิดกล้องไม่ได้: $e');
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final user = ref.read(currentUserProvider);
    final store = ref.read(mediaStoreProvider);
    final chat = ref.read(chatRepositoryProvider);
    final stamp = DateTime.now().microsecondsSinceEpoch;

    try {
      for (final slot in _Slot.values) {
        final photo = _shots[slot]!;
        final url = await store.upload(
          bytes: photo.bytes,
          path: 'orders/${widget.orderId}/proof/$stamp-${slot.name}.jpg',
        );

        await chat.send(
          Message(
            id: 'm$stamp${slot.name}',
            orderId: widget.orderId,
            senderId: user?.id ?? 'carrier',
            senderName: user?.displayName ?? 'นักหิ้ว',
            sentAt: DateTime.now(),
            kind: MessageKind.image,
            imageUrl: url,
          ),
        );
      }

      await chat.postSystemNote(
        widget.orderId,
        'นักหิ้วอัปหลักฐานการซื้อแล้ว (${_Slot.values.length} รูป · '
        'ถ่ายจากกล้องในแอป)',
      );

      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'อัปโหลดไม่สำเร็จ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final simulated = ref.watch(mediaStoreProvider).isSimulated;

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
              'อัปหลักฐานการซื้อ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'ถ่ายจากกล้องในแอปเท่านั้น เลือกจากแกลเลอรีไม่ได้ '
              'เพื่อให้หลักฐานปลอมย้อนหลังไม่ได้',
              style: TextStyle(
                color: AppColors.inkMuted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            for (final slot in _Slot.values) ...[
              _slotTile(slot),
              const SizedBox(height: 10),
            ],
            if (simulated) ...[
              const SizedBox(height: 4),
              const Text(
                'โหมดทดลอง — รูปเก็บในหน่วยความจำ หายเมื่อรีเฟรชหน้า',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _complete && !_busy ? _submit : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _complete
                          ? 'ส่งหลักฐาน'
                          : 'ถ่ายให้ครบ ${_Slot.values.length} รูปก่อน',
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('ยังไม่ส่งตอนนี้'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotTile(_Slot slot) {
    final photo = _shots[slot];

    return InkWell(
      onTap: _busy ? null : () => _capture(slot),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: photo == null ? Colors.white : AppColors.brandSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photo == null ? AppColors.line : AppColors.brand,
          ),
        ),
        child: Row(
          children: [
            if (photo == null)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.inkMuted),
              )
            else
              // รูปยังไม่ได้อัปโหลด จึงโชว์จาก bytes ที่เพิ่งถ่ายมาตรงๆ
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  photo.bytes,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    photo == null
                        ? slot.hint
                        : 'ถ่ายแล้ว · ${photo.sizeKB} KB',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: photo == null
                          ? AppColors.inkMuted
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              photo == null ? Icons.photo_camera : Icons.check_circle,
              size: 20,
              color: photo == null ? AppColors.inkMuted : AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

/// รูปที่ต้องมีครบก่อนถึงจะยืนยันว่าซื้อของแล้ว
enum _Slot {
  receipt('สลิป / ใบเสร็จ', 'ต้องเห็นยอดเงินและชื่อร้านชัดเจน'),
  product('ตัวสินค้า', 'ถ่ายให้เห็นของจริงที่ซื้อมา');

  const _Slot(this.title, this.hint);
  final String title;
  final String hint;
}
