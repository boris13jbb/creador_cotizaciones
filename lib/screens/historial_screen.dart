import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cotizacion.dart';
import '../saas/domain/org_enums.dart';
import '../saas/providers/auth_controller.dart';
import '../saas/services/quote_mapper.dart';
import '../saas/services/quote_reminder_service.dart';
import '../services/db_service.dart';
import '../ui/layout/responsive.dart';
import '../ui/widgets/async_state_view.dart';
import '../widgets/cotizacion_card.dart';
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
  Object? _error;
  String? _statusFilter;

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
    if (!_hasMore || _loadingMore || _loading) return;
    if (_queryController.text.trim().isNotEmpty) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextCursor = null;
      _hasMore = false;
    });
    try {
      final page = await DBService.instance.obtenerPagina(
        limit: _pageSize,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
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

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await DBService.instance.obtenerPagina(
        limit: _pageSize,
        startAfterUpdatedAt: _nextCursor,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = e;
      });
    }
  }

  List<Cotizacion> _filtrar(List<Cotizacion> cotizaciones, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return cotizaciones;

    bool match(Cotizacion c) {
      return c.numero.toLowerCase().contains(query) ||
          c.cliente.toLowerCase().contains(query) ||
          c.ubicacion.toLowerCase().contains(query) ||
          c.tipoServicio.toLowerCase().contains(query);
    }

    return cotizaciones.where(match).toList();
  }

  @override
  Widget build(BuildContext context) {
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar = !widget.embeddedInShell || useRail;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('Historial'),
              actions: [
                IconButton(
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadInitial,
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
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Número, cliente, ubicación o servicio',
                    prefixIcon: Icon(Icons.search),
                    helperText:
                        'La búsqueda aplica a las cotizaciones ya cargadas',
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
                      label: const Text('Todas'),
                      selected: _statusFilter == null,
                      onSelected: (_) {
                        setState(() => _statusFilter = null);
                        _loadInitial();
                      },
                    ),
                    const SizedBox(width: 8),
                    for (final s in const [
                      QuoteStatus.draft,
                      QuoteStatus.sent,
                      QuoteStatus.viewed,
                      QuoteStatus.accepted,
                      QuoteStatus.rejected,
                      QuoteStatus.archived,
                    ]) ...[
                      FilterChip(
                        label: Text(s.id),
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
              Builder(
                builder: (context) {
                  final now = DateTime.now().toUtc();
                  final stale = QuoteReminderService.instance.countStaleSent(
                    items: _items.map(
                      (c) => (
                        status: c.quoteStatus ?? '',
                        updatedAt:
                            DateTime.tryParse(c.fecha)?.toUtc() ?? now,
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
                      color: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.notifications_active_outlined),
                        title: Text(
                          '$stale cotización(es) enviada(s) sin respuesta (>7 días)',
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            setState(
                              () => _statusFilter = QuoteStatus.sent.id,
                            );
                            _loadInitial();
                          },
                          child: const Text('Ver enviadas'),
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
                    tooltip: 'Actualizar',
                    onPressed: _loadInitial,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final filtered = _filtrar(_items, _queryController.text);

    return AsyncStateView(
      loading: _loading,
      error: _error != null && _items.isEmpty ? _error : null,
      isEmpty: !_loading && _items.isEmpty,
      emptyIcon: Icons.history,
      emptyTitle: 'Aún no hay cotizaciones guardadas',
      emptySubtitle: 'Cuando guardes una, aparecerá aquí.',
      onRetry: _loadInitial,
      child: filtered.isEmpty
          ? AsyncStateView(
              isEmpty: true,
              emptyIcon: Icons.search_off,
              emptyTitle: 'Sin resultados',
              emptySubtitle:
                  'Prueba con otro término o carga más cotizaciones.',
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
                              child: const Text('Cargar más'),
                            ),
                    ),
                  );
                }

                final cot = filtered[index];
                final hasOrg =
                    context.read<AuthController>().organizationId != null;
                return CotizacionCard(
                  cotizacion: cot,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PreviewScreen(cotizacion: cot),
                      ),
                    );
                    if (result == true) await _loadInitial();
                  },
                  onEdit: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NuevaCotizacionScreen(cotizacion: cot),
                      ),
                    );
                    if (result == true) await _loadInitial();
                  },
                  onDuplicate: hasOrg
                      ? () async {
                          try {
                            final copy = await DBService.instance
                                .duplicateQuote(cot.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Duplicada como ${copy.number}'),
                              ),
                            );
                            await _loadInitial();
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
                        }
                      : null,
                  onArchive: hasOrg
                      ? () async {
                          try {
                            await DBService.instance.setQuoteStatus(
                              cot.id,
                              QuoteStatus.archived,
                            );
                            await _loadInitial();
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
                        }
                      : null,
                  onNewVersion: hasOrg
                      ? () async {
                          try {
                            final next = await DBService.instance
                                .createQuoteVersion(cot.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Versión ${next.version} creada'),
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
                            await _loadInitial();
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
                        }
                      : null,
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar'),
                        content: Text('¿Eliminar la cotización ${cot.numero}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await DBService.instance.eliminarCotizacion(cot.id);
                      await _loadInitial();
                    }
                  },
                );
              },
            ),
    );
  }
}
