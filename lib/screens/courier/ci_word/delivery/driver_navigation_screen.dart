import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/controllers/traffic_controller.dart';
import 'package:city_courierapp/services/maps/traffic_service.dart';
import 'package:city_courierapp/widgets/maps/maplibre_navigation_view.dart';
import 'package:city_courierapp/widgets/maps/navigation_camera_controller.dart';
import 'package:city_courierapp/widgets/maps/navigation_turn_banner.dart';
import 'package:city_courierapp/widgets/maps/traffic_overlay_widgets.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_at_delivery_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/screens/chat/chat_launch_helper.dart';
import 'package:city_courierapp/services/courier/courier_contact_helper.dart';

/// Memetakan fase navigasi ke halaman tujuan setelah kurir tiba di lokasi.
Widget buildNavigationArrivalScreen({
  required NavigationPhase phase,
  required Map<String, dynamic> order,
}) {
  if (phase == NavigationPhase.delivery) {
    return DriverAtDeliveryScreen(order: order);
  }
  return DriverDeliveryFlowScreen(
    order: order,
    initialState: DeliveryFlowState.pickingUp,
  );
}

/// Dialog konfirmasi mengakhiri navigasi bergaya kartu City Courier (putih bersih).
Future<bool> showEndNavigationConfirmDialog(
  BuildContext context, {
  String? targetLabel,
}) async {
  final subtitle = targetLabel != null && targetLabel.isNotEmpty
      ? 'Rute navigasi menuju $targetLabel yang sedang berjalan akan dihentikan.'
      : 'Rute yang sedang berjalan akan dihentikan.';
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFDC2626),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Akhiri navigasi?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ya, Akhiri',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed == true;
}

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
  final TrafficService? trafficService;
  final bool initialTrafficEnabled;
  final NavigationController? navigationController;
  final Duration autoArrivalDelay;
  final bool autoStartController;
  final bool initial3dEnabled;

  const DriverNavigationScreen({
    super.key,
    required this.order,
    this.phase,
    this.trafficService,
    this.initialTrafficEnabled = true,
    this.navigationController,
    this.autoArrivalDelay = const Duration(milliseconds: 1500),
    this.autoStartController = true,
    this.initial3dEnabled = true,
  });

  static NavigationPhase deriveNavigationPhase(Map<String, dynamic> order) {
    final status = (order['status']?.toString() ?? '').trim().toLowerCase();
    const deliveryStatuses = <String>{
      'picked_up',
      'delivering',
      'in_transit',
      'on_delivery',
      'delivered',
    };
    if (deliveryStatuses.contains(status)) return NavigationPhase.delivery;
    return NavigationPhase.pickup;
  }

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen>
    with WidgetsBindingObserver {
  late final NavigationController _controller;
  late final bool _ownsController;
  late final TrafficService _trafficService;
  late final TrafficController _trafficController;
  late final NavigationMapLibreController _mapController;
  final ValueNotifier<double> _mapBearingNotifier = ValueNotifier<double>(0.0);
  final ArrivalAutoRedirector _arrivalRedirector = ArrivalAutoRedirector();

  bool _isMapReady = false;
  bool _isAutoCenter = true;
  bool _userAdjustedZoom = false;
  late bool _is3dEnabled;
  bool _isBottomSheetExpanded = false;
  bool _isUserGesturing = false;
  double _currentMapBearingDeg = 0.0;
  LatLng? _gestureStartCenter;
  double _gestureStartZoom = NavigationCameraMath.defaultNavZoom;
  double _gestureStartBearing = 0.0;
  Size _mapViewportSize = const Size(400.0, 800.0);

  String? _dismissedAlertSignature;
  String? _lastAltPrefetchSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _is3dEnabled = widget.initial3dEnabled;
    _mapController = NavigationMapLibreController()
      ..addListener(_onMapControllerChanged);
    _trafficService = widget.trafficService ?? TrafficService();
    _trafficController = TrafficController(
      service: _trafficService,
      initialEnabled: widget.initialTrafficEnabled,
      initialShowLegend: false,
    )..addListener(_onTrafficChanged);
    _ownsController = widget.navigationController == null;
    _controller = widget.navigationController ??
        NavigationController(
          order: widget.order,
          phase: widget.phase ??
              DriverNavigationScreen.deriveNavigationPhase(widget.order),
        );
    _controller.addListener(_onControllerChanged);
    _controller.onVoiceCommand = (command) {
      if (command == 'arrive') {
        _confirmArrival();
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoStartController) {
        unawaited(_controller.start());
      }
      if (_controller.hasArrived) {
        _scheduleAutoArrival();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isResumed = state == AppLifecycleState.resumed;
    _trafficController.setMapActive(isResumed);
    if (isResumed && mounted && _isMapReady && _isAutoCenter) {
      _syncFollowCamera(immediate: false, force: true);
    }
  }

  void _onTrafficChanged() {
    if (mounted) setState(() {});
  }

  void _onMapControllerChanged() {
    if (!mounted) return;
    final nextBearing = _mapController.bearingDeg;
    if ((nextBearing - _currentMapBearingDeg).abs() > 0.25) {
      _currentMapBearingDeg = nextBearing;
      _mapBearingNotifier.value = nextBearing;
    }
    if (_mapController.isReady && _mapController.styleController != null) {
      if (_is3dEnabled &&
          _mapController.usingFallbackRaster &&
          mounted) {
        setState(() => _is3dEnabled = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapBearingNotifier.dispose();
    _arrivalRedirector.dispose();
    _trafficController.removeListener(_onTrafficChanged);
    _trafficController.dispose();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    } else {
      _controller.stopTracking(stopSpeech: false);
    }
    _mapController.removeListener(_onMapControllerChanged);
    _mapController.dispose();
    super.dispose();
  }

  EdgeInsets _cameraFollowPadding() {
    return NavigationCameraMath.computeMapLibreFollowPadding(
      _mapViewportSize,
      isNavigationActive: _isAutoCenter,
      is3dEnabled: _is3dEnabled,
      bottomSheetClearance: _bottomOverlayClearance(),
    );
  }

  double _targetNavigationZoom() {
    return NavigationCameraMath.computeTargetZoom(
      speedKmH: _controller.speedKmH,
      is3dEnabled: _is3dEnabled,
      distanceToNextTurnMeters: _controller.distanceToNextManeuver,
    );
  }

  double _targetNavigationPitch() {
    return _is3dEnabled
        ? NavigationCameraMath.default3dPitchDeg
        : NavigationCameraMath.default2dPitchDeg;
  }

  void _syncFollowCamera({
    bool immediate = false,
    bool force = false,
  }) {
    if (!_isMapReady) return;
    final cur = _controller.snappedLocation ?? _controller.currentLocation;
    final cam = _mapController.camera;
    final targetCenter =
        (_isAutoCenter && cur != null) ? cur : (cam?.center ?? cur);
    if (targetCenter == null) return;

    final targetZoom = (_isAutoCenter && !_userAdjustedZoom && cur != null)
        ? _targetNavigationZoom()
        : (cam?.zoom ?? NavigationCameraMath.defaultNavZoom);
    final targetBearing = _controller.isCompassHeadingUp
        ? _controller.effectiveVehicleHeading
        : (cam?.bearingDeg ?? 0.0);
    final targetPitch = _targetNavigationPitch();
    final padding = _cameraFollowPadding();

    unawaited(
      _mapController.animateCamera(
        center: targetCenter,
        zoom: targetZoom,
        bearingDeg: targetBearing,
        pitchDeg: targetPitch,
        padding: padding,
        immediate: immediate,
        force: force,
      ),
    );
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.hasArrived) {
      _scheduleAutoArrival();
    }

    if (_isMapReady && (_isAutoCenter || _controller.isCompassHeadingUp)) {
      _syncFollowCamera();
    }

    _syncRouteTrafficWithController();
    setState(() {});
  }

  void _syncRouteTrafficWithController() {
    final route = _controller.route;
    if (route == null || route.coordinates.length < 2) return;

    final cur = _controller.snappedLocation ?? _controller.currentLocation;
    final dest = _controller.destination;
    final sig = TrafficService.buildRouteSignature(route.coordinates);

    unawaited(
      _trafficController
          .syncRouteTraffic(
            routeCoordinates: route.coordinates,
            courierLocation: cur,
            destination: dest,
            travelMode: _controller.travelMode,
            initialSegments:
                route.trafficSegments.isNotEmpty ? route.trafficSegments : null,
          )
          .then((_) {
            if (!mounted) return;
            final analysis = _trafficController.routeAnalysis;
            if (analysis != null &&
                analysis.hasCongestion &&
                cur != null &&
                dest != null &&
                _lastAltPrefetchSignature != sig &&
                _trafficController.alternativesResult == null) {
              _lastAltPrefetchSignature = sig;
              unawaited(
                _trafficController.loadTrafficAlternatives(
                  origin: cur,
                  destination: dest,
                  travelMode: 'motorcycle',
                ),
              );
            }
          }),
    );
  }

  void _openRouteAlternatives() {
    final route = _controller.route;
    final origin = _controller.snappedLocation ??
        _controller.currentLocation ??
        (route != null && route.coordinates.isNotEmpty
            ? route.coordinates.first
            : null);
    final dest = _controller.destination ??
        (route != null && route.coordinates.isNotEmpty
            ? route.coordinates.last
            : null);

    if (origin == null || dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koordinat rute belum siap untuk mencari alternatif.'),
        ),
      );
      return;
    }

    final activeSig = route != null && route.coordinates.length >= 2
        ? TrafficService.buildRouteSignature(route.coordinates)
        : '';

    showRouteAlternativesSheet(
      context: context,
      controller: _trafficController,
      origin: origin,
      destination: dest,
      currentRouteSignature: activeSig,
      onConfirmAlternative: (alt) {
        if (!mounted || alt.coordinates.length < 2) return;
        final newRoute = routeModelFromAlternative(alt);
        _dismissedAlertSignature = null;
        _lastAltPrefetchSignature = null;
        _controller.applyAlternativeRoute(newRoute);
        unawaited(
          _trafficController.syncRouteTraffic(
            routeCoordinates: newRoute.coordinates,
            courierLocation: origin,
            destination: dest,
            travelMode: 'motorcycle',
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Beralih ke ${alt.label}${alt.viaRoad != null ? ' via ${alt.viaRoad}' : ''}',
            ),
            backgroundColor: const Color(0xFF0F7B4A),
          ),
        );
      },
    );
  }

  String? _orderValue(List<String> keys) {
    for (final k in keys) {
      final v = widget.order[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    final nestedShip = widget.order['shipment'];
    if (nestedShip is Map) {
      for (final k in keys) {
        final v = nestedShip[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
    }
    return null;
  }

  String? get _receiverPhone =>
      _orderValue(const ['receiver_phone', 'recipient_phone', 'dropoff_phone']);

  String? get _senderPhone =>
      _orderValue(const ['sender_phone', 'pickup_phone']);

  String get _orderTrackingNumber =>
      _orderValue(const [
        'tracking_number',
        'order_number',
        'shipment_number',
        'id',
      ]) ??
      '-';

  String get _senderName =>
      _orderValue(const ['sender_name', 'pickup_name', 'customer_name']) ??
      'Pengirim';

  String get _receiverName =>
      _orderValue(const ['receiver_name', 'recipient_name', 'dropoff_name']) ??
      'Penerima';

  String get _pickupAddress =>
      _orderValue(const ['pickup_address']) ?? 'Alamat pengirim';

  String get _dropoffAddress =>
      _orderValue(const ['dropoff_address', 'delivery_address']) ??
      'Alamat penerima';

  Future<void> _call(String? phone) =>
      CourierContactHelper.callPhone(context, phone);

  void _scheduleAutoArrival() {
    _arrivalRedirector.schedule(
      widget.autoArrivalDelay,
      _performArrivalNavigation,
    );
  }

  void _confirmArrival() {
    _arrivalRedirector.triggerNow(_performArrivalNavigation);
  }

  void _performArrivalNavigation() {
    if (!mounted) return;
    _controller.stopTracking(stopSpeech: false);
    _trafficController.setMapActive(false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => buildNavigationArrivalScreen(
          phase: _controller.phase,
          order: widget.order,
        ),
      ),
    );
  }

  void _recenterCamera() {
    _isUserGesturing = false;
    setState(() {
      _isAutoCenter = true;
      _userAdjustedZoom = false;
    });
    _controller.setCompassHeadingUp(true);
    _syncFollowCamera(force: true);
  }

  void _onCompassPressed() {
    _isUserGesturing = false;
    if (!_isMapReady) {
      _controller.toggleCompassMode();
      return;
    }
    final cam = _mapController.camera;
    final currentBearing = cam?.bearingDeg ?? _currentMapBearingDeg;
    final isOffNorth =
        NavigationCameraMath.shortestAngleDeltaDeg(0.0, currentBearing).abs() >
            2.0;

    if (isOffNorth) {
      // Kembali menghadap Utara (0°), nonaktifkan auto-rotate sampai diaktifkan lagi.
      _controller.setCompassHeadingUp(false);
      final cur = _controller.snappedLocation ?? _controller.currentLocation;
      unawaited(
        _mapController.animateCamera(
          center: (_isAutoCenter && cur != null) ? cur : cam?.center,
          zoom: cam?.zoom,
          bearingDeg: 0.0,
          pitchDeg: _targetNavigationPitch(),
          padding: _cameraFollowPadding(),
          duration: const Duration(milliseconds: 420),
          force: true,
        ),
      );
    } else {
      // Sudah Utara-atas -> kembali ke mode navigasi mengikuti kendaraan & arah perjalanan.
      setState(() {
        _isAutoCenter = true;
        _userAdjustedZoom = false;
      });
      _controller.setCompassHeadingUp(true);
      _syncFollowCamera(force: true);
    }
  }

  void _toggle3dTilt() {
    _isUserGesturing = false;
    final next3d = !_is3dEnabled;
    setState(() {
      _is3dEnabled = next3d;
      if (next3d) {
        // Saat kembali ke mode 3D, kembalikan kamera mengikuti kurir & arah.
        _isAutoCenter = true;
        _userAdjustedZoom = false;
      }
    });
    if (next3d) {
      _controller.setCompassHeadingUp(true);
    }
    if (_isMapReady) {
      final cam = _mapController.camera;
      final cur = _controller.snappedLocation ?? _controller.currentLocation;
      unawaited(
        _mapController.animateCamera(
          center: (_isAutoCenter && cur != null) ? cur : cam?.center,
          zoom: (_isAutoCenter && !_userAdjustedZoom && cur != null)
              ? _targetNavigationZoom()
              : cam?.zoom,
          bearingDeg: next3d
              ? _controller.effectiveVehicleHeading
              : (cam?.bearingDeg ?? 0.0),
          pitchDeg: _targetNavigationPitch(),
          padding: _cameraFollowPadding(),
          duration: const Duration(milliseconds: 520),
          force: true,
        ),
      );
    }
  }

  double _bottomOverlayClearance() {
    if (_controller.hasArrived) return 268.0;
    if (_controller.hasRoute &&
        (_controller.status == NavigationStatus.navigating ||
            _controller.status == NavigationStatus.offRoute ||
            _controller.status == NavigationStatus.rerouting)) {
      return _isBottomSheetExpanded ? 214.0 : 96.0;
    }
    return 20.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          _buildMapOverlays(),
          _buildHeader(),
          if (_trafficController.isTrafficEnabled &&
              (_trafficController.selectedRoad != null ||
                  _trafficController.selectedIncident != null))
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom +
                  _bottomOverlayClearance(),
              child: TrafficSelectionOverlay(controller: _trafficController),
            ),
          ..._buildStateOverlays(),
          _buildBottom(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- map

  Widget _buildMap() {
    final dest = _controller.destination ?? const LatLng(-7.2575, 112.7521);
    final cur = _controller.snappedLocation ?? _controller.currentLocation;
    final initialCenter = cur ?? dest;
    final route = _controller.route;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : (MediaQuery.maybeOf(context)?.size.width ?? 400.0);
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : (MediaQuery.maybeOf(context)?.size.height ?? 800.0);
        _mapViewportSize = Size(w, h);

        return NavigationMapLibreView(
          mapController: _mapController,
          initialCenter: initialCenter,
          initialZoom: cur != null ? _targetNavigationZoom() : 15.5,
          initialBearingDeg: _controller.isCompassHeadingUp
              ? _controller.effectiveVehicleHeading
              : 0.0,
          initialPitchDeg: _targetNavigationPitch(),
          routeCoordinates: route?.coordinates ?? const [],
          routeTrafficSegments: _trafficController.routeSegments,
          trafficEnabled: _trafficController.isTrafficEnabled,
          incidents: _trafficController.incidents,
          selectedRoad: _trafficController.selectedRoad,
          courierLocation: cur,
          vehicleHeadingDeg: _controller.effectiveVehicleHeading,
          pickupLocation: _controller.pickupLocation,
          destination: _controller.destination,
          phase: _controller.phase,
          onMapReady: () {
            _isMapReady = true;
            _syncFollowCamera(immediate: true, force: true);
            final bounds = _mapController.visibleBounds;
            if (bounds != null) {
              _trafficController.onViewportChanged(
                bounds,
                _mapController.zoom,
              );
            }
          },
          onUserGestureStart: () {
            _isUserGesturing = true;
            final cam = _mapController.camera;
            _gestureStartCenter = cam?.center;
            _gestureStartZoom = cam?.zoom ?? _mapController.zoom;
            _gestureStartBearing = cam?.bearingDeg ?? _currentMapBearingDeg;
          },
          onCameraChanged: (cam) {
            _currentMapBearingDeg = cam.bearingDeg;
            _mapBearingNotifier.value = cam.bearingDeg;

            if (_isUserGesturing) {
              if (NavigationCameraMath.shortestAngleDeltaDeg(
                        _gestureStartBearing,
                        cam.bearingDeg,
                      ).abs() >
                      3.0 &&
                  _controller.isCompassHeadingUp) {
                _controller.setCompassHeadingUp(false);
              }
              if ((cam.zoom - _gestureStartZoom).abs() > 0.08) {
                _userAdjustedZoom = true;
              }
              final startCenter = _gestureStartCenter;
              if (startCenter != null &&
                  const Distance().as(
                        LengthUnit.Meter,
                        startCenter,
                        cam.center,
                      ) >
                      15.0 &&
                  _isAutoCenter) {
                setState(() {
                  _isAutoCenter = false;
                });
              }
            }

            final bounds = _mapController.visibleBounds;
            if (bounds != null) {
              _trafficController.onViewportChanged(bounds, cam.zoom);
            }
          },
          onCameraIdle: () {
            _isUserGesturing = false;
          },
          onMapTap: (point) {
            if (_trafficController.isTrafficEnabled) {
              final fallbackName = _controller.currentStep?.roadName ??
                  _controller.nextStep?.roadName;
              unawaited(
                _trafficController.selectRoadAt(
                  point,
                  zoom: _mapController.zoom,
                  fallbackRoadName: fallbackName,
                ),
              );
            }
          },
          onIncidentTap: _trafficController.selectIncident,
          onFallbackTriggered: () {
            if (!mounted) return;
            setState(() {
              _is3dEnabled = false;
            });
          },
        );
      },
    );
  }

  void _zoomIn() {
    if (!_isMapReady) return;
    _isUserGesturing = false;
    _userAdjustedZoom = true;
    final cam = _mapController.camera;
    final currentZoom = cam?.zoom ?? _mapController.zoom;
    if (currentZoom < 22.0) {
      unawaited(
        _mapController.animateCamera(
          center: cam?.center,
          zoom: math.min(22.0, currentZoom + 1.0),
          bearingDeg: cam?.bearingDeg,
          pitchDeg: _targetNavigationPitch(),
          padding: _cameraFollowPadding(),
          duration: const Duration(milliseconds: 260),
          force: true,
        ),
      );
    }
  }

  void _zoomOut() {
    if (!_isMapReady) return;
    _isUserGesturing = false;
    _userAdjustedZoom = true;
    final cam = _mapController.camera;
    final currentZoom = cam?.zoom ?? _mapController.zoom;
    if (currentZoom > 3.0) {
      unawaited(
        _mapController.animateCamera(
          center: cam?.center,
          zoom: math.max(3.0, currentZoom - 1.0),
          bearingDeg: cam?.bearingDeg,
          pitchDeg: _targetNavigationPitch(),
          padding: _cameraFollowPadding(),
          duration: const Duration(milliseconds: 260),
          force: true,
        ),
      );
    }
  }

  void _openReportIncident() {
    final cur = _controller.snappedLocation ??
        _controller.currentLocation ??
        _mapController.camera?.center ??
        _controller.destination ??
        const LatLng(-7.2575, 112.7521);
    final roadName = _controller.currentStep?.roadName ??
        _controller.nextStep?.roadName;
    showRoadIncidentReportSheet(
      context: context,
      controller: _trafficController,
      courierLocation: cur,
      currentRoadName: roadName,
    );
  }

  Future<void> _confirmCancelNavigation() async {
    final confirmed = await showEndNavigationConfirmDialog(
      context,
      targetLabel: _controller.phase == NavigationPhase.pickup
          ? 'lokasi pengirim'
          : 'lokasi penerima',
    );
    if (!confirmed || !mounted) return;
    _arrivalRedirector.cancel();
    _controller.stopTracking();
    _trafficController.setMapActive(false);
    Navigator.pop(context);
  }

  void _showSummary() {
    final routeTraffic = _trafficController.routeAnalysis;
    final closest = _trafficController.closestCongestion;
    final delaySec = routeTraffic?.estimatedDelaySeconds;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
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
            if (routeTraffic != null) ...[
              _summaryRow('Kondisi lalu lintas', routeTraffic.overallStatusLabel),
              if (closest != null)
                _summaryRow(
                  'Kemacetan terdekat',
                  '${closest.roadName ?? 'Jalur aktif'} (${closest.formattedDistance})',
                ),
              if (delaySec != null && delaySec >= 30)
                _summaryRow(
                  'Perkiraan keterlambatan',
                  '+${(delaySec / 60.0).ceil()} menit',
                ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _openRouteAlternatives();
                },
                icon: const Icon(Icons.alt_route_rounded, size: 19),
                label: const Text('Bandingkan Rute Alternatif (TomTom Traffic)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F7B4A),
                  side: const BorderSide(color: Color(0xFF0F7B4A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetCtx),
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
    final isSoundEnabled = _controller.soundEnabled;
    final isHeadingUp = _controller.isCompassHeadingUp;
    final overlayBottom = _bottomOverlayClearance();
    final isCameraLockedToNav = _isAutoCenter && isHeadingUp;
    final recenterAccent =
        isCameraLockedToNav ? const Color(0xFF0F172A) : AppColors.primaryOrange;

    return Positioned.fill(
      child: SafeArea(
        child: Stack(
          children: [
            // Bottom-left: Compact speed pill + 'Tengahkan' pill button
            Positioned(
              left: 16,
              bottom: overlayBottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          size: 15,
                          color: AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          speed,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          'km/j',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 0,
                    child: InkWell(
                      key: const Key('nav_recenter_button'),
                      onTap: _recenterCamera,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isCameraLockedToNav
                                ? const Color(0xFFE2E8F0)
                                : AppColors.primaryOrange,
                            width: isCameraLockedToNav ? 1.0 : 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.near_me_outlined,
                              size: 17,
                              color: recenterAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tengahkan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: recenterAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom-right: Dynamic Google Maps Compass, 2D/3D Tilt, Sound, Zoom, Incident
            Positioned(
              right: 16,
              bottom: overlayBottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: _mapBearingNotifier,
                    builder: (_, bearingDeg, _) {
                      final deltaNorth =
                          NavigationCameraMath.shortestAngleDeltaDeg(
                        0.0,
                        bearingDeg,
                      );
                      return NavigationCompassButton(
                        key: const Key('nav_compass_button'),
                        mapRotationDeg: -deltaNorth,
                        isAutoRotateActive: isHeadingUp,
                        onTap: _onCompassPressed,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  NavigationTiltToggleButton(
                    key: const Key('nav_tilt_toggle_button'),
                    is3dEnabled: _is3dEnabled,
                    onTap: _toggle3dTilt,
                  ),
                  const SizedBox(height: 6),
                  _mapFab(
                    isSoundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    _controller.toggleSound,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _zoomIn,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: const SizedBox(
                            width: 40,
                            height: 34,
                            child: Icon(
                              Icons.add,
                              size: 19,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          height: 1,
                          width: 24,
                          color: const Color(0xFFE2E8F0),
                        ),
                        InkWell(
                          onTap: _zoomOut,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20),
                          ),
                          child: const SizedBox(
                            width: 40,
                            height: 34,
                            child: Icon(
                              Icons.remove,
                              size: 19,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _mapFab(
                    Icons.warning_amber_rounded,
                    _openReportIncident,
                    color: AppColors.primaryOrange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color ?? const Color(0xFF0F172A), size: 20),
        ),
      ),
    );
  }

  // ------------------------------------------------------- header & banner

  Widget _buildHeader() {
    final currentStep = _controller.currentStep;
    final thenStep = _controller.thenStep;
    final fallbackInstruction = _controller.title;

    final distanceToShow = _controller.distanceToNextManeuver;
    final formattedDist =
        distanceToShow > 0 ? _formatDistance(distanceToShow) : '';

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationTurnBanner(
            key: const Key('nav_turn_banner'),
            currentStep: currentStep,
            thenStep: thenStep,
            fallbackInstruction: fallbackInstruction,
            distanceLabel: formattedDist,
          ),
          if (_controller.accuracyWarning) _buildAccuracyBanner(),
          if (_controller.status == NavigationStatus.offRoute ||
              _controller.status == NavigationStatus.rerouting)
            _buildOffRouteBanner(),
          if (_trafficController.isTrafficEnabled &&
              _trafficController.closestCongestion != null &&
              _dismissedAlertSignature !=
                  _trafficController.routeAnalysis?.routeSignature) ...[
            const SizedBox(height: 8),
            RouteCongestionAlertCard(
              alert: _trafficController.closestCongestion!,
              fasterAlternative:
                  _trafficController.alternativesResult?.recommendedRoute,
              onViewAlternativesTap: _openRouteAlternatives,
              onDismiss: () {
                setState(() {
                  _dismissedAlertSignature =
                      _trafficController.routeAnalysis?.routeSignature;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertBanner(String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            Icon(icon, color: AppColors.textWhite, size: 18),
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
          Row(
            children: [
              Expanded(
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
              const SizedBox(width: 8),
              CourierWhatsAppIconButton(
                key: const Key('nav_error_wa_button'),
                size: 48,
                iconSize: 21,
                tooltip: isPickup ? 'Chat WA Pengirim' : 'Chat WA Penerima',
                onTap: () => CourierContactHelper.openWhatsAppChat(
                  context,
                  phone: phone,
                  isSender: isPickup,
                  order: widget.order,
                ),
              ),
            ],
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
    final isPickup = c.phase == NavigationPhase.pickup;
    final phaseColor =
        isPickup ? AppColors.primaryOrange : const Color(0xFF0F7B4A);
    final phaseBg =
        isPickup ? const Color(0xFFFFF7ED) : const Color(0xFFE8F7EE);
    final targetName = isPickup ? _senderName : _receiverName;
    final targetAddress = isPickup ? _pickupAddress : _dropoffAddress;
    final phone = isPickup ? _senderPhone : _receiverPhone;
    final closestCongestion = _trafficController.isTrafficEnabled
        ? _trafficController.closestCongestion
        : null;
    final hasAltAlert = _trafficController.isTrafficEnabled &&
        (_trafficController.alternativesResult?.hasFasterAlternative == true ||
            closestCongestion != null);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -150 && !_isBottomSheetExpanded) {
            setState(() => _isBottomSheetExpanded = true);
          } else if (v > 150 && _isBottomSheetExpanded) {
            setState(() => _isBottomSheetExpanded = false);
          }
        },
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              18,
              8,
              18,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 20,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle (tap to toggle order details)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(
                    () => _isBottomSheetExpanded = !_isBottomSheetExpanded,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 2),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Compact Image-1 Style Navigation Bar: [X]  ETA/km  [Alt Route]
                Row(
                  children: [
                    Tooltip(
                      message: 'Akhiri Navigasi',
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('nav_exit_button'),
                          onTap: _confirmCancelNavigation,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF0F172A),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        key: const Key('nav_bottom_eta_toggle'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(
                          () =>
                              _isBottomSheetExpanded = !_isBottomSheetExpanded,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatDuration(
                                    c.durationRemainingSeconds ?? 0,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF0F7B4A),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  closestCongestion != null
                                      ? Icons.warning_amber_rounded
                                      : Icons.eco_rounded,
                                  size: 16,
                                  color: closestCongestion?.color ??
                                      const Color(0xFF16A34A),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_formatDistance(c.distanceRemaining)} • ${_formatTime(c.eta)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _isBottomSheetExpanded
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                  size: 16,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Rute Alternatif',
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('nav_alternatives_button'),
                          onTap: _openRouteAlternatives,
                          onLongPress: _showSummary,
                          customBorder: const CircleBorder(),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.alt_route_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 22,
                                ),
                              ),
                              if (hasAltAlert)
                                Positioned(
                                  top: 1,
                                  right: 1,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: (_trafficController
                                                  .alternativesResult
                                                  ?.hasFasterAlternative ==
                                              true)
                                          ? const Color(0xFF16A34A)
                                          : closestCongestion!.color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Expandable City Courier Order Details
                if (_isBottomSheetExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: phaseBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: phaseColor,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                c.title,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: phaseColor,
                                ),
                              ),
                            ),
                            Text(
                              _orderTrackingNumber,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((step?.roadName ?? '').isNotEmpty)
                        Flexible(
                          child: Text(
                            step!.roadName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPickup
                              ? Icons.inventory_2_outlined
                              : Icons.location_on,
                          color: AppColors.primaryOrange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPickup
                                  ? 'Titik Penjemputan:'
                                  : 'Titik Pengantaran:',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              targetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              targetAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _call(phone),
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.phone,
                              color: AppColors.primaryOrange,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ChatOrderIconButton(
                        key: const Key('nav_internal_chat_button'),
                        size: 40,
                        iconSize: 18,
                        isCircular: true,
                        tooltip: 'Chat Dalam Aplikasi',
                        onTap: () => ChatLaunchHelper.openOrderChat(
                          context,
                          orderIdentifier: ChatLaunchHelper.extractOrderIdentifier(
                            widget.order,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CourierWhatsAppIconButton(
                        key: const Key('nav_wa_button'),
                        size: 40,
                        iconSize: 19,
                        tooltip: isPickup
                            ? 'Chat WA Pengirim'
                            : 'Chat WA Penerima',
                        onTap: () => CourierContactHelper.openWhatsAppChat(
                          context,
                          phone:
                              phone ??
                              (isPickup
                                  ? CourierContactHelper.extractSenderPhone(
                                      widget.order,
                                    )
                                  : CourierContactHelper.extractReceiverPhone(
                                      widget.order,
                                    )),
                          isSender: isPickup,
                          order: widget.order,
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
          10,
          20,
          MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            const SizedBox(height: 4),
            Text(
              'Mengalihkan otomatis ke halaman berikutnya...',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (phone != null) ...[
                  CourierWhatsAppIconButton(
                    key: const Key('nav_arrived_wa_button'),
                    size: 50,
                    iconSize: 21,
                    tooltip: isPickup
                        ? 'Chat WA Pengirim'
                        : 'Chat WA Penerima',
                    onTap: () => CourierContactHelper.openWhatsAppChat(
                      context,
                      phone: phone,
                      isSender: isPickup,
                      order: widget.order,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                    onPressed: _arrivalRedirector.isTriggered
                        ? null
                        : _confirmArrival,
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
              onPressed: () {
                _arrivalRedirector.cancel();
                _controller.stopTracking();
                _trafficController.setMapActive(false);
                Navigator.pop(context);
              },
              child: const Text('Tutup Navigasi'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- formatters

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
