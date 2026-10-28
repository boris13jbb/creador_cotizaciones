import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/utils/money_cents.dart';
import '../../domain/org_enums.dart';
import '../../models/catalog_item.dart';
import '../catalog_repository.dart';
import 'catalog_csv_codec.dart';
import 'catalog_import_headers.dart';
import 'catalog_import_models.dart';
import 'catalog_xlsx_codec.dart';

/// Análisis y confirmación de importación masiva del catálogo.
///
/// El análisis y las plantillas no requieren red. La persistencia reutiliza
/// [CatalogRepository] (mismo camino que el alta manual).
class CatalogImportService {
  CatalogImportService({CatalogRepository? repository, Uuid? uuid})
    : _repository = repository ?? CatalogRepository.instance,
      _uuid = uuid ?? const Uuid();

  static final CatalogImportService instance = CatalogImportService();

  final CatalogRepository _repository;
  final Uuid _uuid;

  /// Límite de tamaño del archivo (2 MiB).
  static const int maxFileBytes = 2 * 1024 * 1024;

  /// Límite de filas de datos (sin cabecera).
  static const int maxDataRows = 2000;

  /// Extensiones admitidas (`.xls` legacy no se soporta).
  static const supportedExtensions = {'csv', 'xlsx'};

  /// Analiza bytes locales sin escribir en el catálogo.
  CatalogImportAnalysis analyzeBytes({
    required List<int> bytes,
    required String fileName,
    required String organizationId,
    required List<CatalogItem> existingItems,
  }) {
    if (bytes.length > maxFileBytes) {
      return CatalogImportAnalysis(
        fileName: fileName,
        detectedDataRows: 0,
        rows: const [],
        globalIssues: [
          CatalogImportIssue(
            kind: CatalogImportIssueKind.fileTooLarge,
            detail: '$maxFileBytes',
          ),
        ],
      );
    }

    final ext = _resolveFormat(fileName: fileName, bytes: bytes);
    if (ext == null) {
      return CatalogImportAnalysis(
        fileName: fileName,
        detectedDataRows: 0,
        rows: const [],
        globalIssues: [
          CatalogImportIssue(
            kind: CatalogImportIssueKind.unsupportedFormat,
            detail: _extensionOf(fileName).isEmpty
                ? fileName
                : _extensionOf(fileName),
          ),
        ],
      );
    }

    List<List<String>> table;
    try {
      if (ext == 'csv') {
        table = CatalogCsvCodec.instance.decodeBytes(bytes);
      } else {
        table = CatalogXlsxCodec.instance.decodeBytes(bytes);
      }
    } catch (e) {
      return CatalogImportAnalysis(
        fileName: fileName,
        detectedDataRows: 0,
        rows: const [],
        globalIssues: [
          CatalogImportIssue(
            kind: CatalogImportIssueKind.parseError,
            detail: e.toString(),
          ),
        ],
      );
    }

    return analyzeTable(
      table: table,
      fileName: fileName,
      organizationId: organizationId,
      existingItems: existingItems,
    );
  }

