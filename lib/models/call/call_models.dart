import 'package:flutter/foundation.dart';

enum CallStatus {
  ringing,
  accepted,
  rejected,
  missed,
  ended,
  failed;

  bool get isActive => this == CallStatus.ringing || this == CallStatus.accepted;
  bool get isTerminal => !isActive;

  static CallStatus fromString(String? raw) {
    return switch ((raw ?? '').toLowerCase()) {
      'ringing' => CallStatus.ringing,
      'accepted' => CallStatus.accepted,
      'rejected' => CallStatus.rejected,
      'missed' => CallStatus.missed,
      'failed' => CallStatus.failed,
      _ => CallStatus.ended,
    };
  }
}

@immutable
class CallParticipant {
  final int userId;
  final String role;
  final String name;
  final String? avatar;

  const CallParticipant({
    required this.userId,
    required this.role,
    required this.name,
    this.avatar,
  });

  bool get isCourier => role.toLowerCase() == 'courier';

  String get roleDisplay => isCourier ? 'Kurir City Courier' : 'Customer';

  factory CallParticipant.fromJson(Map<String, dynamic>? json, {int fallbackId = 0}) {
    if (json == null) {
      return CallParticipant(
        userId: fallbackId,
        role: 'courier',
        name: 'Pengguna City Courier',
      );
    }
    return CallParticipant(
      userId: _toInt(json['user_id']) ?? fallbackId,
      role: (json['role'] ?? 'customer').toString(),
      name: (json['name'] ?? 'Pengguna City Courier').toString(),
      avatar: _cleanNullableStr(json['avatar']),
    );
  }
}

@immutable
class IceServerConfig {
  final dynamic urls;
  final String? username;
  final String? credential;

  const IceServerConfig({
    required this.urls,
    this.username,
    this.credential,
  });

  Map<String, dynamic> toWebRtcMap() {
    return {
      'urls': urls,
      if (username != null && username!.isNotEmpty) 'username': username,
      if (credential != null && credential!.isNotEmpty) 'credential': credential,
    };
  }

  factory IceServerConfig.fromJson(Map<String, dynamic> json) {
    return IceServerConfig(
      urls: json['urls'],
      username: _cleanNullableStr(json['username']),
      credential: _cleanNullableStr(json['credential']),
    );
  }
}

@immutable
class CallSessionModel {
  final int id;
  final String callUuid;
  final int? orderId;
  final String? orderNumber;
  final int conversationId;
  final int callerId;
  final int receiverId;
  final CallStatus status;
  final String? endReason;
  final String viewerRole;
  final CallParticipant caller;
  final CallParticipant receiver;
  final DateTime? startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int? duration;
  final DateTime? expiresAt;

  const CallSessionModel({
    required this.id,
    required this.callUuid,
    this.orderId,
    this.orderNumber,
    required this.conversationId,
    required this.callerId,
    required this.receiverId,
    required this.status,
    this.endReason,
    required this.viewerRole,
    required this.caller,
    required this.receiver,
    this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.duration,
    this.expiresAt,
  });

  bool get isIncoming => viewerRole == 'receiver';

  CallParticipant counterpartyForUser(int? currentUserId) {
    if (currentUserId != null && currentUserId > 0) {
      return currentUserId == callerId ? receiver : caller;
    }
    return isIncoming ? caller : receiver;
  }

  CallSessionModel copyWith({
    CallStatus? status,
    String? endReason,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? duration,
  }) {
    return CallSessionModel(
      id: id,
      callUuid: callUuid,
      orderId: orderId,
      orderNumber: orderNumber,
      conversationId: conversationId,
      callerId: callerId,
      receiverId: receiverId,
      status: status ?? this.status,
      endReason: endReason ?? this.endReason,
      viewerRole: viewerRole,
      caller: caller,
      receiver: receiver,
      startedAt: startedAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      expiresAt: expiresAt,
    );
  }

  factory CallSessionModel.fromJson(Map<String, dynamic> json) {
    final callerId = _toInt(json['caller_id']) ?? 0;
    final receiverId = _toInt(json['receiver_id']) ?? 0;
    return CallSessionModel(
      id: _toInt(json['id']) ?? 0,
      callUuid: (json['call_uuid'] ?? '').toString(),
      orderId: _toInt(json['order_id']),
      orderNumber: _cleanNullableStr(json['order_number']),
      conversationId: _toInt(json['conversation_id']) ?? 0,
      callerId: callerId,
      receiverId: receiverId,
      status: CallStatus.fromString(json['status']?.toString()),
      endReason: _cleanNullableStr(json['end_reason']),
      viewerRole: (json['viewer_role'] ?? 'caller').toString(),
      caller: CallParticipant.fromJson(
        json['caller'] is Map ? Map<String, dynamic>.from(json['caller'] as Map) : null,
        fallbackId: callerId,
      ),
      receiver: CallParticipant.fromJson(
        json['receiver'] is Map ? Map<String, dynamic>.from(json['receiver'] as Map) : null,
        fallbackId: receiverId,
      ),
      startedAt: _toDate(json['started_at']),
      answeredAt: _toDate(json['answered_at']),
      endedAt: _toDate(json['ended_at']),
      duration: _toInt(json['duration']),
      expiresAt: _toDate(json['expires_at']),
    );
  }
}

@immutable
class CallSignalModel {
  final int id;
  final int callSessionId;
  final int senderId;
  final int receiverId;
  final String signalType;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  const CallSignalModel({
    required this.id,
    required this.callSessionId,
    required this.senderId,
    required this.receiverId,
    required this.signalType,
    required this.payload,
    this.createdAt,
  });

  factory CallSignalModel.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return CallSignalModel(
      id: _toInt(json['id']) ?? 0,
      callSessionId: _toInt(json['call_session_id']) ?? 0,
      senderId: _toInt(json['sender_id']) ?? 0,
      receiverId: _toInt(json['receiver_id']) ?? 0,
      signalType: (json['signal_type'] ?? '').toString(),
      payload: rawPayload is Map ? Map<String, dynamic>.from(rawPayload) : const {},
      createdAt: _toDate(json['created_at']),
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
  return DateTime.tryParse(value.toString())?.toLocal();
}

String? _cleanNullableStr(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return (s.isEmpty || s == 'null') ? null : s;
}
