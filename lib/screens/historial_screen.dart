import 'package:flutter/material.dart';
import '../l10n/l10n_ext.dart';
import 'package:provider/provider.dart';

import '../models/cotizacion.dart';
import '../saas/domain/org_enums.dart';
import '../saas/historial/historial_query.dart';
import '../saas/providers/auth_controller.dart';
import '../saas/services/quote_mapper.dart';
import '../saas/services/quote_reminder_service.dart';
import '../saas/services/quote_share_ui.dart';
import '../services/db_service.dart';
import '../services/pdf_share_service.dart';
import '../ui/layout/responsive.dart';
import '../ui/widgets/async_state_view.dart';
import '../widgets/cotizacion_card.dart';
import '../widgets/quote_conflict_dialog.dart';
import 'nueva_cotizacion_screen.dart';
import 'preview_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  static const _pageSize = 20;

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  final List<Cotizacion> _items = [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _remoteFailed = false;
  Object? _error;
  String? _statusFilter;
  String? _busyQuoteId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading || _refreshing) return;
    if (_queryController.text.trim().isNotEmpty) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial({bool soft = false}) async {
    if (_loading && soft) return;
    if (_refreshing) return;

    setState(() {
      if (soft && _items.isNotEmpty) {
        _refreshing = true;
      } else {
        _loading = true;
        _items.clear();
        _nextCursor = null;
        _hasMore = false;
      }
      _error = null;
      _remoteFailed = false;
    });

    try {
      final page = await DBService.instance.obtenerPagina(
        limit: _pageSize,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        if (!soft || _items.isEmpty) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items
            ..clear()
            ..addAll(page.items);
        }
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _remoteFailed = page.remoteFailed;
        _loading = false;
        _refreshing = false;
        if (page.remoteFailed && page.items.isEmpty) {
          _error = Exception(context.l10n.historyLoadFailed);
        }
      });
      if (page.remoteFailed && page.items.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.historyRemoteFailedSnack),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading || _refreshing) return;
    setState(() => _loadingMore = true);
    try {
      final page = await DBService.instance.obtenerPagina(
        limit: _pageSize,
        startAfterUpdatedAt: _nextCursor,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        final existing = {for (final c in _items) c.id};
        for (final c in page.items) {
          if (!existing.contains(c.id)) {
            _items.add(c);
            existing.add(c.id);
          }
        }
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        if (page.remoteFailed) _remoteFailed = true;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        // Conservar lista ya cargada; solo avisar.
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.historyLoadMoreFailed(
                '$e'.replaceFirst('Exception: ', ''),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _runAction(
    String quoteId,
    Future<void> Function() action,
  ) async {
    if (_busyQuoteId != null) return;
    setState(() => _busyQuoteId = quoteId);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyQuoteId = null);
    }
  }

  Future<bool> _resolveConflictIfNeeded(Cotizacion cot) async {
    if (cot.offlineSyncStatus != 'conflict') return true;
    final resolved = await showQuoteConflictDialog(
      context,
      quoteId: cot.id,
      quoteNumber: cot.numero,
    );
    if (resolved != null) await _loadInitial(soft: true);
    return resolved == true;
  }

  @override
  Widget build(BuildContext context) {
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar = !widget.embeddedInShell || useRail;
    final query = _queryController.text;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(context.l10n.navHistory),
              actions: [
                IconButton(
                  tooltip: context.l10n.refresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: (_loading || _refreshing)
                      ? null
                      : () => _loadInitial(soft: true),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: ContentConstraint(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: context.l10n.search,
                    hintText: context.l10n.searchHintQuotes,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.l10n.clear,
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _queryController.clear();
                              setState(() {});
                            },
                          ),
                    helperText: _hasMore
                        ? context.l10n.searchHelperLoadMore
                        : context.l10n.searchHelperLoaded,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    FilterChip(
                      label: Text(context.l10n.all),
                      selected: _statusFilter == null,
                      onSelected: (_) {
                        setState(() => _statusFilter = null);
                        _loadInitial();
                      },
                    ),
                    const SizedBox(width: 8),
                    for (final s in HistorialQuery.filterableStatuses) ...[
                      FilterChip(
                        label: Text(
                          HistorialQuery.statusLabel(s, context.l10n),
                        ),
                        selected: _statusFilter == s.id,
                        onSelected: (_) {
                          setState(() => _statusFilter = s.id);
                          _loadInitial();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (_remoteFailed && _items.isNotEmpty)
                Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.55),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: Text(context.l10n.historyRemoteFailedBanner),
                    subtitle: Text(context.l10n.historyRemoteFailedSubtitle),
                    trailing: TextButton(
                      onPressed: (_loading || _refreshing)
                          ? null
                          : () => _loadInitial(soft: true),
                      child: Text(context.l10n.retry),
                    ),
                  ),
                ),
              Builder(
                builder: (context) {
                  final now = DateTime.now().toUtc();
                  final stale = QuoteReminderService.instance.countStaleSent(
                    items: _items.map(
                      (c) => (
                        status: c.quoteStatus ?? '',
                        updatedAt: DateTime.tryParse(c.fecha)?.toUtc() ?? now,
                      ),
                    ),
                  );
                  if (stale == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      0,
                    ),
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: Text(context.l10n.staleSentBanner(stale)),
                        trailing: TextButton(
                          onPressed: () {
                            setState(() => _statusFilter = QuoteStatus.sent.id);
                            _loadInitial();
                          },
                          child: Text(context.l10n.viewSent),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (!showAppBar)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: context.l10n.refresh,
                    onPressed: (_loading || _refreshing)
                        ? null
                        : () => _loadInitial(soft: true),
                    icon: _refreshing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ),
              if (_refreshing) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final filtered = HistorialQuery.applySearch(_items, _queryController.text);
    final hasQuery = _queryController.text.trim().isNotEmpty;
    final hasFilter = _statusFilter != null;

    final l10n = context.l10n;
    String emptyTitle;
    String emptySubtitle;
    IconData emptyIcon;
    if (hasQuery) {
      emptyTitle = l10n.noSearchResults;
      emptySubtitle = _hasMore
          ? l10n.noSearchResultsLoadMore
          : l10n.noSearchResultsHint(_queryController.text.trim());
      emptyIcon = Icons.search_off;
    } else if (hasFilter) {
      emptyTitle = l10n.noQuotesForStatus;
      emptySubtitle = l10n.noQuotesForStatusHint(
        HistorialQuery.statusLabelForId(_statusFilter, l10n),
      );
      emptyIcon = Icons.filter_alt_off_outlined;
    } else {
      emptyTitle = l10n.noQuotesYet;
      emptySubtitle = l10n.noQuotesYetHint;
      emptyIcon = Icons.history;
    }

    return AsyncStateView(
      loading: _loading,
      error: _error != null && _items.isEmpty ? _error : null,
      isEmpty: !_loading && _items.isEmpty && !hasQuery,
      emptyIcon: emptyIcon,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      onRetry: () => _loadInitial(),
      child: filtered.isEmpty
          ? AsyncStateView(
              isEmpty: true,
              emptyIcon: emptyIcon,
              emptyTitle: emptyTitle,
              emptySubtitle: emptySubtitle,
              onRetry: _hasMore ? _loadMore : null,
              retryLabel: _hasMore ? l10n.loadMore : null,
              child: const SizedBox.shrink(),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              itemCount: filtered.length + ((_hasMore || _loadingMore) ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= filtered.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _loadMore,
                              child: Text(context.l10n.loadMore),
                            ),
                    ),
                  );
                }

                final cot = filtered[index];
                final hasOrg =
                    context.read<AuthController>().organizationId != null;
                final busy = _busyQuoteId != null;
                return CotizacionCard(
                  cotizacion: cot,
                  actionsEnabled: !busy,
                  onTap: () => _runAction(cot.id, () async {
                    if (!await _resolveConflictIfNeeded(cot)) return;
                    if (!context.mounted) return;
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PreviewScreen(cotizacion: cot),
                      ),
                    );
                    if (result == true) await _loadInitial(soft: true);
                  }),
                  onEdit: () => _runAction(cot.id, () async {
                    if (!await _resolveConflictIfNeeded(cot)) return;
                    if (!context.mounted) return;
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NuevaCotizacionScreen(cotizacion: cot),
                      ),
                    );
                    if (result == true) await _loadInitial(soft: true);
                  }),
                  onShare: () => _runAction(cot.id, () async {
                    if (PdfShareService.instance.isBusy) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.sharePdfBusy)),
                      );
                      return;
                    }
                    await QuoteShareUi.shareCotizacionWithFeedback(
                      context,
                      cot,
                    );
                  }),
                  onDuplicate: hasOrg
                      ? () => _runAction(cot.id, () async {
                          try {
                            final copy = await DBService.instance
                                .duplicateQuote(cot.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.duplicatedAs(copy.number),
                                ),
                              ),
                            );
                            await _loadInitial(soft: true);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$e'.replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        })
                      : null,
                  onArchive: hasOrg
                      ? () => _runAction(cot.id, () async {
                          try {
                            await DBService.instance.setQuoteStatus(
                              cot.id,
                              QuoteStatus.archived,
                            );
                            await _loadInitial(soft: true);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$e'.replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        })
                      : null,
                  onRestore: hasOrg
                      ? () => _runAction(cot.id, () async {
                          try {
                            await DBService.instance.setQuoteStatus(
                              cot.id,
                              QuoteStatus.draft,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.restoredToDraft),
                              ),
                            );
                            await _loadInitial(soft: true);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$e'.replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        })
                      : null,
                  onNewVersion: hasOrg
                      ? () => _runAction(cot.id, () async {
                          try {
                            final next = await DBService.instance
                                .createQuoteVersion(cot.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.versionCreated(next.version),
                                ),
                              ),
                            );
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NuevaCotizacionScreen(
                                  cotizacion: QuoteMapper.toCotizacion(next),
                                ),
                              ),
                            );
                            await _loadInitial(soft: true);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$e'.replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        })
                      : null,
                  onDelete: () => _runAction(cot.id, () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) {
                        final d = ctx.l10n;
                        return AlertDialog(
                          title: Text(d.deleteQuoteTitle),
                          content: Text(d.deleteQuoteBody(cot.numero)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(d.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                d.delete,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirm == true) {
                      await DBService.instance.eliminarCotizacion(cot.id);
                      await _loadInitial(soft: true);
                    }
                  }),
                );
              },
            ),
    );
  }
}
