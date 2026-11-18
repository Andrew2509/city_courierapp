import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/models/payment/payment_method.dart';
import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class PaymentProviderDisabledException implements Exception {
  final String message;
  const PaymentProviderDisabledException(this.message);

  @override
  String toString() => message;
}

class CheckoutPaymentMethodsResult {
  final List<PaymentMethod> methods;
  final bool ipaymuEnabled;
  final bool hasError;
  final String? message;

  const CheckoutPaymentMethodsResult({
    required this.methods,
    required this.ipaymuEnabled,
    this.hasError = false,
    this.message,
  });
}

class PaymentService {
  static String get _baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStore.read();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get list of available payment methods
  static Future<CheckoutPaymentMethodsResult>
  fetchCheckoutPaymentMethods() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/payment/methods'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      final dynamic decoded = _tryDecodeJson(response.body);
      final Map<String, dynamic>? data = decoded is Map<String, dynamic>
          ? decoded
          : (decoded is Map ? Map<String, dynamic>.from(decoded) : null);

      if (response.statusCode == 200 &&
          data != null &&
          data['success'] == true) {
        final bool ipaymuEnabled =
            data['ipaymu_enabled'] != false && data['disabled'] != true;
        final String? message = _nonEmptyString(data['message']);

        if (!ipaymuEnabled) {
          return CheckoutPaymentMethodsResult(
            methods: const [],
            ipaymuEnabled: false,
            hasError: false,
            message: message,
          );
        }

        final List methods = data['data'] is List
            ? data['data'] as List
            : const [];
        return CheckoutPaymentMethodsResult(
          methods: methods.map((m) => PaymentMethod.fromJson(m)).toList(),
          ipaymuEnabled: true,
          hasError: false,
          message: message,
        );
      }

      if ((response.statusCode == 403 || response.statusCode == 503) &&
          data != null &&
          data['error_code'] == 'PROVIDER_DISABLED') {
        return CheckoutPaymentMethodsResult(
          methods: const [],
          ipaymuEnabled: false,
          hasError: false,
          message: _nonEmptyString(data['message']),
        );
      }

      final String? serverMsg = data != null
          ? _nonEmptyString(data['message'])
          : null;
      final String fallbackMsg = response.statusCode == 401
          ? 'Sesi login berakhir. Silakan login ulang untuk memuat Virtual Account & QRIS.'
          : 'Gagal memuat Virtual Account & QRIS (HTTP ${response.statusCode}).';

      return CheckoutPaymentMethodsResult(
        methods: const [],
        ipaymuEnabled: true,
        hasError: true,
        message: serverMsg ?? fallbackMsg,
      );
    } on TimeoutException {
      return const CheckoutPaymentMethodsResult(
        methods: [],
        ipaymuEnabled: true,
        hasError: true,
        message: 'Waktu muat metode pembayaran habis. Ketuk Muat Ulang.',
      );
    } catch (e) {
      debugPrint('PaymentService Error (getPaymentMethods): $e');
      return const CheckoutPaymentMethodsResult(
        methods: [],
        ipaymuEnabled: true,
        hasError: true,
        message: 'Tidak dapat memuat Virtual Account & QRIS dari server.',
      );
    }
  }

  static dynamic _tryDecodeJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String? _nonEmptyString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static Future<List<PaymentMethod>> getPaymentMethods() async {
    final result = await fetchCheckoutPaymentMethods();
    return result.methods;
  }

  static Future<PaymentResult?> createPayment({
    String? orderId,
    String? shipmentId,
    required String paymentType,
    required String channelCode,
    required int amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment/create'),
        headers: await _getHeaders(),
        body: jsonEncode({
          if (orderId != null) 'order_id': orderId,
          if (shipmentId != null) 'shipment_id': shipmentId,
          'payment_type': paymentType,
          'channel_code': channelCode,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PaymentResult.fromJson(data['data']);
        }
        throw Exception(data['message'] ?? 'Gagal membuat pembayaran');
      } else {
        // Tampilkan body lengkap (termasuk blok `debug` dari backend) supaya
        // penolakan provider seperti "Suspicious buyer" bisa didiagnosis dari
        // console tanpa menebak-nebak.
        print(
          'PaymentService: createPayment gagal (${response.statusCode}) body=${response.body}',
        );
        final data = jsonDecode(response.body);
        String msg = data['message'] ?? 'Error ${response.statusCode}';
        if (data is Map && data['error_code'] == 'PROVIDER_DISABLED') {
          throw PaymentProviderDisabledException(msg);
        }
        if (data['errors'] != null) {
          msg += ': ' + data['errors'].toString();
        }
        throw Exception(msg);
      }
    } catch (e) {
      print('PaymentService Error (createPayment): $e');
      rethrow;
    }
  }

  /// Check payment status
  static Future<PaymentResult?> getStatus(String paymentId) async {
    try {
      final encodedId = Uri.encodeComponent(paymentId);
      final response = await http
          .get(
            Uri.parse('$_baseUrl/payment/status?payment_id=$encodedId'),
            headers: await _getHeaders(),
          )
          // Tanpa batas waktu, tombol Cek Status bisa menggantung diam-diam.
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PaymentResult.fromJson(data['data']);
        }
        print('PaymentService: getStatus ditolak body=${response.body}');
        return null;
      }

      // Jangan diam: 401/404 di sini membuat tombol "Cek Status" terlihat mati.
      print(
        'PaymentService: getStatus gagal (${response.statusCode}) body=${response.body}',
      );
      return null;
    } catch (e) {
      print('PaymentService Error (getStatus): $e');
      return null;
    }
  }

  /// Batalkan pembayaran yang masih menunggu.
  ///
  /// Backend menanyakan status resmi ke iPaymu lebih dulu: bila transaksi masih
  /// pending, pembayaran ditutup lokal (iPaymu tanpa API pembatalan); bila sudah
  /// dibayar, pembatalan ditolak dan harus lewat refund manual.
  static Future<Map<String, dynamic>> cancelPayment(String paymentId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/payment/cancel'),
            headers: await _getHeaders(),
            body: jsonEncode({'payment_id': paymentId}),
          )
          .timeout(const Duration(seconds: 30));

      final dynamic data = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Pembayaran berhasil dibatalkan',
          'payment': data['payment'],
        };
      }

      return {
        'success': false,
        'error_code': data is Map ? data['error_code']?.toString() : null,
        'payment': data is Map ? data['payment'] : null,
        'message': data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Gagal membatalkan pembayaran (HTTP ${response.statusCode})',
      };
    } catch (e) {
      print('PaymentService Error (cancelPayment): $e');
      return {'success': false, 'message': 'Gagal membatalkan pembayaran: $e'};
    }
  }

  /// Confirm COD or Tunai payment directly to the backend
  static Future<bool> confirmCodPayment({
    required String shipmentId,
    required String paymentMethod,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/shipments/$shipmentId/confirm-payment'),
        headers: await _getHeaders(),
        body: jsonEncode({'payment_method': paymentMethod}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['success'] == true;
      } else {
        throw Exception(
          data['message'] ?? 'Gagal mengonfirmasi metode pembayaran',
        );
      }
    } catch (e) {
      print('PaymentService Error (confirmCodPayment): $e');
      rethrow;
    }
  }
}
