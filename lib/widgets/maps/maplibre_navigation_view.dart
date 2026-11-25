import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';
import 'package:city_courierapp/widgets/maps/maplibre_navigation_style.dart';
import 'package:city_courierapp/widgets/maps/navigation_camera_controller.dart';

/// Snapshot kamera peta aktif dari renderer MapLibre 3D.
@immutable
class NavigationMapCameraState {
  final LatLng center;
  final double zoom;
  final double bearingDeg;
  final double pitchDeg;

  const NavigationMapCameraState({
    required this.center,
    required this.zoom,
    required this.bearingDeg,
    required this.pitchDeg,
  });
}

/// Controller imperatif untuk menggerakkan kamera [NavigationMapLibreView]
/// dengan halus tanpa menyebabkan rebuild widget peta.
class NavigationMapLibreController extends ChangeNotifier {
  ml.MapController? _mapController;
  ml.StyleController? _styleController;
  NavigationMapCameraState? _camera;
  bool _isReady = false;
  bool _has3dBuildings = false;
  bool _usingFallbackRaster = false;
  LatLngBounds? _visibleBounds;
  double? _lastAnimatedLat;
  double? _lastAnimatedLng;
  double? _lastAnimatedZoom;
  double? _lastAnimatedBearing;
  double? _lastAnimatedPitch;
  EdgeInsets? _lastAnimatedPadding;

  bool get isReady => _isReady;
  bool get has3dBuildings => _has3dBuildings;
  bool get usingFallbackRaster => _usingFallbackRaster;
  NavigationMapCameraState? get camera => _camera;
  LatLngBounds? get visibleBounds => _visibleBounds;
  double get bearingDeg => _camera?.bearingDeg ?? 0.0;
  double get pitchDeg => _camera?.pitchDeg ?? 0.0;
  double get zoom => _camera?.zoom ?? NavigationCameraMath.defaultNavZoom;

  void attach({
    required ml.MapController mapController,
    NavigationMapCameraState? initialCamera,
  }) {
    _mapController = mapController;
    if (initialCamera != null) {
      _camera = initialCamera;
    }
    _isReady = true;
    notifyListeners();
  }

  void markStyleLoaded({
    required ml.StyleController styleController,
    required bool has3dBuildings,
    required bool usingFallbackRaster,
  }) {
    _styleController = styleController;
    _has3dBuildings = has3dBuildings;
    _usingFallbackRaster = usingFallbackRaster;
    _refreshVisibleBounds();
    notifyListeners();
  }

  void updateCameraFromEvent(ml.MapCamera mlCamera) {
    _camera = NavigationMapCameraState(
      center: LatLng(mlCamera.center.lat, mlCamera.center.lon),
      zoom: mlCamera.zoom,
      bearingDeg: NavigationCameraMath.normalizeAngleDeg(mlCamera.bearing),
      pitchDeg: mlCamera.pitch,
    );
    _refreshVisibleBounds();
    notifyListeners();
  }

  void _refreshVisibleBounds() {
    final ctrl = _mapController;
    if (ctrl == null) return;
    try {
      final b = ctrl.getVisibleRegion();
      _visibleBounds = LatLngBounds(
        LatLng(b.latitudeSouth, b.longitudeWest),
        LatLng(b.latitudeNorth, b.longitudeEast),
      );
    } catch (_) {}
  }

