import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/atlas_theme.dart';
import 'atlas_avatar.dart';

/// "Hey Atlas" algılandığında gösterilen overlay
class WakeWordOverlay extends StatelessWidget {
  const WakeWordOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AtlasColors.bg.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AtlasAvatar(
              isListening: true,
              size: 200,
            ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 900.ms,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 32),

            ShaderMask(
              shaderCallback: (b) =>
                  AtlasColors.primaryGradient.createShader(b),
              child: const Text(
                'Dinliyorum...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 8),

            Text(
              '"Hey Atlas" algılandı',
              style: TextStyle(
                color: AtlasColors.neonGreen,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
