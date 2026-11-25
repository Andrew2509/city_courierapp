import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum VoiceCallConnectionState {
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

/// Abstract audio WebRTC engine so CallProvider business logic can be deterministically
/// tested without native platform channels while FlutterWebRtcCallEngine drives real audio.
abstract class WebRtcCallEngine {
  Stream<Map<String, dynamic>> get onIceCandidate;
  Stream<VoiceCallConnectionState> get onConnectionState;

  Future<void> initialize({required List<Map<String, dynamic>> iceServers});
  Future<Map<String, dynamic>> createOffer();
  Future<Map<String, dynamic>> createAnswer();
  Future<void> setRemoteDescription({required String sdp, required String type});
  Future<void> addIceCandidate(Map<String, dynamic> candidate);
  Future<void> setMicrophoneMuted(bool muted);
  Future<void> setSpeakerphoneOn(bool speakerOn);
  Future<void> dispose();
}

class FlutterWebRtcCallEngine implements WebRtcCallEngine {
  final StreamController<Map<String, dynamic>> _iceController = StreamController.broadcast();
  final StreamController<VoiceCallConnectionState> _connController = StreamController.broadcast();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _disposed = false;

  @override
  Stream<Map<String, dynamic>> get onIceCandidate => _iceController.stream;

  @override
  Stream<VoiceCallConnectionState> get onConnectionState => _connController.stream;

  @override
  Future<void> initialize({required List<Map<String, dynamic>> iceServers}) async {
    _disposed = false;

    final constraints = <String, dynamic>{
      'audio': <String, dynamic>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    final configuration = <String, dynamic>{
      'iceServers': iceServers.isNotEmpty
          ? iceServers
          : [
              {'urls': 'stun:stun.l.google.com:19302'},
            ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    for (final track in _localStream!.getAudioTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_disposed || candidate.candidate == null || candidate.candidate!.isEmpty) return;
      _iceController.add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (_disposed) return;
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _connController.add(VoiceCallConnectionState.connected);
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _connController.add(VoiceCallConnectionState.disconnected);
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _connController.add(VoiceCallConnectionState.failed);
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _connController.add(VoiceCallConnectionState.closed);
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
        case RTCIceConnectionState.RTCIceConnectionStateNew:
        case RTCIceConnectionState.RTCIceConnectionStateCount:
          _connController.add(VoiceCallConnectionState.connecting);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (_disposed) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _connController.add(VoiceCallConnectionState.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _connController.add(VoiceCallConnectionState.disconnected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _connController.add(VoiceCallConnectionState.failed);
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _connController.add(VoiceCallConnectionState.closed);
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          _connController.add(VoiceCallConnectionState.connecting);
      }
    };

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> createOffer() async {
    final pc = _peerConnection;
    if (pc == null) throw StateError('PeerConnection belum diinisialisasi.');

    final desc = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await pc.setLocalDescription(desc);
    return {
      'sdp': desc.sdp ?? '',
      'type': desc.type ?? 'offer',
    };
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    final pc = _peerConnection;
    if (pc == null) throw StateError('PeerConnection belum diinisialisasi.');

    final desc = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await pc.setLocalDescription(desc);
    return {
      'sdp': desc.sdp ?? '',
      'type': desc.type ?? 'answer',
    };
  }

  @override
  Future<void> setRemoteDescription({required String sdp, required String type}) async {
    final pc = _peerConnection;
    if (pc == null) throw StateError('PeerConnection belum diinisialisasi.');

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
  }

  @override
  Future<void> addIceCandidate(Map<String, dynamic> candidate) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final raw = candidate['candidate']?.toString();
    if (raw == null || raw.isEmpty) return;

    await pc.addCandidate(
      RTCIceCandidate(
        raw,
        candidate['sdpMid']?.toString(),
        (candidate['sdpMLineIndex'] as num?)?.toInt(),
      ),
    );
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      await Helper.setMicrophoneMute(muted, track);
    }
  }

  @override
  Future<void> setSpeakerphoneOn(bool speakerOn) async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    try {
      for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
        await track.stop();
      }
      await _localStream?.dispose();
      await _remoteStream?.dispose();
    } catch (_) {}
    _localStream = null;
    _remoteStream = null;

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (_) {}
    _peerConnection = null;

    if (!_iceController.isClosed) {
      await _iceController.close();
    }
    if (!_connController.isClosed) {
      await _connController.close();
    }
  }
}
