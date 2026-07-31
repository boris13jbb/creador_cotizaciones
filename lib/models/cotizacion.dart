import 'dart:convert';

import 'forma_pago_item.dart';
import 'servicio.dart';

class Cotizacion {
  final String id;
  final String numero;
  final String fecha;
  final String cliente;
  final String ubicacion;
  final String tipoServicio;
  final String cantidadEquipos;
  final String tiempoEstimado;
  final String descripcion;
  final List<Servicio> servicios;
  final double total;
  final List<String> incluye;
  final List<String> noIncluye;
  final List<String> notas;
  final String? logoPath;

  /// Subtítulo bajo el título principal (ej. "Desarrollo Web • Plataforma de Venta de Servicios Fotográficos").
  final String? subtitulo;
  /// Validez en días (ej. 30 para "Válida: 30 días").
  final int? validezDias;
  /// Texto del pie (ej. "Documento confidencial — Elaborado para uso exclusivo del cliente | Freelancer Independiente | Ecuador").
  final String? footerText;
  /// Etiqueta de la firma del técnico/desarrollador.
  final String? firmaTecnicoLabel;
  /// Etiqueta de la firma del cliente.
  final String? firmaClienteLabel;
  /// Forma de pago: JSON array de { etiqueta, descripcion, monto }. Si null, se calcula 50/25/25 por defecto.
  final String? formaPagoJson;
  /// Campos extra para "Información del proyecto": "Label|Value|Label|Value". Permite añadir más filas.
  final String? camposExtra;

  /// Colores personalizados para la cotización en formato JSON: {"primary":"#hex","secondary":"#hex",...}
  final String? coloresJson;

  Cotizacion({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.cliente,
    required this.ubicacion,
    required this.tipoServicio,
    required this.cantidadEquipos,
    required this.tiempoEstimado,
    required this.descripcion,
    required this.servicios,
    required this.total,
    required this.incluye,
    required this.noIncluye,
    required this.notas,
    this.logoPath,
    this.subtitulo,
    this.validezDias,
    this.footerText,
    this.firmaTecnicoLabel,
    this.firmaClienteLabel,
    this.formaPagoJson,
    this.camposExtra,
    this.coloresJson,
  });

  /// Forma de pago parseada (lista vacía si no hay o hay error).
  List<FormaPagoItem> get formaPago {
    if (formaPagoJson == null || formaPagoJson!.trim().isEmpty) return [];
    try {
      final list = jsonDecode(formaPagoJson!) as List<dynamic>?;
      if (list == null) return [];
      return list.map((e) => FormaPagoItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Pares label-value para información extra del proyecto (permite insertar más campos).
  List<MapEntry<String, String>> get camposExtraList {
    if (camposExtra == null || camposExtra!.trim().isEmpty) return [];
    final parts = camposExtra!.split('|');
    final list = <MapEntry<String, String>>[];
    for (var i = 0; i + 1 < parts.length; i += 2) {
      final label = parts[i].trim();
      final value = parts[i + 1].trim();
      if (label.isNotEmpty || value.isNotEmpty) {
        list.add(MapEntry(label, value));
      }
    }
    return list;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'fecha': fecha,
      'cliente': cliente,
      'ubicacion': ubicacion,
      'tipoServicio': tipoServicio,
      'cantidadEquipos': cantidadEquipos,
      'tiempoEstimado': tiempoEstimado,
      'descripcion': descripcion,
      'total': total,
      'logoPath': logoPath,
      'incluye': incluye.join('|'),
      'noIncluye': noIncluye.join('|'),
      'notas': notas.join('|'),
      'subtitulo': subtitulo,
      'validezDias': validezDias,
      'footerText': footerText,
      'firmaTecnicoLabel': firmaTecnicoLabel,
      'firmaClienteLabel': firmaClienteLabel,
      'formaPagoJson': formaPagoJson,
      'camposExtra': camposExtra,
      'coloresJson': coloresJson,
    };
  }

  factory Cotizacion.fromMap(Map<String, dynamic> map, List<Servicio> serviciosList) {
    return Cotizacion(
      id: map['id'] as String? ?? '',
      numero: map['numero'] as String? ?? '',
      fecha: map['fecha'] as String? ?? '',
      cliente: map['cliente'] as String? ?? '',
      ubicacion: map['ubicacion'] as String? ?? '',
      tipoServicio: map['tipoServicio'] as String? ?? '',
      cantidadEquipos: map['cantidadEquipos'] as String? ?? '',
      tiempoEstimado: map['tiempoEstimado'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      total: _toDouble(map['total']),
      logoPath: map['logoPath'] as String?,
      servicios: serviciosList,
      incluye: (map['incluye'] as String?)?.split('|').where((s) => s.isNotEmpty).toList() ?? [],
      noIncluye: (map['noIncluye'] as String?)?.split('|').where((s) => s.isNotEmpty).toList() ?? [],
      notas: (map['notas'] as String?)?.split('|').where((s) => s.isNotEmpty).toList() ?? [],
      subtitulo: map['subtitulo'] as String?,
      validezDias: map['validezDias'] as int?,
      footerText: map['footerText'] as String?,
      firmaTecnicoLabel: map['firmaTecnicoLabel'] as String?,
      firmaClienteLabel: map['firmaClienteLabel'] as String?,
      formaPagoJson: map['formaPagoJson'] as String?,
      camposExtra: map['camposExtra'] as String?,
      coloresJson: map['coloresJson'] as String?,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
