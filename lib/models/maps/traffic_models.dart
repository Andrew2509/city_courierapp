import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum TrafficConditionLevel {
  smooth,
  moderate,
  heavy,
  congested,
  roadClosed,
  unknown,
}

class TrafficClassification {
  final TrafficConditionLevel level;
  final String statusKey;
  final String label;
  final Color color;
  final double? speedRatioPercent;
  final double? congestionPercent;
  final bool isAvailable;
  final bool isCongested;

  const TrafficClassification({
    required this.level,
    required this.statusKey,
    required this.label,
    required this.color,
    required this.speedRatioPercent,
    required this.congestionPercent,
    required this.isAvailable,
    required this.isCongested,
  });

  static TrafficConditionLevel parseLevel(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'smooth':
        return TrafficConditionLevel.smooth;
      case 'moderate':
        return TrafficConditionLevel.moderate;
      case 'heavy':
        return TrafficConditionLevel.heavy;
      case 'congested':
        return TrafficConditionLevel.congested;
      case 'road_closed':
        return TrafficConditionLevel.roadClosed;
      default:
        return TrafficConditionLevel.unknown;
    }
  }
}

class TrafficFlowSegment {
  final LatLng point;
  final String? roadName;
  final int? currentSpeedKmh;
  final int? freeFlowSpeedKmh;
  final int? currentTravelTimeSeconds;
  final int? freeFlowTravelTimeSeconds;
  final double? confidence;
  final bool roadClosure;
  final TrafficClassification classification;
  final List<LatLng> coordinates;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final String source;

