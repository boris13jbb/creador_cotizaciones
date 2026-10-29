import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';
import '../saas/offline/offline_controller.dart';
import '../saas/offline/offline_sync_status.dart';

/// Indicador compacto de conexión / cola de sincronización.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineController.instance,
      builder: (context, _) {
        final c = OfflineController.instance;
        final l10n = context.l10n;
        final color = switch (c.status) {
          OfflineUiStatus.online => Colors.green.shade700,
          OfflineUiStatus.offline => Colors.orange.shade800,
          OfflineUiStatus.syncing => Colors.blue.shade700,
          OfflineUiStatus.pendingChanges => Colors.amber.shade900,
          OfflineUiStatus.syncError => Colors.red.shade700,
        };
        final icon = switch (c.status) {
          OfflineUiStatus.online => Icons.cloud_done_outlined,
          OfflineUiStatus.offline => Icons.cloud_off_outlined,
          OfflineUiStatus.syncing => Icons.sync,
          OfflineUiStatus.pendingChanges => Icons.cloud_upload_outlined,
          OfflineUiStatus.syncError => Icons.sync_problem,
        };

        if (c.status == OfflineUiStatus.online && !c.hasPending) {
          return const SizedBox.shrink();
        }

        final statusText = switch (c.status) {
          OfflineUiStatus.offline => l10n.offlineBannerOffline,
          OfflineUiStatus.syncing => l10n.offlineBannerSyncing,
          OfflineUiStatus.pendingChanges => l10n.offlineBannerPending,
          OfflineUiStatus.syncError => l10n.offlineBannerError,
          OfflineUiStatus.online => l10n.pendingSync,
        };

        final parts = <String>[statusText];
        if (c.pendingQuotes > 0) {
          parts.add(l10n.pendingChangesQuotes(c.pendingQuotes));
        }

        return Material(
          color: color.withValues(alpha: 0.12),
          child: InkWell(
            onTap: c.status == OfflineUiStatus.syncing
                ? null
                : () => OfflineController.instance.syncNow(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parts.join(' · '),
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (c.status != OfflineUiStatus.syncing)
                    Text(
                      l10n.syncNow,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
