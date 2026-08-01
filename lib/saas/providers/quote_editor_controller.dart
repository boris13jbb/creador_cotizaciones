import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money_cents.dart';
import '../../models/cotizacion.dart';
import '../domain/org_enums.dart';
import '../domain/quote_totals.dart';
import '../models/catalog_item.dart';
import '../models/org_client.dart';
import '../models/quote.dart';
import '../services/cloud_cotizacion_repository.dart';
import '../services/quote_draft_store.dart';
import '../services/quote_mapper.dart';

/// Estado del editor por pasos de cotización.
class QuoteEditorController extends ChangeNotifier {
  QuoteEditorController({
    required this.uid,
    required this.organizationId,
    Cotizacion? initialCotizacion,
    Quote? initialQuote,
    this.resumeDraft = true,
  }) {
    _init(initialCotizacion: initialCotizacion, initialQuote: initialQuote);
  }

  final String uid;
  final String organizationId;
  final bool resumeDraft;

  static const calc = QuoteTotalsCalculator();
  static const stepCount = 4;

  int step = 0;
  bool saving = false;
  bool dirty = false;
  String? error;
  String? draftHint;
  late Quote quote;
  bool isNew = true;

  Timer? _draftTimer;

  QuoteTotals get totals => calc.calculate(
    items: quote.items,
    globalDiscountBps: quote.globalDiscountBps,
    globalDiscountFixed: quote.globalDiscountFixed,
    charges: quote.charges,
  );

  Future<void> _init({
    Cotizacion? initialCotizacion,
    Quote? initialQuote,
  }) async {
    if (initialQuote != null) {
      quote = initialQuote.withRecalculatedTotal();
      isNew = false;
      notifyListeners();
      return;
    }

    if (initialCotizacion != null) {
      final existing = await CloudCotizacionRepository.instance.getQuote(
        initialCotizacion.id,
      );
      if (existing != null) {
        quote = existing.withRecalculatedTotal();
        isNew = false;
        notifyListeners();
        return;
      }
      quote = QuoteMapper.fromCotizacion(
        initialCotizacion,
        organizationId: organizationId,
        createdByUid: uid,
      ).withRecalculatedTotal();
      isNew = false;
      notifyListeners();
      return;
    }

    if (resumeDraft) {
      final draft = await QuoteDraftStore.instance.load(uid);
      if (draft != null &&
          draft.organizationId == organizationId &&
          draft.status == QuoteStatus.draft) {
        quote = draft.withRecalculatedTotal();
        isNew = quote.sequence <= 0;
        draftHint = 'Borrador local reanudado';
        dirty = true;
        notifyListeners();
        return;
      }
    }

    final now = DateTime.now().toUtc();
    quote = Quote(
      id: const Uuid().v4(),
      organizationId: organizationId,
      number: 'BORRADOR',
      sequence: 0,
      status: QuoteStatus.draft,
      clientName: '',
      issueDate: now,
      items: const [],
      total: MoneyCents.zero,
      createdByUid: uid,
      createdAt: now,
      updatedAt: now,
      legacyFields: {
        'ubicacion': '',
        'tipoServicio': '',
        'cantidadEquipos': '',
        'tiempoEstimado': '',
        'descripcion': '',
      },
    );
    notifyListeners();
  }

  void goTo(int index) {
    if (index < 0 || index >= stepCount) return;
    step = index;
    notifyListeners();
  }

  void next() {
    if (step < stepCount - 1) {
      step++;
      notifyListeners();
    }
  }

  void back() {
    if (step > 0) {
      step--;
      notifyListeners();
    }
  }

