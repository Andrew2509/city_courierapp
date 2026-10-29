import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
import 'package:city_courierapp/services/shipping/active_order_service.dart';

/// Floating active delivery order card on the user's home screen.
///
/// Features matching user's visual screenshots:
/// - State 1 (Compact Pill Bar): Soft orange truck icon, courier name,
///   arrival time badge, destination subtitle, and "Lihat >" action.
/// - State 2 (Expanded Full Card): "Sedang Dikirim" status badge, tracking code
///   with one-tap copy, courier driver info with call & chat buttons,
///   status banner, 3-stage delivery stepper progress, and orange
///   "Lihat Live Tracking >" CTA button.
class FloatingActiveOrderWidget extends StatefulWidget {
  const FloatingActiveOrderWidget({super.key});

  @override
  State<FloatingActiveOrderWidget> createState() =>
      _FloatingActiveOrderWidgetState();
}

class _FloatingActiveOrderWidgetState extends State<FloatingActiveOrderWidget> {
  // Toggle between compact pill (Image 2) and expanded card (Image 1)
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ActiveOrderService.activeOrderNotifier,
      builder: (context, order, _) {
        if (order == null || order['is_active'] != true) {
          return const SizedBox.shrink();
        }

        final orderId = order['order_id'] ?? 'CC2610284680';
        final status = order['status'] ?? 'Sedang Dikirim';
        final estTime = order['estimated_time'] ?? '~25 mnt';
        final courierName = order['courier_name'] ?? 'Pak Budi Santoso';
        final courierVehicle =
            order['courier_vehicle'] ?? 'Honda Vario • B 4920 SDC';
        final courierPhone = order['courier_phone'] ?? '081234567890';
        final destination = order['destination'] ?? 'Kebayoran Baru';
        final statusMsg = order['status_message'] ??
            'Kurir sedang menuju alamat penerima di $destination';
        final step = order['step'] ?? 1; // 0: Jemput, 1: Jalan, 2: Terkirim
        final shipmentData = order['shipment_data'] as Map<String, dynamic>?;

        return Positioned(
          bottom: 104, // Positioned gracefully above the bottom navigation bar
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeInCubic,
              crossFadeState: _isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildExpandedCard(
                context: context,
                orderId: orderId,
                status: status,
                estTime: estTime,
                courierName: courierName,
                courierVehicle: courierVehicle,
                courierPhone: courierPhone,
                destination: destination,
                statusMsg: statusMsg,
                step: step,
                shipmentData: shipmentData,
              ),
              secondChild: _buildCompactBar(
                context: context,
                orderId: orderId,
                courierName: courierName,
                estTime: estTime,
                destination: destination,
                shipmentData: shipmentData,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── State 1: Compact Pill Floating Bar (Image 2) ──────────────────

  Widget _buildCompactBar({
    required BuildContext context,
    required String orderId,
    required String courierName,
    required String estTime,
    required String destination,
    Map<String, dynamic>? shipmentData,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          setState(() => _isExpanded = true);
        },
        child: Row(
          children: [
            // Left Soft Orange Square with Truck Icon & Active Green Dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Color(0xFFEA580C),
                    size: 22,
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Middle Courier & Destination Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          courierName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          estTime,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Menuju penerima • $destination',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right "Lihat >" Action
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrackingDetailScreen(
                      trackingNumber: orderId,
                      shipmentData: shipmentData,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: const Row(
                  children: [
                    Text(
                      'Lihat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFEA580C),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── State 2: Full Expanded Floating Card (Image 1) ────────────────

  Widget _buildExpandedCard({
    required BuildContext context,
    required String orderId,
    required String status,
    required String estTime,
    required String courierName,
    required String courierVehicle,
    required String courierPhone,
    required String destination,
    required String statusMsg,
    required int step,
    Map<String, dynamic>? shipmentData,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row: [Sedang Dikirim + Tiba ~25 mnt] & [CC2610284680 + Copy + Collapse]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Status Badge & Estimated Arrival
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tiba $estTime',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),

              // Right: Resi Code + Copy + Minimize icon
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: orderId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nomor resi $orderId disalin!'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          orderId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = false),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Driver Info Row: [Avatar] + [Name & Vehicle] + [Call & Chat]
          Row(
            children: [
              // Avatar with Orange Motor Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF94A3B8),
                      size: 26,
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Name & Vehicle details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courierName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      courierVehicle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Call & Chat Circular Buttons
              Row(
                children: [
                  _buildCircleAction(
                    icon: Icons.phone_outlined,
                    onTap: () async {
                      final url = Uri.parse('tel:$courierPhone');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Nomor kurir: $courierPhone'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildCircleAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () async {
                      final waUrl = Uri.parse(
                          'https://wa.me/62${courierPhone.replaceFirst(RegExp(r'^0'), '')}?text=Halo%20$courierName%2C%20saya%20pemesan%20City%20Courier%20($orderId)');
                      if (await canLaunchUrl(waUrl)) {
                        await launchUrl(waUrl,
                            mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Chat kurir di: $courierPhone'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Status Message Banner (Light Blue/Grey with Orange Clock)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Color(0xFFEA580C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMsg,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Stepper Progress: Jemput Paket ── Dalam Perjalanan ── Terkirim
          _buildStepper(step),
          const SizedBox(height: 14),

          // 5. CTA Button: "Lihat Live Tracking >"
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C), // Vibrant Orange
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrackingDetailScreen(
                      trackingNumber: orderId,
                      shipmentData: shipmentData,
                    ),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lihat Live Tracking',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stepper Component ──────────────────────────────────────────────

  Widget _buildStepper(int step) {
    // step: 0 = Jemput Paket, 1 = Dalam Perjalanan, 2 = Terkirim
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 14),
            // Step 1: Jemput Paket
            _buildStepDot(isDone: step >= 1, isActive: step == 0),

            // Line 1
            Expanded(
              child: Container(
                height: 3,
                color: step >= 1
                    ? const Color(0xFFEA580C)
                    : const Color(0xFFE2E8F0),
              ),
            ),

            // Step 2: Dalam Perjalanan
            _buildStepDot(isDone: step >= 2, isActive: step == 1),

            // Line 2
            Expanded(
              child: Container(
                height: 3,
                color: step >= 2
                    ? const Color(0xFFEA580C)
                    : const Color(0xFFE2E8F0),
              ),
            ),

            // Step 3: Terkirim
            _buildStepDot(isDone: step >= 2, isActive: step == 2),
            const SizedBox(width: 14),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Jemput Paket',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: step == 0 ? FontWeight.bold : FontWeight.w500,
                color:
                    step == 0 ? const Color(0xFFEA580C) : const Color(0xFF475569),
              ),
            ),
            Text(
              'Dalam Perjalanan',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: step == 1 ? FontWeight.bold : FontWeight.w500,
                color:
                    step == 1 ? const Color(0xFFEA580C) : const Color(0xFF64748B),
              ),
            ),
            Text(
              'Terkirim',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: step >= 2 ? FontWeight.bold : FontWeight.w500,
                color:
                    step >= 2 ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepDot({required bool isDone, required bool isActive}) {
    if (isActive) {
      // Concentric orange rings (matching screenshot)
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDD5),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFEA580C),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else if (isDone) {
      // Solid orange completed circle
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: Color(0xFFEA580C),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.circle,
            color: Colors.white,
            size: 4,
          ),
        ),
      );
    } else {
      // Inactive grey circle
      return Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFFCBD5E1),
          shape: BoxShape.circle,
        ),
      );
    }
  }

  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(
          icon,
          size: 17,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}
