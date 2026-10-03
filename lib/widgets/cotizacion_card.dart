import 'package:flutter/material.dart';
import '../models/cotizacion.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class CotizacionCard extends StatelessWidget {
  final Cotizacion cotizacion;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onHide;
  final VoidCallback? onDuplicate;
  final VoidCallback? onArchive;
  final VoidCallback? onNewVersion;

  const CotizacionCard({
    super.key,
    required this.cotizacion,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    this.onHide,
    this.onDuplicate,
    this.onArchive,
    this.onNewVersion,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          cotizacion.cliente,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.tag, size: 14, color: AppTheme.secondaryGreen),
                const SizedBox(width: 4),
                Text(
                  cotizacion.numero,
                  style: const TextStyle(
                    color: AppTheme.secondaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (cotizacion.quoteStatus != null &&
                    cotizacion.quoteStatus!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cotizacion.quoteStatus!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              cotizacion.tipoServicio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${currencyFormat.format(cotizacion.total)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'ver') {
              onTap();
            } else if (value == 'editar') {
              onEdit();
            } else if (value == 'duplicar') {
              onDuplicate?.call();
            } else if (value == 'version') {
              onNewVersion?.call();
            } else if (value == 'archivar') {
              onArchive?.call();
            } else if (value == 'ocultar') {
              onHide?.call();
            } else if (value == 'eliminar') {
              onDelete();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'ver',
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Ver PDF'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            if (onDuplicate != null)
              const PopupMenuItem(
                value: 'duplicar',
                child: Row(
                  children: [
                    Icon(Icons.copy_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Duplicar'),
                  ],
                ),
              ),
            if (onNewVersion != null)
              const PopupMenuItem(
                value: 'version',
                child: Row(
                  children: [
                    Icon(Icons.history_edu_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Nueva versión'),
                  ],
                ),
              ),
            if (onArchive != null)
              const PopupMenuItem(
                value: 'archivar',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Archivar'),
                  ],
                ),
              ),
            if (onHide != null)
              const PopupMenuItem(
                value: 'ocultar',
                child: Row(
                  children: [
                    Icon(Icons.visibility_off_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Ocultar de recientes'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'eliminar',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
