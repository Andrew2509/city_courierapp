import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_complete_screen.dart';

class DriverAtDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DriverAtDeliveryScreen({super.key, required this.order});

  @override
  State<DriverAtDeliveryScreen> createState() => _DriverAtDeliveryScreenState();
}

class _DriverAtDeliveryScreenState extends State<DriverAtDeliveryScreen> {
  late final MapController _mapController;
  bool _isDelivering = false;

  // Mock current location (driver at delivery location)
  final LatLng _currentLocation = const LatLng(-6.2146, 106.8451);
  late final double deliveryLat;
  late final double deliveryLng;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    deliveryLat = double.tryParse(widget.order['dropoff_latitude']?.toString() ?? '') ?? -6.2146;
    deliveryLng = double.tryParse(widget.order['dropoff_longitude']?.toString() ?? '') ?? 106.8451;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMapOnDelivery();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centerMapOnDelivery() {
    _mapController.move(LatLng(deliveryLat, deliveryLng), 15.0);
  }

  Future<void> _callPhone(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _markAsDelivered() {
    setState(() {
      _isDelivering = true;
    });

    // Navigate to complete screen after short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DriverDeliveryCompleteScreen(order: widget.order),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(deliveryLat, deliveryLng),
                initialZoom: 15.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.citycourier.app',
                  maxZoom: 18,
                ),
                MarkerLayer(
                  markers: [
                    // Delivery location marker
                    Marker(
                      point: LatLng(deliveryLat, deliveryLng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange, // Orange
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryOrange.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.textWhite,
                          size: 24,
                        ),
                      ),
                    ),
                    // Driver location marker (at delivery)
                    Marker(
                      point: _currentLocation,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.textWhite,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: AppColors.primaryBlue,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Header
            Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),

            // Bottom Card
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomCard()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Tiba di Lokasi Pengantaran',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            _getCurrentTime(),
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Delivery Location Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primaryOrange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Titik Pengantaran:',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.order['receiver_name'] ??
                            'Lokasi Penerima',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.order['dropoff_address'] ??
                            'Alamat Penerima',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.primaryOrange),
                  onPressed: () => _callPhone(
                    widget.order['receiver_phone'] ?? '+6281398765432',
                  ),
                ),
              ],
            ),
          ),

          // Action Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isDelivering ? null : _markAsDelivered,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successColor, // Success/Green
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isDelivering
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textWhite,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sedang Memproses...',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Konfirmasi Pesanan Diterima',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
