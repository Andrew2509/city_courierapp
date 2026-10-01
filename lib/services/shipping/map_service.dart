import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_service.dart';
import '../token_store.dart';

class MapService {
  // Menggunakan baseUrl yang sama dengan ApiService
  static String get baseUrl => ApiService.baseUrl;

  /**
   * Helper untuk mendapatkan headers otentikasi Bearer token
   */
  static Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStore.read();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /**
   * 1. Mengambil Autocomplete POI (Pencarian Lokasi)
   * GET /shipping/map/autocomplete
   *
   * @param query Kata kunci pencarian (min 2 karakter)
   * @param proximity Opsional koordinat kedekatan "lng,lat"
   */
  static Future<List<dynamic>> searchAutocomplete(String query, {String? proximity}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/shipping/map/autocomplete').replace(
        queryParameters: {
          'q': query,
          if (proximity != null) 'proximity': proximity,
        },
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Error searchAutocomplete: $e');
      return [];
    }
  }

  /**
   * 2. Mengambil Rute Point-to-Point (Directions)
   * POST /shipping/map/routing
   *
   * @param origin Titik awal "lng,lat"
   * @param destination Titik tujuan "lng,lat"
   * @param vias Titik antara (waypoints)
   */
  static Future<Map<String, dynamic>?> getRouting(
    String origin,
    String destination, {
    List<String> vias = const [],
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'origin': origin,
        'destination': destination,
        if (vias.isNotEmpty) 'vias': vias,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/shipping/map/routing'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getRouting: $e');
      return null;
    }
  }

  /**
   * 3. Menghitung Matriks Jarak & Durasi Multi-Titik
   * POST /shipping/map/matrix
   *
   * @param coordinates List koordinat ["lng,lat", "lng,lat", ...]
   */
  static Future<Map<String, dynamic>?> getMatrix(List<String> coordinates) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'coordinates': coordinates,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/shipping/map/matrix'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getMatrix: $e');
      return null;
    }
  }

  /**
   * 4. Mendapatkan Endpoint Vector Peta (Style JSON)
   * GET /shipping/map/styles/{name}.json
   *
   * Memberikan URL penuh yang di-proxy via Laravel.
   */
  static String getStyleUrl(String styleName) {
    return '$baseUrl/shipping/map/styles/$styleName.json';
  }
}
