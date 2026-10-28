import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../models/cotizacion.dart';
import '../../services/pdf_share_service.dart';
import '../../ui/providers/locale_controller.dart';
import '../providers/auth_controller.dart';
import 'cloud_cotizacion_repository.dart';
import 'quote_share_service.dart';

/// Comparte el PDF de una [Cotizacion] desde UI (tarjetas / menús) sin abrir
/// la vista previa. Reutiliza [QuoteShareService] y [PdfShareService].
class QuoteShareUi {
  QuoteShareUi._();

  static String mapError(AppLocalizations l10n, Object e) {
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

  /// Genera/recupera el PDF de [cot] y abre el sheet nativo.
  /// El enlace seguro es opcional y no bloquea el adjunto offline.
  static Future<void> shareCotizacion(
    BuildContext context,
    Cotizacion cot, {
    bool markAsSent = true,
  }) async {
    if (kIsWeb) {
      throw StateError('share_pdf_web_unsupported');
    }
    if (PdfShareService.instance.isBusy) {
      throw StateError('share_pdf_busy');
    }

    final auth = context.read<AuthController>();
    final lang = context.read<LocaleController>().languageCode;
    final uid =
        auth.user?.uid ?? auth.restSession?.uid ?? auth.profile?.uid ?? '';

    final quote = await CloudCotizacionRepository.instance.getQuote(cot.id);
    final shareUrl = await QuoteShareService.instance.tryCreateShareLink(
      quote: auth.organizationId != null ? quote : null,
      createdByUid: uid,
    );

    if (!context.mounted) return;

    await QuoteShareService.instance.shareQuotePdf(
      cot: cot,
      quote: quote,
      shareUrl: shareUrl,
      quoteId: quote?.id ?? cot.id,
      languageCode: lang,
      markAsSent: markAsSent && auth.organizationId != null,
    );
  }

  /// Muestra snack de preparación, ejecuta [shareCotizacion] y errores localizados.
  static Future<void> shareCotizacionWithFeedback(
    BuildContext context,
    Cotizacion cot, {
    bool markAsSent = true,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.sharePdfPreparing),
          duration: const Duration(seconds: 2),
        ),
      );
    try {
      await shareCotizacion(context, cot, markAsSent: markAsSent);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(mapError(l10n, e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
    }
  }
}
