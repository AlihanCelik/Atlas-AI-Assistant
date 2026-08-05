import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/atlas_theme.dart';

/// Konuşan Atlas avatarı — ses dalgası + orbit halkalar
class AtlasAvatar extends StatefulWidget {
  final bool isSpeaking;   // Atlas yanıt verirken
  final bool isListening;  // Kullanıcı konuşurken / wake word
  final double soundLevel; // 0.0–1.0 mikrofon seviyesi
  final double size;

  const AtlasAvatar({
    super.key,
    this.isSpeaking = false,
    this.isListening = false,
    this.soundLevel = 0.0,
    this.size = 180,
  });

  @override
  State<AtlasAvatar> createState() => _AtlasAvatarState();
}

class _AtlasAvatarState extends State<AtlasAvatar>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _idleCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _waveCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final active = widget.isSpeaking || widget.isListening;
    final level = widget.soundLevel;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Dış ses halkası (ses seviyesine göre büyür) ──────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final extra = active ? level * s * 0.25 : 0.0;
              final pulse = _pulseCtrl.value * (active ? 0.06 : 0.03);
              return Container(
                width: s * 0.88 + extra + pulse * s,
                height: s * 0.88 + extra + pulse * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.isListening
                          ? AtlasColors.neonGreen.withOpacity(0.35 + level * 0.3)
                          : widget.isSpeaking
                              ? AtlasColors.neonCyan.withOpacity(0.3 + _pulseCtrl.value * 0.2)
                              : AtlasColors.neonPurple.withOpacity(0.15 + _pulseCtrl.value * 0.1),
                      blurRadius: 36 + level * 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Orbit 1 ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _orbitCtrl,
            builder: (_, __) => Transform.rotate(
              angle: _orbitCtrl.value * 2 * pi,
              child: CustomPaint(
                size: Size(s * 0.90, s * 0.90),
                painter: _OrbitPainter(
                  color: (widget.isListening
                          ? AtlasColors.neonGreen
                          : AtlasColors.neonPurple)
                      .withOpacity(0.30),
                  dotColor: AtlasColors.neonCyan,
                  dotCount: 3,
                ),
              ),
            ),
          ),

          // ── Orbit 2 (ters) ───────────────────────────────────
          AnimatedBuilder(
            animation: _orbitCtrl,
            builder: (_, __) => Transform.rotate(
              angle: -_orbitCtrl.value * 2 * pi * 0.6,
              child: CustomPaint(
                size: Size(s * 0.75, s * 0.75),
                painter: _OrbitPainter(
                  color: AtlasColors.neonCyan.withOpacity(0.18),
                  dotColor: widget.isSpeaking
                      ? AtlasColors.neonCyan
                      : AtlasColors.neonPurple,
                  dotCount: 2,
                ),
              ),
            ),
          ),

          // ── Ses dalgası (aktif durumlarda) ───────────────────
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) => CustomPaint(
              size: Size(s * 0.62, s * 0.62),
              painter: _WavePainter(
                progress: _waveCtrl.value,
                color: widget.isListening
                    ? AtlasColors.neonGreen
                    : AtlasColors.neonCyan,
                barCount: 9,
                intensity: active ? (0.4 + level * 0.6) : 0.0,
              ),
            ),
          ),

          // ── Ana çember ───────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: s * 0.50,
            height: s * 0.50,
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
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _idleCtrl,
                builder: (_, __) => Text(
                  widget.isListening ? '◉' : 'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.isListening ? s * 0.18 : s * 0.22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    shadows: [
                      Shadow(
                        color: AtlasColors.neonCyan.withOpacity(
                            0.6 + _idleCtrl.value * 0.4),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Orbit halkası ────────────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final Color color;
  final Color dotColor;
  final int dotCount;

  _OrbitPainter({
    required this.color,
    required this.dotColor,
    required this.dotCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashCount = 40;
    const step = 2 * pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final a = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a,
        step * 0.45,
        false,
        paint,
      );
    }

    final dotPaint = Paint()..color = dotColor;
    final glowPaint = Paint()
      ..color = dotColor.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * pi;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawCircle(Offset(x, y), 4, glowPaint);
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.color != color;
}

// ─── Ses dalgası ──────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int barCount;
  final double intensity; // 0.0 = gizli, 1.0 = tam

  _WavePainter({
    required this.progress,
    required this.color,
    required this.barCount,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity < 0.01) return;

    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final barW = size.width / (barCount * 2.2);
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = barW * (i * 2.2 + 1.1);
      final phase = (i / barCount) * pi * 2 + progress * pi * 2;
      final heightFactor = (0.15 + sin(phase).abs() * 0.85) * intensity;
      final barH = (size.height * 0.45) * heightFactor;

      final alpha = 0.5 + (i / barCount) * 0.5;
      paint.color = color.withOpacity(alpha * intensity);

      canvas.drawLine(
        Offset(x, centerY - barH),
        Offset(x, centerY + barH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
