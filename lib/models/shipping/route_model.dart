import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/models/maps/traffic_models.dart';

/// Representasi rute hasil routing engine (PRD §37).
///
/// Geometry selalu berasal dari routing engine — bukan garis lurus antara
/// dua koordinat (origin & destination).
class RouteModel {
  final List<LatLng> coordinates;
  final double distanceMeters;
  final double durationSeconds;
  final double? trafficDurationSeconds;
  final int? trafficDelaySeconds;
  final String? summary;
  final String provider;
  final List<RouteStep> steps;
  final List<RouteTrafficSegment> trafficSegments;

  const RouteModel({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
    this.trafficDurationSeconds,
    this.trafficDelaySeconds,
    this.summary,
    this.provider = 'unknown',
    this.steps = const [],
    this.trafficSegments = const [],
  });
}

/// Instruksi navigasi (turn-by-turn) dalam satu rute.
class RouteStep {
  final String instruction;
  final String? maneuver;
  final String? roadName;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng? location;
  final double? routeOffsetMeters;
  final int? roundaboutExitNumber;
  final bool isTomTomStep;

  const RouteStep({
    required this.instruction,
    this.maneuver,
    this.roadName,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.location,
    this.routeOffsetMeters,
    this.roundaboutExitNumber,
    this.isTomTomStep = false,
  });
}