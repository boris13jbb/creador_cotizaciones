import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/cotizacion.dart';
import '../../services/pdf_service.dart';
import '../../services/pdf_share_service.dart';
import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import '../domain/org_enums.dart';
import '../models/org_client.dart';
import '../models/quote.dart';
import '../offline/pdf_local_archive.dart';
import 'auth_service.dart';
import 'cloud_cotizacion_repository.dart';
import 'firestore_rest_client.dart';

/// Comunicación y enlaces de cotización (WhatsApp, correo, share link, PDF).
class QuoteShareService {
  QuoteShareService._();
  static final QuoteShareService instance = QuoteShareService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String buildShareMessage({
    required String number,
    required String clientName,
    required String totalLabel,
    String? shareUrl,
  }) {
    final buf = StringBuffer()
      ..writeln('Hola${clientName.isEmpty ? '' : ' $clientName'},')
      ..writeln()
      ..writeln(
        'Te comparto la cotización *$number* de ${SaasConfig.productName}.',
      )
      ..writeln('Total: $totalLabel');
    if (shareUrl != null && shareUrl.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Ver detalle: $shareUrl');
    }
    buf
      ..writeln()
      ..writeln('Quedo atento a tus comentarios.');
    return buf.toString();
  }

  /// Crea un enlace de solo lectura (7 días). Requiere red/Firestore.
  Future<String> createShareLink({
    required Quote quote,
    required String createdByUid,
  }) async {
    final token = const Uuid().v4().replaceAll('-', '').substring(0, 20);
    final now = DateTime.now().toUtc();
    final expires = now.add(const Duration(days: 7));
    final data = <String, dynamic>{
      'token': token,
      'organizationId': quote.organizationId,
      'quoteId': quote.id,
      'number': quote.number,
      'clientName': quote.clientName,
      'totalCents': quote.total.cents,
      'currency': quote.currency,
      'status': quote.status.id,
      'createdByUid': createdByUid,
      'createdAt': now.toIso8601String(),
      'expiresAt': expires.toIso8601String(),
      'viewCount': 0,
    };

    if (saasUseRestBackend) {
      final session = AuthService.instance.restSession;
      if (session == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.upsertDocument(
        session: session,
        path: 'quoteShares/$token',
        data: data,
      );
    } else {
      await _db.collection('quoteShares').doc(token).set(data);
    }

    final base = SaasConfig.functionsBaseUrl.isNotEmpty
        ? SaasConfig.functionsBaseUrl
        : 'https://us-central1-cotiapp-saas-jb.cloudfunctions.net';
    return '$base/viewQuoteShare?token=$token';
  }

  /// Intenta enlace seguro; si falla (offline, sin org) devuelve null.
  Future<String?> tryCreateShareLink({
    required Quote? quote,
    required String createdByUid,
  }) async {
    if (quote == null || quote.organizationId.isEmpty || createdByUid.isEmpty) {
      return null;
    }
    try {
      return await createShareLink(quote: quote, createdByUid: createdByUid);
    } catch (e) {
      debugPrint('tryCreateShareLink: $e');
      return null;
    }
  }

  Future<void> markSent(String quoteId) async {
    try {
      await CloudCotizacionRepository.instance.setQuoteStatus(
        quoteId,
        QuoteStatus.sent,
      );
    } catch (e) {
      debugPrint('markSent: $e');
    }
  }

  /// Genera (o reutiliza caché local) el PDF y lo comparte con el sheet nativo.
  Future<void> shareQuotePdf({
    required Cotizacion cot,
    Quote? quote,
    OrgClient? client,
    String? shareUrl,
    String? quoteId,
    String languageCode = 'es',
    bool markAsSent = true,
  }) async {
    final bytes = await _resolvePdfBytes(
      cot: cot,
      quote: quote,
      languageCode: languageCode,
    );
    final text = buildShareMessage(
      number: cot.numero,
      clientName: cot.cliente,
      totalLabel: '\$${cot.total.toStringAsFixed(2)}',
      shareUrl: shareUrl,
    );
    final subject = 'Cotización ${cot.numero} — ${SaasConfig.productName}';
    await PdfShareService.instance.sharePdfBytes(
      bytes: bytes,
      number: cot.numero,
      text: text,
      subject: subject,
    );
    if (markAsSent && quoteId != null && quoteId.isNotEmpty) {
      await markSent(quoteId);
    }
  }

  Future<Uint8List> _resolvePdfBytes({
    required Cotizacion cot,
    Quote? quote,
    required String languageCode,
  }) async {
    final orgId = quote?.organizationId;
    if (orgId != null && orgId.isNotEmpty) {
      try {
        final cached = await PdfLocalArchive.instance.findQuotePdf(
          organizationId: orgId,
          quoteId: cot.id,
        );
        if (cached != null && await cached.exists()) {
          final data = await cached.readAsBytes();
          if (PdfShareService.looksLikePdf(data) && data.isNotEmpty) {
            return Uint8List.fromList(data);
          }
        }
      } catch (e) {
        debugPrint('pdf cache read: $e');
      }
    }

    final bytes = quote != null
        ? await PdfService.generarPDFFromQuote(
            quote,
            languageCode: languageCode,
          )
        : await PdfService.generarPDF(cot, languageCode: languageCode);

    if (orgId != null && orgId.isNotEmpty) {
      try {
        await PdfLocalArchive.instance.saveQuotePdf(
          organizationId: orgId,
          quoteId: cot.id,
          number: cot.numero,
          bytes: bytes,
        );
      } catch (_) {}
    }
    return bytes;
  }

  /// WhatsApp: adjunta PDF vía sheet nativo (el usuario elige WhatsApp).
  /// Si [preferTextOnly] y hay teléfono, abre wa.me solo con texto (fallback).
  Future<void> shareWhatsApp({
    required Cotizacion cot,
    OrgClient? client,
    String? shareUrl,
    String? quoteId,
    Quote? quote,
    String languageCode = 'es',
    bool attachPdf = true,
  }) async {
    if (attachPdf && !kIsWeb) {
      await shareQuotePdf(
        cot: cot,
        quote: quote,
        client: client,
        shareUrl: shareUrl,
        quoteId: quoteId,
        languageCode: languageCode,
      );
      return;
    }

    final phone = (client?.phone ?? '')
        .replaceAll(RegExp(r'[^\d+]'), '')
        .replaceAll('+', '');
    final text = buildShareMessage(
      number: cot.numero,
      clientName: cot.cliente,
      totalLabel: '\$${cot.total.toStringAsFixed(2)}',
      shareUrl: shareUrl,
    );
    final uri = phone.isEmpty
        ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')
        : Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir WhatsApp');
    }
    if (quoteId != null) await markSent(quoteId);
  }

  Future<void> shareEmail({
    required Cotizacion cot,
    OrgClient? client,
    String? shareUrl,
    String? quoteId,
    Quote? quote,
    String languageCode = 'es',
    bool attachPdf = true,
  }) async {
    if (attachPdf && !kIsWeb) {
      await shareQuotePdf(
        cot: cot,
        quote: quote,
        client: client,
        shareUrl: shareUrl,
        quoteId: quoteId,
        languageCode: languageCode,
      );
      return;
    }

    final email = client?.email?.trim() ?? '';
    final subject = 'Cotización ${cot.numero} — ${SaasConfig.productName}';
    final body = buildShareMessage(
      number: cot.numero,
      clientName: cot.cliente,
      totalLabel: '\$${cot.total.toStringAsFixed(2)}',
      shareUrl: shareUrl,
    );
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': subject, 'body': body},
    );
    if (!await launchUrl(uri)) {
      throw Exception('No se pudo abrir el cliente de correo');
    }
    if (quoteId != null) await markSent(quoteId);
  }
}
