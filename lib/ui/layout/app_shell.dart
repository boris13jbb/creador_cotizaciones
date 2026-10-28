import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/account/pricing_screen.dart';
import '../../screens/historial_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/nueva_cotizacion_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../widgets/offline_status_banner.dart';
import '../layout/responsive.dart';
import '../tokens/app_icons.dart';
import '../widgets/plan_badge.dart';

enum AppDestination { home, historial, reports, pricing, account }

/// Shell autenticado con NavigationBar (móvil) o NavigationRail (desktop).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialDestination = AppDestination.home});

  final AppDestination initialDestination;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
  }

  void _select(AppDestination destination) {
    if (_destination == destination) return;
    setState(() => _destination = destination);
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

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthController>().access;
    final useRail = Responsive.useNavigationRail(context);
    final l10n = context.l10n;

    final body = switch (_destination) {
      AppDestination.home => HomeScreen(
        onOpenHistorial: () => _select(AppDestination.historial),
        embeddedInShell: true,
      ),
      AppDestination.historial => const HistorialScreen(embeddedInShell: true),
      AppDestination.reports => const ReportsScreen(embeddedInShell: true),
      AppDestination.pricing => const PricingScreen(embeddedInShell: true),
      AppDestination.account => const AccountScreen(embeddedInShell: true),
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OfflineStatusBanner(),
        Expanded(child: body),
      ],
    );

    if (useRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _destination.index,
                onDestinationSelected: (i) => _select(AppDestination.values[i]),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
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
                  NavigationRailDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: Text(l10n.navHome),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.history_outlined),
                    selectedIcon: const Icon(Icons.history),
                    label: Text(l10n.navHistory),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.insights_outlined),
                    selectedIcon: const Icon(Icons.insights),
                    label: Text(l10n.navReports),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.workspace_premium_outlined),
                    selectedIcon: const Icon(Icons.workspace_premium),
                    label: Text(l10n.navPlans),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: Text(l10n.navAccount),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
        floatingActionButton: _destination == AppDestination.home
            ? _nuevaCotizacionFab(context)
            : null,
      );
    }

    return Scaffold(
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
      floatingActionButton: _destination == AppDestination.home
          ? _nuevaCotizacionFab(context)
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination.index,
        onDestinationSelected: (i) => _select(AppDestination.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: l10n.navReports,
          ),
          NavigationDestination(
            icon: const Icon(Icons.workspace_premium_outlined),
            selectedIcon: const Icon(Icons.workspace_premium),
            label: l10n.navPlans,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navAccount,
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
