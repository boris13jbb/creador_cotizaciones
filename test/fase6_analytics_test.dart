import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/config/saas_config.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/models/entitlements.dart';
import 'package:creador_cotizaciones/saas/models/org_quote_stats.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/services/entitlements_calculator.dart';
import 'package:creador_cotizaciones/saas/services/org_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 31, 12);

  Quote buildQuote({
    required String id,
    required QuoteStatus status,
    required int cents,
    required DateTime updatedAt,
    DateTime? createdAt,
  }) {
    return Quote(
      id: id,
      organizationId: 'org',
      number: id,
      sequence: 1,
      status: status,
      clientName: 'C$id',
      issueDate: updatedAt,
      items: const [],
      total: MoneyCents(cents),
      createdByUid: 'u',
      createdAt: createdAt ?? updatedAt,
      updatedAt: updatedAt,
    );
  }

  test('OrgQuoteStats calcula pipeline, conversión y seguimiento', () {
    final stats = OrgQuoteStats.fromQuotes([
      buildQuote(
        id: '1',
        status: QuoteStatus.sent,
        cents: 10000,
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      buildQuote(
        id: '2',
        status: QuoteStatus.accepted,
        cents: 20000,
        updatedAt: now,
      ),
      buildQuote(
        id: '3',
        status: QuoteStatus.rejected,
        cents: 5000,
        updatedAt: now,
      ),
      buildQuote(
        id: '4',
        status: QuoteStatus.viewed,
        cents: 8000,
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ], now: now);

    expect(stats.totalQuotes, 4);
    expect(stats.countOf(QuoteStatus.sent), 1);
    expect(stats.pipelineCents, 10000 + 8000);
    expect(stats.acceptedCents, 20000);
    expect(stats.acceptanceRate, closeTo(0.5, 0.001));
    expect(stats.staleFollowUps, 1);
  });

  test('CSV export incluye cabecera y filas', () {
    final csv = OrgAnalyticsService.instance.quotesToCsv([
      buildQuote(
        id: 'q1',
        status: QuoteStatus.draft,
        cents: 1234,
        updatedAt: now,
      ),
    ]);
    expect(csv.split('\n').first, contains('totalCents'));
    expect(csv, contains('q1'));
    expect(csv, contains('1234'));
    expect(csv, contains('draft'));
  });

  test('Pro/Business habilitan equipo y CSV; Free no', () {
    final calc = EntitlementsService.instance;
    final free = calc.evaluate(
      Entitlements(
        uid: 'u',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      now: now,
    );
    expect(free.canManageTeam, isFalse);
    expect(free.canExportReportsCsv, isFalse);
    expect(free.canViewReports, isTrue);

    final pro = calc.evaluate(
      Entitlements(
        uid: 'u',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      now: now,
    );
    expect(pro.canManageTeam, isTrue);
    expect(pro.canExportReportsCsv, isTrue);
    expect(pro.maxSeats, SaasConfig.proMaxSeats);

    final biz = calc.evaluate(
      Entitlements(
        uid: 'u',
        plan: SubscriptionPlan.business,
        subscriptionStatus: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      now: now,
    );
    expect(biz.maxSeats, SaasConfig.businessMaxSeats);
  });

  test('trial otorga equipo Pro (asientos Pro)', () {
    final access = EntitlementsService.instance.evaluate(
      Entitlements(
        uid: 'u',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'trialing',
        trialEndsAt: now.add(const Duration(days: 5)),
        createdAt: now,
        updatedAt: now,
      ),
      now: now,
    );
    expect(access.canManageTeam, isTrue);
    expect(access.maxSeats, SaasConfig.proMaxSeats);
  });
}
