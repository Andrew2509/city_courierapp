import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:city_courierapp/models/call/call_models.dart';
import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/screens/call/incoming_call_screen.dart';
import 'package:city_courierapp/screens/call/voice_call_screen.dart';
import 'package:city_courierapp/services/call/call_api_service.dart';
import 'package:city_courierapp/services/call/voice_call_native_bridge.dart';
import 'package:city_courierapp/services/call/webrtc_call_engine.dart';
import 'package:city_courierapp/services/chat/chat_notification_service.dart';
import 'package:city_courierapp/services/chat/chat_realtime_service.dart';

enum VoiceCallUiPhase {
  idle,
  starting,
  ringingOutgoing,
  ringingIncoming,
  connecting,
  connected,
  ended,
  failed,
}

typedef MicPermissionRequester = Future<bool> Function();
typedef CallEngineFactory = WebRtcCallEngine Function();

Future<bool> _defaultMicPermissionRequester() async {
  final status = await Permission.microphone.request();
  if (status.isGranted || status.isLimited) {
    return true;
  }
  return false;
}

class CallProvider extends ChangeNotifier {
  final CallApiService _apiService;
  final ChatRealtimeService _realtimeService;
  final CallEngineFactory _engineFactory;
  final MicPermissionRequester _micPermissionRequester;
  final GlobalKey<NavigatorState>? _navigatorKey;
  final bool _enableNativeBridge;

  int? _currentUserId;
  bool _disposed = false;

  CallSessionModel? _currentCall;
  List<IceServerConfig> _iceServers = const [];
  VoiceCallUiPhase _phase = VoiceCallUiPhase.idle;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  int _callDurationSeconds = 0;
  String? _statusMessage;
  String? _errorMessage;

  WebRtcCallEngine? _engine;
  StreamSubscription? _iceSub;
  StreamSubscription? _connSub;
  final List<StreamSubscription> _realtimeSubs = [];

  final Set<int> _processedSignalIds = <int>{};
  int _lastSignalId = 0;
  bool _remoteDescriptionSet = false;
  final List<Map<String, dynamic>> _pendingIceCandidates = [];
  bool _creatingAnswer = false;
  bool _callScreenOpen = false;
  bool _incomingScreenOpen = false;
  int? _handledTerminalCallId;

  Timer? _ringTimeoutTimer;
  Timer? _signalPollTimer;
  Timer? _durationTimer;
  Timer? _disconnectGraceTimer;
  Timer? _autoDismissTimer;

  CallProvider({
    CallApiService? apiService,
    required ChatRealtimeService realtimeService,
    CallEngineFactory? engineFactory,
    MicPermissionRequester? microphonePermissionRequester,
    GlobalKey<NavigatorState>? navigatorKey,
    bool enableNativeBridge = true,
  })  : _apiService = apiService ?? CallApiService(),
        _realtimeService = realtimeService,
        _engineFactory = engineFactory ?? FlutterWebRtcCallEngine.new,
        _micPermissionRequester = microphonePermissionRequester ?? _defaultMicPermissionRequester,
        _navigatorKey = navigatorKey,
        _enableNativeBridge = enableNativeBridge {
    _bindRealtimeEvents();
  }

  int? get currentUserId => _currentUserId;
  CallSessionModel? get currentCall => _currentCall;
  VoiceCallUiPhase get phase => _phase;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  int get callDurationSeconds => _callDurationSeconds;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  bool get hasOngoingCall =>
      _currentCall != null &&
      (_phase == VoiceCallUiPhase.starting ||
          _phase == VoiceCallUiPhase.ringingOutgoing ||
          _phase == VoiceCallUiPhase.ringingIncoming ||
          _phase == VoiceCallUiPhase.connecting ||
          _phase == VoiceCallUiPhase.connected);

