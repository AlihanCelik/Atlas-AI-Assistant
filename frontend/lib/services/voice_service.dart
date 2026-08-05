import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sesli konuşma servisi — macOS native SFSpeechRecognizer + NSSpeechSynthesizer
class VoiceService extends ChangeNotifier {
  static const _channel = MethodChannel('com.atlas.atlasApp/voice');

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _permissionGranted = false;
  bool _initialized = false;
  double _soundLevel = 0.0;
  String _lastWords = '';

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isAvailable => _permissionGranted && _initialized;
  bool get permissionDenied => _initialized && !_permissionGranted;
  double get soundLevel => _soundLevel;
  String get lastWords => _lastWords;

  Future<void> initialize() async {
    if (_initialized) return;
    debugPrint('[Voice] İzinler kontrol ediliyor...');

    if (kIsWeb || !(Platform.isMacOS || Platform.isIOS)) {
      _initialized = true;
      _permissionGranted = true;
      notifyListeners();
      return;
    }

    try {
      final status = await _channel
          .invokeMethod<String>('requestPermissions')
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => 'authorized',
          );
      debugPrint('[Voice] İzin durumu: $status');
      _permissionGranted = status == 'authorized';
      _initialized = true;

      if (_permissionGranted) {
        _channel.setMethodCallHandler(_handleNativeCall);
      }
    } catch (e) {
      debugPrint('[Voice] İzin kontrolü uyarısı: $e');
      _initialized = true;
      _permissionGranted = true;
    }

    notifyListeners();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        final args = call.arguments as Map;
        final text = args['text'] as String? ?? '';
        final isFinal = args['final'] as bool? ?? false;
        _lastWords = text;
        if (isFinal) {
          _isListening = false;
          _soundLevel = 0.0;
        }
        notifyListeners();
        break;

      case 'onSoundLevel':
        final level = (call.arguments as num?)?.toDouble() ?? 0.0;
        _soundLevel = level.clamp(0.0, 1.0);
        notifyListeners();
        break;

      case 'onError':
        debugPrint('[Voice] STT hata: ${call.arguments}');
        _isListening = false;
        _soundLevel = 0.0;
        notifyListeners();
        break;
    }
  }

  // ─── Dinlemeye Başla ──────────────────────────────────────────
  Future<void> startListening({required Function(String) onResult}) async {
    if (!_permissionGranted) {
      await initialize();
      if (!_permissionGranted) return;
    }
    if (_isListening) return;

    _lastWords = '';
    _isListening = true;
    _soundLevel = 0.3;
    notifyListeners();

    debugPrint('[Voice] Dinleme başladı');

    try {
      final result = await _channel.invokeMethod<String>('startListening');
      debugPrint('[Voice] Sonuç: "$result"');

      _isListening = false;
      _soundLevel = 0.0;

      if (result != null && result.isNotEmpty) {
        _lastWords = result;
        onResult(result);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Voice] Dinleme hatası: $e');
      _isListening = false;
      _soundLevel = 0.0;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
    _isListening = false;
    _soundLevel = 0.0;
    notifyListeners();
  }

  // ─── TTS ──────────────────────────────────────────────────────
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    final clean = _cleanForSpeech(text);
    if (clean.isEmpty) return;

    _isSpeaking = true;
    notifyListeners();

    try {
      await _channel.invokeMethod('speak', clean);
      // NSSpeechSynthesizer async çalışır, bitmesini takip edemeyiz
      // Yaklaşık süre hesapla
      final words = clean.split(' ').length;
      final durationMs = (words / 2.5 * 1000).toInt().clamp(1000, 30000);
      await Future.delayed(Duration(milliseconds: durationMs));
    } catch (e) {
      debugPrint('[Voice] TTS hatası: $e');
    }

    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (_) {}
    _isSpeaking = false;
    notifyListeners();
  }

  String _cleanForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`[^`]+`'), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'\1')
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'[-•]\s'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'\1')
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  void dispose() {
    stopSpeaking();
    stopListening();
    super.dispose();
  }
}
