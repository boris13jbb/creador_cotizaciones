import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../saas/config/saas_config.dart';

enum LegalKind { privacy, terms }

/// Pantallas informativas de privacidad/términos (no constituyen asesoría legal).
class LegalScreen extends StatelessWidget {
  final LegalKind kind;

  const LegalScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = kind == LegalKind.privacy;
    final title = isPrivacy ? 'Privacidad' : 'Términos de uso';
    final external = isPrivacy ? SaasConfig.privacyUrl : SaasConfig.termsUrl;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            SaasConfig.productName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Documento informativo (plantilla CotiApp). '
            'Adapta este texto con tu asesor legal antes de producción. '
            'También puedes publicar URLs externas con PRIVACY_URL / TERMS_URL.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          if (external.isNotEmpty)
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.parse(external);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(
                isPrivacy ? 'Ver política completa' : 'Ver términos completos',
              ),
            ),
          const SizedBox(height: 16),
          Text(
            isPrivacy ? _privacyBody : _termsBody,
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 24),
          Text(
            'Contacto: ${SaasConfig.supportEmail}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  static const _privacyBody = '''
1. Responsable: el operador de CotiApp.
2. Datos tratados: correo, nombre mostrado, cotizaciones y metadatos de suscripción.
3. Finalidad: prestar el servicio de cotizaciones en la nube, autenticación, soporte y facturación.
4. Conservación: mientras la cuenta esté activa y los plazos legales aplicables.
5. Derechos: acceso, rectificación, exportación y eliminación desde Mi cuenta, o escribiendo a soporte.
6. Encargados: Firebase (Google) y, si se activa, Stripe para pagos.
7. Esta plantilla no sustituye una política de privacidad revisada legalmente.
''';

  static const _termsBody = '''
1. CotiApp se ofrece bajo planes Free, Pro y Business con límites descritos en la app.
2. El usuario es responsable del contenido de sus cotizaciones y del uso lícito del servicio.
3. El periodo de prueba Pro (14 días) otorga funciones Pro mientras esté vigente.
4. Las suscripciones de pago se gestionan vía Stripe; la cancelación aplica según la política del proveedor y el periodo contratado.
5. Podemos suspender cuentas por abuso, impago o incumplimiento.
6. El software se proporciona “tal cual”; la disponibilidad puede variar.
7. Esta plantilla no sustituye unos términos de uso revisados legalmente.
''';
}