  /// Menganimasikan kamera MapLibre dengan interpolasi native dan filter mikro
  /// agar GPS jitter tidak membuat kamera bergetar.
  Future<void> animateCamera({
    LatLng? center,
    double? zoom,
    double? bearingDeg,
    double? pitchDeg,
    EdgeInsets padding = EdgeInsets.zero,
    Duration duration = const Duration(milliseconds: 420),
    bool immediate = false,
    bool force = false,
  }) async {
    final ctrl = _mapController;
    if (ctrl == null) return;

    final targetCenter = center ?? _camera?.center;
    final targetZoom = zoom ?? _camera?.zoom;
    final targetBearing = bearingDeg != null
        ? NavigationCameraMath.normalizeAngleDeg(bearingDeg)
        : null;
    final targetPitch = pitchDeg?.clamp(0.0, 60.0);

    if (!force && !immediate) {
      final prevLat = _lastAnimatedLat ?? _camera?.center.latitude;
      final prevLng = _lastAnimatedLng ?? _camera?.center.longitude;
      final prevZoom = _lastAnimatedZoom ?? _camera?.zoom ?? 17.0;
      final prevBearing =
          _lastAnimatedBearing ?? _camera?.bearingDeg ?? 0.0;
      final prevPitch = _lastAnimatedPitch ?? _camera?.pitchDeg ?? 0.0;

      final distMeters = (targetCenter != null &&
              prevLat != null &&
              prevLng != null)
          ? const Distance().as(
              LengthUnit.Meter,
              LatLng(prevLat, prevLng),
              targetCenter,
            )
          : 0.0;
      final deltaBearing = targetBearing != null
          ? NavigationCameraMath.shortestAngleDeltaDeg(
              prevBearing,
              targetBearing,
            ).abs()
          : 0.0;
      final deltaZoom =
          targetZoom != null ? (targetZoom - prevZoom).abs() : 0.0;
      final deltaPitch =
          targetPitch != null ? (targetPitch - prevPitch).abs() : 0.0;
      final samePadding = _lastAnimatedPadding == padding;

      if (distMeters < 0.6 &&
          deltaBearing < 1.2 &&
          deltaZoom < 0.02 &&
          deltaPitch < 0.5 &&
          samePadding) {
        return;
      }
    }

    if (targetCenter != null) {
      _lastAnimatedLat = targetCenter.latitude;
      _lastAnimatedLng = targetCenter.longitude;
    }
    if (targetZoom != null) _lastAnimatedZoom = targetZoom;
    if (targetBearing != null) _lastAnimatedBearing = targetBearing;
    if (targetPitch != null) _lastAnimatedPitch = targetPitch;
    _lastAnimatedPadding = padding;

    final geo = targetCenter != null
        ? ml.Geographic(
            lon: targetCenter.longitude,
            lat: targetCenter.latitude,
          )
        : null;

    try {
      if (immediate) {
        await ctrl.moveCamera(
          center: geo,
          zoom: targetZoom,
          bearing: targetBearing,
          pitch: targetPitch,
          padding: padding,
        );
      } else {
        await ctrl
            .animateCamera(
              center: geo,
              zoom: targetZoom,
              bearing: targetBearing,
              pitch: targetPitch,
              padding: padding,
              nativeDuration: duration,
            )
            // Pembatalan wajar saat update GPS berikutnya tiba lebih cepat.
            .catchError((_) {});
      }
      _camera = NavigationMapCameraState(
        center: targetCenter ?? _camera?.center ?? const LatLng(-7.2575, 112.7521),
        zoom: targetZoom ?? _camera?.zoom ?? NavigationCameraMath.defaultNavZoom,
        bearingDeg: targetBearing ?? _camera?.bearingDeg ?? 0.0,
        pitchDeg: targetPitch ?? _camera?.pitchDeg ?? 0.0,
      );
      _refreshVisibleBounds();
    } catch (_) {}
  }

  /// Mengubah style ke fallback OSM bila style OpenFreeMap utama gagal dimuat.
  void switchToFallbackStyle() {
    final ctrl = _mapController;
    if (ctrl == null || _usingFallbackRaster) return;
    _usingFallbackRaster = true;
    try {
      ctrl.setStyle(MapLibreNavigationStyle.osmRasterFallbackStyleJson);
    } catch (_) {}
  }

  ml.StyleController? get styleController => _styleController;

  @override
  void dispose() {
    _mapController = null;
    _styleController = null;
    super.dispose();
  }
}

/// Renderer peta navigasi 3D berbasis [ml.MapLibreMap] + Vector Tiles OSM.
///
/// Menjaga layer GeoJSON rute dan lalu lintas TomTom selalu berada di atas
/// bangunan 3D (`FillExtrusionStyleLayer`), serta merender marker kendaraan &
/// tujuan via `WidgetLayer` agar tidak pernah tertutup gedung tinggi.
class NavigationMapLibreView extends StatefulWidget {
  final NavigationMapLibreController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final double initialBearingDeg;
  final double initialPitchDeg;
  final List<LatLng> routeCoordinates;
  final List<RouteTrafficSegment> routeTrafficSegments;
  final bool trafficEnabled;
  final List<TrafficIncident> incidents;
  final TrafficFlowSegment? selectedRoad;
  final LatLng? courierLocation;
  final double vehicleHeadingDeg;
  final LatLng? pickupLocation;
  final LatLng? destination;
  final NavigationPhase phase;
  final VoidCallback onMapReady;
  final VoidCallback onUserGestureStart;
  final ValueChanged<NavigationMapCameraState> onCameraChanged;
  final VoidCallback? onCameraIdle;
  final ValueChanged<LatLng> onMapTap;
  final ValueChanged<TrafficIncident> onIncidentTap;
  final VoidCallback? onFallbackTriggered;

  const NavigationMapLibreView({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    required this.initialBearingDeg,
    required this.initialPitchDeg,
    required this.routeCoordinates,
    required this.routeTrafficSegments,
    required this.trafficEnabled,
    required this.incidents,
    required this.selectedRoad,
    required this.courierLocation,
    required this.vehicleHeadingDeg,
    required this.pickupLocation,
    required this.destination,
    required this.phase,
    required this.onMapReady,
    required this.onUserGestureStart,
    required this.onCameraChanged,
    this.onCameraIdle,
    required this.onMapTap,
    required this.onIncidentTap,
    this.onFallbackTriggered,
  });

