import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/cotizacion.dart';
import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import '../domain/org_enums.dart';
import '../models/org_client.dart';
import '../models/quote.dart';
import 'auth_service.dart';
import 'cloud_cotizacion_repository.dart';
import 'firestore_rest_client.dart';

/// Comunicación y enlaces de cotización (WhatsApp, correo, share link).
class QuoteShareService {
  QuoteShareService._();
  static final QuoteShareService instance = QuoteShareService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String _message({
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

  /// Crea un enlace de solo lectura (7 días). Requiere reglas/Functions para `viewed`.
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

  Future<void> shareWhatsApp({
    required Cotizacion cot,
    OrgClient? client,
    String? shareUrl,
    String? quoteId,
  }) async {
    final phone = (client?.phone ?? '')
        .replaceAll(RegExp(r'[^\d+]'), '')
        .replaceAll('+', '');
    final text = _message(
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
  }) async {
    final email = client?.email?.trim() ?? '';
    final subject = 'Cotización ${cot.numero} — ${SaasConfig.productName}';
    final body = _message(
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
