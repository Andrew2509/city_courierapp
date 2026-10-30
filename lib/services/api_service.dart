import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/services/auth_service.dart';

class ApiService {
  // Gunakan 10.0.2.2 untuk Android Emulator, 127.0.0.1 untuk iOS Simulator / Web
  static const String baseUrl = 'https://www.neonflux.my.id/api';

  static Future<Map<String, dynamic>?> requestOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengirim OTP.',
      };
    } catch (e) {
      print('Error requestOtp: $e');
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server.',
      };
    }
  }

  static Future<Map<String, dynamic>?> verifyOtp(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final token = data['data']['token'];
          await TokenStore.save(token);
          return data['data']; // Return full data including user role and courier info
        }
      }
      return null;
    } catch (e) {
      print('Error verifyOtp: $e');
      return null;
    }
  }

  static Future<bool> loginWithPhone(String idToken) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/phone');
      print('ApiService: Attempting POST to $uri');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 30));

      print('ApiService: Response status: ${response.statusCode}');
      print('ApiService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final token = data['data']['token'];

          await TokenStore.save(token);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error loginWithPhone: $e');
      return false;
    }
  }

  static Future<bool> loginWithGoogle(String idToken, {String? photoUrl}) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/google');
      print('ApiService: Attempting POST to $uri');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': idToken,
              'photo_url': photoUrl,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('ApiService: Response status: ${response.statusCode}');
      print('ApiService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final token = data['data']['token'];

          await TokenStore.save(token);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error loginWithGoogle: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final token = await TokenStore.read();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Error getProfile: $e');
      return null;
    }
  }

  static Future<bool> updateProfile(
    String name,
    String email, {
    String? phone,
    String? address,
    String? photoPath,
  }) async {
    try {
      final token = await TokenStore.read();

      if (token == null) return false;

      final uri = Uri.parse('$baseUrl/profile/update');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['name'] = name;
      request.fields['email'] = email;
      if (phone != null) request.fields['phone'] = phone;
      if (address != null) request.fields['address'] = address;

      if (photoPath != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error updateProfile: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await TokenStore.clear();
    try {
      await AuthService.signOut().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () {},
      );
    } catch (_) {}
  }

  static Future<List<dynamic>> getDropPoints() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/drop-points'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['status'] == 'success') {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      print('Error getDropPoints: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> trackShipment(String number) async {
    try {
      final token = await TokenStore.read();

      final response = await http.get(
        Uri.parse('$baseUrl/shipments/track/$number'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error trackShipment: $e');
      return null;
    }
  }

  /// Generic authenticated POST helper.
  /// Returns decoded JSON map or error structure on failure.
  static Future<Map<String, dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    try {
      final token = await TokenStore.read();

      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      Map<String, dynamic>? decodedBody;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          decodedBody = parsed;
        }
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedBody ?? {'success': true};
      }

      print('ApiService.post error ${response.statusCode}: ${response.body}');
      if (decodedBody != null) {
        return decodedBody;
      }

      return {
        'success': false,
        'status_code': response.statusCode,
        'message': 'Gagal memproses permintaan (Kode ${response.statusCode})',
      };
    } on TimeoutException catch (e) {
      print('ApiService.post exception: TimeoutException on $endpoint after ${timeout.inSeconds}s: $e');
      return {
        'success': false,
        'is_timeout': true,
        'message': 'Koneksi ke server timeout (${timeout.inSeconds} detik). Server membutuhkan waktu lebih lama untuk memproses pesanan.',
      };
    } catch (e) {
      print('ApiService.post exception: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan jaringan: $e',
      };
    }
  }

  static Future<Map<String, dynamic>?> getSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getSettings: $e');
      return null;
    }
  }
}
