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
