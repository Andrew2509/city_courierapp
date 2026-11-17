import 'dart:convert';
import 'dart:math';

import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:http/http.dart' as http;

class CourierWalletV1Service {
  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _tokenReader;

  CourierWalletV1Service({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenReader,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiService.baseUrl,
        _tokenReader = tokenReader ?? TokenStore.read;

  static final CourierWalletV1Service instance = CourierWalletV1Service();

  static String newIdempotencyKey([String prefix = 'cur-wd']) {
    final rand = Random.secure().nextInt(999999);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$rand';
  }

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final token = await _tokenReader();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'Idempotency-Key': idempotencyKey,
    };
  }

  Uri _v1(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl/v1/courier/wallet$path').replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeData(http.Response response) {
    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      return {};
    }

    throw WalletApiException(
      (decoded['message'] ?? 'Permintaan kurir gagal (HTTP ${response.statusCode})').toString(),
      errorCode: decoded['error_code']?.toString(),
      statusCode: response.statusCode,
    );
  }

  Future<CourierWalletV1Summary> getWallet() async {
    final res = await _client.get(_v1(''), headers: await _headers());
    return CourierWalletV1Summary.fromJson(_decodeData(res));
  }

  Future<({CourierEarningsSummaryV1 summary, List<CourierEarningV1> items})> getEarnings({
    int page = 1,
    String status = 'all',
  }) async {
    final res = await _client.get(
      _v1('/earnings', {'page': '$page', if (status != 'all') 'status': status}),
      headers: await _headers(),
    );
    final data = _decodeData(res);
    return (
      summary: CourierEarningsSummaryV1.fromJson(
        Map<String, dynamic>.from((data['summary'] as Map?) ?? {}),
      ),
      items: (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CourierEarningV1.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<({CourierAutoPayoutStatusV1 autoPayoutStatus, List<PayoutTransactionV1> items})> getPayouts({
    int page = 1,
  }) async {
    final res = await _client.get(_v1('/payouts', {'page': '$page'}), headers: await _headers());
    final data = _decodeData(res);
    return (
      autoPayoutStatus: CourierAutoPayoutStatusV1.fromJson(
        Map<String, dynamic>.from((data['auto_payout_status'] as Map?) ?? {}),
      ),
      items: (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PayoutTransactionV1.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<({PayoutTransactionV1 payout, List<CourierEarningV1> earnings})> getPayoutDetail(int id) async {
    final res = await _client.get(_v1('/payouts/$id'), headers: await _headers());
    final data = _decodeData(res);
    return (
      payout: PayoutTransactionV1.fromJson(data),
      earnings: (data['earnings'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CourierEarningV1.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<List<CourierPayoutNotificationV1>> getNotifications() async {
    final res = await _client.get(_v1('/notifications'), headers: await _headers());
    final data = _decodeData(res);
    return (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => CourierPayoutNotificationV1.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PayoutDestinationV1>> getDestinations() async {
    final res = await _client.get(_v1('/destinations'), headers: await _headers());
    final data = _decodeData(res);
    return (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PayoutDestinationV1.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DestinationInquiryResult> inquireDestination({
    required String destinationType,
    required String channelCode,
    required String accountNumber,
  }) async {
    final res = await _client.post(
      _v1('/destinations/inquiry'),
      headers: await _headers(),
      body: jsonEncode({
        'destination_type': destinationType,
        'channel_code': channelCode,
        'account_number': accountNumber,
      }),
    );
    return DestinationInquiryResult.fromJson(_decodeData(res));
  }

  Future<PayoutDestinationV1> addDestination({
    required String destinationType,
    required String channelCode,
    required String accountNumber,
    required String accountHolderName,
    bool isDefault = true,
  }) async {
    final res = await _client.post(
      _v1('/destinations'),
      headers: await _headers(),
      body: jsonEncode({
        'destination_type': destinationType,
        'channel_code': channelCode,
        'account_number': accountNumber,
        'account_holder_name': accountHolderName,
        'is_default': isDefault,
      }),
    );
    return PayoutDestinationV1.fromJson(_decodeData(res));
  }

  Future<PayoutDestinationV1> setDefaultDestination(int id) async {
    final res = await _client.patch(
      _v1('/destinations/$id/default'),
      headers: await _headers(),
    );
    return PayoutDestinationV1.fromJson(_decodeData(res));
  }

  Future<PayoutTransactionV1> requestWithdrawal({
    required int amount,
    required int destinationId,
    String? idempotencyKey,
    String? transactionPin,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey();
    final res = await _client.post(
      _v1('/withdrawals'),
      headers: await _headers(idempotencyKey: key),
      body: jsonEncode({
        'amount': amount,
        'destination_id': destinationId,
        if (transactionPin != null && transactionPin.isNotEmpty)
          'transaction_pin': transactionPin,
        'idempotency_key': key,
      }),
    );
    return PayoutTransactionV1.fromJson(_decodeData(res));
  }
}
