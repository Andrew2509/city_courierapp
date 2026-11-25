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
import 'package:city_courierapp/services/call/call_api_service.dart';
import 'package:city_courierapp/services/chat/chat_api_service.dart';
import 'package:city_courierapp/services/security/device_metadata_service.dart';
import 'package:city_courierapp/services/token_store.dart';

const String _kCallChannelId = 'city_courier_calls';
const String _kCallChannelName = 'Panggilan Suara Masuk';
const String _kCallChannelDesc = 'Notifikasi panggilan suara masuk antara Customer dan Kurir City Courier.';

int _callNotificationId(int callId) => (callId.abs() & 0x7fffffff) + 500000;

Future<void> _showBackgroundIncomingCallNotification(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data,
) async {
  final callId = int.tryParse((data['call_id'] ?? '').toString());
  if (callId == null || callId <= 0) return;

  final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _kCallChannelId,
      _kCallChannelName,
      description: _kCallChannelDesc,
      importance: Importance.max,
    ),
  );

  final callerName = (data['caller_name'] ?? 'Pengguna City Courier').toString();
  final orderNum = (data['order_number'] ?? '').toString().trim();
  final bodyText = orderNum.isNotEmpty
      ? 'Panggilan suara masuk • Pesanan $orderNum'
      : 'Panggilan suara masuk dari $callerName';

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _kCallChannelId,
      _kCallChannelName,
      channelDescription: _kCallChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      additionalFlags: Int32List.fromList(<int>[4]),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'ACCEPT_CALL',
          'Terima',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'REJECT_CALL',
          'Tolak',
          cancelNotification: true,
        ),
      ],
    ),
  );

  await plugin.show(
    _callNotificationId(callId),
    'Panggilan Masuk • $callerName',
    bodyText,
    details,
    payload: jsonEncode(data.map((k, v) => MapEntry(k, v.toString()))),
  );
}

@pragma('vm:entry-point')
Future<void> onDidReceiveBackgroundCallNotification(NotificationResponse details) async {
  try {
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return;
    final data = Map<String, dynamic>.from(decoded);
    if (data['type'] != 'incoming_call') return;

    final callId = int.tryParse((data['call_id'] ?? '').toString());
    if (callId == null || callId <= 0) return;

    if (details.actionId == 'REJECT_CALL') {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      await plugin.cancel(_callNotificationId(callId));
      final token = await TokenStore.read();
      if (token != null && token.isNotEmpty) {
        await CallApiService().rejectCall(callId, reason: 'rejected_from_notification');
      }
    }
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    if (type != 'incoming_call' && type != 'call_cancelled') {
      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );

    if (type == 'incoming_call') {
      await _showBackgroundIncomingCallNotification(plugin, Map<String, dynamic>.from(data));
    } else {
      final callId = int.tryParse((data['call_id'] ?? '').toString());
      if (callId != null && callId > 0) {
        await plugin.cancel(_callNotificationId(callId));
      }
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
  Future<void> Function(Map<String, dynamic> data, {bool autoAccept})? _callPushHandler;
  Map<String, dynamic>? _pendingCallPushData;
  bool _pendingCallAutoAccept = false;

  void attachCallPushHandler(
    Future<void> Function(Map<String, dynamic> data, {bool autoAccept}) handler,
  ) {
    _callPushHandler = handler;
    final pending = _pendingCallPushData;
    if (pending != null) {
      final autoAccept = _pendingCallAutoAccept;
      _pendingCallPushData = null;
      _pendingCallAutoAccept = false;
      unawaited(handler(pending, autoAccept: autoAccept));
    }
  }

  Future<void> cancelIncomingCallNotification(int callId) async {
    try {
      await _localNotifications.cancel(_callNotificationId(callId));
    } catch (_) {}
  }

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
          unawaited(_handleNotificationResponse(details));
        },
        onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundCallNotification,
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
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kCallChannelId,
          _kCallChannelName,
          description: _kCallChannelDesc,
          importance: Importance.max,
        ),
      );

      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true && launchDetails?.notificationResponse != null) {
        unawaited(_handleNotificationResponse(launchDetails!.notificationResponse!));
      }

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
    final type = (data['type'] ?? '').toString();

    if (type == 'incoming_call' || type == 'call_cancelled') {
      final callId = int.tryParse((data['call_id'] ?? '').toString());
      if (type == 'call_cancelled' && callId != null && callId > 0) {
        await cancelIncomingCallNotification(callId);
      }
      final mapped = data.map((k, v) => MapEntry(k, v.toString()));
      if (_callPushHandler != null) {
        await _callPushHandler!(mapped, autoAccept: false);
      } else if (type == 'incoming_call') {
        _pendingCallPushData = mapped;
        _pendingCallAutoAccept = false;
      }
      return;
    }

    if (type != 'chat_message') return;

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
    final type = (message.data['type'] ?? '').toString();
    if (type == 'incoming_call') {
      final mapped = message.data.map((k, v) => MapEntry(k, v.toString()));
      await _dispatchCallTap(mapped, autoAccept: false);
      return;
    }
    if (type != 'chat_message') return;
    await _navigateToConversationFromData(message.data);
  }

  Future<void> _handleNotificationResponse(NotificationResponse details) async {
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      if (data['type'] == 'incoming_call') {
        final callId = int.tryParse((data['call_id'] ?? '').toString());
        if (callId != null && callId > 0) {
          await cancelIncomingCallNotification(callId);
        }
        if (details.actionId == 'REJECT_CALL') {
          if (callId != null && callId > 0) {
            final token = await TokenStore.read();
            if (token != null && token.isNotEmpty) {
              await CallApiService().rejectCall(callId, reason: 'rejected_from_notification');
            }
          }
          return;
        }
        await _dispatchCallTap(data, autoAccept: details.actionId == 'ACCEPT_CALL');
        return;
      }
      await _navigateToConversationFromData(data);
    } catch (_) {}
  }

  Future<void> _dispatchCallTap(Map<String, dynamic> data, {required bool autoAccept}) async {
    if (_callPushHandler != null) {
      await _callPushHandler!(data, autoAccept: autoAccept);
    } else {
      _pendingCallPushData = data;
      _pendingCallAutoAccept = autoAccept;
    }
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
