import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:city_courierapp/models/call/call_models.dart';
import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/services/chat/chat_api_service.dart';

typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

/// Lightweight Pusher/Laravel Reverb WebSocket v7 client over WebSocketChannel.
/// Speaks directly to Laravel Reverb with Sanctum channel authentication and
/// automatic exponential-backoff reconnect, without native SDK build coupling.
class ChatRealtimeService {
  final ChatApiService _apiService;
  final WebSocketConnector _connector;

  ChatRealtimeConfig? _config;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  String? _socketId;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;
  bool _disposed = false;
  bool _manualDisconnect = false;

  final Set<String> _desiredChannels = <String>{};
  final Set<String> _subscribedChannels = <String>{};

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);

  final StreamController<({int conversationId, ChatMessageModel message, int? customerUnread, int? courierUnread})>
      _messageSentController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _conversationUpdatedController =
      StreamController.broadcast();
  final StreamController<({int conversationId, List<int> messageIds, ChatDeliveryStatus status})>
      _messageStatusController = StreamController.broadcast();
  final StreamController<({int conversationId, int userId, String role, bool isTyping})>
      _typingController = StreamController.broadcast();
  final StreamController<CallSessionModel> _incomingCallController = StreamController.broadcast();
  final StreamController<CallSessionModel> _callUpdatedController = StreamController.broadcast();
  final StreamController<CallSignalModel> _callSignalController = StreamController.broadcast();

  Stream<({int conversationId, ChatMessageModel message, int? customerUnread, int? courierUnread})>
      get onMessageSent => _messageSentController.stream;
  Stream<Map<String, dynamic>> get onConversationUpdated => _conversationUpdatedController.stream;
  Stream<({int conversationId, List<int> messageIds, ChatDeliveryStatus status})> get onMessageStatus =>
      _messageStatusController.stream;
  Stream<({int conversationId, int userId, String role, bool isTyping})> get onUserTyping =>
      _typingController.stream;
  Stream<CallSessionModel> get onIncomingCall => _incomingCallController.stream;
  Stream<CallSessionModel> get onCallUpdated => _callUpdatedController.stream;
  Stream<CallSignalModel> get onCallSignal => _callSignalController.stream;

  bool get isConnected => isConnectedNotifier.value;

  ChatRealtimeService({
    required ChatApiService apiService,
    WebSocketConnector? connector,
  })  : _apiService = apiService,
        _connector = connector ?? WebSocketChannel.connect;

  Future<void> connect(ChatRealtimeConfig config) async {
    if (_disposed || !config.isConnectable) return;
    _config = config;
    _manualDisconnect = false;

    if (_channel != null && (isConnected || _isConnecting)) {
      return;
    }

    _isConnecting = true;
    await _closeSocketOnly();
    _isConnecting = true;

    try {
      final wsScheme = (config.scheme == 'https' || config.scheme == 'wss') ? 'wss' : 'ws';
      final uri = Uri(
        scheme: wsScheme,
        host: config.host,
        port: config.port,
        path: '/app/${config.key}',
        queryParameters: const {
          'protocol': '7',
          'client': 'dart',
          'version': '1.0.0',
          'flash': 'false',
        },
      );

      final channel = _connector(uri);
      _channel = channel;

      _wsSubscription = channel.stream.listen(
        _handleRawFrame,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: false,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  Future<void> subscribePrivateConversation(int conversationId) async {
    await subscribeChannel('private-conversation.$conversationId');
  }

  Future<void> unsubscribePrivateConversation(int conversationId) async {
    await unsubscribeChannel('private-conversation.$conversationId');
  }

  Future<void> subscribePrivateUser(int userId) async {
    await subscribeChannel('private-user.$userId');
  }

  Future<void> subscribePrivateCall(int callId) async {
    await subscribeChannel('private-call.$callId');
  }

  Future<void> unsubscribePrivateCall(int callId) async {
    await unsubscribeChannel('private-call.$callId');
  }

  Future<void> subscribeChannel(String channelName) async {
    _desiredChannels.add(channelName);
    if (isConnected && _socketId != null && !_subscribedChannels.contains(channelName)) {
      await _authorizeAndSendSubscribe(channelName);
    }
  }

  Future<void> unsubscribeChannel(String channelName) async {
    _desiredChannels.remove(channelName);
    if (_subscribedChannels.remove(channelName) && _channel != null && isConnected) {
      _sendJson({
        'event': 'pusher:unsubscribe',
        'data': {'channel': channelName},
      });
    }
  }

  void _handleRawFrame(dynamic raw) {
    if (_disposed || raw == null) return;
    try {
      final map = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(jsonDecode(raw.toString()) as Map);
      final eventName = (map['event'] ?? '').toString();
      final channelName = map['channel']?.toString();
      final dataPayload = _parseDataMap(map['data']);

      if (eventName == 'pusher:connection_established') {
        _socketId = dataPayload['socket_id']?.toString();
        _isConnecting = false;
        _reconnectAttempts = 0;
        isConnectedNotifier.value = true;
        _startHeartbeat();
        unawaited(_resubscribeDesiredChannels());
        return;
      }

      if (eventName == 'pusher:ping') {
        _sendJson({'event': 'pusher:pong', 'data': {}});
        return;
      }

      if (eventName == 'pusher_internal:subscription_succeeded' && channelName != null) {
        _subscribedChannels.add(channelName);
        return;
      }

      _dispatchDomainEvent(eventName, dataPayload);
    } catch (_) {
      // Ignore malformed frame silently to keep socket alive.
    }
  }

  void _dispatchDomainEvent(String eventName, Map<String, dynamic> data) {
    if (eventName == 'message.sent' || eventName.endsWith(r'\MessageSentBroadcast')) {
      final rawMsg = data['message'];
      if (rawMsg is Map) {
        final msg = ChatMessageModel.fromJson(Map<String, dynamic>.from(rawMsg));
        _messageSentController.add((
          conversationId: (data['conversation_id'] as num?)?.toInt() ?? msg.conversationId,
          message: msg,
          customerUnread: (data['customer_unread_count'] as num?)?.toInt(),
          courierUnread: (data['courier_unread_count'] as num?)?.toInt(),
        ));
      }
      return;
    }

    if (eventName == 'conversation.updated' || eventName.endsWith(r'\ConversationUpdatedBroadcast')) {
      _conversationUpdatedController.add(data);
      return;
    }

    if (eventName == 'message.status' || eventName.endsWith(r'\MessageStatusUpdatedBroadcast')) {
      final convId = (data['conversation_id'] as num?)?.toInt();
      final rawIds = (data['message_ids'] as List?) ?? const [];
      final ids = rawIds.map((e) => (e as num).toInt()).toList();
      final status = ChatDeliveryStatus.fromString(data['delivery_status']?.toString());
      if (convId != null && ids.isNotEmpty) {
        _messageStatusController.add((conversationId: convId, messageIds: ids, status: status));
      }
      return;
    }

    if (eventName == 'user.typing' || eventName.endsWith(r'\UserTypingBroadcast')) {
      final convId = (data['conversation_id'] as num?)?.toInt();
      final userId = (data['user_id'] as num?)?.toInt();
      if (convId != null && userId != null) {
        _typingController.add((
          conversationId: convId,
          userId: userId,
          role: (data['role'] ?? 'courier').toString(),
          isTyping: data['is_typing'] == true,
        ));
      }
      return;
    }

    if (eventName == 'call.incoming' || eventName.endsWith(r'\IncomingCallBroadcast')) {
      final rawCall = data['call'];
      if (rawCall is Map) {
        _incomingCallController.add(CallSessionModel.fromJson(Map<String, dynamic>.from(rawCall)));
      }
      return;
    }

    if (eventName == 'call.updated' || eventName.endsWith(r'\CallSessionUpdatedBroadcast')) {
      final rawCall = data['call'];
      if (rawCall is Map) {
        _callUpdatedController.add(CallSessionModel.fromJson(Map<String, dynamic>.from(rawCall)));
      }
      return;
    }

    if (eventName == 'call.signal' || eventName.endsWith(r'\CallSignalBroadcast')) {
      _callSignalController.add(CallSignalModel.fromJson(data));
    }
  }

  Future<void> _resubscribeDesiredChannels() async {
    final channels = List<String>.from(_desiredChannels);
    for (final ch in channels) {
      if (!isConnected || _socketId == null) break;
      await _authorizeAndSendSubscribe(ch);
    }
  }

  Future<void> _authorizeAndSendSubscribe(String channelName) async {
    final socketId = _socketId;
    final config = _config;
    if (socketId == null || config == null) return;

    final auth = await _apiService.authenticateBroadcastChannel(
      authEndpoint: config.authEndpoint,
      socketId: socketId,
      channelName: channelName,
    );

    if (auth == null || !isConnected || _disposed) return;

    _sendJson({
      'event': 'pusher:subscribe',
      'data': {
        'auth': auth,
        'channel': channelName,
      },
    });
  }

  void _sendJson(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (isConnected) {
        _sendJson({'event': 'pusher:ping', 'data': {}});
      }
    });
  }

  void _handleDisconnect() {
    isConnectedNotifier.value = false;
    _socketId = null;
    _subscribedChannels.clear();
    _pingTimer?.cancel();

    if (_disposed || _manualDisconnect || _config == null || _desiredChannels.isEmpty) {
      return;
    }

    _reconnectTimer?.cancel();
    final backoffSeconds = min(30, pow(2, min(_reconnectAttempts, 4)).toInt() * 2);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      if (!_disposed && !_manualDisconnect && _config != null) {
        unawaited(connect(_config!));
      }
    });
  }

  Map<String, dynamic> _parseDataMap(dynamic rawData) {
    if (rawData == null) return const {};
    if (rawData is Map) return Map<String, dynamic>.from(rawData);
    if (rawData is String && rawData.trim().isNotEmpty) {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return const {};
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _desiredChannels.clear();
    await _closeSocketOnly();
  }

  Future<void> _closeSocketOnly() async {
    _isConnecting = false;
    isConnectedNotifier.value = false;
    _socketId = null;
    _subscribedChannels.clear();
    _pingTimer?.cancel();
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messageSentController.close();
    await _conversationUpdatedController.close();
    await _messageStatusController.close();
    await _typingController.close();
    await _incomingCallController.close();
    await _callUpdatedController.close();
    await _callSignalController.close();
    isConnectedNotifier.dispose();
  }
}
