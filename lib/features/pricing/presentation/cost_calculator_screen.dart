import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../request/domain/haul_request.dart';
import '../data/origin_countries.dart';
import '../domain/cost_breakdown.dart';
import '../domain/customs_category.dart';
import '../domain/import_route.dart';
import '../domain/parcel.dart';
import '../domain/pricing_engine.dart';

/// เครื่องคำนวณราคาเต็ม — ของ + ค่าหิ้ว + ค่าส่ง + ภาษีนำเข้า
/// พร้อมเทียบให้เห็นว่าหิ้วติดตัวกับส่งไปรษณีย์ต่างกันเท่าไหร่
class CostCalculatorScreen extends StatefulWidget {
  const CostCalculatorScreen({super.key});

  @override
  State<CostCalculatorScreen> createState() => _CostCalculatorScreenState();
}

class _CostCalculatorScreenState extends State<CostCalculatorScreen> {
  final _priceCtrl = TextEditingController(text: '35200');
  final _weightCtrl = TextEditingController(text: '0.7');
  final _boxCtrl = TextEditingController();
  final _fxCtrl = TextEditingController();

  OriginCountry _origin = OriginCountries.japan;
  Currency _currency = Currencies.jpy;
  HaulCategory _category = HaulCategory.beauty;
  bool _claimRefund = true;
  bool _isDivisible = true;
  double _allowanceUsed = 0;
  ImportRoute _selectedRoute = ImportRoute.handCarry;

  @override
  void initState() {
    super.initState();
    _fxCtrl.text = _rateTextFor(_currency);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _weightCtrl.dispose();
    _boxCtrl.dispose();
    _fxCtrl.dispose();
    super.dispose();
  }

  /// เปลี่ยนประเทศแล้วเด้งสกุลเงินกับเรทตามไปด้วย
  /// ผู้ใช้ยังเลือกสกุลอื่นทับได้ทีหลัง (ร้านออนไลน์ญี่ปุ่นหลายเจ้าคิดเป็น USD)
  void _applyOrigin(OriginCountry c) {
    setState(() {
      _origin = c;
      _currency = Currencies.byCode(c.currencyCode);
      _fxCtrl.text = _rateTextFor(_currency);
      if (!c.taxRefundAvailable) _claimRefund = false;
    });
  }

  void _applyCurrency(Currency c) {
    setState(() {
      _currency = c;
      _fxCtrl.text = _rateTextFor(c);
    });
  }

  static String _rateTextFor(Currency c) {
    if (!FxRates.knows(c.code)) return '';
    final rate = FxRates.thbPer(c.code);
    // สกุลที่เรทต่ำมากอย่างเยนหรือดองต้องการทศนิยมเยอะกว่า
    return rate >= 1 ? rate.toStringAsFixed(2) : rate.toStringAsFixed(4);
  }

  /// เรทที่ใช้จริง — ของที่ผู้ใช้กรอกมาก่อน แล้วค่อยตกไปที่ตาราง
  double get _fxRate {
    final typed = double.tryParse(_fxCtrl.text.trim());
    if (typed != null && typed > 0) return typed;
    return FxRates.thbPer(_currency.code);
  }

  /// ประเทศต้นทางหลังใส่สกุลเงินที่ผู้ใช้เลือกทับ
  ///
  /// [OriginCountry.minSpendForRefund] เป็นยอดในสกุลท้องถิ่น
  /// พอเปลี่ยนสกุลจ่ายต้องแปลงเกณฑ์ตามด้วย ไม่งั้นเทียบกันคนละหน่วย
  OriginCountry get _effectiveOrigin {
    if (_currency.code == _origin.currencyCode) return _origin;

    final nativeRate = FxRates.thbPer(_origin.currencyCode);
    final selectedRate = _fxRate;

    return _origin.copyWith(
      currencyCode: _currency.code,
      currencySymbol: _currency.symbol,
      minSpendForRefund: selectedRate <= 0
          ? _origin.minSpendForRefund
          : _origin.minSpendForRefund * nativeRate / selectedRate,
    );
  }

