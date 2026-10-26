import 'package:creador_cotizaciones/saas/models/org_branding.dart';
import 'package:creador_cotizaciones/saas/services/quote_logo_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const org = OrgBranding(
    logoUrl: 'https://cdn.example/org-logo.png',
    logoStoragePath: 'organizations/org-a/branding/logo.png',
  );

  test('cotización sin logoPath hereda el global vigente', () {
    expect(
      QuoteLogoResolver.resolveLogoPath(quoteLogoPath: null, orgBranding: org),
      org.logoUrl,
    );
    expect(QuoteLogoResolver.hasCustomLogo(null, orgBranding: org), isFalse);
  });

  test('logoPath igual a URL de empresa se trata como herencia (legacy)', () {
    expect(
      QuoteLogoResolver.isInheritedOrgReference(org.logoUrl!, org),
      isTrue,
    );
    expect(
      QuoteLogoResolver.resolveLogoPath(
        quoteLogoPath: org.logoUrl,
        orgBranding: org,
      ),
      org.logoUrl,
    );
    expect(
      QuoteLogoResolver.hasCustomLogo(org.logoUrl, orgBranding: org),
      isFalse,
    );
  });

  test('cambiar global: herencia sigue al logoUrl vigente', () {
    const updated = OrgBranding(
      logoUrl: 'https://cdn.example/org-logo-v2.png',
      logoStoragePath: 'organizations/org-a/branding/logo.png',
    );
    // Doc antiguo con URL vieja (misma ruta Storage canónica).
    expect(
      QuoteLogoResolver.resolveLogoPath(
        quoteLogoPath: 'organizations/org-a/branding/logo.png',
        orgBranding: updated,
      ),
      updated.logoUrl,
    );
  });

  test(
    'personalización quote_ no es herencia y no se ve afectada por global',
    () {
      const custom = 'organizations/org-a/branding/quote_q-1.png';
      expect(QuoteLogoResolver.isInheritedOrgReference(custom, org), isFalse);
      expect(
        QuoteLogoResolver.resolveLogoPath(
          quoteLogoPath: custom,
          orgBranding: org,
        ),
        custom,
      );
      const org2 = OrgBranding(logoUrl: 'https://cdn.example/other.png');
      expect(
        QuoteLogoResolver.resolveLogoPath(
          quoteLogoPath: custom,
          orgBranding: org2,
        ),
        custom,
      );
    },
  );

  test('ruta local / data URL son personalización', () {
    expect(
      QuoteLogoResolver.hasCustomLogo(
        '/data/quote_logos/q1.bin',
        orgBranding: org,
      ),
      isTrue,
    );
    expect(
      QuoteLogoResolver.hasCustomLogo(
        'data:image/png;base64,aaa',
        orgBranding: org,
      ),
      isTrue,
    );
  });

  test('quitar personalización (null) vuelve al global', () {
    expect(
      QuoteLogoResolver.resolveLogoPath(quoteLogoPath: null, orgBranding: org),
      org.logoUrl,
    );
  });

  test('sin org ni custom → null', () {
    expect(
      QuoteLogoResolver.resolveLogoPath(quoteLogoPath: null, orgBranding: null),
      isNull,
    );
  });
}
