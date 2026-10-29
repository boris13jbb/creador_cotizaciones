import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
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

  String _fmtDate(BuildContext context, DateTime d) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l10n = context.l10n;
    final access = auth.access;
    final isPro = access.isPro;
    final useRail = Responsive.useNavigationRail(context);
    final showAppBar =
        !embeddedInShell || (useRail && !Responsive.isWebAdaptive);
    final freeFeatures = <String>[
      l10n.featureFreeQuotes(SaasConfig.freeMaxCotizaciones),
      l10n.featurePdfExport,
      l10n.featureCloudData,
    ];
    final trialLabel = access.isTrialing && access.trialEndsAt != null
        ? l10n.trialProUntil(_fmtDate(context, access.trialEndsAt!))
        : null;

    final width = Responsive.widthOf(context);
    final useRow = width >= AppBreakpoints.expanded;

    final cards = [
      _PlanCard(
        title: 'Free',
        price: r'$0',
        features: freeFeatures,
        highlighted: !isPro,
        actionLabel: isPro ? l10n.planLowerTier : l10n.planCurrent,
        onPressed: null,
      ),
      _PlanCard(
        title: 'Pro',
        price: l10n.priceContactUs,
        features: [
          l10n.featureUnlimitedQuotes,
          l10n.featurePdfDocx,
          l10n.featureCustomBranding,
          l10n.featureReportsCsv,
          l10n.featureTeamSeats(SaasConfig.proMaxSeats),
          l10n.featureTrialDaysOnSignup(SaasConfig.trialDays),
          l10n.featurePrioritySupport,
        ],
        highlighted: isPro && access.effectivePlan.label == 'Pro',
        actionLabel: isPro
            ? '${l10n.planCurrent} / ${l10n.planActive}'
            : l10n.upgradeToPro,
        onPressed: isPro ? null : () => _upgrade(context, plan: 'pro'),
      ),
      _PlanCard(
        title: 'Business',
        price: l10n.priceContactUs,
        features: [
          l10n.featureEverythingInPro,
          l10n.featureUpToSeats(SaasConfig.businessMaxSeats),
          l10n.featureRolesListed,
          l10n.featureReportsCsvAudit,
        ],
        highlighted: access.effectivePlan.label == 'Business',
        actionLabel: access.effectivePlan.label == 'Business'
            ? l10n.planCurrent
            : l10n.upgradeToBusiness,
        onPressed: access.effectivePlan.label == 'Business'
            ? null
            : () => _upgrade(context, plan: 'business'),
      ),
    ];

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(l10n.pricingTitle)) : null,
      body: SafeArea(
        child: ContentConstraint(
          padding: AppSpacing.page,
          child: ListView(
            children: [
              Text(
                l10n.choosePlanHeadline,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.effectivePlan(access.effectivePlan.label),
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
                l10n.supportLine(SaasConfig.supportEmail),
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
