import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:city_courierapp/models/call/call_models.dart';
import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/providers/call_provider.dart';
import 'package:city_courierapp/providers/chat_provider.dart';
import 'package:city_courierapp/screens/call/incoming_call_screen.dart';
import 'package:city_courierapp/screens/call/voice_call_screen.dart';
import 'package:city_courierapp/screens/chat/chat_detail_screen.dart';
import 'package:city_courierapp/services/call/call_api_service.dart';
import 'package:city_courierapp/services/call/webrtc_call_engine.dart';
import 'package:city_courierapp/services/chat/chat_api_service.dart';
import 'package:city_courierapp/services/chat/chat_realtime_service.dart';

class _FakeWebRtcEngine implements WebRtcCallEngine {
  final StreamController<Map<String, dynamic>> iceCtrl = StreamController.broadcast();
  final StreamController<VoiceCallConnectionState> connCtrl = StreamController.broadcast();

  bool initialized = false;
  bool offerCreated = false;
  bool answerCreated = false;
  bool muted = false;
  bool speakerOn = false;
  bool disposed = false;
  String? lastRemoteSdp;
  String? lastRemoteType;
  final List<Map<String, dynamic>> addedIceCandidates = [];
  List<Map<String, dynamic>>? receivedIceServers;

  @override
  Stream<Map<String, dynamic>> get onIceCandidate => iceCtrl.stream;

  @override
  Stream<VoiceCallConnectionState> get onConnectionState => connCtrl.stream;

  @override
  Future<void> initialize({required List<Map<String, dynamic>> iceServers}) async {
    initialized = true;
    receivedIceServers = iceServers;
  }

  @override
  Future<Map<String, dynamic>> createOffer() async {
    offerCreated = true;
    return {'type': 'offer', 'sdp': 'v=0-fake-offer'};
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    answerCreated = true;
    return {'type': 'answer', 'sdp': 'v=0-fake-answer'};
  }

  @override
  Future<void> setRemoteDescription({required String sdp, required String type}) async {
    lastRemoteSdp = sdp;
    lastRemoteType = type;
  }

  @override
  Future<void> addIceCandidate(Map<String, dynamic> candidate) async {
    addedIceCandidates.add(candidate);
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    this.muted = muted;
  }

  @override
  Future<void> setSpeakerphoneOn(bool speakerOn) async {
    this.speakerOn = speakerOn;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!iceCtrl.isClosed) await iceCtrl.close();
    if (!connCtrl.isClosed) await connCtrl.close();
  }
}

class _SinkStub implements WebSocketSink {
  final StreamSink<dynamic> _inner;
  _SinkStub(this._inner);
  @override
  void add(dynamic data) => _inner.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);
  @override
  Future<dynamic> addStream(Stream<dynamic> stream) => _inner.addStream(stream);
  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) => _inner.close();
  @override
  Future<dynamic> get done => _inner.done;
}

class _WsStub implements WebSocketChannel {
  final StreamController<dynamic> inCtrl = StreamController<dynamic>.broadcast();
  final StreamController<dynamic> outCtrl = StreamController<dynamic>.broadcast();
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
  Stream<dynamic> get stream => inCtrl.stream;
  @override
  WebSocketSink get sink => _SinkStub(outCtrl.sink);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ConversationModel makeConversation({String viewerRole = 'customer'}) {
    return ConversationModel.fromJson({
      'id': 25,
      'order_id': 101,
      'order_number': 'CC-VOICE-101',
      'customer_user_id': 1,
      'courier_user_id': 9,
      'status': 'active',
      'wa_bridged_enabled': false,
      'viewer_role': viewerRole,
      'unread_count': 0,
      'counterparty': {
        'user_id': viewerRole == 'customer' ? 9 : 1,
        'role': viewerRole == 'customer' ? 'courier' : 'customer',
        'name': viewerRole == 'customer' ? 'Bima Kurir' : 'Ayu Customer',
        'phone': '081234567890',
      },
    });
  }

  Map<String, dynamic> callJson({
    int id = 50,
    String status = 'ringing',
    String viewerRole = 'caller',
  }) {
    return {
      'id': id,
      'call_uuid': 'uuid-$id',
      'order_id': 101,
      'order_number': 'CC-VOICE-101',
      'conversation_id': 25,
      'caller_id': viewerRole == 'caller' ? 1 : 9,
      'receiver_id': viewerRole == 'caller' ? 9 : 1,
      'status': status,
      'viewer_role': viewerRole,
      'caller': {'user_id': 1, 'role': 'customer', 'name': 'Ayu Customer', 'avatar': null},
      'receiver': {'user_id': 9, 'role': 'courier', 'name': 'Bima Kurir', 'avatar': null},
      'expires_at': DateTime.now().add(const Duration(seconds: 40)).toUtc().toIso8601String(),
    };
  }

