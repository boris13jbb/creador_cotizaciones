import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/account/pricing_screen.dart';
import '../../screens/catalog/catalog_screen.dart';
import '../../screens/clients/clients_screen.dart';
import '../../screens/historial_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/nueva_cotizacion_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../widgets/offline_status_banner.dart';
import '../layout/responsive.dart';
import '../tokens/app_icons.dart';
import '../widgets/plan_badge.dart';

enum AppDestination { home, historial, reports, pricing, account }

/// Shell autenticado con navegación adaptativa.
///
/// - Móvil / nativo estrecho: [NavigationBar]
/// - Web tablet (600–1023): AppBar + [Drawer]
/// - Escritorio (Web ≥1024 / nativo ≥840): [NavigationRail] (colapsable en Web)
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialDestination = AppDestination.home});

  final AppDestination initialDestination;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination;
  bool _railExtended = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
  }

  void _select(AppDestination destination) {
    if (_destination == destination) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    setState(() => _destination = destination);
    _scaffoldKey.currentState?.closeDrawer();
  }

  String _title(BuildContext context) {
    final l10n = context.l10n;
    return switch (_destination) {
      AppDestination.home => SaasConfig.productName,
      AppDestination.historial => l10n.navHistory,
      AppDestination.reports => l10n.navReports,
      AppDestination.pricing => l10n.navPlans,
      AppDestination.account => l10n.myAccount,
    };
  }

  List<_NavItem> _primaryItems(BuildContext context) {
    final l10n = context.l10n;
    return [
      _NavItem(
        destination: AppDestination.home,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.navHome,
      ),
      _NavItem(
        destination: AppDestination.historial,
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
        label: l10n.navHistory,
      ),
      _NavItem(
        destination: AppDestination.reports,
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        label: l10n.navReports,
      ),
      _NavItem(
        destination: AppDestination.pricing,
        icon: Icons.workspace_premium_outlined,
        selectedIcon: Icons.workspace_premium,
        label: l10n.navPlans,
      ),
      _NavItem(
        destination: AppDestination.account,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: l10n.navAccount,
      ),
    ];
  }

  Widget _bodyForDestination() {
    return switch (_destination) {
      AppDestination.home => HomeScreen(
        onOpenHistorial: () => _select(AppDestination.historial),
        embeddedInShell: true,
      ),
      AppDestination.historial => const HistorialScreen(embeddedInShell: true),
      AppDestination.reports => const ReportsScreen(embeddedInShell: true),
      AppDestination.pricing => const PricingScreen(embeddedInShell: true),
      AppDestination.account => const AccountScreen(embeddedInShell: true),
    };
  }

  void _openSecondary(Widget screen) {
    _scaffoldKey.currentState?.closeDrawer();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthController>().access;
    final useRail = Responsive.useNavigationRail(context);
    final useDrawer = Responsive.useWebNavigationDrawer(context);
    final l10n = context.l10n;
    final items = _primaryItems(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OfflineStatusBanner(),
        Expanded(child: _bodyForDestination()),
      ],
    );

    final fab = _destination == AppDestination.home
        ? _nuevaCotizacionFab(context)
        : null;

    if (useRail) {
      final web = Responsive.isWebAdaptive;
      final extended = web && _railExtended;
      // Evitar trailing en NavigationRail: en alturas medias provoca
      // overflow vertical y cajas sin layout («never been laid out»).
      return Scaffold(
        key: _scaffoldKey,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                extended: extended,
                selectedIndex: _destination.index,
                onDestinationSelected: (i) => _select(AppDestination.values[i]),
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                minExtendedWidth: 208,
                leading: web
                    ? IconButton(
                        tooltip: extended ? l10n.collapseMenu : l10n.expandMenu,
                        onPressed: () =>
                            setState(() => _railExtended = !_railExtended),
                        icon: Icon(extended ? Icons.menu_open : Icons.menu),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(AppIcons.marca, size: 28),
                            const SizedBox(height: 8),
                            PlanBadge(
                              label: access.effectivePlan.label,
                              isTrialing: access.isTrialing,
                            ),
                          ],
                        ),
                      ),
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (web)
                      Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              const Icon(AppIcons.marca, size: 22),
                              const SizedBox(width: AppSpacing.sm),
                              PlanBadge(
                                label: access.effectivePlan.label,
                                isTrialing: access.isTrialing,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  _title(context),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.clients,
                                onPressed: () =>
                                    _openSecondary(const ClientsScreen()),
                                icon: const Icon(Icons.people_outline),
                              ),
                              IconButton(
                                tooltip: l10n.catalog,
                                onPressed: () =>
                                    _openSecondary(const CatalogScreen()),
                                icon: const Icon(Icons.inventory_2_outlined),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              // IconButton evita truncar «Nueva cotización» en
                              // cabeceras con título largo + atajos.
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(40, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const NuevaCotizacionScreen(),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add, size: 20),
                                    const SizedBox(width: 6),
                                    Text(l10n.newQuote),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: web ? null : fab,
      );
    }

    if (useDrawer) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_title(context)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PlanBadge(
                label: access.effectivePlan.label,
                isTrialing: access.isTrialing,
              ),
            ),
          ],
        ),
        drawer: _AppNavDrawer(
          selected: _destination,
          items: items,
          onSelect: _select,
          planLabel: access.effectivePlan.label,
          isTrialing: access.isTrialing,
          onClients: () => _openSecondary(const ClientsScreen()),
          onCatalog: () => _openSecondary(const CatalogScreen()),
        ),
        body: content,
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_title(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PlanBadge(
              label: access.effectivePlan.label,
              isTrialing: access.isTrialing,
            ),
          ),
        ],
      ),
      body: content,
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination.index,
        onDestinationSelected: (i) => _select(AppDestination.values[i]),
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }

  Widget _nuevaCotizacionFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NuevaCotizacionScreen()),
        );
      },
      icon: const Icon(Icons.add),
      label: Text(context.l10n.newQuote),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.destination,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final AppDestination destination;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _AppNavDrawer extends StatelessWidget {
  const _AppNavDrawer({
    required this.selected,
    required this.items,
    required this.onSelect,
    required this.planLabel,
    required this.isTrialing,
    required this.onClients,
    required this.onCatalog,
  });

  final AppDestination selected;
  final List<_NavItem> items;
  final ValueChanged<AppDestination> onSelect;
  final String planLabel;
  final bool isTrialing;
  final VoidCallback onClients;
  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NavigationDrawer(
      selectedIndex: selected.index,
      onDestinationSelected: (i) {
        if (i < items.length) {
          onSelect(items[i].destination);
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              const Icon(AppIcons.marca, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  SaasConfig.productName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PlanBadge(label: planLabel, isTrialing: isTrialing),
            ],
          ),
        ),
        const Divider(),
        for (final item in items)
          NavigationDrawerDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: Text(l10n.clients),
          onTap: onClients,
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(l10n.catalog),
          onTap: onCatalog,
        ),
      ],
    );
  }
}
