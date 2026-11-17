import 'dart:convert';
import 'dart:math';

import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:http/http.dart' as http;

class CustomerWalletService {
  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _tokenReader;

  CustomerWalletService({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenReader,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiService.baseUrl,
        _tokenReader = tokenReader ?? TokenStore.read;

  static final CustomerWalletService instance = CustomerWalletService();

  static String newIdempotencyKey([String prefix = 'cc']) {
    final rand = Random.secure().nextInt(999999);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$rand';
  }

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final token = await _tokenReader();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
    };
  }

  Uri _v1(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl/v1/customer/wallet$path').replace(queryParameters: query);
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
      (decoded['message'] ?? 'Permintaan gagal (HTTP ${response.statusCode})').toString(),
      errorCode: decoded['error_code']?.toString(),
      statusCode: response.statusCode,
    );
  }

  Future<CustomerWalletSummary> getWallet() async {
    final res = await _client.get(_v1(''), headers: await _headers());
    return CustomerWalletSummary.fromJson(_decodeData(res));
  }

  Future<({List<WalletTransactionV1> items, int currentPage, int lastPage})> getTransactions({
    int page = 1,
    int perPage = 15,
    String type = 'all',
    String status = 'all',
  }) async {
    final res = await _client.get(
      _v1('/transactions', {
        'page': '$page',
        'per_page': '$perPage',
        if (type != 'all') 'type': type,
        if (status != 'all') 'status': status,
      }),
      headers: await _headers(),
    );
    final data = _decodeData(res);
    final items = (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => WalletTransactionV1.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final pagination = (data['pagination'] as Map?) ?? {};
    return (
      items: items,
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagination['last_page'] as num?)?.toInt() ?? 1,
    );
  }

  Future<WalletTransactionV1> getTransactionDetail(int id) async {
    final res = await _client.get(_v1('/transactions/$id'), headers: await _headers());
    return WalletTransactionV1.fromJson(_decodeData(res));
  }

  Future<TopupMethodsBundle> getTopupMethods() async {
    final res = await _client.get(_v1('/topups/methods'), headers: await _headers());
    return TopupMethodsBundle.fromJson(_decodeData(res));
  }

  Future<TopupTransactionV1> createTopup({
    required int amount,
    required String paymentType,
    required String channelCode,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey('topup');
    final res = await _client.post(
      _v1('/topups'),
      headers: await _headers(idempotencyKey: key),
      body: jsonEncode({
        'amount': amount,
        'payment_type': paymentType,
        'channel_code': channelCode,
        'idempotency_key': key,
      }),
    );
    return TopupTransactionV1.fromJson(_decodeData(res));
  }

  Future<TopupTransactionV1> getTopupDetail(int id) async {
    final res = await _client.get(_v1('/topups/$id'), headers: await _headers());
    return TopupTransactionV1.fromJson(_decodeData(res));
  }

  Future<TopupTransactionV1> simulateTopupPaid(int id) async {
    final res = await _client.post(_v1('/topups/$id/simulate-paid'), headers: await _headers());
    return TopupTransactionV1.fromJson(_decodeData(res));
  }

  Future<Map<String, dynamic>> payOrderWithWallet({
    int? shipmentId,
    int? orderId,
    String? idempotencyKey,
    String? transactionPin,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey('walpay');
    final res = await _client.post(
      _v1('/payments'),
      headers: await _headers(idempotencyKey: key),
      body: jsonEncode({
        if (shipmentId != null) 'shipment_id': shipmentId,
        if (orderId != null) 'order_id': orderId,
        if (transactionPin != null && transactionPin.isNotEmpty)
          'transaction_pin': transactionPin,
        'idempotency_key': key,
      }),
    );
    return _decodeData(res);
  }

  Future<List<PayoutDestinationV1>> getDestinations() async {
    final res = await _client.get(_v1('/destinations'), headers: await _headers());
    final data = _decodeData(res);
    return (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PayoutDestinationV1.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
      _v1('/destinations/$id'),
      headers: await _headers(),
      body: jsonEncode({'is_default': true}),
    );
    return PayoutDestinationV1.fromJson(_decodeData(res));
  }

  Future<List<PayoutTransactionV1>> getWithdrawals() async {
    final res = await _client.get(_v1('/withdrawals'), headers: await _headers());
    final data = _decodeData(res);
    return (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PayoutTransactionV1.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PayoutTransactionV1> requestWithdrawal({
    required int amount,
    required int destinationId,
    String? idempotencyKey,
    String? transactionPin,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey('wd');
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

  Future<({List<RefundTransactionV1> items, List<EligibleRefundShipment> eligibleShipments})> getRefunds() async {
    final res = await _client.get(_v1('/refunds'), headers: await _headers());
    final data = _decodeData(res);
    final items = (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => RefundTransactionV1.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final eligible = (data['eligible_shipments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => EligibleRefundShipment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (items: items, eligibleShipments: eligible);
  }

  Future<RefundTransactionV1> requestRefund({
    required int shipmentId,
    required String reason,
    int? amount,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey('refund');
    final res = await _client.post(
      _v1('/refunds'),
      headers: await _headers(idempotencyKey: key),
      body: jsonEncode({
        'shipment_id': shipmentId,
        'reason': reason,
        if (amount != null) 'amount': amount,
        'idempotency_key': key,
      }),
    );
    return RefundTransactionV1.fromJson(_decodeData(res));
  }
}
