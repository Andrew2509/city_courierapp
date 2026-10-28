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
      final response = await http.post(
        Uri.parse('$baseUrl/shipping/cost'),
        headers: await _getHeaders(),
        body: json.encode({
          'origin': origin,
          'destination': destination,
          'weight': weight,
          'courier': courier,
        }),
      );

      return json.decode(response.body);
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
}
