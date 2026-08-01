import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final orgId = auth.organizationId;
    if (orgId == null) {
      setState(() {
        _loading = false;
        _error = 'Sin organización';
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
        const SnackBar(content: Text('Solo owner/admin pueden invitar.')),
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
          title: const Text('Invitación creada'),
          content: SelectableText(
            'Comparte este token con ${invite.email} (válido 7 días):\n\n'
            '${invite.token}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.token));
                Navigator.pop(ctx);
              },
              child: const Text('Copiar token'),
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

  Future<OrgMembership?> _myMembership(AuthController auth, String orgId) async {
    final uid = auth.user?.uid ?? auth.restSession?.uid;
    if (uid == null) return null;
    for (final m in _members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  Future<void> _acceptDialog() async {
    final tokenCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aceptar invitación'),
        content: TextField(
          controller: tokenCtrl,
          decoration: const InputDecoration(
            labelText: 'Token de invitación',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await OrgTeamService.instance.acceptInvite(token: tokenCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación aceptada')),
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
    final locked = !auth.access.canManageTeam;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipo'),
        actions: [
          TextButton(
            onPressed: _acceptDialog,
            child: const Text('Aceptar invite'),
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
                      title: const Text('Gestión de equipo en Pro/Business'),
                      subtitle: Text(
                        'Hasta ${auth.access.maxSeats} asientos en tu plan actual '
                        'cuando esté activo.',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PricingScreen(),
                          ),
                        ),
                        child: const Text('Planes'),
                      ),
                    ),
                  ),
                Text(
                  'Miembros (${_members.length}/${auth.access.maxSeats})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final m in _members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.displayName?.isNotEmpty == true
                        ? m.displayName!
                        : m.email ?? m.uid),
                    subtitle: Text('${m.role.id} · ${m.status.id}'),
                    trailing: m.role == OrgRole.owner
                        ? const Chip(label: Text('owner'))
                        : locked
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (v) async {
                                  final orgId = auth.organizationId!;
                                  final actor = auth.user?.uid ??
                                      auth.restSession!.uid;
                                  try {
                                    if (v == 'disable') {
                                      await OrgTeamService.instance
                                          .disableMember(
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
                                  const PopupMenuItem(
                                    value: 'admin',
                                    child: Text('Rol: admin'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'sales',
                                    child: Text('Rol: sales'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'readonly',
                                    child: Text('Rol: readonly'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'disable',
                                    child: Text('Desactivar'),
                                  ),
                                ],
                              ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Invitar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _emailCtrl,
                  enabled: !locked,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    hintText: 'coleaga@empresa.com',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<OrgRole>(
                  initialValue: _inviteRole,
                  decoration: const InputDecoration(labelText: 'Rol'),
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
                  label: const Text('Crear invitación'),
                ),
                if (_invites.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Pendientes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final i in _invites)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.email),
                      subtitle: Text('${i.role} · expira ${i.expiresAt.toLocal()}'),
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
