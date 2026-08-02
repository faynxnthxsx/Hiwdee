import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/auth_required_view.dart';
import '../data/address_repository.dart';
import '../domain/address.dart';

/// สมุดที่อยู่ — เลือกที่อยู่เริ่มต้น เพิ่ม แก้ไข ลบ
class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key, this.selectMode = false});

  /// true = เปิดมาเพื่อ "เลือก" ที่อยู่ (กดแล้ว pop ค่ากลับ)
  final bool selectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressListProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(title: Text(selectMode ? 'เลือกที่อยู่' : 'ที่อยู่ของฉัน')),
      body: addresses.isEmpty
          ? EmptyState(
              icon: Icons.location_off_outlined,
              message: 'ยังไม่มีที่อยู่จัดส่ง\nเพิ่มที่อยู่เพื่อใช้ตอนสั่งหิ้ว',
              action: OutlinedButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มที่อยู่'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: addresses.length,
              itemBuilder: (context, i) => _AddressCard(
                address: addresses[i],
                onTap: selectMode
                    ? () => Navigator.of(context).pop(addresses[i])
                    : null,
                onEdit: () => _openForm(context, initial: addresses[i]),
                onSetDefault: () => ref
                    .read(addressListProvider.notifier)
                    .setDefault(addresses[i].id),
                onDelete: () => _confirmDelete(context, ref, addresses[i]),
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มที่อยู่ใหม่'),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {Address? initial}) async {
    final saved = await context.push<Address>(
      AppRoutes.addressForm,
      extra: initial,
    );
    // ถ้าเปิดมาแบบ "เลือกที่อยู่" แล้วเพิ่งเพิ่มอันใหม่ ให้ส่งกลับไปใช้ต่อเลย
    if (saved != null && selectMode && context.mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบที่อยู่นี้?'),
        content: Text(address.fullLine),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      ref.read(addressListProvider.notifier).remove(address.id);
    }
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
    this.onTap,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: address.isDefault ? AppColors.brand : AppColors.line,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    address.receiverName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 12, color: AppColors.line),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.phone(address.phone),
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                address.fullLine,
                style: const TextStyle(height: 1.5, color: AppColors.ink),
              ),
              if (address.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'หมายเหตุ: ${address.note}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _tag(address.label.text, AppColors.inkMuted),
                  if (address.isDefault) ...[
                    const SizedBox(width: 6),
                    _tag('ค่าเริ่มต้น', AppColors.brand),
                  ],
                  const Spacer(),
                  if (!address.isDefault)
                    TextButton(
                      onPressed: onSetDefault,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('ตั้งเป็นค่าเริ่มต้น'),
                    ),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('ลบ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, color: color),
        ),
      );
}
