import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  Completer<void>? _speakCompleter;

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
      _channel.setMethodCallHandler(_handleNativeCall);
      final status = await _channel.invokeMethod<String>('requestPermissions');
      debugPrint('[Voice] İzin durumu: $status');
      _permissionGranted = true;
      _initialized = true;
    } catch (e) {
      debugPrint('[Voice] İzin kontrolü uyarısı: $e');
      _initialized = true;
      _permissionGranted = true;
    }

    notifyListeners();
  }

  void Function(String)? _onResultCallback;

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        if (call.arguments is Map) {
          final args = call.arguments as Map;
          final text = args['text']?.toString() ?? '';
          final isFinal = args['final'] == true;
          _lastWords = text;
          if (isFinal) {
            _isListening = false;
            _soundLevel = 0.0;
            final cb = _onResultCallback;
            _onResultCallback = null;
            if (cb != null) {
              cb(text);
            }
          }
          notifyListeners();
        }
        break;

      case 'onSoundLevel':
        final level = (call.arguments as num?)?.toDouble() ?? 0.0;
        _soundLevel = level.clamp(0.0, 1.0);
        notifyListeners();
        break;

      case 'onSpeakFinished':
        _isSpeaking = false;
        if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
          _speakCompleter!.complete();
        }
        notifyListeners();
        break;

      case 'onError':
        debugPrint('[Voice] STT hata: ${call.arguments}');
        _isListening = false;
        _soundLevel = 0.0;
        _onResultCallback = null;
        notifyListeners();
        break;
    }
  }

  // ─── Dinlemeye Başla ──────────────────────────────────────────
  Future<void> startListening({required void Function(String) onResult}) async {
    if (!_permissionGranted) {
      await initialize();
    }
    if (_isListening) {
      await stopListening();
    }

    _lastWords = '';
    _isListening = true;
    _soundLevel = 0.2;
    _onResultCallback = onResult;
    notifyListeners();

    debugPrint('[Voice] Dinleme anında başladı');

    try {
      await _channel.invokeMethod('startListening');
    } catch (e) {
      debugPrint('[Voice] Dinleme başlatma hatası: $e');
      _isListening = false;
      _soundLevel = 0.0;
      _onResultCallback = null;
      notifyListeners();
      onResult('');
    }
  }

  Future<void> stopListening() async {
    _onResultCallback = null;
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

    _speakCompleter = Completer<void>();

    try {
      await _channel.invokeMethod('speak', clean);
      // Wait for native didFinish callback with length-based fallback timeout
      final words = clean.split(' ').length;
      final maxDurationMs = (words / 1.5 * 1000).toInt().clamp(2000, 45000);

      await _speakCompleter!.future.timeout(
        Duration(milliseconds: maxDurationMs),
        onTimeout: () {
          debugPrint('[Voice] TTS speak timeout fallback');
        },
      );
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
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
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
