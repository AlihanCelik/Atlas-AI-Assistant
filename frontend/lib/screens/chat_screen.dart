import 'dart:math';
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
import '../widgets/cyber_telemetry_bar.dart';
import '../widgets/wake_word_overlay.dart';
import '../widgets/cyber_window.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _terminalScrollController = ScrollController();
  final GlobalKey _avatarKey = GlobalKey();

  Offset? _globalMousePosition;
  Offset? _avatarCenterOffset;
  bool _handsFreeActive = true;
  bool _showDrawerLogs = false;
  bool _showChatHistory = false;

  // Live Terminal Logs
  final List<String> _terminalLogs = [
    '> [SYSTEM] Atlas Neural Ambient Voice Engine v2.5 initialized.',
    '> [VAD] Hands-Free Wake-Word Detector armed: "Hey Atlas".',
    '> [NET] Connecting to WebSocket ws://localhost:8000/ws...',
    '> [AI] Ollama local language model ready.',
    '> [READY] Ambient mode active. Speak "Hey Atlas" or commands hands-free.',
  ];

  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _updateAvatarOffset();
      final atlas = context.read<AtlasService>();
      final voice = context.read<VoiceService>();

      await atlas.connect();
      await voice.initialize();

      // Listen to token stream for live background terminal log
      atlas.tokenStream.listen((token) {
        if (mounted && _terminalLogs.length < 250) {
          setState(() {
            if (_terminalLogs.isEmpty || !_terminalLogs.last.startsWith('> [LLAMA_STREAM]')) {
              _terminalLogs.add('> [LLAMA_STREAM] $token');
            } else {
              _terminalLogs[_terminalLogs.length - 1] += token;
            }
          });
        }
      });

      // Listen to backend wake word event ("Hey Atlas")
      atlas.addListener(() {
        if (atlas.isWakeWordActive && !voice.isListening && !voice.isSpeaking && !atlas.isStreaming) {
          _addLog('🎯 BACKEND WAKE WORD DETECTED ("Hey Atlas")');
          _triggerListening(atlas, voice);
        }
      });
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _terminalScrollController.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  void _updateAvatarOffset() {
    final renderBox = _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      final pos = renderBox.localToGlobal(Offset.zero);
      final center = Offset(
        pos.dx + renderBox.size.width / 2,
        pos.dy + renderBox.size.height / 2,
      );
      if (_avatarCenterOffset != center) {
        setState(() {
          _avatarCenterOffset = center;
        });
      }
    }
  }

  void _addLog(String text) {
    if (!mounted) return;
    setState(() {
      _terminalLogs.add('> [${DateTime.now().toString().substring(11, 19)}] $text');
    });
  }

  /// Mikrofon sadece kullanıcı "Hey Atlas" dediğinde veya mikrofon ikonuna tıkladığında açılır
  Future<void> _triggerListening(AtlasService atlas, VoiceService voice) async {
    if (voice.isListening || voice.isSpeaking || atlas.isStreaming) return;

    _addLog('Mikrofon aktif: Konuşmanız dinleniyor...');
    await voice.startListening(onResult: (text) async {
      if (text.trim().isEmpty) return;

      _addLog('SES ALGILANDI (STT): "$text"');
      await voice.stopSpeaking();
      await atlas.sendMessage(text);

      _waitAndSpeakResponse(atlas, voice);
    });
  }

  void _sendMessage(AtlasService atlas, VoiceService voice, String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    _addLog('USER TEXT PROMPT: "$text"');
    await voice.stopSpeaking();
    await atlas.sendMessage(text);
    _waitAndSpeakResponse(atlas, voice);
  }

  void _waitAndSpeakResponse(AtlasService atlas, VoiceService voice) async {
    // Wait for streaming to start
    int attempts = 0;
    while (!atlas.isStreaming && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // Wait for streaming to finish
    while (atlas.isStreaming) {
      await Future.delayed(const Duration(milliseconds: 150));
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (atlas.messages.isNotEmpty && mounted) {
      final last = atlas.messages.last;
      if (last.role == MessageRole.atlas && last.text.isNotEmpty) {
        _addLog('ATLAS SPEAKING: "${last.text.substring(0, min(50, last.text.length))}..."');
        await voice.speak(last.text);
        // Returns to Standby mode (MİKROFON: BEKLEMEDE)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtlasService, VoiceService>(
      builder: (context, atlas, voice, _) {
        return Scaffold(
          backgroundColor: AtlasColors.bg,
          body: MouseRegion(
            hitTestBehavior: HitTestBehavior.translucent,
            onHover: (e) {
              setState(() {
                _globalMousePosition = e.localPosition;
              });
            },
            onExit: (_) {
              setState(() {
                _globalMousePosition = null;
              });
            },
            child: Stack(
              children: [
                // ── 1. Continuous Matrix Code Rain & Grid Background ───────
                Positioned.fill(
                  child: GridBackground(
                    centerOffset: _avatarCenterOffset,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned.fill(
                  child: CodeRainWidget(
                    densityMultiplier: 1.4,
                    mousePosition: _globalMousePosition,
                    child: const SizedBox.expand(),
                  ),
                ),

              // ── 2. Minimalist Hands-Free Cyber Voice Assistant Screen ────
              SafeArea(
                child: Column(
                  children: [
                    // Top Cyber Status Header
                    _buildTopHeader(atlas, voice),

                    // Main Center Hero Section: Holographic Core Avatar & Voice Card
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Holographic Audio Avatar Core (Click to speak / silence)
                              GestureDetector(
                                onTap: () {
                                  if (voice.isSpeaking) {
                                    // Konuşuyorsa sus
                                    voice.stopSpeaking();
                                    _addLog('> [USER] Atlas susturuldu.');
                                  } else if (voice.isListening) {
                                    voice.stopListening();
                                  } else {
                                    _triggerListening(atlas, voice);
                                  }
                                },
                                child: Tooltip(
                                  message: voice.isSpeaking
                                      ? 'Susturmak için tıklayın'
                                      : voice.isListening
                                          ? 'Dinlemeyi durdurmak için tıklayın'
                                          : 'Konuşmak için tıklayın',
                                  child: AtlasAvatar(
                                    key: _avatarKey,
                                    isSpeaking: voice.isSpeaking || atlas.isStreaming,
                                    isListening: voice.isListening,
                                    soundLevel: voice.soundLevel,
                                    size: 240,
                                  ),
                                ),
                              )
                                  .animate()
                                  .scale(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1, 1),
                                    duration: 800.ms,
                                    curve: Curves.elasticOut,
                                  )
                                  .fadeIn(duration: 500.ms),

                              const SizedBox(height: 24),

                              // Ambient Voice Status Text
                              _buildVoiceStatusBanner(atlas, voice),

                              const SizedBox(height: 16),

                              // Live Ambient Audio Waveform Visualizer
                              _buildAudioWaveVisualizer(voice),

                              const SizedBox(height: 28),

                              // Minimal Floating Response Card (Only when chat has messages)
                              _buildLatestMessageBubble(atlas, voice),

                              const SizedBox(height: 20),

                              // Quick Hands-Free Action Tags
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  // Konuşurken büyük sustur butonu göster
                                  if (voice.isSpeaking)
                                    _CyberChip(
                                      icon: Icons.volume_off_rounded,
                                      label: '🔇 SUSTUR',
                                      color: const Color(0xFFFF5F57),
                                      onTap: () {
                                        voice.stopSpeaking();
                                        _addLog('> [USER] Atlas susturuldu.');
                                      },
                                    ),
                                  _CyberChip(
                                    icon: Icons.flash_on_rounded,
                                    label: '⚡ Test "Hey Atlas"',
                                    color: AtlasColors.neonGreen,
                                    onTap: () {
                                      _addLog('Manual "Hey Atlas" trigger.');
                                      _triggerListening(atlas, voice);
                                    },
                                  ),
                                  _CyberChip(
                                    icon: _handsFreeActive ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
                                    label: _handsFreeActive ? 'Eller Serbest: AÇIK' : 'Eller Serbest: KAPALI',
                                    color: _handsFreeActive ? AtlasColors.neonCyan : AtlasColors.textMuted,
                                    onTap: () {
                                      setState(() {
                                        _handsFreeActive = !_handsFreeActive;
                                      });
                                      _addLog('Hands-free mode: ${_handsFreeActive ? 'ENABLED' : 'DISABLED'}');
                                    },
                                  ),
                                  _CyberChip(
                                    icon: Icons.terminal_rounded,
                                    label: '🖥️ Terminal Logları',
                                    color: AtlasColors.neonPurple,
                                    onTap: () {
                                      setState(() => _showDrawerLogs = !_showDrawerLogs);
                                    },
                                  ),
                                  _CyberChip(
                                    icon: Icons.history_rounded,
                                    label: '💬 Geçmiş',
                                    color: const Color(0xFFF59E0B),
                                    onTap: () {
                                      setState(() => _showChatHistory = !_showChatHistory);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Floating Cyber Command Input Bar
                    _buildBottomPromptBar(atlas, voice),

                    // Bottom Live Telemetry Banner Ticker
                    CyberTelemetryBar(
                      isConnected: atlas.isConnected,
                      isListening: voice.isListening,
                      isSpeaking: voice.isSpeaking || atlas.isStreaming,
                      modelName: atlas.currentModel,
                    ),
                  ],
                ),
              ),

              // ── 3. Toggleable Floating Terminal Log Overlay Window ──────
              if (_showDrawerLogs)
                CyberWindow(
                  title: 'terminal_telemetry.log',
                  icon: Icons.terminal_rounded,
                  accentColor: AtlasColors.neonGreen,
                  initialPosition: const Offset(100, 60),
                  width: 540,
                  height: 440,
                  onClose: () => setState(() => _showDrawerLogs = false),
                  child: _buildTerminalWindowBody(),
                ),

              // ── 4. Toggleable Chat History Window ────────────────────────
              if (_showChatHistory)
                CyberWindow(
                  title: 'conversation_history.json',
                  icon: Icons.history_rounded,
                  accentColor: AtlasColors.neonCyan,
                  initialPosition: const Offset(160, 80),
                  width: 480,
                  height: 480,
                  onClose: () => setState(() => _showChatHistory = false),
                  child: _buildChatHistoryWindowBody(atlas),
                ),

              // Wake Word Overlay Ring Banner
              if (atlas.isWakeWordActive)
                const Positioned.fill(
                  child: WakeWordOverlay(),
                ),
            ],
          ),
        ),
      );
    },
  );
}

  // ─── 1. Top Cyber Status Header ─────────────────────────────────────
  Widget _buildTopHeader(AtlasService atlas, VoiceService voice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF080916).withOpacity(0.88),
        border: Border(
          bottom: BorderSide(
            color: AtlasColors.neonPurple.withOpacity(0.18),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Atlas Cyber Logo
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AtlasColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AtlasColors.neonPurple.withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/ai_core_logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),

            const Text(
              'ATLAS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(width: 8),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AtlasColors.neonPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AtlasColors.neonPurple.withOpacity(0.4)),
              ),
              child: const Text(
                'HANDS-FREE AMBIENT AI',
                style: TextStyle(
                  color: AtlasColors.neonPurple,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Hands Free Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: voice.isListening
                    ? AtlasColors.neonGreen.withOpacity(0.15)
                    : AtlasColors.textMuted.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: voice.isListening
                      ? AtlasColors.neonGreen.withOpacity(0.4)
                      : AtlasColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    voice.isListening ? Icons.graphic_eq_rounded : Icons.mic_off_rounded,
                    size: 13,
                    color: voice.isListening ? AtlasColors.neonGreen : AtlasColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    voice.isListening ? 'MİKROFON: DİNLİYOR (AKTİF)' : 'MİKROFON: BEKLEMEDE',
                    style: TextStyle(
                      color: voice.isListening ? AtlasColors.neonGreen : AtlasColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Model Selector Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AtlasColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AtlasColors.neonCyan.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: atlas.currentModel,
                  dropdownColor: AtlasColors.surfaceElevated,
                  isDense: true,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  items: AtlasService.availableModels.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (m) {
                    if (m != null) atlas.changeModel(m);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Ambient Voice Status Banner ─────────────────────────────────
  Widget _buildVoiceStatusBanner(AtlasService atlas, VoiceService voice) {
    String mainText = 'Konuşmak İçin Logoya Tıklayın';
    String subText = 'Mikrofon kapalıdır. Tıkladığınızda 1 soru için açılır.';
    Color mainColor = AtlasColors.neonCyan;

    if (voice.isListening) {
      mainText = 'Seni Dinliyorum...';
      subText = 'Sesiniz algılanıyor';
      mainColor = AtlasColors.neonGreen;
    } else if (voice.isSpeaking) {
      mainText = 'Atlas Cevap Veriyor...';
      subText = 'Sesli yanıt veriliyor';
      mainColor = AtlasColors.neonPurple;
    } else if (atlas.isStreaming) {
      mainText = 'Düşünüyorum...';
      subText = 'Nöral model yanıt üretiyor';
      mainColor = AtlasColors.neonPink;
    }

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            mainText,
            key: ValueKey(mainText),
            style: TextStyle(
              color: mainColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: mainColor.withOpacity(0.5),
                  blurRadius: 16,
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subText,
          style: TextStyle(
            color: AtlasColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ─── 3. Live Ambient Audio Waveform Visualizer ──────────────────────
  Widget _buildAudioWaveVisualizer(VoiceService voice) {
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, __) {
        return SizedBox(
          height: 28,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(16, (i) {
              final baseVal = sin((i / 16) * pi) * 0.8 + 0.2;
              final dynamicFactor = voice.isListening
                  ? max(0.2, voice.soundLevel * 1.8 * (0.5 + 0.5 * sin(_waveCtrl.value * pi * 2 + i)))
                  : (0.15 + 0.15 * sin(_waveCtrl.value * pi * 2 + i * 0.4));
              final barHeight = (24.0 * baseVal * dynamicFactor).clamp(4.0, 26.0);

              return Container(
                width: 3.5,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: voice.isListening
                      ? AtlasColors.neonGreen
                      : voice.isSpeaking
                          ? AtlasColors.neonPurple
                          : AtlasColors.neonCyan.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: voice.isListening
                          ? AtlasColors.neonGreen.withOpacity(0.6)
                          : AtlasColors.neonCyan.withOpacity(0.3),
                      blurRadius: 6,
                    )
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ─── 4. Minimal Floating Response Card ──────────────────────────────
  Widget _buildLatestMessageBubble(AtlasService atlas, VoiceService voice) {
    final atlasMessages = atlas.messages.where((m) => m.role == MessageRole.atlas).toList();
    if (atlasMessages.isEmpty) return const SizedBox.shrink();

    final last = atlasMessages.last;
    final text = last.isLoading ? null : last.text;

    return Container(
      constraints: BoxConstraints(
        maxWidth: min(MediaQuery.of(context).size.width * 0.65, 580),
        minWidth: 120,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E20).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: voice.isSpeaking
              ? AtlasColors.neonPurple.withOpacity(0.5)
              : AtlasColors.neonCyan.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: voice.isSpeaking
                ? AtlasColors.neonPurple.withOpacity(0.18)
                : AtlasColors.neonCyan.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: text == null || text.isEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AtlasColors.neonCyan),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Düşünüyor...',
                  style: TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            )
          : Text(
              text.length > 320 ? '${text.substring(0, 320)}...' : text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  // ─── 5. Bottom Floating Cyber Command Bar ────────────────────────────
  Widget _buildBottomPromptBar(AtlasService atlas, VoiceService voice) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF090B1A).withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AtlasColors.neonPurple.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AtlasColors.neonPurple.withOpacity(0.1),
            blurRadius: 16,
          )
        ],
      ),
      child: Row(
        children: [
          const Text(
            '> ',
            style: TextStyle(
              color: AtlasColors.neonGreen,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'Yazılı komut girin (örn: /clear, /status veya soru)...',
                hintStyle: TextStyle(color: AtlasColors.textMuted, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (t) => _sendMessage(atlas, voice, t),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 16, color: AtlasColors.neonCyan),
            onPressed: () => _sendMessage(atlas, voice, _inputController.text),
          ),
        ],
      ),
    );
  }

  // ─── Window Body: Terminal Logs Drawer ──────────────────────────────
  Widget _buildTerminalWindowBody() {
    return Container(
      color: const Color(0xFF060711),
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        controller: _terminalScrollController,
        itemCount: _terminalLogs.length,
        itemBuilder: (ctx, i) {
          final log = _terminalLogs[i];
          Color color = AtlasColors.neonGreen;
          if (log.contains('[ERROR]')) color = const Color(0xFFFF5F57);
          if (log.contains('STT')) color = AtlasColors.neonCyan;
          if (log.contains('[LLAMA_STREAM]')) color = AtlasColors.neonPurple;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Text(
              log,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Window Body: Chat History Drawer ───────────────────────────────
  Widget _buildChatHistoryWindowBody(AtlasService atlas) {
    if (atlas.messages.isEmpty) {
      return Center(
        child: Text(
          'Henüz konuşma geçmişi yok',
          style: TextStyle(color: AtlasColors.textSecondary, fontSize: 12, fontFamily: 'monospace'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: atlas.messages.length,
      itemBuilder: (_, i) => MessageBubble(message: atlas.messages[i]),
    );
  }
}

// ─── Cyber Chip Helper ───────────────────────────────────────────────
class _CyberChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CyberChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
