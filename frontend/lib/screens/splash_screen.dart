import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/atlas_theme.dart';
import '../widgets/code_rain_painter.dart';
import '../widgets/grid_painter.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;

  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _textCtrl;

  // Terminalde yazılan metin
  final List<String> _lines = [
    '> Initializing Atlas AI...',
    '> Loading language model...',
    '> Connecting to backend...',
    '> Wake word detector: active',
    '> System ready.',
  ];
  int _visibleLines = 0;
  String _currentTyping = '';
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Terminal yazı efekti
    _startTyping();

    // 5 saniye sonra geçiş
    Future.delayed(const Duration(milliseconds: 5200), () {
      if (mounted) widget.onDone();
    });
  }

  void _startTyping() async {
    await Future.delayed(const Duration(milliseconds: 800));
    for (int lineIdx = 0; lineIdx < _lines.length; lineIdx++) {
      final line = _lines[lineIdx];
      for (int c = 0; c <= line.length; c++) {
        if (!mounted) return;
        setState(() {
          _currentTyping = line.substring(0, c);
          _charIndex = c;
        });
        await Future.delayed(const Duration(milliseconds: 28));
      }
      if (!mounted) return;
      setState(() {
        _visibleLines = lineIdx + 1;
        _currentTyping = '';
      });
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AtlasColors.bg,
      body: Stack(
        children: [
          // Grid arka plan
          Positioned.fill(
            child: GridBackground(child: const SizedBox.expand()),
          ),

          // Kod yağmuru
          Positioned.fill(
            child: CodeRainWidget(child: const SizedBox.expand()),
          ),

          // Merkez içerik
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Atlas Logo + Halkalar ─────────────────────
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dış halka
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => _Ring(
                          radius: 90 + _ringCtrl.value * 6,
                          strokeWidth: 1.0,
                          color: AtlasColors.neonPurple.withOpacity(0.25 + _ringCtrl.value * 0.15),
                          dashCount: 24,
                          rotation: _ringCtrl.value * 2 * pi * 0.08,
                        ),
                      ),

                      // Orta halka
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => _Ring(
                          radius: 72 + _ringCtrl.value * 4,
                          strokeWidth: 1.5,
                          color: AtlasColors.neonCyan.withOpacity(0.35 + _ringCtrl.value * 0.2),
                          dashCount: 16,
                          rotation: -_ringCtrl.value * 2 * pi * 0.12,
                        ),
                      ),

                      // İç glow
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 96 + _pulseCtrl.value * 12,
                          height: 96 + _pulseCtrl.value * 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AtlasColors.neonPurple.withOpacity(0.4 + _pulseCtrl.value * 0.2),
                                blurRadius: 40 + _pulseCtrl.value * 20,
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                color: AtlasColors.neonCyan.withOpacity(0.2),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Logo çemberi
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AtlasColors.neonPurple,
                              AtlasColors.neonCyan,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AtlasColors.neonPurple.withOpacity(0.6),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0, 0),
                            end: const Offset(1, 1),
                            duration: 800.ms,
                            curve: Curves.elasticOut,
                          ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Atlas ismi ───────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) => AtlasColors.primaryGradient
                      .createShader(bounds),
                  child: const Text(
                    'ATLAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 4),

                Text(
                  'Personal AI Assistant',
                  style: TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                )
                    .animate()
                    .fadeIn(delay: 900.ms, duration: 600.ms),

                const SizedBox(height: 40),

                // ── Terminal bloğu ──────────────────────────
                Container(
                  width: min(size.width * 0.5, 420),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AtlasColors.neonPurple.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Terminal başlık çubuğu
                      Row(
                        children: [
                          _dot(const Color(0xFFFF5F57)),
                          const SizedBox(width: 6),
                          _dot(const Color(0xFFFFBD2E)),
                          const SizedBox(width: 6),
                          _dot(const Color(0xFF28CA41)),
                          const SizedBox(width: 12),
                          Text(
                            'atlas — bash',
                            style: TextStyle(
                              color: AtlasColors.textMuted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tamamlanmış satırlar
                      ...List.generate(_visibleLines, (i) {
                        final isSystem = _lines[i].startsWith('>');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _lines[i],
                            style: TextStyle(
                              color: i == _lines.length - 1
                                  ? AtlasColors.neonGreen
                                  : AtlasColors.neonCyan,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      }),

                      // Aktif yazılan satır
                      if (_currentTyping.isNotEmpty)
                        Row(
                          children: [
                            Text(
                              _currentTyping,
                              style: TextStyle(
                                color: AtlasColors.neonCyan,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            // Yanıp sönen imleç
                            _BlinkingCursor(),
                          ],
                        )
                      else if (_visibleLines == 0)
                        Row(
                          children: [
                            Text(
                              '> ',
                              style: TextStyle(
                                color: AtlasColors.neonCyan,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            _BlinkingCursor(),
                          ],
                        ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ─── Kesik halka çizici ────────────────────────────────────────────
class _Ring extends StatelessWidget {
  final double radius;
  final double strokeWidth;
  final Color color;
  final int dashCount;
  final double rotation;

  const _Ring({
    required this.radius,
    required this.strokeWidth,
    required this.color,
    required this.dashCount,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(radius * 2, radius * 2),
        painter: _RingPainter(
          strokeWidth: strokeWidth,
          color: color,
          dashCount: dashCount,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double strokeWidth;
  final Color color;
  final int dashCount;

  _RingPainter(
      {required this.strokeWidth,
      required this.color,
      required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final step = 2 * pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final start = i * step;
      final end = start + step * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        end - start,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}

// ─── Yanıp sönen imleç ────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _ctrl.value > 0.5 ? 1.0 : 0.0,
        child: Container(
          width: 8,
          height: 14,
          color: AtlasColors.neonGreen,
        ),
      ),
    );
  }
}
