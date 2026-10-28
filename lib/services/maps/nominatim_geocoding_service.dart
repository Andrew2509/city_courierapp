import '../../data/models/address_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/map_config.dart';
import 'geocoding_service.dart';

/// Primary geocoding provider using Nominatim (PRD §4).
///
/// Handles forward geocoding (search) and reverse geocoding.
class NominatimGeocodingService implements GeocodingService {
  final http.Client client;

  NominatimGeocodingService({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<List<Address>> searchAddress(String query) async {
    final url = Uri.parse('${MapConfig.nominatimBaseUrl}/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '5',
    });

    try {
      final response = await client.get(url, headers: {
        'User-Agent': 'CityCourierApp/1.0',
      }).timeout(MapConfig.networkTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => _mapNominatimToAddress(item)).toList();
      }
    } catch (e) {
      // Nominatim search failed — caller should fallback to Photon
    }
    return [];
  }

  @override
  Future<Address?> reverseGeocode(double lat, double lng) async {
    final url = Uri.parse('${MapConfig.nominatimBaseUrl}/reverse').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'json',
      'addressdetails': '1',
    });

    try {
      final response = await client.get(url, headers: {
        'User-Agent': 'CityCourierApp/1.0',
      }).timeout(MapConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] != null) return null;
        return _mapNominatimToAddress(data);
      }
    } catch (e) {
      // Nominatim reverse failed — caller should fallback to Photon
    }
    return null;
  }

  @override
  Future<Address?> getPlaceDetails(String placeId) async {
    return null;
  }

  Address _mapNominatimToAddress(Map<String, dynamic> data) {
    final addressDetails = data['address'] as Map<String, dynamic>? ?? {};

    return Address(
      placeId: data['place_id']?.toString(),
      osmType: data['osm_type'],
      osmId: data['osm_id']?.toString(),
      formattedAddress: data['display_name'] ?? '',
      houseNumber: addressDetails['house_number'],
      streetName: addressDetails['road'] ?? addressDetails['pedestrian'] ?? addressDetails['path'],
      neighbourhood: addressDetails['neighbourhood'] ?? addressDetails['suburb'],
      village: addressDetails['village'] ?? addressDetails['suburb'] ?? addressDetails['quarter'] ?? addressDetails['neighbourhood'],
      district: addressDetails['city_district'] ?? addressDetails['district'] ?? addressDetails['subdistrict'] ?? addressDetails['municipality'],
      city: addressDetails['city'] ?? addressDetails['town'] ?? addressDetails['county'] ?? addressDetails['municipality'],
      province: addressDetails['state'] ?? addressDetails['province'],
      postalCode: addressDetails['postcode'],
      country: addressDetails['country'],
      latitude: double.tryParse(data['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(data['lon']?.toString() ?? '0') ?? 0.0,
      locationSource: 'provider',
    );
  }
}
