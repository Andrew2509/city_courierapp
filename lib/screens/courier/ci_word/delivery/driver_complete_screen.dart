import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';
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
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                            child: Column(
                              children: [
                                _buildStatusCard(),
                                const SizedBox(height: 12),
                                _buildOrderInfoCard(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Bottom Action (1 baris sejajar agar tidak menumpuk tinggi)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DriverShipmentScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.primaryOrange,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Lihat Riwayat',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DriverHomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Ke Beranda',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
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
          const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 22),
        ],
      ),
    );
  }

  Widget _buildMapMockup() {
    // Read coordinates from backend
    double dLat = double.tryParse(order['latitude_delivery']?.toString() ?? '') ??
        double.tryParse(order['delivery_latitude']?.toString() ?? '') ??
        double.tryParse(order['dropoff_latitude']?.toString() ?? '') ??
        0;
    double dLng = double.tryParse(order['longitude_delivery']?.toString() ?? '') ??
        double.tryParse(order['delivery_longitude']?.toString() ?? '') ??
        double.tryParse(order['dropoff_longitude']?.toString() ?? '') ??
        0;

    // Fallback to pickup if delivery not available
    if (dLat == 0 || dLng == 0) {
      dLat = double.tryParse(order['pickup_latitude']?.toString() ?? '') ?? -6.200000;
      dLng = double.tryParse(order['pickup_longitude']?.toString() ?? '') ?? 106.816666;
    }
    final mapCenter = LatLng(dLat, dLng);

    return Container(
      width: double.infinity,
      height: 170,
      color: const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 14.5,
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
                      color: Color(0xFF22C55E),
                      size: 38,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(label: 'Menjemput Paket'),
          Expanded(child: _buildStepLine()),
          _buildStepItem(label: 'Diperjalanan'),
          Expanded(child: _buildStepLine()),
          _buildStepItem(label: 'Sampai Tujuan'),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String label}) {
    const Color greenColor = Color(0xFF22C55E);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: greenColor, width: 2),
          ),
          child: const Icon(Icons.check, color: greenColor, size: 17),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Selesai',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: greenColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(top: 16, left: 4, right: 4),
      color: const Color(0xFF22C55E),
    );
  }

  Widget _buildOrderInfoCard(BuildContext context) {
    final nestedShip = order['shipment'] is Map ? order['shipment'] as Map : null;
    final String trackingNumber = (order['tracking_number'] ??
            order['order_number'] ??
            order['id'] ??
            '-')
        .toString();

    final pickupLoc = order['pickup_location'] ?? {};
    final dropoffLoc = order['dropoff_location'] ?? {};

    final String pickupName = (pickupLoc is Map ? pickupLoc['name'] : null)?.toString() ??
        order['pickup_name']?.toString() ??
        order['sender_name']?.toString() ??
        'Pengirim';
    final String pickupAddress = (order['pickup_address'] ??
            (pickupLoc is Map ? pickupLoc['address'] : null) ??
            '-')
        .toString();

    final String dropoffName = (dropoffLoc is Map ? dropoffLoc['name'] : null)?.toString() ??
        order['dropoff_name']?.toString() ??
        order['receiver_name']?.toString() ??
        'Penerima';
    final String dropoffAddress = (order['dropoff_address'] ??
            order['delivery_address'] ??
            (dropoffLoc is Map ? dropoffLoc['address'] : null) ??
            '-')
        .toString();

    final String vehicleRaw = (order['vehicle'] ??
            order['vehicle_type'] ??
            nestedShip?['vehicle'] ??
            'motor')
        .toString()
        .toLowerCase();
    final bool isCar = vehicleRaw == 'mobil';
    final String vehicleLabel = isCar ? 'Mobil' : 'Motor';

    final String itemType = (order['package_description'] ??
            order['item_type'] ??
            nestedShip?['package_description'] ??
            'Paket')
        .toString();
    final String weight = (order['package_weight'] ??
            order['weight'] ??
            nestedShip?['package_weight'] ??
            '1')
        .toString();

    final String paymentMethod = (order['payment_method'] ??
            nestedShip?['payment_method'] ??
            'COD')
        .toString()
        .toUpperCase();
    final String rawPrice = (order['price'] ??
            order['total_amount'] ??
            nestedShip?['total_cost'] ??
            '25000')
        .toString();
    final double parsedPrice = double.tryParse(rawPrice) ?? 25000;
    final String formattedPrice =
        'Rp ${parsedPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';

    final now = DateTime.now();
    final completedDateStr = DateFormat('dd MMM yyyy, HH:mm').format(now);

    final scheduledAt = order['pickup_scheduled_at'] ?? nestedShip?['pickup_scheduled_at'];
    final rawPickupTime = (order['pickup_time'] ?? nestedShip?['pickup_time'] ?? '').toString();
    final pickupTimeStr = ScheduleTimeConfig.extractTimeOnly(
      rawPickupTime,
      scheduledAtFallback: scheduledAt,
    );
    final bool isScheduled = order['scheduled_pickup'] == true ||
        order['scheduled_pickup'] == 1 ||
        order['scheduled_pickup'] == '1' ||
        nestedShip?['scheduled_pickup'] == true ||
        nestedShip?['scheduled_pickup'] == 1 ||
        (scheduledAt != null && scheduledAt.toString().isNotEmpty) ||
        rawPickupTime.isNotEmpty;
    final schedDt = ScheduleTimeConfig.parseDateTimeSafe(scheduledAt);
    final displayDateStr =
        schedDt != null ? ScheduleTimeConfig.formatDisplayDay(schedDt) : 'Hari Ini';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Header: Order ID & Ringkasan Kendaraan/Paket
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Order ID: #$trackingNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCar ? Icons.directions_car : Icons.two_wheeler,
                      size: 13,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$vehicleLabel • $itemType ($weight kg)',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          // Baris Utama: Lokasi (Kiri) & Waktu/Harga (Kanan)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kiri: Pickup & Dropoff
              Expanded(
                flex: 3,
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
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                            Column(
                              children: List.generate(
                                6,
                                (index) => Container(
                                  width: 1.5,
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickupName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pickupAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dropoffName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dropoffAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                  height: 1.35,
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
              // Pembatas Vertikal
              Container(
                width: 1,
                height: 88,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              // Kanan: Waktu Selesai / Jadwal & Harga
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isScheduled ? 'Jadwal Pickup' : 'Waktu Selesai',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (isScheduled) ...[
                      Text(
                        displayDateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (pickupTimeStr.isNotEmpty)
                        Text(
                          pickupTimeStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                    ] else
                      Text(
                        completedDateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Harga',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            paymentMethod,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Lunas',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          // Footer Ringkas: Info Penerima & Link Detail (menggantikan kartu Rincian Pengiriman terpisah)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Diterima oleh $dropoffName • $completedDateStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverDetailShipmentScreen(shipment: order),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Detail',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
