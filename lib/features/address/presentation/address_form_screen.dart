import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/address_repository.dart';
import '../domain/address.dart';
import 'geo_picker_sheet.dart';

/// ฟอร์มที่อยู่จัดส่ง วางฟิลด์ตามแบบ Shopee/Lazada
/// - ข้อมูลผู้ติดต่อ / ที่อยู่ / ป้ายกำกับ / ตั้งเป็นค่าเริ่มต้น
/// - ช่องพื้นที่เป็นช่องเดียวไล่เลือก 3 ระดับ แล้วเติมไปรษณีย์ให้อัตโนมัติ
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.initial});

  /// ส่งมาเมื่อเป็นการแก้ไขที่อยู่เดิม
  final Address? initial;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _lineCtrl;
  late final TextEditingController _noteCtrl;

  GeoSelection? _geo;
  late AddressLabel _label;
  late bool _isDefault;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    final user = ref.read(currentUserProvider);

    _nameCtrl = TextEditingController(text: a?.receiverName ?? user?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: a?.phone ?? user?.phone ?? '');
    _lineCtrl = TextEditingController(text: a?.line1 ?? '');
    _noteCtrl = TextEditingController(text: a?.note ?? '');
    _label = a?.label ?? AddressLabel.home;
    // ที่อยู่แรกของผู้ใช้ให้เป็นค่าเริ่มต้นเลย
    _isDefault = a?.isDefault ?? ref.read(addressListProvider).isEmpty;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _lineCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String? get _areaText {
    if (_geo != null) return _geo!.label;
    final a = widget.initial;
    if (a != null) return a.areaLine;
    return null;
  }

  Future<void> _pickArea() async {
    final result = await showGeoPicker(context);
    if (result != null) setState(() => _geo = result);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_areaText == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกจังหวัด / เขต / แขวง')),
      );
      return;
    }

    final base = widget.initial;
    final geo = _geo;

    final address = Address(
      id: base?.id ?? 'addr_${DateTime.now().microsecondsSinceEpoch}',
      receiverName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      provinceCode: geo?.province.code ?? base!.provinceCode,
      provinceName: geo?.province.nameTh ?? base!.provinceName,
      districtCode: geo?.district.code ?? base!.districtCode,
      districtName: geo?.district.nameTh ?? base!.districtName,
      subdistrictCode: geo?.subdistrict.code ?? base!.subdistrictCode,
      subdistrictName: geo?.subdistrict.nameTh ?? base!.subdistrictName,
      postalCode: geo?.postalCode ?? base!.postalCode,
      line1: _lineCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      label: _label,
      isDefault: _isDefault,
    );

    ref.read(addressListProvider.notifier).upsert(address);
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: Text(_isEdit ? 'แก้ไขที่อยู่' : 'เพิ่มที่อยู่ใหม่'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _sectionLabel('ข้อมูลผู้ติดต่อ'),
            _card([
              _field(
                controller: _nameCtrl,
                label: 'ชื่อ-นามสกุล ผู้รับ',
                hint: 'เช่น สมชาย ใจดี',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อผู้รับ' : null,
              ),
              const Divider(height: 1),
              _field(
                controller: _phoneCtrl,
                label: 'เบอร์โทรศัพท์',
                hint: '08X-XXX-XXXX',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) => RegExp(r'^0\d{9}$').hasMatch(v ?? '')
                    ? null
                    : 'เบอร์ต้องเป็นตัวเลข 10 หลัก ขึ้นต้นด้วย 0',
              ),
            ]),
            _sectionLabel('ที่อยู่'),
            _card([
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  _areaText ?? 'จังหวัด, เขต/อำเภอ, แขวง/ตำบล, รหัสไปรษณีย์',
                  style: TextStyle(
                    fontSize: 15,
                    color: _areaText == null
                        ? AppColors.inkMuted
                        : AppColors.ink,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.inkMuted),
                onTap: _pickArea,
              ),
              const Divider(height: 1),
              _field(
                controller: _lineCtrl,
                label: 'บ้านเลขที่ / หมู่ / ซอย / ถนน',
                hint: 'เช่น 99/1 ม.5 ซ.ลาดพร้าว 15 ถ.ลาดพร้าว',
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'กรุณากรอกรายละเอียดที่อยู่'
                    : null,
              ),
              const Divider(height: 1),
              _field(
                controller: _noteCtrl,
                label: 'หมายเหตุถึงผู้ส่ง (ไม่บังคับ)',
                hint: 'เช่น ฝากไว้ที่นิติบุคคล / โทรก่อนส่ง',
              ),
            ]),
            _sectionLabel('ตั้งค่า'),
            _card([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    const Text('ป้ายกำกับ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final l in AddressLabel.values)
                          ChoiceChip(
                            label: Text(l.text),
                            selected: _label == l,
                            onSelected: (_) => setState(() => _label = l),
                            selectedColor: AppColors.brandSoft,
                            labelStyle: TextStyle(
                              color: _label == l
                                  ? AppColors.brand
                                  : AppColors.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('ตั้งเป็นที่อยู่เริ่มต้น'),
                subtitle: const Text(
                  'ใช้ที่อยู่นี้อัตโนมัติตอนสั่งหิ้ว',
                  style: TextStyle(fontSize: 12),
                ),
                activeThumbColor: AppColors.brand,
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _save,
          child: const Text('บันทึกที่อยู่'),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
      );

  /// Material ไม่ใช่ Container เพราะข้างในมี ListTile/SwitchListTile
  /// ที่วาดพื้นหลังและ ink splash ลงบน Material ที่ใกล้ที่สุด
  /// ถ้าคั่นด้วย ColoredBox ทึบ เอฟเฟกต์จะถูกบัง
  Widget _card(List<Widget> children) => Material(
        color: Colors.white,
        child: Column(children: children),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
