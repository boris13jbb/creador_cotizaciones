import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/models/cotizacion.dart';
import 'package:creador_cotizaciones/models/servicio.dart';

void main() {
  group('Cotizacion', () {
    test('toMap/fromMap conserva campos esenciales', () {
      final cot = Cotizacion(
        id: 'id-1',
        numero: 'COT-001',
        fecha: '2026-07-31',
        cliente: 'Cliente Demo',
        ubicacion: 'Quito',
        tipoServicio: 'Web',
        cantidadEquipos: '1',
        tiempoEstimado: '5 días',
        descripcion: 'Proyecto demo',
        servicios: [
          Servicio(nombre: 'Diseño', descripcion: 'UI', precio: 100.5),
        ],
        total: 100.5,
        incluye: ['Hosting'],
        noIncluye: ['Dominio'],
        notas: ['Nota'],
        validezDias: 30,
      );

      final restored = Cotizacion.fromMap(cot.toMap(), cot.servicios);
      expect(restored.id, 'id-1');
      expect(restored.numero, 'COT-001');
      expect(restored.cliente, 'Cliente Demo');
      expect(restored.total, 100.5);
      expect(restored.servicios.single.nombre, 'Diseño');
      expect(restored.validezDias, 30);
    });

    test('formaPago parsea JSON válido', () {
      final cot = Cotizacion(
        id: 'id-2',
        numero: 'COT-002',
        fecha: '2026-07-31',
        cliente: 'X',
        ubicacion: '',
        tipoServicio: '',
        cantidadEquipos: '',
        tiempoEstimado: '',
        descripcion: '',
        servicios: const [],
        total: 50,
        incluye: const [],
        noIncluye: const [],
        notas: const [],
        formaPagoJson:
            '[{"etiqueta":"Anticipo","descripcion":"50%","monto":50}]',
      );

      expect(cot.formaPago, hasLength(1));
      expect(cot.formaPago.single.etiqueta, 'Anticipo');
      expect(cot.formaPago.single.monto, 50);
    });

    test('formaPago con JSON inválido devuelve lista vacía', () {
      final cot = Cotizacion(
        id: 'id-3',
        numero: 'COT-003',
        fecha: '2026-07-31',
        cliente: 'Y',
        ubicacion: '',
        tipoServicio: '',
        cantidadEquipos: '',
        tiempoEstimado: '',
        descripcion: '',
        servicios: const [],
        total: 0,
        incluye: const [],
        noIncluye: const [],
        notas: const [],
        formaPagoJson: 'no-es-json',
      );
      expect(cot.formaPago, isEmpty);
    });
  });
}
