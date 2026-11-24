import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/core/config/map_config.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';
import 'package:city_courierapp/services/maps/traffic_service.dart';

class _CachedIncidents {
  final LatLngBounds bounds;
  final TrafficIncidentsResult result;

  const _CachedIncidents({required this.bounds, required this.result});
}

/// State controller layer lalu lintas TomTom di atas peta OpenStreetMap.
///
/// Mengatur:
/// - Toggle aktif/nonaktif lapisan lalu lintas
/// - Pembaruan berkala (default 60 detik, dapat dikonfigurasi)
/// - Debounce saat user menggeser/zoom peta
/// - Deduplikasi request dan cache lokal berbatas TTL agar data kedaluwarsa tidak dianggap real-time
/// - Pause pembaruan saat layar peta tidak aktif
class TrafficController extends ChangeNotifier {
  final TrafficService _service;
  final Duration refreshInterval;

  bool _isTrafficEnabled;
  bool _isMapActive = true;
  bool _showLegend = false;
  bool _isLoadingIncidents = false;
  bool _isLoadingSegment = false;
  bool _isLoadingSummary = false;
  bool _isLoadingRouteTraffic = false;
  bool _isLoadingAlternatives = false;
  bool _routeMonitoringMode = false;
  bool _disposed = false;

  String? _errorMessage;
  TrafficErrorKind? _errorKind;
  String? _summaryError;
  String? _alternativesError;

  List<TrafficIncident> _incidents = const [];
  TrafficFlowSegment? _selectedRoad;
  TrafficIncident? _selectedIncident;
  DeliveryTrafficSummary? _deliverySummary;
  RouteTrafficAnalysis? _routeAnalysis;
  TrafficAlternativesResult? _alternativesResult;

  DateTime? _lastUpdatedAt;
  DateTime? _expiresAt;
  int _tileEpoch;

  LatLngBounds? _activeBounds;
  double _activeZoom = MapConfig.defaultZoom;

  Timer? _refreshTimer;
  Timer? _moveDebounceTimer;
  String? _inFlightIncidentsKey;
  String? _inFlightFlowKey;
  String? _inFlightRouteKey;
  String? _inFlightAltKey;

  String? _activeRouteSignature;
  List<LatLng> _activeRouteCoords = const [];
  LatLng? _latestCourierLocation;
  LatLng? _activeDestination;
  String _activeTravelMode = 'motorcycle';

  final Map<String, _CachedIncidents> _incidentsCache = {};
  final Map<String, TrafficFlowSegment> _flowCache = {};
  final Map<String, RouteTrafficAnalysis> _routeAnalysisCache = {};
  final Map<String, TrafficAlternativesResult> _alternativesCache = {};

  Map<String, String> _tileHeaders = const {};

  TrafficController({
    TrafficService? service,
    bool initialEnabled = true,
    bool? initialShowLegend,
    this.refreshInterval = MapConfig.trafficRefreshInterval,
  }) : _service = service ?? TrafficService(),
       _isTrafficEnabled = initialEnabled,
       _showLegend = initialShowLegend ?? initialEnabled,
       _tileEpoch = DateTime.now().millisecondsSinceEpoch ~/ 60000 {
    if (_isTrafficEnabled) {
      unawaited(_loadTileHeaders());
      if (_isMapActive) {
        _startRefreshTimer();
      }
    }
  }

  bool get isTrafficEnabled => _isTrafficEnabled;
  bool get isMapActive => _isMapActive;
  bool get showLegend => _showLegend;
  bool get isRouteNavigationMode => _routeMonitoringMode;
  bool get isLoading =>
      _isLoadingIncidents || _isLoadingSegment || _isLoadingRouteTraffic;
  bool get isLoadingSegment => _isLoadingSegment;
  bool get isLoadingSummary => _isLoadingSummary;
  bool get isLoadingRouteTraffic => _isLoadingRouteTraffic;
  bool get isLoadingAlternatives => _isLoadingAlternatives;

  String? get errorMessage => _errorMessage;
  TrafficErrorKind? get errorKind => _errorKind;
  String? get summaryError => _summaryError;
  String? get alternativesError => _alternativesError;

  RouteTrafficAnalysis? get routeAnalysis {
    final a = _routeAnalysis;
    if (a == null || a.isExpired) return null;
    return a;
  }

