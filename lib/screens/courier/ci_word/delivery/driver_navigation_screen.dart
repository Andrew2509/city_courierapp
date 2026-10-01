import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/widgets/map_arrow_marker.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_at_delivery_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_delivery_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';

/// Maps & Navigasi Kurir (PRD).
///
/// - Rute selalu mengikuti jaringan jalan hasil routing engine (bukan garis
///   lurus origin→destination).
/// - Posisi kurir live, marker mengikuti heading kendaraan.
/// - Deteksi keluar jalur + rerouting otomatis dengan cooldown.
/// - Destination berubah sesuai fase (pengirim saat pickup, penerima saat
///   pengantaran).
class DriverNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final NavigationPhase? phase;

  const DriverNavigationScreen({super.key, required this.order, this.phase});

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  late final NavigationController _controller;
  late final MapController _mapController;
  bool _didFitRoute = false;
  bool _confirming = false;
  bool _isAutoCenter = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _controller = NavigationController(
      order: widget.order,
      phase: widget.phase ?? _derivePhase(widget.order),
    );
    _controller.addListener(_onControllerChanged);
    _controller.onVoiceCommand = (command) {
      if (command == 'arrive' && !_confirming) {
        _confirmArrival();
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_controller.start());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _mapController.dispose();
    super.dispose();
  }

  static NavigationPhase _derivePhase(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? '';
    const deliveryStatuses = <String>{
      'delivering',
      'in_transit',
      'on_delivery',
      'delivered',
    };
    if (deliveryStatuses.contains(status)) return NavigationPhase.delivery;
    return NavigationPhase.pickup;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final st = _controller.status;
    if (!_didFitRoute &&
        st == NavigationStatus.navigating &&
        _controller.currentLocation != null &&
        _controller.destination != null) {
      _didFitRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    }

    try {
      final cur = _controller.snappedLocation ?? _controller.currentLocation;
      if (cur != null && _isAutoCenter) {
        // Pindahkan map ke posisi saat ini agar selalu mengikuti kursor (seperti navigasi)
        _mapController.move(cur, _mapController.camera.zoom);
      }

      if (_controller.isCompassHeadingUp) {
        // Gunakan routeHeading agar peta berputar lurus sejajar dengan garis rute biru
        final headingToUse =
            _controller.routeHeading ?? _controller.heading ?? 0.0;
        _mapController.rotate(-headingToUse);
      } else {
        _mapController.rotate(0.0);
      }
    } catch (_) {}

    setState(() {});
  }

  void _fitRoute() {
    final cur = _controller.currentLocation;
    final dest = _controller.destination;
    if (cur == null || dest == null) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([cur, dest]),
          padding: const EdgeInsets.fromLTRB(50, 150, 50, 320),
          maxZoom: 16.0,
        ),
      );
    } catch (_) {}
  }

  void _recenterToCurrent() {
    final cur = _controller.currentLocation;
    if (cur == null) return;
    _mapController.move(cur, 16.0);
  }

  String? _orderValue(List<String> keys) {
    for (final k in keys) {
      final v = widget.order[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  String? get _receiverPhone =>
      _orderValue(const ['receiver_phone', 'recipient_phone', 'dropoff_phone']);

  String? get _senderPhone =>
      _orderValue(const ['sender_phone', 'pickup_phone']);

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor telepon tidak tersedia')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _confirmArrival() async {
    if (_controller.phase == NavigationPhase.delivery) {
      final order = widget.order;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DriverAtDeliveryScreen(order: order),
        ),
      );
      return;
    }

    setState(() => _confirming = true);
    final result = await CourierOrderService.updateOrderStatus(
      orderId: widget.order['id'].toString(),
      status: 'delivering',
    );
    if (!mounted) return;
    setState(() => _confirming = false);

    if (result['success'] == true) {
      final updatedOrder = Map<String, dynamic>.from(widget.order);
      updatedOrder['status'] = 'delivering';
      if (result['data'] != null) {
        updatedOrder.addAll(Map<String, dynamic>.from(result['data']));
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DriverNavigationDeliveryScreen(order: updatedOrder),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal memperbarui status'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          _buildMapOverlays(),
          if (_controller.accuracyWarning) _buildAccuracyBanner(),
          if (_controller.status == NavigationStatus.offRoute ||
              _controller.status == NavigationStatus.rerouting)
            _buildOffRouteBanner(),
          _buildHeader(),
          ..._buildStateOverlays(),
          if (_confirming) _buildConfirmingOverlay(),
          _buildBottom(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- map

  Widget _buildMap() {
    final dest = _controller.destination ?? const LatLng(-7.2575, 112.7521);
    final cur = _controller.snappedLocation ?? _controller.currentLocation;
    final center = cur ?? dest;
    final route = _controller.route;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.0,
        minZoom: 3.0,
        maxZoom: 22.0,
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture && _isAutoCenter) {
            setState(() {
              _isAutoCenter = false;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.citycourier.app',
          maxNativeZoom: 19,
          maxZoom: 22.0,
        ),
        if (route != null && route.coordinates.length >= 2)
          Builder(
            builder: (context) {
              final camera = MapCamera.of(context);
              final zoom = camera.zoom;

              // Hitung ketebalan dinamis berdasarkan zoom level
              double blueWidth = 5.0;
              if (zoom > 14) {
                blueWidth =
                    5.0 +
                    (zoom - 14) *
                        1.5; // Skala diperkecil agar tidak terlalu tebal
              } else if (zoom < 14) {
                blueWidth = 5.0 - (14 - zoom) * 0.5;
                if (blueWidth < 2.5) blueWidth = 2.5; // Minimal 2.5px
              }
              double whiteWidth = blueWidth + 3.0; // Casing putih +3px

              return PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.coordinates,
                    strokeWidth: whiteWidth,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  Polyline(
                    points: route.coordinates,
                    strokeWidth: blueWidth,
                    color: AppColors.primaryBlue,
                  ),
                ],
              );
            },
          ),
        MarkerLayer(markers: [..._buildArrowMarkers(), ..._buildMarkers()]),
      ],
    );
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom < 22.0) {
        _mapController.move(_mapController.camera.center, currentZoom + 1);
      }
    } catch (_) {}
  }

  void _confirmCancelNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Akhiri navigasi?'),
        content: const Text('Rute yang sedang berjalan akan dihentikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context); // tutup dialog
              Navigator.pop(context); // tutup navigasi
            },
            child: const Text(
              'Akhiri Navigasi',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSummary() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Perjalanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _summaryRow('Tujuan', _controller.destinationLabel ?? '-'),
            _summaryRow(
              'Jarak',
              _formatDistance(_controller.distanceRemaining),
            ),
            _summaryRow('ETA', _controller.formattedEta),
            _summaryRow(
              'Waktu perjalanan',
              _formatDuration(_controller.durationRemainingSeconds ?? 0),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMapOverlays() {
    final speed = _controller.speedKmH.round().toString();
    final isMicEnabled = _controller.isMicEnabled;
    final isSoundEnabled = _controller.soundEnabled;
    final isHeadingUp = _controller.isCompassHeadingUp;

    return Positioned.fill(
      child: SafeArea(
        child: Stack(
          children: [
            // Left Speedometer
            Positioned(
              left: 16,
              bottom: 160,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '30',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Text(
                          speed,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          'km/jam',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Right FABs
            Positioned(
              right: 16,
              bottom: 160,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isAutoCenter) ...[
                    _mapFab(Icons.my_location, () {
                      setState(() {
                        _isAutoCenter = true;
                        final cur =
                            _controller.snappedLocation ??
                            _controller.currentLocation;
                        if (cur != null) {
                          _mapController.move(cur, _mapController.camera.zoom);
                        }
                      });
                    }, color: AppColors.primaryOrange),
                    const SizedBox(height: 12),
                  ],
                  _mapFab(isHeadingUp ? Icons.explore : Icons.explore_off, () {
                    _controller.toggleCompassMode();
                    // Jika user menekan tombol compass, kembalikan ke auto-center juga
                    if (!_isAutoCenter) {
                      setState(() {
                        _isAutoCenter = true;
                      });
                    }
                  }),

                  const SizedBox(height: 12),
                  _mapFab(
                    isSoundEnabled ? Icons.volume_up : Icons.volume_off,
                    _controller.toggleSound,
                  ),
                  const SizedBox(height: 12),
                  _mapFab(Icons.add, _zoomIn),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color ?? Colors.black87, size: 26),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final pickup = _controller.pickupLocation;
    final dest = _controller.destination;

    if (pickup != null && _controller.phase == NavigationPhase.delivery) {
      markers.add(
        Marker(
          point: pickup,
          width: 100,
          height: 100,
          alignment: Alignment.topCenter,
          child: _markerBadge(
            icon: Icons.inventory_2_outlined,
            color: AppColors.primaryBlue,
            label: 'Jemput',
          ),
        ),
      );
    }

    if (dest != null) {
      final isPickup = _controller.phase == NavigationPhase.pickup;
      markers.add(
        Marker(
          point: dest,
          width: 100,
          height: 100,
          alignment: Alignment.topCenter,
          child: _markerBadge(
            icon: isPickup ? Icons.inventory_2_outlined : Icons.home_outlined,
            color: AppColors.primaryOrange,
            label: isPickup ? 'Pengirim' : 'Penerima',
          ),
        ),
      );
    }

    final cur = _controller.snappedLocation ?? _controller.currentLocation;
    if (cur != null) {
      markers.add(
        Marker(point: cur, width: 100, height: 100, child: _driverMarker()),
      );
    }

    return markers;
  }

  double _calculateBearing(LatLng p1, LatLng p2) {
    final lat1 = p1.latitude * math.pi / 180.0;
    final lat2 = p2.latitude * math.pi / 180.0;
    final dLng = (p2.longitude - p1.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    var bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360) % 360;
  }

  List<Marker> _buildArrowMarkers() {
    final route = _controller.route;
    if (route == null || route.coordinates.length < 3) return [];

    final markers = <Marker>[];

    // Taruh panah hanya pada titik-titik di mana ada belokan (sudut > 30 derajat)
    for (int i = 1; i < route.coordinates.length - 1; i++) {
      final p0 = route.coordinates[i - 1];
      final p1 = route.coordinates[i];
      final p2 = route.coordinates[i + 1];

      final bearing1 = _calculateBearing(p0, p1);
      final bearing2 = _calculateBearing(p1, p2);

      var diff = (bearing2 - bearing1).abs();
      if (diff > 180) diff = 360 - diff;

      if (diff > 30.0) {
        // Sudut belokan tajam
        markers.add(
          Marker(
            point: p1,
            width: 28,
            height: 28,
            child: Transform.rotate(
              angle: bearing2 * math.pi / 180,
              child: const MapArrowMarker(),
            ),
          ),
        );
      }
    }

    return markers;
  }

  Widget _markerBadge({
    required IconData icon,
    required Color color,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.textWhite, size: 20),
        ),
      ],
    );
  }

  Widget _driverMarker() {
    // Jika compass mode (map berputar mengikuti rute), map dirotasi sebesar -routeHeading.
    // Agar kurir berputar mengikuti arah HP relatif terhadap rute, kita gunakan:
    // deviceHeadingTurns - (routeHeading / 360)
    // Jika map fix utara di atas (icon 2), user minta kurir "tidak bergerak" berputar-putar sembarangan,
    // jadi kita arahkan saja lurus atau searah rute.
    final routeHeadingTurns =
        (_controller.routeHeading ?? _controller.heading ?? 0.0) / 360.0;

    final baseTurns = _controller.isCompassHeadingUp
        ? (_controller.deviceHeadingTurns - routeHeadingTurns)
        : 0.0;

    // Karena default gambar Kurir.png menghadap ke KIRI,
    // kita tambahkan rotasi +90 derajat (0.25 turns) + kompensasi (0.40).
    final turns = baseTurns + 0.90;

    return AnimatedRotation(
      turns: turns,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Image.asset('assets/Icon/Kurir.png', width: 80, height: 80),
    );
  }

  // ------------------------------------------------------- header & banner

  Widget _buildHeader() {
    final nextStep = _controller.nextStep;
    final currentStep = _controller.currentStep;
    final fallbackInstruction = _controller.title;

    final distanceToShow = _controller.distanceToNextManeuver;
    final instructionText = nextStep?.instruction ?? fallbackInstruction;
    final maneuver = nextStep?.maneuver ?? currentStep?.maneuver;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F7B4A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  maneuver != null ? _maneuverIcon(maneuver) : Icons.navigation,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (distanceToShow > 0)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _formatDistance(distanceToShow).split(' ')[0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDistance(
                                        distanceToShow,
                                      ).split(' ').length >
                                      1
                                  ? _formatDistance(
                                      distanceToShow,
                                    ).split(' ')[1]
                                  : '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      Text(
                        instructionText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (nextStep != null &&
                          nextStep.roadName != null &&
                          nextStep.roadName!.isNotEmpty)
                        Text(
                          nextStep.roadName!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                          ),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _controller.toggleMic,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _controller.isMicEnabled
                          ? Colors.red.shade100
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller.isMicEnabled ? Icons.mic : Icons.mic_none,
                      color: _controller.isMicEnabled
                          ? Colors.red
                          : Colors.grey.shade700,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(String text, Color color, IconData icon) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textWhite, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffRouteBanner() {
    final isRerouting = _controller.status == NavigationStatus.rerouting;
    return _buildAlertBanner(
      isRerouting
          ? 'Menghitung rute baru...'
          : 'Anda keluar dari rute\nMencari rute baru...',
      AppColors.warningColor,
      Icons.route_outlined,
    );
  }

  Widget _buildAccuracyBanner() {
    return _buildAlertBanner(
      'Lokasi kurang akurat\nPastikan GPS aktif dan Anda berada di area terbuka.',
      AppColors.warningColor,
      Icons.gps_off,
    );
  }

  // ------------------------------------------------------- state overlays

  List<Widget> _buildStateOverlays() {
    switch (_controller.status) {
      case NavigationStatus.initializing:
        return [_hintCard('Menyiapkan navigasi...')];
      case NavigationStatus.locating:
        return [_hintCard('Menentukan lokasi Anda...')];
      case NavigationStatus.loadingRoute:
        return [_hintCard('Mencari rute terbaik...')];
      case NavigationStatus.error:
        return [_blocker(_errorCard())];
      case NavigationStatus.locationDisabled:
        return [_blocker(_locationDisabledCard())];
      case NavigationStatus.permissionDenied:
        return [_blocker(_permissionCard())];
      default:
        return const [];
    }
  }

  Widget _hintCard(String text) {
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                text,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blocker(Widget card) {
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        child: Center(child: card),
      ),
    );
  }

  Widget _stateCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required List<Widget> actions,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ...actions,
        ],
      ),
    );
  }

  Widget _errorCard() {
    final isPickup = _controller.phase == NavigationPhase.pickup;
    final phone = isPickup ? _senderPhone : _receiverPhone;

    return _stateCard(
      icon: Icons.error_outline,
      iconColor: AppColors.errorColor,
      title: 'Rute tidak tersedia',
      message: _controller.errorMessage.isEmpty
          ? 'Tidak dapat menentukan rute.\nPeriksa koneksi internet Anda dan coba lagi.'
          : _controller.errorMessage,
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => unawaited(_controller.retry()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.textWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Coba Lagi',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (phone != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _call(phone),
              icon: const Icon(Icons.phone, size: 18),
              label: Text(
                isPickup ? 'Hubungi Pengirim' : 'Hubungi Penerima',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOrange,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: const BorderSide(color: AppColors.primaryOrange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup Navigasi'),
        ),
      ],
    );
  }

  Widget _locationDisabledCard() {
    return _stateCard(
      icon: Icons.location_off_outlined,
      iconColor: AppColors.errorColor,
      title: 'Lokasi diperlukan untuk navigasi.',
      message: 'Aktifkan GPS/lokasi pada perangkat Anda untuk melanjutkan.',
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => unawaited(_controller.openSettings()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.textWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Buka Pengaturan',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup Navigasi'),
        ),
      ],
    );
  }

  Widget _permissionCard() {
    final permanentlyDenied = _controller.permissionPermanentlyDenied;
    return _stateCard(
      icon: Icons.location_on_outlined,
      iconColor: AppColors.primaryOrange,
      title: permanentlyDenied
          ? 'Lokasi diperlukan untuk navigasi.'
          : 'Akses lokasi diperlukan',
      message: permanentlyDenied
          ? 'Buka pengaturan aplikasi untuk mengizinkan akses lokasi.'
          : 'CityCourier membutuhkan akses lokasi untuk membantu Anda '
                'menuju lokasi pengirim dan penerima.',
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: permanentlyDenied
                ? () => unawaited(_controller.openSettings())
                : () => unawaited(_controller.allowLocation()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.textWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              permanentlyDenied ? 'Buka Pengaturan' : 'Izinkan Lokasi',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup Navigasi'),
        ),
      ],
    );
  }

  Widget _buildConfirmingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      ),
    );
  }

  // ------------------------------------------------------- bottom sheet

  Widget _buildBottom() {
    if (_controller.hasArrived) return _buildArrivedCard();
    if (_controller.hasRoute &&
        (_controller.status == NavigationStatus.navigating ||
            _controller.status == NavigationStatus.offRoute ||
            _controller.status == NavigationStatus.rerouting)) {
      return _buildBottomSheet();
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomSheet() {
    final c = _controller;
    final step = c.currentStep;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current Street Pill
          if ((step?.roadName ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                step!.roadName!,
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Bottom Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Y-route icon
                InkWell(
                  onTap: _showSummary,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.alt_route,
                      color: Colors.black87,
                      size: 28,
                    ),
                  ),
                ),
                // Center ETA info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatDuration(c.durationRemainingSeconds ?? 0),
                      style: const TextStyle(
                        color: Color(0xFF0F7B4A),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDistance(c.distanceRemaining)} • ${_formatTime(c.eta)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // X Close icon
                InkWell(
                  onTap: _confirmCancelNavigation,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black87,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivedCard() {
    final isPickup = _controller.phase == NavigationPhase.pickup;
    final contactLabel = isPickup ? 'Hubungi Pengirim' : 'Hubungi Penerima';
    final phone = isPickup ? _senderPhone : _receiverPhone;
    final actionLabel = isPickup
        ? 'Konfirmasi Tiba di Pengirim'
        : 'Konfirmasi Tiba di Penerima';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F7EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.primaryTeal,
                size: 34,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Anda telah tiba',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPickup
                  ? 'Anda telah tiba di lokasi pengirim.'
                  : 'Anda telah tiba di lokasi penerima.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (phone != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(phone),
                      icon: const Icon(Icons.phone, size: 18),
                      label: Text(
                        contactLabel,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryOrange,
                        side: const BorderSide(color: AppColors.primaryOrange),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirming ? null : _confirmArrival,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: AppColors.textWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup Navigasi'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- formatters

  IconData _maneuverIcon(String? maneuver) {
    final m = maneuver ?? '';
    if (m.contains('left')) return Icons.turn_left;
    if (m.contains('right')) return Icons.turn_right;
    if (m.contains('uturn')) return Icons.u_turn_left;
    if (m.contains('roundabout') || m == 'via') return Icons.rotate_right;
    if (m == 'arrive') return Icons.place;
    if (m == 'depart') return Icons.play_arrow;
    return Icons.navigation;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  String _formatDuration(double seconds) {
    final totalMin = (seconds / 60).ceil();
    if (totalMin < 1) return '<1 mnt';
    if (totalMin < 60) return '$totalMin menit';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return m == 0 ? '$h jam' : '$h j $m m';
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '--:--';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
