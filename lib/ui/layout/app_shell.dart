import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/account/pricing_screen.dart';
import '../../screens/historial_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/nueva_cotizacion_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../layout/responsive.dart';
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

  String get _title => switch (_destination) {
    AppDestination.home => SaasConfig.productName,
    AppDestination.historial => 'Historial',
    AppDestination.reports => 'Reportes',
    AppDestination.pricing => 'Planes',
    AppDestination.account => 'Mi cuenta',
  };

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthController>().access;
    final useRail = Responsive.useNavigationRail(context);

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
                      const Icon(Icons.request_quote_rounded, size: 28),
                      const SizedBox(height: 8),
                      PlanBadge(
                        label: access.effectivePlan.label,
                        isTrialing: access.isTrialing,
                      ),
                    ],
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Inicio'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: Text('Historial'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: Text('Reportes'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.workspace_premium_outlined),
                    selectedIcon: Icon(Icons.workspace_premium),
                    label: Text('Planes'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Cuenta'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
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
        title: Text(_title),
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
      body: body,
      floatingActionButton: _destination == AppDestination.home
          ? _nuevaCotizacionFab(context)
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination.index,
        onDestinationSelected: (i) => _select(AppDestination.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Planes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }

  /// Un solo FAB en el shell (sin Hero) para evitar hit-test roto al navegar.
  Widget _nuevaCotizacionFab(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: null,
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NuevaCotizacionScreen()),
        );
      },
      icon: const Icon(Icons.note_add_outlined),
      label: const Text('Nueva'),
    );
  }
}
