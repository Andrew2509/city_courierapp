import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/earnings/driver_earnings_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';

class DriverCompleteScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const DriverCompleteScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      body: SafeArea(
        bottom: false,
        child: Container(
          color: const Color(0xFFFAFAFA),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildMapMockup(),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildOrderInfoCard(),
                                const SizedBox(height: 16),
                                _buildStatusCard(),
                                const SizedBox(height: 16),
                                _buildRincianCard(),
                                const SizedBox(height: 160),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Bottom Action
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFAFAFA).withOpacity(0.0),
                        const Color(0xFFFAFAFA),
                        const Color(0xFFFAFAFA),
                      ],
                      stops: const [0.0, 0.2, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Kembali ke Beranda',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const DriverShipmentScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Lihat Riwayat Pengiriman',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 1, // Shipment tab is selected
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverShipmentScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverEarningsScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverProfileScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          ),
          Text(
            'Pengiriman Selesai',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const Icon(Icons.headset_mic_outlined, color: AppColors.primaryOrange),
        ],
      ),
    );
  }

  Widget _buildMapMockup() {
    // Read coordinates from backend
    double dLat = double.tryParse(order['latitude_delivery']?.toString() ?? '') ??
                 double.tryParse(order['delivery_latitude']?.toString() ?? '') ??
                 double.tryParse(order['dropoff_latitude']?.toString() ?? '') ?? 0;
    double dLng = double.tryParse(order['longitude_delivery']?.toString() ?? '') ??
                 double.tryParse(order['delivery_longitude']?.toString() ?? '') ??
                 double.tryParse(order['dropoff_longitude']?.toString() ?? '') ?? 0;

    // Fallback to pickup if delivery not available
    if (dLat == 0 || dLng == 0) {
      dLat = double.tryParse(order['pickup_latitude']?.toString() ?? '') ?? -6.200000;
      dLng = double.tryParse(order['pickup_longitude']?.toString() ?? '') ?? 106.816666;
    }
    final mapCenter = LatLng(dLat, dLng);
    
    return Container(
      width: double.infinity,
      height: 220,
      color: const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.citycourier.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: mapCenter,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primaryOrange,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Nav Map Button
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.navigation, color: Color(0xFF1A1A1A), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    final String trackingNumber = order['tracking_number'] ?? order['order_number'] ?? order['id']?.toString() ?? '-';
    
    // Read from backend flat fields with nested fallback
    final pickupLoc = order['pickup_location'] ?? {};
    final dropoffLoc = order['dropoff_location'] ?? {};
    
    final pickupName = pickupLoc['name'] ?? order['pickup_name'] ?? order['sender_name'] ?? 'Lokasi Penjemputan';
    final pickupAddress = order['pickup_address'] ?? pickupLoc['address'] ?? '-';
    
    final dropoffName = dropoffLoc['name'] ?? order['dropoff_name'] ?? order['receiver_name'] ?? 'Lokasi Tujuan';
    final dropoffAddress = order['dropoff_address'] ?? order['delivery_address'] ?? dropoffLoc['address'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order ID: #$trackingNumber',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Pickup
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward, color: Colors.white, size: 12),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: const Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickupName,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickupAddress,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Dropoff
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dropoffName,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dropoffAddress,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimasi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('11:30 - 12:00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A))),
                  const SizedBox(height: 16),
                  Text('Harga', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('Rp ${order['price'] ?? order['total_amount'] ?? '25.000'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF22C55E))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'COD',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Pengiriman',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepItem(
                label: 'Menjemput\nPaket',
                isDone: true,
                iconData: Icons.check,
              ),
              Expanded(child: _buildStepLine(true)),
              _buildStepItem(
                label: 'Paket\nDiperjalanan',
                isDone: true,
                iconData: Icons.check,
              ),
              Expanded(child: _buildStepLine(true)),
              _buildStepItem(
                label: 'Selesai\nPengiriman',
                isDone: true,
                iconData: Icons.check,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String label, required bool isDone, required IconData iconData}) {
    Color iconColor = Colors.white;
    Color borderColor = const Color(0xFF22C55E); // Green
    Color bgColor = const Color(0xFF22C55E); // Green

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Selesai',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(top: 20, left: 4, right: 4),
      color: const Color(0xFF22C55E),
    );
  }

  Widget _buildRincianCard() {
    final dropoffLoc = order['dropoff_location'] ?? {};
    final dropoffName = dropoffLoc['name'] ?? order['dropoff_name'] ?? order['receiver_name'] ?? 'Penerima';
    final now = DateTime.now();
    final dateString = DateFormat('dd MMM yyyy, HH:mm').format(now);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian Pengiriman',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today_outlined, 'Waktu Selesai', dateString),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.person_outline, 'Diterima oleh', dropoffName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.payment_outlined, 'Metode Pembayaran', 'COD'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.check_circle_outline, 'Status Pembayaran', 'Dibayar Tunai', isGreenValue: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isGreenValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isGreenValue ? const Color(0xFF22C55E) : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}
