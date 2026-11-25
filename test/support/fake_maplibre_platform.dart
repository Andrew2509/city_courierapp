import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// In-memory fake implementation of [StyleController] for headless widget tests
/// verifying MapLibre 3D building extrusions, GeoJSON route/traffic sources, and
/// layer z-ordering without requiring an Android OpenGL surface.
class FakeStyleController extends StyleController {
  final List<String> _layerIds = [
    'background',
    'road-primary',
    'building',
    'building-3d',
    'highway-name-minor',
  ];
  final Map<String, Source> sources = {};
  final List<StyleLayer> addedLayers = [];
  final List<String> removedLayers = [];
  final Map<String, String> updatedGeoJson = {};

  @override
  Future<void> addImage(String id, Uint8List bytes) async {}

  @override
  Future<void> removeImage(String id) async {}

  @override
  Future<void> addLayer(
    StyleLayer layer, {
    String? belowLayerId,
    String? aboveLayerId,
    int? atIndex,
  }) async {
    addedLayers.add(layer);
    if (belowLayerId != null && _layerIds.contains(belowLayerId)) {
      _layerIds.insert(_layerIds.indexOf(belowLayerId), layer.id);
    } else if (aboveLayerId != null && _layerIds.contains(aboveLayerId)) {
      _layerIds.insert(_layerIds.indexOf(aboveLayerId) + 1, layer.id);
    } else if (atIndex != null && atIndex >= 0 && atIndex <= _layerIds.length) {
      _layerIds.insert(atIndex, layer.id);
    } else {
      _layerIds.add(layer.id);
    }
  }

  @override
  Future<void> addSource(Source source) async {
    sources[source.id] = source;
    if (source is GeoJsonSource) {
      updatedGeoJson[source.id] = source.data;
    }
  }

  @override
  void dispose() {}

  @override
  Future<List<String>> getAttributions() async => getAttributionsSync();

  @override
  List<String> getAttributionsSync() => const [
    '<a href="https://openfreemap.org">OpenFreeMap</a>',
    '<a href="https://openstreetmap.org/copyright">© OpenStreetMap</a>',
  ];

  @override
  List<String> getLayerIds() => List<String>.unmodifiable(_layerIds);

  @override
  Future<void> removeLayer(String id) async {
    removedLayers.add(id);
    _layerIds.remove(id);
  }

  @override
  Future<void> removeSource(String id) async {
    sources.remove(id);
  }

  @override
  void setProjection(MapProjection projection) {}

  @override
  Future<void> updateGeoJsonSource({
    required String id,
    required String data,
  }) async {
    updatedGeoJson[id] = data;
  }

  List<List<double>> decodeFirstLineCoords(String sourceId) {
    final raw = updatedGeoJson[sourceId];
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) return const [];
    final geom = (features.first as Map)['geometry'] as Map;
    final coords = geom['coordinates'] as List<dynamic>? ?? const [];
    return coords
        .map(
          (c) => [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
        )
        .toList(growable: false);
  }
}

/// Recorded camera update call on [FakeMapLibreMapState].
class FakeCameraCall {
  final Geographic? center;
  final double? zoom;
  final double? bearing;
  final double? pitch;
  final EdgeInsets padding;
  final bool animated;

  const FakeCameraCall({
    this.center,
    this.zoom,
    this.bearing,
    this.pitch,
    required this.padding,
    required this.animated,
  });
}

/// Headless [MapLibreMapState] allowing full widget testing of
/// `DriverNavigationScreen` + `NavigationMapLibreView` camera pitch/bearing,
/// bottom-center padding projection, drag/rotate gestures, and layer setup.
class FakeMapLibreMapState extends MapLibreMapState {
  final FakeStyleController fakeStyle = FakeStyleController();
  final List<FakeCameraCall> cameraCalls = [];
  EdgeInsets lastPadding = EdgeInsets.zero;
  Size _viewportSize = const Size(400, 800);
  bool _disposed = false;

  @override
  StyleController? style;

