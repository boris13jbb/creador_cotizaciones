import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import 'app_logger.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';

/// Captura de errores de cliente para soporte (Firestore + logs).
class ErrorReportService {
  ErrorReportService._();
  static final ErrorReportService instance = ErrorReportService._();

  DateTime? _lastSent;
  static const _minInterval = Duration(seconds: 15);

  Future<void> report({
    required String message,
    StackTrace? stackTrace,
    String? uid,
    String? organizationId,
    Map<String, dynamic> context = const {},
  }) async {
    final now = DateTime.now().toUtc();
    if (_lastSent != null && now.difference(_lastSent!) < _minInterval) {
      return;
    }
    _lastSent = now;

    AppLogger.instance.error(
      'client_error',
      error: message,
      stackTrace: stackTrace,
      fields: {'uid': uid, 'organizationId': organizationId, ...context},
    );

    final id = const Uuid().v4();
    final data = <String, dynamic>{
      'id': id,
      'message': message,
      'stack': stackTrace?.toString(),
      'uid': uid,
      'organizationId': organizationId,
      'platform': defaultTargetPlatform.name,
      'context': context,
      'createdAt': now.toIso8601String(),
    };

    try {
      if (saasUseRestBackend) {
        final session = AuthService.instance.restSession;
        if (session == null) return;
        await FirestoreRestClient.instance.upsertDocument(
          session: session,
          path: 'errorReports/$id',
          data: data,
        );
        return;
      }
      await FirebaseFirestore.instance
          .collection('errorReports')
          .doc(id)
          .set(data);
    } catch (e, st) {
      debugPrint('ErrorReportService: $e\n$st');
    }
  }
}
