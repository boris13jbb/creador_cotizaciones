import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../saas/domain/org_enums.dart';
import '../../saas/models/org_activity.dart';
import '../../saas/models/org_quote_stats.dart';
import '../../saas/models/quote.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/activity_repository.dart';
import '../../saas/services/csv_export_service.dart';
import '../../saas/services/org_analytics_service.dart';
import '../../screens/account/pricing_screen.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/widgets/async_state_view.dart';

/// Dashboard de KPIs, conversión y exportación CSV.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  Object? _error;
  OrgQuoteStats? _stats;
  List<Quote> _quotes = const [];
  List<OrgActivity> _activities = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final orgId = auth.organizationId;
    if (orgId == null || orgId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Necesitas una organización para ver reportes.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = auth.restSession;
      final quotes = await OrgAnalyticsService.instance.loadQuotesForStats(
        orgId: orgId,
        session: session,
      );
      final stats = OrgQuoteStats.fromQuotes(quotes);
      final activities = await ActivityRepository.instance.listRecent(
        organizationId: orgId,
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _quotes = quotes;
        _stats = stats;
        _activities = activities;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    final auth = context.read<AuthController>();
    if (!auth.access.canExportReportsCsv) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportar CSV requiere Pro o Business.')),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PricingScreen()),
      );
      return;
    }
    final csv = OrgAnalyticsService.instance.quotesToCsv(_quotes);
    await CsvExportService.instance.shareCsv(
      fileName: 'cotiapp_quotes_${DateTime.now().toIso8601String().split('T').first}.csv',
      csvContent: csv,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar = !widget.embeddedInShell || useRail;
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final pct = NumberFormat.percentPattern();
    final stats = _stats;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('Reportes'),
              actions: [
                IconButton(
                  tooltip: 'Exportar CSV',
                  onPressed: _loading ? null : _exportCsv,
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: ContentConstraint(
          padding: AppSpacing.pageWide,
          child: AsyncStateView(
            loading: _loading,
            error: _error?.toString(),
            isEmpty: !_loading && stats == null,
            emptyTitle: 'Sin datos',
            emptySubtitle: 'Guarda cotizaciones para ver KPIs.',
            onRetry: _load,
            child: stats == null
                ? const SizedBox.shrink()
                : ListView(
                    children: [
                      if (!showAppBar)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: _exportCsv,
                                icon: const Icon(Icons.download_outlined),
                              ),
                              IconButton(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        'Rendimiento comercial',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _KpiCard(
                            label: 'Cotizaciones',
                            value: '${stats.totalQuotes}',
                          ),
                          _KpiCard(
                            label: 'Pipeline',
                            value: money.format(stats.pipelineTotal.asDecimal),
                          ),
                          _KpiCard(
                            label: 'Aceptadas',
                            value: money.format(stats.acceptedTotal.asDecimal),
                          ),
                          _KpiCard(
                            label: 'Conversión',
                            value: pct.format(stats.acceptanceRate),
                          ),
                          _KpiCard(
                            label: 'Seguimiento',
                            value: '${stats.staleFollowUps}',
                          ),
                          _KpiCard(
                            label: 'Últimas 24h',
                            value: '${stats.createdLast24h}',
                          ),
                        ],
                      ),
                      if (stats.unusualUsage) ...[
                        const SizedBox(height: AppSpacing.md),
                        Card(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.45),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_outlined),
                            title: Text(
                              'Uso elevado: ${stats.createdLast24h} cotizaciones en 24h',
                            ),
                            subtitle: const Text(
                              'Revisa actividad anómala o automatizaciones.',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Por estado',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _StatusBars(stats: stats),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Actividad reciente',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_activities.isEmpty)
                        Text(
                          'Aún no hay eventos de auditoría.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        ..._activities.take(12).map(
                          (a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.timeline),
                            title: Text(a.message),
                            subtitle: Text(
                              '${a.type} · ${DateFormat.yMMMd('es').add_Hm().format(a.createdAt.toLocal())}',
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBars extends StatelessWidget {
  const _StatusBars({required this.stats});
  final OrgQuoteStats stats;

  @override
  Widget build(BuildContext context) {
    final maxCount = QuoteStatus.values
        .map((s) => stats.countOf(s))
        .fold<int>(0, (a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final status in QuoteStatus.values)
          if (stats.countOf(status) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      status.id,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxCount == 0
                            ? 0
                            : stats.countOf(status) / maxCount,
                        minHeight: 12,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${stats.countOf(status)}'),
                ],
              ),
            ),
      ],
    );
  }
}
