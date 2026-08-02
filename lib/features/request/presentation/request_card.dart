import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_badges.dart';
import '../domain/haul_request.dart';

/// การ์ดคำขอฝากหิ้วในฟีด — guest ก็เห็นครบทุกอย่าง
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, required this.onTap});

  final HaulRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryThumb(category: request.category),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            OriginBadge(
                              type: request.originType,
                              place: request.originName,
                            ),
                            if (request.isUrgent)
                              UrgentBadge(text: Fmt.remaining(request.deadline)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'จำนวน ${request.quantity} ชิ้น · '
                          'งบไม่เกิน ${Fmt.baht(request.budgetMax)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 16, color: AppColors.brand),
                  const SizedBox(width: 5),
                  Text(
                    'ค่าหิ้ว ${Fmt.baht(request.serviceFeeOffer)}',
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (request.bidCount > 0)
                    Text(
                      '${request.bidCount} คนเสนอราคาแล้ว',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    )
                  else
                    const Text(
                      'ยังไม่มีคนเสนอ',
                      style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
