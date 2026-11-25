import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/services/auth_service.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:city_courierapp/services/security/device_metadata_service.dart';

class ApiService {
  // Gunakan 10.0.2.2 untuk Android Emulator, 127.0.0.1 untuk iOS Simulator / Web
  static const String baseUrl = 'https://www.neonflux.my.id/api';

  static Future<Map<String, dynamic>> requestOtp(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/request-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeBody(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          if (data['message'] != null) 'message': data['message'],
          if (data['retry_after'] != null) 'retry_after': data['retry_after'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengirim OTP.',
        if (data['code'] != null) 'code': data['code'],
        if (data['retry_after'] != null) 'retry_after': data['retry_after'],
      };
    } catch (e) {
      print('Error requestOtp: $e');
      return {'success': false, 'message': 'Tidak dapat terhubung ke server.'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp,
  ) async {
    try {
      final deviceHeaders = await DeviceMetadataService.getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...deviceHeaders,
            },
            body: jsonEncode({'phone': phone, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeBody(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final token = payload['token'];
          if (token is String && token.isNotEmpty) {
            await TokenStore.save(token);
          }
          // Return full data including user role and courier info.
          return {'success': true, ...payload};
        }
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Kode OTP salah atau telah kadaluarsa.',
        if (data['code'] != null) 'code': data['code'],
      };
    } catch (e) {
      print('Error verifyOtp: $e');
      return {'success': false, 'message': 'Tidak dapat terhubung ke server.'};
    }
  }

  /// Decode body JSON tanpa pernah melempar error ke UI.
  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Abaikan body non-JSON (mis. halaman error HTML dari server).
    }
    return <String, dynamic>{};
  }

  static Future<bool> loginWithPhone(String idToken) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/phone');
      print('ApiService: Attempting POST to $uri');

      final deviceHeaders = await DeviceMetadataService.getHeaders();
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...deviceHeaders,
            },
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

  /// Login/registrasi Google. Mengembalikan status kelengkapan profil dari
  /// backend, bukan hanya true/false.
  static Future<Map<String, dynamic>> loginWithGoogle(
    String idToken, {
    String? photoUrl,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/google');

      final deviceHeaders = await DeviceMetadataService.getHeaders();
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...deviceHeaders,
            },
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeBody(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final token = payload['token'];
          if (token is String && token.isNotEmpty) {
            await TokenStore.save(token);
          }

          return {
            'success': true,
            'message': data['message'] ?? 'Login Google berhasil.',
            'user': payload['user'],
            'profile_completed': payload['profile_completed'] ?? false,
            'requires_profile_completion':
                payload['requires_profile_completion'] ?? true,
            'missing_profile_fields': payload['missing_profile_fields'] ?? [],
            'phone_verified': payload['phone_verified'] ?? false,
          };
        }
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Gagal masuk dengan Google.',
        if (data['code'] != null) 'code': data['code'],
      };
    } catch (e) {
      print('Error loginWithGoogle: $e');
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Silakan coba lagi.',
      };
    }
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final token = await TokenStore.read();

      if (token == null) return null;

      final deviceHeaders = await DeviceMetadataService.getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          ...deviceHeaders,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      if (response.statusCode == 401) {
        await TokenStore.clear();
        await BiometricGuardService.clearSessionUnlock(clearPreference: true);
      }
      return null;
    } catch (e) {
      print('Error getProfile: $e');
      return null;
    }
  }

  /// Simpan profil (nama, email opsional, alamat, foto). Nomor telepon tidak
  /// pernah dikirim di sini karena harus lewat verifikasi OTP backend.
  static Future<Map<String, dynamic>> updateProfileResult({
    required String name,
    String? email,
    String? address,
    String? photoPath,
  }) async {
    try {
      final token = await TokenStore.read();

      if (token == null) {
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir. Silakan masuk kembali.',
        };
      }

      final uri = Uri.parse('$baseUrl/profile/update');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['name'] = name;
      if (email != null && email.trim().isNotEmpty) {
        request.fields['email'] = email.trim();
      }
      if (address != null) request.fields['address'] = address;

      if (photoPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photoPath),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = _decodeBody(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Profil berhasil diperbarui.',
          'data': data['data'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memperbarui profil.',
        if (data['code'] != null) 'code': data['code'],
      };
    } catch (e) {
      print('Error updateProfileResult: $e');
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Silakan coba lagi.',
      };
    }
  }

  static Future<bool> updateProfile(
    String name,
    String email, {
    String? phone,
    String? address,
    String? photoPath,
  }) async {
    final result = await updateProfileResult(
      name: name,
      email: email,
      address: address,
      photoPath: photoPath,
    );

    return result['success'] == true;
  }

  /// Kirim OTP untuk memverifikasi nomor telepon akun yang sedang login.
  static Future<Map<String, dynamic>> requestPhoneOtp(String phone) async {
    try {
      final token = await TokenStore.read();

      if (token == null) {
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir. Silakan masuk kembali.',
        };
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/profile/phone/request-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeBody(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message':
              data['message'] ??
              'Kode OTP telah dikirim ke nomor telepon Anda.',
          'retry_after': data['retry_after'] ?? 60,
          'already_verified': data['already_verified'] ?? false,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengirim kode OTP.',
        if (data['code'] != null) 'code': data['code'],
        if (data['retry_after'] != null) 'retry_after': data['retry_after'],
      };
    } catch (e) {
      print('Error requestPhoneOtp: $e');
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Silakan coba lagi.',
      };
    }
  }

  /// Validasi OTP dan simpan nomor telepon di backend.
  static Future<Map<String, dynamic>> verifyPhoneOtp(
    String phone,
    String otp, {
    String? name,
    String? address,
  }) async {
    try {
      final token = await TokenStore.read();

      if (token == null) {
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir. Silakan masuk kembali.',
        };
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/profile/phone/verify-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'phone': phone,
              'otp': otp,
              if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
              'address': ?address,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeBody(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        final result = <String, dynamic>{
          'success': true,
          'message': data['message'] ?? 'Nomor telepon berhasil diverifikasi.',
          'phone_verified': true,
        };

        if (payload is Map<String, dynamic>) {
          result['user'] = payload['user'];
          result['profile_completed'] = payload['profile_completed'] ?? false;
          result['requires_profile_completion'] =
              payload['requires_profile_completion'] ?? false;
        }

        return result;
      }

      return {
        'success': false,
        'message':
            data['message'] ??
            'Kode OTP yang Anda masukkan salah. Silakan coba lagi.',
        if (data['code'] != null) 'code': data['code'],
        if (data['retry_after'] != null) 'retry_after': data['retry_after'],
      };
    } catch (e) {
      print('Error verifyPhoneOtp: $e');
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Silakan coba lagi.',
      };
    }
  }

  static Future<void> logout() async {
    final token = await TokenStore.read();
    if (token != null && token.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$baseUrl/logout'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    await TokenStore.clear();
    await BiometricGuardService.clearSessionUnlock(clearPreference: true);
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
      print(
        'ApiService.post exception: TimeoutException on $endpoint after ${timeout.inSeconds}s: $e',
      );
      return {
        'success': false,
        'is_timeout': true,
        'message':
            'Koneksi ke server timeout (${timeout.inSeconds} detik). Server membutuhkan waktu lebih lama untuk memproses pesanan.',
      };
    } catch (e) {
      print('ApiService.post exception: $e');
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
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
