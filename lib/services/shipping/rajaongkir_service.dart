import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class RajaOngkirService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async => TokenStore.read();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> getProvinces() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipping/provinces'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getCities(int provinceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipping/cities?province_id=$provinceId'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDistricts(int cityId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipping/districts?city_id=$cityId'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getSubdistricts(int districtId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipping/subdistricts?district_id=$districtId'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> calculateCost({
    required String origin,
    required String destination,
    required int weight,
    required String courier,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/shipping/cost'),
            headers: await _getHeaders(),
            body: json.encode({
              'origin': origin,
              'destination': destination,
              'weight': weight,
              'courier': courier,
            }),
          )
          .timeout(const Duration(seconds: 20));

      dynamic decoded;
      try {
        decoded = response.body.isNotEmpty ? json.decode(response.body) : null;
      } catch (_) {
        decoded = null;
      }

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (response.statusCode >= 400) {
          map['success'] = false;
          map['status_code'] = response.statusCode;
          map['message'] ??=
              response.statusCode == 401
                  ? 'Sesi login berakhir. Silakan masuk kembali.'
                  : 'Server mengembalikan status ${response.statusCode}';
          return map;
        }
        final ro = map['rajaongkir'];
        if (map['success'] == null &&
            ro is Map &&
            ro['status'] is Map &&
            ro['status']['code'] == 200) {
          return {
            'success': true,
            'data': ro['results'],
            ...map,
          };
        }
        return map;
      }

      return {
        'success': false,
        'status_code': response.statusCode,
        'message': response.statusCode == 401
            ? 'Sesi login berakhir. Silakan masuk kembali.'
            : 'Respons tarif tidak valid (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/geocoding/reverse?lat=$latitude&lng=$longitude'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> matchRegion({
    required double latitude,
    required double longitude,
    String? fullAddress,
    String? village,
    String? district,
    String? city,
    String? province,
    String? postalCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shipping/match-region'),
        headers: await _getHeaders(),
        body: json.encode({
          'lat': latitude,
          'lng': longitude,
          // ignore: use_null_aware_elements
          if (fullAddress != null) 'formatted_address': fullAddress,
          // ignore: use_null_aware_elements
          if (village != null) 'village': village,
          // ignore: use_null_aware_elements
          if (district != null) 'district': district,
          // ignore: use_null_aware_elements
          if (city != null) 'city': city,
          // ignore: use_null_aware_elements
          if (province != null) 'province': province,
          // ignore: use_null_aware_elements
          if (postalCode != null) 'postal_code': postalCode,
        }),
      ).timeout(const Duration(seconds: 6));

      return json.decode(response.body);
    } catch (e) {
      return {'matched': false, 'message': e.toString()};
    }
  }
}
