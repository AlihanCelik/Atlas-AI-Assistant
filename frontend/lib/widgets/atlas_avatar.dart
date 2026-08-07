import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/atlas_theme.dart';

/// 3D Holographic AI Core Emblem Avatar
class AtlasAvatar extends StatefulWidget {
  final bool isSpeaking;
  final bool isListening;
  final double soundLevel;
  final double size;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  const AtlasAvatar({
    super.key,
    this.isSpeaking = false,
    this.isListening = false,
    this.soundLevel = 0.0,
    this.size = 200,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  State<AtlasAvatar> createState() => _AtlasAvatarState();
}

class _AtlasAvatarState extends State<AtlasAvatar> with TickerProviderStateMixin {
  late AnimationController _idleCtrl;
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final active = widget.isListening || widget.isSpeaking;
    final level = widget.soundLevel.clamp(0.0, 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPressStart: widget.onLongPressStart,
        onLongPressEnd: widget.onLongPressEnd,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Logo Etrafındaki Halkalar (Pulsing Sonar Rings around logo) ────────
              AnimatedBuilder(
                animation: _ringCtrl,
                builder: (_, __) {
                  return CustomPaint(
                    size: Size(s, s),
                    painter: _AvatarRingsPainter(
                      progress: _ringCtrl.value,
                      isListening: widget.isListening,
                      isSpeaking: widget.isSpeaking,
                      soundLevel: level,
                    ),
                  );
                },
              ),

              // ── Ses Dalgası (Equalizer Bars) ──────────────────────
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: active ? 1.0 : 0.2,
                child: SizedBox(
                  width: s * 0.76,
                  height: s * 0.76,
                  child: _EqualizerRing(
                    color: widget.isListening
                        ? AtlasColors.neonGreen
                        : AtlasColors.neonCyan,
                    barCount: 9,
                    intensity: active ? (0.4 + level * 0.6) : 0.0,
                  ),
                ),
              ),

              // ── Ana 3D Yapay Zeka Çekirdek Logosu ───────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: s * 0.52,
                height: s * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.isListening
                        ? [AtlasColors.neonGreen, const Color(0xFF064E3B)]
                        : widget.isSpeaking
                            ? [AtlasColors.neonCyan, AtlasColors.neonPurple]
                            : [AtlasColors.neonPurple, const Color(0xFF5B21B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isListening
                              ? AtlasColors.neonGreen
                              : AtlasColors.neonPurple)
                          .withOpacity(0.7),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: ClipOval(
                    child: AnimatedBuilder(
                      animation: _idleCtrl,
                      builder: (_, __) {
                        final scale = 1.0 + (active ? level * 0.15 : _idleCtrl.value * 0.04);
                        return Transform.scale(
                          scale: scale,
                          child: Image.asset(
                            'assets/ai_core_logo.png',
                            width: s * 0.50,
                            height: s * 0.50,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Icon(
                              Icons.psychology_rounded,
                              size: s * 0.28,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarRingsPainter extends CustomPainter {
  final double progress;
  final bool isListening;
  final bool isSpeaking;
  final double soundLevel;

  _AvatarRingsPainter({
    required this.progress,
    required this.isListening,
    required this.isSpeaking,
    required this.soundLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.46;

    final color = isListening
        ? AtlasColors.neonGreen
        : isSpeaking
            ? AtlasColors.neonCyan
            : AtlasColors.neonPurple;

    for (int i = 0; i < 3; i++) {
      final p = (progress + i / 3.0) % 1.0;
      final r = maxR * 0.45 + p * (maxR * 0.55);
      final opacity = (1.0 - p) * (isListening ? 0.6 : 0.3) * (1.0 + soundLevel * 0.5);

      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + (1.0 - p) * 1.5;

      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_AvatarRingsPainter old) => true;
}

class _EqualizerRing extends StatelessWidget {
  final Color color;
  final int barCount;
  final double intensity;

  const _EqualizerRing({
    required this.color,
    required this.barCount,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.maxWidth;
      final center = size / 2;
      final radius = size * 0.42;

      return Stack(
        children: List.generate(barCount, (i) {
          final angle = (2 * pi / barCount) * i;
          final voiceAmp = (intensity * 2.2).clamp(0.0, 1.0);
          final barH = 5.0 + (voiceAmp * 22.0) * (0.5 + 0.5 * sin(i * 1.5));
          final x = center + radius * cos(angle) - 2;
          final y = center + radius * sin(angle) - barH / 2;

          return Positioned(
            left: x,
            top: y,
            child: Transform.rotate(
              angle: angle + pi / 2,
              child: Container(
                width: 3.5,
                height: barH,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.8),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
            ),
          );
        }),
      );
    });
  }
}
