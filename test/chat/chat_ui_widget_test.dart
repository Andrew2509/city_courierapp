import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/providers/chat_provider.dart';
import 'package:city_courierapp/screens/chat/chat_detail_screen.dart';
import 'package:city_courierapp/screens/chat/chat_launch_helper.dart';
import 'package:city_courierapp/screens/chat/chat_list_screen.dart';
import 'package:city_courierapp/screens/home/tracking/widgets/courier_info_card.dart';
import 'package:city_courierapp/services/chat/chat_api_service.dart';
import 'package:city_courierapp/services/chat/chat_realtime_service.dart';

class _TestSink implements WebSocketSink {
  final StreamSink<dynamic> _inner;
  final Future<void> Function() _onClose;

  _TestSink(this._inner, this._onClose);

  @override
  void add(dynamic data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) => _inner.addStream(stream);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) => _onClose();

  @override
  Future<dynamic> get done => _inner.done;
}

class _TestWsChannel implements WebSocketChannel {
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
  WebSocketSink get sink => _TestSink(clientToServer.sink, () async {
        unawaited(clientToServer.close());
        unawaited(serverToClient.close());
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ChatListScreen displays conversations, unread badge, and toggles WA opt-in',
      (tester) async {
    bool optedInState = false;
    final ws = _TestWsChannel();

    final mockHttp = MockClient((req) async {
      if (req.url.path == '/api/v1/chat/realtime-config') {
        return http.Response(jsonEncode({'success': true, 'data': {'driver': 'null'}}), 200);
      }
      if (req.url.path == '/api/v1/chat/unread-count') {
        return http.Response(jsonEncode({'success': true, 'data': {'total_unread': 3}}), 200);
      }
      if (req.url.path == '/api/v1/chat/conversations') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'total_unread': 3,
              'conversations': [
                {
                  'id': 15,
                  'order_id': 77,
                  'order_number': 'ORD-77',
                  'customer_user_id': 1,
                  'courier_user_id': 9,
                  'status': 'active',
                  'wa_bridged_enabled': true,
                  'viewer_role': 'customer',
                  'unread_count': 3,
                  'last_message_preview': 'Paket sudah di depan pagar ya.',
                  'last_message_at': '2026-11-25T07:30:00Z',
                  'counterparty': {'user_id': 9, 'role': 'courier', 'name': 'Joko Kurir'},
                },
              ],
              'pagination': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 1},
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/chat/whatsapp/status') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'whatsapp_cloud_enabled': true,
              'phone_e164': '6281234567890',
              'phone_verified': true,
              'opt_in_status': optedInState ? 'opted_in' : 'pending',
              'window_open': false,
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/chat/whatsapp/opt-in') {
        final reqJson = jsonDecode(req.body) as Map<String, dynamic>;
        optedInState = reqJson['opt_in'] == true;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'whatsapp_cloud_enabled': true,
              'phone_e164': '6281234567890',
              'phone_verified': true,
              'opt_in_status': optedInState ? 'opted_in' : 'opted_out',
              'window_open': false,
            },
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final api = ChatApiService(
      client: mockHttp,
      tokenReader: () async => 't',
      baseUrl: 'https://www.neonflux.my.id/api',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider(
          apiService: api,
          realtimeService: ChatRealtimeService(apiService: api, connector: (_) => ws),
        ),
        child: const MaterialApp(
          home: ChatListScreen(knownUserId: 1),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pesan Pengiriman'), findsOneWidget);
    expect(find.text('Joko Kurir'), findsOneWidget);
    expect(find.text('Kurir • #ORD-77'), findsOneWidget);
    expect(find.text('Paket sudah di depan pagar ya.'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Notifikasi WhatsApp Bisnis Resmi'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(optedInState, true);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ChatDetailScreen renders messages, via WhatsApp tag, typing indicator, and sends reply',
      (tester) async {
    final ws = _TestWsChannel();
    int sentCount = 0;

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
      if (req.url.path == '/api/v1/chat/whatsapp/status') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'whatsapp_cloud_enabled': true,
              'phone_e164': '6281234567890',
              'phone_verified': true,
              'opt_in_status': 'pending',
              'window_open': false,
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/chat/conversations/15/messages' && req.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'messages': [
                {
                  'id': 1,
                  'conversation_id': 15,
                  'sender_user_id': 9,
                  'sender_role': 'courier',
                  'client_message_id': 'wa-1',
                  'channel': 'whatsapp',
                  'message_type': 'text',
                  'body': 'Halo bu paket siap diantar.',
                  'delivery_status': 'sent',
                  'sent_at': '2026-11-25T07:20:00Z',
                },
              ],
              'has_more': false,
              'next_before_id': null,
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/chat/conversations/15/messages' && req.method == 'POST') {
        sentCount++;
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 200 + sentCount,
              'conversation_id': 15,
              'sender_user_id': 1,
              'sender_role': 'customer',
              'client_message_id': body['client_message_id'],
              'channel': 'internal',
              'message_type': 'text',
              'body': body['body'],
              'delivery_status': 'sent',
              'sent_at': '2026-11-25T07:21:00Z',
            },
          }),
          201,
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final api = ChatApiService(
      client: mockHttp,
      tokenReader: () async => 't',
      baseUrl: 'https://www.neonflux.my.id/api',
    );
    final conv = ConversationModel.fromJson({
      'id': 15,
      'order_id': 77,
      'order_number': 'ORD-77',
      'customer_user_id': 1,
      'courier_user_id': 9,
      'status': 'active',
      'wa_bridged_enabled': true,
      'viewer_role': 'customer',
      'unread_count': 0,
      'counterparty': {'user_id': 9, 'role': 'courier', 'name': 'Joko Kurir'},
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider(
          apiService: api,
          realtimeService: ChatRealtimeService(apiService: api, connector: (_) => ws),
        ),
        child: MaterialApp(
          home: ChatDetailScreen(
            conversation: conv,
            knownUserId: 1,
            authTokenOverride: 't',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Halo bu paket siap diantar.'), findsOneWidget);
    expect(find.text('via WhatsApp'), findsOneWidget);
    expect(find.text('Aktifkan'), findsOneWidget);

    ws.serverToClient.add(jsonEncode({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '333.444'}),
    }));
    await tester.pump(const Duration(milliseconds: 20));

    // Trigger remote typing event over WS
    ws.serverToClient.add(jsonEncode({
      'event': 'user.typing',
      'channel': 'private-conversation.15',
      'data': {
        'conversation_id': 15,
        'user_id': 9,
        'role': 'courier',
        'is_typing': true,
      },
    }));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(find.text('Sedang mengetik...'), findsOneWidget);

    // Send reply
    await tester.enterText(find.byType(TextField), 'Baik mas silakan masuk.');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentCount, 1);
    expect(find.text('Baik mas silakan masuk.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('CourierInfoCard renders ChatOrderIconButton when orderIdentifier is present',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CourierInfoCard(
            courier: TrackingCourier(name: 'Pak Joko', phone: '08123456789'),
            orderIdentifier: 'CC-ORDER-77',
          ),
        ),
      ),
    );

    expect(find.byType(ChatOrderIconButton), findsOneWidget);
    expect(find.text('Hubungi'), findsOneWidget);
  });
}
