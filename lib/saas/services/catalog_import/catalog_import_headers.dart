/// Cabeceras canónicas de la plantilla de catálogo (inglés, estables).
class CatalogImportHeaders {
  CatalogImportHeaders._();

  static const code = 'code';
  static const name = 'name';
  static const description = 'description';
  static const category = 'category';
  static const unit = 'unit';
  static const unitPrice = 'unitPrice';
  static const taxPercent = 'taxPercent';

  /// Orden de columnas en plantillas CSV/XLSX.
  static const List<String> canonical = [
    code,
    name,
    description,
    category,
    unit,
    unitPrice,
    taxPercent,
  ];

  /// Alias aceptados (ES/EN) → cabecera canónica.
  static const Map<String, String> aliases = {
    'code': code,
    'codigo': code,
    'sku': code,
    'cod': code,
    'name': name,
    'nombre': name,
    'producto': name,
    'item': name,
    'description': description,
    'descripcion': description,
    'desc': description,
    'category': category,
    'categoria': category,
    'unit': unit,
    'unidad': unit,
    'unitprice': unitPrice,
    'precio': unitPrice,
    'preciounitario': unitPrice,
    'price': unitPrice,
    'taxpercent': taxPercent,
    'tax': taxPercent,
    'impuesto': taxPercent,
    'iva': taxPercent,
  };

  static String normalize(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String? resolveCanonical(String rawHeader) {
    return aliases[normalize(rawHeader)];
  }

  /// Prefijos de código usados en las filas de ejemplo de la plantilla.
  static bool hasExampleCodePrefix(String code) {
    final c = code.trim().toUpperCase();
    return c.startsWith('EJEMPLO') || c.startsWith('EXAMPLE');
  }

  /// Fila de plantilla a omitir: código EJEMPLO/EXAMPLE **y** texto marcador
  /// en nombre/descripción. Así se pueden importar productos reales aunque
  /// conserven un código con prefijo EJEMPLO (p. ej. plantillas de servicios).
  static bool isExampleRow({
    required String code,
    required String description,
    String name = '',
  }) {
    if (!hasExampleCodePrefix(code)) return false;
    final blob = '$description $name'.toLowerCase();
    return blob.contains('no se importa') ||
        blob.contains('skipped on import') ||
        blob.contains('fila de ejemplo') ||
        blob.contains('example row');
  }

  /// Compatibilidad: solo el prefijo (preferir [isExampleRow]).
  static bool isExampleCode(String code) => hasExampleCodePrefix(code);
}
