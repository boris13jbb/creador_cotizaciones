import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

/// Guarda PDFs generados en el almacenamiento de la app (sobrevive al cierre).
class PdfLocalArchive {
  PdfLocalArchive._();
  static final PdfLocalArchive instance = PdfLocalArchive._();

  Future<Directory?> _dir(String organizationId) async {
    if (kIsWeb) return null;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'offline_pdfs', organizationId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> saveQuotePdf({
    required String organizationId,
    required String quoteId,
    required String number,
    required Uint8List bytes,
  }) async {
    final dir = await _dir(organizationId);
    if (dir == null) return null;
    final safe = number.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final file = File(p.join(dir.path, '${quoteId}_$safe.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<File?> findQuotePdf({
    required String organizationId,
    required String quoteId,
  }) async {
    final dir = await _dir(organizationId);
    if (dir == null || !await dir.exists()) return null;
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('${quoteId}_')) {
        return entity;
      }
    }
    return null;
  }
}
