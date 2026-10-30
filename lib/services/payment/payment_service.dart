import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/models/payment/payment_method.dart';
import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

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
  static Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payment/methods'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List methods = data['data'];
          return methods.map((m) => PaymentMethod.fromJson(m)).toList();
        }
      }
      return [];
    } catch (e) {
      print('PaymentService Error (getPaymentMethods): $e');
      return [];
    }
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
        print('PaymentService: createPayment gagal (${response.statusCode}) body=${response.body}');
        final data = jsonDecode(response.body);
        String msg = data['message'] ?? 'Error ${response.statusCode}';
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
      final response = await http.get(
        Uri.parse('$_baseUrl/payment/status?payment_id=$encodedId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PaymentResult.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('PaymentService Error (getStatus): $e');
      return null;
    }
  }

  /// Cancel payment
  static Future<bool> cancelPayment(String paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment/cancel'),
        headers: await _getHeaders(),
        body: jsonEncode({'payment_id': paymentId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['success'] == true;
      } else {
        throw Exception(data['message'] ?? 'Gagal membatalkan pesanan');
      }
    } catch (e) {
      print('PaymentService Error (cancelPayment): $e');
      rethrow;
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
        throw Exception(data['message'] ?? 'Gagal mengonfirmasi metode pembayaran');
      }
    } catch (e) {
      print('PaymentService Error (confirmCodPayment): $e');
      rethrow;
    }
  }
}
