import 'dart:convert';

/// Identidad visual de la organización (mapa `Organization.branding`).
class OrgBranding {
  static const defaultLogoSizePt = 48.0;
  static const minLogoSizePt = 24.0;
  static const maxLogoSizePt = 96.0;

  static const defaultWatermarkOpacityPct = 12;
  static const minWatermarkOpacityPct = 5;
  static const maxWatermarkOpacityPct = 30;

  final String? logoUrl;
  final String? logoStoragePath;
  final String? colorsJson;
  final double logoSizePt;
  final LogoAlignment logoAlignment;
  final LogoPlacement logoPlacement;

  /// Marca de agua (logo en fondo del PDF).
  final bool watermarkEnabled;
  final int watermarkOpacityPct;
  final WatermarkSize watermarkSize;
  final WatermarkPosition watermarkPosition;

  const OrgBranding({
    this.logoUrl,
    this.logoStoragePath,
    this.colorsJson,
    this.logoSizePt = defaultLogoSizePt,
    this.logoAlignment = LogoAlignment.left,
    this.logoPlacement = LogoPlacement.header,
    this.watermarkEnabled = false,
    this.watermarkOpacityPct = defaultWatermarkOpacityPct,
    this.watermarkSize = WatermarkSize.medium,
    this.watermarkPosition = WatermarkPosition.center,
  });

  bool get hasLogo => logoUrl != null && logoUrl!.trim().isNotEmpty;

  /// Activa y hay logo disponible para dibujar.
  bool get watermarkActive => watermarkEnabled && hasLogo;

  double get watermarkOpacity =>
      (watermarkOpacityPct.clamp(
                minWatermarkOpacityPct,
                maxWatermarkOpacityPct,
              ) /
              100.0)
          .toDouble();