  List<RouteTrafficSegment> get routeSegments =>
      routeAnalysis?.segments ?? const [];

  RouteCongestionAlert? get closestCongestion =>
      routeAnalysis?.closestCongestion;

  TrafficAlternativesResult? get alternativesResult {
    final a = _alternativesResult;
    if (a == null || a.isExpired) return null;
    return a;
  }

  List<TrafficIncident> get incidents {
    if (_routeMonitoringMode) {
      return routeAnalysis?.incidents ?? const [];
    }
    return isDataExpired ? const [] : _incidents;
  }

  TrafficFlowSegment? get selectedRoad =>
      (_selectedRoad != null && !_selectedRoad!.isExpired) ? _selectedRoad : null;
  TrafficIncident? get selectedIncident =>
      isDataExpired ? null : _selectedIncident;
  DeliveryTrafficSummary? get deliverySummary => _deliverySummary;

  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  DateTime? get expiresAt => _expiresAt;
  int get tileEpoch => _tileEpoch;
  Map<String, String> get tileHeaders => _tileHeaders;

  bool get isDataExpired {
    final exp = _expiresAt;
    if (exp == null) return false;
    return DateTime.now().toUtc().isAfter(exp.toUtc());
  }

  bool get canRenderTrafficTiles =>
      _isTrafficEnabled &&
      !_routeMonitoringMode &&
      _tileHeaders.containsKey('Authorization') &&
      _errorKind != TrafficErrorKind.unconfigured &&
      _errorKind != TrafficErrorKind.disabled;

  Future<void> _loadTileHeaders() async {
    try {
      final h = await _service.tileHeaders();
      if (_disposed) return;
      _tileHeaders = h;
      _safeNotify();
    } catch (_) {}
  }

  Future<void> toggleTraffic() => setTrafficEnabled(!_isTrafficEnabled);

  Future<void> setTrafficEnabled(bool enabled) async {
    if (_isTrafficEnabled == enabled) return;
    _isTrafficEnabled = enabled;
    _showLegend = enabled;

    if (!enabled) {
      _stopRefreshTimer();
      _moveDebounceTimer?.cancel();
      _errorMessage = null;
      _errorKind = null;
      _selectedRoad = null;
      _selectedIncident = null;
      _safeNotify();
      return;
    }

    await _loadTileHeaders();
    if (_disposed) return;
    _bumpTileEpoch();
    _safeNotify();
    if (_isMapActive) {
      _startRefreshTimer();
      if ((_routeMonitoringMode && _activeRouteCoords.length >= 2) ||
          _activeBounds != null) {
        await refreshNow(force: true);
      }
    }
  }

  void toggleLegend() {
    _showLegend = !_showLegend;
    _safeNotify();
  }

  void setMapActive(bool active) {
    if (_isMapActive == active) return;
    _isMapActive = active;
    if (!active) {
      _stopRefreshTimer();
      _moveDebounceTimer?.cancel();
      return;
    }

    if (_isTrafficEnabled) {
      _startRefreshTimer();
      final hasRoute = _routeMonitoringMode && _activeRouteCoords.length >= 2;
      if ((hasRoute || _activeBounds != null) &&
          (isDataExpired || _lastUpdatedAt == null)) {
        unawaited(refreshNow());
      }
    }
  }

  void clearSelection() {
    _selectedRoad = null;
    _selectedIncident = null;
    _safeNotify();
  }

  void selectIncident(TrafficIncident incident) {
    _selectedRoad = null;
    _selectedIncident = incident;
    _safeNotify();
  }

  /// Dipanggil saat kamera peta berpindah. Memakai debounce agar tidak membanjiri API
  /// saat kurir menggeser atau melakukan zoom peta.
  void onViewportChanged(LatLngBounds bounds, double zoom) {
    _activeBounds = bounds;
    _activeZoom = zoom;

    if (!_isTrafficEnabled || !_isMapActive || _routeMonitoringMode) return;

    _moveDebounceTimer?.cancel();
    _moveDebounceTimer = Timer(MapConfig.trafficMapMoveDebounce, () {
      if (_disposed || !_isTrafficEnabled || !_isMapActive) return;
      unawaited(_fetchIncidentsForBounds(bounds));
    });
  }

