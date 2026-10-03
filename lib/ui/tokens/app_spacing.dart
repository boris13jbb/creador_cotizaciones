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

  static const EdgeInsets page = EdgeInsets.all(md);
  static const EdgeInsets pageWide = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

/// Anchos de contenido y breakpoints (Material window classes).
abstract final class AppBreakpoints {
  /// Móvil estrecho / prueba de overflow.
  static const double compact = 320;

  /// Teléfono típico → NavigationBar.
  static const double medium = 600;

  /// Tableta / escritorio → NavigationRail.
  static const double expanded = 840;

  /// Ancho máximo del contenido centrado en desktop.
  static const double contentMax = 960;

  /// Auth forms.
  static const double authMax = 420;
}
