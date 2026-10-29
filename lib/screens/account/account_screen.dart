import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/auth_error_l10n.dart';
import '../../l10n/l10n_ext.dart';
import '../../saas/config/saas_config.dart';
import '../../saas/offline/offline_controller.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/billing_service.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/providers/locale_controller.dart';
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
      final l10n = context.l10n;
      final msg = status.emailVerified
          ? l10n.emailVerifiedOk
          : (auth.emailVerificationHint ?? l10n.emailNotVerifiedYet);
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
      final l10n = context.l10n;
      final msg = (err != null && err.isNotEmpty)
          ? l10n.syncWithError(before, after, err)
          : (after == 0 ? l10n.syncCompleted : l10n.syncPartial(after));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeCtrl = context.watch<ThemeController>();
    final localeCtrl = context.watch<LocaleController>();
    final offline = context.watch<OfflineController>();
    final l10n = context.l10n;
    final profile = auth.profile;
    final access = auth.access;
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar =
        !widget.embeddedInShell || (useRail && !Responsive.isWebAdaptive);
    final sessionEmail = auth.user?.email ?? profile?.email ?? '';

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(l10n.myAccount)) : null,
      body: SafeArea(
        child: ContentConstraint.form(
          padding: Responsive.pagePadding(context),
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
                  profile?.displayName ?? l10n.userFallback,
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
                  title: Text(l10n.emailVerified),
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
                          title: Text(l10n.verifyEmailTitle),
                          subtitle: Text(
                            auth.emailVerificationHint ?? l10n.verifyEmailHint,
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
                                  : Text(l10n.updateStatus),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await auth.sendEmailVerification();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? l10n.verificationSent
                                          : (auth.error != null
                                                ? localizeAuthError(
                                                    l10n,
                                                    auth.error,
                                                  )
                                                : l10n.couldNotSend),
                                    ),
                                  ),
                                );
                              },
                              child: Text(l10n.resend),
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
                          ? l10n.pendingChangesQuotes(offline.pendingQuotes)
                          : offline.statusLabel(),
                    ),
                    subtitle: Text(offline.lastError ?? l10n.pendingUntilSync),
                    trailing: TextButton(
                      onPressed: _syncing ? null : _onSyncNow,
                      child: _syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.syncNow),
                    ),
                  ),
                ),
              ],
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: Text(l10n.clients),
                subtitle: Text(l10n.clientsSubtitle),
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
                title: Text(l10n.catalog),
                subtitle: Text(l10n.catalogSubtitle),
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
                title: Text(l10n.team),
                subtitle: Text(
                  access.canManageTeam
                      ? l10n.teamManageSubtitle(access.maxSeats)
                      : l10n.teamProOnly,
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
                title: Text(l10n.visualIdentity),
                subtitle: Text(
                  auth.canCustomBranding
                      ? l10n.visualIdentityOk
                      : l10n.visualIdentityPro,
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
                title: Text(l10n.plan),
                subtitle: Text(
                  [
                    access.effectivePlan.label,
                    if (access.isTrialing) l10n.trialProActive,
                    if (access.isCanceled) l10n.planCanceled,
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
                title: Text(l10n.appearance),
                subtitle: Text(
                  themeCtrl.labelFor(
                    light: l10n.themeLight,
                    dark: l10n.themeDark,
                    system: l10n.themeSystem,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickTheme(context, themeCtrl),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.language),
                subtitle: Text(localeCtrl.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickLanguage(context, localeCtrl),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(l10n.data),
                subtitle: Text(l10n.dataSyncedCloud),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.exportMyData),
                subtitle: Text(l10n.exportMyDataSubtitle),
                onTap: () => _exportData(context, auth),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_outlined),
                title: Text(l10n.billingPortal),
                subtitle: Text(l10n.billingPortalSubtitle),
                onTap: () => _openPortal(context),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.privacy),
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
                title: Text(l10n.terms),
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
                title: Text(
                  l10n.deleteAccount,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => _deleteAccount(context, auth),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  l10n.signOut,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final hasPending = await OfflineController.instance
                      .hasUnsyncedWork();
                  if (!context.mounted) return;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.signOut),
                      content: Text(
                        hasPending
                            ? l10n.signOutPendingWarning
                            : l10n.signOutConfirm,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        if (hasPending)
                          TextButton(
                            onPressed: () async {
                              await OfflineController.instance.syncNow();
                              if (ctx.mounted) Navigator.pop(ctx, false);
                            },
                            child: Text(l10n.syncNow),
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.signOut),
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
                l10n.supportLine(SaasConfig.supportEmail),
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
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(l10n.pickThemeTitle)),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: Text(l10n.themeSystem),
                onTap: () => Navigator.pop(ctx, ThemeMode.system),
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_outlined),
                title: Text(l10n.themeLight),
                onTap: () => Navigator.pop(ctx, ThemeMode.light),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.themeDark),
                onTap: () => Navigator.pop(ctx, ThemeMode.dark),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) await ctrl.setMode(selected);
  }

  Future<void> _pickLanguage(
    BuildContext context,
    LocaleController ctrl,
  ) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(l10n.language)),
              ListTile(
                leading: Icon(
                  ctrl.isSpanish
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(l10n.languageSpanish),
                onTap: () => Navigator.pop(ctx, 'es'),
              ),
              ListTile(
                leading: Icon(
                  ctrl.isEnglish
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(l10n.languageEnglish),
                onTap: () => Navigator.pop(ctx, 'en'),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) await ctrl.setLanguageCode(selected);
  }

  Future<void> _exportData(BuildContext context, AuthController auth) async {
    final json = await auth.exportMyDataJson();
    if (!context.mounted) return;
    if (json == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.error != null
                ? localizeAuthError(context.l10n, auth.error)
                : context.l10n.exportFailed,
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.exportMyData),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(json, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.close),
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
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Text('${l10n.deleteAccount}. ${l10n.signOutConfirm}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
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
              ? (auth.error != null
                    ? localizeAuthError(l10n, auth.error)
                    : l10n.accountDeleted)
              : (auth.error != null
                    ? localizeAuthError(l10n, auth.error)
                    : l10n.accountDeleteFailed),
        ),
      ),
    );
  }
}
