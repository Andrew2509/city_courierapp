import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

/// OVO connection status
enum OvoConnectionStatus {
  notConnected,
  pending,
  connected,
  verificationRequired,
  expired,
  revoked,
  failed,
}

// Backward compatibility alias
typedef DanaConnectionStatus = OvoConnectionStatus;

/// Wallet status
enum WalletStatus {
  notActive,
  active,
  suspended,
}

/// OVO Connection Model
class OvoConnection {
  final OvoConnectionStatus status;
  final String? maskedPhone;
  final String? accountName;
  final String provider;
  final String? connectedAt;

  OvoConnection({
    required this.status,
    this.maskedPhone,
    this.accountName,
    this.provider = 'OVO',
    this.connectedAt,
  });

  factory OvoConnection.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toLowerCase() ?? '';
    return OvoConnection(
      status: OvoConnectionStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == statusStr,
        orElse: () => json['connected'] == true
            ? OvoConnectionStatus.connected
            : OvoConnectionStatus.notConnected,
      ),
      maskedPhone: json['masked_account'] ?? json['masked_phone'] ?? json['phone_number'],
      accountName: json['account_name'],
      provider: json['provider']?.toString() ?? 'OVO',
      connectedAt: json['connected_at'] ?? json['bound_at'],
    );
  }

  bool get isConnected => status == OvoConnectionStatus.connected;
}

// Backward compatibility alias
typedef DanaConnection = OvoConnection;

/// Wallet balance model
class WalletBalance {
  final double availableBalance;
  final double pendingBalance;
  final double totalBalance;
  final double todayEarnings;
  final double totalEarnings;
  final String currency;

  WalletBalance({
    required this.availableBalance,
    required this.pendingBalance,
    double? totalBalance,
    this.todayEarnings = 0.0,
    this.totalEarnings = 0.0,
    required this.currency,
  }) : totalBalance = totalBalance ?? (availableBalance + pendingBalance);

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    final avail = (json['available_balance'] ?? 0).toDouble();
    final pend = (json['pending_balance'] ?? 0).toDouble();
    final tot = json['total_balance'] != null
        ? (json['total_balance'] as num).toDouble()
        : (avail + pend);
    final today = (json['today_earnings'] ?? 0).toDouble();
    final totalEarn = (json['total_earnings'] ?? 0).toDouble();

    return WalletBalance(
      availableBalance: avail,
      pendingBalance: pend,
      totalBalance: tot,
      todayEarnings: today,
      totalEarnings: totalEarn,
      currency: json['currency'] ?? 'IDR',
    );
  }
}

/// Withdrawal fee configuration from backend
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

/// Wallet Service - handles wallet state, OVO connection, and withdrawal API
class WalletService {
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

  /// Get OVO connection status
  static Future<Map<String, dynamic>> getOvoStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/ovo/status'),
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

  /// Connect OVO account via Account Inquiry and Consent
  static Future<Map<String, dynamic>> connectOvo({
    required String phoneNumber,
    required String accountName,
    required bool consent,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/ovo/connect'),
        headers: await _getHeaders(),
        body: json.encode({
          'phone_number': phoneNumber,
          'account_name': accountName,
          'consent': consent,
        }),
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

  /// Update OVO account details
  static Future<Map<String, dynamic>> updateOvo({
    required String phoneNumber,
    required String accountName,
    required bool consent,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/ovo/update'),
        headers: await _getHeaders(),
        body: json.encode({
          'phone_number': phoneNumber,
          'account_name': accountName,
          'consent': consent,
        }),
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

  /// Disconnect OVO account
  static Future<Map<String, dynamic>> disconnectOvo() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/ovo/unbind'),
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

  // Backward compatibility alias methods for DANA
  static Future<Map<String, dynamic>> getDanaStatus() async => getOvoStatus();
  static Future<Map<String, dynamic>> connectDana() async => getOvoStatus();
  static Future<Map<String, dynamic>> disconnectDana() async => disconnectOvo();
  static Future<Map<String, dynamic>> reconnectDana() async => getOvoStatus();
  static Future<Map<String, dynamic>> mockConnectDana() async => getOvoStatus();
  static Future<Map<String, dynamic>> verifyDana({required String phoneNumber}) async {
    return connectOvo(phoneNumber: phoneNumber, accountName: 'Kurir', consent: true);
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

  /// Get withdrawal fee configuration from backend
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

  /// Create withdrawal request (OVO)
  static Future<Map<String, dynamic>> createWithdrawal({
    required double amount,
    required String idempotencyKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/ovo/withdraw'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'idempotency_key': idempotencyKey,
        }),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data['success'] == true,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get withdrawal status / sync
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
  static String generateIdempotencyKey() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final microStr = now.microsecond.toString().padLeft(6, '0');
    return 'WD-$dateStr-$timeStr-$microStr';
  }
}
