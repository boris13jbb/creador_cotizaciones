import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money_cents.dart';
import '../../l10n/l10n_ext.dart';
import '../../saas/domain/org_enums.dart';
import '../../saas/models/catalog_item.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/catalog_repository.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/tokens/app_icons.dart';
import '../../ui/widgets/async_state_view.dart';
import 'catalog_import_flow.dart';

const _kNoOrganization = _NoOrganizationMarker();

class _NoOrganizationMarker {
  const _NoOrganizationMarker();
}

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
        _error = _kNoOrganization;
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
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(
            existing == null ? l10n.newCatalogItem : l10n.editCatalogItem,
          ),
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
                  controller: codeCtrl,
                  decoration: InputDecoration(labelText: l10n.fieldCode),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: l10n.description),
                ),
                TextField(
                  controller: categoryCtrl,
                  decoration: InputDecoration(labelText: l10n.fieldCategory),
                ),
                TextField(
                  controller: unitCtrl,
                  decoration: InputDecoration(labelText: l10n.fieldUnit),
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.fieldUnitPrice,
                    prefixText: r'$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: taxCtrl,
                  decoration: InputDecoration(labelText: l10n.fieldTaxPercent),
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
    final l10n = context.l10n;
    final noOrg = _error == _kNoOrganization;
    final viewError = noOrg ? l10n.noOrganization : _error;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalog),
        actions: [
          IconButton(
            tooltip: l10n.catalogImportTitle,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _orgId == null || _orgId!.isEmpty
                ? null
                : () async {
                    final orgId = _orgId;
                    if (orgId == null) return;
                    final changed = await showCatalogImportFlow(
                      context: context,
                      organizationId: orgId,
                      existingItems: _items,
                    );
                    if (changed && mounted) await _load();
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(),
        icon: const Icon(AppIcons.agregarCatalogo),
        label: Text(l10n.catalogFab),
      ),
      body: ContentConstraint(
        padding: Responsive.isCompact(context) ? null : Responsive.pagePadding(context),
        child: AsyncStateView(
          loading: _loading,
          error: viewError,
          isEmpty: !_loading && _items.isEmpty,
          emptyTitle: l10n.emptyCatalog,
          emptySubtitle: l10n.emptyAddCatalogItems,
          emptyIcon: Icons.inventory_2_outlined,
          onRetry: noOrg ? _createOrganization : _load,
          retryLabel: noOrg ? l10n.createOrganization : null,
          retryIcon: noOrg ? Icons.apartment_rounded : null,
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
                      builder: (ctx) {
                        final dlg = ctx.l10n;
                        return AlertDialog(
                          title: Text(dlg.delete),
                          content: Text(dlg.deleteConfirmItem(item.name)),
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
