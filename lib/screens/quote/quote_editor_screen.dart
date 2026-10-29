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
import '../../l10n/enum_l10n.dart';
import '../../l10n/l10n_ext.dart';
import '../../saas/historial/historial_query.dart';
import '../../theme/app_theme.dart';
import '../../ui/layout/responsive.dart';
import '../../ui/tokens/app_icons.dart';
import '../catalog/catalog_screen.dart';
import '../clients/clients_screen.dart';
import '../preview_screen.dart';
import 'quote_branding_section.dart';
import 'quote_line_item_sheet.dart';

/// Resuelve códigos [QuoteEditorMsg] o deja pasar errores técnicos crudos.
String resolveQuoteEditorMessage(AppLocalizations l10n, String? codeOrRaw) {
  if (codeOrRaw == null || codeOrRaw.isEmpty) return '';
  return switch (codeOrRaw) {
    QuoteEditorMsg.draftResumed => l10n.quoteEditorDraftResumed,
    QuoteEditorMsg.draftSavedLocal => l10n.quoteEditorDraftSavedLocal,
    QuoteEditorMsg.unsavedCloud => l10n.quoteEditorUnsavedCloud,
    QuoteEditorMsg.savedLocalPending => l10n.quoteEditorSavedLocalPending,
    QuoteEditorMsg.savedOk => l10n.quoteEditorSavedOk,
    QuoteEditorMsg.validationClient => l10n.quoteEditorValidationClient,
    QuoteEditorMsg.validationItems => l10n.quoteEditorValidationItems,
    _ => codeOrRaw,
  };
}

