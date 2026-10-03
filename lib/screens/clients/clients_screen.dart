import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../saas/models/org_client.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/client_csv_import_service.dart';
import '../../saas/services/client_repository.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/widgets/async_state_view.dart';

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
        _error = 'Sin organización';
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
          content: Text(auth.error ?? 'No se pudo crear la organización'),
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
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo cliente' : 'Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(labelText: 'Identificación'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Importar clientes CSV'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pega el CSV. Primera fila = cabecera.\n'
                'Plantilla: ${ClientCsvImportService.templateHeader}',
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
                child: const Text('Copiar plantilla'),
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
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
        ],
      ),
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
                ? 'No hay filas válidas'
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
    final extra = parsed.errors.isEmpty
        ? ''
        : ' · ${parsed.errors.length} fila(s) con error';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Importados: $saved$extra')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            tooltip: 'Importar CSV',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _importCsv,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Cliente'),
      ),
      body: ContentConstraint(
        child: AsyncStateView(
          loading: _loading,
          error: _error,
          isEmpty: !_loading && _items.isEmpty,
          emptyTitle: 'Sin clientes',
          emptySubtitle: 'Crea el primero para reutilizarlo en cotizaciones.',
          emptyIcon: Icons.people_outline,
          onRetry: _error?.toString() == 'Sin organización'
              ? _createOrganization
              : _load,
          retryLabel: _error?.toString() == 'Sin organización'
              ? 'Crear organización'
              : null,
          retryIcon: _error?.toString() == 'Sin organización'
              ? Icons.apartment_rounded
              : null,
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
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar'),
                        content: Text('¿Eliminar a ${c.name}?'),
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
