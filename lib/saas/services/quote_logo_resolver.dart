import '../models/org_branding.dart';
import '../models/quote.dart';

/// Precedencia única para UI, vista previa y PDF.
///
/// 1. Logo personalizado de la cotización (`logoPath` propio).
/// 2. Logo global vigente de la empresa.
/// 3. Sin logo (null).
///
/// Convención de modelo (sin campo extra):
/// - `logoPath == null/''` → hereda el global (no se copia la URL en el doc).
/// - `logoPath` apunta al objeto canónico de empresa (`…/branding/logo.png` o
///   igual a `OrgBranding.logoUrl`) → se trata como herencia (compat. antigua).
/// - Cualquier otra ref (local, `quote_*.png`, data URL, URL distinta) → custom.
class QuoteLogoResolver {
  QuoteLogoResolver._();

  /// True si [path] es personalización de esa cotización (no herencia).
  static bool hasCustomLogo(String? path, {OrgBranding? orgBranding}) {
    final p = path?.trim();
    if (p == null || p.isEmpty) return false;
    return !isInheritedOrgReference(p, orgBranding);
  }

  /// Refs que deben seguir el logo global vigente (no un override).
  static bool isInheritedOrgReference(String path, OrgBranding? orgBranding) {
    final p = path.trim();
    if (p.isEmpty) return true;

    final url = orgBranding?.logoUrl?.trim();
    if (url != null && url.isNotEmpty && p == url) return true;
    final storage = orgBranding?.logoStoragePath?.trim();
    if (storage != null && storage.isNotEmpty && p == storage) return true;

    // Objeto canónico de empresa (no `quote_<id>.png`).
    if (p.contains('/branding/quote_')) return false;
    if (p.contains('/branding/logo.png') ||
        p.contains('/branding/logo.jpg') ||
        p.contains('/branding/logo.jpeg') ||
        p.contains('/branding/logo.webp')) {
      return true;
    }
    return false;
  }

  /// Path efectivo a cargar (URL Storage, local, data URL o null).
  static String? resolveLogoPath({
    String? quoteLogoPath,
    OrgBranding? orgBranding,
  }) {
    final custom = quoteLogoPath?.trim();
    if (custom == null || custom.isEmpty) {
      return _orgLogoRef(orgBranding);
    }
    if (isInheritedOrgReference(custom, orgBranding)) {
      // Preferir URL/path global vigente para que un cambio en Identidad visual
      // se refleje sin reescribir cada cotización.
      return _orgLogoRef(orgBranding) ?? custom;
    }
    return custom;
  }

  static String? resolveForQuote(Quote quote, {OrgBranding? orgBranding}) {
    return resolveLogoPath(
      quoteLogoPath: quote.logoPath,
      orgBranding: orgBranding,
    );
  }

  static String? _orgLogoRef(OrgBranding? org) {
    if (org == null) return null;
    final url = org.logoUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    final storage = org.logoStoragePath?.trim();
    if (storage != null && storage.isNotEmpty) return storage;
    return null;
  }
}