  Future<void> refreshNow({bool force = false}) async {
    if (!_isTrafficEnabled || _disposed) return;
    if (_routeMonitoringMode && _activeRouteCoords.length >= 2) {
      await syncRouteTraffic(
        routeCoordinates: _activeRouteCoords,
        courierLocation: _latestCourierLocation,
        destination: _activeDestination,
        travelMode: _activeTravelMode,
        force: force,
      );
    } else {
      _bumpTileEpoch();
      final bounds = _activeBounds;
      if (bounds != null) {
        await _fetchIncidentsForBounds(bounds, force: force);
      }
    }
    final road = _selectedRoad;
    if (road != null) {
      await selectRoadAt(
        road.point,
        zoom: _activeZoom,
        fallbackRoadName: road.roadName,
        force: force,
      );
    }
  }

  /// Mengambil kondisi lalu lintas ruas jalan ketika kurir mengetuk peta OSM.
  Future<TrafficFlowSegment?> selectRoadAt(
    LatLng point, {
    double? zoom,
    String? fallbackRoadName,
    bool force = false,
  }) async {
    if (!_isTrafficEnabled || _disposed) return null;

    final clampedZoom = (zoom ?? _activeZoom).round().clamp(10, 19);
    final key =
        '${clampedZoom}_${point.latitude.toStringAsFixed(4)}_${point.longitude.toStringAsFixed(4)}';

    if (!force) {
      final cached = _flowCache[key];
      if (cached != null && !cached.isExpired) {
        _selectedIncident = null;
        _selectedRoad = (cached.roadName == null && fallbackRoadName != null)
            ? cached.copyWith(roadName: fallbackRoadName)
            : cached;
        _errorMessage = null;
        _errorKind = null;
        _safeNotify();
        return _selectedRoad;
      }
    }

    if (_inFlightFlowKey == key) return _selectedRoad;
    _inFlightFlowKey = key;
    _isLoadingSegment = true;
    _selectedIncident = null;
    _safeNotify();

    try {
      var seg = await _service.getFlowSegment(
        point: point,
        zoom: clampedZoom,
        includeRoadName: true,
      );
      if (seg.roadName == null &&
          fallbackRoadName != null &&
          fallbackRoadName.trim().isNotEmpty) {
        seg = seg.copyWith(roadName: fallbackRoadName.trim());
      }
      if (_disposed) return null;

      _flowCache[key] = seg;
      _selectedRoad = seg;
      _lastUpdatedAt = seg.fetchedAt;
      _expiresAt = seg.expiresAt;
      _errorMessage = null;
      _errorKind = null;
      return seg;
    } on TrafficApiException catch (e) {
      if (_disposed) return null;
      _errorMessage = e.message;
      _errorKind = e.kind;
      return null;
    } finally {
      _inFlightFlowKey = null;
      _isLoadingSegment = false;
      _safeNotify();
    }
  }

  Future<DeliveryTrafficSummary?> loadDeliverySummary({
    required LatLng pickup,
    required LatLng dropoff,
    String? pickupRoadHint,
    String? dropoffRoadHint,
    bool force = false,
  }) async {
    if (!force && _deliverySummary != null && !_deliverySummary!.isExpired) {
      return _deliverySummary;
    }

    _isLoadingSummary = true;
    _summaryError = null;
    _safeNotify();

    try {
      final summary = await _service.getDeliverySummary(
        pickup: pickup,
        dropoff: dropoff,
        pickupRoadHint: pickupRoadHint,
        dropoffRoadHint: dropoffRoadHint,
      );
      if (_disposed) return null;
      _deliverySummary = summary;
      if (_incidents.isEmpty && summary.incidents.isNotEmpty) {
        _incidents = summary.incidents;
        _lastUpdatedAt = summary.fetchedAt;
        _expiresAt = summary.expiresAt;
      }
      return summary;
    } on TrafficApiException catch (e) {
      if (_disposed) return null;
      _summaryError = e.message;
      return null;
    } finally {
      _isLoadingSummary = false;
      _safeNotify();
    }
  }

