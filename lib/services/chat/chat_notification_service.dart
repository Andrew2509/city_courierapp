import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/providers/chat_provider.dart';
import 'package:city_courierapp/screens/chat/chat_detail_screen.dart';
import 'package:city_courierapp/services/chat/chat_api_service.dart';
import 'package:city_courierapp/services/security/device_metadata_service.dart';
import 'package:city_courierapp/services/token_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

/// Pure, platform-free notification gate responsible for deduplicating chat
/// notifications across WebSocket & FCM channels and suppressing alerts when the
/// user already has that exact conversation open in the foreground.
class ChatNotificationCoordinator {
  final int maxTrackedIds;
  final Queue<int> _order = Queue<int>();
  final Set<int> _seenMessageIds = <int>{};
  final Set<String> _seenClientMessageIds = <String>{};

  ChatNotificationCoordinator({this.maxTrackedIds = 250});

  bool shouldDisplay({
    required int? conversationId,
    required int? activeConversationId,
    required int? messageId,
    String? clientMessageId,
    required int? senderUserId,
    required int? currentUserId,
    bool isAppInForeground = true,
  }) {
    if (conversationId == null || conversationId <= 0) {
      return false;
    }

    if (senderUserId != null && currentUserId != null && senderUserId == currentUserId) {
      return false;
    }

    if (isAppInForeground && activeConversationId != null && activeConversationId == conversationId) {
      if (messageId != null) markSeen(messageId: messageId, clientMessageId: clientMessageId);
      return false;
    }

    if (messageId != null && _seenMessageIds.contains(messageId)) {
      return false;
    }

    if (clientMessageId != null &&
        clientMessageId.isNotEmpty &&
        _seenClientMessageIds.contains(clientMessageId)) {
      return false;
    }

    markSeen(messageId: messageId, clientMessageId: clientMessageId);
    return true;
  }

  void markSeen({int? messageId, String? clientMessageId}) {
    if (messageId != null && _seenMessageIds.add(messageId)) {
      _order.addLast(messageId);
      while (_order.length > maxTrackedIds) {
        final oldest = _order.removeFirst();
        _seenMessageIds.remove(oldest);
      }
    }
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      _seenClientMessageIds.add(clientMessageId);
      if (_seenClientMessageIds.length > maxTrackedIds) {
        _seenClientMessageIds.remove(_seenClientMessageIds.first);
      }
    }
  }

  void reset() {
    _order.clear();
    _seenMessageIds.clear();
    _seenClientMessageIds.clear();
  }
}

class ChatNotificationService {
  ChatNotificationService._();

  static final ChatNotificationService instance = ChatNotificationService._();

