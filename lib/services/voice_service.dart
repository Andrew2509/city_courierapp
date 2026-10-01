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
      await _flutterTts.setSpeechRate(0.5); // 0.0 to 1.0
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      print("Error initializing TTS: $e");
    }
  }

  Future<void> _initStt() async {
    if (_isSttInitialized) return;
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (error) {
          print("STT Error: $error");
          if (error.errorMsg == 'error_speech_timeout' || error.permanent) {
             onStatusChanged?.call('notListening');
          }
        },
        onStatus: (status) {
          print("STT Status: $status");
          onStatusChanged?.call(status);
        },
      );
    } catch (e) {
      print("Error initializing STT: $e");
    }
  }

  Future<void> speak(String text) async {
    if (!_isTtsInitialized) await _initTts();
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  bool get isListening => _speechToText.isListening;

  Future<bool> startListening(Function(String) onResult) async {
    if (!_isSttInitialized) await _initStt();
    if (!_isSttInitialized) return false;

    if (!_speechToText.isListening) {
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
    return false;
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }
}
