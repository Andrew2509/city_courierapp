import '../../data/models/address_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_service.dart';
import 'geocoding_service.dart';

/// Geocoding service that proxies through the Laravel backend.
///
/// Backend handles Nominatim → Photon fallback + caching.
/// Flutter just calls the API and receives pre-processed results.
///
/// Architecture:
///   Flutter → Backend API (www.neonflux.my.id/api/geocoding/*)
///            → Nominatim → Photon → merged results
class BackendGeocodingService implements GeocodingService {
  final http.Client client;

  // Backend base URL (same as ApiService)
  static String get _baseUrl => ApiService.baseUrl;

  BackendGeocodingService({http.Client? client})
      : client = client ?? http.Client();

  // ── Search / Forward Geocoding ─────────────────────────────────────
  @override
  Future<List<Address>> searchAddress(
    String query, {
    double? latitude,
    double? longitude,
    int limit = 5,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': query,
        'limit': limit.toString(),
      };
      if (latitude != null && longitude != null) {
        queryParams['lat'] = latitude.toString();
        queryParams['lng'] = longitude.toString();
      }

      final uri = Uri.parse('$_baseUrl/geocoding/search').replace(
        queryParameters: queryParams,
      );

      final response = await client
          .get(uri, headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> items = data['data'];
          return items.map((item) => _mapToAddress(item)).toList();
        }
      }
    } catch (e) {
      // Backend geocoding failed — return empty
    }
    return [];
  }

  // ── Reverse Geocoding ──────────────────────────────────────────────
  @override
  Future<Address?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('$_baseUrl/geocoding/reverse').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
        },
      );

      final response = await client
          .get(uri, headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _mapToAddress(data['data']);
        }
      }
    } catch (e) {
      // Backend reverse geocoding failed
    }
    return null;
  }

  // ── Place Details (not implemented via backend) ─────────────────────
  @override
  Future<Address?> getPlaceDetails(String placeId) async {
    return null;
  }

  // ── Map backend JSON to Address model ──────────────────────────────
  Address _mapToAddress(Map<String, dynamic> data) {
    return Address(
      placeId: data['place_id']?.toString(),
      osmType: data['osm_type'],
      osmId: data['osm_id']?.toString(),
      formattedAddress: data['formatted_address'] ?? '',
      houseNumber: data['house_number'],
      streetName: data['street_name'],
      neighbourhood: data['neighbourhood'],
      village: data['village'],
      district: data['district'],
      city: data['city'],
      province: data['province'],
      postalCode: data['postal_code'],
      country: data['country'],
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      locationSource: data['location_source'] ?? 'provider',
    );
  }
}
