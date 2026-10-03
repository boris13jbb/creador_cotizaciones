import 'package:flutter/material.dart';

/// Iconografía compartida de CotiApp (Material Icons en todas las plataformas).
///
/// Con `uses-material-design: true` en pubspec, estos IconData se renderizan
/// igual en Windows, Web, Android, iOS, macOS y Linux.
abstract final class AppIcons {
  /// Acción principal: crear / nueva cotización (tiles, vacíos, marca).
  static const IconData nuevaCotizacion = Icons.request_quote_outlined;

  /// FAB y acciones compactas de “nueva cotización”.
  static const IconData nuevaCotizacionFab = Icons.note_add_outlined;

  /// Marca en rail / auth.
  static const IconData marca = Icons.request_quote_rounded;

  /// Agregar ítem de catálogo.
  static const IconData agregarCatalogo = Icons.add_box_outlined;

  /// Agregar línea / condición en el editor.
  static const IconData agregarLinea = Icons.add_circle_outline;
}
