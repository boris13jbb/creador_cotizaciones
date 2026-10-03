import 'package:flutter/foundation.dart';

/// Registro estructurado local (y puente a reportes remotos).
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  void info(String event, {Map<String, Object?> fields = const {}}) =>
      _log('INFO', event, fields);

  void warn(String event, {Map<String, Object?> fields = const {}}) =>
      _log('WARN', event, fields);

  void error(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    final merged = <String, Object?>{
      ...fields,
      if (error != null) 'error': '$error',
    };
    _log('ERROR', event, merged);
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  void metric(
    String name, {
    num? value,
    Map<String, Object?> fields = const {},
  }) {
    _log('METRIC', name, {...fields, if (value != null) 'value': value});
  }

  void _log(String level, String event, Map<String, Object?> fields) {
    final payload = <String, Object?>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'event': event,
      ...fields,
    };
    debugPrint('[CotiApp] $payload');
  }
}
