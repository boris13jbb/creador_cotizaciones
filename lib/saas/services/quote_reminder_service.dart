import '../domain/org_enums.dart';
import '../models/quote.dart';

/// Recordatorios ligeros de seguimiento comercial (Fase 5).
class QuoteReminderService {
  QuoteReminderService._();
  static final QuoteReminderService instance = QuoteReminderService._();

  static const defaultFollowUpDays = 7;

  /// Cotizaciones enviadas o vistas sin cierre, más antiguas que [days].
  List<Quote> pendingFollowUp(
    Iterable<Quote> quotes, {
    int days = defaultFollowUpDays,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(Duration(days: days));
    return [
      for (final q in quotes)
        if (_needsFollowUp(q) && q.updatedAt.isBefore(cutoff)) q,
    ];
  }

  /// Aviso a partir de fechas de [Cotizacion]-like (número + estado + fecha ISO).
  int countStaleSent({
    required Iterable<({String status, DateTime updatedAt})> items,
    int days = defaultFollowUpDays,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(Duration(days: days));
    var n = 0;
    for (final i in items) {
      final st = QuoteStatus.fromId(i.status);
      if ((st == QuoteStatus.sent || st == QuoteStatus.viewed) &&
          i.updatedAt.isBefore(cutoff)) {
        n++;
      }
    }
    return n;
  }

  bool _needsFollowUp(Quote q) {
    return q.status == QuoteStatus.sent || q.status == QuoteStatus.viewed;
  }
}
