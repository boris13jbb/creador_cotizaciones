import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../tokens/app_spacing.dart';

class PlanBadge extends StatelessWidget {
  final String label;
  final bool isTrialing;

  const PlanBadge({super.key, required this.label, this.isTrialing = false});

  @override
  Widget build(BuildContext context) {
    final text = isTrialing ? 'Prueba Pro' : label;
    return Semantics(
      label: 'Plan $text',
      child: Chip(
        avatar: Icon(
          Icons.workspace_premium_outlined,
          size: 16,
          color: AppTheme.secondaryGreen,
        ),
        label: Text(text, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
