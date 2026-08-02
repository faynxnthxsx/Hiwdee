import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/thai_geo_repository.dart';
import '../domain/thai_geo.dart';

/// ผลลัพธ์จากตัวเลือกพื้นที่ — ครบทั้ง 3 ระดับ + ไปรษณีย์
class GeoSelection {
  const GeoSelection({
    required this.province,
    required this.district,
    required this.subdistrict,
  });

  final Province province;
  final District district;
  final Subdistrict subdistrict;

  int get postalCode => subdistrict.postalCode;

  String get label =>
      '${subdistrict.nameTh}, ${district.nameTh}, ${province.nameTh}, $postalCode';
}

Future<GeoSelection?> showGeoPicker(BuildContext context) {
  return showModalBottomSheet<GeoSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _GeoPickerSheet(),
  );
}

/// ตัวเลือกพื้นที่แบบไล่ระดับ จังหวัด → เขต/อำเภอ → แขวง/ตำบล
/// เลือกครบแล้วเติมรหัสไปรษณีย์ให้อัตโนมัติ (แบบ Shopee/Lazada)
class _GeoPickerSheet extends ConsumerStatefulWidget {
  const _GeoPickerSheet();

  @override
  ConsumerState<_GeoPickerSheet> createState() => _GeoPickerSheetState();
}

class _GeoPickerSheetState extends ConsumerState<_GeoPickerSheet> {
  final _searchCtrl = TextEditingController();

  Province? _province;
  District? _district;

  int get _level => _province == null ? 0 : (_district == null ? 1 : 2);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetTo(int level) {
    setState(() {
      _searchCtrl.clear();
      if (level == 0) {
        _province = null;
        _district = null;
      } else if (level == 1) {
        _district = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final geoAsync = ref.watch(thaiGeoRepositoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _handle(),
            _header(),
            _breadcrumbs(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: switch (_level) {
                    0 => 'ค้นหาจังหวัด',
                    1 => 'ค้นหาเขต / อำเภอ',
                    _ => 'ค้นหาแขวง / ตำบล',
                  },
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: geoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('โหลดข้อมูลพื้นที่ไม่สำเร็จ\n$e',
                        textAlign: TextAlign.center),
                  ),
                ),
                data: (geo) => _list(geo, scrollController),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _handle() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'เลือกพื้นที่',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  /// แถบขั้นตอน กดย้อนกลับไปแก้ระดับก่อนหน้าได้
  Widget _breadcrumbs() {
    final crumbs = <(String, int)>[
      (_province?.nameTh ?? 'จังหวัด', 0),
      if (_province != null) (_district?.nameTh ?? 'เขต / อำเภอ', 1),
      if (_district != null) ('แขวง / ตำบล', 2),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: crumbs.length,
        separatorBuilder: (_, _) => const Icon(
          Icons.chevron_right,
          size: 18,
          color: AppColors.inkMuted,
        ),
        itemBuilder: (context, i) {
          final (text, level) = crumbs[i];
          final isActive = level == _level;
          return Center(
            child: InkWell(
              onTap: level < _level ? () => _resetTo(level) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.brand : AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _list(ThaiGeoRepository geo, ScrollController controller) {
    final query = _searchCtrl.text;

    final items = switch (_level) {
      0 => geo
          .provinces(query: query)
          .map((p) => _Row(p.nameTh, () => setState(() {
                _province = p;
                _searchCtrl.clear();
              })))
          .toList(),
      1 => geo
          .districtsOf(_province!.code, query: query)
          .map((d) => _Row(d.nameTh, () => setState(() {
                _district = d;
                _searchCtrl.clear();
              })))
          .toList(),
      _ => geo
          .subdistrictsOf(_district!.code, query: query)
          .map((s) => _Row('${s.nameTh}  ·  ${s.postalCode}', () {
                Navigator.of(context).pop(
                  GeoSelection(
                    province: _province!,
                    district: _district!,
                    subdistrict: s,
                  ),
                );
              }))
          .toList(),
    };

    if (items.isEmpty) {
      return const Center(
        child: Text('ไม่พบพื้นที่ที่ค้นหา',
            style: TextStyle(color: AppColors.inkMuted)),
      );
    }

    return ListView.separated(
      controller: controller,
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) => ListTile(
        title: Text(items[i].label, style: const TextStyle(fontSize: 15)),
        trailing: _level < 2
            ? const Icon(Icons.chevron_right, color: AppColors.inkMuted)
            : null,
        onTap: items[i].onTap,
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}