  testWidgets('Customer calls Courier from ChatDetailScreen header, toggles mute/speaker, and ends call',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    late _FakeWebRtcEngine fakeEngine;
    final sentSignals = <Map<String, dynamic>>[];
    bool endedOnServer = false;

    final mockHttp = MockClient((req) async {
      if (req.url.path == '/api/v1/chat/realtime-config') {
        return http.Response(jsonEncode({'success': true, 'data': {'driver': 'null'}}), 200);
      }
      if (req.url.path == '/api/v1/chat/conversations/25/messages') {
        return http.Response(
          jsonEncode({'success': true, 'data': {'messages': [], 'has_more': false, 'next_before_id': null}}),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/incoming') {
        return http.Response(jsonEncode({'success': true, 'data': {'call': null, 'ice_servers': []}}), 200);
      }
      if (req.url.path == '/api/v1/calls/initiate') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': callJson(id: 50, status: 'ringing', viewerRole: 'caller'),
              'ice_servers': [
                {'urls': 'stun:stun.l.google.com:19302'},
                {'urls': 'turn:turn.neonflux.my.id:3478', 'username': 'u1', 'credential': 'c1'},
              ],
            },
          }),
          201,
        );
      }
      if (req.url.path == '/api/v1/calls/50/signals' && req.method == 'POST') {
        sentSignals.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'success': true, 'data': {'id': 1}}), 201);
      }
      if (req.url.path == '/api/v1/calls/50/signals' && req.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': callJson(id: 50, status: 'ringing', viewerRole: 'caller'),
              'signals': [],
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/50/end') {
        endedOnServer = true;
        return http.Response(
          jsonEncode({'success': true, 'data': {'call': callJson(id: 50, status: 'ended'), 'ice_servers': []}}),
          200,
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final chatApi = ChatApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');
    final ws = _WsStub();
    final realtime = ChatRealtimeService(apiService: chatApi, connector: (_) => ws);
    final callApi = CallApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');

    final callProvider = CallProvider(
      apiService: callApi,
      realtimeService: realtime,
      navigatorKey: navKey,
      enableNativeBridge: false,
      microphonePermissionRequester: () async => true,
      engineFactory: () {
        fakeEngine = _FakeWebRtcEngine();
        return fakeEngine;
      },
    );

    final conv = makeConversation(viewerRole: 'customer');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatProvider>(
            create: (_) => ChatProvider(apiService: chatApi, realtimeService: realtime),
          ),
          ChangeNotifierProvider<CallProvider>.value(value: callProvider),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          home: ChatDetailScreen(conversation: conv, knownUserId: 1, authTokenOverride: 't'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Header has in-app Call button (no external WhatsApp/dialer)
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(VoiceCallScreen), findsOneWidget);
    expect(find.text('Bima Kurir'), findsWidgets);
    expect(find.text('Berdering...'), findsOneWidget);
    expect(fakeEngine.initialized, isTrue);
    expect(fakeEngine.offerCreated, isTrue);
    expect(fakeEngine.receivedIceServers?.length, 2);
    expect(sentSignals.any((s) => s['signal_type'] == 'offer'), isTrue);

    // Emit local ICE candidate -> forwarded to signaling API
    fakeEngine.iceCtrl.add({'candidate': 'cand-1', 'sdpMid': '0', 'sdpMLineIndex': 0});
    await tester.pump(const Duration(milliseconds: 20));
    expect(sentSignals.any((s) => s['signal_type'] == 'ice_candidate'), isTrue);

    // Simulate remote connect
    fakeEngine.connCtrl.add(VoiceCallConnectionState.connected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Tersambung'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    // Mute microphone & toggle speaker
    await tester.tap(find.text('Mikrofon'));
    await tester.pump();
    expect(fakeEngine.muted, isTrue);
    expect(find.text('Dibisukan'), findsOneWidget);

    await tester.tap(find.text('Speaker'));
    await tester.pump();
    expect(fakeEngine.speakerOn, isTrue);

    // End call -> disposes engine & returns cleanly
    await tester.tap(find.text('Akhiri'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(endedOnServer, isTrue);
    expect(fakeEngine.disposed, isTrue);
    expect(find.byType(VoiceCallScreen), findsNothing);
    callProvider.dispose();
  });

  testWidgets('Courier sees IncomingCallScreen, accepts call, processes queued ICE + offer, or rejects',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    late _FakeWebRtcEngine fakeEngine;
    final sentSignals = <Map<String, dynamic>>[];
    bool rejectedCalled = false;

    final mockHttp = MockClient((req) async {
      if (req.url.path == '/api/v1/calls/88') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': callJson(id: 88, status: 'ringing', viewerRole: 'receiver'),
              'ice_servers': [{'urls': 'stun:stun.l.google.com:19302'}],
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/88/accept') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': callJson(id: 88, status: 'accepted', viewerRole: 'receiver'),
              'ice_servers': [{'urls': 'stun:stun.l.google.com:19302'}],
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/88/signals' && req.method == 'GET') {
        // ICE candidate arrived slightly before SDP offer -> CallProvider buffers until remoteDescriptionSet
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': callJson(id: 88, status: 'accepted', viewerRole: 'receiver'),
              'signals': [
                {
                  'id': 10,
                  'call_session_id': 88,
                  'sender_id': 1,
                  'receiver_id': 9,
                  'signal_type': 'ice_candidate',
                  'payload': {'candidate': 'early-cand', 'sdpMid': '0', 'sdpMLineIndex': 0},
                },
                {
                  'id': 11,
                  'call_session_id': 88,
                  'sender_id': 1,
                  'receiver_id': 9,
                  'signal_type': 'offer',
                  'payload': {'type': 'offer', 'sdp': 'v=0-caller-offer'},
                },
              ],
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/88/signals' && req.method == 'POST') {
        sentSignals.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'success': true, 'data': {'id': 12}}), 201);
      }
      if (req.url.path == '/api/v1/calls/89') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': callJson(id: 89, status: 'ringing', viewerRole: 'receiver'),
              'ice_servers': [],
            },
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/89/reject') {
        rejectedCalled = true;
        return http.Response(
          jsonEncode({'success': true, 'data': {'call': callJson(id: 89, status: 'rejected'), 'ice_servers': []}}),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/88/end') {
        return http.Response(
          jsonEncode({'success': true, 'data': {'call': callJson(id: 88, status: 'ended'), 'ice_servers': []}}),
          200,
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final chatApi = ChatApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');
    final ws = _WsStub();
    final realtime = ChatRealtimeService(apiService: chatApi, connector: (_) => ws);
    final callApi = CallApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');

    final callProvider = CallProvider(
      apiService: callApi,
      realtimeService: realtime,
      navigatorKey: navKey,
      enableNativeBridge: false,
      microphonePermissionRequester: () async => true,
      engineFactory: () {
        fakeEngine = _FakeWebRtcEngine();
        return fakeEngine;
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<CallProvider>.value(
        value: callProvider,
        child: MaterialApp(navigatorKey: navKey, home: const Scaffold(body: SizedBox())),
      ),
    );

    // 1. Trigger incoming call 88 -> shows IncomingCallScreen -> Accept
    unawaited(callProvider.handleIncomingCall(CallSessionModel.fromJson(callJson(id: 88, status: 'ringing', viewerRole: 'receiver'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(IncomingCallScreen), findsOneWidget);
    expect(find.text('Ayu Customer'), findsOneWidget);
    expect(find.text('Panggilan Suara Masuk'), findsOneWidget);
    expect(find.text('Terima'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);

    await tester.tap(find.text('Terima'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(VoiceCallScreen), findsOneWidget);
    expect(fakeEngine.lastRemoteSdp, 'v=0-caller-offer');
    expect(fakeEngine.addedIceCandidates.length, 1);
    expect(fakeEngine.answerCreated, isTrue);
    expect(sentSignals.any((s) => s['signal_type'] == 'answer'), isTrue);

    unawaited(callProvider.endCall());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 3));

    // 2. Trigger incoming call 89 -> Reject
    unawaited(callProvider.handleIncomingCall(CallSessionModel.fromJson(callJson(id: 89, status: 'ringing', viewerRole: 'receiver'))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(IncomingCallScreen), findsOneWidget);

    await tester.tap(find.text('Tolak'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(rejectedCalled, isTrue);
    expect(find.byType(IncomingCallScreen), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    callProvider.dispose();
  });

  test('Blocks call without microphone permission and marks failed on WebRTC ICE failure', () async {
    int initiateCount = 0;
    bool endFailedCalled = false;

    final mockHttp = MockClient((req) async {
      if (req.url.path == '/api/v1/calls/initiate') {
        initiateCount++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': {
                'id': 91,
                'call_uuid': 'u-91',
                'order_id': 101,
                'conversation_id': 25,
                'caller_id': 1,
                'receiver_id': 9,
                'status': 'ringing',
                'viewer_role': 'caller',
              },
              'ice_servers': [],
            },
          }),
          201,
        );
      }
      if (req.url.path == '/api/v1/calls/91/signals') {
        return http.Response(jsonEncode({'success': true, 'data': {'signals': []}}), 200);
      }
      if (req.url.path == '/api/v1/calls/91/end') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['status'] == 'failed') {
          endFailedCalled = true;
        }
        return http.Response(jsonEncode({'success': true, 'data': {'call': null, 'ice_servers': []}}), 200);
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final chatApi = ChatApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');
    final realtime = ChatRealtimeService(apiService: chatApi, connector: (_) => _WsStub());
    final callApi = CallApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');

    final deniedProvider = CallProvider(
      apiService: callApi,
      realtimeService: realtime,
      enableNativeBridge: false,
      microphonePermissionRequester: () async => false,
    );

    final conv = makeConversation();
    final deniedOk = await deniedProvider.startCallFromChat(conversation: conv, openScreen: false);
    expect(deniedOk, isFalse);
    expect(initiateCount, 0);
    expect(deniedProvider.errorMessage, contains('mikrofon'));

    late _FakeWebRtcEngine failingEngine;
    final failProvider = CallProvider(
      apiService: callApi,
      realtimeService: realtime,
      enableNativeBridge: false,
      microphonePermissionRequester: () async => true,
      engineFactory: () {
        failingEngine = _FakeWebRtcEngine();
        return failingEngine;
      },
    );

    final started = await failProvider.startCallFromChat(conversation: conv, openScreen: false);
    expect(started, isTrue);

    failingEngine.connCtrl.add(VoiceCallConnectionState.failed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(endFailedCalled, isTrue);
    expect(failProvider.phase, VoiceCallUiPhase.failed);
    expect(failingEngine.disposed, isTrue);
    deniedProvider.dispose();
    failProvider.dispose();
  });

  testWidgets('Courier also sees header phone button and handles FCM incoming_call & call_cancelled push',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final mockHttp = MockClient((req) async {
      if (req.url.path == '/api/v1/chat/realtime-config') {
        return http.Response(jsonEncode({'success': true, 'data': {'driver': 'null'}}), 200);
      }
      if (req.url.path == '/api/v1/chat/conversations/25/messages') {
        return http.Response(
          jsonEncode({'success': true, 'data': {'messages': [], 'has_more': false, 'next_before_id': null}}),
          200,
        );
      }
      if (req.url.path == '/api/v1/calls/95') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'call': callJson(id: 95, status: 'ringing', viewerRole: 'receiver'),
              'ice_servers': [],
            },
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final chatApi = ChatApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');
    final realtime = ChatRealtimeService(apiService: chatApi, connector: (_) => _WsStub());
    final callApi = CallApiService(client: mockHttp, tokenReader: () async => 't', baseUrl: 'https://www.neonflux.my.id/api');

    final callProvider = CallProvider(
      apiService: callApi,
      realtimeService: realtime,
      navigatorKey: navKey,
      enableNativeBridge: false,
      microphonePermissionRequester: () async => true,
      engineFactory: _FakeWebRtcEngine.new,
    );

    final courierConv = makeConversation(viewerRole: 'courier');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatProvider>(
            create: (_) => ChatProvider(apiService: chatApi, realtimeService: realtime),
          ),
          ChangeNotifierProvider<CallProvider>.value(value: callProvider),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          home: ChatDetailScreen(conversation: courierConv, knownUserId: 9, authTokenOverride: 't'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.call_rounded), findsOneWidget);

    await callProvider.handleIncomingPushData({'type': 'incoming_call', 'call_id': '95'});
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(IncomingCallScreen), findsOneWidget);

    await callProvider.handleIncomingPushData({'type': 'call_cancelled', 'call_id': '95'});
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(IncomingCallScreen), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    callProvider.dispose();
  });
}
