import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';

class DriverStartPickupScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const DriverStartPickupScreen({super.key, required this.request});

  @override
  State<DriverStartPickupScreen> createState() =>
      _DriverStartPickupScreenState();
}

class _DriverStartPickupScreenState extends State<DriverStartPickupScreen> {
  final MapController _mapController = MapController();
  final LatLng _driverLocation = const LatLng(-6.2088, 106.8456);
  late LatLng _pickupLocation;

  @override
  void initState() {
    super.initState();
    double pickupLat =
        double.tryParse(widget.request['pickup_latitude']?.toString() ?? '') ?? -6.2000;
    double pickupLng =
        double.tryParse(widget.request['pickup_longitude']?.toString() ?? '') ?? 106.8500;
    _pickupLocation = LatLng(pickupLat, pickupLng);
  }

  void _startNavigation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverNavigationScreen(
          order: widget.request,
          phase: NavigationPhase.pickup,
        ),
      ),
    );
  }

  Future<void> _signalArrival() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      ),
    );

    try {
      final result = await CourierOrderService.updateOrderStatus(
        orderId: widget.request['id'].toString(),
        status: 'picking_up',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sinyal kedatangan telah dikirim ke pengirim'),
            backgroundColor: AppColors.successColor,
          ),
        );

        // After arrival, navigate to pickup process
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DriverDeliveryFlowScreen(order: result['data'] ?? widget.request),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal mengirim sinyal')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _callSender() async {
    final phone = widget.request['sender_phone'] ?? '081343323155';
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          // Map Background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickupLocation,
              initialZoom: 15,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.citycourier.app',
              ),
              MarkerLayer(
                markers: [
                  // Pickup Marker
                  Marker(
                    point: _pickupLocation,
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textWhite,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            'Titik Jemput',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on,
                          color: AppColors.errorColor,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                  // Driver Marker
                  Marker(
                    point: _driverLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.local_shipping,
                      color: AppColors.primaryBlue,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          color: AppColors.primaryTeal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Menuju Titik Penjemputan',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Sheet Task
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardCardBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nomor Resi: ${widget.request['tracking_number'] ?? widget.request['order_number'] ?? widget.request['id'] ?? 'CC-09871'}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.request['sender_name'] ?? 'PT Sentral Logistik',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Estimasi: 12 Menit',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warningColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Location Details
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.request['pickup_address'] ??
                              'Alamat Lengkap Titik Jemput...',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _callSender,
                            icon: const Icon(Icons.phone, size: 20),
                            label: Text(
                              'Hubungi',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary.withValues(
                                alpha: 0.8,
                              ),
                              side: BorderSide(
                                color: AppColors.dashboardCardBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _startNavigation,
                            icon: const Icon(Icons.navigation, size: 20),
                            label: Text(
                              'Navigasi Sekarang',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textWhite,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: AppColors.textWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _signalArrival,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: AppColors.textWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        'Saya Sudah Tiba di Lokasi',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
