import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/atlas_service.dart';
import '../theme/atlas_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _AtlasIcon(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Gönderen etiketi
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                  child: Text(
                    isUser ? 'Sen' : 'Atlas',
                    style: TextStyle(
                      color: isUser
                          ? AtlasColors.neonPurple.withOpacity(0.7)
                          : AtlasColors.neonCyan.withOpacity(0.7),
                      fontSize: 10,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                // Balon
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                  },
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AtlasColors.neonPurple.withOpacity(0.12)
                          : AtlasColors.surfaceElevated,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      border: Border.all(
                        color: isUser
                            ? AtlasColors.neonPurple.withOpacity(0.25)
                            : AtlasColors.neonCyan.withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? AtlasColors.neonPurple.withOpacity(0.08)
                              : AtlasColors.neonCyan.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: message.isLoading
                        ? const _TypingDots()
                        : isUser
                            ? Text(
                                message.text,
                                style: const TextStyle(
                                  color: AtlasColors.textPrimary,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              )
                            : MarkdownBody(
                                data: message.text,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                    color: AtlasColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                  code: const TextStyle(
                                    color: AtlasColors.neonGreen,
                                    backgroundColor: Color(0xFF0A0A14),
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: const Color(0xFF0A0A14),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AtlasColors.neonGreen.withOpacity(0.2),
                                    ),
                                  ),
                                  blockquoteDecoration: BoxDecoration(
                                    color: AtlasColors.neonPurple.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                    border: const Border(
                                      left: BorderSide(
                                        color: AtlasColors.neonPurple,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .slideX(
                begin: isUser ? 0.08 : -0.08,
                end: 0,
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(width: 8),
          if (isUser) _UserIcon(),
        ],
      ),
    );
  }
}

class _AtlasIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AtlasColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AtlasColors.neonPurple.withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'A',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _UserIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AtlasColors.neonPurple.withOpacity(0.15),
        border: Border.all(
          color: AtlasColors.neonPurple.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: 14,
        color: AtlasColors.neonPurple.withOpacity(0.8),
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
          period: Duration(milliseconds: 500 + i * 180),
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
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrls[i],
            builder: (_, __) => Container(
              margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  AtlasColors.neonPurple,
                  AtlasColors.neonCyan,
                  _ctrls[i].value,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AtlasColors.neonCyan.withOpacity(_ctrls[i].value * 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
