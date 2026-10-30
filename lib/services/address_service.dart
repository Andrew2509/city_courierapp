import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/token_store.dart';

class AddressService {
  static const String _baseUrl = 'https://www.neonflux.my.id/api';

  static Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStore.read();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all saved addresses for the logged-in user
  static Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/addresses'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('AddressService.getAddresses error: $e');
      return [];
    }
  }

  /// Save a new address
  static Future<Map<String, dynamic>?> saveAddress(
      Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/addresses'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('AddressService.saveAddress error: $e');
      return null;
    }
  }

  /// Update an existing address
  static Future<bool> updateAddress(
      int id, Map<String, dynamic> body) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/addresses/$id'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      print('AddressService.updateAddress error: $e');
      return false;
    }
  }

  /// Delete an address
  static Future<bool> deleteAddress(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/addresses/$id'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      print('AddressService.deleteAddress error: $e');
      return false;
    }
  }

  /// Toggle favorite status
  static Future<bool> toggleFavorite(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/addresses/$id/favorite'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      print('AddressService.toggleFavorite error: $e');
      return false;
    }
  }
}
