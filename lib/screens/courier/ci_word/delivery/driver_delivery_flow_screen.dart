import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_confirm_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/earnings/driver_earnings_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';
import 'package:geolocator/geolocator.dart';

import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_photo_capture_screen.dart';

enum DeliveryFlowState { pickingUp, pickedUp, delivering, arrived }

class DriverDeliveryFlowScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final DeliveryFlowState initialState;

  const DriverDeliveryFlowScreen({
    super.key,
    required this.order,
    this.initialState = DeliveryFlowState.pickingUp,
  });

  @override
  State<DriverDeliveryFlowScreen> createState() => _DriverDeliveryFlowScreenState();
}

class _DriverDeliveryFlowScreenState extends State<DriverDeliveryFlowScreen> {
  late DeliveryFlowState _currentState;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final status = widget.order['status']?.toString().toLowerCase();
    if (status == 'delivering' || status == 'in_transit') {
      _currentState = DeliveryFlowState.delivering;
    } else if (status == 'picked_up') {
      _currentState = DeliveryFlowState.pickedUp;
    } else if (status == 'arrived') {
      _currentState = DeliveryFlowState.arrived;
    } else {
      _currentState = widget.initialState;
    }
    _initMapLocations();
  }

  Future<void> _handleConfirmPickup() async {
    String? photoPath;
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverPhotoCaptureScreen(order: widget.order),
        ),
      );
      if (result is String) {
        photoPath = result;
      }
    } catch (_) {}

    setState(() => _isLoading = true);
    try {
      final result = await CourierOrderService.updateOrderStatus(
        orderId: widget.order['id'].toString(),
        status: 'picked_up',
        photoPath: photoPath,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paket berhasil diambil! Siap untuk diantar.'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _currentState = DeliveryFlowState.pickedUp;
          });
          _fetchRoute();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Gagal memperbarui status')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onBottomActionPressed() async {
    switch (_currentState) {
      case DeliveryFlowState.pickingUp:
        await _handleConfirmPickup();
        break;
      case DeliveryFlowState.pickedUp:
        setState(() => _isLoading = true);
        try {
          final result = await CourierOrderService.updateOrderStatus(
            orderId: widget.order['id'].toString(),
            status: 'delivering',
          );
          if (mounted) {
            if (result['success'] == true) {
              setState(() {
                _currentState = DeliveryFlowState.delivering;
              });
              _fetchRoute();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result['message'] ?? 'Gagal memperbarui status')),
              );
            }
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
        break;
      case DeliveryFlowState.delivering:
        setState(() {
          _currentState = DeliveryFlowState.arrived;
        });
        break;
      case DeliveryFlowState.arrived:
        // Navigate to confirm screen with replacement so back button goes to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverConfirmScreen(order: widget.order),
          ),
        );
        break;
    }
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
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pilih kendala yang Anda hadapi di lokasi penjemputan:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pengirim tidak dapat dihubungi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: 'customer_unreachable',
                    groupValue: selectedReason,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Barang belum siap untuk dijemput', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: 'package_not_ready',
                    groupValue: selectedReason,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pengirim meminta penyesuaian jadwal (Reschedule)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: 'reschedule_requested',
                    groupValue: selectedReason,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alamat pickup tidak ditemukan / tidak sesuai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: 'address_not_found',
                    groupValue: selectedReason,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kendala lainnya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: 'other',
                    groupValue: selectedReason,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Tambahkan catatan penjelasan kendala...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                        setState(() => _isLoading = true);
                        final res = await CourierOrderService.reportPickupIssue(
                          orderId: widget.order['id'].toString(),
                          reason: selectedReason,
                          notes: notesController.text.trim(),
                        );
                        if (!mounted) return;
                        setState(() => _isLoading = false);
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
                        backgroundColor: AppColors.primaryOrange,
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

  Future<void> _callContact(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    // After first confirmation (delivering/arrived), prevent back navigation
    final bool canGoBack = _currentState == DeliveryFlowState.pickingUp;

    return PopScope(
      canPop: canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Show confirmation dialog for going back
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Konfirmasi'),
            content: const Text('Apakah Anda yakin ingin kembali? Status pengiriman sudah diperbarui.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tidak'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DriverShipmentScreen()),
                  );
                },
                child: const Text('Ya, Kembali'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      body: SafeArea(
        bottom: false,
        child: Container(
          color: const Color(0xFFFAFAFA),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildMapMockup(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Column(
                              children: [
                                _buildStatusCard(),
                                const SizedBox(height: 12),
                                _buildOrderInfoCard(),
                                if (_currentState == DeliveryFlowState.delivering) ...[
                                  const SizedBox(height: 12),
                                  _buildDeliveryInfoCard(),
                                ] else if (_currentState == DeliveryFlowState.arrived) ...[
                                  const SizedBox(height: 12),
                                  _buildInfoBanner(),
                                ],
                                const SizedBox(height: 88),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  color: Colors.white,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onBottomActionPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _getButtonText(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
              // Full Screen Loading Overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryOrange),
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
    ),
    );
  }

  String _getButtonText() {
    switch (_currentState) {
      case DeliveryFlowState.pickingUp:
        return 'Konfirmasi Barang Diambil';
      case DeliveryFlowState.pickedUp:
        return 'Mulai Antar ke Penerima';
      case DeliveryFlowState.delivering:
        return 'Sampai di Lokasi Penerima';
      case DeliveryFlowState.arrived:
        return 'Konfirmasi Penerima (POD)';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _currentState == DeliveryFlowState.pickingUp
                ? () => Navigator.pop(context)
                : null,
            child: Icon(
              Icons.arrow_back,
              color: _currentState == DeliveryFlowState.pickingUp
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          Text(
            _getHeaderText(),
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          if (_currentState == DeliveryFlowState.pickingUp)
            IconButton(
              onPressed: _showReportIssueDialog,
              icon: const Icon(Icons.report_problem_outlined, color: Color(0xFFD97706), size: 20),
              tooltip: 'Laporkan Kendala Pickup',
            )
          else
            const Icon(Icons.headset_mic_outlined, color: AppColors.primaryOrange),
        ],
      ),
    );
  }

  String _getHeaderText() {
    switch (_currentState) {
      case DeliveryFlowState.pickingUp:
        return 'Menjemput Paket';
      case DeliveryFlowState.pickedUp:
        return 'Paket Siap Diantar';
      case DeliveryFlowState.delivering:
        return 'Paket Diperjalanan';
      case DeliveryFlowState.arrived:
        return 'Tiba di Lokasi Penerima';
    }
  }

  double _pickupLat = 0;
  double _pickupLng = 0;
  double _dropoffLat = 0;
  double _dropoffLng = 0;
  double _courierLat = 0;
  double _courierLng = 0;
  bool _isMapLoading = true;
  List<LatLng> _routeCoordinates = [];

  Future<void> _initMapLocations() async {
    // Ambil koordinat dari backend - field: latitude_pickup, longitude_pickup, latitude_delivery, longitude_delivery
    double pLat = double.tryParse(widget.order['latitude_pickup']?.toString() ?? '') ?? 0;
    double pLng = double.tryParse(widget.order['longitude_pickup']?.toString() ?? '') ?? 0;
    double dLat = double.tryParse(widget.order['latitude_delivery']?.toString() ?? '') ?? 0;
    double dLng = double.tryParse(widget.order['longitude_delivery']?.toString() ?? '') ?? 0;

    // Fallback: coba field alternatif dari backend
    if (pLat == 0 || pLng == 0) {
      pLat = double.tryParse(widget.order['pickup_latitude']?.toString() ?? '') ?? 0;
      pLng = double.tryParse(widget.order['pickup_longitude']?.toString() ?? '') ?? 0;
    }

    if (dLat == 0 || dLng == 0) {
      dLat = double.tryParse(widget.order['dropoff_latitude']?.toString() ?? '') ?? 0;
      dLng = double.tryParse(widget.order['dropoff_longitude']?.toString() ?? '') ?? 0;
    }

    // Fallback: coba dari nested pickup_location / dropoff_location
    if ((pLat == 0 || pLng == 0)) {
      final pickupLoc = widget.order['pickup_location'];
      if (pickupLoc != null && pickupLoc is Map) {
        pLat = double.tryParse(pickupLoc['latitude']?.toString() ?? '') ?? 0;
        pLng = double.tryParse(pickupLoc['longitude']?.toString() ?? '') ?? 0;
      }
    }

    if ((dLat == 0 || dLng == 0)) {
      final dropoffLoc = widget.order['dropoff_location'];
      if (dropoffLoc != null && dropoffLoc is Map) {
        dLat = double.tryParse(dropoffLoc['latitude']?.toString() ?? '') ?? 0;
        dLng = double.tryParse(dropoffLoc['longitude']?.toString() ?? '') ?? 0;
      }
    }

    // Jika masih 0, gunakan LocationRepository (Nominatim/Photon)
    final locationRepo = LocationRepository();

    if (pLat == 0 || pLng == 0) {
      try {
        final String pAddress = widget.order['pickup_address'] ?? '';
        final String simplified = _simplifyAddress(pAddress);
        if (simplified.isNotEmpty) {
          final results = await locationRepo.searchAddress(simplified);
          if (results.isNotEmpty) {
            pLat = results.first.latitude;
            pLng = results.first.longitude;
          }
        }
      } catch (e) {
        // fallback ke default
      }
    }

    if (dLat == 0 || dLng == 0) {
      try {
        final String dAddress = widget.order['dropoff_address'] ?? '';
        final String simplified = _simplifyAddress(dAddress);
        if (simplified.isNotEmpty) {
          final results = await locationRepo.searchAddress(simplified);
          if (results.isNotEmpty) {
            dLat = results.first.latitude;
            dLng = results.first.longitude;
          }
        }
      } catch (e) {
        // fallback ke default
      }
    }

    locationRepo.dispose();

    // Ambil lokasi kurir via GPS
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          // permission ditolak, skip
        } else {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          _courierLat = position.latitude;
          _courierLng = position.longitude;
        }
      }
    } catch (e) {
      // GPS gagal, fallback ke pickup location
    }

    // Jika GPS tidak tersedia, gunakan lokasi pickup sebagai fallback
    if (_courierLat == 0 && _courierLng == 0) {
      _courierLat = pLat == 0 ? -6.2088 : pLat;
      _courierLng = pLng == 0 ? 106.8456 : pLng;
    }

    if (mounted) {
      setState(() {
        _pickupLat = pLat == 0 ? -6.2088 : pLat;
        _pickupLng = pLng == 0 ? 106.8456 : pLng;
        _dropoffLat = dLat == 0 ? -6.2100 : dLat;
        _dropoffLng = dLng == 0 ? 106.8500 : dLng;
      });
    }

    // Fetch rute jalan berdasarkan fase
    await _fetchRoute();

    if (mounted) {
      setState(() {
        _isMapLoading = false;
      });
    }
  }

  /// Sederhanakan alamat untuk geocoding.
  /// Ambil hanya bagian penting: nama tempat/jalan + kota.
  /// Contoh: "Reny Swalayan, No. 132 -134, Jalan Bratang Gede, ..."
  ///       → "Reny Swalayan, Surabaya"
  String _simplifyAddress(String address) {
    if (address.isEmpty) return '';

    // Split by comma
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return address;

    // Ambil 1-2 bagian pertama (nama + jalan)
    String result = parts.first;
    if (parts.length > 1) {
      result += ', ${parts[1]}';
    }

    // Cari dan tambahkan nama kota jika ada
    final cityPatterns = ['Surabaya', 'Sidoarjo', 'Gresik', 'Mojokerto', 'Malang', 'Jakarta', 'Bandung', 'Semarang', 'Yogyakarta', 'Medan'];
    for (final part in parts) {
      for (final city in cityPatterns) {
        if (part.toLowerCase().contains(city.toLowerCase())) {
          // Cek apakah kota sudah ada di result
          if (!result.toLowerCase().contains(city.toLowerCase())) {
            result += ', $city';
          }
          return result;
        }
      }
    }

    return result;
  }

  Future<void> _fetchRoute() async {
    final origin = _mapOrigin;
    final destination = _mapDestination;

    try {
      final routingService = CityCourierRoutingService();
      final route = await routingService.getRoute(
        origin: origin,
        destination: destination,
      );
      if (mounted && route.coordinates.isNotEmpty) {
        setState(() {
          _routeCoordinates = route.coordinates;
        });
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      // Fallback: garis lurus sudah ditangani oleh _mapOrigin/_mapDestination
    }
  }

  /// Titik awal & akhir peta bergantung pada fase delivery
  LatLng get _mapOrigin {
    if (_currentState == DeliveryFlowState.pickingUp) {
      // Saat penjemputan: dari lokasi kurir
      return LatLng(_courierLat, _courierLng);
    }
    // Saat mengantar: dari lokasi pengirim (sudah dijemput)
    return LatLng(_pickupLat, _pickupLng);
  }

  LatLng get _mapDestination {
    if (_currentState == DeliveryFlowState.pickingUp) {
      // Saat penjemputan: menuju lokasi pengirim
      return LatLng(_pickupLat, _pickupLng);
    }
    // Saat mengantar: menuju lokasi penerima
    return LatLng(_dropoffLat, _dropoffLng);
  }

  /// Snap titik ke rute terdekat (agar icon kurir selalu di garis biru)
  LatLng _snapToRoute(LatLng point) {
    if (_routeCoordinates.isEmpty) return point;

    final distance = const Distance();
    LatLng closest = _routeCoordinates.first;
    double minDist = distance.as(LengthUnit.Meter, point, closest);

    for (int i = 1; i < _routeCoordinates.length; i++) {
      final d = distance.as(LengthUnit.Meter, point, _routeCoordinates[i]);
      if (d < minDist) {
        minDist = d;
        closest = _routeCoordinates[i];
      }
    }

    return closest;
  }

  Widget _buildMapMockup() {
    if (_isMapLoading) {
      return const SizedBox(
        width: double.infinity,
        height: 250,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    final origin = _mapOrigin;
    final destination = _mapDestination;

    return SizedBox(
      width: double.infinity,
      height: 250,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: origin,
              initialZoom: 14.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.citycourier.app',
              ),
              PolylineLayer(
                polylines: [
                  // Garis putih sebagai border
                  if (_routeCoordinates.isNotEmpty)
                    Polyline(
                      points: _routeCoordinates,
                      strokeWidth: 8.0,
                      color: Colors.white,
                    ),
                  // Garis biru sebagai rute utama
                  Polyline(
                    points: _routeCoordinates.isNotEmpty ? _routeCoordinates : [origin, destination],
                    strokeWidth: 5.0,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Marker titik asal (kurir saat pickingUp, pengirim saat delivering)
                  // Snap kurir ke rute agar selalu berada di garis biru
                  // Icon tepat di titik rute dengan alignment center
                  // Marker kurir — posisi berubah sesuai fase
                  // pickingUp: di lokasi kurir (GPS), delivering: di lokasi pengirim, arrived: di lokasi penerima
                  Marker(
                    point: _currentState == DeliveryFlowState.pickingUp
                        ? _snapToRoute(origin)
                        : (_currentState == DeliveryFlowState.arrived ? destination : origin),
                    width: 80,
                    height: 80,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Icon di tengah (tepat di titik rute)
                        Center(
                          child: Image.asset(
                            'assets/Icon/Kurir.png',
                            width: 52,
                            height: 52,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF2563EB), width: 2),
                              ),
                              child: const Icon(Icons.delivery_dining, color: Color(0xFF2563EB), size: 18),
                            ),
                          ),
                        ),
                        // Label di atas icon
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Kurir',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Marker titik tujuan
                  Marker(
                    point: destination,
                    width: 60,
                    height: 70,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentState == DeliveryFlowState.pickingUp ? 'Pengirim' : 'Penerima',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryOrange, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _currentState == DeliveryFlowState.pickingUp
                                ? Icons.store
                                : Icons.home_outlined,
                            color: AppColors.primaryOrange,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverNavigationScreen(order: widget.order),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.navigation, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    final nestedShip = widget.order['shipment'] is Map ? widget.order['shipment'] as Map : null;
    final String trackingNumber = (widget.order['tracking_number'] ??
            widget.order['order_number'] ??
            nestedShip?['tracking_number'] ??
            widget.order['id']?.toString() ??
            '-')
        .toString();

    final pickup = widget.order['pickup_location'] ?? widget.order['sender'] ?? {};
    final dropoff = widget.order['dropoff_location'] ?? widget.order['receiver'] ?? {};

    final String pickupName = (pickup is Map ? pickup['name'] : null)?.toString() ??
        widget.order['sender_name']?.toString() ??
        widget.order['customer_name']?.toString() ??
        widget.order['pickup_name']?.toString() ??
        'Pengirim';
    final String pickupAddress = (widget.order['pickup_address'] ??
            (pickup is Map ? pickup['address'] : null) ??
            '-')
        .toString();
    final String senderPhone = (widget.order['sender_phone'] ??
            widget.order['customer_phone'] ??
            '081234567890')
        .toString();

    final String dropoffName = (dropoff is Map ? dropoff['name'] : null)?.toString() ??
        widget.order['receiver_name']?.toString() ??
        widget.order['dropoff_name']?.toString() ??
        'Penerima';
    final String dropoffAddress = (widget.order['dropoff_address'] ??
            widget.order['delivery_address'] ??
            (dropoff is Map ? dropoff['address'] : null) ??
            '-')
        .toString();
    final String receiverPhone = (widget.order['receiver_phone'] ?? '081234567890').toString();

    final scheduledAt = widget.order['pickup_scheduled_at'] ?? nestedShip?['pickup_scheduled_at'];
    final rawPickupTime = (widget.order['pickup_time'] ?? nestedShip?['pickup_time'] ?? '').toString();
    final pickupTimeStr = ScheduleTimeConfig.extractTimeOnly(
      rawPickupTime,
      scheduledAtFallback: scheduledAt,
    );
    final bool isScheduled = widget.order['scheduled_pickup'] == true ||
        widget.order['scheduled_pickup'] == 1 ||
        widget.order['scheduled_pickup'] == '1' ||
        nestedShip?['scheduled_pickup'] == true ||
        nestedShip?['scheduled_pickup'] == 1 ||
        (scheduledAt != null && scheduledAt.toString().isNotEmpty) ||
        rawPickupTime.isNotEmpty;
    final schedDt = ScheduleTimeConfig.parseDateTimeSafe(scheduledAt);
    final displayDateStr = schedDt != null ? ScheduleTimeConfig.formatDisplayDay(schedDt) : 'Hari Ini';

    final String vehicleRaw = (widget.order['vehicle'] ??
            widget.order['vehicle_type'] ??
            nestedShip?['vehicle'] ??
            'motor')
        .toString()
        .toLowerCase();
    final bool isCar = vehicleRaw == 'mobil';
    final String vehicleLabel = isCar ? 'Mobil' : 'Motor';

    final String itemType = (widget.order['package_description'] ??
            widget.order['item_type'] ??
            nestedShip?['package_description'] ??
            'Paket')
        .toString();
    final String weight = (widget.order['package_weight'] ??
            widget.order['weight'] ??
            nestedShip?['package_weight'] ??
            '1')
        .toString();
    final String paymentMethod = (widget.order['payment_method'] ??
            nestedShip?['payment_method'] ??
            'COD')
        .toString()
        .toUpperCase();
    final String rawPrice = (widget.order['price'] ??
            widget.order['total_amount'] ??
            nestedShip?['total_cost'] ??
            '25000')
        .toString();
    final double parsedPrice = double.tryParse(rawPrice) ?? 25000;
    final String formattedPrice =
        'Rp ${parsedPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    final String notes = ScheduleTimeConfig.cleanScheduleTagFromNotes(
      (widget.order['notes'] ?? nestedShip?['notes'] ?? '').toString(),
    );

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
          // Baris Header: Order ID & Ringkasan Barang/Kendaraan
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
          // Baris Utama: Lokasi (Kiri) & Jadwal/Estimasi + Harga (Kanan)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Locations (Pickup & Dropoff)
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
                          child: const Icon(Icons.location_on, color: Colors.white, size: 12),
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
              // Vertical Divider
              Container(
                width: 1,
                height: 88,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              // Meta (Right side)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isScheduled ? 'Jadwal Pickup' : 'Estimasi',
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
                      const Text(
                        '20 - 30 mnt',
                        style: TextStyle(
                          fontSize: 11.5,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  ],
                ),
              ),
            ],
          ),
          // Catatan Pengirim (jika ada)
          if (notes.isNotEmpty && notes != '-') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryOrange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: AppColors.primaryOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Catatan: $notes',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Tombol Kontak Terpadu (Pengirim & Penerima dalam 1 baris tanpa mengulang kartu alamat)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callContact(senderPhone),
                  icon: const Icon(Icons.phone_rounded, size: 15, color: AppColors.primaryOrange),
                  label: const Text(
                    'Hubungi Pengirim',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryOrange, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callContact(receiverPhone),
                  icon: const Icon(Icons.phone_rounded, size: 15, color: Color(0xFF22C55E)),
                  label: const Text(
                    'Hubungi Penerima',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF22C55E), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
          _buildStepItem(
            label: 'Menjemput Paket',
            isActive: _currentState == DeliveryFlowState.pickingUp,
            isDone: _currentState == DeliveryFlowState.pickedUp ||
                _currentState == DeliveryFlowState.delivering ||
                _currentState == DeliveryFlowState.arrived,
            iconData: Icons.inventory_2_outlined,
            doneIconData: Icons.check,
            subLabel: (_currentState == DeliveryFlowState.pickedUp ||
                    _currentState == DeliveryFlowState.delivering ||
                    _currentState == DeliveryFlowState.arrived)
                ? 'Selesai'
                : 'Menuju Lokasi',
          ),
          Expanded(
            child: _buildStepLine(
              _currentState == DeliveryFlowState.pickedUp ||
                  _currentState == DeliveryFlowState.delivering ||
                  _currentState == DeliveryFlowState.arrived,
            ),
          ),
          _buildStepItem(
            label: 'Diperjalanan',
            isActive: _currentState == DeliveryFlowState.pickedUp ||
                _currentState == DeliveryFlowState.delivering,
            isDone: _currentState == DeliveryFlowState.arrived,
            iconData: Icons.local_shipping_outlined,
            doneIconData: Icons.check,
            subLabel: _currentState == DeliveryFlowState.pickedUp
                ? 'Siap Antar'
                : (_currentState == DeliveryFlowState.delivering
                    ? 'Sedang Antar'
                    : (_currentState == DeliveryFlowState.arrived ? 'Selesai' : 'Tahap 2')),
          ),
          Expanded(child: _buildStepLine(_currentState == DeliveryFlowState.arrived)),
          _buildStepItem(
            label: 'Sampai Tujuan',
            isActive: _currentState == DeliveryFlowState.arrived,
            isDone: false,
            iconData: Icons.location_on_outlined,
            subLabel: _currentState == DeliveryFlowState.arrived ? 'Saat Ini' : 'Tahap 3',
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String label,
    required bool isActive,
    required bool isDone,
    required IconData iconData,
    IconData? doneIconData,
    String? subLabel,
  }) {
    Color iconColor;
    Color borderColor;
    const Color bgColor = Colors.white;

    if (isDone) {
      iconColor = const Color(0xFF22C55E);
      borderColor = const Color(0xFF22C55E);
    } else if (isActive) {
      iconColor = AppColors.primaryOrange;
      borderColor = AppColors.primaryOrange;
    } else {
      iconColor = const Color(0xFF94A3B8);
      borderColor = const Color(0xFFE2E8F0);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Icon(
            isDone && doneIconData != null ? doneIconData : iconData,
            color: iconColor,
            size: 17,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isActive || isDone ? const Color(0xFF1A1A1A) : const Color(0xFF64748B),
            height: 1.2,
          ),
        ),
        if (subLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            subLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isDone
                  ? const Color(0xFF22C55E)
                  : (isActive ? AppColors.primaryOrange : const Color(0xFF94A3B8)),
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(top: 17, left: 6, right: 6),
      color: isDone ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildDeliveryInfoCard() {
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
            'Informasi Pengiriman',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn(Icons.access_time, 'Estimasi\nSampai', '11:30 - 12:00'),
              _buildInfoColumn(Icons.route_outlined, 'Jarak Tersisa', '2.4 km'),
              _buildInfoColumn(Icons.inventory_2_outlined, 'Jenis Paket', widget.order['item_type'] ?? 'Elektronik'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    String message = '';
    String title = '';
    IconData icon = Icons.inventory_2;
    switch (_currentState) {
      case DeliveryFlowState.pickingUp:
        message = 'Silakan menuju ke lokasi penjemputan paket.';
        break;
      case DeliveryFlowState.pickedUp:
        message = 'Paket telah diambil. Silakan mulai antar ke lokasi penerima.';
        break;
      case DeliveryFlowState.delivering:
        message = 'Paket sedang dalam perjalanan.\nSilakan antarkan ke lokasi penerima.';
        break;
      case DeliveryFlowState.arrived:
        title = 'Catatan';
        message = 'Mohon konfirmasi kepada penerima sebelum menyerahkan paket.';
        icon = Icons.error_outline;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: title.isNotEmpty ? FontWeight.w500 : FontWeight.w600,
                    color: AppColors.primaryOrange,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
