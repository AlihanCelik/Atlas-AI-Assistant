import 'dart:math';
import 'package:flutter/material.dart';

/// Futuristic Neural Constellation & Quantum Particle Mesh background
class GridPainter extends CustomPainter {
  final double progress;
  final double glowProgress;
  final List<_NeuralParticle> particles;
  final Offset? centerOffset;

  GridPainter({
    required this.progress,
    this.glowProgress = 0.0,
    required this.particles,
    this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Default to avatar center (~28% from top of window) if no custom center offset provided
    final center = centerOffset ?? Offset(size.width / 2, size.height * 0.28);
    final cx = center.dx;
    final cy = center.dy;

    // ── 1. Deep Space Radial Ambient Glow ──────────────────────────
    final glowRadius = size.width * 0.55;
    final radialGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x2A8B5CF6), // Neon purple glow
          const Color(0x1806B6D4), // Cyan glow
          const Color(0x08080916),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.8, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius),
      );

    canvas.drawCircle(Offset(cx, cy), glowRadius, radialGlow);

    // ── 3. Neural Constellation Particle Connections ───────────────
    final linePaint = Paint()..strokeWidth = 0.65;

    for (int i = 0; i < particles.length; i++) {
      final p1 = particles[i];
      p1.update(size, progress);

      for (int j = i + 1; j < particles.length; j++) {
        final p2 = particles[j];
        final dx = p1.x - p2.x;
        final dy = p1.y - p2.y;
        final distSq = dx * dx + dy * dy;

        const maxDist = 135.0;
        if (distSq < maxDist * maxDist) {
          final dist = sqrt(distSq);
          final alpha = (1.0 - (dist / maxDist)).clamp(0.0, 0.45);

          linePaint.color = (i % 2 == 0 ? const Color(0xFF8B5CF6) : const Color(0xFF06B6D4))
              .withOpacity(alpha);

          canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), linePaint);
        }
      }
    }

    // ── 4. Particle Nodes ──────────────────────────────────────────
    final nodePaint = Paint();
    final nodeGlow = Paint();

    for (final p in particles) {
      nodeGlow
        ..color = p.color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      nodePaint.color = p.color.withOpacity(p.opacity);

      canvas.drawCircle(Offset(p.x, p.y), p.radius * 2.2, nodeGlow);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, nodePaint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) => true;
}

class _NeuralParticle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double opacity;
  Color color;

  _NeuralParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  void update(Size size, double progress) {
    x += vx;
    y += vy;

    if (x < 0) x = size.width;
    if (x > size.width) x = 0;
    if (y < 0) y = size.height;
    if (y > size.height) y = 0;
  }
}

class GridBackground extends StatefulWidget {
  final Widget child;
  final Offset? centerOffset;

  const GridBackground({
    super.key,
    required this.child,
    this.centerOffset,
  });

  @override
  State<GridBackground> createState() => _GridBackgroundState();
}

class _GridBackgroundState extends State<GridBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_NeuralParticle> _particles;
  final _random = Random();

  static const List<Color> _particleColors = [
    Color(0xFF8B5CF6), // Neon purple
    Color(0xFF06B6D4), // Neon cyan
    Color(0xFF10B981), // Neon green
    Color(0xFFEC4899), // Neon pink
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _initParticles();
  }

  void _initParticles() {
    _particles = List.generate(48, (_) {
      return _NeuralParticle(
        x: _random.nextDouble() * 1200,
        y: _random.nextDouble() * 900,
        vx: (_random.nextDouble() - 0.5) * 0.45,
        vy: (_random.nextDouble() - 0.5) * 0.45,
        radius: 1.2 + _random.nextDouble() * 2.2,
        opacity: 0.25 + _random.nextDouble() * 0.5,
        color: _particleColors[_random.nextInt(_particleColors.length)],
      );
    });
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
      builder: (_, __) => CustomPaint(
        painter: GridPainter(
          glowProgress: _ctrl.value,
          progress: _ctrl.value,
          particles: _particles,
          centerOffset: widget.centerOffset,
        ),
        child: widget.child,
      ),
    );
  }
}
