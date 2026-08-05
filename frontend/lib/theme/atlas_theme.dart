import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AtlasColors {
  // Base
  static const bg = Color(0xFF080810);
  static const surface = Color(0xFF0D0D1A);
  static const surfaceElevated = Color(0xFF12121F);
  static const border = Color(0xFF1A1A2E);

  // Neon
  static const neonPurple = Color(0xFF7C3AED);
  static const neonCyan = Color(0xFF06B6D4);
  static const neonGreen = Color(0xFF10B981);
  static const neonPink = Color(0xFFEC4899);

  // Glow variants
  static const glowPurple = Color(0x407C3AED);
  static const glowCyan = Color(0x4006B6D4);
  static const glowGreen = Color(0x4010B981);

  // Text
  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF334155);
  static const textCode = Color(0xFF10B981);

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [neonPurple, neonCyan],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get bgGradient => const LinearGradient(
        colors: [bg, Color(0xFF0A0A18), Color(0xFF080810)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class AtlasTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AtlasColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AtlasColors.neonPurple,
          secondary: AtlasColors.neonCyan,
          surface: AtlasColors.surface,
          background: AtlasColors.bg,
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          ThemeData.dark().textTheme.copyWith(
                bodyMedium: const TextStyle(color: AtlasColors.textPrimary),
                bodyLarge: const TextStyle(color: AtlasColors.textPrimary),
              ),
        ),
        useMaterial3: true,
      );
}
