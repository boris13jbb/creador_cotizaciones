import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../models/cotizacion.dart';
import '../saas/models/org_client.dart';
import '../saas/models/quote.dart';
import '../saas/providers/auth_controller.dart';
import '../saas/services/client_repository.dart';
import '../saas/services/cloud_cotizacion_repository.dart';
import '../saas/services/quote_share_service.dart';
import '../screens/account/pricing_screen.dart';
import '../services/docx_service.dart';
import '../services/pdf_service.dart';
import 'nueva_cotizacion_screen.dart';

class PreviewScreen extends StatefulWidget {
  final Cotizacion cotizacion;
  final Quote? quote;

  const PreviewScreen({super.key, required this.cotizacion, this.quote});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late Cotizacion _cotizacion;
  Quote? _quote;
  OrgClient? _client;
  bool _loadingQuote = true;

  @override
  void initState() {
    super.initState();
    _cotizacion = widget.cotizacion;
    _quote = widget.quote;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    try {
      _quote ??= await CloudCotizacionRepository.instance.getQuote(
        _cotizacion.id,
      );
      if (!mounted) return;
      final orgId = context.read<AuthController>().organizationId;
      final clientId = _quote?.clientId;
      if (orgId != null && clientId != null && clientId.isNotEmpty) {
        final clients = await ClientRepository.instance.list(orgId);
        for (final c in clients) {
          if (c.id == clientId) {
            _client = c;
            break;
          }
        }
      }
    } catch (_) {
      // Preview sigue con Cotizacion legacy.
    }
    if (mounted) setState(() => _loadingQuote = false);
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) {
    if (_quote != null) {
      return PdfService.generarPDFFromQuote(_quote!);
    }
    return PdfService.generarPDF(_cotizacion);
  }

  Future<void> _exportarWord(BuildContext context) async {
    final auth = context.read<AuthController>();
    if (!auth.canExportDocx) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La exportación DOCX está disponible en Pro (o durante la prueba).',
          ),
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PricingScreen()),
      );
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Generando Word...'),
        duration: Duration(seconds: 1),
      ),
    );
    final ok = await DocxService.generarYCompartirDocx(
      _cotizacion,
      quote: _quote,
    );
    if (!mounted) return;
    scaffold.hideCurrentSnackBar();
    if (ok && _quote != null) {
      await QuoteShareService.instance.markSent(_quote!.id);
    }
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Word listo para compartir'
              : 'Error al generar Word. Revisa que exista assets/plantilla.docx',
        ),
        backgroundColor: ok ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _shareMenu() async {
    final auth = context.read<AuthController>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(ctx, 'wa'),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Correo'),
              onTap: () => Navigator.pop(ctx, 'mail'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copiar enlace seguro (7 días)'),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      String? shareUrl;
      if (_quote != null && auth.organizationId != null) {
        shareUrl = await QuoteShareService.instance.createShareLink(
          quote: _quote!,
          createdByUid:
              auth.user?.uid ??
              auth.restSession?.uid ??
              auth.profile?.uid ??
              '',
        );
      }

      if (choice == 'wa') {
        await QuoteShareService.instance.shareWhatsApp(
          cot: _cotizacion,
          client: _client,
          shareUrl: shareUrl,
          quoteId: _quote?.id,
        );
      } else if (choice == 'mail') {
        await QuoteShareService.instance.shareEmail(
          cot: _cotizacion,
          client: _client,
          shareUrl: shareUrl,
          quoteId: _quote?.id,
        );
      } else if (choice == 'link') {
        if (shareUrl == null) {
          throw Exception(
            'Se requiere organización y cotización en la nube para el enlace.',
          );
        }
        await QuoteShareService.instance.markSent(_quote!.id);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Enlace seguro'),
            content: SelectableText(shareUrl!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDocx = context.watch<AuthController>().canExportDocx;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cotización: ${_cotizacion.numero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir',
            onPressed: _loadingQuote ? null : _shareMenu,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar Cotización',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NuevaCotizacionScreen(cotizacion: _cotizacion),
                ),
              );
              if (result == true && mounted && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          if (!kIsWeb)
            IconButton(
              icon: Icon(
                Icons.description,
                color: canDocx ? null : Colors.grey,
              ),
              tooltip: canDocx ? 'Exportar Word' : 'DOCX (Pro)',
              onPressed: () => _exportarWord(context),
            ),
        ],
      ),
      body: _loadingQuote
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              build: _buildPdf,
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              initialPageFormat: PdfPageFormat.a4,
              pdfFileName: 'Cotizacion_${_cotizacion.numero}.pdf',
              onShared: _quote == null
                  ? null
                  : (_) async {
                      await QuoteShareService.instance.markSent(_quote!.id);
                    },
            ),
    );
  }
}
