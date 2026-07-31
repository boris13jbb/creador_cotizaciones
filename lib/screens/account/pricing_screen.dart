import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  Future<void> _openStripe(BuildContext context) async {
    final link = SaasConfig.stripePaymentLink;
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configura STRIPE_PAYMENT_LINK para habilitar el cobro. '
            'Mientras tanto contacta soporte para activar Pro.',
          ),
        ),
      );
      return;
    }
    final uri = Uri.parse(link);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace de pago')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final isPro = profile?.isPro ?? false;
    final freeFeatures = <String>[
      'Hasta ${SaasConfig.freeMaxCotizaciones} cotizaciones',
      'Exportación PDF',
      'Datos en la nube',
      '14 días de prueba de funciones Pro',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Planes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Elige el plan ideal para tu negocio',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Plan actual: ${profile?.plan.label ?? 'Free'}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          _PlanCard(
            title: 'Free',
            price: r'$0',
            features: freeFeatures,
            highlighted: !isPro,
            actionLabel: isPro ? 'Plan inferior' : 'Plan actual',
            onPressed: null,
          ),
          const SizedBox(height: 16),
          _PlanCard(
            title: 'Pro',
            price: r'$9.99/mes',
            features: const [
              'Cotizaciones ilimitadas',
              'PDF + DOCX',
              'Branding personalizado',
              'Soporte prioritario',
            ],
            highlighted: isPro,
            actionLabel: isPro ? 'Plan actual' : 'Mejorar a Pro',
            onPressed: isPro ? null : () => _openStripe(context),
          ),
          const SizedBox(height: 24),
          Text(
            'Soporte: ${SaasConfig.supportEmail}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final bool highlighted;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.highlighted,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? Theme.of(context).colorScheme.secondary : Colors.grey;
    return Card(
      elevation: highlighted ? 3 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(120), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
