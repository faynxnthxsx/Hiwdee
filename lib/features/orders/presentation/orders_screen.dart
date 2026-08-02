import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_badges.dart';
import '../../../shared/widgets/auth_required_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import '../domain/order_status.dart';

/// แท็บออเดอร์ — guest เข้ามาได้ แต่ต้องล็อกอินถึงจะเห็นรายการ
///
/// แยกสองฝั่งเพราะผู้ใช้คนเดียวเป็นได้ทั้งผู้ฝากและนักหิ้ว
/// (บัญชีเดียวสองบทบาท — เหมือนที่ [AppUser.isCarrier] ตั้งใจไว้)
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('ออเดอร์ของฉัน')),
        body: const AuthRequiredView(
          icon: Icons.receipt_long_outlined,
          title: 'ดูออเดอร์ของคุณ',
          message: 'เข้าสู่ระบบเพื่อติดตามสถานะของที่ฝากหิ้ว '
              'และงานที่รับหิ้วไว้',
          reason: 'เข้าสู่ระบบเพื่อดูออเดอร์',
        ),
      );
    }

    final mine = ref.watch(ordersByRoleProvider(OrderActor.requester));
    final hauling = ref.watch(ordersByRoleProvider(OrderActor.carrier));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surfaceAlt,
        appBar: AppBar(
          title: const Text('ออเดอร์ของฉัน'),
          bottom: TabBar(
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.inkMuted,
            indicatorColor: AppColors.brand,
            tabs: [
              Tab(text: 'ฉันฝาก (${mine.length})'),
              Tab(text: 'ฉันหิ้ว (${hauling.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrderList(
              orders: mine,
              emptyMessage: 'ยังไม่มีออเดอร์ที่คุณฝาก\n'
                  'ลองโพสต์คำขอแล้วรอนักหิ้วเสนอราคาดู',
            ),
            _OrderList(
              orders: hauling,
              emptyMessage: 'ยังไม่มีงานที่คุณรับหิ้ว\n'
                  'ไปที่ฟีดแล้วเสนอราคาคำขอที่สนใจได้เลย',
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.emptyMessage});

  final List<Order> orders;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(icon: Icons.inbox_outlined, message: emptyMessage);
    }

    // ที่ยังไม่จบขึ้นก่อน แล้วค่อยเรียงใหม่สุดลงไป
    final sorted = [...orders]..sort((a, b) {
        if (a.status.isTerminal != b.status.isTerminal) {
          return a.status.isTerminal ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: sorted.length,
      itemBuilder: (context, i) => _OrderCard(order: sorted[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final step = OrderFlow.happyPath.indexOf(order.status);
    final tint = switch (order.status) {
      OrderStatus.completed => AppColors.success,
      OrderStatus.cancelled => AppColors.inkMuted,
      OrderStatus.disputed => AppColors.danger,
      OrderStatus.awaitingPayment => AppColors.warning,
      _ => AppColors.brand,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          onTap: () => context.push(AppRoutes.orderDetail(order.id)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryThumb(category: order.category, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            order.myRole == OrderActor.requester
                                ? 'นักหิ้ว: ${order.carrierName}'
                                : 'ผู้ฝาก: ${order.requesterName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.status.text,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: tint,
                        ),
                      ),
                    ),
                  ],
                ),
                if (step >= 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < OrderFlow.happyPath.length; i++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: EdgeInsets.only(
                              right:
                                  i == OrderFlow.happyPath.length - 1 ? 0 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: i <= step ? tint : AppColors.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      order.myRole == OrderActor.requester
                          ? 'จ่ายทั้งหมด ${Fmt.baht(order.requesterTotalTHB)}'
                          : 'ได้ค่าจ้าง ${Fmt.baht(order.carrierEarningTHB)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (order.availableActions.isNotEmpty)
                      Text(
                        'มี ${order.availableActions.length} อย่างให้ทำ',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      )
                    else
                      Text(
                        Fmt.ago(order.createdAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
