import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/token_store.dart';

class ChatApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const ChatApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class ChatApiService {
  final http.Client _client;
  final Future<String?> Function() _tokenReader;
  final String baseUrl;

  ChatApiService({
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

  Future<Map<String, String>> _headers({bool jsonContent = true}) async {
    final token = await _tokenReader();
    return {
      'Accept': 'application/json',
      if (jsonContent) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(response.body);
      decoded = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded['success'] == false) {
        throw ChatApiException(
          decoded['message']?.toString() ?? 'Permintaan chat gagal.',
          statusCode: response.statusCode,
          errorCode: decoded['error_code']?.toString(),
        );
      }
      return decoded;
    }

    throw ChatApiException(
      decoded['message']?.toString() ?? 'Gagal memproses chat (${response.statusCode})',
      statusCode: response.statusCode,
      errorCode: decoded['error_code']?.toString(),
    );
  }

  Future<({List<ConversationModel> conversations, int totalUnread, int currentPage, int lastPage})>
      getConversations({int page = 1, int perPage = 20}) async {
    final uri = _v1('/chat/conversations').replace(queryParameters: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });

    final response = await _client.get(uri, headers: await _headers()).timeout(const Duration(seconds: 20));
    final body = _decodeResponse(response);
    final data = (body['data'] is Map) ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};
    final rawList = (data['conversations'] as List?) ?? const [];
    final pagination = (data['pagination'] is Map) ? Map<String, dynamic>.from(data['pagination'] as Map) : const {};

    return (
      conversations: rawList
          .whereType<Map>()
          .map((e) => ConversationModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalUnread: (data['total_unread'] as num?)?.toInt() ?? 0,
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? page,
      lastPage: (pagination['last_page'] as num?)?.toInt() ?? page,
    );
  }

  Future<int> getUnreadSummary() async {
    final response = await _client
        .get(_v1('/chat/unread-count'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final body = _decodeResponse(response);
    return (body['data']?['total_unread'] as num?)?.toInt() ?? 0;
  }

  Future<ConversationModel> openConversationByOrder(String orderIdentifier) async {
    final response = await _client
        .post(
          _v1('/chat/conversations/by-order/${Uri.encodeComponent(orderIdentifier)}'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decodeResponse(response);
    return ConversationModel.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<ConversationModel> getConversation(int conversationId) async {
    final response = await _client
        .get(_v1('/chat/conversations/$conversationId'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final body = _decodeResponse(response);
    return ConversationModel.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<({List<ChatMessageModel> messages, bool hasMore, int? nextBeforeId})> getMessages(
    int conversationId, {
    int? beforeId,
    int limit = 30,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (beforeId != null) {
      query['before_id'] = beforeId.toString();
    }

    final uri = _v1('/chat/conversations/$conversationId/messages').replace(queryParameters: query);
    final response = await _client.get(uri, headers: await _headers()).timeout(const Duration(seconds: 20));
    final body = _decodeResponse(response);
    final data = (body['data'] is Map) ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};
    final rawList = (data['messages'] as List?) ?? const [];

    return (
      messages: rawList
          .whereType<Map>()
          .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: data['has_more'] == true,
      nextBeforeId: (data['next_before_id'] as num?)?.toInt(),
    );
  }

  Future<ChatMessageModel> sendMessage({
    required int conversationId,
    String? body,
    required String clientMessageId,
    String? imagePath,
  }) async {
    final uri = _v1('/chat/conversations/$conversationId/messages');

    if (imagePath != null && imagePath.isNotEmpty) {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _headers(jsonContent: false));
      request.fields['client_message_id'] = clientMessageId;
      request.fields['message_type'] = 'image';
      if (body != null && body.trim().isNotEmpty) {
        request.fields['body'] = body.trim();
      }
      request.files.add(await http.MultipartFile.fromPath('media', imagePath));

      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final parsed = _decodeResponse(response);
      return ChatMessageModel.fromJson(Map<String, dynamic>.from(parsed['data'] as Map));
    }

    final response = await _client
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({
            'body': body?.trim() ?? '',
            'message_type': 'text',
            'client_message_id': clientMessageId,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final parsed = _decodeResponse(response);
    return ChatMessageModel.fromJson(Map<String, dynamic>.from(parsed['data'] as Map));
  }

  Future<void> markRead(int conversationId, {int? lastReadMessageId}) async {
    await _client
        .post(
          _v1('/chat/conversations/$conversationId/read'),
          headers: await _headers(),
          body: jsonEncode({
            'last_read_message_id': ?lastReadMessageId,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  Future<void> sendTyping(int conversationId, {bool isTyping = true}) async {
    await _client
        .post(
          _v1('/chat/conversations/$conversationId/typing'),
          headers: await _headers(),
          body: jsonEncode({'is_typing': isTyping}),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<ChatRealtimeConfig?> getRealtimeConfig() async {
    try {
      final response = await _client
          .get(_v1('/chat/realtime-config'), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      final body = _decodeResponse(response);
      if (body['data'] is Map) {
        return ChatRealtimeConfig.fromJson(Map<String, dynamic>.from(body['data'] as Map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> authenticateBroadcastChannel({
    required String authEndpoint,
    required String socketId,
    required String channelName,
  }) async {
    final uri = Uri.parse(baseUrl).resolve(authEndpoint);
    final response = await _client
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({
            'socket_id': socketId,
            'channel_name': channelName,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['auth'] != null) {
      return decoded['auth'].toString();
    }
    return null;
  }

  Future<WhatsappBridgeStatus?> getWhatsappStatus() async {
    final response = await _client
        .get(_v1('/chat/whatsapp/status'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final body = _decodeResponse(response);
    if (body['data'] is Map) {
      return WhatsappBridgeStatus.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    }
    return null;
  }

  Future<WhatsappBridgeStatus?> updateWhatsappOptIn({
    required bool optIn,
    int? conversationId,
  }) async {
    final response = await _client
        .post(
          _v1('/chat/whatsapp/opt-in'),
          headers: await _headers(),
          body: jsonEncode({
            'opt_in': optIn,
            'source': 'app_toggle',
            'conversation_id': ?conversationId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeResponse(response);
    if (body['data'] is Map) {
      return WhatsappBridgeStatus.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    }
    return null;
  }

  Future<void> registerDeviceToken({
    required String fcmToken,
    String? deviceId,
    String platform = 'android',
  }) async {
    await _client
        .post(
          _v1('/devices/fcm-token'),
          headers: await _headers(),
          body: jsonEncode({
            'fcm_token': fcmToken,
            'device_id': ?deviceId,
            'platform': platform,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _client
        .delete(
          _v1('/devices/fcm-token'),
          headers: await _headers(),
          body: jsonEncode({'fcm_token': fcmToken}),
        )
        .timeout(const Duration(seconds: 10));
  }
}
