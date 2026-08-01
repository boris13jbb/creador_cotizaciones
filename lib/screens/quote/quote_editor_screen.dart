import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/money_cents.dart';
import '../../models/cotizacion.dart';
import '../../saas/domain/org_enums.dart';
import '../../saas/domain/quote_totals.dart';
import '../../saas/models/catalog_item.dart';
import '../../saas/models/org_client.dart';
import '../../saas/models/quote.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/providers/quote_editor_controller.dart';
import '../../saas/services/catalog_repository.dart';
import '../../saas/services/client_repository.dart';
import '../../saas/services/quote_mapper.dart';
import '../../ui/layout/responsive.dart';
import '../catalog/catalog_screen.dart';
import '../clients/clients_screen.dart';
import '../preview_screen.dart';
import 'quote_branding_section.dart';
import 'quote_line_item_sheet.dart';

/// Editor profesional por pasos (cliente → ítems → condiciones → revisar).
class QuoteEditorScreen extends StatefulWidget {
  const QuoteEditorScreen({
    super.key,
    this.cotizacion,
    this.initialQuote,
    this.resumeDraft = true,
  });

  final Cotizacion? cotizacion;
  final Quote? initialQuote;
  final bool resumeDraft;

  @override
  State<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends State<QuoteEditorScreen> {
  QuoteEditorController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final auth = context.read<AuthController>();
    final orgId = auth.organizationId;
    if (orgId == null || orgId.isEmpty) return;
    _controller = QuoteEditorController(
      uid: auth.user?.uid ?? auth.restSession?.uid ?? auth.profile?.uid ?? '',
      organizationId: orgId,
      initialCotizacion: widget.cotizacion,
      initialQuote: widget.initialQuote,
      resumeDraft: widget.resumeDraft && widget.cotizacion == null,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final orgId = auth.organizationId;
    if (orgId == null || orgId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cotización')),
        body: const Center(
          child: Padding(
            padding: AppSpacing.page,
            child: Text(
              'Aún no hay organización activa. Cierra sesión e inicia de nuevo '
              'para crear tu empresa automática.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final wide = Responsive.useNavigationRail(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              controller.isNew ? 'Nueva cotización' : controller.quote.number,
            ),
            actions: [
              if (controller.draftHint != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      controller.dirty ? '•' : '✓',
                      style: TextStyle(
                        color: controller.dirty
                            ? Colors.amber
                            : Colors.lightGreenAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: wide
                    ? Row(
                        children: [
                          for (
                            var i = 0;
                            i < QuoteEditorController.stepCount;
                            i++
                          )
                            Expanded(
                              child: _StepChip(
                                index: i,
                                selected: controller.step == i,
                                onTap: () => controller.goTo(i),
                              ),
                            ),
                        ],
                      )
                    : SizedBox(
                        height: 72,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (
                              var i = 0;
                              i < QuoteEditorController.stepCount;
                              i++
                            )
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _StepChip(
                                  index: i,
                                  selected: controller.step == i,
                                  onTap: () => controller.goTo(i),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              if (controller.error != null)
                MaterialBanner(
                  content: Text(controller.error!),
                  actions: [
                    TextButton(
                      onPressed: controller.clearError,
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              Expanded(
                child: ContentConstraint(
                  padding: AppSpacing.page,
                  child: controller.initializing
                      ? const Center(child: CircularProgressIndicator())
                      : _StepBody(
                          key: ValueKey('step-${controller.quote.id}'),
                          controller: controller,
                        ),
                ),
              ),
              _BottomBar(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  static const labels = ['Cliente', 'Ítems', 'Condiciones', 'Revisar'];

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('${index + 1}. ${labels[index]}'),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});

  final QuoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final totals = controller.totals;
    final busy = controller.saving || controller.initializing;
    return Material(
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (controller.step > 0)
                OutlinedButton(
                  onPressed: busy ? null : controller.back,
                  child: const Text('Atrás'),
                ),
              const Spacer(),
              Flexible(
                child: Text(
                  totals.total.format(),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (controller.step < QuoteEditorController.stepCount - 1)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () {
                          final err = controller.validateStep(controller.step);
                          if (err != null) {
                            controller.reportStepError(err);
                            return;
                          }
                          controller.next();
                        },
                  child: const Text('Siguiente'),
                )
              else
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await controller.saveToCloud();
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Guardada ${controller.quote.number}',
                                ),
                              ),
                            );
                            Navigator.pop(context, true);
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({super.key, required this.controller});

  final QuoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    return switch (controller.step) {
      0 => _ClientStep(controller: controller),
      1 => _ItemsStep(controller: controller),
      2 => _ConditionsStep(controller: controller),
      _ => _ReviewStep(controller: controller),
    };
  }
}

class _ClientStep extends StatefulWidget {
  const _ClientStep({required this.controller});
  final QuoteEditorController controller;

  @override
  State<_ClientStep> createState() => _ClientStepState();
}

class _ClientStepState extends State<_ClientStep> {
  late final TextEditingController _name;
  late final TextEditingController _ubicacion;
  late final TextEditingController _tipo;
  late final TextEditingController _desc;
  late final TextEditingController _validez;

  @override
  void initState() {
    super.initState();
    final q = widget.controller.quote;
    final legacy = q.legacyFields;
    _name = TextEditingController(text: q.clientName);
    _ubicacion = TextEditingController(text: '${legacy['ubicacion'] ?? ''}');
    _tipo = TextEditingController(text: '${legacy['tipoServicio'] ?? ''}');
    _desc = TextEditingController(text: '${legacy['descripcion'] ?? ''}');
    final days = legacy['validezDias'];
    _validez = TextEditingController(text: days == null ? '' : '$days');
  }

  @override
  void dispose() {
    _name.dispose();
    _ubicacion.dispose();
    _tipo.dispose();
    _desc.dispose();
    _validez.dispose();
    super.dispose();
  }

  Future<void> _pickClient() async {
    final orgId = widget.controller.organizationId;
    final clients = await ClientRepository.instance.list(orgId);
    if (!mounted) return;
    final selected = await showModalBottomSheet<OrgClient>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        if (clients.isEmpty) {
          return const Padding(
            padding: AppSpacing.page,
            child: Text(
              'No hay clientes. Crea uno desde Mi cuenta → Clientes.',
            ),
          );
        }
        return ListView.builder(
          itemCount: clients.length,
          itemBuilder: (_, i) {
            final c = clients[i];
            return ListTile(
              title: Text(c.name),
              subtitle: Text(
                [
                  c.email,
                  c.phone,
                ].where((e) => e != null && e.isNotEmpty).join(' · '),
              ),
              onTap: () => Navigator.pop(ctx, c),
            );
          },
        );
      },
    );
    if (selected != null) {
      widget.controller.setClient(selected);
      _name.text = selected.name;
      if (selected.address != null) {
        _ubicacion.text = selected.address!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Cliente y datos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: _pickClient,
              icon: const Icon(Icons.person_search),
              label: const Text('Elegir'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientsScreen()),
                );
              },
              child: const Text('Gestionar'),
            ),
          ],
        ),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Cliente *'),
          onChanged: widget.controller.setClientName,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _ubicacion,
          decoration: const InputDecoration(labelText: 'Ubicación'),
          onChanged: (v) => widget.controller.setLegacyField('ubicacion', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo de servicio'),
          onChanged: (v) => widget.controller.setLegacyField('tipoServicio', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _desc,
          decoration: const InputDecoration(labelText: 'Descripción'),
          maxLines: 3,
          onChanged: (v) => widget.controller.setLegacyField('descripcion', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _validez,
          decoration: const InputDecoration(
            labelText: 'Validez (días)',
            hintText: 'Ej. 15',
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final days = int.tryParse(v);
            widget.controller.setValidezDias(days);
          },
        ),
      ],
    );
  }
}

class _ItemsStep extends StatelessWidget {
  const _ItemsStep({required this.controller});
  final QuoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    const calc = QuoteTotalsCalculator();
    final items = controller.quote.items;

    return Column(
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Ítems', style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () async {
                final orgId = controller.organizationId;
                final catalog = await CatalogRepository.instance.list(orgId);
                if (!context.mounted) return;
                final selected = await showModalBottomSheet<CatalogItem>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) {
                    if (catalog.isEmpty) {
                      return const Padding(
                        padding: AppSpacing.page,
                        child: Text(
                          'Catálogo vacío. Agrégalo en Mi cuenta → Catálogo.',
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: catalog.length,
                      itemBuilder: (_, i) {
                        final item = catalog[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.unitPrice.format()),
                          onTap: () => Navigator.pop(ctx, item),
                        );
                      },
                    );
                  },
                );
                if (selected != null) controller.addFromCatalog(selected);
              },
              child: const Text('Catálogo'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final item = await showQuoteLineItemSheet(context);
                if (item != null) controller.upsertItem(item);
              },
              icon: const Icon(Icons.add),
              label: const Text('Ítem'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Sin ítems todavía'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final line = calc.lineAmounts(item);
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.quantity} ${item.unit} × ${item.unitPrice.format()}'
                        '${item.discountBps > 0 ? ' · -${(item.discountBps / 100).toStringAsFixed(1)}%' : ''}'
                        '${item.taxBps > 0 ? ' · +${(item.taxBps / 100).toStringAsFixed(1)}%' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            line.net.format(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final edited = await showQuoteLineItemSheet(
                                context,
                                initial: item,
                              );
                              if (edited != null) {
                                controller.upsertItem(edited);
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => controller.removeItem(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CatalogScreen()),
              );
            },
            child: const Text('Gestionar catálogo'),
          ),
        ),
      ],
    );
  }
}

