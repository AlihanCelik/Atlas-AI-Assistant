import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/atlas_theme.dart';

/// Floating Coder Glass Window container widget
class CyberWindow extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final VoidCallback onClose;
  final VoidCallback? onMinimize;
  final List<Widget>? headerActions;
  final double width;
  final double height;
  final Offset initialPosition;

  const CyberWindow({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
    required this.onClose,
    this.onMinimize,
    this.headerActions,
    this.width = 460,
    this.height = 420,
    this.initialPosition = const Offset(80, 40),
  });

  @override
  State<CyberWindow> createState() => _CyberWindowState();
}

class _CyberWindowState extends State<CyberWindow> {
  late Offset _position;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Boundary check so window doesn't get dragged off screen
    final maxLeft = screenSize.width - 120;
    final maxTop = screenSize.height - 80;
    final clampedLeft = _position.dx.clamp(10.0, maxLeft);
    final clampedTop = _position.dy.clamp(10.0, maxTop);

    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: _isMinimized ? 44 : widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E1B).withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(
                children: [
                  // ── Title Bar ──────────────────────────────────────────
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.08),
                      border: Border(
                        bottom: BorderSide(
                          color: widget.accentColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Window Dots (Close, Minimize, Expand)
                        Row(
                          children: [
                            _WindowDot(
                              color: const Color(0xFFFF5F57),
                              onTap: widget.onClose,
                              tooltip: 'Kapat',
                            ),
                            const SizedBox(width: 8),
                            _WindowDot(
                              color: const Color(0xFFFFBD2E),
                              onTap: () {
                                setState(() {
                                  _isMinimized = !_isMinimized;
                                });
                                widget.onMinimize?.call();
                              },
                              tooltip: _isMinimized ? 'Genişlet' : 'Simge Durumu',
                            ),
                            const SizedBox(width: 8),
                            _WindowDot(
                              color: const Color(0xFF28CA41),
                              onTap: () {},
                              tooltip: 'Sabitle',
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Icon + Title
                        Icon(
                          widget.icon,
                          size: 16,
                          color: widget.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: AtlasColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            fontFamily: 'monospace',
                          ),
                        ),

                        const Spacer(),

                        if (widget.headerActions != null) ...widget.headerActions!,

                        const SizedBox(width: 4),

                        // Drag hint
                        Icon(
                          Icons.drag_indicator_rounded,
                          size: 16,
                          color: AtlasColors.textMuted.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),

                  // ── Window Body ───────────────────────────────────────
                  if (!_isMinimized)
                    Expanded(
                      child: widget.child,
                    ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 200.ms).scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
              duration: 250.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

class _WindowDot extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _WindowDot({
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_WindowDot> createState() => _WindowDotState();
}

class _WindowDotState extends State<_WindowDot> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHover = true),
        onExit: (_) => setState(() => _isHover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHover ? widget.color : widget.color.withOpacity(0.8),
              boxShadow: _isHover
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.6),
                        blurRadius: 6,
                      )
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
