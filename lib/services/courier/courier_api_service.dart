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
        final payload = data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        return {
          'success': true,
          'status': payload['work_status'] ?? 'offline',
          'data': payload,
          'statusCode': response.statusCode,
        };
      }
      return {
        'success': false,
        'status': 'offline',
        'message': data is Map ? data['message'] : null,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'status': 'offline', 'message': e.toString()};
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
        'latitude': ?latitude,
        'longitude': ?longitude,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/courier/status'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      final data = response.body.isNotEmpty
          ? (json.decode(response.body) as Map<String, dynamic>)
          : <String, dynamic>{};
      final bool isSuccess =
          response.statusCode == 200 && data['success'] == true;

      return {
        'success': isSuccess,
        'data': data['data'],
        'error_code': data['error_code'],
        'message':
            data['message'] ?? (isSuccess ? 'Status berhasil diperbarui.' : 'Gagal update status'),
        'statusCode': response.statusCode,
      };
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
        'accuracy': ?accuracy,
        'speed_kmh': ?speedKmh,
        'battery_percent': ?batteryPercent,
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
