import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

/// DANA connection status from PRD §32
enum DanaConnectionStatus {
  notConnected,
  pending,
  connected,
  verificationRequired,
  expired,
  revoked,
  failed,
}

/// Wallet status from PRD §6
enum WalletStatus {
  notActive,
  active,
  suspended,
}

/// DANA connection model
class DanaConnection {
  final DanaConnectionStatus status;
  final String? maskedPhone;
  final String? connectedAt;

  DanaConnection({
    required this.status,
    this.maskedPhone,
    this.connectedAt,
  });

  factory DanaConnection.fromJson(Map<String, dynamic> json) {
    return DanaConnection(
      status: DanaConnectionStatus.values.firstWhere(
        (e) => e.name == json['status']?.toString().toLowerCase(),
        orElse: () => DanaConnectionStatus.notConnected,
      ),
      maskedPhone: json['masked_account'] ?? json['masked_phone'],
      connectedAt: json['connected_at'],
    );
  }

  bool get isConnected => status == DanaConnectionStatus.connected;
}

/// Wallet balance model
class WalletBalance {
  final double availableBalance;
  final double pendingBalance;
  final double totalWithdrawn;
  final String currency;

  WalletBalance({
    required this.availableBalance,
    required this.pendingBalance,
    this.totalWithdrawn = 0,
    required this.currency,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      availableBalance: (json['available_balance'] ?? 0).toDouble(),
      pendingBalance: (json['pending_balance'] ?? 0).toDouble(),
      totalWithdrawn: (json['total_withdrawn'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'IDR',
    );
  }
}

/// Withdrawal fee configuration from backend
/// PRD §15: Fee from configuration, not hardcoded.
class WithdrawalFeeConfig {
  final double adminFee;
  final double minimum;
  final double maximum;
  final double dailyLimit;

  WithdrawalFeeConfig({
    required this.adminFee,
    required this.minimum,
    required this.maximum,
    required this.dailyLimit,
  });

  factory WithdrawalFeeConfig.fromJson(Map<String, dynamic> json) {
    return WithdrawalFeeConfig(
      adminFee: (json['admin_fee'] ?? 2500).toDouble(),
      minimum: (json['minimum'] ?? 10000).toDouble(),
      maximum: (json['maximum'] ?? 5000000).toDouble(),
      dailyLimit: (json['daily_limit'] ?? 5000000).toDouble(),
    );
  }
}

/// Wallet Service - handles wallet state, DANA connection, and withdrawal API
class WalletService {
  static final Random _random = Random.secure();

  static String get _baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async => TokenStore.read();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get wallet data from backend
  static Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/wallet'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get DANA connection status
  static Future<Map<String, dynamic>> getDanaStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/dana/status'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'errorCode': data['error_code'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'errorCode': 'NETWORK_ERROR'};
    }
  }

  /// Start DANA linking — Deeplink Binding session via backend.
  /// POST /api/courier/dana/binding → { binding_url, external_id, binding_mode, expires_at }
  ///
  /// `seamless: true` memakai Seamless Binding (nomor HP kurir yang sudah
  /// terverifikasi); kirim `seamless: false` untuk Normal Binding bila DANA
  /// menolak seamless atau nomor belum terverifikasi.
  static Future<Map<String, dynamic>> connectDana({bool seamless = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/dana/binding'),
        headers: await _getHeaders(),
        body: json.encode({'seamless': seamless}),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'sessionId': data['data']?['session_id'],
        'authorizationUrl': data['data']?['binding_url'] ??
            data['data']?['authorization_url'] ??
            data['data']?['redirect_url'],
        'externalId': data['data']?['external_id'],
        'bindingMode': data['data']?['binding_mode'],
        'expiresAt': data['data']?['expires_at'],
        'status': data['data']?['status'],
        'errorCode': data['error_code'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'errorCode': 'NETWORK_ERROR'};
    }
  }

  /// Mode Demo: minta backend mencatat koneksi DANA simulasi.
  /// Backend yang mengelola status (POST /courier/dana/mock-connect).
  static Future<Map<String, dynamic>> mockConnectDana() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/dana/mock-connect'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'errorCode': data['error_code'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'errorCode': 'NETWORK_ERROR'};
    }
  }

  /// Verify DANA account via Account Inquiry with phone number.
  /// PRD §8-10: Input phone → Account Inquiry → Valid/Invalid
  static Future<Map<String, dynamic>> verifyDana({
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/dana/verify'),
        headers: await _getHeaders(),
        body: json.encode({'phone_number': phoneNumber}),
      );

      // If 404, the endpoint is not deployed yet — return clear signal
      if (response.statusCode == 404) {
        return {
          'success': false,
          'data': null,
          'message': 'Route not found — endpoint not deployed',
        };
      }

      // Try to parse JSON response
      try {
        final data = json.decode(response.body);
        return {
          'success': response.statusCode == 200 && data['success'] == true,
          'data': data['data'],
          'message': data['message'],
        };
      } catch (_) {
        // Response is not JSON (Laravel returns HTML for 404s)
        return {
          'success': false,
          'data': null,
          'message': 'Route not found — endpoint not deployed',
        };
      }
    } catch (e) {
      // Network error
      return {
        'success': false,
        'data': null,
        'message': 'Route not found — endpoint not deployed',
      };
    }
  }

  /// Disconnect DANA account.
  /// PRD §27: POST /api/courier/dana/unbind
  static Future<Map<String, dynamic>> disconnectDana() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/dana/unbind'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'errorCode': data['error_code'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'errorCode': 'NETWORK_ERROR'};
    }
  }

  /// Reconnect DANA account (replace with new DANA account).
  /// PRD §28: POST /api/courier/dana/rebind
  static Future<Map<String, dynamic>> reconnectDana() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/dana/rebind'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'sessionId': data['data']?['session_id'],
        'authorizationUrl': data['data']?['binding_url'] ??
            data['data']?['authorization_url'] ??
            data['data']?['redirect_url'],
        'errorCode': data['error_code'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'errorCode': 'NETWORK_ERROR'};
    }
  }

  /// Get wallet transactions
  static Future<Map<String, dynamic>> getTransactions({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/wallet/transactions?page=$page'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get courier earnings summary (Hari/Minggu/Bulan + saldo + aktivitas terbaru)
  /// GET /api/courier/earnings
  static Future<Map<String, dynamic>> getEarnings() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/earnings'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get withdrawal fee configuration from backend.
  /// PRD §15: Fee from configuration, not hardcoded.
  static Future<Map<String, dynamic>> getFeeConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/wallet/fee-config'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Create withdrawal request
  static Future<Map<String, dynamic>> createWithdrawal({
    required double amount,
    required String idempotencyKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/withdrawals'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'idempotency_key': idempotencyKey,
        }),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 &&
            response.statusCode < 300 &&
            data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get withdrawal status (syncs latest status with payment provider).
  static Future<Map<String, dynamic>> getWithdrawalStatus(
      String withdrawalId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/withdrawals/$withdrawalId/status'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get all withdrawals
  static Future<Map<String, dynamic>> getWithdrawals({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/withdrawals?page=$page'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Generate idempotency key for withdrawal.
  /// PRD §25: Unique idempotency key with timestamp and random component.
  static String generateIdempotencyKey() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    // Use microseconds for uniqueness
    final microStr = now.microsecond.toString().padLeft(6, '0');
    // Random suffix so two requests in the same millisecond cannot collide
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final randomStr = List.generate(
        4, (_) => chars[_random.nextInt(chars.length)]).join();
    return 'WD-$dateStr-$timeStr-$microStr-$randomStr';
  }
}
