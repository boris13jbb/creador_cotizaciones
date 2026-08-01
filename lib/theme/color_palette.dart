class ColorPalette {
  final String primary;
  final String secondary;
  final String accent;
  final String success;
  final String error;

  ColorPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.error,
  });

  Map<String, String> toJson() {
    return {
      'primary': primary,
      'secondary': secondary,
      'accent': accent,
      'success': success,
      'error': error,
    };
  }

  static ColorPalette fromJson(Map<String, dynamic> json) {
    return ColorPalette(
      primary: json['primary'] as String,
      secondary: json['secondary'] as String,
      accent: json['accent'] as String,
      success: json['success'] as String,
      error: json['error'] as String,
    );
  }
}
