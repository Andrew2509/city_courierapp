import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class RajaOngkirService {
  static String get baseUrl => ApiService.baseUrl;

  @visibleForTesting
  static Future<http.Response> Function(
    Uri uri,
    Map<String, String> headers,
  )? httpGetOverride;

  static Future<String?> _getToken() async => TokenStore.read();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _normalizeResponse(
    http.Response response, {
    required String fallbackError,
  }) {
    Map<String, dynamic>? map;
    if (response.body.isNotEmpty) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    if (response.statusCode >= 400) {
      final result = map ?? <String, dynamic>{};
      result['success'] = false;
      result['status_code'] = response.statusCode;
      if (response.statusCode == 401) {
        result['message'] =
            'Akses data wilayah belum diizinkan tanpa login. Silakan masuk terlebih dahulu atau coba lagi nanti.';
      } else {
        result['message'] ??= '$fallbackError (${response.statusCode})';
      }
      return result;
    }

    if (map != null) {
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
      'message': '$fallbackError (${response.statusCode})',
    };
  }

  static Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required String fallbackError,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = httpGetOverride != null
          ? await httpGetOverride!(uri, headers)
          : await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));

      return _normalizeResponse(response, fallbackError: fallbackError);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getProvinces() {
    return _getJson(
      Uri.parse('$baseUrl/shipping/provinces'),
      fallbackError: 'Gagal mengambil data provinsi',
    );
  }

  static Future<Map<String, dynamic>> getCities(int provinceId) {
    return _getJson(
      Uri.parse('$baseUrl/shipping/cities?province_id=$provinceId'),
      fallbackError: 'Gagal mengambil data kota/kabupaten',
    );
  }

  static Future<Map<String, dynamic>> getDistricts(int cityId) {
    return _getJson(
      Uri.parse('$baseUrl/shipping/districts?city_id=$cityId'),
      fallbackError: 'Gagal mengambil data kecamatan',
    );
  }

  static Future<Map<String, dynamic>> getSubdistricts(int districtId) {
    return _getJson(
      Uri.parse('$baseUrl/shipping/subdistricts?district_id=$districtId'),
      fallbackError: 'Gagal mengambil data kelurahan/desa',
    );
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

      return _normalizeResponse(
        response,
        fallbackError: 'Respons tarif tidak valid',
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    return _getJson(
      Uri.parse('$baseUrl/geocoding/reverse?lat=$latitude&lng=$longitude'),
      fallbackError: 'Gagal mendeteksi alamat dari koordinat',
    );
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
