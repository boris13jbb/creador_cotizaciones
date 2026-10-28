import '../../models/catalog_item.dart';

/// Política segura ante duplicados detectados por código/SKU.
enum CatalogDuplicatePolicy {
  /// No escribe filas cuyo código ya existe en el catálogo o se repite en el archivo.
  skip,

  /// Actualiza el ítem existente cuando el código coincide de forma fiable.
  updateByCode,
}

enum CatalogImportIssueKind {
  emptyFile,
  missingNameHeader,
  unknownHeaders,
  emptyName,
  invalidPrice,
  negativePrice,
  invalidTax,
  negativeTax,
  tooManyRows,
  fileTooLarge,
  unsupportedFormat,
  emptySheet,
  onlyExamples,
  internalDuplicateCode,
  existingDuplicateCode,
  parseError,
}

/// Error o advertencia asociada a una fila o al archivo completo.
class CatalogImportIssue {
  final CatalogImportIssueKind kind;
  final int? rowNumber;
  final String? field;
  final String? detail;

  const CatalogImportIssue({
    required this.kind,
    this.rowNumber,
    this.field,
    this.detail,
  });
}

/// Fila analizada previa a la confirmación.
class CatalogImportPreviewRow {
  final int rowNumber;
  final String code;
  final String name;
  final String description;
  final String category;
  final String unit;
  final double unitPrice;
  final double taxPercent;
  final bool isExample;
  final bool isValid;
  final String? matchedExistingId;
  final List<CatalogImportIssue> issues;

  const CatalogImportPreviewRow({
    required this.rowNumber,
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.unit,
    required this.unitPrice,
    required this.taxPercent,
    this.isExample = false,
    this.isValid = true,
    this.matchedExistingId,
    this.issues = const [],
  });

  bool get isDuplicate => issues.any(
    (i) =>
        i.kind == CatalogImportIssueKind.internalDuplicateCode ||
        i.kind == CatalogImportIssueKind.existingDuplicateCode,
  );

  bool get matchesExisting =>
      matchedExistingId != null && matchedExistingId!.isNotEmpty;
}

/// Resultado del análisis previo (sin escrituras).
class CatalogImportAnalysis {
  final String fileName;
  final int detectedDataRows;
  final List<CatalogImportPreviewRow> rows;
  final List<CatalogImportIssue> globalIssues;
  final List<String> unrecognizedHeaders;

  const CatalogImportAnalysis({
    required this.fileName,
    required this.detectedDataRows,
    required this.rows,
    this.globalIssues = const [],
    this.unrecognizedHeaders = const [],
  });

  List<CatalogImportPreviewRow> get validRows =>
      rows.where((r) => r.isValid && !r.isExample).toList();

  List<CatalogImportPreviewRow> get errorRows =>
      rows.where((r) => !r.isValid && !r.isExample).toList();

  List<CatalogImportPreviewRow> get duplicateRows =>
      rows.where((r) => r.isDuplicate && !r.isExample).toList();

  List<CatalogImportPreviewRow> get exampleRows =>
      rows.where((r) => r.isExample).toList();

  bool get hasBlockingGlobalIssues => globalIssues.any(
    (i) =>
        i.kind == CatalogImportIssueKind.emptyFile ||
        i.kind == CatalogImportIssueKind.missingNameHeader ||
        i.kind == CatalogImportIssueKind.unsupportedFormat ||
        i.kind == CatalogImportIssueKind.fileTooLarge ||
        i.kind == CatalogImportIssueKind.tooManyRows ||
        i.kind == CatalogImportIssueKind.emptySheet ||
        i.kind == CatalogImportIssueKind.parseError,
  );

  int get importableCount {
    return validRows.where((r) {
      if (!r.matchesExisting) return true;
      // Los duplicados existentes se cuentan según política en commit.
      return true;
    }).length;
  }
}

/// Resultado de la persistencia tras confirmación.
class CatalogImportCommitResult {
  final int created;
  final int updated;
  final int skipped;
  final List<String> failures;

  const CatalogImportCommitResult({
    required this.created,
    required this.updated,
    required this.skipped,
    this.failures = const [],
  });

  int get saved => created + updated;
  bool get hasPartialFailures => failures.isNotEmpty;
}

/// Ítem listo para upsert, con metadatos de deduplicación.
class CatalogImportUpsertPlan {
  final CatalogItem item;
  final bool isUpdate;
  final int sourceRowNumber;

  const CatalogImportUpsertPlan({
    required this.item,
    required this.isUpdate,
    required this.sourceRowNumber,
  });
}
