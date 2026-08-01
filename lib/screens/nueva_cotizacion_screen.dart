import 'package:flutter/material.dart';

import '../models/cotizacion.dart';
import 'quote/quote_editor_screen.dart';

/// Punto de entrada compatible: redirige al editor profesional por pasos.
class NuevaCotizacionScreen extends StatelessWidget {
  final Cotizacion? cotizacion;

  const NuevaCotizacionScreen({super.key, this.cotizacion});

  @override
  Widget build(BuildContext context) {
    return QuoteEditorScreen(
      cotizacion: cotizacion,
      resumeDraft: cotizacion == null,
    );
  }
}
