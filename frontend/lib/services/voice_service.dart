import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Sesli konuşma servisi
/// - speech_to_text  → mikrofon → metin
/// - macOS `say`     → metin → ses (TTS)
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  bool _sttAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _permissionDenied = false;
  String _lastWords = '';
  double _soundLevel = 0.0;
  Process? _sayProcess;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isAvailable => _sttAvailable;
  bool get permissionDenied => _permissionDenied;
  String get lastWords => _lastWords;
  double get soundLevel => _soundLevel;

  /// Başlangıçta initialize — izin iste
  Future<void> initialize() async {
    debugPrint('[Voice] STT initialize başlıyor...');
    try {
      _sttAvailable = await _stt.initialize(
        onStatus: _onSttStatus,
        onError: (e) {
          debugPrint('[Voice] STT hata: ${e.errorMsg} | permanent: ${e.permanent}');
          if (e.permanent) {
            _permissionDenied = true;
            notifyListeners();
          }
        },
        debugLogging: true,
      );
      debugPrint('[Voice] STT hazır: $_sttAvailable');

      if (_sttAvailable) {
        // Mevcut locale'leri listele
        final locales = await _stt.locales();
        debugPrint('[Voice] Mevcut diller: ${locales.map((l) => l.localeId).join(', ')}');
      }
    } catch (e) {
      debugPrint('[Voice] initialize hatası: $e');
      _sttAvailable = false;
    }
    notifyListeners();
  }

  // ─── Mikrofon Dinle ────────────────────────────────────────────
  Future<void> startListening({required Function(String) onResult}) async {
    if (!_sttAvailable) {
      debugPrint('[Voice] STT hazır değil, tekrar initialize deneniyor...');
      await initialize();
      if (!_sttAvailable) return;
    }

    if (_isListening) return;

    _lastWords = '';
    _isListening = true;
    notifyListeners();

    debugPrint('[Voice] Dinleme başladı');

    // Türkçe varsa kullan, yoksa varsayılan
    final locales = await _stt.locales();
    final hasTr = locales.any((l) => l.localeId.startsWith('tr'));
    final locale = hasTr ? 'tr_TR' : '';
    debugPrint('[Voice] Kullanılan locale: ${locale.isEmpty ? "varsayılan" : locale}');

    await _stt.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        debugPrint('[Voice] Tanınan: "$_lastWords" | final: ${result.finalResult}');
        notifyListeners();

        if (result.finalResult && _lastWords.isNotEmpty) {
          onResult(_lastWords);
          stopListening();
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 2),
      localeId: hasTr ? 'tr_TR' : null,
      listenMode: ListenMode.confirmation,
      onSoundLevelChange: (level) {
        _soundLevel = ((level + 2.0) / 12.0).clamp(0.0, 1.0);
        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
    _soundLevel = 0.0;
    notifyListeners();
    debugPrint('[Voice] Dinleme durduruldu');
  }

  void _onSttStatus(String status) {
    debugPrint('[Voice] STT durum: $status');
    if (status == 'done' || status == 'notListening') {
      if (_isListening) {
        _isListening = false;
        _soundLevel = 0.0;
        notifyListeners();
      }
    }
  }

  // ─── TTS (macOS say komutu) ────────────────────────────────────
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await stopSpeaking();

    final clean = _cleanForSpeech(text);
    if (clean.isEmpty) return;

    _isSpeaking = true;
    notifyListeners();
    debugPrint('[Voice] TTS başlıyor: "${clean.substring(0, clean.length.clamp(0, 50))}..."');

    // Mevcut Türkçe sesleri dene
    final voices = ['Yelda', 'Siri', 'Samantha'];
    bool started = false;

    for (final voice in voices) {
      try {
        _sayProcess = await Process.start('say', ['-v', voice, '-r', '175', clean]);
        started = true;
        debugPrint('[Voice] TTS sesi: $voice');
        break;
      } catch (_) {
        continue;
      }
    }

    if (!started) {
      try {
        _sayProcess = await Process.start('say', ['-r', '175', clean]);
      } catch (e) {
        debugPrint('[Voice] TTS başlatılamadı: $e');
        _isSpeaking = false;
        notifyListeners();
        return;
      }
    }

    _sayProcess!.exitCode.then((_) {
      _isSpeaking = false;
      _sayProcess = null;
      notifyListeners();
      debugPrint('[Voice] TTS tamamlandı');
    });
  }

  Future<void> stopSpeaking() async {
    if (_sayProcess != null) {
      _sayProcess!.kill();
      _sayProcess = null;
    }
    if (_isSpeaking) {
      _isSpeaking = false;
      notifyListeners();
    }
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
    _stt.cancel();
    _sayProcess?.kill();
    super.dispose();
  }
}
