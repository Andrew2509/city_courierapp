import '../../data/models/address_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/map_config.dart';
import 'geocoding_service.dart';

/// Photon geocoding provider — used as fallback when Nominatim fails
/// or returns too few results (PRD §4, §5).
class PhotonGeocodingService implements GeocodingService {
  final http.Client client;

  PhotonGeocodingService({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<List<Address>> searchAddress(String query) async {
    final url = Uri.parse('${MapConfig.photonBaseUrl}/api').replace(queryParameters: {
      'q': query,
      'limit': '5',
      'lang': 'id',
    });

    try {
      final response = await client.get(url, headers: {
        'User-Agent': 'CityCourierApp/1.0',
      }).timeout(MapConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        return features.map((item) => _mapPhotonToAddress(item)).toList();
      }
    } catch (e) {
      // Photon failed — caller should handle
    }
    return [];
  }

  @override
  Future<Address?> reverseGeocode(double lat, double lng) async {
    // Photon supports reverse geocoding via /reverse endpoint
    final url = Uri.parse('${MapConfig.photonBaseUrl}/reverse').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'lang': 'id',
    });

    try {
      final response = await client.get(url, headers: {
        'User-Agent': 'CityCourierApp/1.0',
      }).timeout(MapConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          return _mapPhotonToAddress(data['features'][0]);
        }
      }
    } catch (e) {
      // Photon reverse failed
    }
    return null;
  }

  @override
  Future<Address?> getPlaceDetails(String placeId) async {
    return null;
  }

  Address _mapPhotonToAddress(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coords = geometry['coordinates'] as List<dynamic>? ?? [0, 0];

    // Photon uses GeoJSON: [longitude, latitude]
    final longitude = coords.isNotEmpty ? (coords[0] as num).toDouble() : 0.0;
    final latitude = coords.length > 1 ? (coords[1] as num).toDouble() : 0.0;

    // Build formatted address from available properties
    final parts = <String>[];
    final name = properties['name'] as String?;
    final street = properties['street'] as String?;
    final housenumber = properties['housenumber'] as String?;
    final city = properties['city'] as String?;
    final state = properties['state'] as String?;
    final postcode = properties['postcode'] as String?;

    if (street != null) {
      parts.add(housenumber != null ? '$street $housenumber' : street);
    } else if (name != null) {
      parts.add(name);
    }
    if (city != null) parts.add(city);

    return Address(
      placeId: feature['properties']?['osm_id']?.toString(),
      formattedAddress: parts.isNotEmpty ? parts.join(', ') : (name ?? 'Unknown'),
      houseNumber: housenumber,
      streetName: street ?? properties['name'] as String?,
      neighbourhood: properties['neighbourhood'] as String?,
      village: properties['village'] as String?,
      district: properties['district'] as String?,
      city: city,
      province: state,
      postalCode: postcode,
      country: properties['country'] as String?,
      latitude: latitude,
      longitude: longitude,
      locationSource: 'provider',
    );
  }
}
