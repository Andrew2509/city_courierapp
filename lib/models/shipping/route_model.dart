import 'package:latlong2/latlong.dart';

/// Representasi rute hasil routing engine (PRD §37).
///
/// Geometry selalu berasal dari routing engine — bukan garis lurus antara
/// dua koordinat (origin & destination).
class RouteModel {
  final List<LatLng> coordinates;
  final double distanceMeters;
  final double durationSeconds;
  final double? trafficDurationSeconds;
  final String? summary;
  final List<RouteStep> steps;

  const RouteModel({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
    this.trafficDurationSeconds,
    this.summary,
    this.steps = const [],
  });
}

/// Instruksi navigasi (turn-by-turn) dalam satu rute.
class RouteStep {
  final String instruction;
  final String? maneuver;
  final String? roadName;
  final double distanceMeters;
  final double durationSeconds;

  const RouteStep({
    required this.instruction,
    this.maneuver,
    this.roadName,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
  });
}