class _ConditionsStep extends StatefulWidget {
  const _ConditionsStep({required this.controller});
  final QuoteEditorController controller;

  @override
  State<_ConditionsStep> createState() => _ConditionsStepState();
}

class _ConditionsStepState extends State<_ConditionsStep> {
  late final TextEditingController _include;
  late final TextEditingController _exclude;
  late final TextEditingController _note;
  late final TextEditingController _globalDisc;
  late final TextEditingController _charges;

  @override
  void initState() {
    super.initState();
    final q = widget.controller.quote;
    _include = TextEditingController();
    _exclude = TextEditingController();
    _note = TextEditingController();
    _globalDisc = TextEditingController(
      text: (q.globalDiscountBps / 100).toStringAsFixed(1),
    );
    _charges = TextEditingController(
      text: q.charges.asDecimal.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _include.dispose();
    _exclude.dispose();
    _note.dispose();
    _globalDisc.dispose();
    _charges.dispose();
    super.dispose();
  }

  Widget _chipEditor({
    required String title,
    required List<String> values,
    required TextEditingController input,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 8,
          children: [
            for (final v in values)
              InputChip(
                label: Text(v),
                onDeleted: () =>
                    onChanged(values.where((e) => e != v).toList()),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: input,
                decoration: const InputDecoration(hintText: 'Agregar…'),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isEmpty) return;
                  onChanged([...values, t]);
                  input.clear();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final t = input.text.trim();
                if (t.isEmpty) return;
                onChanged([...values, t]);
                input.clear();
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.controller.quote;
    return ListView(
      children: [
        _chipEditor(
          title: 'Incluye',
          values: q.includes,
          input: _include,
          onChanged: widget.controller.setIncludes,
        ),
        _chipEditor(
          title: 'No incluye',
          values: q.excludes,
          input: _exclude,
          onChanged: widget.controller.setExcludes,
        ),
        _chipEditor(
          title: 'Notas',
          values: q.notes,
          input: _note,
          onChanged: widget.controller.setNotes,
        ),
        TextField(
          controller: _globalDisc,
          decoration: const InputDecoration(labelText: 'Descuento global %'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            final pct = num.tryParse(v.replaceAll(',', '.')) ?? 0;
            widget.controller.setGlobalDiscountBps((pct * 100).round());
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _charges,
          decoration: const InputDecoration(
            labelText: 'Cargos adicionales',
            prefixText: r'$ ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            final n = num.tryParse(v.replaceAll(',', '.')) ?? 0;
            widget.controller.setCharges(MoneyCents.fromDecimal(n));
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<QuoteStatus>(
          initialValue: q.status,
          decoration: const InputDecoration(labelText: 'Estado'),
          items: [
            for (final s in QuoteStatus.values)
              DropdownMenuItem(value: s, child: Text(s.id)),
          ],
          onChanged: (s) {
            if (s != null) widget.controller.setStatus(s);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        QuoteBrandingSection(controller: widget.controller),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.controller});
  final QuoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final q = controller.quote;
    final t = controller.totals;
    return ListView(
      children: [
        Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(q.clientName),
          subtitle: Text(q.number),
        ),
        Text('Ítems: ${q.items.length}'),
        Text('Subtotal: ${t.linesGross.format()}'),
        Text('Descuentos: -${t.linesDiscount.format()}'),
        Text('Impuestos: ${t.linesTax.format()}'),
        if (t.globalDiscount.cents > 0)
          Text('Descuento global: -${t.globalDiscount.format()}'),
        if (t.charges.cents > 0) Text('Cargos: ${t.charges.format()}'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Total: ${t.total.format()}',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (controller.draftHint != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            controller.draftHint!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: controller.saving
              ? null
              : () async {
                  final ok = await controller.saveToCloud();
                  if (!context.mounted || !ok) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PreviewScreen(
                        cotizacion: QuoteMapper.toCotizacion(controller.quote),
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Guardar y previsualizar PDF'),
        ),
      ],
    );
  }
}
