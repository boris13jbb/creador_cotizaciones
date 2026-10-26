import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../saas/config/saas_config.dart';
import '../../saas/offline/offline_controller.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/billing_service.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/providers/theme_controller.dart';
import '../catalog/catalog_screen.dart';
import '../clients/clients_screen.dart';
import '../legal/legal_screen.dart';
import '../team/team_screen.dart';
import 'company_identity_screen.dart';
import 'pricing_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with WidgetsBindingObserver {
  bool _refreshingEmail = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Solo consulta Auth; no reenvía correo.
      context.read<AuthController>().refreshEmailVerification();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthController>().refreshEmailVerification();
    }
  }

  Future<void> _onRefreshEmail(AuthController auth) async {
    setState(() => _refreshingEmail = true);
    try {
      final status = await auth.refreshEmailVerification();
      if (!mounted) return;
      final msg = status.emailVerified
          ? 'Correo verificado correctamente'
          : (auth.emailVerificationHint ??
                'Aún no verificado. Si abriste el enlace, pulsa de nuevo «Actualizar estado».');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _refreshingEmail = false);
    }
  }

  Future<void> _onSyncNow() async {
    setState(() => _syncing = true);
    try {
      final offline = OfflineController.instance;
      final before = offline.pendingQuotes;
      await offline.syncNow();
      if (!mounted) return;
      final after = offline.pendingQuotes;
      final err = offline.lastError;
      final msg = (err != null && err.isNotEmpty)
          ? 'Sync: $before→$after pendientes. Error: $err'
          : (after == 0
                ? 'Sincronización completada'
                : 'Sync parcial: quedan $after cotiz. pendientes');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeCtrl = context.watch<ThemeController>();
    final offline = context.watch<OfflineController>();
    final profile = auth.profile;
    final access = auth.access;
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar = !widget.embeddedInShell || useRail;
    final sessionEmail = auth.user?.email ?? profile?.email ?? '';

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
                subtitle: Text(sessionEmail),
              ),
              if (auth.isEmailVerified)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.mark_email_read_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Correo verificado'),
                  subtitle: Text(sessionEmail),
                )
              else
                Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? null
                      : const Color(0xFFFFF4DE),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.mark_email_unread_outlined),
                          title: const Text('Verifica tu correo'),
                          subtitle: Text(
                            auth.emailVerificationHint ??
                                'Si ya abriste el enlace en el navegador, '
                                    'pulsa «Actualizar estado». No hace falta '
                                    'reenviar salvo que no hayas recibido el correo.',
                          ),
                        ),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _refreshingEmail
                                  ? null
                                  : () => _onRefreshEmail(auth),
                              child: _refreshingEmail
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Actualizar estado'),
                            ),
                            TextButton(
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (offline.hasPending ||
                  (offline.lastError != null &&
                      offline.lastError!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: Text(
                      offline.pendingQuotes > 0
                          ? 'Cambios pendientes · ${offline.pendingQuotes} cotiz.'
                          : offline.statusLabel(),
                    ),
                    subtitle: Text(
                      offline.lastError ??
                          'Solo en este dispositivo hasta sincronizar.',
                    ),
                    trailing: TextButton(
                      onPressed: _syncing ? null : _onSyncNow,
                      child: _syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sincronizar'),
                    ),
                  ),
                ),
              ],
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
                leading: const Icon(Icons.branding_watermark_outlined),
                title: const Text('Identidad visual'),
                subtitle: Text(
                  auth.canCustomBranding
                      ? 'Logotipo y colores de la empresa'
                      : 'Disponible en Pro o prueba',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompanyIdentityScreen(),
                    ),
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
                  final hasPending = await OfflineController.instance
                      .hasUnsyncedWork();
                  if (!context.mounted) return;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: Text(
                        hasPending
                            ? 'Hay cambios pendientes de sincronizar en este dispositivo. '
                                  'No se borrarán, pero otra cuenta no podrá verlos. '
                                  '¿Seguro que deseas salir?'
                            : '¿Seguro que deseas salir?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        if (hasPending)
                          TextButton(
                            onPressed: () async {
                              await OfflineController.instance.syncNow();
                              if (ctx.mounted) Navigator.pop(ctx, false);
                            },
                            child: const Text('Sincronizar primero'),
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
