import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/screens/home/tracking/widgets/tracking_progress_bar.dart';
import 'package:city_courierapp/screens/home/tracking/widgets/tracking_timeline_widget.dart';
import 'package:city_courierapp/screens/home/tracking/widgets/courier_info_card.dart';
import 'package:intl/intl.dart';

/// Bottom sheet draggable untuk info tracking
class TrackingBottomSheet extends StatelessWidget {
  final TrackingModel tracking;
  final VoidCallback? onRefresh;

  const TrackingBottomSheet({
    super.key,
    required this.tracking,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge + refresh
                  _buildStatusHeader(isDark),
                  const SizedBox(height: 16),

                  // Tracking number
                  _buildTrackingNumber(context, isDark),
                  const SizedBox(height: 16),

                  // Progress bar
                  _buildProgressBar(),
                  const SizedBox(height: 20),

                  // Estimated delivery
                  if (tracking.estimatedDelivery != null) ...[
                    _buildEstimasi(isDark),
                    const SizedBox(height: 16),
                  ],

                  // Location info (from / to)
                  if (tracking.origin != null || tracking.destination != null)
                    _buildLocationInfo(isDark),
                  const SizedBox(height: 16),

                  // Courier info
                  _buildCourierSection(isDark),
                  const SizedBox(height: 20),

                  // Timeline header
                  _buildTimelineHeader(isDark),
                  const SizedBox(height: 12),

                  // Timeline
                  TrackingTimelineWidget(
                    timeline: tracking.timeline,
                    currentStatus: tracking.status,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(bool isDark) {
    final statusColor = _getStatusColor(tracking.status);

    return Row(
      children: [
        // Status dot
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Status text
        Expanded(
          child: Text(
            tracking.statusLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),

        // Refresh button
        if (onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
              padding: const EdgeInsets.all(8),
            ),
          ),
      ],
    );
  }

  Widget _buildTrackingNumber(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: tracking.trackingNumber));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor resi berhasil disalin.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nomor Resi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tracking.trackingNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEC5B13).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.copy,
                color: Color(0xFFEC5B13),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return TrackingProgressBar(status: tracking.status);
  }

  Widget _buildEstimasi(bool isDark) {
    final now = DateTime.now();
    final est = tracking.estimatedDelivery!;
    final isToday = est.year == now.year &&
        est.month == now.month &&
        est.day == now.day;
    final isTomorrow = est.year == now.year &&
        est.month == now.month &&
        est.day == now.day + 1;

    String estimasiText;
    if (isToday) {
      estimasiText = 'Hari ini';
    } else if (isTomorrow) {
      estimasiText = 'Besok';
    } else {
      estimasiText = DateFormat('dd MMMM yyyy', 'id_ID').format(est);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimasi tiba',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
              Text(
                estimasiText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Origin
          if (tracking.origin != null)
            _buildLocationRow(
              icon: Icons.circle,
              iconColor: const Color(0xFF4CAF50),
              label: 'Dari',
              address: tracking.origin!.address,
              isDark: isDark,
            ),

          // Divider with dots
          if (tracking.origin != null && tracking.destination != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 9),
                  ...List.generate(
                    6,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Destination
          if (tracking.destination != null)
            _buildLocationRow(
              icon: Icons.circle,
              iconColor: const Color(0xFFE53935),
              label: 'Ke',
              address: tracking.destination!.address,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 10),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address.isNotEmpty ? address : 'Alamat tidak tersedia',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourierSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kurir Anda',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        CourierInfoCard(courier: tracking.courier),
      ],
    );
  }

  Widget _buildTimelineHeader(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.history,
          size: 18,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          'Riwayat Pengiriman',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.delivered:
        return const Color(0xFF4CAF50);
      case TrackingStatus.cancelled:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFEC5B13);
    }
  }
}
