import '../../core/utils/money_cents.dart';
import '../domain/org_enums.dart';
import '../domain/quote_totals.dart';

/// Cotización comercial completa (modelo de dominio).
class Quote {
  final String id;
  final String organizationId;
  final String number;
  final int sequence;
  final QuoteStatus status;
  final String? clientId;
  final String clientName;
  final DateTime issueDate;
  final DateTime? dueDate;
  final String currency;
  final List<QuoteLineItem> items;
  final int globalDiscountBps;
  final MoneyCents globalDiscountFixed;
  final MoneyCents charges;
  final MoneyCents total;
  final List<String> includes;
  final List<String> excludes;
  final List<String> notes;
  final List<Map<String, dynamic>> payments;
  final String? conditions;
  final String? logoPath;
  final String? colorsJson;
  final String? subtitle;
  final String? footerText;
  final String? extraFields;
  final int version;
  final String? previousVersionId;
  final String createdByUid;
  final String? updatedByUid;
  final String? legacyUserPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Campos legacy de UI (ubicación, tipo servicio, etc.).
  final Map<String, dynamic> legacyFields;

  const Quote({
    required this.id,
    required this.organizationId,
    required this.number,
    required this.sequence,
    this.status = QuoteStatus.draft,
    this.clientId,
    required this.clientName,
    required this.issueDate,
    this.dueDate,
    this.currency = 'USD',
    this.items = const [],
    this.globalDiscountBps = 0,
    this.globalDiscountFixed = MoneyCents.zero,
    this.charges = MoneyCents.zero,
    required this.total,
    this.includes = const [],
    this.excludes = const [],
    this.notes = const [],
    this.payments = const [],
    this.conditions,
    this.logoPath,
    this.colorsJson,
    this.subtitle,
    this.footerText,
    this.extraFields,
    this.version = 1,
    this.previousVersionId,
    required this.createdByUid,
    this.updatedByUid,
    this.legacyUserPath,
    required this.createdAt,
    required this.updatedAt,
    this.legacyFields = const {},
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'number': number,
    'sequence': sequence,
    'status': status.id,
    'clientId': clientId,
    'clientName': clientName,
    'issueDate': issueDate.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'currency': currency,
    'items': items.map((e) => e.toMap()).toList(),
    'globalDiscountBps': globalDiscountBps,
    'globalDiscountFixedCents': globalDiscountFixed.cents,
    'chargesCents': charges.cents,
    'totalCents': total.cents,
    'includes': includes,
    'excludes': excludes,
    'notes': notes,
    'payments': payments,
    'conditions': conditions,
    'logoPath': logoPath,
    'colorsJson': colorsJson,
    'subtitle': subtitle,
    'footerText': footerText,
    'extraFields': extraFields,
    'version': version,
    'previousVersionId': previousVersionId,
    'createdByUid': createdByUid,
    'updatedByUid': updatedByUid,
    'legacyUserPath': legacyUserPath,
    'legacyFields': legacyFields,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Quote.fromMap(Map<String, dynamic> map) {
    final itemsRaw =
        (map['items'] as List<dynamic>?) ??
        (map['servicios'] as List<dynamic>?) ??
        [];
    return Quote(
      id: map['id'] as String? ?? '',
      organizationId: map['organizationId'] as String? ?? '',
      number: map['number'] as String? ?? map['numero'] as String? ?? '',
      sequence: (map['sequence'] as num?)?.round() ?? 0,
      status: QuoteStatus.fromId(map['status'] as String?),
      clientId: map['clientId'] as String?,
      clientName:
          map['clientName'] as String? ?? map['cliente'] as String? ?? '',
      issueDate:
          DateTime.tryParse(
            map['issueDate'] as String? ?? map['fecha'] as String? ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc(),
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'] as String)?.toUtc()
          : null,
      currency: map['currency'] as String? ?? 'USD',
      items: itemsRaw
          .whereType<Map>()
          .map((e) => QuoteLineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      globalDiscountBps: (map['globalDiscountBps'] as num?)?.round() ?? 0,
      globalDiscountFixed: MoneyCents(
        (map['globalDiscountFixedCents'] as num?)?.round() ?? 0,
      ),
      charges: MoneyCents((map['chargesCents'] as num?)?.round() ?? 0),
      total: map['totalCents'] != null
          ? MoneyCents((map['totalCents'] as num).round())
          : MoneyCents.fromDecimal(map['total'] ?? 0),
      includes: _stringList(map['includes'] ?? map['incluye']),
      excludes: _stringList(map['excludes'] ?? map['noIncluye']),
      notes: _stringList(map['notes'] ?? map['notas']),
      payments: ((map['payments'] as List<dynamic>?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      conditions: map['conditions'] as String?,
      logoPath: map['logoPath'] as String?,
      colorsJson: map['colorsJson'] as String? ?? map['coloresJson'] as String?,
      subtitle: map['subtitle'] as String? ?? map['subtitulo'] as String?,
      footerText: map['footerText'] as String?,
      extraFields:
          map['extraFields'] as String? ?? map['camposExtra'] as String?,
      version: (map['version'] as num?)?.round() ?? 1,
      previousVersionId: map['previousVersionId'] as String?,
      createdByUid: map['createdByUid'] as String? ?? '',
      updatedByUid: map['updatedByUid'] as String?,
      legacyUserPath: map['legacyUserPath'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      legacyFields: Map<String, dynamic>.from(
        map['legacyFields'] as Map? ?? {},
      ),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => '$e').where((s) => s.isNotEmpty).toList();
    }
    if (value is String) {
      return value.split('|').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Quote copyWith({
    String? id,
    String? organizationId,
    String? number,
    int? sequence,
    QuoteStatus? status,
    String? clientId,
    bool clearClientId = false,
    String? clientName,
    DateTime? issueDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? currency,
    List<QuoteLineItem>? items,
    int? globalDiscountBps,
    MoneyCents? globalDiscountFixed,
    MoneyCents? charges,
    MoneyCents? total,
    List<String>? includes,
    List<String>? excludes,
    List<String>? notes,
    List<Map<String, dynamic>>? payments,
    String? conditions,
    String? logoPath,
    bool clearLogoPath = false,
    String? colorsJson,
    bool clearColorsJson = false,
    String? subtitle,
    String? footerText,
    String? extraFields,
    int? version,
    String? previousVersionId,
    String? createdByUid,
    String? updatedByUid,
    String? legacyUserPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? legacyFields,
  }) {
    return Quote(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      number: number ?? this.number,
      sequence: sequence ?? this.sequence,
      status: status ?? this.status,
      clientId: clearClientId ? null : (clientId ?? this.clientId),
      clientName: clientName ?? this.clientName,
      issueDate: issueDate ?? this.issueDate,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      currency: currency ?? this.currency,
      items: items ?? this.items,
      globalDiscountBps: globalDiscountBps ?? this.globalDiscountBps,
      globalDiscountFixed: globalDiscountFixed ?? this.globalDiscountFixed,
      charges: charges ?? this.charges,
      total: total ?? this.total,
      includes: includes ?? this.includes,
      excludes: excludes ?? this.excludes,
      notes: notes ?? this.notes,
      payments: payments ?? this.payments,
      conditions: conditions ?? this.conditions,
      logoPath: clearLogoPath ? null : (logoPath ?? this.logoPath),
      colorsJson: clearColorsJson ? null : (colorsJson ?? this.colorsJson),
      subtitle: subtitle ?? this.subtitle,
      footerText: footerText ?? this.footerText,
      extraFields: extraFields ?? this.extraFields,
      version: version ?? this.version,
      previousVersionId: previousVersionId ?? this.previousVersionId,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      legacyUserPath: legacyUserPath ?? this.legacyUserPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      legacyFields: legacyFields ?? this.legacyFields,
    );
  }

  /// Recalcula [total] con la calculadora de dominio.
  Quote withRecalculatedTotal() {
    const calc = QuoteTotalsCalculator();
    final totals = calc.calculate(
      items: items,
      globalDiscountBps: globalDiscountBps,
      globalDiscountFixed: globalDiscountFixed,
      charges: charges,
    );
    return copyWith(total: totals.total, updatedAt: DateTime.now().toUtc());
  }
}

/// Página cursor de cotizaciones.
class QuotePage {
  final List<Quote> items;
  final String? nextCursor;
  final bool hasMore;

  const QuotePage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}