  @override
  State<NavigationMapLibreView> createState() =>
      _NavigationMapLibreViewState();
}

class _NavigationMapLibreViewState extends State<NavigationMapLibreView> {
  ml.StyleController? _styleController;
  Timer? _styleLoadWatchdog;
  bool _layersInitialized = false;
  bool _isFallbackStyleLoaded = false;

  late String _routeGeoJson;
  late String _routeTrafficGeoJson;
  late String _incidentsGeoJson;
  late String _selectedRoadGeoJson;

  double? _unwrappedDriverTurns;

  @override
  void initState() {
    super.initState();
    _recomputeGeoJson();
    _startStyleWatchdog();
  }

  @override
  void didUpdateWidget(covariant NavigationMapLibreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prevRoute = _routeGeoJson;
    final prevTraffic = _routeTrafficGeoJson;
    final prevIncidents = _incidentsGeoJson;
    final prevSelected = _selectedRoadGeoJson;

    _recomputeGeoJson();

    final style = _styleController;
    if (style != null &&
        _layersInitialized &&
        (prevRoute != _routeGeoJson ||
            prevTraffic != _routeTrafficGeoJson ||
            prevIncidents != _incidentsGeoJson ||
            prevSelected != _selectedRoadGeoJson)) {
      unawaited(
        MapLibreNavigationStyle.syncGeoJsonSources(
          style: style,
          routeGeoJson: _routeGeoJson,
          routeTrafficGeoJson: _routeTrafficGeoJson,
          incidentsGeoJson: _incidentsGeoJson,
          selectedRoadGeoJson: _selectedRoadGeoJson,
        ).catchError((_) {}),
      );
    }
  }

  void _startStyleWatchdog() {
    _styleLoadWatchdog?.cancel();
    _styleLoadWatchdog = Timer(const Duration(seconds: 9), () {
      if (!mounted || _layersInitialized || _isFallbackStyleLoaded) return;
      _isFallbackStyleLoaded = true;
      widget.onFallbackTriggered?.call();
      widget.mapController.switchToFallbackStyle();
    });
  }

  void _recomputeGeoJson() {
    _routeGeoJson =
        MapLibreNavigationStyle.buildRouteGeoJson(widget.routeCoordinates);
    _routeTrafficGeoJson = MapLibreNavigationStyle.buildRouteTrafficGeoJson(
      coordinates: widget.routeCoordinates,
      segments: widget.routeTrafficSegments,
      trafficEnabled: widget.trafficEnabled,
    );
    _incidentsGeoJson = MapLibreNavigationStyle.buildIncidentsGeoJson(
      incidents: widget.incidents,
      trafficEnabled: widget.trafficEnabled,
    );
    _selectedRoadGeoJson = MapLibreNavigationStyle.buildSelectedRoadGeoJson(
      selectedRoad: widget.selectedRoad,
      trafficEnabled: widget.trafficEnabled,
    );
  }

  @override
  void dispose() {
    _styleLoadWatchdog?.cancel();
    super.dispose();
  }

  void _handleMapEvent(ml.MapEvent event) {
    switch (event) {
      case ml.MapEventMapCreated():
        widget.mapController.attach(
          mapController: event.mapController,
          initialCamera: NavigationMapCameraState(
            center: widget.initialCenter,
            zoom: widget.initialZoom,
            bearingDeg: widget.initialBearingDeg,
            pitchDeg: widget.initialPitchDeg,
          ),
        );
        widget.onMapReady();
      case ml.MapEventStyleLoaded():
        _styleLoadWatchdog?.cancel();
        _styleController = event.style;
        unawaited(_initializeLayers(event.style));
      case ml.MapEventStartMoveCamera():
        if (event.reason == ml.CameraChangeReason.apiGesture) {
          widget.onUserGestureStart();
        }
      case ml.MapEventMoveCamera():
        widget.mapController.updateCameraFromEvent(event.camera);
        final updated = widget.mapController.camera;
        if (updated != null) {
          widget.onCameraChanged(updated);
        }
      case ml.MapEventCameraIdle():
      case ml.MapEventIdle():
        widget.onCameraIdle?.call();
      case ml.MapEventClick():
        widget.onMapTap(LatLng(event.point.lat, event.point.lon));
      default:
        break;
    }
  }

