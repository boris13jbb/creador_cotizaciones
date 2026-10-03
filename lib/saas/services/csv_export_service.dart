import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

/// Comparte o descarga texto CSV generado en cliente.
class CsvExportService {
  CsvExportService._();
  static final CsvExportService instance = CsvExportService._();

  Future<void> shareCsv({
    required String fileName,
    required String csvContent,
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
    if (kIsWeb) {
      // share_plus en web comparte texto; el usuario puede guardar.
      await Share.share(csvContent, subject: safe);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(utf8.encode(csvContent));
    await Share.shareXFiles([XFile(file.path)], text: safe);
  }
}
