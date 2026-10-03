import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/billing_service.dart';
import '../../ui/layout/responsive.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  Future<void> _upgrade(BuildContext context, {String plan = 'pro'}) async {
    try {
      await BillingService.instance.startCheckout(plan: plan);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final access = auth.access;
    final isPro = access.isPro;
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar = !embeddedInShell || useRail;
    final freeFeatures = <String>[
      'Hasta ${SaasConfig.freeMaxCotizaciones} cotizaciones',
      'Exportación PDF',
      'Datos en la nube',
    ];
    final trialLabel = access.isTrialing && access.trialEndsAt != null
        ? 'Prueba Pro hasta ${_fmt(access.trialEndsAt!)}'
        : null;

    final width = Responsive.widthOf(context);
    final useRow = width >= AppBreakpoints.expanded;

    final cards = [
      _PlanCard(
        title: 'Free',
        price: r'$0',
        features: freeFeatures,
        highlighted: !isPro,
        actionLabel: isPro ? 'Plan inferior' : 'Plan actual',
        onPressed: null,
      ),
      _PlanCard(
        title: 'Pro',
        price: 'Consultar',
        features: [
          'Cotizaciones ilimitadas',
          'PDF + DOCX',
          'Branding personalizado',
          'Reportes + CSV',
          'Equipo hasta ${SaasConfig.proMaxSeats} asientos',
          '${SaasConfig.trialDays} días de prueba Pro al registrarte',
          'Soporte prioritario',
        ],
        highlighted: isPro && access.effectivePlan.label == 'Pro',
        actionLabel: isPro ? 'Plan actual / activo' : 'Mejorar a Pro',
        onPressed: isPro ? null : () => _upgrade(context, plan: 'pro'),
      ),
      _PlanCard(
        title: 'Business',
        price: 'Consultar',
        features: [
          'Todo lo de Pro',
          'Hasta ${SaasConfig.businessMaxSeats} asientos',
          'Roles owner/admin/sales/readonly',
          'Reportes + CSV + auditoría',
        ],
        highlighted: access.effectivePlan.label == 'Business',
        actionLabel: access.effectivePlan.label == 'Business'
            ? 'Plan actual'
            : 'Mejorar a Business',
        onPressed: access.effectivePlan.label == 'Business'
            ? null
            : () => _upgrade(context, plan: 'business'),
      ),
    ];

    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Planes')) : null,
      body: SafeArea(
        child: ContentConstraint(
          padding: AppSpacing.page,
          child: ListView(
            children: [
              Text(
                'Elige el plan ideal para tu negocio',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Plan efectivo: ${access.effectivePlan.label}'
                '${access.isTrialing ? ' (prueba)' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (trialLabel != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(trialLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (useRow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.md),
                      Expanded(child: cards[i]),
                    ],
                  ],
                )
              else ...[
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  cards[i],
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Soporte: ${SaasConfig.supportEmail}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
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
    final theme = Theme.of(context);
    final color = highlighted
        ? theme.colorScheme.secondary
        : theme.colorScheme.outline;

    return Semantics(
      container: true,
      label: 'Plan $title',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(
            color: color.withValues(alpha: highlighted ? 0.9 : 0.4),
            width: highlighted ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                price,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 18, color: color),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(f)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
      ),
    );
  }
}
