import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

import 'catalog_csv_codec.dart';
import 'catalog_xlsx_codec.dart';

/// Resultado de generar/guardar una plantilla.
class CatalogTemplateShareResult {
  final String fileName;
  final String? savedPath;
  final bool shared;

  const CatalogTemplateShareResult({
    required this.fileName,
    this.savedPath,
    this.shared = false,
  });
}

/// Genera y descarga/comparte plantillas locales (sin red ni Firebase).
class CatalogTemplateService {
  CatalogTemplateService._();
  static final CatalogTemplateService instance = CatalogTemplateService._();

  Future<CatalogTemplateShareResult> shareCsvTemplate({
    required bool spanishLabels,
  }) async {
    final content = CatalogCsvCodec.instance.buildTemplate(
      spanishLabels: spanishLabels,
    );
    final name = spanishLabels
        ? 'cotiapp_plantilla_catalogo.csv'
        : 'cotiapp_catalog_template.csv';
    return _saveOrShare(
      fileName: name,
      bytes: utf8.encode(content),
      mimeType: 'text/csv',
      extension: 'csv',
    );
  }

  Future<CatalogTemplateShareResult> shareXlsxTemplate({
    required bool spanishLabels,
  }) async {
    final bytes = CatalogXlsxCodec.instance.buildTemplate(
      spanishLabels: spanishLabels,
    );
    final name = spanishLabels
        ? 'cotiapp_plantilla_catalogo.xlsx'
        : 'cotiapp_catalog_template.xlsx';
    return _saveOrShare(
      fileName: name,
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      extension: 'xlsx',
    );
  }

  Future<CatalogTemplateShareResult> _saveOrShare({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String extension,
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final data = Uint8List.fromList(bytes);
    if (data.isEmpty) {
      throw StateError('La plantilla generada está vacía');
    }

    // 1) Diálogo de guardar (Windows/desktop y plataformas que lo soporten).
    if (!kIsWeb) {
      try {
        final saved = await FilePicker.platform.saveFile(
          dialogTitle: safe,
          fileName: safe,
          type: FileType.custom,
          allowedExtensions: [extension],
          bytes: data,
        );
        if (saved != null && saved.isNotEmpty) {
          // En algunas plataformas saveFile solo devuelve la ruta y hay que escribir.
          final path = saved.toLowerCase().endsWith('.$extension')
              ? saved
              : '$saved.$extension';
          final file = File(path);
          if (!await file.exists() || (await file.length()) == 0) {
            await file.writeAsBytes(data, flush: true);
          }
          return CatalogTemplateShareResult(fileName: safe, savedPath: path);
        }
      } catch (_) {
        // Continuar con share / temp.
      }
    }

    // 2) Web / fallback: compartir o escribir en temp + share.
    if (kIsWeb) {
      await Share.shareXFiles([
        XFile.fromData(data, mimeType: mimeType, name: safe),
      ], text: safe);
      return CatalogTemplateShareResult(fileName: safe, shared: true);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(data, flush: true);
    if (!await file.exists() || (await file.length()) == 0) {
      throw StateError('No se pudo escribir la plantilla en disco');
    }
    await Share.shareXFiles([
      XFile(file.path, mimeType: mimeType, name: safe),
    ], text: safe);
    return CatalogTemplateShareResult(
      fileName: safe,
      savedPath: file.path,
      shared: true,
    );
  }
}