  /// Analiza una tabla ya decodificada (útil en tests).
  CatalogImportAnalysis analyzeTable({
    required List<List<String>> table,
    required String fileName,
    required String organizationId,
    required List<CatalogItem> existingItems,
  }) {
    if (table.isEmpty) {
      return CatalogImportAnalysis(
        fileName: fileName,
        detectedDataRows: 0,
        rows: const [],
        globalIssues: const [
          CatalogImportIssue(kind: CatalogImportIssueKind.emptyFile),
        ],
      );
    }

    final headerRow = table.first;
    final headerIndex = <String, int>{};
    final unrecognized = <String>[];
    for (var i = 0; i < headerRow.length; i++) {
      final raw = headerRow[i].trim();
      if (raw.isEmpty) continue;
      final canonical = CatalogImportHeaders.resolveCanonical(raw);
      if (canonical == null) {
        unrecognized.add(raw);
      } else {
        headerIndex.putIfAbsent(canonical, () => i);
      }
    }

    if (!headerIndex.containsKey(CatalogImportHeaders.name)) {
      return CatalogImportAnalysis(
        fileName: fileName,
        detectedDataRows: 0,
        rows: const [],
        globalIssues: const [
          CatalogImportIssue(kind: CatalogImportIssueKind.missingNameHeader),
        ],
        unrecognizedHeaders: unrecognized,
      );
    }

    final dataRowCount = table.length - 1;
    if (dataRowCount > maxDataRows) {
      return CatalogImportAnalysis(
        fileName: fileName,
        detectedDataRows: dataRowCount,
        rows: const [],
        globalIssues: [
          CatalogImportIssue(
            kind: CatalogImportIssueKind.tooManyRows,
            detail: '$maxDataRows',
          ),
        ],
        unrecognizedHeaders: unrecognized,
      );
    }

    final existingByCode = <String, CatalogItem>{};
    for (final item in existingItems) {
      final key = _normalizeCode(item.code);
      if (key.isEmpty) continue;
      existingByCode.putIfAbsent(key, () => item);
    }

    final seenCodesInFile = <String, int>{};
    final rows = <CatalogImportPreviewRow>[];

    for (var i = 1; i < table.length; i++) {
      final cells = table[i];
      final rowNumber = i + 1; // 1-based incluyendo cabecera

      String cell(String key) {
        final idx = headerIndex[key];
        if (idx == null || idx >= cells.length) return '';
        return cells[idx].trim();
      }

      final code = cell(CatalogImportHeaders.code);
      final name = cell(CatalogImportHeaders.name);
      final description = cell(CatalogImportHeaders.description);
      final categoryRaw = cell(CatalogImportHeaders.category);
      final unitRaw = cell(CatalogImportHeaders.unit);
      final priceRaw = cell(CatalogImportHeaders.unitPrice);
      final taxRaw = cell(CatalogImportHeaders.taxPercent);

      // Fila completamente vacía → omitir sin error.
      if (code.isEmpty &&
          name.isEmpty &&
          description.isEmpty &&
          categoryRaw.isEmpty &&
          unitRaw.isEmpty &&
          priceRaw.isEmpty &&
          taxRaw.isEmpty) {
        continue;
      }

      final isExample = CatalogImportHeaders.isExampleRow(
        code: code,
        description: description,
        name: name,
      );
      final issues = <CatalogImportIssue>[];

      if (name.isEmpty) {
        issues.add(
          const CatalogImportIssue(
            kind: CatalogImportIssueKind.emptyName,
            field: CatalogImportHeaders.name,
          ),
        );
      }

      double unitPrice = 0;
      if (priceRaw.isNotEmpty) {
        final parsed = _parseNumber(priceRaw);
        if (parsed == null) {
          issues.add(
            CatalogImportIssue(
              kind: CatalogImportIssueKind.invalidPrice,
              field: CatalogImportHeaders.unitPrice,
              detail: priceRaw,
              rowNumber: rowNumber,
            ),
          );
        } else if (parsed < 0) {
          issues.add(
            CatalogImportIssue(
              kind: CatalogImportIssueKind.negativePrice,
              field: CatalogImportHeaders.unitPrice,
              detail: priceRaw,
              rowNumber: rowNumber,
            ),
          );
        } else {
          unitPrice = parsed;
        }
      }

      double taxPercent = 0;
      if (taxRaw.isNotEmpty) {
        final parsed = _parseNumber(taxRaw);
        if (parsed == null) {
          issues.add(
            CatalogImportIssue(
              kind: CatalogImportIssueKind.invalidTax,
              field: CatalogImportHeaders.taxPercent,
              detail: taxRaw,
              rowNumber: rowNumber,
            ),
          );
        } else if (parsed < 0) {
          issues.add(
            CatalogImportIssue(
              kind: CatalogImportIssueKind.negativeTax,
              field: CatalogImportHeaders.taxPercent,
              detail: taxRaw,
              rowNumber: rowNumber,
            ),
          );
        } else {
          taxPercent = parsed;
        }
      }

      String? matchedId;
      final codeKey = _normalizeCode(code);
      if (codeKey.isNotEmpty && !isExample) {
        final firstSeen = seenCodesInFile[codeKey];
        if (firstSeen != null) {
          issues.add(
            CatalogImportIssue(
              kind: CatalogImportIssueKind.internalDuplicateCode,
              field: CatalogImportHeaders.code,
              detail: code,
              rowNumber: rowNumber,
            ),
          );
        } else {
          seenCodesInFile[codeKey] = rowNumber;
        }

        final existing = existingByCode[codeKey];
        if (existing != null) {
          matchedId = existing.id;
          issues.add(
            CatalogImportIssue(
              kind: CatalogImportIssueKind.existingDuplicateCode,
              field: CatalogImportHeaders.code,
              detail: code,
              rowNumber: rowNumber,
            ),
          );
        }
      }

      // Issues de nombre/precio/tax sin rowNumber en constructores const: fijar.
      final withRow = issues
          .map(
            (issue) => CatalogImportIssue(
              kind: issue.kind,
              field: issue.field,
              detail: issue.detail,
              rowNumber: issue.rowNumber ?? rowNumber,
            ),
          )
          .toList();

      final critical = withRow.any(
        (i) =>
            i.kind == CatalogImportIssueKind.emptyName ||
            i.kind == CatalogImportIssueKind.invalidPrice ||
            i.kind == CatalogImportIssueKind.negativePrice ||
            i.kind == CatalogImportIssueKind.invalidTax ||
            i.kind == CatalogImportIssueKind.negativeTax ||
            i.kind == CatalogImportIssueKind.internalDuplicateCode,
      );

      rows.add(
        CatalogImportPreviewRow(
          rowNumber: rowNumber,
          code: code,
          name: name,
          description: description,
          category: categoryRaw.isEmpty ? 'General' : categoryRaw,
          unit: unitRaw.isEmpty ? 'und' : unitRaw,
          unitPrice: unitPrice,
          taxPercent: taxPercent,
          isExample: isExample,
          isValid: !critical && !isExample,
          matchedExistingId: matchedId,
          issues: withRow,
        ),
      );
    }

    final global = <CatalogImportIssue>[];
    if (unrecognized.isNotEmpty) {
      global.add(
        CatalogImportIssue(
          kind: CatalogImportIssueKind.unknownHeaders,
          detail: unrecognized.join(', '),
        ),
      );
    }
    if (rows.isEmpty) {
      global.add(
        const CatalogImportIssue(kind: CatalogImportIssueKind.emptySheet),
      );
    } else if (rows.every((r) => r.isExample)) {
      global.add(
        CatalogImportIssue(
          kind: CatalogImportIssueKind.onlyExamples,
          detail: '${rows.length}',
        ),
      );
    }

    return CatalogImportAnalysis(
      fileName: fileName,
      detectedDataRows: rows.length,
      rows: rows,
      globalIssues: global,
      unrecognizedHeaders: unrecognized,
    );
  }

