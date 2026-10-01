import '../../data/models/route_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/map_config.dart';

abstract class RoutingService {
  Future<RouteModel?> calculateRoute(LatLng origin, LatLng destination);
}

class OSRMRoutingService implements RoutingService {
  final http.Client client;

  OSRMRoutingService({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<RouteModel?> calculateRoute(LatLng origin, LatLng destination) async {
    final String coords = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse('${MapConfig.osrmBaseUrl}/route/v1/driving/$coords').replace(queryParameters: {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'true',
      'alternatives': 'false', // Change to true if alternative routes are needed
    });

    try {
      final response = await client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final routeData = data['routes'][0];
          
          return _parseRoute(routeData);
        }
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  RouteModel _parseRoute(Map<String, dynamic> routeData) {
    final geometry = routeData['geometry'];
    final List<LatLng> coordinates = [];
    
    if (geometry != null && geometry['type'] == 'LineString') {
      final coords = geometry['coordinates'] as List;
      for (var coord in coords) {
        // GeoJSON uses [longitude, latitude]
        coordinates.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
      }
    }

    final distance = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (routeData['duration'] as num?)?.toDouble() ?? 0.0;
    
    final List<RouteStep> steps = [];
    if (routeData['legs'] != null && routeData['legs'].isNotEmpty) {
      final leg = routeData['legs'][0];
      if (leg['steps'] != null) {
        for (var step in leg['steps']) {
          final location = step['maneuver']['location'] as List;
          steps.add(RouteStep(
            instruction: step['maneuver']['type'] ?? '',
            roadName: step['name'],
            distance: (step['distance'] as num?)?.toDouble() ?? 0.0,
            duration: (step['duration'] as num?)?.toDouble() ?? 0.0,
            maneuver: step['maneuver']['modifier'],
            coordinate: LatLng(location[1].toDouble(), location[0].toDouble()),
          ));
        }
      }
    }

    return RouteModel(
      coordinates: coordinates,
      distance: distance,
      duration: duration,
      summary: routeData['legs']?[0]?['summary'] ?? '',
      steps: steps,
    );
  }
}
