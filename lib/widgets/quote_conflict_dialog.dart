import 'package:flutter/material.dart';

import '../saas/services/cloud_cotizacion_repository.dart';

/// Diálogo explícito para resolver conflicto local vs remoto.
Future<bool?> showQuoteConflictDialog(
  BuildContext context, {
  required String quoteId,
  required String quoteNumber,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Conflicto de sincronización'),
      content: Text(
        'La cotización $quoteNumber tiene cambios distintos en este dispositivo '
        'y en la nube. Elige qué versión conservar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await CloudCotizacionRepository.instance.resolveQuoteConflict(
                quoteId: quoteId,
                keepLocal: false,
              );
              if (ctx.mounted) Navigator.pop(ctx, false);
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('$e'.replaceFirst('Exception: ', '')),
                  ),
                );
              }
            }
          },
          child: const Text('Usar versión en la nube'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await CloudCotizacionRepository.instance.resolveQuoteConflict(
                quoteId: quoteId,
                keepLocal: true,
              );
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('$e'.replaceFirst('Exception: ', '')),
                  ),
                );
              }
            }
          },
          child: const Text('Conservar este dispositivo'),
        ),
      ],
    ),
  );
}
