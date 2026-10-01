import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class WithdrawalService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async => TokenStore.read();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> getWithdrawals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/withdrawals'),
        headers: await _getHeaders(),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'data': responseData['data'] ?? [],
        };
      }
      return {'success': false, 'message': responseData['message'] ?? 'Gagal mengambil data'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String bankName,
    required String accountName,
    required String accountNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/withdrawals'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'bank_name': bankName,
          'account_name': accountName,
          'account_number': accountNumber,
        }),
      );

      final responseData = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && responseData['success'] == true,
        'message': responseData['message'] ?? (response.statusCode == 200 ? 'Permintaan penarikan berhasil dikirim' : 'Gagal mengirim permintaan'),
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
