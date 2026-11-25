import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/services/chat/chat_api_service.dart';
import 'package:city_courierapp/services/chat/chat_notification_service.dart';
import 'package:city_courierapp/services/chat/chat_realtime_service.dart';

/// Central Provider managing City Courier internal conversations, messages,
/// unread counts, realtime Reverb WebSocket updates, and safe polling fallback.
class ChatProvider extends ChangeNotifier {
  final ChatApiService _apiService;
  final ChatRealtimeService _realtimeService;
  final Random _random = Random.secure();

  int? _currentUserId;
  bool _realtimeInitialized = false;
  bool _disposed = false;

  List<ConversationModel> _conversations = [];
  bool _loadingConversations = false;
  String? _conversationsError;
  int _totalUnreadCount = 0;

  final Map<int, List<ChatMessageModel>> _messagesByConversation = {};
  final Map<int, bool> _hasMoreByConversation = {};
  final Map<int, int?> _nextBeforeIdByConversation = {};
  final Map<int, bool> _loadingMessages = {};
  final Map<int, bool> _counterpartyTyping = {};
  final Map<int, Timer> _typingExpiryTimers = {};
  final Map<int, DateTime> _lastTypingSentAt = {};

  int? _activeConversationId;
  WhatsappBridgeStatus? _whatsappStatus;
  String? _lastWhatsappError;

  Timer? _fallbackPollingTimer;
  final List<StreamSubscription> _subscriptions = [];

  ChatProvider({
    ChatApiService? apiService,
    ChatRealtimeService? realtimeService,
  })  : _apiService = apiService ?? ChatApiService(),
        _realtimeService = realtimeService ??
            ChatRealtimeService(apiService: apiService ?? ChatApiService()) {
    _bindRealtimeStreams();
  }

  int? get currentUserId => _currentUserId;
  List<ConversationModel> get conversations => List.unmodifiable(_conversations);
  bool get loadingConversations => _loadingConversations;
  String? get conversationsError => _conversationsError;
  int get totalUnreadCount => _totalUnreadCount;
  int? get activeConversationId => _activeConversationId;
  WhatsappBridgeStatus? get whatsappStatus => _whatsappStatus;
  String? get lastWhatsappError => _lastWhatsappError;
  bool get isRealtimeConnected => _realtimeService.isConnected;
  ValueListenable<bool> get realtimeConnectedListenable => _realtimeService.isConnectedNotifier;
  ChatRealtimeService get realtimeService => _realtimeService;

  List<ChatMessageModel> messagesFor(int conversationId) =>
      List.unmodifiable(_messagesByConversation[conversationId] ?? const []);

  bool hasMoreFor(int conversationId) => _hasMoreByConversation[conversationId] ?? false;
  bool isLoadingMessages(int conversationId) => _loadingMessages[conversationId] ?? false;
  bool isCounterpartyTyping(int conversationId) => _counterpartyTyping[conversationId] ?? false;

  void _bindRealtimeStreams() {
    _subscriptions.add(_realtimeService.onMessageSent.listen(_handleRealtimeMessage));
    _subscriptions.add(_realtimeService.onConversationUpdated.listen(_handleConversationUpdated));
    _subscriptions.add(_realtimeService.onMessageStatus.listen(_handleMessageStatus));
    _subscriptions.add(_realtimeService.onUserTyping.listen(_handleUserTyping));
    _realtimeService.isConnectedNotifier.addListener(_syncFallbackPolling);
  }

  Future<void> bindAuthenticatedUser(int userId) async {
    if (_currentUserId == userId && _realtimeInitialized) {
      ChatNotificationService.instance.updateSessionContext(
        currentUserId: userId,
        activeConversationId: _activeConversationId,
      );
      await _realtimeService.subscribePrivateUser(userId);
      return;
    }

    _currentUserId = userId;
    ChatNotificationService.instance.updateSessionContext(
      currentUserId: userId,
      activeConversationId: _activeConversationId,
    );
    unawaited(ChatNotificationService.instance.syncFcmToken());
    await _ensureRealtimeConnected();
    await _realtimeService.subscribePrivateUser(userId);
    await refreshUnreadSummary();
  }

