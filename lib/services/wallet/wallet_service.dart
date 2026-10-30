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
  final String? accountName;
  final String? provider;
  final String? connectedAt;

  DanaConnection({
    required this.status,
    this.maskedPhone,
    this.accountName,
    this.provider,
    this.connectedAt,
  });

  factory DanaConnection.fromJson(Map<String, dynamic> json) {
    return DanaConnection(
      status: DanaConnectionStatus.values.firstWhere(
        (e) => e.name == json['status']?.toString().toLowerCase(),
        orElse: () => DanaConnectionStatus.notConnected,
      ),
      maskedPhone: json['masked_account'] ?? json['masked_phone'],
      accountName: json['account_name'],
      provider: json['provider']?.toString(),
      connectedAt: json['connected_at'] ?? json['bound_at'],
    );
  }

  bool get isConnected => status == DanaConnectionStatus.connected;
}

/// Wallet balance model
class WalletBalance {
  final double availableBalance;
  final double pendingBalance;
  final double totalWithdrawn;
  final double totalEarnings;
  final double totalBalance;
  final double todayEarnings;
  final String currency;

  WalletBalance({
    required this.availableBalance,
    required this.pendingBalance,
    this.totalWithdrawn = 0,
    this.totalEarnings = 0,
    this.totalBalance = 0,
    this.todayEarnings = 0,
    required this.currency,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    final available = (json['available_balance'] ?? 0).toDouble();
    final pending = (json['pending_balance'] ?? 0).toDouble();

    return WalletBalance(
      availableBalance: available,
      pendingBalance: pending,
      totalWithdrawn: (json['total_withdrawn'] ?? 0).toDouble(),
      totalEarnings: (json['total_earnings'] ?? 0).toDouble(),
      totalBalance: (json['total_balance'] ?? (available + pending)).toDouble(),
      todayEarnings: (json['today_earnings'] ?? 0).toDouble(),
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
      adminFee: (json['admin_fee'] ?? 0).toDouble(),
      minimum: (json['minimum'] ?? 10000).toDouble(),
      maximum: (json['maximum'] ?? 5000000).toDouble(),
      dailyLimit: (json['daily_limit'] ?? 5000000).toDouble(),
    );
  }
}

/// Satu baris riwayat dompet yang sudah dinormalisasi backend
/// (GET /api/courier/wallet/history).
class WalletHistoryItem {
  final String id;
  final String kind; // earning | bonus | adjustment | reversal | withdrawal
  final String title;
  final String? description;
  final double amount; // negatif untuk penarikan
  final double fee;
  final double netAmount;
  final String status; // success | processing | pending | failed | cancelled
  final String statusLabel;
  final String? reference;
  final String? destination;
  final String? accountName;
  final String? provider;
  final int? orderId;
  final int? withdrawalId;
  final DateTime? createdAt;
  final DateTime? processedAt;

  WalletHistoryItem({
    required this.id,
    required this.kind,
    required this.title,
    this.description,
    required this.amount,
    this.fee = 0,
    this.netAmount = 0,
    required this.status,
    required this.statusLabel,
    this.reference,
    this.destination,
    this.accountName,
    this.provider,
    this.orderId,
    this.withdrawalId,
    this.createdAt,
    this.processedAt,
  });

  factory WalletHistoryItem.fromJson(Map<String, dynamic> json) {
    return WalletHistoryItem(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? 'earning').toString(),
      title: (json['title'] ?? 'Transaksi').toString(),
      description: json['description']?.toString(),
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      fee: ((json['fee'] ?? 0) as num).toDouble(),
      netAmount: ((json['net_amount'] ?? 0) as num).toDouble(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['status_label'] ?? 'Menunggu').toString(),
      reference: json['reference']?.toString(),
      destination: json['destination']?.toString(),
      accountName: json['account_name']?.toString(),
      provider: json['provider']?.toString(),
      orderId: (json['order_id'] as num?)?.toInt(),
      withdrawalId: (json['withdrawal_id'] as num?)?.toInt(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal(),
      processedAt: DateTime.tryParse((json['processed_at'] ?? '').toString())?.toLocal(),
    );
  }

  bool get isIncoming => amount > 0;

  bool get isWithdrawal => kind == 'withdrawal';

  /// Penarikan yang masih berjalan (dana ditahan).
  bool get isOngoing =>
      isWithdrawal && const ['pending', 'processing'].contains(status);

  bool get isFailed =>
      isWithdrawal && const ['failed', 'cancelled'].contains(status);
}

/// Notifikasi dompet — diturunkan backend dari status transaksi nyata.
class WalletNotificationItem {
  final String id;
  final String type;
  final String title;
  final String message;
  final String level; // success | info | warning | error
  final DateTime? createdAt;

  WalletNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.level,
    this.createdAt,
  });

  factory WalletNotificationItem.fromJson(Map<String, dynamic> json) {
    return WalletNotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      level: (json['level'] ?? 'info').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal(),
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

  /// Riwayat dompet terpadu + filter jenis & status.
  /// GET /api/courier/wallet/history?filter=&status=&page=
  static Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int perPage = 15,
    String? filter,
    String? status,
  }) async {
    try {
      final query = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        if (filter != null && filter != 'all') 'filter': filter,
        'status': ?status,
      };

      final uri = Uri.parse('$_baseUrl/courier/wallet/history')
          .replace(queryParameters: query);

      final response = await http.get(uri, headers: await _getHeaders());
      final data = json.decode(response.body);

      if (response.statusCode != 200 || data['success'] != true) {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal memuat riwayat transaksi',
        };
      }

      final payload = data['data'] as Map<String, dynamic>? ?? {};
      final items = (payload['transactions'] as List<dynamic>? ?? [])
          .map((e) => WalletHistoryItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      return {
        'success': true,
        'items': items,
        'total': (payload['total'] as num?)?.toInt() ?? items.length,
        'hasMore': payload['has_more'] == true,
        'page': (payload['page'] as num?)?.toInt() ?? page,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Notifikasi dompet dari status transaksi nyata.
  /// GET /api/courier/wallet/notifications
  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/wallet/notifications'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        return {'success': false, 'message': data['message']};
      }

      final items = (data['data']?['notifications'] as List<dynamic>? ?? [])
          .map((e) => WalletNotificationItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      return {'success': true, 'items': items};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get wallet transactions (ledger, tanpa filter).
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

  /// Normalisasi nomor HP DANA (pra-validasi klien).
  ///
  /// Menerima format 08…, 628…, dan 8… lalu mengembalikan bentuk 628…
  /// — mengikuti aturan yang sama dengan normalisasi di backend.
  /// Mengembalikan null bila format tidak valid (bukan dibenahi sepihak;
  /// nomor akhirnya tetap dinormalisasi server).
  static String? normalizePhone(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    String subscriber;
    if (digits.startsWith('62')) {
      subscriber = digits.substring(2);
    } else if (digits.startsWith('0')) {
      subscriber = digits.substring(1);
    } else if (digits.startsWith('8')) {
      subscriber = digits;
    } else {
      return null;
    }

    // Panjang pelanggan 9-13 digit setelah "0", konsisten dengan validasi
    // normalisasi di backend.
    if (subscriber.length < 9 || subscriber.length > 13) return null;
    return '62$subscriber';
  }

  /// Penyamaran nomor HP untuk tampilan: 62812****7890.
  /// Mirip backend — nilai yang sudah berisi `****` tidak diubah ulang.
  static String maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    if (phone.contains('****')) return phone;

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '-';

    // Akhiran subscriber dipisah dari prefix tampilan agar output konsisten:
    // 62812… → 6281****7890, 0812… → 0812****7890 (ala nilai legacy).
    String cc;
    String subscriber;
    if (digits.startsWith('62')) {
      cc = '62';
      subscriber = digits.substring(2);
    } else if (digits.startsWith('0')) {
      cc = '0';
      subscriber = digits.substring(1);
    } else {
      cc = '';
      subscriber = digits;
    }
    if (subscriber.length <= 4) return phone;

    // Total digit yang ditampilkan sebelum '****' = 4 (mengikuti format
    // legacy "0812****7890"): 62 → 2 digit, 0 → 3 digit, tanpa prefix → 4.
    final keep = 4 - cc.length;
    return '$cc${subscriber.substring(0, keep)}****${subscriber.substring(subscriber.length - 4)}';
  }

  /// Preview nama pemilik akun DANA tujuan.
  ///
  /// GET /api/courier/withdrawals/destination-inquiry?phone=…
  /// Sumber kebenaran = penyedia payout (iPaymu). Selama layanan payout
  /// belum aktif / spec inquiry belum tersedia, backend membalas
  /// { available: false, status: … } — service mengembalikan available
  /// false TANPA menganggapnya gagal. 404 (server lama) = unavailable.
  /// Mengembalikan null hanya saat jaringan error (kirim ulang nanti ok).
  static Future<Map<String, dynamic>?> fetchDestinationName(String phone) async {
    try {
      final uri = Uri.parse('$_baseUrl/courier/withdrawals/destination-inquiry')
          .replace(queryParameters: {'phone': phone});
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 422) return {'available': false, 'status': 'invalid_phone'};
      if (response.statusCode == 404) return {'available': false, 'status': 'endpoint_missing'};

      final data = json.decode(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        return {'available': false, 'status': 'unavailable'};
      }

      final payload = (data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      return {
        'available': payload['available'] == true,
        'accountName': payload['account_name']?.toString(),
        'status': payload['status']?.toString() ?? 'unknown',
      };
    } catch (_) {
      // Timeout/socket: jangan blokir user — hanya tampil "tidak dapat
      // memeriksa" lalu coba lagi pada perubahan nomor berikutnya.
      return null;
    }
  }

  /// Create withdrawal request.
  ///
  /// `destinationPhone`: nomor DANA tujuan yang diketik kurir saat penarikan
  /// (tidak ada binding — backend memvalidasi & menormalisasi).
  ///
  /// Backend membalas 201 untuk permintaan baru dan 200 untuk permintaan
  /// idempotent yang sama — keduanya sukses.
  static Future<Map<String, dynamic>> createWithdrawal({
    required double amount,
    required String idempotencyKey,
    String? destinationPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courier/withdrawals'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'idempotency_key': idempotencyKey,
          if (destinationPhone != null && destinationPhone.trim().isNotEmpty)
            'phone_number': destinationPhone.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      Map<String, dynamic> data;
      try {
        data = (json.decode(response.body) as Map).cast<String, dynamic>();
      } catch (_) {
        return {
          'success': false,
          'message': 'Respons server tidak dapat dibaca. Periksa status penarikan sebelum mencoba lagi.',
          'uncertain': true,
        };
      }

      final isSuccess = (response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true;

      return {
        'success': isSuccess,
        'data': data['data'],
        'errorCode': data['error_code'],
        'message': data['message'],
        // 5xx / respons tak terbaca: hasil tidak pasti, jangan kirim ulang
        // dengan key baru — periksa status transaksi lebih dulu.
        'uncertain': !isSuccess && response.statusCode >= 500,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi terputus. Periksa status penarikan sebelum mencoba lagi.',
        'uncertain': true,
      };
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

  /// Detail penarikan (tanpa memanggil provider).
  static Future<Map<String, dynamic>> getWithdrawalDetail(String reference) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courier/withdrawals/$reference'),
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
