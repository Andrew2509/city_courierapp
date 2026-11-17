import 'dart:convert';

import 'package:city_courierapp/models/security/account_security_models.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:city_courierapp/services/security/device_metadata_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:http/http.dart' as http;

class AccountSecurityService {
  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _tokenReader;
  final Future<void> Function() _onUnauthorized;
  final Future<Map<String, String>> Function() _deviceHeadersReader;

  AccountSecurityService({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenReader,
    Future<void> Function()? onUnauthorized,
    Future<Map<String, String>> Function()? deviceHeadersReader,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiService.baseUrl,
        _tokenReader = tokenReader ?? TokenStore.read,
        _onUnauthorized = onUnauthorized ??
            (() async {
              await TokenStore.clear();
              await BiometricGuardService.clearSessionUnlock(
                clearPreference: true,
              );
            }),
        _deviceHeadersReader =
            deviceHeadersReader ?? DeviceMetadataService.getHeaders;

  static final AccountSecurityService instance = AccountSecurityService();

  Future<Map<String, String>> _headers() async {
    final token = await _tokenReader();
    final deviceHeaders = await _deviceHeadersReader();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...deviceHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl/security$path');

  Future<Map<String, dynamic>> _parseResponse(http.Response response) async {
    Map<String, dynamic> decoded = {};
    if (response.bodyBytes.isNotEmpty) {
      try {
        final raw = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (_) {}
    }

    if (response.statusCode == 401) {
      await _onUnauthorized();
      throw SecurityApiException(
        (decoded['message'] ?? 'Sesi login Anda telah berakhir. Silakan masuk kembali.')
            .toString(),
        code: decoded['code']?.toString() ?? 'UNAUTHENTICATED',
        statusCode: 401,
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded['success'] == true) {
      return decoded;
    }

    throw SecurityApiException(
      (decoded['message'] ?? 'Permintaan gagal (HTTP ${response.statusCode}).')
          .toString(),
      code: (decoded['code'] ?? decoded['error_code'])?.toString(),
      statusCode: response.statusCode,
      attemptsLeft: (decoded['attempts_left'] as num?)?.toInt(),
      retryAfter: (decoded['retry_after'] as num?)?.toInt(),
    );
  }

  Future<AccountSecurityOverview> getOverview() async {
    final res = await _client
        .get(_uri('/overview'), headers: await _headers())
        .timeout(const Duration(seconds: 25));
    final decoded = await _parseResponse(res);
    final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final overview = AccountSecurityOverview.fromJson(data);
    await BiometricGuardService.setLocalEnabled(
      overview.preferences.biometricEnabled,
      userId: overview.user.id,
    );
    return overview;
  }

  Future<({String message, AccountSecurityOverview overview})> updatePin({
    required String pin,
    required String pinConfirmation,
    String? currentPin,
    String? otp,
  }) async {
    final res = await _client
        .post(
          _uri('/pin'),
          headers: await _headers(),
          body: jsonEncode({
            'pin': pin,
            'pin_confirmation': pinConfirmation,
            if (currentPin != null && currentPin.isNotEmpty)
              'current_pin': currentPin,
            if (otp != null && otp.isNotEmpty) 'otp': otp,
          }),
        )
        .timeout(const Duration(seconds: 25));

    final decoded = await _parseResponse(res);
    final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return (
      message: (decoded['message'] ?? 'PIN Transaksi berhasil diperbarui!').toString(),
      overview: AccountSecurityOverview.fromJson(data),
    );
  }

  Future<({String message, int retryAfter})> requestPinResetOtp() async {
    final res = await _client
        .post(_uri('/pin/request-otp'), headers: await _headers())
        .timeout(const Duration(seconds: 25));
    final decoded = await _parseResponse(res);
    return (
      message:
          (decoded['message'] ?? 'Kode OTP reset PIN telah dikirim ke WhatsApp.')
              .toString(),
      retryAfter: (decoded['retry_after'] as num?)?.toInt() ?? 60,
    );
  }

  Future<bool> verifyPin(String pin) async {
    final res = await _client
        .post(
          _uri('/pin/verify'),
          headers: await _headers(),
          body: jsonEncode({'pin': pin}),
        )
        .timeout(const Duration(seconds: 25));
    final decoded = await _parseResponse(res);
    final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return data['valid'] == true;
  }

  Future<({String message, AccountSecurityOverview overview})> updatePreferences({
    bool? biometricEnabled,
    bool? securityAlertsEnabled,
  }) async {
    final res = await _client
        .patch(
          _uri('/preferences'),
          headers: await _headers(),
          body: jsonEncode({
            'biometric_enabled': ?biometricEnabled,
            'security_alerts_enabled': ?securityAlertsEnabled,
          }),
        )
        .timeout(const Duration(seconds: 25));

    final decoded = await _parseResponse(res);
    final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final overview = AccountSecurityOverview.fromJson(data);
    await BiometricGuardService.setLocalEnabled(
      overview.preferences.biometricEnabled,
      userId: overview.user.id,
    );
    return (
      message:
          (decoded['message'] ?? 'Preferensi keamanan diperbarui.').toString(),
      overview: overview,
    );
  }

  Future<({String message, AccountSecurityOverview overview})> revokeDevice(
    int tokenId,
  ) async {
    final res = await _client
        .delete(_uri('/devices/$tokenId'), headers: await _headers())
        .timeout(const Duration(seconds: 25));
    final decoded = await _parseResponse(res);
    final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return (
      message: (decoded['message'] ?? 'Perangkat berhasil dihapus.').toString(),
      overview: AccountSecurityOverview.fromJson(data),
    );
  }

  Future<({String message, int revokedCount, AccountSecurityOverview overview})>
      revokeOtherDevices() async {
    final res = await _client
        .post(_uri('/devices/revoke-others'), headers: await _headers())
        .timeout(const Duration(seconds: 25));
    final decoded = await _parseResponse(res);
    final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return (
      message: (decoded['message'] ??
              'Semua sesi di perangkat lain telah berhasil diakhiri.')
          .toString(),
      revokedCount: (decoded['revoked_count'] as num?)?.toInt() ?? 0,
      overview: AccountSecurityOverview.fromJson(data),
    );
  }
}
