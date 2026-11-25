import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:city_courierapp/models/call/call_models.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class CallApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const CallApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class CallApiResponse {
  final CallSessionModel? call;
  final List<IceServerConfig> iceServers;

  const CallApiResponse({this.call, this.iceServers = const []});
}

class CallApiService {
  final http.Client _client;
  final Future<String?> Function() _tokenReader;
  final String baseUrl;

  CallApiService({
    http.Client? client,
    Future<String?> Function()? tokenReader,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _tokenReader = tokenReader ?? TokenStore.read,
        baseUrl = baseUrl ?? ApiService.baseUrl;

  Uri _v1(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (normalizedBase.endsWith('/v1')) {
      return Uri.parse('$normalizedBase$path');
    }
    return Uri.parse('$normalizedBase/v1$path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokenReader();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(response.body);
      decoded = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded['success'] == false) {
        throw CallApiException(
          decoded['message']?.toString() ?? 'Permintaan panggilan gagal.',
          statusCode: response.statusCode,
          errorCode: decoded['error_code']?.toString(),
        );
      }
      return decoded;
    }

    throw CallApiException(
      decoded['message']?.toString() ?? 'Gagal memproses panggilan (${response.statusCode})',
      statusCode: response.statusCode,
      errorCode: decoded['error_code']?.toString(),
    );
  }

  CallApiResponse _parseCallEnvelope(Map<String, dynamic> body) {
    final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : const <String, dynamic>{};
    final rawCall = data['call'];
    final rawIce = (data['ice_servers'] as List?) ?? const [];

    return CallApiResponse(
      call: rawCall is Map ? CallSessionModel.fromJson(Map<String, dynamic>.from(rawCall)) : null,
      iceServers: rawIce
          .whereType<Map>()
          .map((e) => IceServerConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<CallApiResponse> getIncomingCall() async {
    final response = await _client
        .get(_v1('/calls/incoming'), headers: await _headers())
        .timeout(const Duration(seconds: 12));
    return _parseCallEnvelope(_decode(response));
  }

  Future<CallApiResponse> initiateCall({
    int? conversationId,
    String? orderIdentifier,
    Map<String, dynamic>? offer,
  }) async {
    final response = await _client
        .post(
          _v1('/calls/initiate'),
          headers: await _headers(),
          body: jsonEncode({
            'conversation_id': ?conversationId,
            'order_identifier': ?orderIdentifier,
            'offer': ?offer,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parseCallEnvelope(_decode(response));
  }

  Future<CallApiResponse> getCallStatus(int callId) async {
    final response = await _client
        .get(_v1('/calls/$callId'), headers: await _headers())
        .timeout(const Duration(seconds: 12));
    return _parseCallEnvelope(_decode(response));
  }

  Future<CallApiResponse> acceptCall(int callId, {Map<String, dynamic>? answer}) async {
    final response = await _client
        .post(
          _v1('/calls/$callId/accept'),
          headers: await _headers(),
          body: jsonEncode({
            'answer': ?answer,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parseCallEnvelope(_decode(response));
  }

  Future<CallApiResponse> rejectCall(int callId, {String? reason}) async {
    final response = await _client
        .post(
          _v1('/calls/$callId/reject'),
          headers: await _headers(),
          body: jsonEncode({
            'reason': ?reason,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return _parseCallEnvelope(_decode(response));
  }

  Future<CallApiResponse> endCall(int callId, {String? status, String? reason}) async {
    final response = await _client
        .post(
          _v1('/calls/$callId/end'),
          headers: await _headers(),
          body: jsonEncode({
            'status': ?status,
            'reason': ?reason,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return _parseCallEnvelope(_decode(response));
  }

  Future<void> sendSignal(
    int callId, {
    required String signalType,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          _v1('/calls/$callId/signals'),
          headers: await _headers(),
          body: jsonEncode({
            'signal_type': signalType,
            'payload': payload,
          }),
        )
        .timeout(const Duration(seconds: 12));
    _decode(response);
  }

  Future<({CallSessionModel? call, List<CallSignalModel> signals})> getSignals(
    int callId, {
    int afterId = 0,
  }) async {
    final uri = _v1('/calls/$callId/signals').replace(
      queryParameters: {'after_id': afterId.toString()},
    );
    final response = await _client.get(uri, headers: await _headers()).timeout(const Duration(seconds: 12));
    final body = _decode(response);
    final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : const <String, dynamic>{};
    final rawCall = data['call'];
    final rawSignals = (data['signals'] as List?) ?? const [];

    return (
      call: rawCall is Map ? CallSessionModel.fromJson(Map<String, dynamic>.from(rawCall)) : null,
      signals: rawSignals
          .whereType<Map>()
          .map((e) => CallSignalModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
