import 'package:flutter/services.dart';

class VoiceCallNativeBridge {
  static const MethodChannel _channel = MethodChannel('city_courier/voice_call_native');

  static Future<void> startIncomingRingtone() async {
    try {
      await _channel.invokeMethod<bool>('startIncomingRingtone');
    } catch (_) {}
  }

  static Future<void> stopRingtone() async {
    try {
      await _channel.invokeMethod<bool>('stopRingtone');
    } catch (_) {}
  }

  static Future<void> startCallService({
    required String title,
    required String subtitle,
  }) async {
    try {
      await _channel.invokeMethod<bool>('startCallService', {
        'title': title,
        'subtitle': subtitle,
      });
    } catch (_) {}
  }

  static Future<void> stopCallService() async {
    try {
      await _channel.invokeMethod<bool>('stopCallService');
    } catch (_) {}
  }
}
