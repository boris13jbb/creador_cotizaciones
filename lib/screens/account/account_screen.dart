import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/billing_service.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/providers/theme_controller.dart';
import '../catalog/catalog_screen.dart';
import '../clients/clients_screen.dart';
import '../legal/legal_screen.dart';
import '../team/team_screen.dart';
import 'pricing_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeCtrl = context.watch<ThemeController>();
    final profile = auth.profile;
    final access = auth.access;
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar = !embeddedInShell || useRail;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Mi cuenta')) : null,
      body: SafeArea(
        child: ContentConstraint(
          padding: AppSpacing.page,
          child: ListView(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  child: Text(
                    (profile?.displayName.isNotEmpty == true)
                        ? profile!.displayName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(
                  profile?.displayName ?? 'Usuario',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(profile?.email ?? auth.user?.email ?? ''),
              ),
              if (!auth.isEmailVerified)
                Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? null
                      : const Color(0xFFFFF4DE),
                  child: ListTile(
                    leading: const Icon(Icons.mark_email_unread_outlined),
                    title: const Text('Verifica tu correo'),
                    subtitle: const Text(
                      'Te enviamos un enlace de verificación. '
                      'Revisa tu bandeja o reenvíalo.',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final ok = await auth.sendEmailVerification();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Correo de verificación enviado'
                                  : (auth.error ?? 'No se pudo enviar'),
                            ),
                          ),
                        );
                      },
                      child: const Text('Reenviar'),
                    ),
                  ),
                ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: const Text('Clientes'),
                subtitle: const Text('Directorio reutilizable'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClientsScreen()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Catálogo'),
                subtitle: const Text('Productos y servicios'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CatalogScreen()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Equipo'),
                subtitle: Text(
                  access.canManageTeam
                      ? 'Miembros e invitaciones (hasta ${access.maxSeats})'
                      : 'Disponible en Pro / Business',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamScreen()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Plan'),
                subtitle: Text(
                  [
                    access.effectivePlan.label,
                    if (access.isTrialing) '· Prueba Pro activa',
                    if (access.isCanceled) '· Cancelado',
                  ].join(' '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PricingScreen()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Apariencia'),
                subtitle: Text(themeCtrl.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickTheme(context, themeCtrl),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cloud_done_outlined),
                title: Text('Datos'),
                subtitle: Text('Sincronizados en la nube (Firestore)'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined),
                title: const Text('Exportar mis datos'),
                subtitle: const Text('Descarga JSON con perfil y cotizaciones'),
                onTap: () => _exportData(context, auth),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Portal de facturación'),
                subtitle: const Text('Gestionar suscripción Stripe'),
                onTap: () => _openPortal(context),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacidad'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const LegalScreen(kind: LegalKind.privacy),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Términos'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(kind: LegalKind.terms),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Eliminar cuenta',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _deleteAccount(context, auth),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: const Text('¿Seguro que deseas salir?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Salir'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthController>().signOut();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Soporte: ${SaasConfig.supportEmail}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, ThemeController ctrl) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('Sistema'),
                onTap: () => Navigator.pop(ctx, ThemeMode.system),
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_outlined),
                title: const Text('Claro'),
                onTap: () => Navigator.pop(ctx, ThemeMode.light),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Oscuro'),
                onTap: () => Navigator.pop(ctx, ThemeMode.dark),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) await ctrl.setMode(selected);
  }

  Future<void> _exportData(BuildContext context, AuthController auth) async {
    final json = await auth.exportMyDataJson();
    if (!context.mounted) return;
    if (json == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'No se pudo exportar')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportación lista'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(json, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPortal(BuildContext context) async {
    try {
      await BillingService.instance.openCustomerPortal();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context, AuthController auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Se eliminarán tu perfil y cotizaciones. Esta acción no se puede deshacer. '
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final ok = await auth.deleteAccount();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (auth.error ?? 'Cuenta eliminada')
              : (auth.error ?? 'No se pudo eliminar la cuenta'),
        ),
      ),
    );
  }
}
