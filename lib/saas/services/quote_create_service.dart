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

/// Error de createOrgQuote con código callable preservado (no genérico).
class QuoteCreateException implements Exception {
  QuoteCreateException({required this.code, required this.message, this.cause});

  /// Código normalizado (`unauthenticated`, `permission-denied`, …).
  final String code;
  final String message;
  final Object? cause;

  bool get isUnauthenticated => code == 'unauthenticated';
  bool get isTransient =>
      code == 'unavailable' || code == 'deadline-exceeded' || code == 'aborted';

  @override
  String toString() => 'QuoteCreateException($code): $message';
}

/// Creación autoritativa de cotizaciones vía Cloud Function `createOrgQuote`.
class QuoteCreateService {
  QuoteCreateService._();
  static final QuoteCreateService instance = QuoteCreateService._();

  static bool isLimitExceededError(Object error) {
    if (error is QuoteLimitExceededException) return true;
    if (error is QuoteCreateException && error.code == 'resource-exhausted') {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('resource-exhausted') ||
        text.contains('límite del plan') ||
        text.contains('limite del plan');
  }

  /// Interpreta el flag de cola offline (`__isNew`) tras JSON encode/decode.
  static bool payloadMarksNewQuote(Map<String, dynamic> payload) {
    final v = payload['__isNew'];
    return v == true || v == 1 || v == 'true' || v == '1';
  }

  /// Región de la Function Gen2 desplegada (`setGlobalOptions` en functions).
  static const String functionsRegion = 'us-central1';

  /// Códigos callable que se conservan para UI/sync (Fase 3).
  static const Set<String> knownCallableCodes = {
    'unauthenticated',
    'permission-denied',
    'failed-precondition',
    'resource-exhausted',
    'unavailable',
    'deadline-exceeded',
    'internal',
    'not-found',
    'invalid-argument',
    'aborted',
  };

  /// Mapeo puro de error callable → excepción tipada (testeable sin Firebase).
  static Exception mapFunctionsError(
    String code,
    String? message, {
    Object? cause,
  }) {
    final normalized = _normalizeCode(code);
    final msg = _safeUserMessage(normalized, message);

    if (normalized == 'resource-exhausted' ||
        msg.toLowerCase().contains('límite del plan') ||
        msg.toLowerCase().contains('limite del plan')) {
      return QuoteLimitExceededException(msg);
    }

    return QuoteCreateException(
      code: normalized.isEmpty ? 'unknown' : normalized,
      message: msg,
      cause: cause,
    );
  }

  static String _normalizeCode(String code) {
    var c = code.trim().toLowerCase().replaceAll('_', '-');
    // HTTP/GCP a veces envía "UNAUTHENTICATED" o "401".
    if (c == '401' || c == 'unauthorized') return 'unauthenticated';
    if (c.startsWith('functions/')) {
      c = c.substring('functions/'.length);
    }
    if (c.startsWith('firebase-functions/')) {
      c = c.substring('firebase-functions/'.length);
    }
    return c;
  }

  static String _safeUserMessage(String code, String? message) {
    final raw = (message ?? '').trim();
    // Nunca devolver cuerpos que puedan filtrar tokens.
    if (raw.toLowerCase().contains('bearer ') ||
        raw.toLowerCase().contains('idtoken')) {
      return _fallbackMessage(code);
    }
    if (raw.isNotEmpty) return raw;
    return _fallbackMessage(code);
  }

  static String _fallbackMessage(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'Debes iniciar sesión para continuar.';
      case 'permission-denied':
        return 'No tienes permiso para crear cotizaciones.';
      case 'resource-exhausted':
        return 'Límite del plan alcanzado.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Servicio no disponible. Reintenta en unos segundos.';
      case 'failed-precondition':
        return 'No se cumplen las condiciones para crear la cotización.';
      default:
        return 'No se pudo crear la cotización ($code).';
    }
  }

  /// Crea (o reintenta idempotente) una cotización en el servidor.
  Future<Quote> createOrgQuote(Quote quote) async {
    final orgId = quote.organizationId.trim();
    if (orgId.isEmpty) {
      throw QuoteCreateException(
        code: 'invalid-argument',
        message: 'organizationId requerido para crear cotización.',
      );
    }
    if (quote.id.trim().isEmpty) {
      throw QuoteCreateException(
        code: 'invalid-argument',
        message: 'quote.id requerido para crear cotización.',
      );
    }

    final payload = <String, dynamic>{
      'organizationId': orgId,
      'quoteId': quote.id,
      'quote': quote.toMap(),
    };

    try {
      // Token fresco antes del callable: evita unauthenticated por sesión fría.
      await AuthService.instance.ensureCallableAuth(forceRefresh: true);
      final raw = saasUseRestBackend
          ? await _callHttp(payload)
          : await _callCallable(payload);
      final map = _extractQuoteMap(raw, fallback: quote);
      return Quote.fromMap(map);
    } on QuoteLimitExceededException {
      rethrow;
    } on QuoteCreateException {
      rethrow;
    } on CallableAuthException catch (e) {
      throw QuoteCreateException(code: e.code, message: e.message, cause: e);
    } on FirebaseFunctionsException catch (e) {
      // details puede traer código Admin (p. ej. app/no-app) sin secretos.
      debugPrint(
        'createOrgQuote FunctionsException '
        'code=${e.code} details=${e.details}',
      );
      throw mapFunctionsError(e.code, e.message, cause: e);
    } catch (e) {
      // Conservar causa; no sustituir todos los fallos por unauthenticated.
      final text = e.toString();
      if (text.toLowerCase().contains('unauthenticated') ||
          text.contains('UNAUTHENTICATED')) {
        throw mapFunctionsError('unauthenticated', null, cause: e);
      }
      throw QuoteCreateException(
        code: 'internal',
        message: 'No se pudo crear la cotización.',
        cause: e,
      );
    }
  }

  Future<Map<String, dynamic>> _callCallable(Map<String, dynamic> data) async {
    final callable = FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: functionsRegion,
    ).httpsCallable('createOrgQuote');
    final result = await callable.call(data);
    final raw = result.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw QuoteCreateException(
      code: 'internal',
      message: 'Respuesta inválida de createOrgQuote',
    );
  }

  Future<Map<String, dynamic>> _callHttp(Map<String, dynamic> data) async {
    // Misma política que BillingService: refrescar token antes del callable HTTP.
    final session = await AuthService.instance.ensureValidRestSession();
    final projectId = IdentityToolkitClient.instance.projectId.isNotEmpty
        ? IdentityToolkitClient.instance.projectId
        : Firebase.app().options.projectId;
    final base = SaasConfig.functionsBaseUrl.isNotEmpty
        ? SaasConfig.functionsBaseUrl
        : 'https://$functionsRegion-$projectId.cloudfunctions.net';
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
          ? (err['message'] as String? ?? 'Error HTTP ${res.statusCode}')
          : 'Error HTTP ${res.statusCode}';
      throw mapFunctionsError(code, message);
    }
    if (body is Map && body['result'] is Map) {
      return Map<String, dynamic>.from(body['result'] as Map);
    }
    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }
    throw QuoteCreateException(
      code: 'internal',
      message: 'Respuesta inválida de createOrgQuote HTTP',
    );
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
}
