import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';

class DriverDetailShipmentScreen extends StatefulWidget {
  final Map<String, dynamic> shipment;

  const DriverDetailShipmentScreen({super.key, required this.shipment});

  @override
  State<DriverDetailShipmentScreen> createState() =>
      _DriverDetailShipmentScreenState();
}

class _DriverDetailShipmentScreenState
    extends State<DriverDetailShipmentScreen> {
  final MapController _mapController = MapController();

  late double _pickupLat;
  late double _pickupLng;
  late double _dropoffLat;
  late double _dropoffLng;

  bool _isMapReady = false;
  bool _isAccepting = false;
  bool _isRejectingOrder = false;
  bool _isCancellingAssignment = false;
  bool _isLoadingLocation = true;
  bool _isLocallyCancelled = false;
  String? _localCourierCancelStatus;

  bool get _isPendingAdminApproval {
    final status = _localCourierCancelStatus ??
        widget.shipment['courier_cancel_status']?.toString();
    return status == 'pending_approval';
  }

  @override
  void initState() {
    super.initState();
    _initLocations();
  }

  Future<void> _initLocations() async {
    double pLat =
        double.tryParse(widget.shipment['pickup_latitude']?.toString() ?? '') ??
        0;
    double pLng =
        double.tryParse(
          widget.shipment['pickup_longitude']?.toString() ?? '',
        ) ??
        0;
    double dLat =
        double.tryParse(
          widget.shipment['dropoff_latitude']?.toString() ?? '',
        ) ??
        0;
    double dLng =
        double.tryParse(
          widget.shipment['dropoff_longitude']?.toString() ?? '',
        ) ??
        0;

    final locationRepo = LocationRepository();

    if (pLat == 0 || pLng == 0) {
      try {
        final String pAddress = widget.shipment['pickup_address'] ?? '';
        final String simplified = _simplifyAddress(pAddress);
        if (simplified.isNotEmpty) {
          final results = await locationRepo.searchAddress(simplified);
          if (results.isNotEmpty) {
            pLat = results.first.latitude;
            pLng = results.first.longitude;
          }
        }
      } catch (e) {
        // fallback
      }
    }

    if (dLat == 0 || dLng == 0) {
      try {
        final String dAddress = widget.shipment['dropoff_address'] ?? '';
        final String simplified = _simplifyAddress(dAddress);
        if (simplified.isNotEmpty) {
          final results = await locationRepo.searchAddress(simplified);
          if (results.isNotEmpty) {
            dLat = results.first.latitude;
            dLng = results.first.longitude;
          }
        }
      } catch (e) {
        // fallback
      }
    }

    locationRepo.dispose();

    if (mounted) {
      setState(() {
        _pickupLat = pLat == 0 ? -7.2575 : pLat;
        _pickupLng = pLng == 0 ? 112.7521 : pLng;
        _dropoffLat = dLat == 0 ? -7.2675 : dLat;
        _dropoffLng = dLng == 0 ? 112.7621 : dLng;
        _isLoadingLocation = false;
      });
      Future.delayed(const Duration(milliseconds: 300), _fitBounds);
    }
  }

  /// Sederhanakan alamat untuk geocoding.
  String _simplifyAddress(String address) {
    if (address.isEmpty) return '';
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return address;
    String result = parts.first;
    if (parts.length > 1) {
      result += ', ${parts[1]}';
    }
    final cityPatterns = ['Surabaya', 'Sidoarjo', 'Gresik', 'Mojokerto', 'Malang', 'Jakarta', 'Bandung', 'Semarang', 'Yogyakarta', 'Medan'];
    for (final part in parts) {
      for (final city in cityPatterns) {
        if (part.toLowerCase().contains(city.toLowerCase())) {
          if (!result.toLowerCase().contains(city.toLowerCase())) {
            result += ', $city';
          }
          return result;
        }
      }
    }
    return result;
  }

  void _fitBounds() {
    if (!_isMapReady) return;
    final bounds = LatLngBounds.fromPoints([
      LatLng(_pickupLat, _pickupLng),
      LatLng(_dropoffLat, _dropoffLng),
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.shipment['status'] ?? 'pending';
    final isPending = status == 'pending';
    final isAssigned = status == 'assigned';
    final isPickingUp = status == 'picking_up';
    final isPickedUp = status == 'picked_up';
    final isDelivering = status == 'delivering';
    final isDelivered = status == 'delivered';
    final nestedShip = widget.shipment['shipment'] is Map ? widget.shipment['shipment'] as Map : null;
    final isCancelled = _isLocallyCancelled ||
        status == 'cancelled' ||
        nestedShip?['status'] == 'cancelled';
    final vehicleType = (widget.shipment['vehicle'] ?? widget.shipment['vehicle_type'] ?? nestedShip?['vehicle'] ?? 'motor').toString().toLowerCase();
    final isCar = vehicleType == 'mobil';
    final vehicleName = isCar ? 'Mobil' : 'Motor';

    final scheduledAt = widget.shipment['pickup_scheduled_at'] ?? nestedShip?['pickup_scheduled_at'];
    final rawPickupTime = (widget.shipment['pickup_time'] ?? nestedShip?['pickup_time'] ?? '').toString();
    final pickupTimeStr = ScheduleTimeConfig.extractTimeOnly(
      rawPickupTime,
      scheduledAtFallback: scheduledAt,
    );
    final isScheduled = widget.shipment['scheduled_pickup'] == true ||
        widget.shipment['scheduled_pickup'] == 1 ||
        widget.shipment['scheduled_pickup'] == '1' ||
        nestedShip?['scheduled_pickup'] == true ||
        nestedShip?['scheduled_pickup'] == 1 ||
        (scheduledAt != null && scheduledAt.toString().isNotEmpty) ||
        rawPickupTime.isNotEmpty;
    final canStartPickup = isScheduled ? ScheduleTimeConfig.canStartPickup(scheduledAt) : true;
    final isOverdue = isScheduled ? ScheduleTimeConfig.isPickupOverdue(scheduledAt) : false;
    final statusLabel = isScheduled ? ScheduleTimeConfig.getCourierPickupStatusLabel(scheduledAt) : 'Siap Pickup';

    final schedDt = ScheduleTimeConfig.parseDateTimeSafe(scheduledAt);
    final displayDateStr = schedDt != null ? ScheduleTimeConfig.formatDisplayDay(schedDt) : 'Hari Ini';

    final orderId =
        widget.shipment['tracking_number'] ??
        widget.shipment['order_number'] ??
        '#SH-${widget.shipment['id'] ?? '0000'}';
    final senderName =
        widget.shipment['sender_name'] ??
        widget.shipment['merchant']?['name'] ??
        'Toko Elektronik Surabaya';
    final senderAddress =
        widget.shipment['pickup_address'] ??
        'Jl. Raya Darmo No. 123, Surabaya, Jawa Timur';
    final senderPhone = widget.shipment['sender_phone'] ?? '081234567890';

    final receiverName = widget.shipment['receiver_name'] ?? 'Budi Santoso';
    final receiverAddress =
        widget.shipment['dropoff_address'] ??
        'Jl. Kutisari Indah No. 45, Surabaya, Jawa Timur';
    final receiverPhone = widget.shipment['receiver_phone'] ?? '081234567890';

    final double price =
        double.tryParse(widget.shipment['price']?.toString() ?? '0') ?? 25000;
    final isCOD = widget.shipment['payment_method'] == 'COD';
    final weight = widget.shipment['weight'] ?? '2.5';
    final itemType = widget.shipment['item_type'] ?? 'Elektronik';
    final notes = ScheduleTimeConfig.cleanScheduleTagFromNotes(
      widget.shipment['notes'] ??
          'Harap pastikan barang dalam kondisi baik. Terima kasih!',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Map
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.48, // 48% height
            child: _isLoadingLocation
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5A00)),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_pickupLat, _pickupLng),
                      initialZoom: 13.0,
                      maxZoom: 18.0,
                      onMapReady: () {
                        setState(() {
                          _isMapReady = true;
                        });
                        Future.delayed(
                          const Duration(milliseconds: 300),
                          _fitBounds,
                        );
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.citycourier.app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(_pickupLat, _pickupLng),
                              LatLng(_dropoffLat, _dropoffLng),
                            ],
                            strokeWidth: 5.0,
                            color: const Color(0xFFFF5A00),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          // Origin
                          Marker(
                            point: LatLng(_pickupLat, _pickupLng),
                            width: 40,
                            height: 40,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF5A00),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 10,
                                  color: const Color(0xFFFF5A00),
                                ),
                              ],
                            ),
                          ),
                          // Destination
                          Marker(
                            point: LatLng(_dropoffLat, _dropoffLng),
                            width: 40,
                            height: 40,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF22C55E),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 10,
                                  color: const Color(0xFF22C55E),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // Header Floating Bar
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            (isPending || isAssigned) ? 'Pesanan Diterima' : 'Detail Pesanan',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black26),
                          ),
                          child: Text(
                            orderId,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.headset_mic_outlined,
                      size: 19,
                      color: Color(0xFFFF5A00),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map Controls: Navigation
          Positioned(
            right: 16,
            top: 106,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverNavigationScreen(order: widget.shipment),
                  ),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A00),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5A00).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Map Controls: Recenter Location
          Positioned(
            left: 16,
            bottom: MediaQuery.of(context).size.height * 0.58 + 24,
            child: GestureDetector(
              onTap: _fitBounds,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 19,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Detail Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.58,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 25,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Badges Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (isPickedUp || isDelivered)
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFFF5A00),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                isPending
                                    ? 'Pesanan Baru'
                                    : isAssigned
                                    ? (isScheduled ? 'Terjadwal' : 'Ditugaskan')
                                    : isPickingUp
                                    ? 'Proses Pickup'
                                    : isPickedUp
                                    ? 'Paket Diambil'
                                    : isDelivering
                                    ? 'Diperjalanan'
                                    : isDelivered
                                    ? 'Selesai'
                                    : isCancelled
                                    ? 'Dibatalkan'
                                    : 'Diproses',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Vehicle Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black26),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCar ? Icons.directions_car : Icons.two_wheeler,
                                    size: 13,
                                    color: const Color(0xFFFF5A00),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    vehicleName,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Copy Resi Button
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: orderId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nomor pesanan disalin!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                orderId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: Color(0xFFFF5A00),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),
                  const Divider(height: 1, color: Colors.black12),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Scheduled Pickup Banner (jika terjadwal)
                          if (isScheduled) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFF5A00),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 16,
                                    color: Color(0xFFFF5A00),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pickup: $displayDateStr, ${pickupTimeStr.isNotEmpty ? pickupTimeStr : 'Fleksibel'}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: canStartPickup
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFFFF5A00),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isOverdue ? '$statusLabel (Terlambat)' : statusLabel,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 2. Summary Grid (Tarif & Estimasi)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tarif Pengiriman',
                                        style: TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _formatCurrency(price),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF22C55E),
                                              ),
                                            ),
                                          ),
                                          if (isCOD) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFF22C55E)),
                                              ),
                                              child: const Text(
                                                'COD',
                                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.black),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isScheduled ? 'Jadwal & Kendaraan' : 'Waktu & Kendaraan',
                                        style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            isCar ? Icons.directions_car : Icons.two_wheeler,
                                            size: 14,
                                            color: const Color(0xFFFF5A00),
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              isScheduled
                                                  ? '${pickupTimeStr.isNotEmpty ? pickupTimeStr : displayDateStr} • $vehicleName'
                                                  : '~25 mnt • $vehicleName',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 3. Compact Route Timeline
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              children: [
                                // Origin
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5A00).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF5A00),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Penjemputan • $senderName',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            senderAddress,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _makePhoneCall(senderPhone),
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFFF5A00)),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
                                          ],
                                        ),
                                        child: const Icon(Icons.phone_rounded, size: 14, color: Color(0xFFFF5A00)),
                                      ),
                                    ),
                                  ],
                                ),

                                // Connecting Line
                                Padding(
                                  padding: const EdgeInsets.only(left: 7),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 2,
                                      height: 14,
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),

                                // Destination
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF22C55E),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tujuan • $receiverName',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            receiverAddress,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _makePhoneCall(receiverPhone),
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF22C55E)),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
                                          ],
                                        ),
                                        child: const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF22C55E)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 4. Detail Paket Tile
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFFFF5A00)),
                                const SizedBox(width: 8),
                                const Text(
                                  'Barang:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$itemType • $weight kg',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 5. Catatan Tile (jika ada)
                          if (notes.isNotEmpty && notes != '-') ...[
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFF5A00)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.notes_rounded, size: 15, color: Color(0xFFFF5A00)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Catatan: $notes',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Colors.black, height: 1.35, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 6. Banner Status Menunggu Persetujuan Admin (jika kurir sudah mengajukan pembatalan)
                          if (_isPendingAdminApproval) ...[
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFD97706)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Menunggu Persetujuan Admin',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Permintaan kamu sedang diperiksa oleh admin. Status penugasan akan diperbarui setelah keputusan diberikan.',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFF78350F),
                                            height: 1.35,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Pinned Fixed Bottom Action Bar
                  Container(
                    padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(top: BorderSide(color: Colors.black12, width: 1.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: _buildActionButtons(
                      isPending: isPending,
                      isAssigned: isAssigned,
                      isPickingUp: isPickingUp,
                      isPickedUp: isPickedUp,
                      isDelivering: isDelivering,
                      isDelivered: isDelivered,
                      isCancelled: isCancelled,
                      canStartPickup: canStartPickup,
                      statusLabel: statusLabel,
                      pickupTimeStr: pickupTimeStr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required bool isPending,
    required bool isAssigned,
    required bool isPickingUp,
    required bool isPickedUp,
    required bool isDelivering,
    required bool isDelivered,
    required bool isCancelled,
    required bool canStartPickup,
    required String statusLabel,
    required String pickupTimeStr,
  }) {
    if (isCancelled) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black, width: 1.5),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel_outlined, color: Colors.black, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Pesanan Telah Dibatalkan (Aksi Diblokir)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isPending) {
      final bool isBusy = _isAccepting || _isRejectingOrder;
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: isBusy
                  ? null
                  : _showRejectOrderConfirmationDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626), width: 1.3),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isRejectingOrder
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Color(0xFFDC2626),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Tolak Pesanan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: ElevatedButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      setState(() {
                        _isAccepting = true;
                      });
                      final requestId = widget.shipment['id']?.toString() ?? '';
                      final acceptResult = await CourierOrderService.acceptPickupRequest(requestId);

                      if (mounted) {
                        setState(() {
                          _isAccepting = false;
                        });
                        if (acceptResult['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pesanan berhasil diterima!'),
                              backgroundColor: Color(0xFF22C55E),
                            ),
                          );
                          Navigator.pop(context, true);
                        } else {
                          final msg = (acceptResult['message'] ?? 'Gagal menerima pesanan').toString();
                          if (msg.toLowerCase().contains('dibatalkan')) {
                            setState(() => _isLocallyCancelled = true);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: const Color(0xFFFF5A00),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isAccepting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Terima Pesanan',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      );
    }

    if (isAssigned) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canStartPickup
                  ? () async {
                      setState(() => _isAccepting = true);
                      final orderId = widget.shipment['id']?.toString() ?? '';
                      final res = await CourierOrderService.updateOrderStatus(
                        orderId: orderId,
                        status: 'picking_up',
                      );
                      if (!mounted) return;
                      setState(() => _isAccepting = false);

                      if (res['success'] == true) {
                        final updated = (res['data'] as Map<String, dynamic>?) ?? widget.shipment;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DriverDeliveryFlowScreen(order: updated),
                          ),
                        );
                      } else {
                        final msg = (res['message'] ?? 'Gagal memulai penjemputan').toString();
                        if (msg.toLowerCase().contains('dibatalkan')) {
                          setState(() => _isLocallyCancelled = true);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: const Color(0xFFFF5A00),
                          ),
                        );
                      }
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Penjemputan belum dapat dimulai ($statusLabel). Anda dapat mulai 30 menit sebelum jadwal pickup ($pickupTimeStr).',
                          ),
                          backgroundColor: const Color(0xFFFF5A00),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: canStartPickup ? const Color(0xFFFF5A00) : Colors.white,
                foregroundColor: canStartPickup ? Colors.white : Colors.black,
                side: canStartPickup ? BorderSide.none : const BorderSide(color: Colors.black, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    canStartPickup ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                    size: 18,
                    color: canStartPickup ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    canStartPickup ? 'Mulai Pickup Sekarang' : 'Mulai Pickup (Terkunci)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: canStartPickup ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildCancelAssignmentButton(
            onPressed: () => _onCancelOrderButtonPressed(isAlreadyPickedUp: false),
          ),
        ],
      );
    }

    if (isPickingUp) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _showReportIssueDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Kendala Pickup',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverDeliveryFlowScreen(order: widget.shipment),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Proses Pickup',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCancelAssignmentButton(
            onPressed: () => _onCancelOrderButtonPressed(isAlreadyPickedUp: false),
          ),
        ],
      );
    }

    if (isPickedUp) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final res = await CourierOrderService.updateOrderStatus(
                  orderId: widget.shipment['id'].toString(),
                  status: 'delivering',
                );
                if (!mounted) return;
                if (res['success'] == true) {
                  final updated = (res['data'] as Map<String, dynamic>?) ?? widget.shipment;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverDeliveryFlowScreen(order: updated),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Mulai Antar ke Penerima',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildCancelAssignmentButton(
            onPressed: () => _onCancelOrderButtonPressed(isAlreadyPickedUp: true),
          ),
        ],
      );
    }

    if (isDelivering) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverDeliveryFlowScreen(order: widget.shipment),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Lanjutkan Pengantaran',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildCancelAssignmentButton(
            onPressed: () => _onCancelOrderButtonPressed(isAlreadyPickedUp: true),
          ),
        ],
      );
    }

    if (isDelivered) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
              SizedBox(width: 8),
              Text(
                'Pesanan Selesai Terkirim',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF22C55E)),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCancelAssignmentButton({required VoidCallback onPressed}) {
    if (_isPendingAdminApproval) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
            backgroundColor: const Color(0xFFFFFBEB),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 6),
              Text(
                'Menunggu Persetujuan Admin',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: (_isAccepting || _isCancellingAssignment) ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFDC2626), width: 1.3),
          foregroundColor: const Color(0xFFDC2626),
          backgroundColor: const Color(0xFFFEF2F2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isCancellingAssignment
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFFDC2626),
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Text(
                    'Batalkan Pesanan',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _onCancelOrderButtonPressed({required bool isAlreadyPickedUp}) {
    if (isAlreadyPickedUp) {
      _showCannotCancelAfterPickupDialog();
      return;
    }
    _showCourierCancelConfirmationDialog();
  }

  void _showCannotCancelAfterPickupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pembatalan Tidak Dapat Diproses',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Barang sudah diambil atau sedang dalam pengiriman. Kurir tidak diizinkan membatalkan pesanan secara langsung. Silakan laporkan kendala kepada admin City Courier.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.black87,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Kembali',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showReportIssueDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text(
              'Laporkan Kendala ke Admin',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showCourierCancelConfirmationDialog() {
    String? selectedReason;
    final notesController = TextEditingController();
    final List<String> cancelReasons = [
      'Tidak dapat menjemput pada jadwal yang ditentukan.',
      'Kendala kendaraan.',
      'Lokasi pickup sulit dijangkau.',
      'Kendala pribadi atau keadaan darurat.',
      'Alasan lainnya.',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bool isOtherSelected = selectedReason == 'Alasan lainnya.';
            final bool canConfirm = selectedReason != null &&
                (!isOtherSelected || notesController.text.trim().isNotEmpty);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Batalkan Pesanan?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Apakah kamu yakin ingin membatalkan penugasan pesanan ini? Pastikan kamu memilih alasan yang sesuai.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...cancelReasons.map(
                      (reason) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: const Color(0xFFDC2626),
                        onChanged: (val) {
                          setModalState(() {
                            selectedReason = val;
                          });
                        },
                      ),
                    ),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        onChanged: (_) => setModalState(() {}),
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Keterangan tambahan (wajib diisi)',
                          labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                          hintText: 'Tuliskan alasan pembatalan penugasan secara jelas...',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.black45),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black26, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Kembali',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: canConfirm
                                ? () async {
                                    final chosenReason = selectedReason!;
                                    final extraNotes = notesController.text.trim();
                                    Navigator.pop(ctx);
                                    await _submitCourierCancelAssignment(
                                      reason: chosenReason,
                                      notes: extraNotes,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              disabledBackgroundColor: Colors.black12,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.black38,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Konfirmasi Pembatalan',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitCourierCancelAssignment({
    required String reason,
    String? notes,
  }) async {
    final orderId = widget.shipment['id']?.toString() ?? '';
    setState(() {
      _isCancellingAssignment = true;
    });

    final result = await CourierOrderService.cancelCourierAssignment(
      orderId: orderId,
      reason: reason,
      notes: notes,
    );

    if (!mounted) return;
    setState(() {
      _isCancellingAssignment = false;
      if (result['success'] == true && result['action_taken'] == 'pending_approval') {
        _localCourierCancelStatus = 'pending_approval';
      }
    });

    _showCourierCancelResultDialog(result);
  }

  void _showCourierCancelResultDialog(Map<String, dynamic> result) {
    final bool isSuccess = result['success'] == true;
    final String actionTaken = (result['action_taken'] ?? '').toString();
    final bool isPendingApproval = isSuccess && actionTaken == 'pending_approval';
    final bool isReleased = isSuccess && !isPendingApproval;

    final String title = isReleased
        ? 'Penugasan Berhasil Dibatalkan'
        : (isPendingApproval
            ? 'Permintaan Pembatalan Terkirim'
            : 'Pembatalan Tidak Dapat Diproses');

    final String message = isReleased
        ? 'Penugasan pesanan ini sudah dilepas dari akun kamu.'
        : (isPendingApproval
            ? 'Permintaan kamu sedang diperiksa oleh admin. Status penugasan akan diperbarui setelah keputusan diberikan.'
            : (result['message'] ?? 'Pembatalan penugasan tidak dapat diproses saat ini.').toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isReleased
                  ? Icons.check_circle_outline_rounded
                  : (isPendingApproval
                      ? Icons.hourglass_top_rounded
                      : Icons.error_outline_rounded),
              color: isReleased
                  ? const Color(0xFF22C55E)
                  : (isPendingApproval
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626)),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.black87,
            height: 1.45,
          ),
        ),
        actions: [
          if (!isSuccess && result['error_code'] == 'item_already_picked_up')
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showReportIssueDialog();
              },
              child: const Text(
                'Laporkan Kendala ke Admin',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF5A00),
                ),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isReleased && mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isReleased
                  ? const Color(0xFF22C55E)
                  : (isPendingApproval
                      ? const Color(0xFFFF5A00)
                      : Colors.black),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              isReleased
                  ? 'Selesai'
                  : (isPendingApproval
                      ? 'Mengerti'
                      : 'Kembali ke Detail Pesanan'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectOrderConfirmationDialog() {
    String? selectedReason;
    final notesController = TextEditingController();
    final List<String> rejectReasons = [
      'Lokasi pickup terlalu jauh.',
      'Tidak tersedia pada jadwal pickup.',
      'Kendaraan tidak sesuai atau sedang bermasalah.',
      'Kapasitas barang tidak sesuai.',
      'Sedang menangani pesanan lain.',
      'Alasan lainnya.',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bool isOtherSelected = selectedReason == 'Alasan lainnya.';
            final bool canConfirm = selectedReason != null &&
                (!isOtherSelected || notesController.text.trim().isNotEmpty);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Tolak Pesanan?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Apakah kamu yakin ingin menolak pesanan ini? Pesanan akan dikembalikan ke proses penugasan sesuai kebijakan sistem.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...rejectReasons.map(
                      (reason) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: const Color(0xFFDC2626),
                        onChanged: (val) {
                          setModalState(() {
                            selectedReason = val;
                          });
                        },
                      ),
                    ),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        onChanged: (_) => setModalState(() {}),
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Keterangan tambahan (wajib diisi)',
                          labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                          hintText: 'Tuliskan alasan penolakan pesanan secara jelas...',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.black45),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black26, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Kembali',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: canConfirm
                                ? () async {
                                    final chosenReason = selectedReason!;
                                    final extraNotes = notesController.text.trim();
                                    Navigator.pop(ctx);
                                    await _submitCourierRejectOrder(
                                      reason: chosenReason,
                                      notes: extraNotes,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              disabledBackgroundColor: Colors.black12,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.black38,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Konfirmasi Penolakan',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitCourierRejectOrder({
    required String reason,
    String? notes,
  }) async {
    final orderId = widget.shipment['id']?.toString() ?? '';
    setState(() {
      _isRejectingOrder = true;
    });

    final result = await CourierOrderService.rejectOrderOffer(
      orderId: orderId,
      reason: reason,
      notes: notes,
    );

    if (!mounted) return;
    setState(() {
      _isRejectingOrder = false;
    });

    _showCourierRejectResultDialog(result);
  }

  void _showCourierRejectResultDialog(Map<String, dynamic> result) {
    final bool isSuccess = result['success'] == true;
    final String title = isSuccess
        ? 'Pesanan Telah Ditolak'
        : (result['title'] ?? 'Penolakan Tidak Dapat Diproses').toString();
    final String message = isSuccess
        ? 'Pesanan berhasil ditolak dan dikembalikan ke sistem penugasan.'
        : (result['message'] ??
                'Pesanan ini mungkin sudah diterima oleh kurir lain atau penawaran sudah berakhir.')
            .toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              color: isSuccess ? const Color(0xFF22C55E) : const Color(0xFFDC2626),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.black87,
            height: 1.45,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isSuccess && mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? const Color(0xFF22C55E) : Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              isSuccess ? 'Kembali ke Daftar Pesanan' : 'Mengerti',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportIssueDialog() {
    String selectedReason = 'customer_unreachable';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Laporkan Kendala Pickup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pilih kendala yang Anda hadapi di lokasi penjemputan:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pengirim tidak dapat dihubungi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                    value: 'customer_unreachable',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFFF5A00),
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Barang belum siap untuk dijemput', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                    value: 'package_not_ready',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFFF5A00),
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pengirim meminta penyesuaian jadwal (Reschedule)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                    value: 'reschedule_requested',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFFF5A00),
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alamat pickup tidak ditemukan / tidak sesuai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                    value: 'address_not_found',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFFF5A00),
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kendala lainnya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                    value: 'other',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFFF5A00),
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Tambahkan catatan penjelasan kendala...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.black45),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isAccepting = true);
                        final res = await CourierOrderService.reportPickupIssue(
                          orderId: widget.shipment['id'].toString(),
                          reason: selectedReason,
                          notes: notesController.text.trim(),
                        );
                        if (!mounted) return;
                        setState(() => _isAccepting = false);
                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kendala pickup berhasil dilaporkan.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Gagal melaporkan kendala'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Kirim Laporan Kendala', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
