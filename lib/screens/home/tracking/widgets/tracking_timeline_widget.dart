import 'package:flutter/material.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:intl/intl.dart';

/// Timeline vertical untuk riwayat pengiriman
class TrackingTimelineWidget extends StatelessWidget {
  final List<TrackingTimelineItem> timeline;
  final TrackingStatus currentStatus;

  const TrackingTimelineWidget({
    super.key,
    required this.timeline,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (timeline.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Belum ada riwayat pengiriman.',
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(timeline.length, (index) {
        final item = timeline[index];
        final isLast = index == timeline.length - 1;
        final isFirst = index == 0;

        // Determine if this is the current active step
        final isCurrent = isFirst || item.isCurrent;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: dot + line
              Column(
                children: [
                  // Dot
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getDotColor(item, isCurrent),
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: _getDotColor(item, isCurrent)
                                    .withOpacity(0.3),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _getIcon(item),
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                  // Line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Right: content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.statusLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          color: isCurrent
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(item.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                      ),
                      if (item.description != null &&
                          item.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _getDotColor(TrackingTimelineItem item, bool isCurrent) {
    final status = item.status.toLowerCase();
    if (status == 'cancelled' || status == 'failed') {
      return const Color(0xFFEF4444);
    }
    if (status == 'delivered') {
      return const Color(0xFF4CAF50);
    }
    if (isCurrent) {
      return const Color(0xFFEC5B13);
    }
    return const Color(0xFF94A3B8);
  }

  IconData _getIcon(TrackingTimelineItem item) {
    final status = item.status.toLowerCase();
    switch (status) {
      case 'pending':
        return Icons.receipt_long;
      case 'confirmed':
        return Icons.verified_outlined;
      case 'assigned':
        return Icons.person_add_outlined;
      case 'pickup':
      case 'picking_up':
        return Icons.inventory_2;
      case 'picked_up':
        return Icons.inventory_2;
      case 'in_transit':
      case 'delivering':
        return Icons.local_shipping;
      case 'arriving':
        return Icons.near_me;
      case 'delivered':
        return Icons.check;
      case 'cancelled':
        return Icons.close;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    try {
      final formatter = DateFormat('dd MMM yyyy • HH:mm', 'id_ID');
      return formatter.format(date);
    } catch (_) {
      final formatter = DateFormat('dd MMM yyyy • HH:mm');
      return formatter.format(date);
    }
  }
}
