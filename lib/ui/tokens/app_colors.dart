import 'package:flutter/material.dart';

/// Paleta de producto (no confundir con ColorPalette de branding PDF).
abstract final class AppColors {
  static const Color ink = Color(0xFF1A1A2E);
  static const Color forest = Color(0xFF2D6A4F);
  static const Color forestBright = Color(0xFF40916C);
  static const Color mist = Color(0xFFF3F6F4);
  static const Color successSoft = Color(0xFFD8F3DC);
  static const Color dangerSoft = Color(0xFFFFE5E5);
  static const Color danger = Color(0xFFB42318);
  static const Color warningSoft = Color(0xFFFFF4DE);

  // Compatibilidad con AppTheme legacy.
  static const Color primaryDark = ink;
  static const Color secondaryGreen = forest;
  static const Color accentGreen = forestBright;
  static const Color lightGray = mist;
  static const Color successGreen = successSoft;
  static const Color errorRed = dangerSoft;
}
