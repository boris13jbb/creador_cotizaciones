import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money_cents.dart';
import '../../l10n/l10n_ext.dart';
import '../../saas/domain/quote_totals.dart';
import '../../ui/layout/responsive.dart';

Future<QuoteLineItem?> showQuoteLineItemSheet(
  BuildContext context, {
  QuoteLineItem? initial,
}) {
  return showModalBottomSheet<QuoteLineItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _QuoteLineItemForm(initial: initial),
    ),
  );
}

class _QuoteLineItemForm extends StatefulWidget {
  const _QuoteLineItemForm({this.initial});

  final QuoteLineItem? initial;

  @override
  State<_QuoteLineItemForm> createState() => _QuoteLineItemFormState();
}

class _QuoteLineItemFormState extends State<_QuoteLineItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _qty;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  late final TextEditingController _tax;
  late final TextEditingController _code;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _desc = TextEditingController(text: i?.description ?? '');
    _qty = TextEditingController(text: i != null ? '${i.quantity}' : '1');
    _unit = TextEditingController(text: i?.unit ?? 'und');
    _price = TextEditingController(
      text: i != null ? i.unitPrice.asDecimal.toStringAsFixed(2) : '',
    );
    _discount = TextEditingController(
      text: i != null ? (i.discountBps / 100).toStringAsFixed(1) : '0',
    );
    _tax = TextEditingController(
      text: i != null ? (i.taxBps / 100).toStringAsFixed(1) : '0',
    );
    _code = TextEditingController(text: i?.code ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _qty.dispose();
    _unit.dispose();
    _price.dispose();
    _discount.dispose();
    _tax.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final qty = num.tryParse(_qty.text.replaceAll(',', '.')) ?? 1;
    final price = num.tryParse(_price.text.replaceAll(',', '.')) ?? 0;
    final discPct = num.tryParse(_discount.text.replaceAll(',', '.')) ?? 0;
    final taxPct = num.tryParse(_tax.text.replaceAll(',', '.')) ?? 0;
    Navigator.pop(
      context,
      QuoteLineItem.fromQuantity(
        id: widget.initial?.id ?? const Uuid().v4(),
        catalogItemId: widget.initial?.catalogItemId,
        code: _code.text.trim(),
        name: _name.text.trim(),
        description: _desc.text.trim(),
        unit: _unit.text.trim().isEmpty ? 'und' : _unit.text.trim(),
        quantity: qty,
        unitPrice: MoneyCents.fromDecimal(price),
        discountBps: (discPct * 100).round(),
        taxBps: (taxPct * 100).round(),
        sortOrder: widget.initial?.sortOrder ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null ? l10n.newLineItem : l10n.editLineItem,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.name),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.requiredField
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _desc,
                decoration: InputDecoration(labelText: l10n.description),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      decoration: InputDecoration(
                        labelText: l10n.fieldQuantity,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null || n <= 0) return l10n.invalidQuantity;
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: InputDecoration(labelText: l10n.fieldUnit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _price,
                decoration: InputDecoration(
                  labelText: l10n.fieldUnitPrice,
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n < 0) return l10n.invalidPrice;
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discount,
                      decoration: InputDecoration(
                        labelText: l10n.fieldDiscountPercent,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _tax,
                      decoration: InputDecoration(
                        labelText: l10n.fieldTaxPercent,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(
                  labelText: l10n.fieldCodeOptional,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _submit,
                child: Text(l10n.saveLineItem),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
