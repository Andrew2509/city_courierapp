import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/core/config/map_config.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/maps/traffic_classifier_service.dart';
import 'package:city_courierapp/services/token_store.dart';

enum TrafficErrorKind {
  offline,
  timeout,
  unconfigured,
  disabled,
  rateLimited,
  invalidResponse,
  serverError,
}

class TrafficApiException implements Exception {
  final TrafficErrorKind kind;
  final String message;
  final int? statusCode;

  const TrafficApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class TrafficIncidentsResult {
  final List<TrafficIncident> incidents;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final String source;

  const TrafficIncidentsResult({
    required this.incidents,
    required this.fetchedAt,
    required this.expiresAt,
    this.source = 'tomtom_live',
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
}

/// Client HTTP menuju endpoint proxy Laravel `/api/shipping/map/traffic/*`.
/// Tidak menyimpan atau mengirim TomTom API Key di kode Flutter.
class TrafficService {
  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _tokenReader;
  final Duration _timeout;
  final Set<void Function()> _pendingTokenCancelers = {};

  TrafficService({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenReader,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiService.baseUrl).replaceAll(RegExp(r'/+$'), ''),
       _tokenReader = tokenReader ?? TokenStore.read,
       _timeout = timeout ?? MapConfig.networkTimeout;

  /// Membatalkan pembacaan token yang masih tertunda saat controller/halaman di-dispose.
  void cancelPendingTokenReads() {
    for (final cancel in List<void Function()>.from(_pendingTokenCancelers)) {
      cancel();
    }
    _pendingTokenCancelers.clear();
  }

  Future<String?> _readTokenSafe() {
    final completer = Completer<String?>();
    late final Timer timer;
    late final void Function() canceler;

    canceler = () {
      if (timer.isActive) timer.cancel();
      _pendingTokenCancelers.remove(canceler);
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    };

    timer = Timer(const Duration(seconds: 2), canceler);
    _pendingTokenCancelers.add(canceler);

    Future<String?>.sync(() => _tokenReader()).then((token) {
      if (timer.isActive) timer.cancel();
      _pendingTokenCancelers.remove(canceler);
      if (!completer.isCompleted) {
        completer.complete(token);
      }
    }).catchError((Object _) {
      if (timer.isActive) timer.cancel();
      _pendingTokenCancelers.remove(canceler);
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _readTokenSafe();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> tileHeaders() async {
    final token = await _readTokenSafe();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String buildFlowTileUrl({required int epoch}) {
    return '$_baseUrl/shipping/map/traffic/tiles/{z}/{x}/{y}.png'
        '?style=${MapConfig.trafficTileStyle}'
        '&tile_size=${MapConfig.trafficTileSize}'
        '&thickness=${MapConfig.trafficTileThickness}'
        '&v=$epoch';
  }

  Future<TrafficFlowSegment> getFlowSegment({
    required LatLng point,
    int zoom = MapConfig.trafficFlowZoom,
    bool includeRoadName = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/shipping/map/traffic/flow').replace(
      queryParameters: {
        'lat': point.latitude.toStringAsFixed(6),
        'lng': point.longitude.toStringAsFixed(6),
        'zoom': zoom.clamp(0, 22).toString(),
        'style': MapConfig.trafficTileStyle,
        'include_road_name': includeRoadName ? '1' : '0',
      },
    );

    final data = await _getJsonData(uri);
    final parsed = _parseFlowSegment(data, fallbackPoint: point);
    if (parsed == null) {
      throw const TrafficApiException(
        kind: TrafficErrorKind.invalidResponse,
        message: 'Data kondisi jalan belum valid atau belum tersedia.',
      );
    }
    return parsed;
  }

  Future<TrafficIncidentsResult> getIncidents({
    required LatLngBounds bounds,
    String language = 'id-ID',
  }) async {
    final uri = Uri.parse('$_baseUrl/shipping/map/traffic/incidents').replace(
      queryParameters: {
        'min_lat': bounds.south.toStringAsFixed(5),
        'min_lng': bounds.west.toStringAsFixed(5),
        'max_lat': bounds.north.toStringAsFixed(5),
        'max_lng': bounds.east.toStringAsFixed(5),
        'language': language,
      },
    );

    final data = await _getJsonData(uri);
    final timestamps = _parseFreshness(data);

    final rawList = data['incidents'];
    if (rawList is! List) {
      throw const TrafficApiException(
        kind: TrafficErrorKind.invalidResponse,
        message: 'Format data insiden lalu lintas tidak valid.',
      );
    }

    final incidents = rawList
        .whereType<Map>()
        .map((m) => TrafficIncident.fromJson(Map<String, dynamic>.from(m)))
        .where((inc) => inc.point.latitude != 0 || inc.point.longitude != 0)
        .toList();

    return TrafficIncidentsResult(
      incidents: incidents,
      fetchedAt: timestamps.$1,
      expiresAt: timestamps.$2,
      source: (data['source'] ?? 'tomtom_live').toString(),
    );
  }

  Future<DeliveryTrafficSummary> getDeliverySummary({
    required LatLng pickup,
    required LatLng dropoff,
    String? pickupRoadHint,
    String? dropoffRoadHint,
  }) async {
    final uri = Uri.parse('$_baseUrl/shipping/map/traffic/delivery-summary');
    final data = await _postJsonData(uri, {
      'pickup_lat': pickup.latitude,
      'pickup_lng': pickup.longitude,
      'dropoff_lat': dropoff.latitude,
      'dropoff_lng': dropoff.longitude,
      if (pickupRoadHint != null && pickupRoadHint.trim().isNotEmpty)
        'pickup_road_hint': pickupRoadHint.trim(),
      if (dropoffRoadHint != null && dropoffRoadHint.trim().isNotEmpty)
        'dropoff_road_hint': dropoffRoadHint.trim(),
    });

    final timestamps = _parseFreshness(data);
    final pickupRaw = data['pickup_traffic'] is Map
        ? Map<String, dynamic>.from(data['pickup_traffic'] as Map)
        : null;
    final dropoffRaw = data['dropoff_traffic'] is Map
        ? Map<String, dynamic>.from(data['dropoff_traffic'] as Map)
        : null;

    final pickupTraffic = pickupRaw != null
        ? _parseFlowSegment(pickupRaw, fallbackPoint: pickup)
        : null;
    final dropoffTraffic = dropoffRaw != null
        ? _parseFlowSegment(dropoffRaw, fallbackPoint: dropoff)
        : null;

    final incidents = (data['incidents'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TrafficIncident.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final warnings = (data['congestion_warnings'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TrafficCongestionWarning.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final altRaw = data['alternative_route'] is Map
        ? Map<String, dynamic>.from(data['alternative_route'] as Map)
        : null;

    return DeliveryTrafficSummary(
      pickupTraffic: pickupTraffic,
      dropoffTraffic: dropoffTraffic,
      incidents: incidents,
      hasCongestion: data['has_congestion'] == true,
      warnings: warnings,
      alternativeRoute: AlternativeRouteCapability.fromJson(altRaw),
      fetchedAt: timestamps.$1,
      expiresAt: timestamps.$2,
    );
  }

  /// Menghitung signature deterministik dari polyline rute agar request
  /// tidak diulang hanya karena jitter kecil pada koordinat GPS kurir.
  static String buildRouteSignature(List<LatLng> routeCoordinates) {
    final n = routeCoordinates.length;
    if (n < 2) return 'empty';
    final step = n <= 12 ? 1 : (n ~/ 10);
    final parts = <String>[];
    for (int i = 0; i < n; i += step) {
      final p = routeCoordinates[i];
      parts.add('${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}');
    }
    final last = routeCoordinates.last;
    parts.add('${last.latitude.toStringAsFixed(4)},${last.longitude.toStringAsFixed(4)}');
    return '$n|${parts.join(';')}';
  }

  /// Analisa kemacetan TomTom SEPANJANG jalur rute aktif kurir menuju penerima.
  Future<RouteTrafficAnalysis> analyzeRouteTraffic({
    required List<LatLng> routeCoordinates,
    LatLng? courierLocation,
    String travelMode = 'motorcycle',
  }) async {
    if (routeCoordinates.length < 2) {
      throw const TrafficApiException(
        kind: TrafficErrorKind.invalidResponse,
        message: 'Minimal dua titik rute diperlukan untuk analisa lalu lintas.',
      );
    }

    // Jika rute sangat panjang (> 800 titik), pilih sampel berindeks seragam dan
    // petakan kembali indeks respons ke koordinat asli agar pewarnaan tetap akurat.
    final List<int> indexMap;
    if (routeCoordinates.length <= 800) {
      indexMap = List<int>.generate(routeCoordinates.length, (i) => i);
    } else {
      final step = (routeCoordinates.length / 798).ceil();
      final mapped = <int>[0];
      for (int i = step; i < routeCoordinates.length - 1; i += step) {
        mapped.add(i);
      }
      mapped.add(routeCoordinates.length - 1);
      indexMap = mapped;
    }

    final payloadCoords = indexMap
        .map((i) => {
              'lat': routeCoordinates[i].latitude,
              'lng': routeCoordinates[i].longitude,
            })
        .toList(growable: false);

    final uri = Uri.parse('$_baseUrl/shipping/map/traffic/route-analysis');
    final data = await _postJsonData(uri, {
      'coordinates': payloadCoords,
      if (courierLocation != null) 'courier_lat': courierLocation.latitude,
      if (courierLocation != null) 'courier_lng': courierLocation.longitude,
      'travel_mode': travelMode == 'car' ? 'car' : 'motorcycle',
    });

    final timestamps = _parseFreshness(data);
    final maxOriginalIdx = routeCoordinates.length - 1;
    int mapIdx(int backendIdx) {
      if (backendIdx <= 0) return 0;
      if (backendIdx >= indexMap.length) return maxOriginalIdx;
      return indexMap[backendIdx];
    }

    final segments = (data['segments'] as List? ?? [])
        .whereType<Map>()
        .map((raw) {
          final parsed =
              RouteTrafficSegment.fromJson(Map<String, dynamic>.from(raw));
          final mappedStart = mapIdx(parsed.startIndex);
          final mappedEnd = mapIdx(parsed.endIndex);
          return RouteTrafficSegment(
            startIndex: mappedStart,
            endIndex: mappedEnd < mappedStart ? mappedStart : mappedEnd,
            classification: parsed.classification,
            currentSpeedKmh: parsed.currentSpeedKmh,
            freeFlowSpeedKmh: parsed.freeFlowSpeedKmh,
            estimatedDelaySeconds: parsed.estimatedDelaySeconds,
            distanceFromCourierMeters: parsed.distanceFromCourierMeters,
            isAhead: parsed.isAhead,
            roadName: parsed.roadName,
            point: parsed.point,
            sourceType: parsed.sourceType,
          );
        })
        .toList();

    final incidents = (data['incidents'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TrafficIncident.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final closestRaw = data['closest_congestion'] is Map
        ? Map<String, dynamic>.from(data['closest_congestion'] as Map)
        : null;
    RouteCongestionAlert? closestAlert;
    if (closestRaw != null) {
      final parsedAlert = RouteCongestionAlert.fromJson(closestRaw);
      final mappedStart = mapIdx(parsedAlert.startIndex);
      final mappedEnd = mapIdx(parsedAlert.endIndex);
      closestAlert = RouteCongestionAlert(
        type: parsedAlert.type,
        roadName: parsedAlert.roadName,
        distanceFromCourierMeters: parsedAlert.distanceFromCourierMeters,
        level: parsedAlert.level,
        statusLabel: parsedAlert.statusLabel,
        color: parsedAlert.color,
        currentSpeedKmh: parsedAlert.currentSpeedKmh,
        freeFlowSpeedKmh: parsedAlert.freeFlowSpeedKmh,
        speedRatioPercent: parsedAlert.speedRatioPercent,
        congestionPercent: parsedAlert.congestionPercent,
        estimatedDelaySeconds: parsedAlert.estimatedDelaySeconds,
        description: parsedAlert.description,
        startIndex: mappedStart,
        endIndex: mappedEnd < mappedStart ? mappedStart : mappedEnd,
        point: parsedAlert.point,
      );
    }

    final overallStatus =
        TrafficClassification.parseLevel(data['overall_status']?.toString());

    return RouteTrafficAnalysis(
      routeSignature: buildRouteSignature(routeCoordinates),
      routeCoordinates: List<LatLng>.unmodifiable(routeCoordinates),
      routeDistanceMeters:
          (data['route_distance_meters'] as num?)?.toDouble() ?? 0.0,
      remainingDistanceMeters:
          (data['remaining_distance_meters'] as num?)?.toDouble() ?? 0.0,
      courierIndex: mapIdx((data['courier_index'] as num?)?.toInt() ?? 0),
      sampledPointsCount:
          (data['sampled_points_count'] as num?)?.toInt() ?? 0,
      availableSamplesCount:
          (data['available_samples_count'] as num?)?.toInt() ?? 0,
      unknownSamplesCount:
          (data['unknown_samples_count'] as num?)?.toInt() ?? 0,
      congestedSegmentsCount:
          (data['congested_segments_count'] as num?)?.toInt() ??
              segments.where((s) => s.classification.isCongested).length,
      hasCongestion: data['has_congestion'] == true,
      hasRoadClosure: data['has_road_closure'] == true,
      overallStatus: overallStatus,
      overallStatusLabel:
          (data['overall_status_label'] ?? 'Data Tidak Tersedia').toString(),
      estimatedDelaySeconds:
          (data['estimated_delay_seconds'] as num?)?.toInt(),
      closestCongestion: closestAlert,
      segments: segments,
      incidents: incidents,
      fetchedAt: timestamps.$1,
      expiresAt: timestamps.$2,
      source: (data['source'] ?? 'tomtom_live').toString(),
    );
  }

  /// Meminta daftar rute utama + alternatif berbasis lalu lintas real-time TomTom.
  Future<TrafficAlternativesResult> getTrafficAlternatives({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'motorcycle',
    int maxAlternatives = 2,
  }) async {
    final uri = Uri.parse('$_baseUrl/shipping/map/traffic/alternatives');
    final data = await _postJsonData(uri, {
      'origin_lat': origin.latitude,
      'origin_lng': origin.longitude,
      'destination_lat': destination.latitude,
      'destination_lng': destination.longitude,
      'travel_mode': travelMode == 'car' ? 'car' : 'motorcycle',
      'max_alternatives': maxAlternatives.clamp(1, 3),
    });

    final timestamps = _parseFreshness(data);
    final routes = (data['routes'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TrafficAlternativeRoute.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return TrafficAlternativesResult(
      routingEngine:
          (data['routing_engine'] ?? 'tomtom_routing_v1').toString(),
      travelMode: (data['travel_mode'] ?? travelMode).toString(),
      autoSwitch: false,
      hasFasterAlternative: data['has_faster_alternative'] == true,
      recommendedRouteIndex:
          (data['recommended_route_index'] as num?)?.toInt(),
      routes: routes,
      fetchedAt: timestamps.$1,
      expiresAt: timestamps.$2,
    );
  }

  Future<Map<String, dynamic>> _getJsonData(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(_timeout);
      return _decodeData(response);
    } on TrafficApiException {
      rethrow;
    } on TimeoutException {
      throw const TrafficApiException(
        kind: TrafficErrorKind.timeout,
        message: 'Waktu tunggu memuat data lalu lintas habis.',
      );
    } on SocketException {
      throw const TrafficApiException(
        kind: TrafficErrorKind.offline,
        message: 'Koneksi internet terputus. Tidak dapat memuat data lalu lintas.',
      );
    } on http.ClientException {
      throw const TrafficApiException(
        kind: TrafficErrorKind.offline,
        message: 'Gagal terhubung ke server lalu lintas.',
      );
    } catch (_) {
      throw const TrafficApiException(
        kind: TrafficErrorKind.serverError,
        message: 'Terjadi gangguan saat memuat data lalu lintas.',
      );
    }
  }

  Future<Map<String, dynamic>> _postJsonData(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(uri, headers: await _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      return _decodeData(response);
    } on TrafficApiException {
      rethrow;
    } on TimeoutException {
      throw const TrafficApiException(
        kind: TrafficErrorKind.timeout,
        message: 'Waktu tunggu memeriksa lalu lintas pengiriman habis.',
      );
    } on SocketException {
      throw const TrafficApiException(
        kind: TrafficErrorKind.offline,
        message: 'Koneksi internet terputus.',
      );
    } on http.ClientException {
      throw const TrafficApiException(
        kind: TrafficErrorKind.offline,
        message: 'Gagal terhubung ke server lalu lintas.',
      );
    } catch (_) {
      throw const TrafficApiException(
        kind: TrafficErrorKind.serverError,
        message: 'Terjadi gangguan saat memeriksa kondisi lalu lintas.',
      );
    }
  }

  Map<String, dynamic> _decodeData(http.Response response) {
    Map<String, dynamic> bodyMap = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          bodyMap = decoded;
        }
      } catch (_) {
        throw TrafficApiException(
          kind: TrafficErrorKind.invalidResponse,
          message: 'Respons lalu lintas tidak valid.',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        bodyMap['success'] == true &&
        bodyMap['data'] is Map) {
      final data = Map<String, dynamic>.from(bodyMap['data'] as Map);
      if (data['is_stale'] == true) {
        throw const TrafficApiException(
          kind: TrafficErrorKind.invalidResponse,
          message: 'Data lalu lintas sudah kedaluwarsa dan perlu dimuat ulang.',
        );
      }
      return data;
    }

    final code = (bodyMap['error_code'] ?? '').toString().toUpperCase();
    final message = (bodyMap['message'] ?? '').toString().trim();

    if (code == 'TOMTOM_NOT_CONFIGURED') {
      throw TrafficApiException(
        kind: TrafficErrorKind.unconfigured,
        message: message.isNotEmpty
            ? message
            : 'Layanan lalu lintas TomTom belum dikonfigurasi.',
        statusCode: response.statusCode,
      );
    }
    if (code == 'PROVIDER_DISABLED') {
      throw TrafficApiException(
        kind: TrafficErrorKind.disabled,
        message: message.isNotEmpty
            ? message
            : 'Layanan peta dan lalu lintas sedang dinonaktifkan.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      throw TrafficApiException(
        kind: TrafficErrorKind.rateLimited,
        message: 'Permintaan lalu lintas terlalu padat. Coba lagi sebentar.',
        statusCode: response.statusCode,
      );
    }

    throw TrafficApiException(
      kind: response.statusCode >= 500
          ? TrafficErrorKind.serverError
          : TrafficErrorKind.invalidResponse,
      message: message.isNotEmpty
          ? message
          : 'Data lalu lintas belum tersedia (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  (DateTime, DateTime) _parseFreshness(Map<String, dynamic> data) {
    final now = DateTime.now().toUtc();
    final fetched = data['fetched_at'] != null
        ? DateTime.tryParse(data['fetched_at'].toString())?.toUtc()
        : null;
    final expires = data['expires_at'] != null
        ? DateTime.tryParse(data['expires_at'].toString())?.toUtc()
        : null;

    if (fetched == null || expires == null || now.isAfter(expires)) {
      throw const TrafficApiException(
        kind: TrafficErrorKind.invalidResponse,
        message: 'Data lalu lintas sudah kedaluwarsa.',
      );
    }
    return (fetched, expires);
  }

  TrafficFlowSegment? _parseFlowSegment(
    Map<String, dynamic> json, {
    required LatLng fallbackPoint,
  }) {
    final ptMap = json['point'] is Map
        ? Map<String, dynamic>.from(json['point'] as Map)
        : <String, dynamic>{};
    final point = LatLng(
      (ptMap['lat'] as num?)?.toDouble() ?? fallbackPoint.latitude,
      (ptMap['lng'] as num?)?.toDouble() ?? fallbackPoint.longitude,
    );

    final curSpeed = (json['current_speed_kmh'] as num?)?.toInt();
    final freeSpeed = (json['free_flow_speed_kmh'] as num?)?.toInt();
    final roadClosure = json['road_closure'] == true;

    final classification = TrafficClassifierService.classify(
      currentSpeedKmh: curSpeed,
      freeFlowSpeedKmh: freeSpeed,
      roadClosure: roadClosure,
    );

    final coords = (json['coordinates'] as List? ?? [])
        .whereType<Map>()
        .map((c) {
          final lat = (c['lat'] as num?)?.toDouble();
          final lng = (c['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();

    final now = DateTime.now().toUtc();
    final fetchedAt = json['fetched_at'] != null
        ? (DateTime.tryParse(json['fetched_at'].toString())?.toUtc() ?? now)
        : now;
    final expiresAt = json['expires_at'] != null
        ? (DateTime.tryParse(json['expires_at'].toString())?.toUtc() ??
            fetchedAt.add(MapConfig.trafficClientCacheTtl))
        : fetchedAt.add(MapConfig.trafficClientCacheTtl);

    if (now.isAfter(expiresAt)) {
      return null;
    }

    final rawRoadName = json['road_name']?.toString().trim();

    return TrafficFlowSegment(
      point: point,
      roadName: (rawRoadName != null && rawRoadName.isNotEmpty)
          ? rawRoadName
          : null,
      currentSpeedKmh: curSpeed,
      freeFlowSpeedKmh: freeSpeed,
      currentTravelTimeSeconds: (json['current_travel_time_seconds'] as num?)?.toInt(),
      freeFlowTravelTimeSeconds: (json['free_flow_travel_time_seconds'] as num?)?.toInt(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      roadClosure: roadClosure,
      classification: classification,
      coordinates: coords,
      fetchedAt: fetchedAt,
      expiresAt: expiresAt,
      source: (json['source'] ?? 'tomtom_live').toString(),
    );
  }
}
