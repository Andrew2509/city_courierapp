import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/controllers/traffic_controller.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_complete_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/services/courier/courier_contact_helper.dart';
import 'package:city_courierapp/services/maps/traffic_service.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/widgets/maps/traffic_overlay_widgets.dart';

class DriverAtDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DriverAtDeliveryScreen({super.key, required this.order});

  @override
  State<DriverAtDeliveryScreen> createState() => _DriverAtDeliveryScreenState();
}

class _DriverAtDeliveryScreenState extends State<DriverAtDeliveryScreen>
    with WidgetsBindingObserver {
  late final MapController _mapController;
  late final TrafficService _trafficService;
  late final TrafficController _trafficController;
  final RoutingService _routingService = CityCourierRoutingService();
  final Distance _distance = const Distance();

  StreamSubscription<Position>? _positionSub;
  bool _isDelivering = false;

  LatLng? _currentLocation;
  RouteModel? _route;
  late final double deliveryLat;
  late final double deliveryLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _trafficService = TrafficService();
    _trafficController = TrafficController(
      service: _trafficService,
      initialEnabled: true,
      initialShowLegend: false,
    )..addListener(_onTrafficChanged);

    deliveryLat =
        double.tryParse(widget.order['dropoff_latitude']?.toString() ?? '') ??
            -7.2575;
    deliveryLng =
        double.tryParse(widget.order['dropoff_longitude']?.toString() ?? '') ??
            112.7521;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMapOnDelivery();
      unawaited(_startLiveGps());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _trafficController.setMapActive(state == AppLifecycleState.resumed);
  }

  void _onTrafficChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startLiveGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _updatePosition(pos);

      if (!mounted) return;
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 8,
        ),
      ).listen(_updatePosition, onError: (_) {});
    } catch (_) {
      // Gunakan koordinat tujuan sebagai fokus awal bila GPS tidak tersedia.
    }
  }

  void _updatePosition(Position pos) {
    if (!mounted) return;
    final pt = LatLng(pos.latitude, pos.longitude);
    final firstFix = _currentLocation == null;
    setState(() {
      _currentLocation = pt;
    });
    if (firstFix) {
      unawaited(_loadRouteAndTraffic(pt));
    } else {
      _trafficController.updateCourierPosition(pt);
    }
  }

  Future<void> _loadRouteAndTraffic(LatLng origin) async {
    final dest = LatLng(deliveryLat, deliveryLng);
    final dist = _distance.as(LengthUnit.Meter, origin, dest);
    if (dist <= 20.0) return;

    try {
      final route = await _routingService.getRoute(
        origin: origin,
        destination: dest,
        profile: 'motorcycle',
      );
      if (!mounted) return;
      setState(() {
        _route = route;
      });
      await _trafficController.syncRouteTraffic(
        routeCoordinates: route.coordinates,
        courierLocation: origin,
        destination: dest,
        travelMode: 'motorcycle',
        initialSegments:
            route.trafficSegments.isNotEmpty ? route.trafficSegments : null,
      );
    } catch (_) {
      // Fallback aman bila offline
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _trafficController.removeListener(_onTrafficChanged);
    _trafficController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _centerMapOnDelivery() {
    final target = LatLng(deliveryLat, deliveryLng);
    try {
      _mapController.move(target, 16.0);
    } catch (_) {}
  }

  void _openTurnByTurnNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DriverNavigationScreen(
          order: widget.order,
          phase: NavigationPhase.delivery,
        ),
      ),
    );
  }

  void _markAsDelivered() {
    setState(() {
      _isDelivering = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
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
    final dest = LatLng(deliveryLat, deliveryLng);
    final cur = _currentLocation;
    final route = _route;
    final distMeters =
        cur != null ? _distance.as(LengthUnit.Meter, cur, dest) : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: dest,
                initialZoom: 16.0,
                minZoom: 3.0,
                maxZoom: 20.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: () {
                  try {
                    _trafficController.onViewportChanged(
                      _mapController.camera.visibleBounds,
                      _mapController.camera.zoom,
                    );
                  } catch (_) {}
                },
                onPositionChanged: (camera, _) {
                  _trafficController.onViewportChanged(
                    camera.visibleBounds,
                    camera.zoom,
                  );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.citycourier.app',
                  maxZoom: 20,
                ),
                ...buildTrafficOverlayLayers(
                  controller: _trafficController,
                  trafficService: _trafficService,
                ),
                if (route != null && route.coordinates.length >= 2)
                  PolylineLayer(
                    polylines: buildTrafficColoredRoutePolylines(
                      coordinates: route.coordinates,
                      segments: _trafficController.routeSegments,
                      trafficEnabled: _trafficController.isTrafficEnabled,
                      baseColor: AppColors.primaryBlue,
                      casingWidth: 9.0,
                      lineWidth: 6.0,
                    ),
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: dest,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryOrange.withValues(alpha: 0.45),
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
                    if (cur != null)
                      Marker(
                        point: cur,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(distMeters),
                    const SizedBox(height: 8),
                    TrafficMapFloatingControls(controller: _trafficController),
                  ],
                ),
              ),
            ),

            if (_trafficController.isTrafficEnabled &&
                (_trafficController.selectedRoad != null ||
                    _trafficController.selectedIncident != null))
              Positioned(
                left: 16,
                right: 16,
                bottom: 200,
                child: TrafficSelectionOverlay(controller: _trafficController),
              ),

            Positioned(
              right: 16,
              bottom: 205,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _mapCircleBtn(Icons.my_location, () {
                    final target = cur ?? dest;
                    _mapController.move(target, 16.5);
                  }, color: AppColors.primaryOrange),
                  const SizedBox(height: 8),
                  _mapCircleBtn(Icons.add, () {
                    final z = _mapController.camera.zoom;
                    if (z < 20.0) {
                      _mapController.move(_mapController.camera.center, z + 1);
                    }
                  }),
                  const SizedBox(height: 8),
                  _mapCircleBtn(Icons.remove, () {
                    final z = _mapController.camera.zoom;
                    if (z > 3.0) {
                      _mapController.move(_mapController.camera.center, z - 1);
                    }
                  }),
                ],
              ),
            ),

            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomCard()),
          ],
        ),
      ),
    );
  }

  Widget _mapCircleBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: color ?? Colors.black87),
        ),
      ),
    );
  }

  Widget _buildHeader(double? distMeters) {
    final distLabel = distMeters == null
        ? 'Lokasi penerima'
        : (distMeters >= 1000
            ? '${(distMeters / 1000).toStringAsFixed(1)} km dari tujuan'
            : '${distMeters.round()} m dari tujuan');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tiba di Lokasi Pengantaran',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$distLabel • ${_getCurrentTime()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _openTurnByTurnNavigation,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.navigation_rounded, size: 15),
            label: const Text(
              'Navigasi',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
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
                        widget.order['receiver_name'] ?? 'Lokasi Penerima',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.order['dropoff_address'] ?? 'Alamat Penerima',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                CourierWhatsAppIconButton(
                  key: const Key('at_delivery_wa_button'),
                  size: 40,
                  iconSize: 19,
                  tooltip: 'Chat WA Penerima',
                  onTap: () => CourierContactHelper.openWhatsAppChat(
                    context,
                    phone: CourierContactHelper.extractReceiverPhone(
                      widget.order,
                    ),
                    role: WhatsAppContactRole.receiver,
                    order: widget.order,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton(
              onPressed: _isDelivering ? null : _markAsDelivered,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F7B4A),
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