  Future<void> _ensureRealtimeConnected() async {
    if (_realtimeInitialized && _realtimeService.isConnected) return;
    _realtimeInitialized = true;
    final config = await _apiService.getRealtimeConfig();
    if (config != null && config.isConnectable) {
      await _realtimeService.connect(config);
    }
    _syncFallbackPolling();
  }

  void _syncFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    if (_disposed || _currentUserId == null || _realtimeService.isConnected) {
      return;
    }

    // Only poll when WebSocket is unavailable: 10s inside active room, 30s otherwise.
    final interval = _activeConversationId != null
        ? const Duration(seconds: 10)
        : const Duration(seconds: 30);

    _fallbackPollingTimer = Timer.periodic(interval, (_) {
      if (_activeConversationId != null) {
        unawaited(loadLatestMessages(_activeConversationId!, silent: true));
      } else if (_currentUserId != null) {
        unawaited(refreshUnreadSummary());
      }
    });
  }

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      _loadingConversations = true;
      _conversationsError = null;
      notifyListeners();
    }

    try {
      final result = await _apiService.getConversations();
      _conversations = result.conversations;
      _totalUnreadCount = result.totalUnread;
      _conversationsError = null;
    } catch (e) {
      _conversationsError = e.toString();
    } finally {
      _loadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadSummary() async {
    try {
      _totalUnreadCount = await _apiService.getUnreadSummary();
      notifyListeners();
    } catch (_) {}
  }

  Future<ConversationModel> openOrderConversation(String orderIdentifier) async {
    final conv = await _apiService.openConversationByOrder(orderIdentifier);
    _upsertConversation(conv);
    await _ensureRealtimeConnected();
    if (_currentUserId != null) {
      await _realtimeService.subscribePrivateUser(_currentUserId!);
    }
    notifyListeners();
    return conv;
  }

  Future<void> enterConversation(int conversationId, {int? knownUserId}) async {
    _activeConversationId = conversationId;
    ChatNotificationService.instance.updateSessionContext(
      currentUserId: knownUserId ?? _currentUserId,
      activeConversationId: _activeConversationId,
    );
    if (knownUserId != null) {
      await bindAuthenticatedUser(knownUserId);
    } else {
      await _ensureRealtimeConnected();
    }

    await _realtimeService.subscribePrivateConversation(conversationId);
    _syncFallbackPolling();
    await loadLatestMessages(conversationId);
  }

  Future<void> leaveConversation(int conversationId) async {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
      ChatNotificationService.instance.updateSessionContext(
        currentUserId: _currentUserId,
        activeConversationId: null,
      );
    }
    await _realtimeService.unsubscribePrivateConversation(conversationId);
    _syncFallbackPolling();
  }

  Future<void> loadLatestMessages(int conversationId, {bool silent = false}) async {
    if (!silent) {
      _loadingMessages[conversationId] = true;
      notifyListeners();
    }

    try {
      final result = await _apiService.getMessages(conversationId);
      final currentList = _messagesByConversation[conversationId] ?? [];
      final failedLocal = currentList
          .where((m) => m.deliveryStatus == ChatDeliveryStatus.failed || m.deliveryStatus == ChatDeliveryStatus.sending)
          .toList();

      final merged = _mergeMessageLists(result.messages, failedLocal);
      _messagesByConversation[conversationId] = merged;
      _hasMoreByConversation[conversationId] = result.hasMore;
      _nextBeforeIdByConversation[conversationId] = result.nextBeforeId;

      if (_activeConversationId == conversationId && result.messages.isNotEmpty) {
        final latestServerId = result.messages.last.id;
        unawaited(_markConversationRead(conversationId, upToId: latestServerId));
      }
    } finally {
      _loadingMessages[conversationId] = false;
      notifyListeners();
    }
  }

  Future<void> loadOlderMessages(int conversationId) async {
    if (isLoadingMessages(conversationId) || !hasMoreFor(conversationId)) return;
    final nextBefore = _nextBeforeIdByConversation[conversationId];
    if (nextBefore == null) return;

    _loadingMessages[conversationId] = true;
    notifyListeners();

    try {
      final result = await _apiService.getMessages(conversationId, beforeId: nextBefore);
      final existing = _messagesByConversation[conversationId] ?? [];
      _messagesByConversation[conversationId] = _mergeMessageLists(result.messages, existing);
      _hasMoreByConversation[conversationId] = result.hasMore;
      _nextBeforeIdByConversation[conversationId] = result.nextBeforeId;
    } finally {
      _loadingMessages[conversationId] = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required ConversationModel conversation,
    String? body,
    String? imagePath,
  }) async {
    final trimmedBody = body?.trim();
    if ((trimmedBody == null || trimmedBody.isEmpty) && (imagePath == null || imagePath.isEmpty)) {
      return;
    }

    final clientMsgId = _generateClientUuid();
    final optimistic = ChatMessageModel(
      conversationId: conversation.id,
      senderUserId: _currentUserId,
      senderRole: conversation.viewerRole,
      clientMessageId: clientMsgId,
      channel: 'internal',
      messageType: imagePath != null ? 'image' : 'text',
      body: trimmedBody,
      localMediaPath: imagePath,
      deliveryStatus: ChatDeliveryStatus.sending,
      sentAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    _upsertMessage(conversation.id, optimistic);
    notifyListeners();

    await _dispatchSend(conversation.id, optimistic);
  }

  Future<void> retryFailedMessage(int conversationId, String clientMessageId) async {
    final list = _messagesByConversation[conversationId] ?? [];
    final idx = list.indexWhere((m) => m.clientMessageId == clientMessageId);
    if (idx < 0) return;

    final retried = list[idx].copyWith(
      deliveryStatus: ChatDeliveryStatus.sending,
      errorMessage: null,
    );
    list[idx] = retried;
    notifyListeners();

    await _dispatchSend(conversationId, retried);
  }

  Future<void> _dispatchSend(int conversationId, ChatMessageModel localMsg) async {
    try {
      final serverMsg = await _apiService.sendMessage(
        conversationId: conversationId,
        body: localMsg.body,
        clientMessageId: localMsg.clientMessageId ?? _generateClientUuid(),
        imagePath: localMsg.localMediaPath,
      );
      _upsertMessage(conversationId, serverMsg);
      _updateConversationPreviewFromMessage(conversationId, serverMsg);
    } catch (e) {
      final failed = localMsg.copyWith(
        deliveryStatus: ChatDeliveryStatus.failed,
        errorMessage: e.toString(),
      );
      _upsertMessage(conversationId, failed);
    }
    notifyListeners();
  }

  Future<void> notifyTyping(int conversationId, bool isTyping) async {
    final now = DateTime.now();
    final last = _lastTypingSentAt[conversationId];
    if (isTyping && last != null && now.difference(last).inMilliseconds < 2200) {
      return;
    }
    _lastTypingSentAt[conversationId] = now;
    try {
      await _apiService.sendTyping(conversationId, isTyping: isTyping);
    } catch (_) {}
  }

  Future<void> loadWhatsappStatus() async {
    try {
      _whatsappStatus = await _apiService.getWhatsappStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> toggleWhatsappOptIn({required bool optIn, int? conversationId}) async {
    _lastWhatsappError = null;
    try {
      _whatsappStatus = await _apiService.updateWhatsappOptIn(
        optIn: optIn,
        conversationId: conversationId,
      );
      notifyListeners();
      return true;
    } on ChatApiException catch (e) {
      _lastWhatsappError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _lastWhatsappError = 'Gagal memperbarui preferensi WhatsApp.';
      notifyListeners();
      return false;
    }
  }

  void _handleRealtimeMessage(
    ({int conversationId, ChatMessageModel message, int? customerUnread, int? courierUnread}) event,
  ) {
    _upsertMessage(event.conversationId, event.message);
    _updateConversationPreviewFromMessage(event.conversationId, event.message);

    final conv = _findConversation(event.conversationId);
    final isFromMe = conv != null
        ? event.message.isFromViewer(conv.viewerRole, viewerUserId: _currentUserId)
        : (event.message.senderUserId != null && event.message.senderUserId == _currentUserId);

    if (_activeConversationId == event.conversationId) {
      if (!isFromMe && event.message.id != null) {
        unawaited(_markConversationRead(event.conversationId, upToId: event.message.id));
      }
    } else if (!isFromMe) {
      final senderLabel = event.message.senderName ?? conv?.displayTitle ?? 'Pesan Baru';
      final preview = (event.message.body?.trim().isNotEmpty == true)
          ? event.message.body!.trim()
          : '[Foto]';
      unawaited(
        ChatNotificationService.instance.maybeNotifyFromRealtime(
          conversationId: event.conversationId,
          messageId: event.message.id,
          clientMessageId: event.message.clientMessageId,
          senderUserId: event.message.senderUserId,
          title: conv?.orderNumber != null ? '$senderLabel • #${conv!.orderNumber}' : senderLabel,
          body: preview,
          orderNumber: conv?.orderNumber,
        ),
      );
    }

    notifyListeners();
  }

  void _handleConversationUpdated(Map<String, dynamic> data) {
    final convId = (data['conversation_id'] as num?)?.toInt();
    if (convId == null) return;

    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx < 0) {
      unawaited(loadConversations(silent: true));
      return;
    }

    final existing = _conversations[idx];
    final unread = existing.viewerRole == 'customer'
        ? (data['customer_unread_count'] as num?)?.toInt()
        : (data['courier_unread_count'] as num?)?.toInt();

    final effectiveUnread = _activeConversationId == convId ? 0 : (unread ?? existing.unreadCount);
    final updated = existing.copyWith(
      unreadCount: effectiveUnread,
      lastMessageId: (data['last_message_id'] as num?)?.toInt(),
      lastMessagePreview: data['last_message_preview']?.toString(),
      lastMessageAt: DateTime.tryParse(data['last_message_at']?.toString() ?? '')?.toLocal(),
    );

    _conversations[idx] = updated;
    _sortConversations();
    _recomputeTotalUnread();
    notifyListeners();
  }

  void _handleMessageStatus(
    ({int conversationId, List<int> messageIds, ChatDeliveryStatus status}) event,
  ) {
    final list = _messagesByConversation[event.conversationId];
    if (list == null) return;

    final idSet = event.messageIds.toSet();
    bool changed = false;

    for (int i = 0; i < list.length; i++) {
      final msg = list[i];
      if (msg.id != null && idSet.contains(msg.id)) {
        if (event.status.progressRank > msg.deliveryStatus.progressRank) {
          list[i] = msg.copyWith(
            deliveryStatus: event.status,
            deliveredAt: event.status == ChatDeliveryStatus.delivered ? (msg.deliveredAt ?? DateTime.now()) : msg.deliveredAt,
            readAt: event.status == ChatDeliveryStatus.read ? (msg.readAt ?? DateTime.now()) : msg.readAt,
          );
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _handleUserTyping(
    ({int conversationId, int userId, String role, bool isTyping}) event,
  ) {
    if (_currentUserId != null && event.userId == _currentUserId) return;

    _typingExpiryTimers[event.conversationId]?.cancel();
    _counterpartyTyping[event.conversationId] = event.isTyping;

    if (event.isTyping) {
      _typingExpiryTimers[event.conversationId] = Timer(const Duration(seconds: 4), () {
        _counterpartyTyping[event.conversationId] = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> _markConversationRead(int conversationId, {int? upToId}) async {
    try {
      await _apiService.markRead(conversationId, lastReadMessageId: upToId);
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx >= 0 && _conversations[idx].unreadCount > 0) {
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
        _recomputeTotalUnread();
        notifyListeners();
      }
    } catch (_) {}
  }

  void _upsertMessage(int conversationId, ChatMessageModel incoming) {
    final list = List<ChatMessageModel>.from(_messagesByConversation[conversationId] ?? const []);
    final idx = list.indexWhere((m) {
      if (incoming.id != null && m.id != null && incoming.id == m.id) return true;
      if (incoming.clientMessageId != null &&
          incoming.clientMessageId!.isNotEmpty &&
          m.clientMessageId == incoming.clientMessageId) {
        return true;
      }
      return false;
    });

    if (idx >= 0) {
      final existing = list[idx];
      final keepStatus = existing.deliveryStatus.progressRank > incoming.deliveryStatus.progressRank &&
              incoming.deliveryStatus != ChatDeliveryStatus.sending &&
              incoming.deliveryStatus != ChatDeliveryStatus.failed
          ? existing.deliveryStatus
          : incoming.deliveryStatus;
      list[idx] = incoming.copyWith(deliveryStatus: keepStatus);
    } else {
      list.add(incoming);
    }

    list.sort((a, b) {
      if (a.id != null && b.id != null) return a.id!.compareTo(b.id!);
      return a.sortTimestamp.compareTo(b.sortTimestamp);
    });

    _messagesByConversation[conversationId] = list;
  }

  List<ChatMessageModel> _mergeMessageLists(
    List<ChatMessageModel> first,
    List<ChatMessageModel> second,
  ) {
    final map = <String, ChatMessageModel>{};
    for (final m in [...first, ...second]) {
      final key = m.clientMessageId?.isNotEmpty == true ? 'c_${m.clientMessageId}' : 's_${m.id}';
      final prev = map[key];
      if (prev == null) {
        map[key] = m;
      } else {
        map[key] = m.id != null ? m : prev;
      }
    }
    final merged = map.values.toList();
    merged.sort((a, b) {
      if (a.id != null && b.id != null) return a.id!.compareTo(b.id!);
      return a.sortTimestamp.compareTo(b.sortTimestamp);
    });
    return merged;
  }

  void _upsertConversation(ConversationModel conv) {
    final idx = _conversations.indexWhere((c) => c.id == conv.id);
    if (idx >= 0) {
      _conversations[idx] = conv;
    } else {
      _conversations.insert(0, conv);
    }
    _sortConversations();
    _recomputeTotalUnread();
  }

  void _updateConversationPreviewFromMessage(int conversationId, ChatMessageModel msg) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) return;

    final existing = _conversations[idx];
    final preview = (msg.body?.trim().isNotEmpty == true)
        ? msg.body!.trim()
        : (msg.messageType == 'image' ? '[Foto]' : '[Pesan]');

    _conversations[idx] = existing.copyWith(
      lastMessageId: msg.id ?? existing.lastMessageId,
      lastMessagePreview: preview,
      lastMessageAt: msg.sortTimestamp,
    );
    _sortConversations();
  }

  ConversationModel? _findConversation(int conversationId) {
    for (final c in _conversations) {
      if (c.id == conversationId) return c;
    }
    return null;
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      final at = a.lastMessageAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastMessageAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
  }

  void _recomputeTotalUnread() {
    _totalUnreadCount = _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  String _generateClientUuid() {
    final hex = List<String>.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Future<void> clearOnLogout() async {
    _currentUserId = null;
    _activeConversationId = null;
    _realtimeInitialized = false;
    _conversations = [];
    _messagesByConversation.clear();
    _hasMoreByConversation.clear();
    _nextBeforeIdByConversation.clear();
    _counterpartyTyping.clear();
    _totalUnreadCount = 0;
    _fallbackPollingTimer?.cancel();
    for (final t in _typingExpiryTimers.values) {
      t.cancel();
    }
    _typingExpiryTimers.clear();
    await _realtimeService.disconnect();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _fallbackPollingTimer?.cancel();
    for (final t in _typingExpiryTimers.values) {
      t.cancel();
    }
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _realtimeService.isConnectedNotifier.removeListener(_syncFallbackPolling);
    unawaited(_realtimeService.dispose());
    super.dispose();
  }
}
