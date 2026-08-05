import 'package:flutter/material.dart';

/// Siber grid arka planı
class GridPainter extends CustomPainter {
  final double glowProgress;

  GridPainter({required this.glowProgress});

  @override
  void paint(Canvas canvas, Size size) {
    // Yatay çizgiler
    final hPaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }

    // Dikey çizgiler
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hPaint);
    }

    // Merkez glow
    final cx = size.width / 2;
    final cy = size.height / 2;
    final glowRadius = 200.0 + glowProgress * 60.0;

    final radialGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x157C3AED),
          const Color(0x0A06B6D4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius),
      );

    canvas.drawCircle(Offset(cx, cy), glowRadius, radialGlow);

    // Alt köşe perspektif çizgileri
    final perspPaint = Paint()
      ..color = const Color(0x0D7C3AED)
      ..strokeWidth = 0.5;

    for (int i = 0; i < 10; i++) {
      final t = i / 10.0;
      canvas.drawLine(
        Offset(size.width * t, size.height),
        Offset(cx, cy * 0.6),
        perspPaint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter old) => old.glowProgress != glowProgress;
}

class GridBackground extends StatefulWidget {
  final Widget child;

  const GridBackground({super.key, required this.child});

  @override
  State<GridBackground> createState() => _GridBackgroundState();
}

class _GridBackgroundState extends State<GridBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
      builder: (_, __) => CustomPaint(
        painter: GridPainter(glowProgress: _ctrl.value),
        child: widget.child,
      ),
    );
  }
}
