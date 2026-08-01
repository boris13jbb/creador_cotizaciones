import '../config/saas_config.dart';
import '../models/org_quote_stats.dart';
import '../models/quote.dart';
import 'app_logger.dart';
import 'identity_toolkit_client.dart';
import 'org_quote_repository.dart';

/// KPIs y agregaciones comerciales sobre cotizaciones de la org.
class OrgAnalyticsService {
  OrgAnalyticsService._();
  static final OrgAnalyticsService instance = OrgAnalyticsService._();

  static const _pageSize = 100;
  static const _maxPages = 10; // hasta 1000 cotizaciones

  Future<List<Quote>> loadQuotesForStats({
    required String orgId,
    AuthSession? session,
  }) async {
    final all = <Quote>[];
    String? cursor;
    for (var i = 0; i < _maxPages; i++) {
      final page = await OrgQuoteRepository.instance.listQuotes(
        orgId: orgId,
        limit: _pageSize,
        startAfterUpdatedAt: cursor,
        session: session,
      );
      all.addAll(page.items);
      if (!page.hasMore || page.nextCursor == null) break;
      cursor = page.nextCursor;
    }
    AppLogger.instance.metric(
      'org_quotes_loaded_for_stats',
      value: all.length,
      fields: {'orgId': orgId},
    );
    return all;
  }

  Future<OrgQuoteStats> computeStats({
    required String orgId,
    AuthSession? session,
    DateTime? now,
  }) async {
    final quotes = await loadQuotesForStats(orgId: orgId, session: session);
    final stats = OrgQuoteStats.fromQuotes(
      quotes,
      now: now,
      unusualPerDay: SaasConfig.unusualQuotesPerDay,
    );
    if (stats.unusualUsage) {
      AppLogger.instance.warn(
        'unusual_quote_volume',
        fields: {
          'orgId': orgId,
          'createdLast24h': stats.createdLast24h,
          'threshold': SaasConfig.unusualQuotesPerDay,
        },
      );
    }
    return stats;
  }

  String quotesToCsv(Iterable<Quote> quotes) {
    final buf = StringBuffer();
    buf.writeln(
      'id,number,status,clientName,totalCents,currency,issueDate,dueDate,createdByUid,updatedAt',
    );
    for (final q in quotes) {
      buf.writeln(
        [
          _esc(q.id),
          _esc(q.number),
          _esc(q.status.id),
          _esc(q.clientName),
          q.total.cents,
          _esc(q.currency),
          _esc(q.issueDate.toIso8601String()),
          _esc(q.dueDate?.toIso8601String() ?? ''),
          _esc(q.createdByUid),
          _esc(q.updatedAt.toIso8601String()),
        ].join(','),
      );
    }
    return buf.toString();
  }

  String _esc(String value) {
    final needs = value.contains(',') || value.contains('"') || value.contains('\n');
    if (!needs) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
