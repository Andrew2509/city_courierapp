 import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class CourierRegistrationService {
  static String get baseUrl => ApiService.baseUrl;

  /// Normalisasi nomor HP ke format internasional (62...), hanya digit.
  /// Dipakai untuk request & verify OTP agar cache key di backend konsisten.
  static String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (!digits.startsWith('62')) {
      digits = '62$digits';
    }
    return digits;
  }

  /// Minta kode OTP pendaftaran kurir (6 digit) via WhatsApp/Fonnte.
  static Future<Map<String, dynamic>> requestPhoneOtp(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/courier/request-phone-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'phone': normalizePhone(phone)}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? 'Gagal mengirim kode verifikasi.',
        'errors': data['errors'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. ${e.toString()}',
      };
    }
  }

  /// Verifikasi kode OTP pendaftaran kurir.
  static Future<Map<String, dynamic>> verifyPhoneOtp(
    String phone,
    String otp,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/courier/verify-phone-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'phone': normalizePhone(phone),
              'otp': otp,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? 'Verifikasi gagal.',
        'data': data['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. ${e.toString()}',
      };
    }
  }

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
