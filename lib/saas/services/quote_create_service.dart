import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import '../models/quote.dart';
import 'auth_service.dart';
import 'identity_toolkit_client.dart';

/// Error de cupo Free (mapeado desde `resource-exhausted` de createOrgQuote).
class QuoteLimitExceededException implements Exception {
  QuoteLimitExceededException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Creación autoritativa de cotizaciones vía Cloud Function `createOrgQuote`.
class QuoteCreateService {
  QuoteCreateService._();
  static final QuoteCreateService instance = QuoteCreateService._();

  static bool isLimitExceededError(Object error) {
    if (error is QuoteLimitExceededException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('resource-exhausted') ||
        text.contains('límite del plan') ||
        text.contains('limite del plan');
  }

  /// Crea (o reintenta idempotente) una cotización en el servidor.
  Future<Quote> createOrgQuote(Quote quote) async {
    final orgId = quote.organizationId.trim();
    if (orgId.isEmpty) {
      throw Exception('organizationId requerido para crear cotización.');
    }
    if (quote.id.trim().isEmpty) {
      throw Exception('quote.id requerido para crear cotización.');
    }

    final payload = <String, dynamic>{
      'organizationId': orgId,
      'quoteId': quote.id,
      'quote': quote.toMap(),
    };

    try {
      final raw = saasUseRestBackend
          ? await _callHttp(payload)
          : await _callCallable(payload);
      final map = _extractQuoteMap(raw, fallback: quote);
      return Quote.fromMap(map);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsError(e.code, e.message);
    }
  }

  Future<Map<String, dynamic>> _callCallable(Map<String, dynamic> data) async {
    final callable = FirebaseFunctions.instance.httpsCallable('createOrgQuote');
    final result = await callable.call(data);
    final raw = result.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw Exception('Respuesta inválida de createOrgQuote');
  }

  Future<Map<String, dynamic>> _callHttp(Map<String, dynamic> data) async {
    final session = AuthService.instance.restSession;
    if (session == null) {
      throw Exception('Sesión REST no disponible');
    }
    final projectId = IdentityToolkitClient.instance.projectId.isNotEmpty
        ? IdentityToolkitClient.instance.projectId
        : Firebase.app().options.projectId;
    final base = SaasConfig.functionsBaseUrl.isNotEmpty
        ? SaasConfig.functionsBaseUrl
        : 'https://us-central1-$projectId.cloudfunctions.net';
    final uri = Uri.parse('$base/createOrgQuote');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.idToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': data}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = body is Map ? body['error'] : null;
      final code = err is Map
          ? (err['status'] as String? ?? err['code'] as String? ?? '')
          : '';
      final message = err is Map
          ? (err['message'] as String? ?? res.body)
          : res.body;
      throw _mapFunctionsError(code, message);
    }
    if (body is Map && body['result'] is Map) {
      return Map<String, dynamic>.from(body['result'] as Map);
    }
    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }
    throw Exception('Respuesta inválida de createOrgQuote HTTP');
  }

  Map<String, dynamic> _extractQuoteMap(
    Map<String, dynamic> raw, {
    required Quote fallback,
  }) {
    final quoteRaw = raw['quote'];
    if (quoteRaw is Map) {
      return Map<String, dynamic>.from(quoteRaw);
    }
    debugPrint('createOrgQuote sin quote en respuesta; se conserva local');
    return fallback.toMap();
  }

  Exception _mapFunctionsError(String code, String? message) {
    final normalized = code.toLowerCase().replaceAll('_', '-');
    final msg = (message == null || message.trim().isEmpty)
        ? 'No se pudo crear la cotización'
        : message.trim();
    if (normalized == 'resource-exhausted' ||
        msg.toLowerCase().contains('límite del plan') ||
        msg.toLowerCase().contains('limite del plan')) {
      return QuoteLimitExceededException(msg);
    }
    if (normalized == 'permission-denied') {
      return Exception(msg);
    }
    if (normalized == 'unauthenticated') {
      return Exception('Debes iniciar sesión para continuar.');
    }
    return Exception(msg);
  }
}
