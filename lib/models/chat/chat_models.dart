import 'package:flutter/foundation.dart';

enum ChatDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  int get progressRank => switch (this) {
    ChatDeliveryStatus.sending => 0,
    ChatDeliveryStatus.failed => 1,
    ChatDeliveryStatus.sent => 2,
    ChatDeliveryStatus.delivered => 3,
    ChatDeliveryStatus.read => 4,
  };

  static ChatDeliveryStatus fromString(String? raw) {
    return switch ((raw ?? '').toLowerCase()) {
      'sending' => ChatDeliveryStatus.sending,
      'delivered' => ChatDeliveryStatus.delivered,
      'read' => ChatDeliveryStatus.read,
      'failed' => ChatDeliveryStatus.failed,
      _ => ChatDeliveryStatus.sent,
    };
  }
}

@immutable
class ChatCounterparty {
  final int? userId;
  final String role;
  final String? name;
  final String? phone;

  const ChatCounterparty({
    this.userId,
    required this.role,
    this.name,
    this.phone,
  });

  factory ChatCounterparty.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatCounterparty(role: 'courier');
    }
    return ChatCounterparty(
      userId: _toInt(json['user_id']),
      role: (json['role'] ?? 'courier').toString(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

@immutable
class ConversationModel {
  final int id;
  final int orderId;
  final int? shipmentId;
  final String? orderNumber;
  final int customerUserId;
  final int? courierUserId;
  final int? courierId;
  final String status;
  final bool waBridgedEnabled;
  final String viewerRole;
  final int unreadCount;
  final int? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final ChatCounterparty counterparty;
  final DateTime? createdAt;

  const ConversationModel({
    required this.id,
    required this.orderId,
    this.shipmentId,
    this.orderNumber,
    required this.customerUserId,
    this.courierUserId,
    this.courierId,
    required this.status,
    required this.waBridgedEnabled,
    required this.viewerRole,
    required this.unreadCount,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastMessageAt,
    required this.counterparty,
    this.createdAt,
  });

  bool get isActive => status == 'active';

  String get displayTitle {
    final name = counterparty.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return viewerRole == 'customer' ? 'Kurir City Courier' : 'Customer';
  }

  ConversationModel copyWith({
    int? courierUserId,
    String? status,
    bool? waBridgedEnabled,
    int? unreadCount,
    int? lastMessageId,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
  }) {
    return ConversationModel(
      id: id,
      orderId: orderId,
      shipmentId: shipmentId,
      orderNumber: orderNumber,
      customerUserId: customerUserId,
      courierUserId: courierUserId ?? this.courierUserId,
      courierId: courierId,
      status: status ?? this.status,
      waBridgedEnabled: waBridgedEnabled ?? this.waBridgedEnabled,
      viewerRole: viewerRole,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      counterparty: counterparty,
      createdAt: createdAt,
    );
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: _toInt(json['id']) ?? 0,
      orderId: _toInt(json['order_id']) ?? 0,
      shipmentId: _toInt(json['shipment_id']),
      orderNumber: json['order_number']?.toString(),
      customerUserId: _toInt(json['customer_user_id']) ?? 0,
      courierUserId: _toInt(json['courier_user_id']),
      courierId: _toInt(json['courier_id']),
      status: (json['status'] ?? 'active').toString(),
      waBridgedEnabled: json['wa_bridged_enabled'] == true || json['wa_bridged_enabled'] == 1,
      viewerRole: (json['viewer_role'] ?? 'customer').toString(),
      unreadCount: _toInt(json['unread_count']) ?? 0,
      lastMessageId: _toInt(json['last_message_id']),
      lastMessagePreview: json['last_message_preview']?.toString(),
      lastMessageAt: _toDate(json['last_message_at']),
      counterparty: ChatCounterparty.fromJson(
        json['counterparty'] is Map
            ? Map<String, dynamic>.from(json['counterparty'] as Map)
            : null,
      ),
      createdAt: _toDate(json['created_at']),
    );
  }
}

@immutable
class ChatMessageModel {
  final int? id;
  final int conversationId;
  final int? senderUserId;
  final String? senderName;
  final String senderRole;
  final String? clientMessageId;
  final String channel;
  final String messageType;
  final String? body;
  final String? mediaUrl;
  final String? localMediaPath;
  final String? mediaMime;
  final int? mediaSize;
  final ChatDeliveryStatus deliveryStatus;
  final String? waMessageId;
  final String? waStatus;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? createdAt;
  final String? errorMessage;

  const ChatMessageModel({
    this.id,
    required this.conversationId,
    this.senderUserId,
    this.senderName,
    required this.senderRole,
    this.clientMessageId,
    this.channel = 'internal',
    this.messageType = 'text',
    this.body,
    this.mediaUrl,
    this.localMediaPath,
    this.mediaMime,
    this.mediaSize,
    this.deliveryStatus = ChatDeliveryStatus.sent,
    this.waMessageId,
    this.waStatus,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.createdAt,
    this.errorMessage,
  });

  String get stableKey {
    if (clientMessageId != null && clientMessageId!.isNotEmpty) {
      return 'c_$clientMessageId';
    }
    return 's_${id ?? hashCode}';
  }

  DateTime get sortTimestamp => sentAt ?? createdAt ?? DateTime.now();

  bool isFromViewer(String viewerRole, {int? viewerUserId}) {
    if (senderUserId != null && viewerUserId != null) {
      return senderUserId == viewerUserId;
    }
    return senderRole == viewerRole;
  }

  bool get isWhatsAppChannel => channel == 'whatsapp';

  ChatMessageModel copyWith({
    int? id,
    ChatDeliveryStatus? deliveryStatus,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? waMessageId,
    String? waStatus,
    String? errorMessage,
    String? mediaUrl,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderName: senderName,
      senderRole: senderRole,
      clientMessageId: clientMessageId,
      channel: channel,
      messageType: messageType,
      body: body,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      localMediaPath: localMediaPath,
      mediaMime: mediaMime,
      mediaSize: mediaSize,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      waMessageId: waMessageId ?? this.waMessageId,
      waStatus: waStatus ?? this.waStatus,
      sentAt: sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: _toInt(json['id']),
      conversationId: _toInt(json['conversation_id']) ?? 0,
      senderUserId: _toInt(json['sender_user_id']),
      senderName: json['sender_name']?.toString(),
      senderRole: (json['sender_role'] ?? 'customer').toString(),
      clientMessageId: json['client_message_id']?.toString(),
      channel: (json['channel'] ?? 'internal').toString(),
      messageType: (json['message_type'] ?? 'text').toString(),
      body: json['body']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      mediaMime: json['media_mime']?.toString(),
      mediaSize: _toInt(json['media_size']),
      deliveryStatus: ChatDeliveryStatus.fromString(json['delivery_status']?.toString()),
      waMessageId: json['wa_message_id']?.toString(),
      waStatus: json['wa_status']?.toString(),
      sentAt: _toDate(json['sent_at']),
      deliveredAt: _toDate(json['delivered_at']),
      readAt: _toDate(json['read_at']),
      createdAt: _toDate(json['created_at']),
    );
  }
}

@immutable
class WhatsappBridgeStatus {
  final bool whatsappCloudEnabled;
  final String? phoneE164;
  final bool phoneVerified;
  final String optInStatus;
  final bool windowOpen;
  final DateTime? windowExpiresAt;

  const WhatsappBridgeStatus({
    required this.whatsappCloudEnabled,
    this.phoneE164,
    required this.phoneVerified,
    required this.optInStatus,
    required this.windowOpen,
    this.windowExpiresAt,
  });

  bool get isOptedIn => optInStatus == 'opted_in';

  factory WhatsappBridgeStatus.fromJson(Map<String, dynamic> json) {
    return WhatsappBridgeStatus(
      whatsappCloudEnabled: json['whatsapp_cloud_enabled'] == true,
      phoneE164: json['phone_e164']?.toString(),
      phoneVerified: json['phone_verified'] == true,
      optInStatus: (json['opt_in_status'] ?? 'pending').toString(),
      windowOpen: json['window_open'] == true,
      windowExpiresAt: _toDate(json['window_expires_at']),
    );
  }
}

@immutable
class ChatRealtimeConfig {
  final String driver;
  final String? key;
  final String host;
  final int port;
  final String scheme;
  final String cluster;
  final String authEndpoint;

  const ChatRealtimeConfig({
    required this.driver,
    this.key,
    required this.host,
    required this.port,
    required this.scheme,
    required this.cluster,
    required this.authEndpoint,
  });

  bool get isConnectable =>
      (driver == 'reverb' || driver == 'pusher') &&
      key != null &&
      key!.trim().isNotEmpty &&
      host.trim().isNotEmpty;

  factory ChatRealtimeConfig.fromJson(Map<String, dynamic> json) {
    return ChatRealtimeConfig(
      driver: (json['driver'] ?? 'null').toString(),
      key: json['key']?.toString(),
      host: (json['host'] ?? '').toString(),
      port: _toInt(json['port']) ?? 443,
      scheme: (json['scheme'] ?? 'https').toString(),
      cluster: (json['cluster'] ?? 'mt1').toString(),
      authEndpoint: (json['auth_endpoint'] ?? '/api/v1/chat/broadcasting/auth').toString(),
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString())?.toLocal();
}
