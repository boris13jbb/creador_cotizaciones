import 'package:creador_cotizaciones/l10n/app_localizations_es.dart';
import 'package:creador_cotizaciones/models/cotizacion.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/historial/historial_query.dart';
import 'package:flutter_test/flutter_test.dart';

Cotizacion _cot({
  required String id,
  String numero = 'COT-001',
  String cliente = 'Acme',
  String descripcion = '',
  String tipo = 'Servicio',
  String? status = 'draft',
  String fecha = '2026-01-02T00:00:00.000Z',
  double total = 10,
}) {
  return Cotizacion(
    id: id,
    numero: numero,
    fecha: fecha,
    cliente: cliente,
    ubicacion: 'Quito',
    tipoServicio: tipo,
    cantidadEquipos: '1',
    tiempoEstimado: '1d',
    descripcion: descripcion,
    servicios: const [],
    total: total,
    incluye: const [],
    noIncluye: const [],
    notas: const [],
    quoteStatus: status,
  );
}

void main() {
  group('HistorialQuery.search', () {
    final items = [
      _cot(id: 'a', numero: 'COT-006', cliente: 'brgc', descripcion: 'bb'),
      _cot(id: 'b', numero: 'COT-002', cliente: 'bhf', status: 'archived'),
      _cot(id: 'c', numero: 'COT-001', cliente: 'Boris', tipo: 'bes'),
    ];

    test('ignora mayúsculas y encuentra por cliente', () {
      final r = HistorialQuery.applySearch(items, 'BORIS');
      expect(r.map((e) => e.id), ['c']);
    });

    test('encuentra por número de cotización', () {
      final r = HistorialQuery.applySearch(items, 'cot-006');
      expect(r.single.numero, 'COT-006');
    });

    test('encuentra por descripción', () {
      final r = HistorialQuery.applySearch(items, 'bb');
      expect(r.map((e) => e.id), ['a']);
    });

    test('query vacío no filtra', () {
      expect(HistorialQuery.applySearch(items, '  ').length, 3);
    });

    test('sin coincidencias devuelve lista vacía sin mutar origen', () {
      final r = HistorialQuery.applySearch(items, 'zzzz');
      expect(r, isEmpty);
      expect(items.length, 3);
    });
  });

  group('HistorialQuery.merge', () {
    test('no duplica el mismo id entre remoto y local', () {
      final remote = [_cot(id: '1', numero: 'COT-001', cliente: 'Remoto')];
      final local = [
        (
          cotizacion: _cot(
            id: '1',
            numero: 'COT-001',
            cliente: 'LocalPendiente',
          ),
          syncStatus: 'pending',
        ),
        (
          cotizacion: _cot(id: '2', numero: 'LOCAL-1', cliente: 'SoloLocal'),
          syncStatus: 'pending',
        ),
      ];
      final merged = HistorialQuery.mergeRemoteAndLocal(
        remote: remote,
        local: local,
      );
      expect(merged.map((e) => e.id).toSet(), {'1', '2'});
      expect(merged.firstWhere((e) => e.id == '1').cliente, 'LocalPendiente');
      expect(
        merged.firstWhere((e) => e.id == '1').offlineSyncStatus,
        'pending',
      );
    });

    test('filtro de estado aplica al merge local', () {
      final remote = [
        _cot(id: '1', status: 'draft'),
        _cot(id: '2', status: 'archived'),
      ];
      final local = [
        (
          cotizacion: _cot(id: '3', status: 'archived', numero: 'LOCAL-A'),
          syncStatus: 'synced',
        ),
      ];
      final merged = HistorialQuery.mergeRemoteAndLocal(
        remote: remote,
        local: local,
        statusFilter: 'archived',
      );
      // Remoto ya viene prefiltrado en repo; aquí solo filtramos locales.
      expect(merged.any((e) => e.id == '3'), isTrue);
      expect(
        merged.any((e) => e.id == '1' && e.quoteStatus == 'draft'),
        isTrue,
      );
    });
  });

  group('HistorialQuery.status labels', () {
    final l10n = AppLocalizationsEs();

    test('cubre todos los estados del enum', () {
      for (final s in QuoteStatus.values) {
        expect(HistorialQuery.statusLabel(s, l10n), isNotEmpty);
        expect(HistorialQuery.filterableStatuses, contains(s));
      }
    });

    test('archived tiene etiqueta en español', () {
      expect(
        HistorialQuery.statusLabel(QuoteStatus.archived, l10n),
        'Archivada',
      );
    });
  });
}
