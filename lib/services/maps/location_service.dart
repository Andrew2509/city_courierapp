import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// GPS location result with accuracy metadata (PRD §18).
class GpsPosition {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;
  bool isAccurate;

  GpsPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    this.isAccurate = true,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}

abstract class LocationService {
  Future<GpsPosition?> getCurrentLocation();
  Stream<LatLng> startTracking();
  Future<bool> handleLocationPermission();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  @override
  Future<GpsPosition?> getCurrentLocation() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return null;

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final gpsPos = GpsPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );

      // Mark as inaccurate if accuracy is poor (PRD §18)
      if (position.accuracy > 80.0) {
        gpsPos.isAccurate = false;
      }

      return gpsPos;
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<LatLng> startTracking() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((Position position) => LatLng(position.latitude, position.longitude));
  }
}
