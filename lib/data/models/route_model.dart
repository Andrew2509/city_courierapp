import 'package:latlong2/latlong.dart';

class RouteModel {
  final List<LatLng> coordinates;
  final double distance; // in meters
  final double duration; // in seconds
  final double? trafficDuration; // optional
  final String summary;
  final List<RouteStep> steps;
  final List<RouteModel> alternativeRoutes;

  RouteModel({
    required this.coordinates,
    required this.distance,
    required this.duration,
    this.trafficDuration,
    required this.summary,
    this.steps = const [],
    this.alternativeRoutes = const [],
  });
}

class RouteStep {
  final String instruction;
  final String? roadName;
  final double distance; // in meters
  final double duration; // in seconds
  final String? maneuver;
  final LatLng coordinate;

  RouteStep({
    required this.instruction,
    this.roadName,
    required this.distance,
    required this.duration,
    this.maneuver,
    required this.coordinate,
  });
}
