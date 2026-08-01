import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cotizacion.dart';
import '../saas/providers/auth_controller.dart';
import '../services/db_service.dart';
import '../ui/layout/responsive.dart';
import '../ui/widgets/app_action_tile.dart';
import '../ui/widgets/async_state_view.dart';
import '../ui/widgets/plan_badge.dart';
import '../widgets/cotizacion_card.dart';
import 'nueva_cotizacion_screen.dart';
import 'preview_screen.dart';
import 'reports/reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenHistorial,
    this.embeddedInShell = false,
  });

  final VoidCallback? onOpenHistorial;
  final bool embeddedInShell;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Cotizacion>> _cotizacionesFuture;
  final Set<String> _cotizacionesOcultas = {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refreshLista();
  }

  void _refreshLista() {
    setState(() {
      _error = null;
      _cotizacionesFuture = DBService.instance.obtenerTodas();
    });
  }

  Future<void> _openNueva() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NuevaCotizacionScreen()),
    );
    if (mounted) _refreshLista();
  }

  void _openHistorial() {
    if (widget.onOpenHistorial != null) {
      widget.onOpenHistorial!();
      return;
    }
    // Fallback si Home se abre fuera del shell.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthController>().access;
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar = !widget.embeddedInShell || useRail;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final body = RefreshIndicator(
      onRefresh: () async => _refreshLista(),
      child: ContentConstraint(
        padding: AppSpacing.pageWide,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              '¿Qué deseas crear hoy?',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cotizaciones profesionales sincronizadas en la nube',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppActionGrid(
              children: [
                AppActionTile(
                  title: 'Nueva cotización',
                  subtitle: 'Crear desde cero',
                  icon: Icons.add_chart_outlined,
                  onTap: _openNueva,
                ),
                AppActionTile(
                  title: 'Historial',
                  subtitle: 'Ver y gestionar',
                  icon: Icons.history_outlined,
                  onTap: _openHistorial,
                ),
                AppActionTile(
                  title: 'Reportes',
                  subtitle: 'KPIs y exportación',
                  icon: Icons.insights_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            AppSectionHeader(
              title: 'Cotizaciones recientes',
              actionLabel: 'Ver todas',
              onAction: _openHistorial,
            ),
            _buildRecientes(),
            SizedBox(height: 88 + bottomInset),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('CotiApp'),
              actions: [
                if (!widget.embeddedInShell)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PlanBadge(
                      label: access.effectivePlan.label,
                      isTrialing: access.isTrialing,
                    ),
                  ),
                IconButton(
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshLista,
                ),
              ],
            )
          : null,
      body: body,
      floatingActionButton: (!widget.embeddedInShell || useRail)
          ? FloatingActionButton.extended(
              onPressed: _openNueva,
              icon: const Icon(Icons.add),
              label: const Text('Nueva'),
            )
          : null,
    );
  }

  Widget _buildRecientes() {
    return FutureBuilder<List<Cotizacion>>(
      future: _cotizacionesFuture,
      builder: (context, snapshot) {
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final err = snapshot.hasError ? snapshot.error : _error;
        final all = snapshot.data ?? [];
        final cotizaciones = all
            .where((c) => !_cotizacionesOcultas.contains(c.id))
            .toList();

        return AsyncStateView(
          loading: waiting,
          error: err,
          isEmpty: cotizaciones.isEmpty,
          emptyIcon: Icons.request_quote_outlined,
          emptyTitle: 'Aún no hay cotizaciones',
          emptySubtitle: 'Crea la primera para verla aquí.',
          onRetry: _refreshLista,
          child: Column(
            children: [
              for (final cot in cotizaciones.take(5))
                CotizacionCard(
                  cotizacion: cot,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PreviewScreen(cotizacion: cot),
                      ),
                    );
                    if (mounted) _refreshLista();
                  },
                  onEdit: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NuevaCotizacionScreen(cotizacion: cot),
                      ),
                    );
                    if (mounted) _refreshLista();
                  },
                  onHide: () =>
                      setState(() => _cotizacionesOcultas.add(cot.id)),
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
                      if (mounted) _refreshLista();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