  String get formattedDuration {
    final mins = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get phaseLabel => switch (_phase) {
    VoiceCallUiPhase.idle => 'Siap',
    VoiceCallUiPhase.starting => 'Menyiapkan panggilan...',
    VoiceCallUiPhase.ringingOutgoing => 'Berdering...',
    VoiceCallUiPhase.ringingIncoming => 'Panggilan masuk...',
    VoiceCallUiPhase.connecting => 'Menghubungkan...',
    VoiceCallUiPhase.connected => 'Tersambung',
    VoiceCallUiPhase.failed => _statusMessage ?? 'Panggilan gagal tersambung',
    VoiceCallUiPhase.ended => _statusMessage ?? 'Panggilan berakhir',
  };

  void _bindRealtimeEvents() {
    _realtimeSubs.add(
      _realtimeService.onIncomingCall.listen((call) {
        unawaited(handleIncomingCall(call));
      }),
    );
    _realtimeSubs.add(
      _realtimeService.onCallUpdated.listen((call) {
        unawaited(_handleRemoteCallUpdated(call));
      }),
    );
    _realtimeSubs.add(
      _realtimeService.onCallSignal.listen((signal) {
        unawaited(_handleIncomingSignal(signal));
      }),
    );
  }

  Future<void> bindAuthenticatedUser(int userId) async {
    final changed = _currentUserId != userId;
    _currentUserId = userId;
    if (changed) {
      await checkIncomingCalls();
    }
  }

  Future<void> clearOnLogout() async {
    await _teardownMediaAndTimers(stopNative: true);
    _currentUserId = null;
    _currentCall = null;
    _iceServers = const [];
    _phase = VoiceCallUiPhase.idle;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  Future<bool> startCallFromChat({
    required ConversationModel conversation,
    bool openScreen = true,
  }) async {
    if (hasOngoingCall) {
      _errorMessage = 'Masih ada panggilan yang sedang berlangsung.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _statusMessage = null;
    _handledTerminalCallId = null;

    final micGranted = await _micPermissionRequester();
    if (!micGranted) {
      _errorMessage = 'Izin mikrofon diperlukan untuk melakukan panggilan suara.';
      notifyListeners();
      return false;
    }

    _resetPerCallState();
    _phase = VoiceCallUiPhase.starting;
    _statusMessage = 'Menyiapkan panggilan...';
    notifyListeners();

    try {
      final res = await _apiService.initiateCall(
        conversationId: conversation.id,
      );

      final session = res.call;
      if (session == null) {
        throw const CallApiException('Sesi panggilan tidak dikembalikan server.');
      }

      _currentCall = session;
      _iceServers = res.iceServers;
      _phase = VoiceCallUiPhase.ringingOutgoing;
      _statusMessage = 'Berdering...';
      notifyListeners();

      if (openScreen) {
        _openVoiceCallScreen();
      }

      await _prepareEngine(session);
      await _realtimeService.subscribePrivateCall(session.id);

      if (_enableNativeBridge) {
        final target = session.counterpartyForUser(_currentUserId);
        await VoiceCallNativeBridge.startCallService(
          title: 'Memanggil ${target.name}',
          subtitle: session.orderNumber != null ? 'Order #${session.orderNumber}' : 'City Courier',
        );
      }

      final offer = await _engine!.createOffer();
      await _apiService.sendSignal(
        session.id,
        signalType: 'offer',
        payload: offer,
      );

      _startRingTimeoutTimer(session);
      _startSignalAndStatusPolling(session.id, fastMode: true);

      return true;
    } catch (e) {
      final failedCallId = _currentCall?.id;
      if (failedCallId != null) {
        unawaited(_safeEndCallOnServer(failedCallId, status: 'failed', reason: 'client_init_failed'));
      }
      await _teardownMediaAndTimers(stopNative: true);
      _phase = VoiceCallUiPhase.failed;
      _errorMessage = e.toString();
      _statusMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> checkIncomingCalls({bool autoAccept = false}) async {
    if (_currentUserId == null) return;
    if (_phase == VoiceCallUiPhase.connecting || _phase == VoiceCallUiPhase.connected) {
      return;
    }

    try {
      final res = await _apiService.getIncomingCall();
      final call = res.call;
      if (call == null || call.status != CallStatus.ringing) {
        if (_phase == VoiceCallUiPhase.ringingIncoming) {
          await _handleRemoteCallTerminal(
            _currentCall?.copyWith(status: CallStatus.missed) ??
                CallSessionModel(
                  id: _currentCall?.id ?? 0,
                  callUuid: '',
                  conversationId: 0,
                  callerId: 0,
                  receiverId: 0,
                  status: CallStatus.missed,
                  viewerRole: 'receiver',
                  caller: const CallParticipant(userId: 0, role: 'customer', name: 'Pengguna'),
                  receiver: const CallParticipant(userId: 0, role: 'courier', name: 'Kurir'),
                ),
            label: 'Panggilan berakhir',
          );
        }
        return;
      }

      _iceServers = res.iceServers;
      await handleIncomingCall(call, autoAccept: autoAccept);
    } catch (_) {}
  }

  Future<void> handleIncomingPushData(
    Map<String, dynamic> data, {
    bool autoAccept = false,
  }) async {
    final type = (data['type'] ?? '').toString();
    final callId = int.tryParse((data['call_id'] ?? '').toString());
    if (callId == null || callId <= 0) return;

    if (type == 'call_cancelled') {
      if (_currentCall?.id == callId &&
          (_phase == VoiceCallUiPhase.ringingIncoming || _phase == VoiceCallUiPhase.starting)) {
        await _handleRemoteCallTerminal(
          _currentCall!.copyWith(status: CallStatus.missed),
          label: 'Panggilan dibatalkan',
        );
      }
      return;
    }

    if (type == 'incoming_call') {
      try {
        final res = await _apiService.getCallStatus(callId);
        if (res.call != null && res.call!.status == CallStatus.ringing) {
          _iceServers = res.iceServers;
          await handleIncomingCall(res.call!, autoAccept: autoAccept);
        }
      } catch (_) {}
    }
  }

  Future<void> handleIncomingCall(
    CallSessionModel call, {
    bool autoAccept = false,
  }) async {
    if (call.status != CallStatus.ringing) return;
    if (_handledTerminalCallId == call.id) return;
    if (_currentCall != null && _currentCall!.id != call.id && hasOngoingCall) {
      return;
    }

    if (_iceServers.isEmpty) {
      try {
        final statusRes = await _apiService.getCallStatus(call.id);
        if (statusRes.call == null || statusRes.call!.status != CallStatus.ringing) {
          return;
        }
        call = statusRes.call!;
        _iceServers = statusRes.iceServers;
      } catch (_) {}
    }

    final isNewRing = _currentCall?.id != call.id;
    _currentCall = call;

    if (isNewRing) {
      _resetPerCallState();
      _phase = VoiceCallUiPhase.ringingIncoming;
      _statusMessage = 'Panggilan masuk...';
      _errorMessage = null;
      notifyListeners();

      await _realtimeService.subscribePrivateCall(call.id);
      _startRingTimeoutTimer(call);
      _startSignalAndStatusPolling(call.id, fastMode: false);

      if (_enableNativeBridge && !autoAccept) {
        await VoiceCallNativeBridge.startIncomingRingtone();
      }
      if (!autoAccept) {
        _openIncomingCallScreen();
      }
    }

    if (autoAccept) {
      await acceptIncomingCall();
    }
  }

  Future<bool> acceptIncomingCall({bool openScreen = true}) async {
    final call = _currentCall;
    if (call == null) return false;

    if (_enableNativeBridge) {
      await VoiceCallNativeBridge.stopRingtone();
      unawaited(ChatNotificationService.instance.cancelIncomingCallNotification(call.id));
    }

    final micGranted = await _micPermissionRequester();
    if (!micGranted) {
      _errorMessage = 'Izin mikrofon diperlukan untuk menjawab panggilan.';
      _phase = VoiceCallUiPhase.failed;
      _statusMessage = _errorMessage;
      notifyListeners();
      unawaited(rejectIncomingCall(reason: 'mic_permission_denied'));
      return false;
    }

    _phase = VoiceCallUiPhase.connecting;
    _statusMessage = 'Menghubungkan...';
    _errorMessage = null;
    notifyListeners();

    if (openScreen) {
      _openVoiceCallScreen(replaceIncoming: true);
    }

    try {
      if (_iceServers.isEmpty) {
        final statusRes = await _apiService.getCallStatus(call.id);
        _iceServers = statusRes.iceServers;
      }

      await _prepareEngine(call);
      await _realtimeService.subscribePrivateCall(call.id);

      final acceptRes = await _apiService.acceptCall(call.id);
      if (acceptRes.call != null) {
        _currentCall = acceptRes.call;
      }
      if (acceptRes.iceServers.isNotEmpty) {
        _iceServers = acceptRes.iceServers;
      }

      _ringTimeoutTimer?.cancel();
      _startSignalAndStatusPolling(call.id, fastMode: true);

      if (_enableNativeBridge) {
        final caller = call.counterpartyForUser(_currentUserId);
        await VoiceCallNativeBridge.startCallService(
          title: 'Panggilan dengan ${caller.name}',
          subtitle: call.orderNumber != null ? 'Order #${call.orderNumber}' : 'City Courier',
        );
      }

      await _fetchMissedSignalsAndSync(call.id);
      return true;
    } catch (e) {
      unawaited(_safeEndCallOnServer(call.id, status: 'failed', reason: 'accept_failed'));
      await _teardownMediaAndTimers(stopNative: true);
      _phase = VoiceCallUiPhase.failed;
      _errorMessage = e.toString();
      _statusMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> rejectIncomingCall({String? reason}) async {
    final call = _currentCall;
    if (call == null) return;

    _handledTerminalCallId = call.id;
    _phase = VoiceCallUiPhase.ended;
    _statusMessage = 'Panggilan ditolak';
    _closeCallOverlays();
    _currentCall = null;
    _iceServers = const [];
    notifyListeners();
    _resetToIdleSoon();

    await _teardownMediaAndTimers(stopNative: true, callId: call.id);

    try {
      await _apiService.rejectCall(call.id, reason: reason);
    } catch (_) {}
  }

  Future<void> endCall({String? status, String? reason}) async {
    final call = _currentCall;
    if (call == null) {
      _closeCallOverlays();
      return;
    }

    _handledTerminalCallId = call.id;
    final desiredStatus = status ?? (_phase == VoiceCallUiPhase.connected ? 'ended' : 'missed');

    _phase = desiredStatus == 'failed' ? VoiceCallUiPhase.failed : VoiceCallUiPhase.ended;
    _statusMessage = desiredStatus == 'failed' ? 'Panggilan gagal tersambung' : 'Panggilan berakhir';
    _closeCallOverlays();
    _currentCall = null;
    _iceServers = const [];
    notifyListeners();
    _resetToIdleSoon();

    await _teardownMediaAndTimers(stopNative: true, callId: call.id);
    unawaited(_realtimeService.unsubscribePrivateCall(call.id));

    try {
      await _apiService.endCall(call.id, status: desiredStatus, reason: reason);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine?.setMicrophoneMuted(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _engine?.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> _prepareEngine(CallSessionModel call) async {
    await _iceSub?.cancel();
    await _connSub?.cancel();
    await _engine?.dispose();

    final engine = _engineFactory();
    _engine = engine;
    await engine.initialize(
      iceServers: _iceServers.map((e) => e.toWebRtcMap()).toList(),
    );

    _iceSub = engine.onIceCandidate.listen((candidate) {
      final activeId = _currentCall?.id;
      if (activeId == null) return;
      unawaited(
        _apiService
            .sendSignal(
              activeId,
              signalType: 'ice_candidate',
              payload: candidate,
            )
            .catchError((_) {}),
      );
    });

    _connSub = engine.onConnectionState.listen((state) {
      _handleWebRtcConnectionState(state);
    });
  }

  void _handleWebRtcConnectionState(VoiceCallConnectionState state) {
    if (_disposed || _currentCall == null) return;

    switch (state) {
      case VoiceCallConnectionState.connected:
        _disconnectGraceTimer?.cancel();
        _ringTimeoutTimer?.cancel();
        if (_phase != VoiceCallUiPhase.connected) {
          _phase = VoiceCallUiPhase.connected;
          _statusMessage = 'Tersambung';
          _startDurationTimer();
          // Slow down status heartbeat once connected (if WS drops)
          _startSignalAndStatusPolling(_currentCall!.id, fastMode: false);
          notifyListeners();
        }
      case VoiceCallConnectionState.connecting:
        if (_phase == VoiceCallUiPhase.ringingOutgoing || _phase == VoiceCallUiPhase.ringingIncoming) {
          _phase = VoiceCallUiPhase.connecting;
          _statusMessage = 'Menghubungkan...';
          notifyListeners();
        }
      case VoiceCallConnectionState.disconnected:
        _disconnectGraceTimer?.cancel();
        _disconnectGraceTimer = Timer(const Duration(seconds: 10), () {
          if (_phase == VoiceCallUiPhase.connected || _phase == VoiceCallUiPhase.connecting) {
            unawaited(_handleConnectionFailure('Koneksi internet terputus.', reason: 'network_disconnected'));
          }
        });
      case VoiceCallConnectionState.failed:
        unawaited(_handleConnectionFailure('Gagal membangun koneksi audio WebRTC.', reason: 'ice_connection_failed'));
      case VoiceCallConnectionState.closed:
        break;
    }
  }

  Future<void> _handleConnectionFailure(String msg, {required String reason}) async {
    final call = _currentCall;
    if (call == null || _handledTerminalCallId == call.id) return;

    _handledTerminalCallId = call.id;
    await _teardownMediaAndTimers(stopNative: true);
    unawaited(_safeEndCallOnServer(call.id, status: 'failed', reason: reason));

    _phase = VoiceCallUiPhase.failed;
    _errorMessage = msg;
    _statusMessage = msg;
    notifyListeners();
  }

  Future<void> _handleRemoteCallUpdated(CallSessionModel call) async {
    if (_currentCall == null || _currentCall!.id != call.id) return;
    _currentCall = call;

    if (call.status == CallStatus.accepted) {
      _ringTimeoutTimer?.cancel();
      if (_phase == VoiceCallUiPhase.ringingOutgoing) {
        _phase = VoiceCallUiPhase.connecting;
        _statusMessage = 'Menghubungkan...';
        notifyListeners();
      }
      await _fetchMissedSignalsAndSync(call.id);
      return;
    }

    if (call.status.isTerminal) {
      final label = switch (call.status) {
        CallStatus.rejected => 'Panggilan ditolak',
        CallStatus.missed => 'Tidak dijawab',
        CallStatus.failed => 'Panggilan gagal tersambung',
        _ => 'Panggilan berakhir',
      };
      await _handleRemoteCallTerminal(call, label: label);
    }
  }

  Future<void> _handleRemoteCallTerminal(CallSessionModel call, {required String label}) async {
    if (_handledTerminalCallId == call.id) return;
    _handledTerminalCallId = call.id;

    await _teardownMediaAndTimers(stopNative: true, callId: call.id);
    unawaited(_realtimeService.unsubscribePrivateCall(call.id));

    _phase = call.status == CallStatus.failed ? VoiceCallUiPhase.failed : VoiceCallUiPhase.ended;
    _statusMessage = label;
    notifyListeners();

    _closeCallOverlays();
    _currentCall = null;
    _iceServers = const [];
    _resetToIdleSoon();
  }

  Future<void> _handleIncomingSignal(CallSignalModel signal) async {
    if (_currentCall == null || signal.callSessionId != _currentCall!.id) return;
    if (_currentUserId != null && signal.senderId == _currentUserId) return;
    if (signal.id > 0 && !_processedSignalIds.add(signal.id)) return;
    if (signal.id > _lastSignalId) {
      _lastSignalId = signal.id;
    }

    final engine = _engine;
    if (engine == null) return;

    if (signal.signalType == 'offer') {
      final sdp = signal.payload['sdp']?.toString();
      if (sdp == null || sdp.isEmpty) return;

      await engine.setRemoteDescription(
        sdp: sdp,
        type: signal.payload['type']?.toString() ?? 'offer',
      );
      _remoteDescriptionSet = true;
      await _flushPendingIceCandidates();

      if (!_creatingAnswer) {
        _creatingAnswer = true;
        try {
          final answer = await engine.createAnswer();
          await _apiService.sendSignal(
            _currentCall!.id,
            signalType: 'answer',
            payload: answer,
          );
        } finally {
          _creatingAnswer = false;
        }
      }
      return;
    }

    if (signal.signalType == 'answer') {
      final sdp = signal.payload['sdp']?.toString();
      if (sdp == null || sdp.isEmpty) return;

      await engine.setRemoteDescription(
        sdp: sdp,
        type: signal.payload['type']?.toString() ?? 'answer',
      );
      _remoteDescriptionSet = true;
      await _flushPendingIceCandidates();
      return;
    }

    if (signal.signalType == 'ice_candidate') {
      if (!_remoteDescriptionSet) {
        _pendingIceCandidates.add(signal.payload);
      } else {
        await engine.addIceCandidate(signal.payload);
      }
    }
  }

  Future<void> _flushPendingIceCandidates() async {
    final engine = _engine;
    if (engine == null || !_remoteDescriptionSet) return;
    final queued = List<Map<String, dynamic>>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final c in queued) {
      await engine.addIceCandidate(c);
    }
  }

  void _startRingTimeoutTimer(CallSessionModel call) {
    _ringTimeoutTimer?.cancel();
    final expiresAt = call.expiresAt ?? DateTime.now().add(const Duration(seconds: 45));
    final diff = expiresAt.difference(DateTime.now());
    final wait = diff.isNegative ? const Duration(seconds: 1) : diff;

    _ringTimeoutTimer = Timer(wait, () {
      if (_currentCall?.id == call.id &&
          (_phase == VoiceCallUiPhase.ringingOutgoing || _phase == VoiceCallUiPhase.ringingIncoming)) {
        if (_phase == VoiceCallUiPhase.ringingOutgoing) {
          unawaited(endCall(status: 'missed', reason: 'missed_timeout'));
        } else {
          unawaited(checkIncomingCalls());
        }
      }
    });
  }

  void _startSignalAndStatusPolling(int callId, {required bool fastMode}) {
    _signalPollTimer?.cancel();
    final interval = fastMode ? const Duration(milliseconds: 500) : const Duration(milliseconds: 1600);
    _signalPollTimer = Timer.periodic(interval, (_) {
      if (_disposed || _currentCall?.id != callId) return;
      if (_phase == VoiceCallUiPhase.ringingIncoming) {
        unawaited(_pollCallStatusOnly(callId));
      } else if (_phase == VoiceCallUiPhase.ringingOutgoing || _phase == VoiceCallUiPhase.connecting) {
        unawaited(_fetchMissedSignalsAndSync(callId));
      } else if (_phase == VoiceCallUiPhase.connected && !_realtimeService.isConnected) {
        unawaited(_pollCallStatusOnly(callId));
      }
    });
  }

  Future<void> _pollCallStatusOnly(int callId) async {
    try {
      final res = await _apiService.getCallStatus(callId);
      if (res.call != null) {
        await _handleRemoteCallUpdated(res.call!);
      }
    } catch (_) {}
  }

  Future<void> _fetchMissedSignalsAndSync(int callId) async {
    try {
      final result = await _apiService.getSignals(callId, afterId: _lastSignalId);
      if (result.call != null) {
        if (result.call!.status == CallStatus.accepted && _phase == VoiceCallUiPhase.ringingOutgoing) {
          _currentCall = result.call;
          _ringTimeoutTimer?.cancel();
          _phase = VoiceCallUiPhase.connecting;
          _statusMessage = 'Menghubungkan...';
          notifyListeners();
        } else if (result.call!.status.isTerminal) {
          await _handleRemoteCallUpdated(result.call!);
          return;
        }
      }

      for (final signal in result.signals) {
        await _handleIncomingSignal(signal);
      }
    } catch (_) {}
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase == VoiceCallUiPhase.connected) {
        _callDurationSeconds++;
        notifyListeners();
      }
    });
  }

  Future<void> _safeEndCallOnServer(int callId, {required String status, required String reason}) async {
    try {
      await _apiService.endCall(callId, status: status, reason: reason);
    } catch (_) {}
  }

  void _resetPerCallState() {
    _processedSignalIds.clear();
    _lastSignalId = 0;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();
    _creatingAnswer = false;
    _isMuted = false;
    _isSpeakerOn = false;
    _callDurationSeconds = 0;
    _autoDismissTimer?.cancel();
  }

  Future<void> _teardownMediaAndTimers({required bool stopNative, int? callId}) async {
    _ringTimeoutTimer?.cancel();
    _signalPollTimer?.cancel();
    _durationTimer?.cancel();
    _disconnectGraceTimer?.cancel();

    await _iceSub?.cancel();
    _iceSub = null;
    await _connSub?.cancel();
    _connSub = null;

    await _engine?.dispose();
    _engine = null;

    if (stopNative && _enableNativeBridge) {
      await VoiceCallNativeBridge.stopRingtone();
      await VoiceCallNativeBridge.stopCallService();
      final activeCallId = callId ?? _currentCall?.id;
      if (activeCallId != null && activeCallId > 0) {
        unawaited(ChatNotificationService.instance.cancelIncomingCallNotification(activeCallId));
      }
    }
  }

  void _openIncomingCallScreen() {
    if (_incomingScreenOpen || _callScreenOpen) return;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    _incomingScreenOpen = true;
    unawaited(
      navigator
          .push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const IncomingCallScreen(),
            ),
          )
          .whenComplete(() {
        _incomingScreenOpen = false;
      }),
    );
  }

  void _openVoiceCallScreen({bool replaceIncoming = false}) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    if (replaceIncoming && _incomingScreenOpen) {
      _incomingScreenOpen = false;
      _callScreenOpen = true;
      unawaited(
        navigator
            .pushReplacement(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const VoiceCallScreen(),
              ),
            )
            .whenComplete(() {
          _callScreenOpen = false;
        }),
      );
      return;
    }

    if (_callScreenOpen) return;
    _callScreenOpen = true;
    unawaited(
      navigator
          .push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const VoiceCallScreen(),
            ),
          )
          .whenComplete(() {
        _callScreenOpen = false;
      }),
    );
  }

  void openOngoingCallScreen() => _openVoiceCallScreen();

  void _closeCallOverlays() {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    if (_incomingScreenOpen || _callScreenOpen) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      _incomingScreenOpen = false;
      _callScreenOpen = false;
    }
  }

  void _resetToIdleSoon() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 2), () {
      if (_currentCall == null && (_phase == VoiceCallUiPhase.ended || _phase == VoiceCallUiPhase.failed)) {
        _phase = VoiceCallUiPhase.idle;
        _statusMessage = null;
        _errorMessage = null;
        notifyListeners();
      }
    });
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
    unawaited(_teardownMediaAndTimers(stopNative: true));
    for (final sub in _realtimeSubs) {
      sub.cancel();
    }
    _autoDismissTimer?.cancel();
    super.dispose();
  }
}
