import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Interactive Matrix & Computer Code Rain painter reacting to mouse cursor movement
class CodeRainPainter extends CustomPainter {
  final double progress;
  final List<_CodeColumn> columns;
  final Offset? mousePosition;

  CodeRainPainter({
    required this.progress,
    required this.columns,
    this.mousePosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final col in columns) {
      col.paint(canvas, size, progress, mousePosition);
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
  final double fontSize;

  _CodeColumn({
    required this.x,
    required this.speed,
    required this.offset,
    required this.chars,
    required this.color,
    required this.opacity,
    this.fontSize = 11.0,
  });

  void paint(Canvas canvas, Size size, double progress, Offset? mousePos) {
    final lineHeight = fontSize + 6.0;
    final totalHeight = chars.length * lineHeight;
    final t = (progress * speed + offset) % 1.0;
    final headY = t * (size.height + totalHeight) - totalHeight;

    for (int i = 0; i < chars.length; i++) {
      final baseY = headY + i * lineHeight;
      if (baseY < -lineHeight || baseY > size.height) continue;

      double drawX = x;
      double drawY = baseY;
      double charOpacity = opacity;
      Color charColor = color;
      double charSize = fontSize;
      bool isMouseNear = false;

      // Mouse Hover Reaction & Parallax Offset
      if (mousePos != null) {
        final dx = mousePos.dx - x;
        final dy = mousePos.dy - baseY;
        final distSquare = dx * dx + dy * dy;
        const interactionRadiusSq = 140.0 * 140.0;

        if (distSquare < interactionRadiusSq) {
          isMouseNear = true;
          final dist = sqrt(distSquare);
          final normFactor = 1.0 - (dist / 140.0);

          // Subtle push away / parallax displacement based on mouse movement
          drawX += (dx / (dist + 0.1)) * normFactor * -12.0;
          drawY += (dy / (dist + 0.1)) * normFactor * -8.0;

          // Increase brightness & size when mouse passes over
          charOpacity = (opacity + normFactor * 0.75).clamp(0.0, 1.0);
          charSize = fontSize + normFactor * 2.5;
          charColor = Color.lerp(color, Colors.white, normFactor * 0.8) ?? Colors.white;
        }
      }

      final isFront = i == chars.length - 1;
      final fade = (i / chars.length);

      final textStyle = TextStyle(
        color: isMouseNear
            ? charColor.withOpacity(charOpacity)
            : (isFront
                ? Colors.white.withOpacity(min(1.0, opacity * 2.4))
                : color.withOpacity(opacity * fade * 0.95)),
        fontSize: charSize,
        fontWeight: (isFront || isMouseNear) ? FontWeight.bold : FontWeight.w500,
        fontFamily: 'monospace',
        shadows: (isFront || isMouseNear)
            ? [
                Shadow(
                  color: isMouseNear ? Colors.cyanAccent.withOpacity(0.9) : color.withOpacity(0.9),
                  blurRadius: isMouseNear ? 14 : 10,
                )
              ]
            : null,
      );

      final textPainter = TextPainter(
        text: TextSpan(text: chars[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(drawX, drawY));
    }
  }
}

class CodeRainWidget extends StatefulWidget {
  final Widget child;
  final double densityMultiplier;
  final Offset? mousePosition;

  const CodeRainWidget({
    super.key,
    required this.child,
    this.densityMultiplier = 1.0,
    this.mousePosition,
  });

  @override
  State<CodeRainWidget> createState() => _CodeRainWidgetState();
}

class _CodeRainWidgetState extends State<CodeRainWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  late List<_CodeColumn> _columns;
  final _random = Random();
  Offset? _mousePosition;

  // Real Computer & System Code Snippets
  static const List<String> _codeSnippets = [
    'def wake_word_listener():',
    'async def stream_tokens(prompt):',
    'ollama.chat_stream(model="llama3.2:3b")',
    'class AtlasNeuralKernel(nn.Module):',
    'import torch.nn as nn, numpy as np',
    'ws.send(json.dumps({"type": "chat"}))',
    'if "hey atlas" in text.lower():',
    'VAD.detect_voice_activity(sample_rate=16000)',
    'return ChatResponse(status=200, model=model)',
    '0x7FF8A9B2C40A',
    'await connection.broadcast(payload)',
    'vector_db.similarity_search(query_embed)',
    'System.init_atlas_core(gpu_enabled=True)',
    'def parse_user_intent(audio_buffer):',
    'embeddings.embed_query(input_text)',
    '01011001 01000001 01011001 01001001',
    'GPU_TEMP: 41°C | RAM_ALLOC: 482MB',
    'class AtlasApp extends StatelessWidget',
    'setState(() => _isListening = true);',
    'AVAudioEngine.inputNode.installTap()',
    'FastAPI.lifespan(app_instance)',
    'SpeechRecognition.google_stt(tr-TR)',
  ];

  static const List<String> _codeChars = [
    '0', '1', '{', '}', '(', ')', ';', '/', '*', '=', ':', '!',
    'f', 'n', 'x', 'i', 'v', 'a', 'b', 'c', 'k', 'm', 'r',
    '<', '>', '=', '!', '&', '|', '#', '@', '\$', '%', '^', '~',
    'A', 'T', 'L', 'A', 'S', 'P', 'R', 'O', 'C', 'E', 'S', 'S',
  ];

  static const List<Color> _colors = [
    Color(0xFF8B5CF6), // neon purple
    Color(0xFF06B6D4), // neon cyan
    Color(0xFF10B981), // neon green
    Color(0xFF6366F1), // indigo
    Color(0xFFEC4899), // neon pink
  ];

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })..start();

    _generateColumns();
  }

  void _generateColumns() {
    final count = (85 * widget.densityMultiplier).toInt();
    _columns = List.generate(count, (i) {
      final isSnippetCol = _random.nextDouble() < 0.4;
      final charCount = isSnippetCol ? 6 + _random.nextInt(10) : 8 + _random.nextInt(18);

      List<String> colChars;
      if (isSnippetCol) {
        final snippet = _codeSnippets[_random.nextInt(_codeSnippets.length)];
        colChars = snippet.split('');
      } else {
        colChars = List.generate(
          charCount,
          (_) => _codeChars[_random.nextInt(_codeChars.length)],
        );
      }

      return _CodeColumn(
        x: i * 15.0 + _random.nextDouble() * 8,
        speed: 0.12 + _random.nextDouble() * 0.45,
        offset: _random.nextDouble(),
        chars: colChars,
        color: _colors[_random.nextInt(_colors.length)],
        opacity: 0.08 + _random.nextDouble() * 0.20,
        fontSize: isSnippetCol ? 10.5 : 11.5,
      );
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeMousePos = widget.mousePosition ?? _mousePosition;
    final elapsedSec = _stopwatch.elapsedMilliseconds / 1000.0;

    return MouseRegion(
      onHover: (event) {
        if (widget.mousePosition == null) {
          _mousePosition = event.localPosition;
        }
      },
      onExit: (_) {
        if (widget.mousePosition == null) {
          _mousePosition = null;
        }
      },
      child: CustomPaint(
        painter: CodeRainPainter(
          progress: elapsedSec * 0.04,
          columns: _columns,
          mousePosition: activeMousePos,
        ),
        child: widget.child,
      ),
    );
  }
}
