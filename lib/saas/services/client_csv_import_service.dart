import 'package:uuid/uuid.dart';

import '../models/org_client.dart';

class ClientCsvImportResult {
  final List<OrgClient> toUpsert;
  final List<String> errors;
  final int skippedEmpty;

  const ClientCsvImportResult({
    required this.toUpsert,
    required this.errors,
    this.skippedEmpty = 0,
  });

  int get okCount => toUpsert.length;
}

/// Parsea CSV de clientes (cabecera flexible).
/// Columnas reconocidas: name/nombre, email, phone/telefono, identification/id,
/// address/direccion, city/ciudad, country/pais, notes/notas.
class ClientCsvImportService {
  ClientCsvImportService._();
  static final ClientCsvImportService instance = ClientCsvImportService._();

  static const templateHeader =
      'name,email,phone,identification,address,city,country,notes';

  ClientCsvImportResult parse({
    required String csv,
    required String organizationId,
  }) {
    final lines = csv
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const ClientCsvImportResult(
        toUpsert: [],
        errors: ['El CSV está vacío'],
      );
    }

    final headerCells = _splitCsvLine(lines.first);
    final headerIndex = <String, int>{};
    for (var i = 0; i < headerCells.length; i++) {
      headerIndex[_normalizeHeader(headerCells[i])] = i;
    }

    final nameIdx = _findIndex(headerIndex, ['name', 'nombre', 'cliente']);
    if (nameIdx == null) {
      return const ClientCsvImportResult(
        toUpsert: [],
        errors: ['Falta columna name/nombre. Plantilla: $templateHeader'],
      );
    }

    final errors = <String>[];
    final clients = <OrgClient>[];
    var skipped = 0;
    final now = DateTime.now().toUtc();

    for (var row = 1; row < lines.length; row++) {
      final cells = _splitCsvLine(lines[row]);
      String cell(String key) {
        final idx = _findIndex(headerIndex, [key]);
        if (idx == null || idx >= cells.length) return '';
        return cells[idx].trim();
      }

      String cellAny(List<String> keys) {
        for (final k in keys) {
          final v = cell(k);
          if (v.isNotEmpty) return v;
        }
        return '';
      }

      final name = nameIdx < cells.length ? cells[nameIdx].trim() : '';
      if (name.isEmpty) {
        skipped++;
        continue;
      }

      final email = cellAny(['email', 'correo']);
      if (email.isNotEmpty && !email.contains('@')) {
        errors.add('Fila ${row + 1}: email inválido ($email)');
        continue;
      }

      clients.add(
        OrgClient(
          id: const Uuid().v4(),
          organizationId: organizationId,
          name: name,
          email: email.isEmpty ? null : email,
          phone: _nullIfEmpty(cellAny(['phone', 'telefono', 'tel'])),
          identification: _nullIfEmpty(
            cellAny(['identification', 'identificacion', 'id', 'ruc', 'nit']),
          ),
          address: _nullIfEmpty(cellAny(['address', 'direccion', 'dirección'])),
          city: _nullIfEmpty(cellAny(['city', 'ciudad'])),
          country: _nullIfEmpty(cellAny(['country', 'pais', 'país'])),
          notes: _nullIfEmpty(cellAny(['notes', 'notas'])),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return ClientCsvImportResult(
      toUpsert: clients,
      errors: errors,
      skippedEmpty: skipped,
    );
  }

  String? _nullIfEmpty(String v) => v.isEmpty ? null : v;

  int? _findIndex(Map<String, int> map, List<String> keys) {
    for (final k in keys) {
      final idx = map[_normalizeHeader(k)];
      if (idx != null) return idx;
    }
    return null;
  }

  String _normalizeHeader(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Split CSV respetando comillas dobles.
  List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }
}
