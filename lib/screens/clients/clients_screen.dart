import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/l10n_ext.dart';
import '../../saas/models/org_client.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/client_csv_import_service.dart';
import '../../saas/services/client_repository.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/widgets/async_state_view.dart';

const _kNoOrganization = _NoOrganizationMarker();

class _NoOrganizationMarker {
  const _NoOrganizationMarker();
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<OrgClient> _items = [];
  bool _loading = true;
  Object? _error;

  String? get _orgId => context.read<AuthController>().organizationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      setState(() {
        _loading = false;
        _error = _kNoOrganization;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ClientRepository.instance.list(orgId);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _createOrganization() async {
    final auth = context.read<AuthController>();
    final ok = await auth.createOrRecoverOrganization();
    if (!mounted) return;
    if (ok) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? context.l10n.createOrganizationFailed),
        ),
      );
    }
  }

  Future<void> _edit([OrgClient? existing]) async {
    final orgId = _orgId;
    if (orgId == null) return;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final idCtrl = TextEditingController(text: existing?.identification ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(existing == null ? l10n.newClient : l10n.editClient),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.fieldClientNameRequired,
                  ),
                ),
                TextField(
                  controller: idCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.fieldIdentification,
                  ),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(labelText: l10n.email),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(labelText: l10n.fieldPhone),
                ),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(labelText: l10n.fieldAddress),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now().toUtc();
    final client = OrgClient(
      id: existing?.id ?? const Uuid().v4(),
      organizationId: orgId,
      name: name,
      identification: idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await ClientRepository.instance.upsert(
      organizationId: orgId,
      client: client,
    );
    await _load();
  }

  Future<void> _importCsv() async {
    final orgId = _orgId;
    if (orgId == null) return;
    final csvCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.importClientsCsvTitle),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.importCsvHelp(ClientCsvImportService.templateHeader),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(
                      const ClipboardData(
                        text:
                            '${ClientCsvImportService.templateHeader}\n'
                            'Acme SA,info@acme.com,+593999,1790012345001,Quito,,EC,',
                      ),
                    );
                  },
                  child: Text(l10n.copyTemplate),
                ),
                TextField(
                  controller: csvCtrl,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'name,email,phone,...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.importAction),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    final parsed = ClientCsvImportService.instance.parse(
      csv: csvCtrl.text,
      organizationId: orgId,
    );
    csvCtrl.dispose();

    if (parsed.toUpsert.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parsed.errors.isEmpty
                ? context.l10n.importNoValidRows
                : parsed.errors.first,
          ),
        ),
      );
      return;
    }

    var saved = 0;
    for (final c in parsed.toUpsert) {
      await ClientRepository.instance.upsert(organizationId: orgId, client: c);
      saved++;
    }
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    final l10n = context.l10n;
    final extra = parsed.errors.isEmpty
        ? ''
        : l10n.importRowsWithErrors(parsed.errors.length);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.importResult(saved)}$extra')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final noOrg = _error == _kNoOrganization;
    final viewError = noOrg ? l10n.noOrganization : _error;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clients),
        actions: [
          IconButton(
            tooltip: l10n.importClientsCsvTitle,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _importCsv,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.client),
      ),
      body: ContentConstraint(
        child: AsyncStateView(
          loading: _loading,
          error: viewError,
          isEmpty: !_loading && _items.isEmpty,
          emptyTitle: l10n.emptyNoClients,
          emptySubtitle: l10n.emptyCreateFirstClient,
          emptyIcon: Icons.people_outline,
          onRetry: noOrg ? _createOrganization : _load,
          retryLabel: noOrg ? l10n.createOrganization : null,
          retryIcon: noOrg ? Icons.apartment_rounded : null,
          child: ListView.separated(
            padding: AppSpacing.page,
            itemCount: _items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = _items[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text(
                  [
                    c.email,
                    c.phone,
                  ].where((e) => e != null && e.isNotEmpty).join(' · '),
                ),
                onTap: () => _edit(c),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final orgId = _orgId;
                    if (orgId == null) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) {
                        final dlg = ctx.l10n;
                        return AlertDialog(
                          title: Text(dlg.delete),
                          content: Text(dlg.deleteConfirmNamed(c.name)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(dlg.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(dlg.delete),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirm == true) {
                      await ClientRepository.instance.delete(orgId, c.id);
                      await _load();
                    }
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
