import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../address/data/address_repository.dart';
import '../../address/domain/address.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/request_repository.dart';
import '../domain/haul_request.dart';

/// ฟอร์มโพสต์คำขอฝากหิ้ว — เข้ามาถึงหน้านี้ได้แปลว่าล็อกอิน + มีที่อยู่แล้ว
class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _budgetCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  HaulCategory _category = HaulCategory.beauty;
  OriginType _originType = OriginType.abroad;
  DateTime _deadline = DateTime.now().add(const Duration(days: 14));

  /// ที่อยู่ที่เลือกไว้สำหรับคำขอนี้ (ค่าเริ่มต้นคือที่อยู่หลัก)
  Address? _address;

  @override
  void initState() {
    super.initState();
    _address = ref.read(defaultAddressProvider);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _originCtrl.dispose();
    _qtyCtrl.dispose();
    _budgetCtrl.dispose();
    _feeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _changeAddress() async {
    final picked = await context.push<Address>(AppRoutes.addresses);
    if (picked != null) setState(() => _address = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final request = HaulRequest(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      category: _category,
      originType: _originType,
      originName: _originCtrl.text.trim(),
      quantity: int.parse(_qtyCtrl.text),
      budgetMax: double.parse(_budgetCtrl.text),
      serviceFeeOffer: double.parse(_feeCtrl.text),
      deadline: _deadline,
      requesterName: ref.read(currentUserProvider)?.displayName ?? 'ฉัน',
      createdAt: DateTime.now(),
      note: _noteCtrl.text.trim(),
    );

    ref.read(requestListProvider.notifier).add(request);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('โพสต์คำขอเรียบร้อย รอนักหิ้วเสนอราคา')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(title: const Text('ฝากหิ้วของ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _addressCard(),
            _label('ของที่อยากได้'),
            _card([
              _text(
                controller: _titleCtrl,
                hint: 'เช่น SK-II Facial Treatment Essence 230ml',
                validator: (v) => (v == null || v.trim().length < 4)
                    ? 'ใส่ชื่อสินค้าให้ชัดเจนหน่อยนะ'
                    : null,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in HaulCategory.values)
                      ChoiceChip(
                        label: Text('${c.emoji} ${c.text}'),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                        selectedColor: AppColors.brandSoft,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _category == c
                              ? AppColors.brand
                              : AppColors.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ]),
            _label('หิ้วมาจากไหน'),
            _card([
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SegmentedButton<OriginType>(
                  segments: const [
                    ButtonSegment(
                      value: OriginType.abroad,
                      label: Text('ต่างประเทศ'),
                      icon: Icon(Icons.flight_takeoff, size: 18),
                    ),
                    ButtonSegment(
                      value: OriginType.domestic,
                      label: Text('ในประเทศ'),
                      icon: Icon(Icons.place, size: 18),
                    ),
                  ],
                  selected: {_originType},
                  onSelectionChanged: (s) =>
                      setState(() => _originType = s.first),
                ),
              ),
              _text(
                controller: _originCtrl,
                hint: _originType == OriginType.abroad
                    ? 'เช่น ญี่ปุ่น · โตเกียว'
                    : 'เช่น เชียงใหม่',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'ระบุแหล่งที่จะให้ไปหิ้ว'
                    : null,
              ),
            ]),
            _label('จำนวนและงบประมาณ'),
            _card([
              Row(
                children: [
                  Expanded(
                    child: _text(
                      controller: _qtyCtrl,
                      hint: 'จำนวน (ชิ้น)',
                      keyboardType: TextInputType.number,
                      validator: _positiveInt,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.line),
                  Expanded(
                    child: _text(
                      controller: _budgetCtrl,
                      hint: 'งบค่าของสูงสุด (บาท)',
                      keyboardType: TextInputType.number,
                      validator: _positiveNum,
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              _text(
                controller: _feeCtrl,
                hint: 'ค่าจ้างหิ้วที่ยินดีจ่าย (บาท)',
                keyboardType: TextInputType.number,
                validator: _positiveNum,
              ),
            ]),
            _label('กำหนดเวลา'),
            _card([
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('ต้องได้ของภายใน'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Fmt.thaiDate(_deadline),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.inkMuted),
                  ],
                ),
                onTap: _pickDeadline,
              ),
            ]),
            _label('รายละเอียดเพิ่มเติม'),
            _card([
              _text(
                controller: _noteCtrl,
                hint: 'เช่น ขอกล่องซีล ไม่เอา tester / ขอใบเสร็จด้วย',
                maxLines: 3,
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _submit,
          child: const Text('โพสต์คำขอ'),
        ),
      ),
    );
  }

  /// แถบที่อยู่จัดส่งด้านบนสุด — วางแบบเดียวกับหน้าเช็คเอาต์ของช้อปปี้
  Widget _addressCard() {
    final a = _address;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const Icon(Icons.location_on_outlined, color: AppColors.brand),
        title: a == null
            ? const Text('เลือกที่อยู่จัดส่ง')
            : Text(
                '${a.receiverName}  ${Fmt.phone(a.phone)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
        subtitle: a == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  a.fullLine,
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          onTap: _changeAddress,
        ),
      ),
    );
  }

  String? _positiveInt(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n <= 0) ? 'ใส่จำนวนเต็มมากกว่า 0' : null;
  }

  String? _positiveNum(String? v) {
    final n = double.tryParse(v ?? '');
    return (n == null || n <= 0) ? 'ใส่จำนวนเงินมากกว่า 0' : null;
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
      );

  /// Material ไม่ใช่ Container เพราะข้างในมี ListTile
  /// ที่วาดพื้นหลังและ ink splash ลงบน Material ที่ใกล้ที่สุด
  Widget _card(List<Widget> children) =>
      Material(color: Colors.white, child: Column(children: children));

  Widget _text({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