  QuoteInput get _input {
    final dims = _boxCtrl.text
        .split(RegExp(r'[x×*, ]+'))
        .map((s) => double.tryParse(s.trim()) ?? 0)
        .toList();

    return QuoteInput(
      category: _category,
      origin: _effectiveOrigin,
      goodsForeign: double.tryParse(_priceCtrl.text) ?? 0,
      parcel: Parcel(
        weightKg: double.tryParse(_weightCtrl.text) ?? 0,
        lengthCm: dims.isNotEmpty ? dims[0] : 0,
        widthCm: dims.length > 1 ? dims[1] : 0,
        heightCm: dims.length > 2 ? dims[2] : 0,
      ),
      claimLocalTaxRefund: _claimRefund,
      allowanceUsedTHB: _allowanceUsed,
      isDivisible: _isDivisible,
      fxRateTHB: _fxRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final comparison = PricingEngine.compare(input);
    final selected = _selectedRoute == ImportRoute.handCarry
        ? comparison.handCarry
        : comparison.postal;

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('คำนวณค่าหิ้ว + ภาษี'),
        actions: [
          IconButton(
            tooltip: 'คู่มือภาษีสำหรับนักหิ้ว',
            onPressed: () => context.push(AppRoutes.customsGuide),
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _inputCard(),
          const SizedBox(height: 12),
          if (!input.isDomestic) ...[
            _comparisonCard(comparison),
            const SizedBox(height: 12),
          ],
          _breakdownCard(selected),
          if (selected.tax.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _warningsCard(selected),
          ],
          const SizedBox(height: 12),
          _carrierCard(selected),
          const SizedBox(height: 12),
          _disclaimer(),
        ],
      ),
    );
  }

  // ── ส่วนกรอกข้อมูล ────────────────────────────────────────────

