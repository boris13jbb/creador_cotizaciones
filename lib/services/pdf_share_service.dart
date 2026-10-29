import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

/// Resultado de preparar un PDF temporal para compartir.
class PreparedPdfShare {
  const PreparedPdfShare({
    required this.filePath,
    required this.fileName,
    required this.byteLength,
  });

  final String filePath;
  final String fileName;
  final int byteLength;
}

/// Genera archivo temporal y abre el sheet nativo de Android/iOS/desktop.
///
/// Usa [share_plus] (FileProvider en Android). No requiere permisos de
/// almacenamiento externo ni URL pública de Firebase.
class PdfShareService {
  PdfShareService._();
  static final PdfShareService instance = PdfShareService._();

  bool _busy = false;
  bool get isBusy => _busy;

  /// Directorio temporal inyectable (tests). Si es null usa path_provider.
  Directory? debugTempRoot;

  /// Cabecera mágica de un PDF válido.
  static bool looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
  }

  static String safeFileName(String number) {
    final safe = number.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final base = safe.isEmpty ? 'cotizacion' : safe;
    return 'Cotizacion_$base.pdf';
  }

  /// Escribe bytes en caché/temporal y verifica tamaño > 0.
  Future<PreparedPdfShare> prepareTempPdf({
    required Uint8List bytes,
    required String number,
  }) async {
    if (kIsWeb) {
      throw StateError('share_pdf_web_unsupported');
    }
    if (bytes.isEmpty) {
      throw StateError('share_pdf_empty');
    }
    if (!looksLikePdf(bytes)) {
      throw StateError('share_pdf_invalid');
    }

    final dir = debugTempRoot ?? await getTemporaryDirectory();
    final shareDir = Directory(p.join(dir.path, 'cotiapp_share'));
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }

    final fileName = safeFileName(number);
    final file = File(p.join(shareDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    final length = await file.length();
    if (!await file.exists() || length <= 0) {
      throw StateError('share_pdf_write_failed');
    }
    if (length != bytes.length) {
      throw StateError('share_pdf_write_failed');
    }

    return PreparedPdfShare(
      filePath: file.path,
      fileName: fileName,
      byteLength: length,
    );
  }

  /// Comparte un PDF ya preparado vía el menú nativo del sistema.
  Future<void> sharePrepared(
    PreparedPdfShare prepared, {
    String? text,
    String? subject,
  }) async {
    if (kIsWeb) {
      throw StateError('share_pdf_web_unsupported');
    }
    try {
      await Share.shareXFiles(
        [
          XFile(
            prepared.filePath,
            mimeType: 'application/pdf',
            name: prepared.fileName,
          ),
        ],
        text: text,
        subject: subject,
      );
    } catch (e, st) {
      debugPrint('PdfShareService.sharePrepared: $e\n$st');
      throw StateError('share_pdf_open_failed');
    }
  }

  /// Flujo completo: validar → escribir → abrir sheet. Anti doble-pulsación.
  Future<PreparedPdfShare> sharePdfBytes({
    required Uint8List bytes,
    required String number,
    String? text,
    String? subject,
  }) async {
    if (_busy) {
      throw StateError('share_pdf_busy');
    }
    _busy = true;
    try {
      final prepared = await prepareTempPdf(bytes: bytes, number: number);
      await sharePrepared(prepared, text: text, subject: subject);
      return prepared;
    } finally {
      _busy = false;
    }
  }

  /// Solo para tests: libera el candado sin compartir.
  void debugResetBusy() => _busy = false;

  /// Solo para tests: fuerza el candado anti doble-pulsación.
  void debugSetBusy(bool value) => _busy = value;
}