  factory OrgBranding.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const OrgBranding();
    final size = (map['logoSizePt'] as num?)?.toDouble() ?? defaultLogoSizePt;
    final opacityRaw = map['watermarkOpacityPct'] ?? map['watermarkOpacity'];
    var opacityPct = defaultWatermarkOpacityPct;
    if (opacityRaw is num) {
      // Compat: solo fracciones (0, 1) → %; enteros como 1/12/30 son %.
      opacityPct = (opacityRaw > 0 && opacityRaw < 1)
          ? (opacityRaw * 100).round()
          : opacityRaw.round();
    }
    return OrgBranding(
      logoUrl: map['logoUrl'] as String? ?? map['logoPath'] as String?,
      logoStoragePath: map['logoStoragePath'] as String?,
      colorsJson: _normalizeColors(map['colorsJson'] ?? map['colors']),
      logoSizePt: size.clamp(minLogoSizePt, maxLogoSizePt),
      logoAlignment: LogoAlignment.fromId(map['logoAlignment'] as String?),
      logoPlacement: LogoPlacement.fromId(map['logoPlacement'] as String?),
      watermarkEnabled: map['watermarkEnabled'] == true,
      watermarkOpacityPct: opacityPct.clamp(
        minWatermarkOpacityPct,
        maxWatermarkOpacityPct,
      ),
      watermarkSize: WatermarkSize.fromId(map['watermarkSize'] as String?),
      watermarkPosition: WatermarkPosition.fromId(
        map['watermarkPosition'] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'logoUrl': logoUrl,
    'logoStoragePath': logoStoragePath,
    'colorsJson': colorsJson,
    'logoSizePt': logoSizePt,
    'logoAlignment': logoAlignment.id,
    'logoPlacement': logoPlacement.id,
    'watermarkEnabled': watermarkEnabled,
    'watermarkOpacityPct': watermarkOpacityPct.clamp(
      minWatermarkOpacityPct,
      maxWatermarkOpacityPct,
    ),
    'watermarkSize': watermarkSize.id,
    'watermarkPosition': watermarkPosition.id,
  };

  OrgBranding copyWith({
    String? logoUrl,
    bool clearLogoUrl = false,
    String? logoStoragePath,
    bool clearLogoStoragePath = false,
    String? colorsJson,
    bool clearColorsJson = false,
    double? logoSizePt,
    LogoAlignment? logoAlignment,
    LogoPlacement? logoPlacement,
    bool? watermarkEnabled,
    int? watermarkOpacityPct,
    WatermarkSize? watermarkSize,
    WatermarkPosition? watermarkPosition,
  }) {
    return OrgBranding(
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      logoStoragePath: clearLogoStoragePath
          ? null
          : (logoStoragePath ?? this.logoStoragePath),
      colorsJson: clearColorsJson ? null : (colorsJson ?? this.colorsJson),
      logoSizePt: (logoSizePt ?? this.logoSizePt).clamp(
        minLogoSizePt,
        maxLogoSizePt,
      ),
      logoAlignment: logoAlignment ?? this.logoAlignment,
      logoPlacement: logoPlacement ?? this.logoPlacement,
      watermarkEnabled: watermarkEnabled ?? this.watermarkEnabled,
      watermarkOpacityPct: (watermarkOpacityPct ?? this.watermarkOpacityPct)
          .clamp(minWatermarkOpacityPct, maxWatermarkOpacityPct),
      watermarkSize: watermarkSize ?? this.watermarkSize,
      watermarkPosition: watermarkPosition ?? this.watermarkPosition,
    );
  }

  /// Campos legacy de [Quote] para que el PDF conserve layout por cotización.
  Map<String, dynamic> toQuoteLegacyFields() => {
    'logoSizePt': logoSizePt,
    'logoAlignment': logoAlignment.id,
    'logoPlacement': logoPlacement.id,
    'watermarkEnabled': watermarkEnabled,
    'watermarkOpacityPct': watermarkOpacityPct,
    'watermarkSize': watermarkSize.id,
    'watermarkPosition': watermarkPosition.id,
  };

  static OrgBranding fromQuoteLegacy({
    required String? logoPath,
    required String? colorsJson,
    required Map<String, dynamic> legacy,
  }) {
    return OrgBranding.fromMap({
      'logoUrl': logoPath,
      'colorsJson': colorsJson,
      ...legacy,
    });
  }

  static String? _normalizeColors(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is Map) {
      try {
        return jsonEncode(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

enum LogoAlignment {
  left('left'),
  center('center'),
  right('right');

  const LogoAlignment(this.id);
  final String id;

  static LogoAlignment fromId(String? id) {
    return LogoAlignment.values.firstWhere(
      (e) => e.id == id,
      orElse: () => LogoAlignment.left,
    );
  }

  String get label => switch (this) {
    LogoAlignment.left => 'Izquierda',
    LogoAlignment.center => 'Centro',
    LogoAlignment.right => 'Derecha',
  };
}

/// Ubicación del logo de encabezado. La plantilla actual solo soporta encabezado.
enum LogoPlacement {
  header('header');

  const LogoPlacement(this.id);
  final String id;

  static LogoPlacement fromId(String? id) {
    return LogoPlacement.values.firstWhere(
      (e) => e.id == id,
      orElse: () => LogoPlacement.header,
    );
  }

  String get label => 'Encabezado';
}

enum WatermarkSize {
  small('small'),
  medium('medium'),
  large('large');

  const WatermarkSize(this.id);
  final String id;

  static WatermarkSize fromId(String? id) {
    return WatermarkSize.values.firstWhere(
      (e) => e.id == id,
      orElse: () => WatermarkSize.medium,
    );
  }

  String get label => switch (this) {
    WatermarkSize.small => 'Pequeño',
    WatermarkSize.medium => 'Mediano',
    WatermarkSize.large => 'Grande',
  };

  /// Ancho máximo en puntos PDF (proporción conservada con contain).
  double get maxWidthPt => switch (this) {
    WatermarkSize.small => 140,
    WatermarkSize.medium => 220,
    WatermarkSize.large => 300,
  };
}

enum WatermarkPosition {
  center('center'),
  topCenter('topCenter'),
  bottomCenter('bottomCenter'),
  bottomRight('bottomRight');

  const WatermarkPosition(this.id);
  final String id;

  static WatermarkPosition fromId(String? id) {
    return WatermarkPosition.values.firstWhere(
      (e) => e.id == id,
      orElse: () => WatermarkPosition.center,
    );
  }

  String get label => switch (this) {
    WatermarkPosition.center => 'Centro',
    WatermarkPosition.topCenter => 'Centro superior',
    WatermarkPosition.bottomCenter => 'Centro inferior',
    WatermarkPosition.bottomRight => 'Esquina inferior derecha',
  };
}
