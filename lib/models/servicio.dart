class Servicio {
  final String nombre;
  final String descripcion;
  final double precio;

  Servicio({
    required this.nombre,
    required this.descripcion,
    required this.precio,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
    };
  }

  factory Servicio.fromMap(Map<String, dynamic> map) {
    return Servicio(
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      precio: (map['precio'] ?? 0.0).toDouble(),
    );
  }
}