  void _touch(Quote Function(Quote q) update) {
    quote = update(quote).withRecalculatedTotal();
    dirty = true;
    draftHint = 'Cambios sin guardar en la nube';
    error = null;
    notifyListeners();
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await QuoteDraftStore.instance.save(uid, quote);
        draftHint = 'Borrador guardado en este dispositivo';
        notifyListeners();
      } catch (e) {
        debugPrint('draft save: $e');
      }
    });
  }

  void setClient(OrgClient client) {
    _touch(
      (q) => q.copyWith(
        clientId: client.id,
        clientName: client.name,
        legacyFields: {
          ...q.legacyFields,
          if (client.address != null && client.address!.isNotEmpty)
            'ubicacion': client.address,
        },
      ),
    );
  }

  void setClientName(String name) {
    _touch((q) => q.copyWith(clientName: name));
  }

  void setLegacyField(String key, String value) {
    _touch((q) => q.copyWith(legacyFields: {...q.legacyFields, key: value}));
  }

  void setValidezDias(int? days) {
    _touch((q) {
      final due = days == null ? null : q.issueDate.add(Duration(days: days));
      return q.copyWith(
        dueDate: due,
        clearDueDate: days == null,
        legacyFields: {...q.legacyFields, 'validezDias': days},
      );
    });
  }

  void setSubtitle(String? value) => _touch((q) => q.copyWith(subtitle: value));

  void setFooter(String? value) => _touch((q) => q.copyWith(footerText: value));

  void setIncludes(List<String> values) =>
      _touch((q) => q.copyWith(includes: values));

  void setExcludes(List<String> values) =>
      _touch((q) => q.copyWith(excludes: values));

  void setNotes(List<String> values) =>
      _touch((q) => q.copyWith(notes: values));

  void setGlobalDiscountBps(int bps) =>
      _touch((q) => q.copyWith(globalDiscountBps: bps));

  void setCharges(MoneyCents charges) =>
      _touch((q) => q.copyWith(charges: charges));

  void setPayments(List<Map<String, dynamic>> payments) =>
      _touch((q) => q.copyWith(payments: payments));

  void setStatus(QuoteStatus status) =>
      _touch((q) => q.copyWith(status: status));

  void setLogoPath(String? path) =>
      _touch((q) => q.copyWith(logoPath: path, clearLogoPath: path == null));

  void setColorsJson(String? json) => _touch(
        (q) => q.copyWith(colorsJson: json, clearColorsJson: json == null),
      );

  void upsertItem(QuoteLineItem item) {
    _touch((q) {
      final items = [...q.items];
      final idx = items.indexWhere((e) => e.id == item.id);
      if (idx >= 0) {
        items[idx] = item;
      } else {
        items.add(item.copyWith(sortOrder: items.length));
      }
      return q.copyWith(items: items);
    });
  }

  void addFromCatalog(CatalogItem item) {
    upsertItem(
      QuoteLineItem.fromQuantity(
        id: const Uuid().v4(),
        catalogItemId: item.id,
        code: item.code,
        name: item.name,
        description: item.description,
        unit: item.unit,
        quantity: 1,
        unitPrice: item.unitPrice,
        taxBps: item.taxBps,
        sortOrder: quote.items.length,
      ),
    );
  }

  void removeItem(String id) {
    _touch((q) => q.copyWith(items: q.items.where((e) => e.id != id).toList()));
  }

  String? validateStep(int index) {
    switch (index) {
      case 0:
        if (quote.clientName.trim().isEmpty) {
          return 'Indica el cliente';
        }
        return null;
      case 1:
        if (quote.items.isEmpty) return 'Agrega al menos un ítem';
        return null;
      default:
        return null;
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void reportStepError(String message) {
    error = message;
    notifyListeners();
  }

  Future<bool> saveToCloud({QuoteStatus? status}) async {
    final stepError = validateStep(0) ?? validateStep(1);
    if (stepError != null) {
      error = stepError;
      notifyListeners();
      return false;
    }

    saving = true;
    error = null;
    notifyListeners();
    try {
      var toSave = quote;
      if (status != null) {
        toSave = toSave.copyWith(status: status);
      }
      final saved = await CloudCotizacionRepository.instance.saveQuote(
        toSave,
        isNew: isNew,
      );
      quote = saved;
      isNew = false;
      dirty = false;
      draftHint = 'Guardado en la nube';
      await QuoteDraftStore.instance.clear(uid);
      saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      saving = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> discardDraft() async {
    await QuoteDraftStore.instance.clear(uid);
    draftHint = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    super.dispose();
  }
}
