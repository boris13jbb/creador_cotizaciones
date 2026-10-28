import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../saas/domain/org_enums.dart';
import '../../saas/models/org_activity.dart';
import '../../saas/models/organization.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/org_team_service.dart';
import '../../screens/account/pricing_screen.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/widgets/async_state_view.dart';

/// Panel de equipo: miembros, invitaciones y roles.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _loading = true;
  Object? _error;
  List<OrgMembership> _members = const [];
  List<OrgInvite> _invites = const [];
  final _emailCtrl = TextEditingController();
  OrgRole _inviteRole = OrgRole.sales;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String _formatInviteExpiry(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final orgId = auth.organizationId;
    if (orgId == null) {
      setState(() {
        _loading = false;
        _error = context.l10n.noOrganization;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = auth.restSession;
      final members = await OrgTeamService.instance.listOrgMembers(
        orgId: orgId,
        session: session,
      );
      final invites = await OrgTeamService.instance.listInvites(
        orgId: orgId,
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _invites = invites;
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

  Future<void> _invite() async {
    final auth = context.read<AuthController>();
    final l10n = context.l10n;
    if (!auth.access.canManageTeam) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PricingScreen()),
      );
      return;
    }
    final orgId = auth.organizationId;
    final uid = auth.user?.uid ?? auth.restSession?.uid;
    if (orgId == null || uid == null) return;

    final membership = await _myMembership(auth, orgId);
    if (!mounted) return;
    if (membership == null || !membership.role.canManageOrg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.inviteOwnersOnly)),
      );
      return;
    }

    try {
      final invite = await OrgTeamService.instance.inviteMember(
        orgId: orgId,
        email: _emailCtrl.text,
        role: _inviteRole,
        invitedByUid: uid,
        maxSeats: auth.access.maxSeats,
        session: auth.restSession,
      );
      if (!mounted) return;
      _emailCtrl.clear();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.inviteCreatedTitle),
          content: SelectableText(
            l10n.inviteShareToken(invite.email, invite.token),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.token));
                Navigator.pop(ctx);
              },
              child: Text(l10n.copyToken),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<OrgMembership?> _myMembership(
    AuthController auth,
    String orgId,
  ) async {
    final uid = auth.user?.uid ?? auth.restSession?.uid;
    if (uid == null) return null;
    for (final m in _members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  Future<void> _acceptDialog() async {
    final l10n = context.l10n;
    final tokenCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.acceptInvite),
        content: TextField(
          controller: tokenCtrl,
          decoration: InputDecoration(labelText: l10n.fieldInviteToken),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await OrgTeamService.instance.acceptInvite(token: tokenCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.inviteAccepted)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      tokenCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l10n = context.l10n;
    final locked = !auth.access.canManageTeam;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.teamTitle),
        actions: [
          TextButton(
            onPressed: _acceptDialog,
            child: Text(l10n.acceptInvite),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: ContentConstraint(
          padding: AppSpacing.pageWide,
          child: AsyncStateView(
            loading: _loading,
            error: _error?.toString(),
            onRetry: _load,
            child: ListView(
              children: [
                if (locked)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(l10n.teamProUpsellTitle),
                      subtitle: Text(
                        l10n.teamProUpsellBody(auth.access.maxSeats),
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PricingScreen(),
                          ),
                        ),
                        child: Text(l10n.navPlans),
                      ),
                    ),
                  ),
                Text(
                  l10n.membersCount(_members.length, auth.access.maxSeats),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final m in _members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      m.displayName?.isNotEmpty == true
                          ? m.displayName!
                          : m.email ?? m.uid,
                    ),
                    subtitle: Text('${m.role.id} · ${m.status.id}'),
                    trailing: m.role == OrgRole.owner
                        ? Chip(label: Text(m.role.id))
                        : locked
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) async {
                              final orgId = auth.organizationId!;
                              final actor =
                                  auth.user?.uid ?? auth.restSession!.uid;
                              try {
                                if (v == 'disable') {
                                  await OrgTeamService.instance.disableMember(
                                    orgId: orgId,
                                    memberUid: m.uid,
                                    actorUid: actor,
                                    session: auth.restSession,
                                  );
                                } else {
                                  await OrgTeamService.instance
                                      .updateMemberRole(
                                        orgId: orgId,
                                        memberUid: m.uid,
                                        role: OrgRole.fromId(v),
                                        actorUid: actor,
                                        session: auth.restSession,
                                      );
                                }
                                await _load();
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
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'admin',
                                child: Text(l10n.roleLabel('admin')),
                              ),
                              PopupMenuItem(
                                value: 'sales',
                                child: Text(l10n.roleLabel('sales')),
                              ),
                              PopupMenuItem(
                                value: 'readonly',
                                child: Text(l10n.roleLabel('readonly')),
                              ),
                              PopupMenuItem(
                                value: 'disable',
                                child: Text(l10n.deactivateMember),
                              ),
                            ],
                          ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.inviteSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _emailCtrl,
                  enabled: !locked,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    hintText: l10n.hintColleagueEmail,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<OrgRole>(
                  initialValue: _inviteRole,
                  decoration: InputDecoration(labelText: l10n.fieldRole),
                  items: [
                    for (final r in [
                      OrgRole.admin,
                      OrgRole.sales,
                      OrgRole.readonly,
                    ])
                      DropdownMenuItem(value: r, child: Text(r.id)),
                  ],
                  onChanged: locked
                      ? null
                      : (r) {
                          if (r != null) setState(() => _inviteRole = r);
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: locked ? null : _invite,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(l10n.createInvitation),
                ),
                if (_invites.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.pendingInvites,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final i in _invites)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.email),
                      subtitle: Text(
                        l10n.inviteExpires(
                          i.role,
                          _formatInviteExpiry(context, i.expiresAt),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
