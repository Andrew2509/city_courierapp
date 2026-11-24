import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isTtsInitialized = false;
  bool _isSttInitialized = false;

  Function(String)? onStatusChanged;

  Future<void> init() async {
    await _initTts();
    await _initStt();
  }

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    try {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setSpeechRate(0.52);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions
                .interruptSpokenAudioAndMixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      await _flutterTts.awaitSpeakCompletion(false);
      _isTtsInitialized = true;
    } catch (_) {
      // Abaikan pada environment test/non-device tanpa plugin TTS
    }
  }

  Future<void> _initStt() async {
    if (_isSttInitialized) return;
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (error) {
          if (error.errorMsg == 'error_speech_timeout' || error.permanent) {
            onStatusChanged?.call('notListening');
          }
        },
        onStatus: (status) {
          onStatusChanged?.call(status);
        },
      );
    } catch (_) {
      // Abaikan jika STT tidak tersedia
    }
  }

  Future<void> speak(String text, {bool interrupt = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      if (!_isTtsInitialized) await _initTts();
      if (interrupt) {
        await _flutterTts.stop();
      }
      await _flutterTts.speak(trimmed, focus: false);
    } catch (_) {
      // Aman di unit test / headless environment
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  bool get isListening => _speechToText.isListening;

  Future<bool> startListening(Function(String) onResult) async {
    try {
      if (!_isSttInitialized) await _initStt();
      if (!_isSttInitialized) return false;

      if (!_speechToText.isListening) {
        await _flutterTts.stop();
        await _speechToText.listen(
          onResult: (result) {
            onResult(result.recognizedWords);
          },
          localeId: 'id_ID',
          cancelOnError: true,
          partialResults: true,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
  }
}
