import '../../core/utils/money_cents.dart';
import '../domain/org_enums.dart';

class CatalogItem {
  final String id;
  final String organizationId;
  final String code;
  final String name;
  final String description;
  final String category;
  final String unit;
  final MoneyCents unitPrice;
  final int taxBps;
  final CatalogItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CatalogItem({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    this.description = '',
    this.category = 'General',
    this.unit = 'und',
    required this.unitPrice,
    this.taxBps = 0,
    this.status = CatalogItemStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'code': code,
    'name': name,
    'description': description,
    'category': category,
    'unit': unit,
    'unitPriceCents': unitPrice.cents,
    'taxBps': taxBps,
    'status': status.id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CatalogItem.fromMap(Map<String, dynamic> map) {
    return CatalogItem(
      id: map['id'] as String? ?? '',
      organizationId: map['organizationId'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      unit: map['unit'] as String? ?? 'und',
      unitPrice: map['unitPriceCents'] != null
          ? MoneyCents((map['unitPriceCents'] as num).round())
          : MoneyCents.fromDecimal(map['unitPrice'] ?? 0),
      taxBps: (map['taxBps'] as num?)?.round() ?? 0,
      status: CatalogItemStatus.fromId(map['status'] as String?),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}
