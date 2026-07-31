/// Un tramo de forma de pago (ej. Anticipo 50%, Entrega parcial 25%, Saldo final 25%).
class FormaPagoItem {
  final String etiqueta;
  final String descripcion;
  final double monto;

  FormaPagoItem({
    required this.etiqueta,
    required this.descripcion,
    required this.monto,
  });

  Map<String, dynamic> toJson() => {
        'etiqueta': etiqueta,
        'descripcion': descripcion,
        'monto': monto,
      };

  factory FormaPagoItem.fromJson(Map<String, dynamic> json) {
    return FormaPagoItem(
      etiqueta: json['etiqueta']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      monto: (json['monto'] is num) ? (json['monto'] as num).toDouble() : 0,
    );
  }
}