  @override
  void initState() {
    super.initState();
    camera = MapCamera(
      center: options.initCenter ?? const Geographic(lon: 112.7521, lat: -7.2575),
      zoom: options.initZoom,
      bearing: options.initBearing,
      pitch: options.initPitch,
    );
    isInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      widget.onEvent?.call(MapEventMapCreated(mapController: this));
      widget.onMapCreated?.call(this);
      style = fakeStyle;
      widget.onEvent?.call(MapEventStyleLoaded(fakeStyle));
      widget.onStyleLoaded?.call(fakeStyle);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Simulates user 2-finger rotation gesture.
  void simulateUserRotate(double newBearingDeg) {
    final prev = camera!;
    final next = MapCamera(
      center: prev.center,
      zoom: prev.zoom,
      bearing: newBearingDeg,
      pitch: prev.pitch,
    );
    widget.onEvent?.call(
      const MapEventStartMoveCamera(reason: CameraChangeReason.apiGesture),
    );
    camera = next;
    widget.onEvent?.call(MapEventMoveCamera(camera: next));
    widget.onEvent?.call(const MapEventCameraIdle());
    if (mounted) setState(() {});
  }

  /// Simulates user pinch-zoom gesture.
  void simulateUserPinchZoom(double newZoom) {
    final prev = camera!;
    final next = MapCamera(
      center: prev.center,
      zoom: newZoom,
      bearing: prev.bearing,
      pitch: prev.pitch,
    );
    widget.onEvent?.call(
      const MapEventStartMoveCamera(reason: CameraChangeReason.apiGesture),
    );
    camera = next;
    widget.onEvent?.call(MapEventMoveCamera(camera: next));
    widget.onEvent?.call(const MapEventCameraIdle());
    if (mounted) setState(() {});
  }

  @override
  Widget buildPlatformWidget(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final pt = toLngLat(details.localPosition);
            widget.onEvent?.call(
              MapEventClick(point: pt, screenPoint: details.localPosition),
            );
          },
          onPanStart: (_) {
            widget.onEvent?.call(
              const MapEventStartMoveCamera(
                reason: CameraChangeReason.apiGesture,
              ),
            );
          },
          onPanUpdate: (details) {
            final prev = camera!;
            final next = MapCamera(
              center: Geographic(
                lon: prev.center.lon - details.delta.dx * 0.0001,
                lat: prev.center.lat + details.delta.dy * 0.0001,
              ),
              zoom: prev.zoom,
              bearing: prev.bearing,
              pitch: prev.pitch,
            );
            camera = next;
            widget.onEvent?.call(MapEventMoveCamera(camera: next));
            if (mounted) setState(() {});
          },
          onPanEnd: (_) {
            widget.onEvent?.call(const MapEventCameraIdle());
          },
          child: const SizedBox.expand(),
        );
      },
    );
  }

  @override
  Future<void> animateCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 2),
    double webSpeed = 1.2,
    Duration? webMaxDuration,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    lastPadding = padding;
    cameraCalls.add(
      FakeCameraCall(
        center: center,
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
        padding: padding,
        animated: true,
      ),
    );
    final prev = camera!;
    final next = MapCamera(
      center: center ?? prev.center,
      zoom: zoom ?? prev.zoom,
      bearing: bearing ?? prev.bearing,
      pitch: pitch ?? prev.pitch,
    );
    camera = next;
    widget.onEvent?.call(
      const MapEventStartMoveCamera(
        reason: CameraChangeReason.developerAnimation,
      ),
    );
    widget.onEvent?.call(MapEventMoveCamera(camera: next));
    widget.onEvent?.call(const MapEventCameraIdle());
    if (mounted) setState(() {});
  }

  @override
  Future<void> moveCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    lastPadding = padding;
    cameraCalls.add(
      FakeCameraCall(
        center: center,
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
        padding: padding,
        animated: false,
      ),
    );
    final prev = camera!;
    final next = MapCamera(
      center: center ?? prev.center,
      zoom: zoom ?? prev.zoom,
      bearing: bearing ?? prev.bearing,
      pitch: pitch ?? prev.pitch,
    );
    camera = next;
    widget.onEvent?.call(MapEventMoveCamera(camera: next));
    if (mounted) setState(() {});
  }

  @override
  Future<void> fitBounds({
    required LngLatBounds bounds,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 2),
    double webSpeed = 1.2,
    Duration? webMaxDuration,
    Offset offset = Offset.zero,
    double webMaxZoom = double.maxFinite,
    bool webLinear = false,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {}

  @override
  Future<void> enableLocation({
    Duration fastestInterval = const Duration(milliseconds: 750),
    Duration maxWaitTime = const Duration(seconds: 1),
    bool pulseFade = true,
    bool accuracyAnimation = true,
    bool compassAnimation = true,
    bool pulse = true,
    BearingRenderMode bearingRenderMode = BearingRenderMode.gps,
  }) async {}

  @override
  Future<void> trackLocation({
    bool trackLocation = true,
    BearingTrackMode trackBearing = BearingTrackMode.gps,
  }) async {}

  @override
  MapCamera getCamera() => camera!;

  @override
  List<RenderedFeature> featuresAtPoint(
    Offset point, {
    List<String>? layerIds,
  }) => const [];

  @override
  List<RenderedFeature> featuresInRect(
    Rect rect, {
    List<String>? layerIds,
  }) => const [];

  @override
  double getMetersPerPixelAtLatitude(double latitude) =>
      156543.03392 * math.cos(latitude * math.pi / 180.0) / math.pow(2, camera!.zoom);

  @override
  LngLatBounds getVisibleRegion() {
    final c = camera!.center;
    final span = 0.015 * math.pow(2, 16.0 - camera!.zoom);
    return LngLatBounds(
      longitudeWest: c.lon - span,
      longitudeEast: c.lon + span,
      latitudeSouth: c.lat - span,
      latitudeNorth: c.lat + span,
    );
  }

  @override
  List<QueriedLayer> queryLayers(Offset screenLocation) => const [];

  @override
  void setStyle(String style) {}

  @override
  Geographic toLngLat(Offset screenLocation) {
    final cam = camera!;
    final mpp = getMetersPerPixelAtLatitude(cam.center.lat);
    final originX =
        (_viewportSize.width + lastPadding.left - lastPadding.right) / 2.0;
    final originY =
        (_viewportSize.height + lastPadding.top - lastPadding.bottom) / 2.0;
    final dxMeters = (screenLocation.dx - originX) * mpp;
    final dyMeters = -(screenLocation.dy - originY) * mpp;
    return Geographic(
      lon: cam.center.lon + dxMeters / 111320.0,
      lat: cam.center.lat + dyMeters / 111320.0,
    );
  }

  @override
  List<Geographic> toLngLats(List<Offset> screenLocations) =>
      screenLocations.map(toLngLat).toList(growable: false);

  @override
  Offset toScreenLocation(Geographic lngLat) {
    final cam = camera!;
    final mpp = getMetersPerPixelAtLatitude(cam.center.lat);
    final originX =
        (_viewportSize.width + lastPadding.left - lastPadding.right) / 2.0;
    final originY =
        (_viewportSize.height + lastPadding.top - lastPadding.bottom) / 2.0;
    final dxMeters = (lngLat.lon - cam.center.lon) * 111320.0;
    final dyMeters = (lngLat.lat - cam.center.lat) * 111320.0;
    final rad = cam.bearing * math.pi / 180.0;
    final rx = dxMeters * math.cos(rad) - dyMeters * math.sin(rad);
    final ry = dxMeters * math.sin(rad) + dyMeters * math.cos(rad);
    return Offset(originX + rx / mpp, originY - ry / mpp);
  }

  @override
  List<Offset> toScreenLocations(List<Geographic> lngLats) =>
      lngLats.map(toScreenLocation).toList(growable: false);
}

/// Registered fake platform exposing [latestMapState] for test assertions.
class FakeMapLibrePlatform extends MapLibrePlatform {
  FakeMapLibreMapState? latestMapState;

  @override
  MapLibreMapState createWidgetState() {
    final state = FakeMapLibreMapState();
    latestMapState = state;
    return state;
  }

  @override
  bool get offlineManagerIsSupported => false;

  @override
  bool get permissionManagerIsSupported => false;

  @override
  bool get userLocationIsSupported => false;
}

/// Registers [FakeMapLibrePlatform] as `MapLibrePlatform.instance` and returns
/// the controller handle for inspecting style layers, camera, and gestures.
FakeMapLibrePlatform registerFakeMapLibrePlatform() {
  final platform = FakeMapLibrePlatform();
  MapLibrePlatform.instance = platform;
  return platform;
}
