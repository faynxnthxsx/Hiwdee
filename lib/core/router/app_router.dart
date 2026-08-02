import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/address/domain/address.dart';
import '../../features/address/presentation/address_form_screen.dart';
import '../../features/address/presentation/address_list_screen.dart';
import '../../features/carrier/presentation/carrier_onboard_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/pricing/presentation/cost_calculator_screen.dart';
import '../../features/pricing/presentation/customs_guide_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/request/presentation/create_request_screen.dart';
import '../../features/request/presentation/feed_screen.dart';
import '../../features/request/presentation/request_detail_screen.dart';
import '../../features/trip/presentation/trip_feed_screen.dart';
import 'app_routes.dart';

/// ไม่มี redirect กันหน้าเลย — ทุกหน้าสาธารณะเข้าได้หมด
/// การกั้นสิทธิ์ทำที่ระดับ "ปุ่ม" ผ่าน AuthGate แทน (ดู core/router/auth_gate.dart)
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.feed,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.feed,
                builder: (_, _) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.trips,
                builder: (_, _) => const TripFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (_, _) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.me,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ต้องมาก่อน '/request/:id' ไม่งั้น "new" จะถูกอ่านเป็น id
      GoRoute(
        path: AppRoutes.requestNew,
        builder: (_, _) => const CreateRequestScreen(),
      ),
      GoRoute(
        path: AppRoutes.requestDetailPattern,
        builder: (_, state) =>
            RequestDetailScreen(requestId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: AppRoutes.orderDetailPattern,
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: AppRoutes.addressForm,
        builder: (_, state) =>
            AddressFormScreen(initial: state.extra as Address?),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        builder: (_, _) => const AddressListScreen(selectMode: true),
      ),

      GoRoute(
        path: AppRoutes.carrierOnboard,
        builder: (_, _) => const CarrierOnboardScreen(),
      ),

      // ต้องมาก่อน '/calculator' ไม่งั้น go_router จับคู่ตัวสั้นก่อน
      GoRoute(
        path: AppRoutes.customsGuide,
        builder: (_, _) => const CustomsGuideScreen(),
      ),
      GoRoute(
        path: AppRoutes.calculator,
        builder: (_, _) => const CostCalculatorScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('ไม่พบหน้านี้\n${state.uri}')),
    ),
  );
});
