import '../../data/models/address_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/map_config.dart';
import 'geocoding_service.dart';

/// Photon geocoding provider — high performance search-as-you-type autocomplete
/// with proximity biasing and OpenStreetMap GeoJSON feature parsing.
class PhotonGeocodingService implements GeocodingService {
  final http.Client client;

  PhotonGeocodingService({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<List<Address>> searchAddress(
    String query, {
    double? latitude,
    double? longitude,
    int limit = 5,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'limit': limit.toString(),
      'lang': 'id',
    };

    if (latitude != null && longitude != null) {
      queryParams['lat'] = latitude.toString();
      queryParams['lon'] = longitude.toString();
    }

    final url = Uri.parse('${MapConfig.photonBaseUrl}/api').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await client.get(url, headers: {
        'User-Agent': 'CityCourierApp/1.0 (contact: developer@citycourier.com)',
        'Accept': 'application/json',
      }).timeout(MapConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
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
        'User-Agent': 'CityCourierApp/1.0 (contact: developer@citycourier.com)',
        'Accept': 'application/json',
      }).timeout(MapConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
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

    final name = properties['name'] as String?;
    final street = properties['street'] as String?;
    final housenumber = properties['housenumber'] as String?;
    final village = (properties['locality'] ??
            properties['village'] ??
            properties['suburb'] ??
            properties['neighbourhood'])
        as String?;
    final district = properties['district'] as String?;
    final city = (properties['city'] ?? properties['county']) as String?;
    final state = properties['state'] as String?;
    final postcode = properties['postcode'] as String?;
    final country = properties['country'] as String? ?? 'Indonesia';

    // Build formatted address carefully without fabricating nonexistent numbers
    final addressParts = <String>[];

    // 1. Specific location / POI name or street
    if (name != null && name.trim().isNotEmpty) {
      if (street != null && street.trim().isNotEmpty && name.toLowerCase() != street.toLowerCase()) {
        final streetPart = housenumber != null && housenumber.trim().isNotEmpty
            ? '$street No. $housenumber'
            : street;
        addressParts.add('$name, $streetPart');
      } else {
        final namePart = housenumber != null && housenumber.trim().isNotEmpty
            ? '$name No. $housenumber'
            : name;
        addressParts.add(namePart);
      }
    } else if (street != null && street.trim().isNotEmpty) {
      final streetPart = housenumber != null && housenumber.trim().isNotEmpty
          ? '$street No. $housenumber'
          : street;
      addressParts.add(streetPart);
    }

    // 2. Village / Kelurahan
    if (village != null && village.trim().isNotEmpty) {
      addressParts.add(village.trim());
    }

    // 3. District / Kecamatan
    if (district != null && district.trim().isNotEmpty) {
      addressParts.add('Kec. ${district.trim()}');
    }

    // 4. City / Kabupaten
    if (city != null && city.trim().isNotEmpty) {
      addressParts.add(city.trim());
    }

    // 5. Province
    if (state != null && state.trim().isNotEmpty) {
      addressParts.add(state.trim());
    }

    // 6. Postcode
    if (postcode != null && postcode.trim().isNotEmpty) {
      addressParts.add(postcode.trim());
    }

    final formattedAddress = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : (name ?? 'Titik Lokasi');

    return Address(
      placeId: properties['osm_id']?.toString(),
      osmType: properties['osm_type']?.toString(),
      osmId: properties['osm_id']?.toString(),
      formattedAddress: formattedAddress,
      houseNumber: housenumber,
      streetName: street ?? name,
      neighbourhood: properties['neighbourhood'] as String?,
      village: village,
      district: district,
      city: city,
      province: state,
      postalCode: postcode,
      country: country,
      latitude: latitude,
      longitude: longitude,
      locationSource: 'provider',
    );
  }
}
