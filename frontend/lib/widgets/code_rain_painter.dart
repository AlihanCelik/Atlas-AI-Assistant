import 'dart:math';
import 'package:flutter/material.dart';

/// Matrix-style floating code characters arka plan
class CodeRainPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, animasyon zamanı
  final List<_CodeColumn> columns;

  CodeRainPainter({required this.progress, required this.columns});

  @override
  void paint(Canvas canvas, Size size) {
    for (final col in columns) {
      col.paint(canvas, size, progress);
    }
  }

  @override
  bool shouldRepaint(CodeRainPainter old) => true;
}

class _CodeColumn {
  final double x;
  final double speed;
  final double offset;
  final List<String> chars;
  final Color color;
  final double opacity;

  _CodeColumn({
    required this.x,
    required this.speed,
    required this.offset,
    required this.chars,
    required this.color,
    required this.opacity,
  });

  void paint(Canvas canvas, Size size, double progress) {
    final t = (progress * speed + offset) % 1.0;
    final headY = t * (size.height + chars.length * 18.0) - chars.length * 18.0;

    for (int i = 0; i < chars.length; i++) {
      final y = headY + i * 18.0;
      if (y < -18 || y > size.height) continue;

      // Baştaki karakter daha parlak
      final isFront = i == chars.length - 1;
      final fade = (i / chars.length);

      final textPainter = TextPainter(
        text: TextSpan(
          text: chars[i],
          style: TextStyle(
            color: isFront
                ? Colors.white.withOpacity(opacity)
                : color.withOpacity(opacity * fade * 0.8),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x, y));
    }
  }
}

class CodeRainWidget extends StatefulWidget {
  final Widget child;

  const CodeRainWidget({super.key, required this.child});

  @override
  State<CodeRainWidget> createState() => _CodeRainWidgetState();
}

class _CodeRainWidgetState extends State<CodeRainWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_CodeColumn> _columns;
  final _random = Random();

  // Yazılımla ilgili karakterler ve semboller
  static const _codeChars = [
    '0', '1', '{', '}', '(', ')', ';', '/', '*',
    'f', 'n', 'x', 'i', 'λ', '∑', '∆', '≡',
    '<', '>', '=', '!', '&', '|', '#', '@',
    'A', 'T', 'L', 'S', 'π', '∞', '▶', '■',
  ];

  static const _colors = [
    Color(0xFF7C3AED), // purple
    Color(0xFF06B6D4), // cyan
    Color(0xFF10B981), // green
    Color(0xFF6366F1), // indigo
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _generateColumns();
  }

  void _generateColumns() {
    _columns = List.generate(55, (i) {
      final charCount = 6 + _random.nextInt(12);
      return _CodeColumn(
        x: i * 18.0 + _random.nextDouble() * 8,
        speed: 0.15 + _random.nextDouble() * 0.35,
        offset: _random.nextDouble(),
        chars: List.generate(
          charCount,
          (_) => _codeChars[_random.nextInt(_codeChars.length)],
        ),
        color: _colors[_random.nextInt(_colors.length)],
        opacity: 0.06 + _random.nextDouble() * 0.10,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: CodeRainPainter(
          progress: _controller.value,
          columns: _columns,
        ),
        child: widget.child,
      ),
    );
  }
}
