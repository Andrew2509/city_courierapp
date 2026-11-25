import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/providers/chat_provider.dart';
import 'package:city_courierapp/services/chat/chat_api_service.dart';
import 'package:city_courierapp/services/chat/chat_realtime_service.dart';

class _FakeWebSocketSink implements WebSocketSink {
  final StreamSink<dynamic> _inner;
  final Future<void> Function([int? closeCode, String? closeReason]) _onClose;

  _FakeWebSocketSink(this._inner, this._onClose);

  @override
  void add(dynamic data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) => _inner.addStream(stream);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) => _onClose(closeCode, closeReason);

  @override
  Future<dynamic> get done => _inner.done;
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> serverToClient = StreamController<dynamic>.broadcast();
  final StreamController<dynamic> clientToServer = StreamController<dynamic>.broadcast();
  final Completer<void> _ready = Completer<void>()..complete();

  @override
  Future<void> get ready => _ready.future;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Stream<dynamic> get stream => serverToClient.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(clientToServer.sink, ([_, _]) async {
        await clientToServer.close();
        await serverToClient.close();
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Chat Models & Status Rank', () {
    test('parses conversation, message, and enforces monotonic status rank', () {
      final conv = ConversationModel.fromJson({
        'id': 12,
        'order_id': 901,
        'order_number': 'ORD-901',
        'customer_user_id': 5,
        'courier_user_id': 8,
        'status': 'active',
        'wa_bridged_enabled': true,
        'viewer_role': 'customer',
        'unread_count': 2,
        'counterparty': {
          'user_id': 8,
          'role': 'courier',
          'name': 'Budi Kurir',
          'phone': '081234567890',
        },
      });

      expect(conv.id, 12);
      expect(conv.displayTitle, 'Budi Kurir');
      expect(conv.unreadCount, 2);

      final msg = ChatMessageModel.fromJson({
        'id': 50,
        'conversation_id': 12,
        'sender_user_id': 5,
        'sender_role': 'customer',
        'client_message_id': 'c-1',
        'channel': 'whatsapp',
        'message_type': 'text',
        'body': 'Halo pak',
        'delivery_status': 'read',
      });

      expect(msg.isWhatsAppChannel, true);
      expect(msg.deliveryStatus, ChatDeliveryStatus.read);
      expect(
        ChatDeliveryStatus.read.progressRank > ChatDeliveryStatus.delivered.progressRank,
        true,
      );
    });
  });

  group('ChatRealtimeService (Reverb Protocol v7)', () {
    test('authorizes private channel, answers ping, and emits parsed chat events', () async {
      final fakeChannel = _FakeWebSocketChannel();
      final sentFrames = <Map<String, dynamic>>[];
      fakeChannel.clientToServer.stream.listen((raw) {
        sentFrames.add(jsonDecode(raw.toString()) as Map<String, dynamic>);
      });

      final mockHttp = MockClient((req) async {
        if (req.url.path == '/api/v1/chat/broadcasting/auth') {
          final payload = jsonDecode(req.body) as Map<String, dynamic>;
          expect(payload['socket_id'], '111.222');
          expect(payload['channel_name'], 'private-conversation.42');
          return http.Response(jsonEncode({'auth': 'key:hmac-signature'}), 200);
        }
        return http.Response('{}', 404);
      });

      final api = ChatApiService(
        client: mockHttp,
        tokenReader: () async => 'sanctum-token',
        baseUrl: 'https://www.neonflux.my.id/api',
      );

      final realtime = ChatRealtimeService(
        apiService: api,
        connector: (_) => fakeChannel,
      );

      const cfg = ChatRealtimeConfig(
        driver: 'reverb',
        key: 'reverb-key',
        host: 'ws.neonflux.my.id',
        port: 443,
        scheme: 'https',
        cluster: 'mt1',
        authEndpoint: '/api/v1/chat/broadcasting/auth',
      );

      await realtime.connect(cfg);
      await realtime.subscribePrivateConversation(42);

      // Simulate Reverb handshake frame
      fakeChannel.serverToClient.add(jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '111.222'}),
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(realtime.isConnected, true);
      expect(
        sentFrames.any((f) =>
            f['event'] == 'pusher:subscribe' &&
            f['data']['channel'] == 'private-conversation.42' &&
            f['data']['auth'] == 'key:hmac-signature'),
        true,
      );

      // Simulate ping -> pong
      fakeChannel.serverToClient.add(jsonEncode({'event': 'pusher:ping', 'data': {}}));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sentFrames.any((f) => f['event'] == 'pusher:pong'), true);

      // Simulate incoming message.sent
      final msgFuture = realtime.onMessageSent.first;
      fakeChannel.serverToClient.add(jsonEncode({
        'event': 'message.sent',
        'channel': 'private-conversation.42',
        'data': {
          'conversation_id': 42,
          'message': {
            'id': 101,
            'conversation_id': 42,
            'sender_user_id': 8,
            'sender_role': 'courier',
            'client_message_id': 'srv-101',
            'channel': 'internal',
            'message_type': 'text',
            'body': 'Kurir sudah dekat',
            'delivery_status': 'sent',
          },
        },
      }));

      final emitted = await msgFuture;
      expect(emitted.conversationId, 42);
      expect(emitted.message.body, 'Kurir sudah dekat');

      await realtime.dispose();
    });
  });

  group('ChatProvider Optimistic Send, Retry & Deduplication', () {
    test('reconciles optimistic message with server reply, retries failed send, and updates read status',
        () async {
      bool shouldFailNextSend = true;
      int serverIdSeq = 500;
      final fakeChannel = _FakeWebSocketChannel();

      final mockHttp = MockClient((req) async {
        if (req.url.path == '/api/v1/chat/realtime-config') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'driver': 'reverb',
                'key': 'k',
                'host': 'ws.neonflux.my.id',
                'port': 443,
                'scheme': 'https',
                'auth_endpoint': '/api/v1/chat/broadcasting/auth',
              },
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/chat/unread-count') {
          return http.Response(jsonEncode({'success': true, 'data': {'total_unread': 0}}), 200);
        }
        if (req.url.path == '/api/v1/chat/conversations/by-order/99') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 7,
                'order_id': 99,
                'order_number': 'ORD-99',
                'customer_user_id': 1,
                'courier_user_id': 2,
                'status': 'active',
                'wa_bridged_enabled': true,
                'viewer_role': 'customer',
                'unread_count': 0,
                'counterparty': {'user_id': 2, 'role': 'courier', 'name': 'Kurir 2'},
              },
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/chat/conversations/7/messages' && req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'messages': [], 'has_more': false, 'next_before_id': null},
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/chat/conversations/7/messages' && req.method == 'POST') {
          if (shouldFailNextSend) {
            return http.Response(jsonEncode({'success': false, 'message': 'Jaringan terputus'}), 503);
          }
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': serverIdSeq++,
                'conversation_id': 7,
                'sender_user_id': 1,
                'sender_role': 'customer',
                'client_message_id': body['client_message_id'],
                'channel': 'internal',
                'message_type': 'text',
                'body': body['body'],
                'delivery_status': 'sent',
              },
            }),
            201,
          );
        }
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final api = ChatApiService(
        client: mockHttp,
        tokenReader: () async => 'token',
        baseUrl: 'https://www.neonflux.my.id/api',
      );
      final realtime = ChatRealtimeService(apiService: api, connector: (_) => fakeChannel);
      final provider = ChatProvider(apiService: api, realtimeService: realtime);

      await provider.bindAuthenticatedUser(1);
      final conv = await provider.openOrderConversation('99');
      await provider.enterConversation(conv.id, knownUserId: 1);

      // Simulate handshake established before testing live events
      fakeChannel.serverToClient.add(jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '222.333'}),
      }));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 1) First send fails -> marked failed in UI without crashing
      await provider.sendMessage(conversation: conv, body: 'Pesan pertama');
      var msgs = provider.messagesFor(conv.id);
      expect(msgs.length, 1);
      expect(msgs.first.deliveryStatus, ChatDeliveryStatus.failed);

      // 2) Retry succeeds -> reconciles in-place (still 1 bubble, now sent with id 500)
      shouldFailNextSend = false;
      await provider.retryFailedMessage(conv.id, msgs.first.clientMessageId!);
      msgs = provider.messagesFor(conv.id);
      expect(msgs.length, 1);
      expect(msgs.first.id, 500);
      expect(msgs.first.deliveryStatus, ChatDeliveryStatus.sent);

      // 3) Realtime read event updates bubble 500 -> read
      fakeChannel.serverToClient.add(jsonEncode({
        'event': 'message.status',
        'channel': 'private-conversation.7',
        'data': {
          'conversation_id': 7,
          'message_ids': [500],
          'delivery_status': 'read',
        },
      }));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(provider.messagesFor(conv.id).first.deliveryStatus, ChatDeliveryStatus.read);

      // 4) Logout clears state cleanly
      await provider.clearOnLogout();
      expect(provider.conversations, isEmpty);
      expect(provider.messagesFor(conv.id), isEmpty);

      provider.dispose();
    });
  });
}
