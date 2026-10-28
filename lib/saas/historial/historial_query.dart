import '../../l10n/app_localizations.dart';
import '../../models/cotizacion.dart';
import '../domain/org_enums.dart';

/// Lógica pura de búsqueda/filtros del Historial (testeable sin UI).
class HistorialQuery {
  HistorialQuery._();

  /// Estados ofrecidos en chips (todos los del dominio).
  static const List<QuoteStatus> filterableStatuses = QuoteStatus.values;

  static String statusLabel(QuoteStatus status, AppLocalizations l10n) {
    switch (status) {
      case QuoteStatus.draft:
        return l10n.statusDraft;
      case QuoteStatus.sent:
        return l10n.statusSent;
      case QuoteStatus.viewed:
        return l10n.statusViewed;
      case QuoteStatus.accepted:
        return l10n.statusAccepted;
      case QuoteStatus.rejected:
        return l10n.statusRejected;
      case QuoteStatus.expired:
        return l10n.statusExpired;
      case QuoteStatus.converted:
        return l10n.statusConverted;
      case QuoteStatus.archived:
        return l10n.statusArchived;
    }
  }

  static String statusLabelForId(String? id, AppLocalizations l10n) {
    if (id == null || id.isEmpty) return '';
    return statusLabel(QuoteStatus.fromId(id), l10n);
  }

  /// Búsqueda local case-insensitive sobre campos comerciales visibles.
  static bool matchesSearch(Cotizacion c, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    bool hit(String? v) => (v ?? '').toLowerCase().contains(query);
    return hit(c.numero) ||
        hit(c.cliente) ||
        hit(c.ubicacion) ||
        hit(c.tipoServicio) ||
        hit(c.descripcion) ||
        hit(c.subtitulo) ||
        hit(c.id);
  }

  static List<Cotizacion> applySearch(List<Cotizacion> items, String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return List<Cotizacion>.from(items);
    return items.where((c) => matchesSearch(c, query)).toList();
  }

  /// Reconcilia remoto + local por id estable (misma regla que el repositorio).
  static List<Cotizacion> mergeRemoteAndLocal({
    required List<Cotizacion> remote,
    required List<({Cotizacion cotizacion, String syncStatus})> local,
    String? statusFilter,
  }) {
    final byId = <String, Cotizacion>{for (final c in remote) c.id: c};
    for (final rec in local) {
      final cot = rec.cotizacion;
      final status = cot.quoteStatus;
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          status != statusFilter) {
        continue;
      }
      final pendingLike =
          rec.syncStatus == 'pending' ||
          rec.syncStatus == 'conflict' ||
          rec.syncStatus == 'error';
      if (pendingLike || !byId.containsKey(cot.id)) {
        byId[cot.id] = cot.withOfflineSyncStatus(rec.syncStatus);
      } else {
        byId[cot.id] = byId[cot.id]!.withOfflineSyncStatus('synced');
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return merged;
  }
}