  const TrafficFlowSegment({
    required this.point,
    this.roadName,
    required this.currentSpeedKmh,
    required this.freeFlowSpeedKmh,
    this.currentTravelTimeSeconds,
    this.freeFlowTravelTimeSeconds,
    this.confidence,
    required this.roadClosure,
    required this.classification,
    required this.coordinates,
    required this.fetchedAt,
    required this.expiresAt,
    this.source = 'tomtom_live',
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  TrafficFlowSegment copyWith({String? roadName}) {
    return TrafficFlowSegment(
      point: point,
      roadName: roadName ?? this.roadName,
      currentSpeedKmh: currentSpeedKmh,
      freeFlowSpeedKmh: freeFlowSpeedKmh,
      currentTravelTimeSeconds: currentTravelTimeSeconds,
      freeFlowTravelTimeSeconds: freeFlowTravelTimeSeconds,
      confidence: confidence,
      roadClosure: roadClosure,
      classification: classification,
      coordinates: coordinates,
      fetchedAt: fetchedAt,
      expiresAt: expiresAt,
      source: source,
    );
  }
}

class TrafficIncident {
  final String id;
  final String category;
  final String categoryLabel;
  final String severity;
  final String severityLabel;
  final String description;
  final String? from;
  final String? to;
  final String? roadLabel;
  final List<String> roadNumbers;
  final int? delaySeconds;
  final int? lengthMeters;
  final DateTime? startTime;
  final DateTime? endTime;
  final LatLng point;
  final List<LatLng> coordinates;

  const TrafficIncident({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.severity,
    required this.severityLabel,
    required this.description,
    this.from,
    this.to,
    this.roadLabel,
    this.roadNumbers = const [],
    this.delaySeconds,
    this.lengthMeters,
    this.startTime,
    this.endTime,
    required this.point,
    this.coordinates = const [],
  });

  Color get markerColor {
    switch (category) {
      case 'road_closed':
      case 'accident':
      case 'flooding':
        return const Color(0xFFDC2626);
      case 'lane_closed':
      case 'road_works':
      case 'broken_down_vehicle':
        return const Color(0xFFF97316);
      case 'jam':
        return severity == 'major'
            ? const Color(0xFFDC2626)
            : const Color(0xFFEAB308);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get iconData {
    switch (category) {
      case 'accident':
        return Icons.car_crash_rounded;
      case 'road_closed':
        return Icons.block_rounded;
      case 'lane_closed':
        return Icons.do_not_disturb_on_rounded;
      case 'road_works':
        return Icons.construction_rounded;
      case 'flooding':
        return Icons.water_damage_rounded;
      case 'broken_down_vehicle':
        return Icons.build_circle_rounded;
      case 'jam':
        return Icons.traffic_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  factory TrafficIncident.fromJson(Map<String, dynamic> json) {
    final pt = json['point'] is Map
        ? Map<String, dynamic>.from(json['point'] as Map)
        : <String, dynamic>{};
    final rawCoords = (json['coordinates'] as List? ?? [])
        .whereType<Map>()
        .map((c) {
          final lat = (c['lat'] as num?)?.toDouble();
          final lng = (c['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();

    final pointLat = (pt['lat'] as num?)?.toDouble() ??
        (rawCoords.isNotEmpty ? rawCoords.first.latitude : 0.0);
    final pointLng = (pt['lng'] as num?)?.toDouble() ??
        (rawCoords.isNotEmpty ? rawCoords.first.longitude : 0.0);

    return TrafficIncident(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? 'other').toString(),
      categoryLabel: (json['category_label'] ?? 'Gangguan Lalu Lintas').toString(),
      severity: (json['severity'] ?? 'unknown').toString(),
      severityLabel: (json['severity_label'] ?? 'Perlu Diwaspadai').toString(),
      description: (json['description'] ?? '').toString(),
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      roadLabel: json['road_label']?.toString(),
      roadNumbers: (json['road_numbers'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      delaySeconds: (json['delay_seconds'] as num?)?.toInt(),
      lengthMeters: (json['length_meters'] as num?)?.toInt(),
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'].toString())
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'].toString())
          : null,
      point: LatLng(pointLat, pointLng),
      coordinates: rawCoords,
    );
  }
}

class TrafficCongestionWarning {
  final String area;
  final String severity;
  final String title;
  final String detail;

  const TrafficCongestionWarning({
    required this.area,
    required this.severity,
    required this.title,
    required this.detail,
  });

  factory TrafficCongestionWarning.fromJson(Map<String, dynamic> json) {
    return TrafficCongestionWarning(
      area: (json['area'] ?? 'corridor').toString(),
      severity: (json['severity'] ?? 'moderate').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
    );
  }
}

/// Fondasi metadata rekomendasi rute alternatif berbasis lalu lintas.
/// Saat `supported == false`, aplikasi tidak boleh mengklaim fitur rute alternatif sudah aktif.
class AlternativeRouteCapability {
  final bool supported;
  final String routingEngine;
  final bool trafficAware;
  final bool recommendationAvailable;
  final String message;

  const AlternativeRouteCapability({
    required this.supported,
    required this.routingEngine,
    required this.trafficAware,
    required this.recommendationAvailable,
    required this.message,
  });

  factory AlternativeRouteCapability.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AlternativeRouteCapability(
        supported: false,
        routingEngine: 'osrm_openstreetmap',
        trafficAware: false,
        recommendationAvailable: false,
        message:
            'Rekomendasi rute alternatif berbasis lalu lintas belum aktif karena routing saat ini menggunakan OSRM OpenStreetMap.',
      );
    }

    return AlternativeRouteCapability(
      supported: json['supported'] == true,
      routingEngine: (json['routing_engine'] ?? 'osrm_openstreetmap').toString(),
      trafficAware: json['traffic_aware'] == true,
      recommendationAvailable: json['recommendation_available'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class DeliveryTrafficSummary {
  final TrafficFlowSegment? pickupTraffic;
  final TrafficFlowSegment? dropoffTraffic;
  final List<TrafficIncident> incidents;
  final bool hasCongestion;
  final List<TrafficCongestionWarning> warnings;
  final AlternativeRouteCapability alternativeRoute;
  final DateTime fetchedAt;
  final DateTime expiresAt;

  const DeliveryTrafficSummary({
    required this.pickupTraffic,
    required this.dropoffTraffic,
    required this.incidents,
    required this.hasCongestion,
    required this.warnings,
    required this.alternativeRoute,
    required this.fetchedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
}

/// Segmen lalu lintas yang dipetakan tepat pada rentang indeks polyline rute aktif.
class RouteTrafficSegment {
  final int startIndex;
  final int endIndex;
  final TrafficClassification classification;
  final int? currentSpeedKmh;
  final int? freeFlowSpeedKmh;
  final int? estimatedDelaySeconds;
  final double? distanceFromCourierMeters;
  final bool isAhead;
  final String? roadName;
  final LatLng? point;
  final String sourceType;

  const RouteTrafficSegment({
    required this.startIndex,
    required this.endIndex,
    required this.classification,
    this.currentSpeedKmh,
    this.freeFlowSpeedKmh,
    this.estimatedDelaySeconds,
    this.distanceFromCourierMeters,
    this.isAhead = true,
    this.roadName,
    this.point,
    this.sourceType = 'flow',
  });

  /// Di garis navigasi, segmen dengan data lalu lintas tersedia selain lancar (`>=70%`)
  /// akan merubah warna sub-segmen polyline (kuning / oranye / merah).
  bool get shouldHighlightOnRoute =>
      classification.isAvailable &&
      classification.level != TrafficConditionLevel.smooth;

  Color get routeLineColor {
    switch (classification.level) {
      case TrafficConditionLevel.moderate:
        return const Color(0xFFEAB308);
      case TrafficConditionLevel.heavy:
        return const Color(0xFFF97316);
      case TrafficConditionLevel.congested:
      case TrafficConditionLevel.roadClosed:
        return const Color(0xFFDC2626);
      case TrafficConditionLevel.smooth:
      case TrafficConditionLevel.unknown:
        return const Color(0xFF2563EB);
    }
  }

  RouteTrafficSegment copyWithDistance({
    required double distanceFromCourierMeters,
    required bool isAhead,
  }) {
    return RouteTrafficSegment(
      startIndex: startIndex,
      endIndex: endIndex,
      classification: classification,
      currentSpeedKmh: currentSpeedKmh,
      freeFlowSpeedKmh: freeFlowSpeedKmh,
      estimatedDelaySeconds: estimatedDelaySeconds,
      distanceFromCourierMeters: distanceFromCourierMeters,
      isAhead: isAhead,
      roadName: roadName,
      point: point,
      sourceType: sourceType,
    );
  }

  factory RouteTrafficSegment.fromJson(Map<String, dynamic> json) {
    final level = TrafficClassification.parseLevel(json['status']?.toString());
    final colorHex = (json['color_hex'] ?? '').toString();
    final Color color = switch (level) {
      TrafficConditionLevel.smooth => const Color(0xFF16A34A),
      TrafficConditionLevel.moderate => const Color(0xFFEAB308),
      TrafficConditionLevel.heavy => const Color(0xFFF97316),
      TrafficConditionLevel.congested || TrafficConditionLevel.roadClosed =>
        const Color(0xFFDC2626),
      TrafficConditionLevel.unknown =>
        colorHex == '#DC2626' ? const Color(0xFFDC2626) : const Color(0xFF64748B),
    };

    final ptRaw = json['point'] is Map
        ? Map<String, dynamic>.from(json['point'] as Map)
        : null;
    final ptLat = (ptRaw?['lat'] as num?)?.toDouble();
    final ptLng = (ptRaw?['lng'] as num?)?.toDouble();

    final isAvailable = json['is_available'] == true;
    final isCongested = json['is_congested'] == true ||
        level == TrafficConditionLevel.heavy ||
        level == TrafficConditionLevel.congested ||
        level == TrafficConditionLevel.roadClosed;

    final rawRoad = json['road_name']?.toString().trim();

    return RouteTrafficSegment(
      startIndex: (json['start_index'] as num?)?.toInt() ?? 0,
      endIndex: (json['end_index'] as num?)?.toInt() ?? 0,
      classification: TrafficClassification(
        level: level,
        statusKey: (json['status'] ?? 'unknown').toString(),
        label: (json['status_label'] ?? 'Data Tidak Tersedia').toString(),
        color: color,
        speedRatioPercent: (json['speed_ratio_percent'] as num?)?.toDouble(),
        congestionPercent: (json['congestion_percent'] as num?)?.toDouble(),
        isAvailable: isAvailable,
        isCongested: isCongested,
      ),
      currentSpeedKmh: (json['current_speed_kmh'] as num?)?.toInt(),
      freeFlowSpeedKmh: (json['free_flow_speed_kmh'] as num?)?.toInt(),
      estimatedDelaySeconds: (json['estimated_delay_seconds'] as num?)?.toInt(),
      distanceFromCourierMeters:
          (json['distance_from_courier_meters'] as num?)?.toDouble(),
      isAhead: json['is_ahead'] != false,
      roadName: (rawRoad != null && rawRoad.isNotEmpty) ? rawRoad : null,
      point: (ptLat != null && ptLng != null) ? LatLng(ptLat, ptLng) : null,
      sourceType: (json['source_type'] ?? 'flow').toString(),
    );
  }
}

/// Informasi kemacetan terdekat di depan kurir di sepanjang rute aktif.
class RouteCongestionAlert {
  final String type;
  final String? roadName;
  final double distanceFromCourierMeters;
  final TrafficConditionLevel level;
  final String statusLabel;
  final Color color;
  final int? currentSpeedKmh;
  final int? freeFlowSpeedKmh;
  final double? speedRatioPercent;
  final double? congestionPercent;
  final int? estimatedDelaySeconds;
  final String? description;
  final int startIndex;
  final int endIndex;
  final LatLng? point;

  const RouteCongestionAlert({
    required this.type,
    this.roadName,
    required this.distanceFromCourierMeters,
    required this.level,
    required this.statusLabel,
    required this.color,
    this.currentSpeedKmh,
    this.freeFlowSpeedKmh,
    this.speedRatioPercent,
    this.congestionPercent,
    this.estimatedDelaySeconds,
    this.description,
    required this.startIndex,
    required this.endIndex,
    this.point,
  });

  String get formattedDistance {
    if (distanceFromCourierMeters < 1000) {
      return '${distanceFromCourierMeters.round()} m';
    }
    final km = (distanceFromCourierMeters / 1000.0).toStringAsFixed(1);
    return '${km.replaceAll('.', ',')} km';
  }

  String? get formattedDelay {
    final sec = estimatedDelaySeconds;
    if (sec == null || sec < 30) return null;
    final mins = (sec / 60.0).ceil();
    return '+$mins mnt';
  }

  RouteCongestionAlert copyWithDistance(double newDistanceMeters) {
    return RouteCongestionAlert(
      type: type,
      roadName: roadName,
      distanceFromCourierMeters: newDistanceMeters,
      level: level,
      statusLabel: statusLabel,
      color: color,
      currentSpeedKmh: currentSpeedKmh,
      freeFlowSpeedKmh: freeFlowSpeedKmh,
      speedRatioPercent: speedRatioPercent,
      congestionPercent: congestionPercent,
      estimatedDelaySeconds: estimatedDelaySeconds,
      description: description,
      startIndex: startIndex,
      endIndex: endIndex,
      point: point,
    );
  }

  factory RouteCongestionAlert.fromJson(Map<String, dynamic> json) {
    final level = TrafficClassification.parseLevel(json['status']?.toString());
    final color = switch (level) {
      TrafficConditionLevel.moderate => const Color(0xFFEAB308),
      TrafficConditionLevel.heavy => const Color(0xFFF97316),
      TrafficConditionLevel.congested || TrafficConditionLevel.roadClosed =>
        const Color(0xFFDC2626),
      TrafficConditionLevel.smooth => const Color(0xFF16A34A),
      TrafficConditionLevel.unknown => const Color(0xFF64748B),
    };

    final ptRaw = json['point'] is Map
        ? Map<String, dynamic>.from(json['point'] as Map)
        : null;
    final ptLat = (ptRaw?['lat'] as num?)?.toDouble();
    final ptLng = (ptRaw?['lng'] as num?)?.toDouble();
    final rawRoad = json['road_name']?.toString().trim();

    return RouteCongestionAlert(
      type: (json['type'] ?? 'flow').toString(),
      roadName: (rawRoad != null && rawRoad.isNotEmpty) ? rawRoad : null,
      distanceFromCourierMeters:
          (json['distance_from_courier_meters'] as num?)?.toDouble() ?? 0.0,
      level: level,
      statusLabel: (json['status_label'] ?? 'Padat').toString(),
      color: color,
      currentSpeedKmh: (json['current_speed_kmh'] as num?)?.toInt(),
      freeFlowSpeedKmh: (json['free_flow_speed_kmh'] as num?)?.toInt(),
      speedRatioPercent: (json['speed_ratio_percent'] as num?)?.toDouble(),
      congestionPercent: (json['congestion_percent'] as num?)?.toDouble(),
      estimatedDelaySeconds: (json['estimated_delay_seconds'] as num?)?.toInt(),
      description: json['description']?.toString(),
      startIndex: (json['start_index'] as num?)?.toInt() ?? 0,
      endIndex: (json['end_index'] as num?)?.toInt() ?? 0,
      point: (ptLat != null && ptLng != null) ? LatLng(ptLat, ptLng) : null,
    );
  }
}

/// Hasil analisa lalu lintas khusus sepanjang polyline rute aktif kurir.
class RouteTrafficAnalysis {
  final String routeSignature;
  final List<LatLng> routeCoordinates;
  final double routeDistanceMeters;
  final double remainingDistanceMeters;
  final int courierIndex;
  final int sampledPointsCount;
  final int availableSamplesCount;
  final int unknownSamplesCount;
  final int congestedSegmentsCount;
  final bool hasCongestion;
  final bool hasRoadClosure;
  final TrafficConditionLevel overallStatus;
  final String overallStatusLabel;
  final int? estimatedDelaySeconds;
  final RouteCongestionAlert? closestCongestion;
  final List<RouteTrafficSegment> segments;
  final List<TrafficIncident> incidents;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final String source;

  const RouteTrafficAnalysis({
    required this.routeSignature,
    required this.routeCoordinates,
    required this.routeDistanceMeters,
    required this.remainingDistanceMeters,
    required this.courierIndex,
    required this.sampledPointsCount,
    required this.availableSamplesCount,
    required this.unknownSamplesCount,
    required this.congestedSegmentsCount,
    required this.hasCongestion,
    required this.hasRoadClosure,
    required this.overallStatus,
    required this.overallStatusLabel,
    this.estimatedDelaySeconds,
    this.closestCongestion,
    required this.segments,
    required this.incidents,
    required this.fetchedAt,
    required this.expiresAt,
    this.source = 'tomtom_live',
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
}

/// Langkah instruksi pada opsi rute alternatif TomTom Routing.
class TrafficRouteStepData {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String roadName;
  final String maneuverType;
  final LatLng location;

  const TrafficRouteStepData({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.roadName,
    required this.maneuverType,
    required this.location,
  });

  factory TrafficRouteStepData.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : <String, dynamic>{};
    return TrafficRouteStepData(
      instruction: (json['instruction'] ?? '').toString(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      roadName: (json['road_name'] ?? '').toString(),
      maneuverType: (json['maneuver_type'] ?? 'STRAIGHT').toString(),
      location: LatLng(
        (loc['lat'] as num?)?.toDouble() ?? 0.0,
        (loc['lng'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }
}

/// Opsi rute (utama maupun alternatif) dari TomTom Routing v1 berbasis kondisi lalu lintas.
class TrafficAlternativeRoute {
  final int routeIndex;
  final String label;
  final String? viaRoad;
  final double distanceMeters;
  final int travelTimeSeconds;
  final int? noTrafficTravelTimeSeconds;
  final int? trafficDelaySeconds;
  final int timeSavedSeconds;
  final int delayReductionSeconds;
  final bool isRecommended;
  final TrafficConditionLevel overallStatus;
  final String overallStatusLabel;
  final Color overallColor;
  final int congestedSegmentsCount;
  final List<LatLng> coordinates;
  final List<TrafficRouteStepData> steps;
  final List<RouteTrafficSegment> segments;

  const TrafficAlternativeRoute({
    required this.routeIndex,
    required this.label,
    this.viaRoad,
    required this.distanceMeters,
    required this.travelTimeSeconds,
    this.noTrafficTravelTimeSeconds,
    this.trafficDelaySeconds,
    required this.timeSavedSeconds,
    required this.delayReductionSeconds,
    required this.isRecommended,
    required this.overallStatus,
    required this.overallStatusLabel,
    required this.overallColor,
    required this.congestedSegmentsCount,
    required this.coordinates,
    required this.steps,
    required this.segments,
  });

  factory TrafficAlternativeRoute.fromJson(Map<String, dynamic> json) {
    final level =
        TrafficClassification.parseLevel(json['overall_status']?.toString());
    final color = switch (level) {
      TrafficConditionLevel.moderate => const Color(0xFFEAB308),
      TrafficConditionLevel.heavy => const Color(0xFFF97316),
      TrafficConditionLevel.congested || TrafficConditionLevel.roadClosed =>
        const Color(0xFFDC2626),
      TrafficConditionLevel.smooth => const Color(0xFF16A34A),
      TrafficConditionLevel.unknown => const Color(0xFF64748B),
    };

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

    final steps = (json['steps'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TrafficRouteStepData.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final segments = (json['segments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => RouteTrafficSegment.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final via = json['via_road']?.toString().trim();

    return TrafficAlternativeRoute(
      routeIndex: (json['route_index'] as num?)?.toInt() ?? 0,
      label: (json['label'] ?? 'Rute').toString(),
      viaRoad: (via != null && via.isNotEmpty) ? via : null,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      travelTimeSeconds: (json['travel_time_seconds'] as num?)?.toInt() ?? 0,
      noTrafficTravelTimeSeconds:
          (json['no_traffic_travel_time_seconds'] as num?)?.toInt(),
      trafficDelaySeconds: (json['traffic_delay_seconds'] as num?)?.toInt(),
      timeSavedSeconds: (json['time_saved_seconds'] as num?)?.toInt() ?? 0,
      delayReductionSeconds:
          (json['delay_reduction_seconds'] as num?)?.toInt() ?? 0,
      isRecommended: json['is_recommended'] == true,
      overallStatus: level,
      overallStatusLabel: (json['overall_status_label'] ?? 'Lancar').toString(),
      overallColor: color,
      congestedSegmentsCount:
          (json['congested_segments_count'] as num?)?.toInt() ?? 0,
      coordinates: coords,
      steps: steps,
      segments: segments,
    );
  }
}

class TrafficAlternativesResult {
  final String routingEngine;
  final String travelMode;
  final bool autoSwitch;
  final bool hasFasterAlternative;
  final int? recommendedRouteIndex;
  final List<TrafficAlternativeRoute> routes;
  final DateTime fetchedAt;
  final DateTime expiresAt;

  const TrafficAlternativesResult({
    required this.routingEngine,
    required this.travelMode,
    required this.autoSwitch,
    required this.hasFasterAlternative,
    this.recommendedRouteIndex,
    required this.routes,
    required this.fetchedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  TrafficAlternativeRoute? get recommendedRoute {
    final idx = recommendedRouteIndex;
    if (idx == null || idx < 0 || idx >= routes.length) return null;
    return routes[idx];
  }
}

/// Interface fondasi untuk ekspansi routing berbasis lalu lintas (misalnya TomTom Routing API)
/// di masa depan. Belum memiliki implementasi aktif karena routing masih OSRM OSM.
abstract class TrafficAwareRoutingHook {
  bool get isSupported;
  String get engineName;
}

class OsrmOnlyRoutingHook implements TrafficAwareRoutingHook {
  const OsrmOnlyRoutingHook();

  @override
  bool get isSupported => false;

  @override
  String get engineName => 'OSRM OpenStreetMap (non-traffic)';
}
