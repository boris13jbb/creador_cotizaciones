import '../domain/org_enums.dart';
import '../../core/utils/money_cents.dart';
import 'quote.dart';

/// Agregados comerciales de cotizaciones de una organización.
class OrgQuoteStats {
  final int totalQuotes;
  final Map<String, int> countByStatus;
  final Map<String, int> centsByStatus;
  final int pipelineCents;
  final int acceptedCents;
  final int rejectedCents;
  final double acceptanceRate;
  final int staleFollowUps;
  final int createdLast24h;
  final bool unusualUsage;
  final DateTime computedAt;

  const OrgQuoteStats({
    required this.totalQuotes,
    required this.countByStatus,
    required this.centsByStatus,
    required this.pipelineCents,
    required this.acceptedCents,
    required this.rejectedCents,
    required this.acceptanceRate,
    required this.staleFollowUps,
    required this.createdLast24h,
    required this.unusualUsage,
    required this.computedAt,
  });

  int countOf(QuoteStatus status) => countByStatus[status.id] ?? 0;

  MoneyCents get pipelineTotal => MoneyCents(pipelineCents);
  MoneyCents get acceptedTotal => MoneyCents(acceptedCents);

  factory OrgQuoteStats.fromQuotes(
    Iterable<Quote> quotes, {
    DateTime? now,
    int unusualPerDay = 50,
    int followUpDays = 7,
  }) {
    final n = (now ?? DateTime.now()).toUtc();
    final counts = <String, int>{};
    final cents = <String, int>{};
    var pipeline = 0;
    var accepted = 0;
    var rejected = 0;
    var stale = 0;
    var last24 = 0;
    final dayAgo = n.subtract(const Duration(hours: 24));
    final cutoff = n.subtract(Duration(days: followUpDays));

    for (final q in quotes) {
      final st = q.status.id;
      counts[st] = (counts[st] ?? 0) + 1;
      cents[st] = (cents[st] ?? 0) + q.total.cents;

      if (q.status == QuoteStatus.accepted) {
        accepted += q.total.cents;
      } else if (q.status == QuoteStatus.rejected) {
        rejected += q.total.cents;
      } else if (q.status == QuoteStatus.sent ||
          q.status == QuoteStatus.viewed ||
          q.status == QuoteStatus.draft) {
        pipeline += q.total.cents;
      }

      if ((q.status == QuoteStatus.sent || q.status == QuoteStatus.viewed) &&
          q.updatedAt.isBefore(cutoff)) {
        stale++;
      }
      if (q.createdAt.isAfter(dayAgo)) {
        last24++;
      }
    }

    final decided =
        (counts[QuoteStatus.accepted.id] ?? 0) +
        (counts[QuoteStatus.rejected.id] ?? 0);
    final acceptedCount = counts[QuoteStatus.accepted.id] ?? 0;
    final rate = decided == 0 ? 0.0 : acceptedCount / decided;

    return OrgQuoteStats(
      totalQuotes: quotes.length,
      countByStatus: counts,
      centsByStatus: cents,
      pipelineCents: pipeline,
      acceptedCents: accepted,
      rejectedCents: rejected,
      acceptanceRate: rate,
      staleFollowUps: stale,
      createdLast24h: last24,
      unusualUsage: last24 >= unusualPerDay,
      computedAt: n,
    );
  }
}
