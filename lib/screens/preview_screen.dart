import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/cotizacion.dart';
import '../saas/models/org_client.dart';
import '../saas/models/quote.dart';
import '../saas/providers/auth_controller.dart';
import '../saas/offline/pdf_local_archive.dart';
import '../saas/services/client_repository.dart';
import '../saas/services/cloud_cotizacion_repository.dart';
import '../saas/services/quote_share_service.dart';
import '../screens/account/pricing_screen.dart';
import '../services/docx_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_share_service.dart';
import '../ui/providers/locale_controller.dart';
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
  bool _sharing = false;

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

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final lang = mounted ? context.read<LocaleController>().languageCode : 'es';
    final bytes = _quote != null
        ? await PdfService.generarPDFFromQuote(_quote!, languageCode: lang)
        : await PdfService.generarPDF(_cotizacion, languageCode: lang);
    try {
      final orgId =
          _quote?.organizationId ??
          (mounted ? context.read<AuthController>().organizationId : null);
      if (orgId != null && orgId.isNotEmpty) {
        await PdfLocalArchive.instance.saveQuotePdf(
          organizationId: orgId,
          quoteId: _cotizacion.id,
          number: _cotizacion.numero,
          bytes: bytes,
        );
      }
    } catch (_) {}
    return bytes;
  }

  String _mapShareError(Object e) {
    final l10n = context.l10n;
    final code = e is StateError ? e.message : '$e';
    return switch (code) {
      'share_pdf_empty' => l10n.sharePdfEmpty,
      'share_pdf_invalid' => l10n.sharePdfInvalid,
      'share_pdf_write_failed' => l10n.sharePdfWriteFailed,
      'share_pdf_open_failed' => l10n.sharePdfOpenFailed,
      'share_pdf_busy' => l10n.sharePdfBusy,
      'share_pdf_web_unsupported' => l10n.sharePdfOpenFailed,
      _ => '$e'.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''),
    };
  }

  Future<void> _exportarWord(BuildContext context) async {
    final auth = context.read<AuthController>();
    final l10n = context.l10n;
    if (!auth.canExportDocx) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.docxProRequired)));
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PricingScreen()),
      );
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(l10n.generatingWord),
        duration: const Duration(seconds: 1),
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
        content: Text(ok ? l10n.wordReadyToShare : l10n.wordGenerateFailed),
        backgroundColor: ok ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _shareMenu() async {
    if (_sharing || PdfShareService.instance.isBusy) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.sharePdfBusy)));
      return;
    }

    final auth = context.read<AuthController>();
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sheetL10n = ctx.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(sheetL10n.sharePdfFile),
                  onTap: () => Navigator.pop(ctx, 'pdf'),
                ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: Text(sheetL10n.shareWhatsApp),
                onTap: () => Navigator.pop(ctx, 'wa'),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(sheetL10n.shareEmail),
                onTap: () => Navigator.pop(ctx, 'mail'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(sheetL10n.shareSecureLink7d),
                onTap: () => Navigator.pop(ctx, 'link'),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    setState(() => _sharing = true);
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(l10n.sharePdfPreparing),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final lang = context.read<LocaleController>().languageCode;
      final uid =
          auth.user?.uid ?? auth.restSession?.uid ?? auth.profile?.uid ?? '';

      // El enlace es opcional: no bloquea compartir el PDF offline.
      final shareUrl = choice == 'link'
          ? await QuoteShareService.instance.tryCreateShareLink(
              quote: _quote,
              createdByUid: uid,
            )
          : await QuoteShareService.instance.tryCreateShareLink(
              quote: auth.organizationId != null ? _quote : null,
              createdByUid: uid,
            );

      if (!mounted) return;

      if (choice == 'link') {
        if (shareUrl == null) {
          throw Exception(
            auth.organizationId == null || _quote == null
                ? l10n.shareLinkRequiresCloud
                : l10n.shareLinkUnavailableOffline,
          );
        }
        await QuoteShareService.instance.markSent(_quote!.id);
        if (!mounted) return;
        scaffold.hideCurrentSnackBar();
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.secureLinkTitle),
            content: SelectableText(shareUrl),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
            ],
          ),
        );
        return;
      }

      if (kIsWeb) {
        // En web no hay shareXFiles de archivo; se mantiene texto + enlace.
        if (choice == 'wa') {
          await QuoteShareService.instance.shareWhatsApp(
            cot: _cotizacion,
            client: _client,
            shareUrl: shareUrl,
            quoteId: _quote?.id,
            attachPdf: false,
          );
        } else {
          await QuoteShareService.instance.shareEmail(
            cot: _cotizacion,
            client: _client,
            shareUrl: shareUrl,
            quoteId: _quote?.id,
            attachPdf: false,
          );
        }
        return;
      }

      // PDF / WhatsApp / Correo: adjuntan el archivo vía sheet nativo.
      await QuoteShareService.instance.shareQuotePdf(
        cot: _cotizacion,
        quote: _quote,
        client: _client,
        shareUrl: shareUrl,
        quoteId: _quote?.id,
        languageCode: lang,
      );
      if (!mounted) return;
      scaffold.hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(
        SnackBar(
          content: Text(_mapShareError(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      } else {
        _sharing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDocx = context.watch<AuthController>().canExportDocx;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quotePreviewTitle(_cotizacion.numero)),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: l10n.share,
            onPressed: (_loadingQuote || _sharing) ? null : _shareMenu,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.tooltipEditQuote,
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
              tooltip: canDocx ? l10n.tooltipExportWord : l10n.tooltipDocxPro,
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