/// Localiza etiquetas canónicas de pago sin alterar el valor persistido.
String localizePaymentLabel(AppLocalizations l10n, String raw) {
  final key = raw.trim().toUpperCase();
  return switch (key) {
    'UN SOLO PAGO' => l10n.paymentLabelSingle,
    'ANTICIPO' => l10n.paymentLabelDeposit,
    'ENTREGA' => l10n.paymentLabelDelivery,
    'SALDO' => l10n.paymentLabelBalance,
    _ => raw,
  };
}

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
      final l10n = context.l10n;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.newQuoteFab)),
        body: Center(
          child: Padding(
            padding: AppSpacing.page,
            child: Text(
              l10n.noActiveOrganization,
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
        final l10n = context.l10n;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              controller.isNew ? l10n.newQuoteFab : controller.quote.number,
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
                  content: Text(
                    resolveQuoteEditorMessage(l10n, controller.error),
                  ),
                  actions: [
                    TextButton(
                      onPressed: controller.clearError,
                      child: Text(l10n.close),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.stepClient,
      l10n.stepItems,
      l10n.stepConditions,
      l10n.stepReview,
    ];
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

  /// El theme usa [Size.fromHeight(48)] (ancho infinito). En un [Row] eso
  /// provoca `BoxConstraints forces an infinite width`; aquí se limita solo
  /// la altura mínima y el ancho queda al contenido.
  static final ButtonStyle _filledInRow = FilledButton.styleFrom(
    minimumSize: const Size(0, 48),
  );
  static final ButtonStyle _outlinedInRow = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 48),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totals = controller.totals;
    final busy = controller.saving || controller.initializing;

    final totalLabel = Text(
      totals.total.format(),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    final primary = controller.step < QuoteEditorController.stepCount - 1
        ? FilledButton(
            style: _filledInRow,
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
            child: Text(l10n.next),
          )
        : FilledButton(
            style: _filledInRow,
            onPressed: busy
                ? null
                : () async {
                    final ok = await controller.saveToCloud();
                    if (!context.mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.quoteSaved(controller.quote.number),
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
                : Text(l10n.save),
          );

    return AdaptiveActionBar(
      leading: [
        if (controller.step > 0)
          OutlinedButton(
            style: _outlinedInRow,
            onPressed: busy ? null : controller.back,
            child: Text(l10n.back),
          ),
      ],
      center: totalLabel,
      trailing: [primary],
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
          return Padding(
            padding: AppSpacing.page,
            child: Text(ctx.l10n.noClientsHint),
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
    final l10n = context.l10n;
    return ListView(
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.clientAndData,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: _pickClient,
              icon: const Icon(Icons.person_search),
              label: Text(l10n.choose),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientsScreen()),
                );
              },
              child: Text(l10n.manage),
            ),
          ],
        ),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: '${l10n.stepClient} *'),
          onChanged: widget.controller.setClientName,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _ubicacion,
          decoration: InputDecoration(labelText: l10n.fieldLocation),
          onChanged: (v) => widget.controller.setLegacyField('ubicacion', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _tipo,
          decoration: InputDecoration(labelText: l10n.fieldServiceType),
          onChanged: (v) => widget.controller.setLegacyField('tipoServicio', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _desc,
          decoration: InputDecoration(labelText: l10n.description),
          maxLines: 3,
          onChanged: (v) => widget.controller.setLegacyField('descripcion', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _validez,
          decoration: InputDecoration(
            labelText: l10n.fieldValidityDays,
            hintText: l10n.hintDaysExample,
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
    final l10n = context.l10n;

    return Column(
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.stepItems, style: Theme.of(context).textTheme.titleMedium),
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
                      return Padding(
                        padding: AppSpacing.page,
                        child: Text(ctx.l10n.emptyCatalogHint),
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
              child: Text(l10n.catalog),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final item = await showQuoteLineItemSheet(context);
                if (item != null) controller.upsertItem(item);
              },
              icon: const Icon(AppIcons.agregarLinea),
              label: Text(l10n.catalogFab),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(l10n.emptyNoItemsYet))
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
                            tooltip: l10n.edit,
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
                            tooltip: l10n.delete,
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
            child: Text(l10n.manageCatalog),
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
  late final TextEditingController _plazo;
  late final TextEditingController _validez;
  late final TextEditingController _garantia;
  late final TextEditingController _terms;
  late final TextEditingController _anticipoPct;
  late final TextEditingController _saldoPct;

  @override
  void initState() {
    super.initState();
    final q = widget.controller.quote;
    final legacy = q.legacyFields;
    _include = TextEditingController();
    _exclude = TextEditingController();
    _note = TextEditingController();
    _globalDisc = TextEditingController(
      text: (q.globalDiscountBps / 100).toStringAsFixed(1),
    );
    _charges = TextEditingController(
      text: q.charges.asDecimal.toStringAsFixed(2),
    );
    _plazo = TextEditingController(text: '${legacy['tiempoEstimado'] ?? ''}');
    final days = legacy['validezDias'];
    _validez = TextEditingController(text: days == null ? '' : '$days');
    _garantia = TextEditingController(text: '${legacy['garantia'] ?? ''}');
    _terms = TextEditingController(text: q.conditions ?? '');
    final split = _paymentSplit(q);
    _anticipoPct = TextEditingController(text: split.$1);
    _saldoPct = TextEditingController(text: split.$2);
    // Alinea UI con payments del modelo / PDF según modalidad.
    if (q.payments.isEmpty ||
        (q.paymentMode == PaymentMode.split &&
            q.legacyFields['anticipoPct'] == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.controller.quote.paymentMode == PaymentMode.single) {
          widget.controller.setPaymentMode(PaymentMode.single);
        } else {
          _applyPaymentPercents();
        }
      });
    }
  }

  @override
  void dispose() {
    _include.dispose();
    _exclude.dispose();
    _note.dispose();
    _globalDisc.dispose();
    _charges.dispose();
    _plazo.dispose();
    _validez.dispose();
    _garantia.dispose();
    _terms.dispose();
    _anticipoPct.dispose();
    _saldoPct.dispose();
    super.dispose();
  }

  /// Deriva % de anticipo/saldo desde legacy o payments guardados.
  (String, String) _paymentSplit(Quote q) {
    final aLegacy = q.legacyFields['anticipoPct'];
    final sLegacy = q.legacyFields['saldoPct'];
    if (aLegacy is num || sLegacy is num) {
      final a = (aLegacy as num?)?.round() ?? 50;
      final s = (sLegacy as num?)?.round() ?? (100 - a);
      return ('$a', '$s');
    }
    final payments = q.payments;
    if (payments.isEmpty) return ('50', '50');
    final totalCents = widget.controller.totals.total.cents;
    if (totalCents <= 0) return ('50', '50');

    int anticipo = 0;
    int saldo = 0;
    for (final p in payments) {
      final label = '${p['label'] ?? ''}'.toLowerCase();
      final cents = (p['amountCents'] as num?)?.round() ?? 0;
      if (label.contains('anticipo') || label.contains('entrada')) {
        anticipo += cents;
      } else if (label.contains('saldo')) {
        saldo += cents;
      }
    }
    if (anticipo == 0 && saldo == 0 && payments.isNotEmpty) {
      anticipo = (payments.first['amountCents'] as num?)?.round() ?? 0;
      if (payments.length > 1) {
        saldo = (payments.last['amountCents'] as num?)?.round() ?? 0;
      }
    }
    final aPct = ((anticipo * 100) / totalCents).round().clamp(0, 100);
    final sPct = saldo > 0
        ? ((saldo * 100) / totalCents).round().clamp(0, 100)
        : (100 - aPct);
    return ('$aPct', '$sPct');
  }

  Widget _paymentBlock(Map<String, dynamic> p) {
    final l10n = context.l10n;
    final rawLabel = '${p['label'] ?? ''}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            localizePaymentLabel(l10n, rawLabel),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MoneyCents((p['amountCents'] as num?)?.round() ?? 0).format(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBlocks(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 420 && payments.length > 1;
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < payments.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _paymentBlock(payments[i]),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < payments.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _paymentBlock(payments[i])),
            ],
          ],
        );
      },
    );
  }

  void _applyPaymentPercents() {
    final anticipo = (num.tryParse(_anticipoPct.text.replaceAll(',', '.')) ?? 0)
        .clamp(0, 100)
        .toDouble();
    var saldo = (num.tryParse(_saldoPct.text.replaceAll(',', '.')) ?? 0)
        .clamp(0, 100)
        .toDouble();
    if (anticipo + saldo > 100) {
      saldo = 100 - anticipo;
      _saldoPct.text = saldo.toStringAsFixed(
        saldo == saldo.roundToDouble() ? 0 : 1,
      );
    }
    widget.controller.setPaymentPercents(
      anticipoPct: anticipo,
      saldoPct: saldo,
    );
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
          runSpacing: 4,
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
                decoration: InputDecoration(hintText: context.l10n.hintAddChip),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isEmpty) return;
                  onChanged([...values, t]);
                  input.clear();
                },
              ),
            ),
            IconButton(
              icon: const Icon(AppIcons.agregarLinea),
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
    final l10n = context.l10n;
    final q = widget.controller.quote;
    final totals = widget.controller.totals;
    return ListView(
      children: [
        Text(
          l10n.commercialConditions,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.paymentMethod, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.totalBase(totals.total.format()),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final button = SegmentedButton<PaymentMode>(
              segments: [
                for (final m in PaymentMode.values)
                  ButtonSegment(value: m, label: Text(m.l10nLabel(l10n))),
              ],
              selected: {q.paymentMode},
              onSelectionChanged: (s) {
                final mode = s.first;
                widget.controller.setPaymentMode(mode);
                if (mode == PaymentMode.split) {
                  final split = _paymentSplit(widget.controller.quote);
                  _anticipoPct.text = split.$1;
                  _saldoPct.text = split.$2;
                }
                setState(() {});
              },
            );
            if (constraints.maxWidth < 360) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 360, child: button),
              );
            }
            return button;
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (q.paymentMode == PaymentMode.split) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _anticipoPct,
                  decoration: InputDecoration(
                    labelText: l10n.fieldDepositPercent,
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _applyPaymentPercents(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _saldoPct,
                  decoration: InputDecoration(
                    labelText: l10n.fieldBalancePercent,
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _applyPaymentPercents(),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                _anticipoPct.text = '50';
                _saldoPct.text = '50';
                _applyPaymentPercents();
              },
              child: Text(l10n.use5050Split),
            ),
          ),
        ] else
          Text(
            l10n.singlePaymentHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.sm),
        _paymentBlocks(q.payments),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _plazo,
          decoration: InputDecoration(
            labelText: l10n.fieldDeliveryTime,
            hintText: l10n.hintDeliveryTime,
          ),
          onChanged: (v) =>
              widget.controller.setLegacyField('tiempoEstimado', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _validez,
          decoration: InputDecoration(
            labelText: l10n.fieldQuoteValidityDays,
            hintText: l10n.hintDaysExample,
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final days = int.tryParse(v.trim());
            widget.controller.setValidezDias(days);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _garantia,
          decoration: InputDecoration(
            labelText: l10n.fieldWarranty,
            hintText: l10n.hintWarranty,
          ),
          maxLines: 2,
          onChanged: (v) => widget.controller.setLegacyField('garantia', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _terms,
          decoration: InputDecoration(
            labelText: l10n.fieldCommercialTerms,
            hintText: l10n.hintCommercialTerms,
          ),
          maxLines: 3,
          onChanged: widget.controller.setConditions,
        ),
        const SizedBox(height: AppSpacing.lg),
        _chipEditor(
          title: l10n.includesSection,
          values: q.includes,
          input: _include,
          onChanged: widget.controller.setIncludes,
        ),
        _chipEditor(
          title: l10n.excludesSection,
          values: q.excludes,
          input: _exclude,
          onChanged: widget.controller.setExcludes,
        ),
        _chipEditor(
          title: l10n.notesSection,
          values: q.notes,
          input: _note,
          onChanged: widget.controller.setNotes,
        ),
        TextField(
          controller: _globalDisc,
          decoration: InputDecoration(labelText: l10n.fieldGlobalDiscount),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            final pct = num.tryParse(v.replaceAll(',', '.')) ?? 0;
            widget.controller.setGlobalDiscountBps((pct * 100).round());
            // Recalcula tramos sobre el nuevo total.
            _applyPaymentPercents();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _charges,
          decoration: InputDecoration(
            labelText: l10n.fieldExtraCharges,
            prefixText: r'$ ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            final n = num.tryParse(v.replaceAll(',', '.')) ?? 0;
            widget.controller.setCharges(MoneyCents.fromDecimal(n));
            _applyPaymentPercents();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<QuoteStatus>(
          key: ValueKey('status-${q.status.id}'),
          initialValue: q.status,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.fieldStatus),
          items: [
            for (final s in QuoteStatus.values)
              DropdownMenuItem(
                value: s,
                child: Text(HistorialQuery.statusLabel(s, l10n)),
              ),
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
    final l10n = context.l10n;
    final q = controller.quote;
    final t = controller.totals;
    return ListView(
      children: [
        Text(l10n.reviewSummary, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(q.clientName),
          subtitle: Text(q.number),
        ),
        Text('${l10n.stepItems}: ${q.items.length}'),
        Text('${l10n.subtotal}: ${t.linesGross.format()}'),
        Text('${context.l10n.discountsLabel}: -${t.linesDiscount.format()}'),
        Text('${l10n.taxes}: ${t.linesTax.format()}'),
        if (t.globalDiscount.cents > 0)
          Text('${context.l10n.globalDiscountLabel}: -${t.globalDiscount.format()}'),
        if (t.charges.cents > 0)
          Text('${l10n.fieldExtraCharges}: ${t.charges.format()}'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${l10n.total}: ${t.total.format()}',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (controller.draftHint != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            resolveQuoteEditorMessage(l10n, controller.draftHint),
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
          label: Text(l10n.saveAndPreviewPdf),
        ),
      ],
    );
  }
}
