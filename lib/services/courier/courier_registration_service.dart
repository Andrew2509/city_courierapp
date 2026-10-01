 import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class CourierRegistrationService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String nik,
    required String phone,
    required String address,
    required String city,
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleYear,
    required String vehiclePlate,
    required String photoPath,
    required String idCardPath,
    required String licensePath,
    String? skckPath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/register-kurir');
      final request = http.MultipartRequest('POST', uri);

      final token = await TokenStore.read();

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      // User data
      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['password_confirmation'] = passwordConfirmation;

      // Courier data
      request.fields['nik'] = nik;
      request.fields['phone'] = phone;
      request.fields['address'] = address;
      request.fields['city'] = city;
      request.fields['vehicle_type'] = vehicleType.toLowerCase();
      request.fields['vehicle_brand'] = vehicleBrand;
      request.fields['vehicle_year'] = vehicleYear;
      request.fields['vehicle_plate'] = vehiclePlate;

      // Files
      request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      request.files.add(await http.MultipartFile.fromPath('id_card_photo', idCardPath));
      request.files.add(await http.MultipartFile.fromPath('driving_license_photo', licensePath));
      
      if (skckPath != null && skckPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('skck_photo', skckPath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      return {
        'success': response.statusCode == 201 && responseData['success'] == true,
        'message': responseData['message'] ?? (response.statusCode == 201 ? 'Registrasi Berhasil' : 'Registrasi Gagal'),
        'data': responseData['data'],
        'errors': responseData['errors'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
