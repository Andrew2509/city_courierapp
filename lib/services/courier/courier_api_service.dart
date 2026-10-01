import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class CourierApiService {
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

  static Future<Map<String, dynamic>> getCourierStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courier/details'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'status': data['data']['work_status'] ?? 'offline',
          'data': data['data'],
        };
      }
      return {'success': false, 'status': 'offline'};
    } catch (e) {
      return {'success': false, 'status': 'offline'};
    }
  }

  static Future<Map<String, dynamic>> updateCourierStatus({
    required String status,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final body = {
        'status': status,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/courier/status'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal update status'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateCourierLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speedKmh,
    int? batteryPercent,
  }) async {
    try {
      final body = {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speedKmh != null) 'speed_kmh': speedKmh,
        if (batteryPercent != null) 'battery_percent': batteryPercent,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/courier/location'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  static Future<Map<String, dynamic>> getCourierStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courier/stats'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal mengambil stats'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
