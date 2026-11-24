import 'dart:async';

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
  bool _disposed = false;

  String? _errorMessage;
  TrafficErrorKind? _errorKind;
  String? _summaryError;

  List<TrafficIncident> _incidents = const [];
  TrafficFlowSegment? _selectedRoad;
  TrafficIncident? _selectedIncident;
  DeliveryTrafficSummary? _deliverySummary;

  DateTime? _lastUpdatedAt;
  DateTime? _expiresAt;
  int _tileEpoch;

  LatLngBounds? _activeBounds;
  double _activeZoom = MapConfig.defaultZoom;

  Timer? _refreshTimer;
  Timer? _moveDebounceTimer;
  String? _inFlightIncidentsKey;
  String? _inFlightFlowKey;

  final Map<String, _CachedIncidents> _incidentsCache = {};
  final Map<String, TrafficFlowSegment> _flowCache = {};

  Map<String, String> _tileHeaders = const {};

  TrafficController({
    TrafficService? service,
    bool initialEnabled = true,
    this.refreshInterval = MapConfig.trafficRefreshInterval,
  }) : _service = service ?? TrafficService(),
       _isTrafficEnabled = initialEnabled,
       _showLegend = initialEnabled,
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
  bool get isLoading => _isLoadingIncidents || _isLoadingSegment;
  bool get isLoadingSegment => _isLoadingSegment;
  bool get isLoadingSummary => _isLoadingSummary;

  String? get errorMessage => _errorMessage;
  TrafficErrorKind? get errorKind => _errorKind;
  String? get summaryError => _summaryError;

  List<TrafficIncident> get incidents => isDataExpired ? const [] : _incidents;
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
      if (_activeBounds != null) {
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
      if (_activeBounds != null && (isDataExpired || _lastUpdatedAt == null)) {
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

    if (!_isTrafficEnabled || !_isMapActive) return;

    _moveDebounceTimer?.cancel();
    _moveDebounceTimer = Timer(MapConfig.trafficMapMoveDebounce, () {
      if (_disposed || !_isTrafficEnabled || !_isMapActive) return;
      unawaited(_fetchIncidentsForBounds(bounds));
    });
  }

  Future<void> refreshNow({bool force = false}) async {
    if (!_isTrafficEnabled || _disposed) return;
    _bumpTileEpoch();
    final bounds = _activeBounds;
    if (bounds != null) {
      await _fetchIncidentsForBounds(bounds, force: force);
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
