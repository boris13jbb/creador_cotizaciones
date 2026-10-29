import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import '../../l10n/l10n_ext.dart';
import '../../saas/models/catalog_item.dart';
import '../../saas/services/catalog_import/catalog_import_l10n.dart';
import '../../saas/services/catalog_import/catalog_import_models.dart';
import '../../saas/services/catalog_import/catalog_import_service.dart';
import '../../saas/services/catalog_import/catalog_template_service.dart';
import '../../ui/providers/locale_controller.dart';

/// Abre el menú de importación del catálogo.
///
/// Devuelve `true` si se confirmó una importación con escrituras (o skips).
Future<bool> showCatalogImportFlow({
  required BuildContext context,
  required String organizationId,
  required List<CatalogItem> existingItems,
}) async {
  final l10n = context.l10n;
  final choice = await showModalBottomSheet<_CatalogImportAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final sheetL10n = ctx.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                sheetL10n.catalogImportTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: Text(sheetL10n.catalogImportDownloadExcel),
              onTap: () =>
                  Navigator.pop(ctx, _CatalogImportAction.downloadExcel),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(sheetL10n.catalogImportDownloadCsv),
              onTap: () => Navigator.pop(ctx, _CatalogImportAction.downloadCsv),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(sheetL10n.catalogImportSelectFile),
              onTap: () => Navigator.pop(ctx, _CatalogImportAction.selectFile),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(sheetL10n.catalogImportViewInstructions),
              onTap: () =>
                  Navigator.pop(ctx, _CatalogImportAction.instructions),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (!context.mounted || choice == null) return false;

  final spanish = _useSpanishTemplates(context);

  switch (choice) {
    case _CatalogImportAction.downloadExcel:
      try {
        final result = await CatalogTemplateService.instance.shareXlsxTemplate(
          spanishLabels: spanish,
        );
        if (context.mounted) {
          final detail = result.savedPath == null
              ? l10n.catalogImportTemplateShared
              : '${l10n.catalogImportTemplateShared} (${result.savedPath})';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(detail)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.catalogImportTemplateError(e.toString())),
            ),
          );
        }
      }
      return false;
    case _CatalogImportAction.downloadCsv:
      try {
        final result = await CatalogTemplateService.instance.shareCsvTemplate(
          spanishLabels: spanish,
        );
        if (context.mounted) {
          final detail = result.savedPath == null
              ? l10n.catalogImportTemplateShared
              : '${l10n.catalogImportTemplateShared} (${result.savedPath})';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(detail)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.catalogImportTemplateError(e.toString())),
            ),
          );
        }
      }
      return false;
    case _CatalogImportAction.instructions:
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final dlg = ctx.l10n;
          return AlertDialog(
            title: Text(dlg.catalogImportInstructionsTitle),
            content: SingleChildScrollView(
              child: Text(dlg.catalogImportInstructionsBody),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(dlg.cancel),
              ),
            ],
          );
        },
      );
      return false;
    case _CatalogImportAction.selectFile:
      return _pickAndReview(
        context: context,
        organizationId: organizationId,
        existingItems: existingItems,
      );
  }
}

bool _useSpanishTemplates(BuildContext context) {
  try {
    return context.read<LocaleController>().isSpanish;
  } catch (_) {
    // LocaleController puede no estar disponible en tests.
  }
  return Localizations.localeOf(context).languageCode == 'es';
}

Future<bool> _pickAndReview({
  required BuildContext context,
  required String organizationId,
  required List<CatalogItem> existingItems,
}) async {
  final l10n = context.l10n;
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'xlsx'],
    withData: true,
    allowMultiple: false,
  );
  if (!context.mounted) return false;
  if (result == null || result.files.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.catalogImportNoFile)));
    return false;
  }

  final file = result.files.single;
  // Android/Windows: a veces solo hay path; en web suele venir `bytes`.
  List<int>? bytes = file.bytes;
  if ((bytes == null || bytes.isEmpty) &&
      file.path != null &&
      file.path!.isNotEmpty &&
      !kIsWeb) {
    try {
      bytes = await File(file.path!).readAsBytes();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.catalogImportAnalyzeError(e.toString()))),
        );
      }
      return false;
    }
  }
  if (!context.mounted) return false;
  if (bytes == null || bytes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.catalogImportAnalyzeError(
            'No se pudieron leer los bytes del archivo',
          ),
        ),
      ),
    );
    return false;
  }

  // Algunos selectores Android omiten la extensión en `name`.
  var fileName = file.name.trim();
  if (!fileName.contains('.') && file.path != null) {
    fileName = file.path!.split(RegExp(r'[\\/]')).last;
  }
  if (!fileName.contains('.')) {
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
      fileName = '$fileName.xlsx';
    } else {
      fileName = '$fileName.csv';
    }
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(ctx.l10n.catalogImportAnalyzing)),
          ],
        ),
      ),
    ),
  );

  CatalogImportAnalysis analysis;
  try {
    // compute evita bloquear la UI en archivos grandes; los modelos son simples.
    analysis = await compute(
      _analyzeInIsolate,
      _AnalyzeArgs(
        bytes: bytes,
        fileName: fileName,
        organizationId: organizationId,
        existingMaps: existingItems.map((e) => e.toMap()).toList(),
      ),
    );
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.catalogImportAnalyzeError(e.toString()))),
      );
    }
    return false;
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (!context.mounted) return false;

  if (analysis.hasBlockingGlobalIssues) {
    final issue = analysis.globalIssues.isEmpty
        ? l10n.catalogImportAnalyzeError('archivo')
        : catalogImportIssueMessage(l10n, analysis.globalIssues.first);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issue)));
    return false;
  }

  final imported = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => CatalogImportReviewScreen(
        analysis: analysis,
        organizationId: organizationId,
        existingItems: existingItems,
      ),
      fullscreenDialog: true,
    ),
  );
  return imported == true;
}

