import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money_cents.dart';
import '../../saas/domain/org_enums.dart';
import '../../saas/models/catalog_item.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/catalog_repository.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/widgets/async_state_view.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<CatalogItem> _items = [];
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
      final list = await CatalogRepository.instance.list(orgId);
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

  Future<void> _edit([CatalogItem? existing]) async {
    final orgId = _orgId;
    if (orgId == null) return;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'und');
    final priceCtrl = TextEditingController(
      text: existing?.unitPrice.asDecimal.toStringAsFixed(2) ?? '',
    );
    final taxCtrl = TextEditingController(
      text: existing != null ? (existing.taxBps / 100).toStringAsFixed(1) : '0',
    );
    final categoryCtrl = TextEditingController(
      text: existing?.category ?? 'General',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo ítem' : 'Editar ítem'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Código'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Unidad'),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio unitario',
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: taxCtrl,
                decoration: const InputDecoration(labelText: 'Impuesto %'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final price = num.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final taxPct = num.tryParse(taxCtrl.text.replaceAll(',', '.')) ?? 0;
    final now = DateTime.now().toUtc();

    final item = CatalogItem(
      id: existing?.id ?? const Uuid().v4(),
      organizationId: orgId,
      code: codeCtrl.text.trim(),
      name: name,
      description: descCtrl.text.trim(),
      category: categoryCtrl.text.trim().isEmpty
          ? 'General'
          : categoryCtrl.text.trim(),
      unit: unitCtrl.text.trim().isEmpty ? 'und' : unitCtrl.text.trim(),
      unitPrice: MoneyCents.fromDecimal(price),
      taxBps: (taxPct * 100).round(),
      status: CatalogItemStatus.active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await CatalogRepository.instance.upsert(organizationId: orgId, item: item);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Ítem'),
      ),
      body: ContentConstraint(
        child: AsyncStateView(
          loading: _loading,
          error: _error,
          isEmpty: !_loading && _items.isEmpty,
          emptyTitle: 'Catálogo vacío',
          emptySubtitle: 'Agrega productos o servicios reutilizables.',
          emptyIcon: Icons.inventory_2_outlined,
          onRetry: _load,
          child: ListView.separated(
            padding: AppSpacing.page,
            itemCount: _items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = _items[i];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.category} · ${item.unitPrice.format()} / ${item.unit}',
                ),
                onTap: () => _edit(item),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final orgId = _orgId;
                    if (orgId == null) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar'),
                        content: Text('¿Eliminar ${item.name}?'),
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
                      await CatalogRepository.instance.delete(orgId, item.id);
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