  Future<void> _fetchIncidentsForBounds(
    LatLngBounds rawBounds, {
    bool force = false,
  }) async {
    if (!_isTrafficEnabled || !_isMapActive || _disposed) return;

    final clampedBounds = _clampBoundsSpan(rawBounds, maxSpanDeg: 0.6);
    final cacheKey = _bboxKey(clampedBounds);

    if (!force) {
      final exact = _incidentsCache[cacheKey];
      if (exact != null && !exact.result.isExpired) {
        _incidents = exact.result.incidents;
        _lastUpdatedAt = exact.result.fetchedAt;
        _expiresAt = exact.result.expiresAt;
        _errorMessage = null;
        _errorKind = null;
        _safeNotify();
        return;
      }

      // Cek apakah area baru masih berada di dalam cache bbox yang masih segar
      for (final entry in _incidentsCache.values) {
        if (!entry.result.isExpired &&
            _containsBounds(entry.bounds, clampedBounds)) {
          _incidents = entry.result.incidents;
          _lastUpdatedAt = entry.result.fetchedAt;
          _expiresAt = entry.result.expiresAt;
          _errorMessage = null;
          _errorKind = null;
          _safeNotify();
          return;
        }
      }
    }

    if (_inFlightIncidentsKey == cacheKey) return;
    _inFlightIncidentsKey = cacheKey;
    _isLoadingIncidents = true;
    _safeNotify();

    try {
      final res = await _service.getIncidents(bounds: clampedBounds);
      if (_disposed) return;

      _evictExpiredCaches();
      _incidentsCache[cacheKey] = _CachedIncidents(
        bounds: clampedBounds,
        result: res,
      );
      _incidents = res.incidents;
      _lastUpdatedAt = res.fetchedAt;
      _expiresAt = res.expiresAt;
      _errorMessage = null;
      _errorKind = null;
    } on TrafficApiException catch (e) {
      if (_disposed) return;
      _errorMessage = e.message;
      _errorKind = e.kind;
    } finally {
      _inFlightIncidentsKey = null;
      _isLoadingIncidents = false;
      _safeNotify();
    }
  }

