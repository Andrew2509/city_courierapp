import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';

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
  bool _isLoadingLocation = true;

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
    final isNew = status == 'pending' || status == 'assigned';
    final isDelivered = status == 'delivered';
    final isCancelled = status == 'cancelled';

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
    final notes =
        widget.shipment['notes'] ??
        'Harap pastikan barang dalam kondisi baik. Terima kasih!';

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
                            color: const Color(0xFF2563EB),
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

          // Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0),
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isNew ? 'Pesanan Diterima' : 'Detail Pesanan',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Icon(
                          Icons.headset_mic_outlined,
                          color: Color(0xFFFF5A00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isNew
                              ? const Color(0xFFFFF0E6)
                              : isDelivered
                              ? const Color(0xFFF1F5F9)
                              : isCancelled
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isNew
                              ? 'Baru'
                              : isDelivered
                              ? 'Selesai'
                              : isCancelled
                              ? 'Dibatalkan'
                              : 'Diproses',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isNew
                                ? const Color(0xFFFF5A00)
                                : isDelivered
                                ? const Color(0xFF475569)
                                : isCancelled
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      Text(
                        'Order ID: $orderId',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF5A00),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Map Controls
          Positioned(
            right: 20,
            top: 120,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            bottom: MediaQuery.of(context).size.height * 0.56 + 20,
            child: GestureDetector(
              onTap: _fitBounds,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),

          // Detail Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.56,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 30,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Locations
                    Stack(
                      children: [
                        Positioned(
                          left: 10,
                          top: 22,
                          bottom: 22,
                          child: CustomPaint(
                            size: const Size(1, double.infinity),
                            painter: DottedLinePainter(),
                          ),
                        ),
                        Column(
                          children: [
                            // Origin
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF5A00),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF5A00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Lokasi Pengirim',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        senderAddress,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () =>
                                            _makePhoneCall(senderPhone),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: const Color(0xFFFFEDD5),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.phone_outlined,
                                                size: 12,
                                                color: Color(0xFFFF5A00),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Hubungi Pengirim',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFFF5A00),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Destination
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF22C55E),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Lokasi Penerima',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        receiverName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        receiverAddress,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () =>
                                            _makePhoneCall(receiverPhone),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: const Color(0xFFFFEDD5),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.phone_outlined,
                                                size: 12,
                                                color: Color(0xFFFF5A00),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Hubungi Penerima',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFFF5A00),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(
                      color: Color(0xFFF1F5F9),
                      thickness: 1.5,
                    ), // HTML had a dashed divider here, we use a normal one or our own DottedLinePainter
                    const SizedBox(height: 24),

                    // Meta Info
                    Column(
                      children: [
                        _buildMetaRow(
                          Icons.access_time,
                          'Estimasi Waktu',
                          '20 - 30 menit',
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Harga',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  _formatCurrency(price),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF22C55E),
                                  ),
                                ),
                                if (isCOD) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'COD',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildMetaRow(
                          Icons.inventory_2_outlined,
                          'Berat & Ukuran',
                          '$weight kg • 30x20x15 cm',
                        ),
                        const SizedBox(height: 18),
                        _buildMetaRow(
                          Icons.local_shipping_outlined,
                          'Jenis Paket',
                          itemType,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Catatan
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.notes,
                              size: 16,
                              color: Color(0xFFFF5A00),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Catatan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            notes,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A1A),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Actions
                    if (isNew) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isAccepting
                                  ? null
                                  : () {
                                      Navigator.pop(context, false);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFFF5A00),
                                side: const BorderSide(
                                  color: Color(0xFFFF5A00),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Tolak',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isAccepting
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isAccepting = true;
                                      });
                                      final requestId =
                                          widget.shipment['id']?.toString() ??
                                          '';
                                      final acceptResult =
                                          await CourierOrderService.acceptPickupRequest(
                                            requestId,
                                          );

                                      if (mounted) {
                                        setState(() {
                                          _isAccepting = false;
                                        });
                                        if (acceptResult['success'] == true) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Pesanan berhasil diterima!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DriverDeliveryFlowScreen(
                                                    order: widget.shipment,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                acceptResult['message'] ??
                                                    'Gagal menerima pesanan',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isAccepting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Terima Pesanan',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
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
