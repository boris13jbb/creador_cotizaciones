import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// Estados visuales reutilizables: carga, vacío, error, offline y reintento.
class AsyncStateView extends StatelessWidget {
  final bool loading;
  final Object? error;
  final bool isEmpty;
  final bool isOffline;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final VoidCallback? onRetry;
  final Widget child;

  const AsyncStateView({
    super.key,
    required this.child,
    this.loading = false,
    this.error,
    this.isEmpty = false,
    this.isOffline = false,
    this.emptyTitle = 'Sin datos',
    this.emptySubtitle = '',
    this.emptyIcon = Icons.inbox_outlined,
    this.onRetry,
  });

  static bool looksLikeOffline(Object? error) {
    if (error == null) return false;
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection') ||
        text.contains('offline') ||
        text.contains('unavailable');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Semantics(
          label: 'Cargando',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final offline = isOffline || looksLikeOffline(error);
    if (error != null || offline) {
      return _Message(
        icon: offline ? Icons.wifi_off_rounded : Icons.error_outline,
        title: offline ? 'Sin conexión' : 'Algo salió mal',
        subtitle: offline ? 'Revisa tu red e inténtalo de nuevo.' : '$error',
        actionLabel: onRetry == null ? null : 'Reintentar',
        onAction: onRetry,
      );
    }

    if (isEmpty) {
      return _Message(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: onRetry == null ? null : 'Actualizar',
        onAction: onRetry,
      );
    }

    return child;
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.page,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 72,
                color: theme.colorScheme.outline,
                semanticLabel: title,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