  static const String androidChannelId = 'city_courier_chat';
  static const String androidChannelName = 'Pesan Pengiriman';
  static const String androidChannelDescription =
      'Notifikasi chat realtime antara Customer dan Kurir City Courier.';

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ChatNotificationCoordinator _coordinator = ChatNotificationCoordinator();
  final ChatApiService _apiService = ChatApiService();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  String? _currentFcmToken;
  int? _activeConversationId;
  int? _currentUserId;

  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          unawaited(_handleNotificationPayloadJson(details.payload));
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          androidChannelId,
          androidChannelName,
          description: androidChannelDescription,
          importance: Importance.high,
        ),
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await androidPlugin?.requestNotificationsPermission();

      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((msg) {
        unawaited(_handleForegroundRemoteMessage(msg));
      });

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        unawaited(_handleRemoteMessageTap(msg));
      });

      messaging.onTokenRefresh.listen((newToken) {
        _currentFcmToken = newToken;
        unawaited(syncFcmToken());
      });

      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        unawaited(_handleRemoteMessageTap(initialMsg));
      }
    } catch (e) {
      debugPrint('[ChatNotificationService] init warning: $e');
    }
  }

  void updateSessionContext({int? currentUserId, int? activeConversationId}) {
    _currentUserId = currentUserId;
    _activeConversationId = activeConversationId;
  }

  Future<void> syncFcmToken() async {
    if (kIsWeb) return;
    try {
      final sessionToken = await TokenStore.read();
      if (sessionToken == null || sessionToken.isEmpty) return;

      _currentFcmToken ??= await FirebaseMessaging.instance.getToken();
      if (_currentFcmToken == null || _currentFcmToken!.isEmpty) return;

      final headers = await DeviceMetadataService.getHeaders();
      final deviceId = headers['X-Device-Id'];
      await _apiService.registerDeviceToken(
        fcmToken: _currentFcmToken!,
        deviceId: deviceId,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {}
  }

  Future<void> unregisterCurrentToken() async {
    try {
      _coordinator.reset();
      _currentUserId = null;
      _activeConversationId = null;
      final token = _currentFcmToken;
      if (token != null && token.isNotEmpty) {
        await _apiService.unregisterDeviceToken(token);
      }
    } catch (_) {}
  }

  Future<void> maybeNotifyFromRealtime({
    required int conversationId,
    required int? messageId,
    String? clientMessageId,
    required int? senderUserId,
    required String title,
    required String body,
    String? orderNumber,
  }) async {
    final shouldShow = _coordinator.shouldDisplay(
      conversationId: conversationId,
      activeConversationId: _activeConversationId,
      messageId: messageId,
      clientMessageId: clientMessageId,
      senderUserId: senderUserId,
      currentUserId: _currentUserId,
      isAppInForeground: true,
    );

    if (!shouldShow) return;

    await _showLocalNotification(
      notificationId: messageId ?? conversationId,
      title: title,
      body: body,
      payload: {
        'type': 'chat_message',
        'conversation_id': conversationId.toString(),
        'order_number': ?orderNumber,
        'message_id': ?messageId?.toString(),
      },
    );
  }

  Future<void> _handleForegroundRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] != 'chat_message') return;

    final conversationId = int.tryParse((data['conversation_id'] ?? '').toString());
    final messageId = int.tryParse((data['message_id'] ?? '').toString());
    final clientMessageId = data['client_message_id']?.toString();

    final shouldShow = _coordinator.shouldDisplay(
      conversationId: conversationId,
      activeConversationId: _activeConversationId,
      messageId: messageId,
      clientMessageId: clientMessageId,
      senderUserId: null,
      currentUserId: _currentUserId,
      isAppInForeground: true,
    );

    if (!shouldShow) return;

    final title = message.notification?.title ??
        (data['order_number'] != null ? 'Pesan • ${data['order_number']}' : 'Pesan Pengiriman');
    final body = message.notification?.body ?? 'Anda menerima pesan baru.';

    await _showLocalNotification(
      notificationId: messageId ?? conversationId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: data.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<void> _showLocalNotification({
    required int notificationId,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        channelDescription: androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        notificationId.abs() & 0x7fffffff,
        title,
        body,
        details,
        payload: jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    if (message.data['type'] != 'chat_message') return;
    await _navigateToConversationFromData(message.data);
  }

  Future<void> _handleNotificationPayloadJson(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        await _navigateToConversationFromData(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  Future<void> _navigateToConversationFromData(Map<String, dynamic> data) async {
    final convId = int.tryParse((data['conversation_id'] ?? '').toString());
    if (convId == null || convId <= 0) return;

    final token = await TokenStore.read();
    if (token == null || token.isEmpty) return;

    await WidgetsBinding.instance.endOfFrame;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    try {
      final conv = await _apiService.getConversation(convId);
      final ctx = _navigatorKey?.currentContext;
      int? knownUserId;
      if (ctx != null && ctx.mounted) {
        knownUserId = ctx.read<ChatProvider>().currentUserId;
      }
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversation: conv,
            knownUserId: knownUserId,
          ),
        ),
      );
    } catch (_) {}
  }
}