  Widget _inputCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdown<OriginCountry>(
                  label: 'ซื้อจากประเทศ',
                  value: _origin,
                  items: OriginCountries.all,
                  labelOf: (c) => c.nameTh,
                  onChanged: _applyOrigin,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown<HaulCategory>(
                  label: 'หมวดสินค้า',
                  value: _category,
                  items: HaulCategory.values,
                  labelOf: (c) => '${c.emoji} ${c.text}',
                  onChanged: (c) => setState(() => _category = c),
                ),
              ),
            ],
          ),
          if (_origin.isCustom) ...[
            const SizedBox(height: 12),
            _customOriginNotice(),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _dropdown<Currency>(
                  label: 'จ่ายเป็นสกุลเงิน',
                  value: _currency,
                  items: Currencies.all,
                  labelOf: (c) => '${c.code} · ${c.nameTh}',
                  onChanged: _applyCurrency,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _numberField(
                  controller: _fxCtrl,
                  label: 'เรท (บาท/1 ${_currency.code})',
                  hint: FxRates.knows(_currency.code) ? null : 'ใส่เรทเอง',
                  allowDecimal: true,
                ),
              ),
            ],
          ),
          if (_currency.code != _origin.currencyCode) ...[
            const SizedBox(height: 6),
            Text(
              'กำลังคิดเป็น ${_currency.nameTh} '
              'ทั้งที่สกุลประจำ${_origin.nameTh}คือ ${_origin.currencyCode} '
              '— เกณฑ์ขั้นต่ำของการคืนภาษีถูกแปลงให้แล้ว',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.inkMuted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _numberField(
                  controller: _priceCtrl,
                  label: 'ราคาสินค้ารวม (${_currency.code})',
                  prefix: _currency.symbol,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _numberField(
                  controller: _weightCtrl,
                  label: 'น้ำหนัก (กก.)',
                  allowDecimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _numberField(
            controller: _boxCtrl,
            label: 'ขนาดกล่อง ก×ย×ส เป็น ซม. (ไม่บังคับ)',
            hint: 'เช่น 40x30x25 — ของเบาแต่กล่องใหญ่คิดตามปริมาตร',
            allowDecimal: true,
            allowSeparators: true,
          ),
          const SizedBox(height: 8),
          if (_origin.taxRefundAvailable)
            _switchTile(
              title: 'ขอคืนภาษีต้นทาง',
              value: _claimRefund,
              onChanged: (v) => setState(() => _claimRefund = v),
              subtitle: Text(
                _origin.refundNote,
                style: const TextStyle(fontSize: 11.5, height: 1.4),
              ),
            ),
          _switchTile(
            title: 'ของแบ่งเป็นชิ้นย่อยได้',
            value: _isDivisible,
            onChanged: (v) => setState(() => _isDivisible = v),
            subtitle: const Text(
              'ปิดถ้าเป็นของชิ้นเดียวราคาแพง เช่น กระเป๋าใบเดียว '
              '— แบ่งไม่ได้จะถูกคิดภาษีเต็มมูลค่า',
              style: TextStyle(fontSize: 11.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'สิทธิยกเว้นที่ใช้ไปแล้วในทริปนี้: '
            '${Fmt.baht(_allowanceUsed)} / ${Fmt.baht(20000)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _allowanceUsed,
            max: 20000,
            divisions: 40,
            activeColor: AppColors.brand,
            label: Fmt.baht(_allowanceUsed),
            onChanged: (v) => setState(() => _allowanceUsed = v),
          ),
          const Text(
            'นักหิ้วมีสิทธิของใช้ส่วนตัว 20,000 บาทต่อคนต่อเที่ยว '
            'ถ้ารับหลายออเดอร์ สิทธิจะถูกใช้ร่วมกัน',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.inkMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// ป้ายบอกให้ชัดว่าประเทศนี้ยังไม่มีข้อมูลกฎหมายในระบบ
  Widget _customOriginNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ประเทศนอกลิสต์ — อากรกับ VAT ยังคำนวณให้ถูกต้อง '
              'เพราะผูกกับพิกัดศุลกากรของสินค้า ไม่ใช่ประเทศ\n'
              'แต่ต้องเลือกสกุลเงินและใส่เรทเอง และ${_origin.refundNote}',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── เทียบสองช่องทาง ──────────────────────────────────────────

  Widget _comparisonCard(RouteComparison cmp) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เทียบช่องทางนำเข้า',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _routeTile(
                  cmp.handCarry,
                  isCheapest: cmp.cheaper.route == ImportRoute.handCarry,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _routeTile(
                  cmp.postal,
                  isCheapest: cmp.cheaper.route == ImportRoute.postal,
                ),
              ),
            ],
          ),
          if (cmp.isSignificant) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'เลือก "${cmp.cheaper.route.text}" '
                      'ประหยัดกว่า ${Fmt.baht(cmp.savings)} '
                      '(${(cmp.savingsRatio * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _routeTile(CostBreakdown b, {required bool isCheapest}) {
    final selected = _selectedRoute == b.route;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoute = b.route),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  b.route == ImportRoute.handCarry
                      ? Icons.flight_takeoff
                      : Icons.local_shipping_outlined,
                  size: 16,
                  color: selected ? AppColors.brand : AppColors.inkMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  b.route.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.brand : AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Fmt.baht(b.total),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              b.tax.isExempt
                  ? 'ไม่มีภาษีนำเข้า'
                  : 'ภาษี ${Fmt.baht(b.tax.total)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: b.tax.isExempt ? AppColors.success : AppColors.danger,
              ),
            ),
            if (isCheapest) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ถูกกว่า',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── รายละเอียดราคา ───────────────────────────────────────────

  Widget _breakdownCard(CostBreakdown b) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'รายละเอียดราคา',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                b.route.text,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...b.lines.map(_lineRow),
          const Divider(height: 24),
          Row(
            children: [
              const Text(
                'ยอดที่ผู้ฝากจ่าย',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                Fmt.baht(b.total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          if (!b.tax.isExempt) ...[
            const SizedBox(height: 6),
            Text(
              'ภาษีคิดเป็น '
              '${(b.effectiveTaxRate * 100).toStringAsFixed(1)}% ของราคาสินค้า',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b.tax.reason,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(CostLine line) {
    final color = line.isDeduction
        ? AppColors.success
        : (line.isHighlight ? AppColors.brand : AppColors.ink);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.label,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                '${line.amount < 0 ? '−' : ''}${Fmt.baht(line.amount.abs())}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (line.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 60),
              child: Text(
                line.hint,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.inkMuted,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── คำเตือน ──────────────────────────────────────────────────

  Widget _warningsCard(CostBreakdown b) {
    final profile = CustomsProfiles.of(_category);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 6),
              const Text(
                'ข้อควรรู้ของหมวดนี้',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'HS ${profile.hsChapter}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...b.tax.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 5,
                        color: AppColors.inkMuted),
                  ),
                  Expanded(
                    child: Text(
                      w,
                      style: const TextStyle(fontSize: 12.5, height: 1.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ฝั่งนักหิ้ว ───────────────────────────────────────────────

  Widget _carrierCard(CostBreakdown b) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ฝั่งนักหิ้วได้อะไร',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _carrierRow(
            'เงินสำรองที่ได้รับก่อนไปซื้อ',
            b.carrierAdvance,
            'ครอบคลุมค่าของ ค่าส่ง และภาษีทั้งหมด — ไม่ต้องควักเงินตัวเอง',
            AppColors.abroad,
          ),
          const SizedBox(height: 10),
          _carrierRow(
            'ค่าจ้างที่ได้จริง',
            b.carrierEarning,
            'จ่ายหลังผู้ฝากกดรับของ '
            '(ค่าหิ้ว ${Fmt.baht(b.serviceFee)} '
            'หักค่าธรรมเนียม ${Fmt.baht(b.platformFee)})',
            AppColors.success,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.brand),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'นักหิ้วไม่ต้องสำรองจ่ายเองในทุกกรณี '
                    'ร้านออนไลน์แพลตฟอร์มจ่ายให้ตรง '
                    'ร้านที่รับบัตรใช้บัตรเสมือน '
                    'ร้านเงินสดโอนล่วงหน้าให้ก่อน',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.brandDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carrierRow(String label, double amount, String hint, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              Fmt.baht(amount),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.inkMuted,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _disclaimer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: const Text(
        'ตัวเลขทั้งหมดเป็นการประมาณการเพื่อช่วยตัดสินใจเท่านั้น '
        'อัตราอากรจริงผูกกับพิกัดศุลกากรของสินค้าแต่ละรายการ '
        'และเจ้าหน้าที่ศุลกากรมีอำนาจตีราคาใหม่ได้ที่หน้าด่าน '
        'กรุณาสำแดงราคาตามจริงเสมอ',
        style: TextStyle(
          fontSize: 11.5,
          height: 1.6,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }

  // ── ตัวช่วย UI ────────────────────────────────────────────────

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          style: const TextStyle(fontSize: 13, color: AppColors.ink),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  /// SwitchListTile วาดพื้นหลังกับ ink splash ลงบน Material ที่ใกล้ที่สุด
  /// การ์ดพวกนี้เป็น ColoredBox ทึบ ถ้าไม่มี Material คั่นเอฟเฟกต์จะถูกบัง
  /// (Flutter assert เตือนตรงๆ ในโหมด debug)
  Widget _switchTile({
    required String title,
    required Widget subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.brand,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle,
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    bool allowDecimal = false,
    bool allowSeparators = false,
  }) {
    final pattern = allowSeparators
        ? RegExp(r'[0-9.x×*, ]')
        : (allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(pattern)],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11.5),
            prefixText: prefix,
          ),
        ),
      ],
    );
  }
}
