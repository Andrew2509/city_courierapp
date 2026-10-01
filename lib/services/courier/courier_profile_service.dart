import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class CourierProfileService {
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

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courier/profile'),
        headers: await _getHeaders(),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'data': responseData['data'],
        };
      }
      return {
        'success': false,
        'message': responseData['message'] ?? 'Gagal mengambil profil'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateWorkStatus(String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/courier/status'),
        headers: await _getHeaders(),
        body: json.encode({'status': status}),
      );

      final responseData = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && responseData['success'] == true,
        'message': responseData['message'] ?? 'Gagal memperbarui status',
        'data': responseData['data'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<bool> updateProfile({
    required String name,
    String? phone,
    String? email,
    String? nik,
    String? address,
    String? city,
    String? vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleColor,
    String? vehicleYear,
    String? photoPath,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$baseUrl/courier/profile');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      request.fields['name'] = name;
      if (phone != null) request.fields['phone'] = phone;
      if (email != null) request.fields['email'] = email;
      if (nik != null) request.fields['nik'] = nik;
      if (address != null) request.fields['address'] = address;
      if (city != null) request.fields['city'] = city;
      if (vehicleType != null) request.fields['vehicle_type'] = vehicleType;
      if (vehicleBrand != null) request.fields['vehicle_brand'] = vehicleBrand;
      if (vehicleModel != null) request.fields['vehicle_model'] = vehicleModel;
      if (vehiclePlate != null) request.fields['vehicle_plate'] = vehiclePlate;
      if (vehicleColor != null) request.fields['vehicle_color'] = vehicleColor;
      if (vehicleYear != null) request.fields['vehicle_year'] = vehicleYear;

      if (photoPath != null && photoPath.isNotEmpty) {
        final file = File(photoPath);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('photo', photoPath),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      return response.statusCode == 200 && responseData['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