  /// Construye el plan de upsert según política, sin escribir.
  List<CatalogImportUpsertPlan> buildCommitPlan({
    required CatalogImportAnalysis analysis,
    required String organizationId,
    required CatalogDuplicatePolicy policy,
    List<CatalogItem> existingItems = const [],
  }) {
    final now = DateTime.now().toUtc();
    final existingById = {for (final item in existingItems) item.id: item};
    final plans = <CatalogImportUpsertPlan>[];

    for (final row in analysis.rows) {
      if (row.isExample || !row.isValid) continue;

      final hasExistingDup = row.issues.any(
        (i) => i.kind == CatalogImportIssueKind.existingDuplicateCode,
      );

      if (hasExistingDup) {
        if (policy == CatalogDuplicatePolicy.skip) {
          continue;
        }
        if (policy == CatalogDuplicatePolicy.updateByCode &&
            row.matchedExistingId != null) {
          final previous = existingById[row.matchedExistingId!];
          plans.add(
            CatalogImportUpsertPlan(
              item: CatalogItem(
                id: row.matchedExistingId!,
                organizationId: organizationId,
                code: row.code,
                name: row.name,
                description: row.description,
                category: row.category,
                unit: row.unit,
                unitPrice: MoneyCents.fromDecimal(row.unitPrice),
                taxBps: (row.taxPercent * 100).round(),
                status: previous?.status ?? CatalogItemStatus.active,
                createdAt: previous?.createdAt ?? now,
                updatedAt: now,
              ),
              isUpdate: true,
              sourceRowNumber: row.rowNumber,
            ),
          );
          continue;
        }
      }

      plans.add(
        CatalogImportUpsertPlan(
          item: CatalogItem(
            id: _uuid.v4(),
            organizationId: organizationId,
            code: row.code,
            name: row.name,
            description: row.description,
            category: row.category,
            unit: row.unit,
            unitPrice: MoneyCents.fromDecimal(row.unitPrice),
            taxBps: (row.taxPercent * 100).round(),
            status: CatalogItemStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
          isUpdate: false,
          sourceRowNumber: row.rowNumber,
        ),
      );
    }
    return plans;
  }

  /// Persiste vía [CatalogRepository]. No toca sync_queue ni cotizaciones.
  Future<CatalogImportCommitResult> commit({
    required CatalogImportAnalysis analysis,
    required String organizationId,
    required CatalogDuplicatePolicy policy,
    List<CatalogItem> existingItems = const [],
    Future<CatalogItem> Function({
      required String organizationId,
      required CatalogItem item,
    })?
    upsertOverride,
  }) async {
    final plans = buildCommitPlan(
      analysis: analysis,
      organizationId: organizationId,
      policy: policy,
      existingItems: existingItems,
    );

    final upsert = upsertOverride ?? _repository.upsert;
    var created = 0;
    var updated = 0;
    final skipped = analysis.validRows.where((r) {
      final dup = r.issues.any(
        (i) => i.kind == CatalogImportIssueKind.existingDuplicateCode,
      );
      return dup && policy == CatalogDuplicatePolicy.skip;
    }).length;

    final failures = <String>[];
    for (final plan in plans) {
      try {
        await upsert(organizationId: organizationId, item: plan.item);
        if (plan.isUpdate) {
          updated++;
        } else {
          created++;
        }
      } catch (e) {
        failures.add('Fila ${plan.sourceRowNumber}: $e');
      }
    }

    return CatalogImportCommitResult(
      created: created,
      updated: updated,
      skipped: skipped,
      failures: failures,
    );
  }

  /// Detecta extensión normalizada.
  String extensionOf(String fileName) => _extensionOf(fileName);

  /// Resuelve formato por extensión o firma ZIP (`PK`) para `.xlsx`.
  String? _resolveFormat({required String fileName, required List<int> bytes}) {
    final ext = _extensionOf(fileName);
    if (supportedExtensions.contains(ext)) return ext;
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return 'xlsx';
    }
    // Texto UTF-8/BOM plausible como CSV cuando el nombre no trae extensión.
    if (bytes.isNotEmpty && ext.isEmpty) {
      try {
        final sample = utf8.decode(
          bytes.take(64).toList(),
          allowMalformed: false,
        );
        final head = sample.replaceAll('\uFEFF', '').toLowerCase();
        if (head.contains('name') ||
            head.contains('nombre') ||
            head.contains('code') ||
            head.contains('codigo')) {
          return 'csv';
        }
      } catch (_) {
        // No es texto UTF-8 válido.
      }
    }
    return null;
  }

  String _extensionOf(String fileName) {
    final name = fileName.trim().toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1);
  }

  String _normalizeCode(String code) => code.trim().toLowerCase();

  /// Acepta `12.5`, `12,5`, `1.234,56` (estilo ES) y `1,234.56` (estilo EN).
  double? _parseNumber(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (s.isEmpty || s == '-' || s == '.' || s == ',') return null;

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      // El último separador suele ser el decimal.
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (hasComma) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s);
  }

  /// Utilidad de test: analiza texto CSV directamente.
  CatalogImportAnalysis analyzeCsvText({
    required String csv,
    required String organizationId,
    List<CatalogItem> existingItems = const [],
    String fileName = 'catalog.csv',
  }) {
    final bytes = utf8.encode(csv);
    return analyzeBytes(
      bytes: bytes,
      fileName: fileName,
      organizationId: organizationId,
      existingItems: existingItems,
    );
  }
}