  void _startRefreshTimer() {
    _stopRefreshTimer();
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      if (_disposed || !_isTrafficEnabled || !_isMapActive) return;
      unawaited(refreshNow(force: true));
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _bumpTileEpoch() {
    _tileEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  void _evictExpiredCaches() {
    _incidentsCache.removeWhere((_, v) => v.result.isExpired);
    _flowCache.removeWhere((_, v) => v.isExpired);
    _routeAnalysisCache.removeWhere((_, v) => v.isExpired);
    _alternativesCache.removeWhere((_, v) => v.isExpired);
  }

  /// Sinkronkan kondisi lalu lintas KHUSUS di sepanjang jalur rute pengiriman aktif.
  ///
  /// Memakai signature rute agar pergerakan GPS normal tidak memicu request API
  /// berulang sebelum TTL 60 detik berakhir atau sebelum terjadi reroute.
  Future<void> syncRouteTraffic({
    required List<LatLng> routeCoordinates,
    LatLng? courierLocation,
    LatLng? destination,
    String travelMode = 'motorcycle',
    bool force = false,
  }) async {
    if (_disposed) return;
    _routeMonitoringMode = true;
    _activeRouteCoords = List<LatLng>.unmodifiable(routeCoordinates);
    _latestCourierLocation = courierLocation;
    if (destination != null) {
      _activeDestination = destination;
    }
    _activeTravelMode = travelMode == 'car' ? 'car' : 'motorcycle';

    if (routeCoordinates.length < 2) {
      _activeRouteSignature = null;
      _routeAnalysis = null;
      _safeNotify();
      return;
    }

    final sig = TrafficService.buildRouteSignature(routeCoordinates);
    final routeChanged = _activeRouteSignature != sig;
    _activeRouteSignature = sig;
    if (routeChanged) {
      _alternativesResult = null;
      _alternativesError = null;
    }

    if (!_isTrafficEnabled || !_isMapActive) {
      return;
    }

    if (!force) {
      final current = _routeAnalysis;
      if (current != null && !current.isExpired && current.routeSignature == sig) {
        if (courierLocation != null) {
          _recomputeCourierProgressAlongRoute(courierLocation);
        }
        return;
      }

      final cached = _routeAnalysisCache[sig];
      if (cached != null && !cached.isExpired) {
        _routeAnalysis = cached;
        if (courierLocation != null) {
          _recomputeCourierProgressAlongRoute(courierLocation, notify: false);
        }
        _lastUpdatedAt = cached.fetchedAt;
        _expiresAt = cached.expiresAt;
        _errorMessage = null;
        _errorKind = null;
        _safeNotify();
        return;
      }
    }

    if (_inFlightRouteKey == sig && !force) return;
    _inFlightRouteKey = sig;
    _isLoadingRouteTraffic = true;
    _safeNotify();

    try {
      final analysis = await _service.analyzeRouteTraffic(
        routeCoordinates: routeCoordinates,
        courierLocation: courierLocation,
        travelMode: _activeTravelMode,
      );
      if (_disposed) return;

      _evictExpiredCaches();
      _routeAnalysisCache[sig] = analysis;
      _routeAnalysis = analysis;
      _lastUpdatedAt = analysis.fetchedAt;
      _expiresAt = analysis.expiresAt;
      _errorMessage = null;
      _errorKind = null;
    } on TrafficApiException catch (e) {
      if (_disposed) return;
      _errorMessage = e.message;
      _errorKind = e.kind;
    } finally {
      _inFlightRouteKey = null;
      _isLoadingRouteTraffic = false;
      _safeNotify();
    }
  }

  /// Perbarui jarak kurir ke titik kemacetan terdekat secara lokal tanpa request API baru
  /// selama rute masih sama dan data lalu lintas belum kedaluwarsa.
  void updateCourierPosition(LatLng? courierLocation) {
    if (_disposed || courierLocation == null) return;
    _latestCourierLocation = courierLocation;
    _recomputeCourierProgressAlongRoute(courierLocation);
  }

  void _recomputeCourierProgressAlongRoute(
    LatLng courier, {
    bool notify = true,
  }) {
    final analysis = _routeAnalysis;
    if (analysis == null ||
        analysis.isExpired ||
        analysis.routeCoordinates.length < 2) {
      return;
    }

    final coords = analysis.routeCoordinates;
    final cum = <double>[0.0];
    for (int i = 1; i < coords.length; i++) {
      cum.add(cum[i - 1] + _haversineMeters(coords[i - 1], coords[i]));
    }

    int nearestIdx = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < coords.length; i++) {
      final d = _haversineMeters(courier, coords[i]);
      if (d < bestDist) {
        bestDist = d;
        nearestIdx = i;
      }
    }

    final courierAlong = cum[nearestIdx];
    final updatedSegments = analysis.segments.map((seg) {
      final s = seg.startIndex.clamp(0, coords.length - 1);
      final e = seg.endIndex.clamp(s, coords.length - 1);
      final d = math.max(0.0, cum[s] - courierAlong);
      return seg.copyWithDistance(
        distanceFromCourierMeters: d,
        isAhead: e >= nearestIdx,
      );
    }).toList();

    RouteCongestionAlert? closest = analysis.closestCongestion;
    if (closest != null) {
      if (closest.endIndex < nearestIdx) {
        // Segmen macet sebelumnya telah terlewati -> cari segmen padat berikutnya di depan.
        RouteTrafficSegment? nextSeg;
        for (final s in updatedSegments) {
          if (s.classification.isCongested && s.isAhead) {
            nextSeg = s;
            break;
          }
        }
        closest = nextSeg != null
            ? RouteCongestionAlert(
                type: nextSeg.sourceType,
                roadName: nextSeg.roadName,
                distanceFromCourierMeters: nextSeg.distanceFromCourierMeters ?? 0,
                level: nextSeg.classification.level,
                statusLabel: nextSeg.classification.label,
                color: nextSeg.classification.color,
                currentSpeedKmh: nextSeg.currentSpeedKmh,
                freeFlowSpeedKmh: nextSeg.freeFlowSpeedKmh,
                speedRatioPercent: nextSeg.classification.speedRatioPercent,
                congestionPercent: nextSeg.classification.congestionPercent,
                estimatedDelaySeconds: nextSeg.estimatedDelaySeconds,
                startIndex: nextSeg.startIndex,
                endIndex: nextSeg.endIndex,
                point: nextSeg.point,
              )
            : null;
      } else {
        final targetIdx = closest.startIndex.clamp(0, coords.length - 1);
        final newDist = math.max(0.0, cum[targetIdx] - courierAlong);
        final prevDist = closest.distanceFromCourierMeters;
        if ((newDist - prevDist).abs() < 35.0 &&
            nearestIdx == analysis.courierIndex) {
          return;
        }
        closest = closest.copyWithDistance(newDist);
      }
    }

    _routeAnalysis = RouteTrafficAnalysis(
      routeSignature: analysis.routeSignature,
      routeCoordinates: analysis.routeCoordinates,
      routeDistanceMeters: analysis.routeDistanceMeters,
      remainingDistanceMeters: math.max(0.0, cum.last - courierAlong),
      courierIndex: nearestIdx,
      sampledPointsCount: analysis.sampledPointsCount,
      availableSamplesCount: analysis.availableSamplesCount,
      unknownSamplesCount: analysis.unknownSamplesCount,
      congestedSegmentsCount: analysis.congestedSegmentsCount,
      hasCongestion: analysis.hasCongestion,
      hasRoadClosure: analysis.hasRoadClosure,
      overallStatus: analysis.overallStatus,
      overallStatusLabel: analysis.overallStatusLabel,
      estimatedDelaySeconds: analysis.estimatedDelaySeconds,
      closestCongestion: closest,
      segments: updatedSegments,
      incidents: analysis.incidents,
      fetchedAt: analysis.fetchedAt,
      expiresAt: analysis.expiresAt,
      source: analysis.source,
    );

    if (notify) {
      _safeNotify();
    }
  }

  /// Muat rekomendasi rute alternatif dari TomTom Routing v1.
  /// Hasil hanya ditampilkan agar kurir memilih secara eksplisit (tanpa auto-switch).
  Future<TrafficAlternativesResult?> loadTrafficAlternatives({
    LatLng? origin,
    LatLng? destination,
    String travelMode = 'motorcycle',
    bool force = false,
  }) async {
    if (_disposed) return null;
    final o = origin ?? _latestCourierLocation;
    final d = destination ?? _activeDestination;
    if (o == null || d == null) {
      _alternativesError = 'Lokasi kurir atau tujuan belum siap.';
      _safeNotify();
      return null;
    }

    final mode = travelMode == 'car' ? 'car' : 'motorcycle';
    final key =
        '${mode}_${o.latitude.toStringAsFixed(4)},${o.longitude.toStringAsFixed(4)}_${d.latitude.toStringAsFixed(4)},${d.longitude.toStringAsFixed(4)}';

    if (!force) {
      final cached = _alternativesCache[key];
      if (cached != null && !cached.isExpired) {
        _alternativesResult = cached;
        _alternativesError = null;
        _safeNotify();
        return cached;
      }
    }

    if (_inFlightAltKey == key) return _alternativesResult;
    _inFlightAltKey = key;
    _isLoadingAlternatives = true;
    _alternativesError = null;
    _safeNotify();

    try {
      final res = await _service.getTrafficAlternatives(
        origin: o,
        destination: d,
        travelMode: mode,
        maxAlternatives: 2,
      );
      if (_disposed) return null;
      _evictExpiredCaches();
      _alternativesCache[key] = res;
      _alternativesResult = res;
      _alternativesError = null;
      return res;
    } on TrafficApiException catch (e) {
      if (_disposed) return null;
      _alternativesError = e.message;
      return null;
    } finally {
      _inFlightAltKey = null;
      _isLoadingAlternatives = false;
      _safeNotify();
    }
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const double r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2.0 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  static String _bboxKey(LatLngBounds b) {
    String r(double v) => (v / 0.005).round().toString();
    return '${r(b.south)}_${r(b.west)}_${r(b.north)}_${r(b.east)}';
  }

  static LatLngBounds _clampBoundsSpan(
    LatLngBounds b, {
    required double maxSpanDeg,
  }) {
    final centerLat = (b.south + b.north) / 2.0;
    final centerLng = (b.west + b.east) / 2.0;
    final halfLat = ((b.north - b.south).abs() / 2.0).clamp(0.015, maxSpanDeg / 2.0);
    final halfLng = ((b.east - b.west).abs() / 2.0).clamp(0.015, maxSpanDeg / 2.0);

    return LatLngBounds(
      LatLng((centerLat - halfLat).clamp(-85.0, 85.0), (centerLng - halfLng).clamp(-179.0, 179.0)),
      LatLng((centerLat + halfLat).clamp(-85.0, 85.0), (centerLng + halfLng).clamp(-179.0, 179.0)),
    );
  }

  static bool _containsBounds(LatLngBounds outer, LatLngBounds inner) {
    return inner.south >= outer.south &&
        inner.north <= outer.north &&
        inner.west >= outer.west &&
        inner.east <= outer.east;
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopRefreshTimer();
    _moveDebounceTimer?.cancel();
    _service.cancelPendingTokenReads();
    super.dispose();
  }
}
