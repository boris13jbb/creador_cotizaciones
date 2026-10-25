import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money_cents.dart';
import '../../models/cotizacion.dart';
import '../domain/org_enums.dart';
import '../domain/quote_totals.dart';
import '../models/catalog_item.dart';
import '../models/org_branding.dart';
import '../models/org_client.dart';
import '../models/organization.dart';
import '../models/quote.dart';
import '../offline/offline_local_store.dart';
import '../offline/offline_sync_status.dart';
import '../services/cloud_cotizacion_repository.dart';
import '../services/organization_service.dart';
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
  }) : quote = _blankQuote(uid: uid, organizationId: organizationId) {
    // quote queda listo de inmediato; _init puede reemplazarlo al cargar draft/remoto.
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

  /// true mientras se carga borrador o cotización existente.
  bool initializing = true;
  String? error;
  String? draftHint;
  Quote quote;
  bool isNew = true;

  Timer? _draftTimer;

  QuoteTotals get totals => calc.calculate(
    items: quote.items,
    globalDiscountBps: quote.globalDiscountBps,
    globalDiscountFixed: quote.globalDiscountFixed,
    charges: quote.charges,
  );

  static Quote _blankQuote({
    required String uid,
    required String organizationId,
  }) {
    final now = DateTime.now().toUtc();
    return Quote(
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
  }

  Future<void> _init({
    Cotizacion? initialCotizacion,
    Quote? initialQuote,
  }) async {
    try {
      if (initialQuote != null) {
        quote = initialQuote.withRecalculatedTotal();
        isNew = false;
        return;
      }

      if (initialCotizacion != null) {
        final existing = await CloudCotizacionRepository.instance.getQuote(
          initialCotizacion.id,
        );
        if (existing != null) {
          quote = existing.withRecalculatedTotal();
          isNew = false;
          return;
        }
        quote = QuoteMapper.fromCotizacion(
          initialCotizacion,
          organizationId: organizationId,
          createdByUid: uid,
        ).withRecalculatedTotal();
        isNew = false;
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
          return;
        }
      }

      // Cotización nueva: aplica identidad visual de la organización.
      await applyOrganizationBranding();
    } catch (e, st) {
      debugPrint('QuoteEditorController._init: $e\n$st');
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  /// Copia logo/colores/layout de la org a la cotización (sin marcar dirty).
  Future<void> applyOrganizationBranding({Organization? organization}) async {
    try {
      final org =
          organization ??
          await OrganizationService.instance.getOrganization(organizationId);
      if (org == null) return;
      final identity = org.visualIdentity;
      quote = quote.copyWith(
        logoPath: identity.logoUrl,
        clearLogoPath: !identity.hasLogo,
        colorsJson: identity.colorsJson,
        clearColorsJson:
            identity.colorsJson == null || identity.colorsJson!.isEmpty,
        legacyFields: {
          ...quote.legacyFields,
          ...identity.toQuoteLegacyFields(),
        },
      );
    } catch (e, st) {
      debugPrint('applyOrganizationBranding: $e\n$st');
    }
  }

  void applyLogoLayout({
    double? logoSizePt,
    LogoAlignment? alignment,
    LogoPlacement? placement,
  }) {
    _touch((q) {
      final legacy = {...q.legacyFields};
      if (logoSizePt != null) {
        legacy['logoSizePt'] = logoSizePt.clamp(
          OrgBranding.minLogoSizePt,
          OrgBranding.maxLogoSizePt,
        );
      }
      if (alignment != null) legacy['logoAlignment'] = alignment.id;
      if (placement != null) legacy['logoPlacement'] = placement.id;
      return q.copyWith(legacyFields: legacy);
    });
  }

  /// Personaliza marca de agua solo en esta cotización (no altera la org).
  void applyWatermarkSettings({
    bool? enabled,
    int? opacityPct,
    WatermarkSize? size,
    WatermarkPosition? position,
  }) {
    _touch((q) {
      final legacy = {...q.legacyFields};
      if (enabled != null) legacy['watermarkEnabled'] = enabled;
      if (opacityPct != null) {
        legacy['watermarkOpacityPct'] = opacityPct.clamp(
          OrgBranding.minWatermarkOpacityPct,
          OrgBranding.maxWatermarkOpacityPct,
        );
      }
      if (size != null) legacy['watermarkSize'] = size.id;
      if (position != null) legacy['watermarkPosition'] = position.id;
      return q.copyWith(legacyFields: legacy);
    });
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
    var next = update(quote).withRecalculatedTotal();
    next = _reconcilePayments(next);
    quote = next;
    dirty = true;
    draftHint = 'Cambios sin guardar en la nube';
    error = null;
    notifyListeners();
    _scheduleDraftSave();
  }

  /// Recalcula tramos de pago al cambiar total o modalidad (sin alterar totales).
  Quote _reconcilePayments(Quote q) {
    if (q.paymentMode == PaymentMode.single) {
      final payments = buildSinglePayment(q.total);
      if (_samePayments(q.payments, payments)) return q;
      return q.copyWith(payments: payments);
    }

    final anticipoRaw = q.legacyFields['anticipoPct'] as num?;
    final saldoRaw = q.legacyFields['saldoPct'] as num?;
    // Cotización antigua o aún sin %: no inventar 50/50; solo reescalar si hay tramos.
    if (anticipoRaw == null && saldoRaw == null) {
      if (q.payments.isEmpty) return q;
      return _scalePaymentsToTotal(q);
    }

    final anticipo = (anticipoRaw ?? 50).toDouble();
    final saldo = (saldoRaw ?? 50).toDouble();
    final payments = buildSplitPayments(
      total: q.total,
      anticipoPct: anticipo,
      saldoPct: saldo,
    );
    if (_samePayments(q.payments, payments)) return q;
    return q.copyWith(payments: payments);
  }

  /// Reparte el nuevo total respetando la proporción de tramos existentes.
  Quote _scalePaymentsToTotal(Quote q) {
    final totalCents = q.total.cents;
    final currentSum = q.payments.fold<int>(
      0,
      (a, p) => a + ((p['amountCents'] as num?)?.round() ?? 0),
    );
    if (currentSum == totalCents) return q;
    if (currentSum <= 0 || totalCents < 0) {
      return q.copyWith(
        payments: buildSplitPayments(
          total: q.total,
          anticipoPct: 50,
          saldoPct: 50,
        ),
      );
    }

    final scaled = <Map<String, dynamic>>[];
    var allocated = 0;
    for (var i = 0; i < q.payments.length; i++) {
      final p = Map<String, dynamic>.from(q.payments[i]);
      if (i == q.payments.length - 1) {
        p['amountCents'] = totalCents - allocated;
      } else {
        final prev = (p['amountCents'] as num?)?.round() ?? 0;
        final next = ((prev * totalCents) / currentSum).round();
        p['amountCents'] = next;
        allocated += next;
      }
      scaled.add(p);
    }
    if (_samePayments(q.payments, scaled)) return q;
    return q.copyWith(payments: scaled);
  }

  static bool _samePayments(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['label'] != b[i]['label']) return false;
      if ((a[i]['amountCents'] as num?)?.round() !=
          (b[i]['amountCents'] as num?)?.round()) {
        return false;
      }
    }
    return true;
  }

  /// Pago único = 100 % del total; saldo pendiente implícito $0.
  static List<Map<String, dynamic>> buildSinglePayment(MoneyCents total) {
    return [
      {
        'label': 'UN SOLO PAGO',
        'description': '100% del total',
        'amountCents': total.cents,
      },
    ];
  }

  /// Anticipo + saldo (y entrega intermedia si % no suman 100).
  static List<Map<String, dynamic>> buildSplitPayments({
    required MoneyCents total,
    required num anticipoPct,
    required num saldoPct,
  }) {
    final anticipo = anticipoPct.clamp(0, 100).toDouble();
    var saldo = saldoPct.clamp(0, 100).toDouble();
    if (anticipo + saldo > 100) {
      saldo = 100 - anticipo;
    }
    final anticipoCents = total.percentBps((anticipo * 100).round());
    final MoneyCents saldoCents;
    final MoneyCents midCents;
    if (anticipo + saldo >= 100) {
      final remaining = total.cents - anticipoCents.cents;
      saldoCents = MoneyCents(remaining < 0 ? 0 : remaining);
      midCents = MoneyCents.zero;
    } else {
      var saldoRaw = total.percentBps((saldo * 100).round());
      var midRaw = MoneyCents(
        total.cents - anticipoCents.cents - saldoRaw.cents,
      );
      if (midRaw.cents < 0) {
        saldoRaw = MoneyCents(saldoRaw.cents + midRaw.cents);
        midRaw = MoneyCents.zero;
      }
      if (saldoRaw.cents < 0) {
        saldoRaw = MoneyCents.zero;
        midRaw = MoneyCents(total.cents - anticipoCents.cents);
        if (midRaw.cents < 0) midRaw = MoneyCents.zero;
      }
      saldoCents = saldoRaw;
      midCents = midRaw;
    }

    return [
      {
        'label': 'ANTICIPO',
        'description': '${anticipo.toStringAsFixed(0)}% de entrada',
        'amountCents': anticipoCents.cents,
      },
      if (midCents.cents > 0)
        {
          'label': 'ENTREGA',
          'description': 'Pago intermedio',
          'amountCents': midCents.cents,
        },
      {
        'label': 'SALDO',
        'description': '${saldo.toStringAsFixed(0)}% saldo pendiente',
        'amountCents': saldoCents.cents,
      },
    ];
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

  void setConditions(String? value) {
    final trimmed = value?.trim();
    _touch(
      (q) => trimmed == null || trimmed.isEmpty
          ? q.copyWith(clearConditions: true)
          : q.copyWith(conditions: trimmed),
    );
  }

  /// Cambia modalidad de pago (un solo pago ↔ anticipo/saldo).
  void setPaymentMode(PaymentMode mode) {
    _touch((q) {
      if (mode == PaymentMode.single) {
        return q.copyWith(paymentMode: PaymentMode.single);
      }
      final anticipo =
          (q.legacyFields['anticipoPct'] as num?)?.toDouble() ?? 50.0;
      final saldo = (q.legacyFields['saldoPct'] as num?)?.toDouble() ?? 50.0;
      return q.copyWith(
        paymentMode: PaymentMode.split,
        legacyFields: {
          ...q.legacyFields,
          'anticipoPct': anticipo,
          'saldoPct': saldo,
          'paymentMode': PaymentMode.split.id,
        },
      );
    });
  }

  /// Recalcula tramos de pago desde porcentajes sobre el total actual.
  /// La suma de tramos coincide exactamente con [totals.total] (en centavos).
  void setPaymentPercents({required num anticipoPct, required num saldoPct}) {
    final anticipo = anticipoPct.clamp(0, 100).toDouble();
    var saldo = saldoPct.clamp(0, 100).toDouble();
    if (anticipo + saldo > 100) {
      saldo = 100 - anticipo;
    }
    _touch(
      (q) => q.copyWith(
        paymentMode: PaymentMode.split,
        legacyFields: {
          ...q.legacyFields,
          'anticipoPct': anticipo,
          'saldoPct': saldo,
          'paymentMode': PaymentMode.split.id,
        },
      ),
    );
  }

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
      var pendingLocal = saved.number.startsWith('LOCAL-');
      try {
        final rec = await OfflineLocalStore.instance.getQuote(
          organizationId: saved.organizationId,
          uid: uid,
          quoteId: saved.id,
        );
        pendingLocal =
            pendingLocal ||
            rec?.syncStatus == OfflineSyncStatus.pending ||
            rec?.syncStatus == OfflineSyncStatus.error;
      } catch (_) {}
      draftHint = pendingLocal
          ? 'Guardada en este dispositivo (pendiente de sincronizar)'
          : 'Guardada correctamente';
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