  Future<void> _initializeLayers(ml.StyleController style) async {
    _recomputeGeoJson();
    try {
      final has3d = await MapLibreNavigationStyle.setupNavigationStyleLayers(
        style: style,
        routeGeoJson: _routeGeoJson,
        routeTrafficGeoJson: _routeTrafficGeoJson,
        incidentsGeoJson: _incidentsGeoJson,
        selectedRoadGeoJson: _selectedRoadGeoJson,
        enable3dBuildings: !_isFallbackStyleLoaded,
      );
      _layersInitialized = true;
      widget.mapController.markStyleLoaded(
        styleController: style,
        has3dBuildings: has3d,
        usingFallbackRaster: _isFallbackStyleLoaded,
      );
    } catch (e) {
      debugPrint('Failed initializing MapLibre navigation layers: $e');
    }
  }

  List<ml.Marker> _buildPassiveMarkers() {
    final markers = <ml.Marker>[];
    final pickup = widget.pickupLocation;
    final dest = widget.destination;

    if (pickup != null && widget.phase == NavigationPhase.delivery) {
      markers.add(
        ml.Marker(
          point: ml.Geographic(lon: pickup.longitude, lat: pickup.latitude),
          size: const Size(104, 82),
          alignment: Alignment.bottomCenter,
          rotate: false,
          flat: false,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _markerBadge(
              icon: Icons.inventory_2_outlined,
              color: AppColors.primaryBlue,
              label: 'Jemput',
            ),
          ),
        ),
      );
    }

    if (dest != null) {
      final isPickup = widget.phase == NavigationPhase.pickup;
      markers.add(
        ml.Marker(
          point: ml.Geographic(lon: dest.longitude, lat: dest.latitude),
          size: const Size(104, 82),
          alignment: Alignment.bottomCenter,
          rotate: false,
          flat: false,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _markerBadge(
              icon: isPickup ? Icons.inventory_2_outlined : Icons.home_outlined,
              color: AppColors.primaryOrange,
              label: isPickup ? 'Pengirim' : 'Penerima',
            ),
          ),
        ),
      );
    }

    final courier = widget.courierLocation;
    if (courier != null) {
      markers.add(
        ml.Marker(
          point: ml.Geographic(lon: courier.longitude, lat: courier.latitude),
          size: const Size(84, 84),
          alignment: Alignment.center,
          rotate: false,
          flat: false,
          child: Builder(
            builder: (context) {
              final mapCam = ml.MapCamera.maybeOf(context);
              final mapBearing = mapCam?.bearing ?? 0.0;
              final relativeDeg = NavigationCameraMath.normalizeAngleDeg(
                widget.vehicleHeadingDeg - mapBearing,
              );
              _unwrappedDriverTurns = NavigationCameraMath.unwrapTurns(
                _unwrappedDriverTurns,
                relativeDeg,
              );
              final turns = _unwrappedDriverTurns! + 0.90;
              return AnimatedRotation(
                turns: turns,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Image.asset(
                  'assets/Icon/Kurir.png',
                  width: 78,
                  height: 78,
                ),
              );
            },
          ),
        ),
      );
    }

    return markers;
  }

  List<ml.Marker> _buildInteractiveIncidentMarkers() {
    if (!widget.trafficEnabled || widget.incidents.isEmpty) {
      return const [];
    }
    return [
      for (final inc in widget.incidents)
        ml.Marker(
          point: ml.Geographic(
            lon: inc.point.longitude,
            lat: inc.point.latitude,
          ),
          size: const Size(34, 34),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => widget.onIncidentTap(inc),
            child: Container(
              decoration: BoxDecoration(
                color: inc.markerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(inc.iconData, color: Colors.white, size: 18),
            ),
          ),
        ),
    ];
  }

  Widget _markerBadge({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
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
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.textWhite, size: 18),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final passiveMarkers = _buildPassiveMarkers();
    final incidentMarkers = _buildInteractiveIncidentMarkers();

    return ml.MapLibreMap(
      options: ml.MapOptions(
        initStyle: MapLibreNavigationStyle.openFreeMapLibertyStyleUrl,
        initCenter: ml.Geographic(
          lon: widget.initialCenter.longitude,
          lat: widget.initialCenter.latitude,
        ),
        initZoom: widget.initialZoom,
        initBearing: widget.initialBearingDeg,
        initPitch: widget.initialPitchDeg,
        minZoom: 3.0,
        maxZoom: 22.0,
        minPitch: 0.0,
        maxPitch: 60.0,
        gestures: const ml.MapGestures.all(),
        androidMode: ml.AndroidPlatformViewMode.tlhc_vd,
        androidTextureMode: true,
      ),
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      onEvent: _handleMapEvent,
      children: [
        if (passiveMarkers.isNotEmpty)
          ml.WidgetLayer(
            markers: passiveMarkers,
            allowInteraction: false,
          ),
        if (incidentMarkers.isNotEmpty)
          ml.WidgetLayer(
            markers: incidentMarkers,
            allowInteraction: true,
          ),
      ],
    );
  }
}
