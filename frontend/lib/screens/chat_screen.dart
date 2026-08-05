import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/atlas_service.dart';
import '../services/voice_service.dart';
import '../theme/atlas_theme.dart';
import '../widgets/atlas_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/code_rain_painter.dart';
import '../widgets/grid_painter.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // Chat geçmişi overlay
  bool _showChatHistory = false;

  // Son yanıt balon animasyonu
  late AnimationController _responseCtrl;

  @override
  void initState() {
    super.initState();

    _responseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final atlas = context.read<AtlasService>();
      final voice = context.read<VoiceService>();
      await atlas.connect();
      await voice.initialize();
    });
  }

  /// Mikrofona bas → dinle → Atlas'a gönder → yanıt gelince sesli oku
  Future<void> _onMicPressed() async {
    final atlas = context.read<AtlasService>();
    final voice = context.read<VoiceService>();

    if (voice.isListening) {
      await voice.stopListening();
      return;
    }

    if (atlas.isStreaming || voice.isSpeaking) return;

    // İzin reddedildiyse kullanıcıya göster
    if (voice.permissionDenied) {
      _showPermissionDialog();
      return;
    }

    // STT hazır değilse tekrar dene
    if (!voice.isAvailable) {
      await voice.initialize();
      if (!voice.isAvailable) {
        _showPermissionDialog();
        return;
      }
    }

    // TTS'i durdur
    await voice.stopSpeaking();

    await voice.startListening(onResult: (text) async {
      if (text.isEmpty) return;
      await atlas.sendMessage(text);
      _waitAndSpeak(atlas, voice);
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AtlasColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mic_off_rounded, color: AtlasColors.neonPink, size: 20),
            const SizedBox(width: 8),
            const Text('Mikrofon İzni',
                style: TextStyle(color: AtlasColors.textPrimary, fontSize: 15)),
          ],
        ),
        content: const Text(
          'Mikrofon erişimi reddedildi.\n\n'
          'Sistem Ayarları → Gizlilik ve Güvenlik → Mikrofon\n'
          'bölümünden atlas_app için izni açın.',
          style: TextStyle(
            color: AtlasColors.textSecondary,
            fontSize: 13,
            height: 1.6,
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tamam',
                style: TextStyle(color: AtlasColors.neonCyan)),
          ),
        ],
      ),
    );
  }

  void _waitAndSpeak(AtlasService atlas, VoiceService voice) {
    // Streaming bitince son mesajı oku
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      return atlas.isStreaming; // streaming bitene kadar bekle
    }).then((_) {
      if (atlas.messages.isNotEmpty) {
        final last = atlas.messages.last;
        if (last.role == MessageRole.atlas && last.text.isNotEmpty) {
          voice.speak(last.text);
          _responseCtrl.forward(from: 0);
        }
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtlasService, VoiceService>(
      builder: (context, atlas, voice, _) {
        return Scaffold(
          backgroundColor: AtlasColors.bg,
          body: Stack(
            children: [
              // ── Arka plan ──────────────────────────────────
              Positioned.fill(
                child: GridBackground(child: const SizedBox.expand()),
              ),
              Positioned.fill(
                child: CodeRainWidget(child: const SizedBox.expand()),
              ),

              // ── Ana içerik ─────────────────────────────────
              SafeArea(
                child: Row(
                  children: [
                    _buildSidebar(atlas, voice),
                    Expanded(child: _buildMainArea(atlas, voice)),
                  ],
                ),
              ),

              // ── Chat geçmişi overlay ───────────────────────
              if (_showChatHistory)
                _ChatHistoryOverlay(
                  atlas: atlas,
                  scrollController: _scrollController,
                  onClose: () => setState(() => _showChatHistory = false),
                ).animate().fadeIn(duration: 200.ms).slideX(
                      begin: -0.05,
                      end: 0,
                      duration: 250.ms,
                      curve: Curves.easeOut,
                    ),
            ],
          ),
        );
      },
    );
  }

  // ─── Sol Sidebar ───────────────────────────────────────────────
  Widget _buildSidebar(AtlasService atlas, VoiceService voice) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: AtlasColors.surface.withOpacity(0.85),
        border: Border(
          right: BorderSide(
            color: AtlasColors.neonPurple.withOpacity(0.12),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),

          // Logo
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AtlasColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AtlasColors.neonPurple.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _divider(),
          const SizedBox(height: 16),

          // Chat geçmişi butonu
          _SideBtn(
            icon: Icons.history_rounded,
            tooltip: 'Konuşma Geçmişi',
            color: AtlasColors.neonCyan,
            active: _showChatHistory,
            badge: atlas.messages.isNotEmpty
                ? '${(atlas.messages.length / 2).ceil()}'
                : null,
            onTap: () {
              setState(() => _showChatHistory = !_showChatHistory);
              if (_showChatHistory) _scrollToBottom();
            },
          ),

          const SizedBox(height: 10),

          // Yeni konuşma
          _SideBtn(
            icon: Icons.refresh_rounded,
            tooltip: 'Yeni Konuşma',
            color: AtlasColors.neonGreen,
            onTap: () {
              atlas.resetConversation();
              voice.stopSpeaking();
            },
          ),

          const SizedBox(height: 10),

          // TTS durdur
          if (voice.isSpeaking)
            _SideBtn(
              icon: Icons.stop_rounded,
              tooltip: 'Sesi Durdur',
              color: AtlasColors.neonPink,
              active: true,
              onTap: () => voice.stopSpeaking(),
            ).animate().fadeIn(duration: 200.ms),

          const Spacer(),

          // Bağlantı durumu
          _StatusDot(connected: atlas.isConnected),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 30,
        height: 1,
        color: AtlasColors.border,
      );

  // ─── Ana Alan ──────────────────────────────────────────────────
  Widget _buildMainArea(AtlasService atlas, VoiceService voice) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Atlas Avatar ───────────────────────────
                AtlasAvatar(
                  isSpeaking: voice.isSpeaking || atlas.isStreaming,
                  isListening: voice.isListening,
                  soundLevel: voice.soundLevel,
                  size: 220,
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      duration: 800.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 28),

                // ── Durum metni ────────────────────────────
                _StatusText(atlas: atlas, voice: voice),

                const SizedBox(height: 36),

                // ── Son yanıt balonu ───────────────────────
                _LastResponseBubble(atlas: atlas, voice: voice),

                const SizedBox(height: 40),

                // ── Mikrofon butonu ────────────────────────
                _MicButton(
                  isListening: voice.isListening,
                  isSpeaking: voice.isSpeaking || atlas.isStreaming,
                  soundLevel: voice.soundLevel,
                  onPressed: _onMicPressed,
                )
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0, delay: 700.ms),

                const SizedBox(height: 16),

                // Kısa ipucu
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: voice.isListening ? 0.0 : 0.5,
                  child: Text(
                    voice.isAvailable
                        ? 'mikrofona bas ve konuş'
                        : 'mikrofon erişimi gerekiyor',
                    style: const TextStyle(
                      color: AtlasColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _responseCtrl.dispose();
    super.dispose();
  }
}

// ─── Durum metni widget ────────────────────────────────────────────
class _StatusText extends StatelessWidget {
  final AtlasService atlas;
  final VoiceService voice;

  const _StatusText({required this.atlas, required this.voice});

  String get _label {
    if (voice.isListening) return 'Seni dinliyorum...';
    if (voice.isSpeaking) return 'Konuşuyorum...';
    if (atlas.isStreaming) return 'Düşünüyorum...';
    if (atlas.messages.isEmpty) return 'Merhaba, ben Atlas!';
    return 'Ne sormak istersin?';
  }

  Color get _color {
    if (voice.isListening) return AtlasColors.neonGreen;
    if (voice.isSpeaking) return AtlasColors.neonCyan;
    if (atlas.isStreaming) return AtlasColors.neonPurple;
    return AtlasColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        _label,
        key: ValueKey(_label),
        style: TextStyle(
          color: _color,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Son yanıt balonu ─────────────────────────────────────────────
class _LastResponseBubble extends StatelessWidget {
  final AtlasService atlas;
  final VoiceService voice;

  const _LastResponseBubble({required this.atlas, required this.voice});

  @override
  Widget build(BuildContext context) {
    // Son Atlas mesajını bul
    final atlasMessages =
        atlas.messages.where((m) => m.role == MessageRole.atlas).toList();

    if (atlasMessages.isEmpty) return const SizedBox.shrink();

    final last = atlasMessages.last;
    final text = last.isLoading ? null : last.text;

    if (text == null || text.isEmpty) {
      return _buildBubble(
        context,
        child: const _TypingDots(),
      );
    }

    // Uzun metni kısalt (sesli moda sığsın)
    final display = text.length > 280 ? '${text.substring(0, 280)}...' : text;

    return _buildBubble(
      context,
      child: Text(
        display,
        style: const TextStyle(
          color: AtlasColors.textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildBubble(BuildContext context, {required Widget child}) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.55,
        minWidth: 80,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AtlasColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: voice.isSpeaking
              ? AtlasColors.neonCyan.withOpacity(0.4)
              : AtlasColors.neonPurple.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: voice.isSpeaking
                ? AtlasColors.neonCyan.withOpacity(0.12)
                : AtlasColors.neonPurple.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Mikrofon Butonu ──────────────────────────────────────────────
class _MicButton extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final double soundLevel;
  final VoidCallback onPressed;

  const _MicButton({
    required this.isListening,
    required this.isSpeaking,
    required this.soundLevel,
    required this.onPressed,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  bool _isHover = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ses seviyesine göre dış halka boyutu
    final ringSize = 88.0 + widget.soundLevel * 24.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHover = true),
      onExit: (_) => setState(() => _isHover = false),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _pressCtrl,
          builder: (_, __) {
            final scale = 1.0 - _pressCtrl.value * 0.06;
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dış ses halkası
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: widget.isListening ? ringSize : 0,
                      height: widget.isListening ? ringSize : 0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AtlasColors.neonGreen.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Buton gövdesi
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.isListening
                            ? const LinearGradient(
                                colors: [
                                  AtlasColors.neonGreen,
                                  Color(0xFF065F46),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : widget.isSpeaking
                                ? LinearGradient(colors: [
                                    AtlasColors.neonPurple.withOpacity(0.4),
                                    AtlasColors.neonCyan.withOpacity(0.4),
                                  ])
                                : _isHover
                                    ? AtlasColors.primaryGradient
                                    : LinearGradient(colors: [
                                        AtlasColors.neonPurple.withOpacity(0.7),
                                        AtlasColors.neonCyan.withOpacity(0.7),
                                      ]),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isListening
                                ? AtlasColors.neonGreen.withOpacity(0.5)
                                : AtlasColors.neonPurple
                                    .withOpacity(_isHover ? 0.6 : 0.35),
                            blurRadius: _isHover ? 24 : 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isListening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Chat Geçmişi Overlay ─────────────────────────────────────────
class _ChatHistoryOverlay extends StatelessWidget {
  final AtlasService atlas;
  final ScrollController scrollController;
  final VoidCallback onClose;

  const _ChatHistoryOverlay({
    required this.atlas,
    required this.scrollController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 60,
      top: 0,
      bottom: 0,
      width: 420,
      child: Container(
        decoration: BoxDecoration(
          color: AtlasColors.bg.withOpacity(0.97),
          border: Border(
            right: BorderSide(
              color: AtlasColors.neonCyan.withOpacity(0.15),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(10, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AtlasColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: AtlasColors.neonCyan.withOpacity(0.12),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: AtlasColors.neonCyan, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Konuşma Geçmişi',
                    style: TextStyle(
                      color: AtlasColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AtlasColors.textSecondary, size: 18),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),

            // Mesajlar
            Expanded(
              child: atlas.messages.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz konuşma yok',
                        style: TextStyle(
                          color: AtlasColors.textSecondary,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: atlas.messages.length,
                      itemBuilder: (_, i) =>
                          MessageBubble(message: atlas.messages[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Yardımcı ─────────────────────────────────────────────────────
class _SideBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool active;
  final String? badge;
  final VoidCallback onTap;

  const _SideBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.active = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: active
                    ? Border.all(color: color.withOpacity(0.35), width: 1)
                    : null,
              ),
              child: Icon(
                icon,
                size: 20,
                color: active ? color : AtlasColors.textSecondary,
              ),
            ),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool connected;

  const _StatusDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: connected ? 'Backend bağlı' : 'Backend bağlı değil',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: connected ? AtlasColors.neonGreen : const Color(0xFFF87171),
          boxShadow: connected
              ? [
                  BoxShadow(
                    color: AtlasColors.neonGreen.withOpacity(0.8),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      )..repeat(
          reverse: true,
          period: Duration(milliseconds: 500 + i * 160),
        ),
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, __) => Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                AtlasColors.neonPurple,
                AtlasColors.neonCyan,
                _ctrls[i].value,
              ),
              boxShadow: [
                BoxShadow(
                  color: AtlasColors.neonCyan
                      .withOpacity(_ctrls[i].value * 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
