import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/cotizacion.dart';
import '../services/docx_service.dart';
import '../services/pdf_service.dart';
import 'nueva_cotizacion_screen.dart';

class PreviewScreen extends StatefulWidget {
  final Cotizacion cotizacion;

  const PreviewScreen({super.key, required this.cotizacion});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late Cotizacion _cotizacion;

  @override
  void initState() {
    super.initState();
    _cotizacion = widget.cotizacion;
  }

  Future<void> _exportarWord(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('Generando Word...'), duration: Duration(seconds: 1)),
    );
    final ok = await DocxService.generarYCompartirDocx(_cotizacion);
    if (!mounted) return;
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Word listo para compartir'
            : 'Error al generar Word. Revisa que exista assets/plantilla.docx'),
        backgroundColor: ok ? null : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cotización: ${_cotizacion.numero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar Cotización',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NuevaCotizacionScreen(cotizacion: _cotizacion),
                ),
              );
              if (result == true && mounted) {
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              }
            },
          ),
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.description),
              tooltip: 'Exportar Word',
              onPressed: () => _exportarWord(context),
            ),
        ],
      ),
      body: PdfPreview(
        build: (format) => PdfService.generarPDF(_cotizacion),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: "Cotizacion_${_cotizacion.numero}.pdf",
      ),
    );
  }
}