class _AnalyzeArgs {
  final List<int> bytes;
  final String fileName;
  final String organizationId;
  final List<Map<String, dynamic>> existingMaps;

  const _AnalyzeArgs({
    required this.bytes,
    required this.fileName,
    required this.organizationId,
    required this.existingMaps,
  });
}

CatalogImportAnalysis _analyzeInIsolate(_AnalyzeArgs args) {
  final existing = args.existingMaps.map(CatalogItem.fromMap).toList();
  return CatalogImportService.instance.analyzeBytes(
    bytes: args.bytes,
    fileName: args.fileName,
    organizationId: args.organizationId,
    existingItems: existing,
  );
}

enum _CatalogImportAction {
  downloadExcel,
  downloadCsv,
  selectFile,
  instructions,
}

/// Pantalla de revisión previa a confirmar la importación.
class CatalogImportReviewScreen extends StatefulWidget {
  const CatalogImportReviewScreen({
    super.key,
    required this.analysis,
    required this.organizationId,
    this.existingItems = const [],
  });

  final CatalogImportAnalysis analysis;
  final String organizationId;
  final List<CatalogItem> existingItems;

  @override
  State<CatalogImportReviewScreen> createState() =>
      _CatalogImportReviewScreenState();
}

class _CatalogImportReviewScreenState extends State<CatalogImportReviewScreen> {
  CatalogDuplicatePolicy _policy = CatalogDuplicatePolicy.skip;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.analysis;
    final theme = Theme.of(context);
    final canConfirm =
        !a.hasBlockingGlobalIssues && a.validRows.isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalogImportReviewTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving
              ? null
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.catalogImportCancelled)),
                  );
                  Navigator.pop(context, false);
                },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.catalogImportFileName(a.fileName),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(l10n.catalogImportRowsDetected(a.detectedDataRows)),
          Text(l10n.catalogImportValidCount(a.validRows.length)),
          Text(l10n.catalogImportErrorCount(a.errorRows.length)),
          Text(l10n.catalogImportDuplicateCount(a.duplicateRows.length)),
          if (a.exampleRows.isNotEmpty)
            Text(l10n.catalogImportExampleSkipped(a.exampleRows.length)),
          if (a.globalIssues.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...a.globalIssues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  catalogImportIssueMessage(l10n, issue),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ] else if (a.validRows.isEmpty && a.exampleRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.catalogImportIssueOnlyExamples,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.catalogImportDuplicatePolicyTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          ...CatalogDuplicatePolicy.values.map((policy) {
            final selected = _policy == policy;
            final label = policy == CatalogDuplicatePolicy.skip
                ? l10n.catalogImportDuplicateSkip
                : l10n.catalogImportDuplicateUpdate;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              title: Text(label),
              selected: selected,
              onTap: _saving ? null : () => setState(() => _policy = policy),
            );
          }),
          const SizedBox(height: 8),
          Text(l10n.catalogImportPreview, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...a.rows.take(40).map((row) => _PreviewTile(row: row)),
          if (a.rows.length > 40)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '… +${a.rows.length - 40}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 88),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.catalogImportCancelled),
                            ),
                          );
                          Navigator.pop(context, false);
                        },
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: canConfirm ? _confirm : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.catalogImportConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    if (widget.analysis.validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.catalogImportNothingToImport)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await CatalogImportService.instance.commit(
        analysis: widget.analysis,
        organizationId: widget.organizationId,
        policy: _policy,
        existingItems: widget.existingItems,
      );
      if (!mounted) return;
      final msg = StringBuffer(
        l10n.catalogImportCommitResult(
          result.created,
          result.updated,
          result.skipped,
        ),
      );
      if (result.hasPartialFailures) {
        msg.write(' ');
        msg.write(l10n.catalogImportPartialFailures(result.failures.length));
      }
      if (result.saved <= 0 && result.skipped <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.catalogImportNothingToImport)),
        );
        setState(() => _saving = false);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg.toString())));
      Navigator.pop(context, result.saved > 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.catalogImportAnalyzeError(e.toString()))),
      );
    }
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.row});

  final CatalogImportPreviewRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = row.isExample
        ? theme.colorScheme.onSurfaceVariant
        : !row.isValid
        ? theme.colorScheme.error
        : row.isDuplicate
        ? theme.colorScheme.tertiary
        : null;
    final issueText = row.issues
        .map((i) => catalogImportIssueMessage(l10n, i))
        .join(' · ');
    final subtitleLines = <String>[
      if (row.isExample) l10n.catalogImportExampleRowLabel,
      if (row.code.isNotEmpty) row.code,
      '${row.category} · ${row.unitPrice.toStringAsFixed(2)} / ${row.unit}',
      if (issueText.isNotEmpty) issueText,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(
          '${l10n.catalogImportRowLabel(row.rowNumber)} · ${row.name}',
          style: TextStyle(
            color: color,
            fontStyle: row.isExample ? FontStyle.italic : null,
          ),
        ),
        subtitle: Text(
          subtitleLines.join('\n'),
          style: TextStyle(color: color),
        ),
        isThreeLine: subtitleLines.length > 2,
      ),
    );
  }
}
