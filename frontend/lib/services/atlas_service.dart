import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

/// Atlas Backend ile iletişim servisi
class AtlasService extends ChangeNotifier {
  static const String _baseUrl = 'http://localhost:8000';
  static const String _wsUrl = 'ws://localhost:8000/ws';

  static const List<String> availableModels = [
    'llama3.2:3b',
    'llama3.1:8b',
    'qwen2:1.5b',
    'mistral:7b',
    'phi3:mini',
  ];

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isStreaming = false;
  bool _isWakeWordActive = false;
  String _currentModel = 'llama3.2:3b';

  String get currentModel => _currentModel;

  // Mesaj geçmişi
  final List<ChatMessage> messages = [];

  // Stream kontrolü
  String _streamingBuffer = '';
  final StreamController<String> _tokenController = StreamController<String>.broadcast();

  bool get isConnected => _isConnected;
  bool get isStreaming => _isStreaming;
  bool get isWakeWordActive => _isWakeWordActive;
  Stream<String> get tokenStream => _tokenController.stream;

  // ─── WebSocket Bağlantısı ─────────────────────────────────────
  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnect,
      );

      notifyListeners();
      debugPrint('[Atlas] WebSocket bağlandı.');
    } catch (e) {
      _isConnected = false;
      debugPrint('[Atlas] Bağlantı hatası: $e');
      notifyListeners();
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }

  // ─── Mesaj Gönder ─────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Kullanıcı mesajını ekle
    messages.add(ChatMessage(role: MessageRole.user, text: text));

    // Atlas cevabı için placeholder
    messages.add(ChatMessage(role: MessageRole.atlas, text: '', isLoading: true));
    notifyListeners();

    _streamingBuffer = '';
    _isStreaming = true;

    if (_isConnected && _channel != null) {
      // WebSocket ile gönder (streaming)
      _channel!.sink.add(json.encode({
        'type': 'chat',
        'message': text,
      }));
    } else {
      // Fallback: REST API
      await _sendViaRest(text);
    }
  }

  Future<void> _sendViaRest(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _finishStreaming(data['response']);
      } else {
        _finishStreaming('Hata: ${response.statusCode}');
      }
    } catch (e) {
      _finishStreaming('Backend\'e bağlanılamadı. Sunucunun çalıştığından emin olun.');
    }
  }

  // ─── WS Mesaj İşleme ──────────────────────────────────────────
  void _onMessage(dynamic data) {
    final payload = json.decode(data as String);
    final type = payload['type'] as String;

    switch (type) {
      case 'stream_start':
        _streamingBuffer = '';
        break;

      case 'stream_token':
        final token = payload['token'] as String;
        _streamingBuffer += token;
        _tokenController.add(token);

        // Son mesajı güncelle
        if (messages.isNotEmpty && messages.last.role == MessageRole.atlas) {
          messages.last = ChatMessage(
            role: MessageRole.atlas,
            text: _streamingBuffer,
            isLoading: false,
          );
          notifyListeners();
        }
        break;

      case 'stream_end':
        _finishStreaming(payload['full_response'] as String);
        break;

      case 'wake_word':
        _isWakeWordActive = true;
        notifyListeners();
        // 3 saniye sonra kapat
        Future.delayed(const Duration(seconds: 3), () {
          _isWakeWordActive = false;
          notifyListeners();
        });
        break;

      case 'error':
        _finishStreaming('⚠️ ${payload['message']}');
        break;

      case 'reset_ok':
        messages.clear();
        notifyListeners();
        break;
    }
  }

  void _finishStreaming(String fullText) {
    _isStreaming = false;
    if (messages.isNotEmpty && messages.last.role == MessageRole.atlas) {
      messages.last = ChatMessage(
        role: MessageRole.atlas,
        text: fullText,
        isLoading: false,
      );
    }
    notifyListeners();
  }

  void _onError(dynamic error) {
    debugPrint('[Atlas] WS Hata: $error');
    _isConnected = false;
    notifyListeners();
  }

  void _onDisconnect() {
    debugPrint('[Atlas] WS bağlantısı kesildi.');
    _isConnected = false;
    notifyListeners();
  }

  // ─── Konuşmayı Sıfırla ────────────────────────────────────────
  void resetConversation() {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(json.encode({'type': 'reset'}));
    } else {
      messages.clear();
      notifyListeners();
    }
  }

  // ─── Backend Durumu ───────────────────────────────────────────
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/status'))
          .timeout(const Duration(seconds: 3));
      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'status': 'offline', 'ollama_running': false};
    }
  }

  Future<void> changeModel(String modelName) async {
    try {
      await http.post(Uri.parse('$_baseUrl/model/$modelName'));
      _currentModel = modelName;
      notifyListeners();
    } catch (e) {
      debugPrint('[Atlas] Model değiştirilemedi: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    _tokenController.close();
    super.dispose();
  }
}

// ─── Veri Modelleri ───────────────────────────────────────────────
enum MessageRole { user, atlas }

class ChatMessage {
  final MessageRole role;
  String text;
  final bool isLoading;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    this.isLoading = false,
  }) : timestamp = DateTime.now();
}
