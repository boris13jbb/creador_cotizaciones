import 'package:flutter/painting.dart';

/// Espaciado, radios y tipografía de escala del design system CotiApp.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Área táctil mínima recomendada (Apple HIG / Material).
  static const double minTouchTarget = 48;

  static const EdgeInsets page = EdgeInsets.all(md);
  static const EdgeInsets pageWide = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets pageCompact = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

/// Anchos de contenido y breakpoints.
///
/// Web (objetivo):
/// - Móvil: &lt; 600
/// - Tablet: 600–1023
/// - Escritorio: ≥ 1024
///
/// Nativo (Android/Windows): conserva umbral de rail en [nativeRail] (840)
/// para no cambiar la navegación existente en dispositivos ya probados.
abstract final class AppBreakpoints {
  /// Móvil estrecho / prueba de overflow.
  static const double compact = 320;

  /// Teléfono típico / inicio de tablet.
  static const double medium = 600;

  /// Escritorio web y layouts de dos columnas.
  static const double expanded = 1024;

  /// Umbral histórico de NavigationRail en Android/Windows.
  static const double nativeRail = 840;

  /// Ancho máximo del contenido centrado en desktop.
  static const double contentMax = 1080;

  /// Formularios y páginas de configuración (evita líneas excesivas).
  static const double formMax = 720;

  /// Auth forms.
  static const double authMax = 420;

  /// Diálogos adaptativos.
  static const double dialogMax = 560;
}
