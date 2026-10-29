import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_ext.dart';
import '../models/cotizacion.dart';
import '../saas/domain/org_enums.dart';
import '../saas/historial/historial_query.dart';
import '../theme/app_theme.dart';

class CotizacionCard extends StatelessWidget {
  final Cotizacion cotizacion;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onHide;
  final VoidCallback? onDuplicate;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onNewVersion;
  final VoidCallback? onShare;
  final bool actionsEnabled;

  const CotizacionCard({
    super.key,
    required this.cotizacion,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    this.onHide,
    this.onDuplicate,
    this.onArchive,
    this.onRestore,
    this.onNewVersion,
    this.onShare,
    this.actionsEnabled = true,
  });

  bool get _isArchived => cotizacion.quoteStatus == QuoteStatus.archived.id;

  (String, Color)? _offlineBadge(BuildContext context) {
    final l10n = context.l10n;
    switch (cotizacion.offlineSyncStatus) {
      case 'pending':
      case 'error':
        return (l10n.deviceOnly, Colors.orange.shade800);
      case 'conflict':
        return (l10n.conflict, Colors.red.shade700);
      default:
        if (cotizacion.numero.startsWith('LOCAL-')) {
          return (l10n.deviceOnly, Colors.orange.shade800);
        }
        return null;
    }
  }

  Color _statusBg(String statusId) {
    if (statusId == QuoteStatus.archived.id) {
      return Colors.blueGrey.shade100;
    }
    if (statusId == QuoteStatus.accepted.id) {
      return AppTheme.secondaryGreen.withValues(alpha: 0.18);
    }
    if (statusId == QuoteStatus.rejected.id ||
        statusId == QuoteStatus.expired.id) {
      return Colors.red.shade50;
    }
    return AppTheme.secondaryGreen.withValues(alpha: 0.12);
  }

  Color _statusFg(String statusId) {
    if (statusId == QuoteStatus.archived.id) {
      return Colors.blueGrey.shade800;
    }
    if (statusId == QuoteStatus.rejected.id ||
        statusId == QuoteStatus.expired.id) {
      return Colors.red.shade800;
    }
    return AppTheme.secondaryGreen;
  }

  Widget _menuRow(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: color == null ? null : TextStyle(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeName = Localizations.localeOf(context).toString();
    final currencyFormat = NumberFormat.currency(
      locale: localeName,
      symbol: '\$',
      decimalDigits: 2,
    );
    final statusId = cotizacion.quoteStatus;
    final offlineBadge = _offlineBadge(context);
    final subtitleLine = cotizacion.tipoServicio.trim().isNotEmpty
        ? cotizacion.tipoServicio
        : (cotizacion.descripcion.trim().isNotEmpty
              ? cotizacion.descripcion
              : (cotizacion.subtitulo ?? ''));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: actionsEnabled ? onTap : null,
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          cotizacion.cliente.isEmpty ? l10n.noClient : cotizacion.cliente,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.tag,
                      size: 14,
                      color: AppTheme.secondaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cotizacion.numero,
                      style: const TextStyle(
                        color: AppTheme.secondaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (statusId != null && statusId.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBg(statusId),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      HistorialQuery.statusLabelForId(statusId, l10n),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusFg(statusId),
                      ),
                    ),
                  ),
                if (offlineBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: offlineBadge.$2.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      offlineBadge.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: offlineBadge.$2,
                      ),
                    ),
                  ),
              ],
            ),
            if (subtitleLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitleLine, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.totalLabel(currencyFormat.format(cotizacion.total)),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          enabled: actionsEnabled,
          icon: const Icon(Icons.more_vert),
          tooltip: l10n.actions,
          onSelected: (value) {
            if (!actionsEnabled) return;
            if (value == 'ver') {
              onTap();
            } else if (value == 'editar') {
              onEdit();
            } else if (value == 'compartir') {
              onShare?.call();
            } else if (value == 'duplicar') {
              onDuplicate?.call();
            } else if (value == 'version') {
              onNewVersion?.call();
            } else if (value == 'archivar') {
              onArchive?.call();
            } else if (value == 'restaurar') {
              onRestore?.call();
            } else if (value == 'ocultar') {
              onHide?.call();
            } else if (value == 'eliminar') {
              onDelete();
            }
          },
          itemBuilder: (context) {
            final m = context.l10n;
            return [
              PopupMenuItem(
                value: 'ver',
                child: _menuRow(Icons.visibility_outlined, m.viewPdf),
              ),
              PopupMenuItem(
                value: 'editar',
                child: _menuRow(Icons.edit_outlined, m.edit),
              ),
              if (onShare != null)
                PopupMenuItem(
                  value: 'compartir',
                  child: _menuRow(Icons.share_outlined, m.shareQuote),
                ),
              if (onDuplicate != null)
                PopupMenuItem(
                  value: 'duplicar',
                  child: _menuRow(Icons.copy_outlined, m.duplicate),
                ),
              if (onNewVersion != null)
                PopupMenuItem(
                  value: 'version',
                  child: _menuRow(Icons.history_edu_outlined, m.newVersion),
                ),
              if (onArchive != null && !_isArchived)
                PopupMenuItem(
                  value: 'archivar',
                  child: _menuRow(Icons.archive_outlined, m.archive),
                ),
              if (onRestore != null && _isArchived)
                PopupMenuItem(
                  value: 'restaurar',
                  child: _menuRow(Icons.unarchive_outlined, m.restoreToDraft),
                ),
              if (onHide != null)
                PopupMenuItem(
                  value: 'ocultar',
                  child: _menuRow(
                    Icons.visibility_off_outlined,
                    m.hideFromRecent,
                  ),
                ),
              PopupMenuItem(
                value: 'eliminar',
                child: _menuRow(
                  Icons.delete_outline,
                  m.delete,
                  color: Colors.red,
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}
