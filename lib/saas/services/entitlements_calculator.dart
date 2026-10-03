import '../config/saas_config.dart';
import '../models/entitlements.dart';

/// Única fuente de cálculo de permisos a partir de plan, estado, trial y fechas.
class EntitlementsService {
  EntitlementsService._();
  static final EntitlementsService instance = EntitlementsService._();

  EffectiveAccess _fromPlan(
    SubscriptionPlan plan, {
    required bool isPro,
    required bool isTrialing,
    required bool isCanceled,
    required DateTime? trialEndsAt,
    required String subscriptionStatus,
    required String reason,
  }) {
    return EffectiveAccess(
      effectivePlan: plan,
      isPro: isPro,
      canExportDocx: plan.canExportDocx,
      canCustomBranding: plan.canCustomBranding,
      canManageTeam: plan.canManageTeam,
      canViewReports: plan.canViewReports,
      canExportReportsCsv: plan.canExportReportsCsv,
      maxCotizaciones: plan.maxCotizaciones,
      maxSeats: plan.maxSeats,
      isTrialing: isTrialing,
      isCanceled: isCanceled,
      trialEndsAt: trialEndsAt,
      subscriptionStatus: subscriptionStatus,
      reason: reason,
    );
  }

  EffectiveAccess evaluate(Entitlements? entitlements, {DateTime? now}) {
    if (entitlements == null) {
      return EffectiveAccess.free(reason: 'sin_entitlements');
    }

    final n = (now ?? DateTime.now()).toUtc();
    final status = entitlements.subscriptionStatus.toLowerCase();

    // Acceso gratis otorgado por super admin (pro/business) con expiración opcional.
    if (entitlements.isAdminGrant && status == 'active') {
      final expired =
          entitlements.grantExpiresAt != null &&
          !entitlements.grantExpiresAt!.isAfter(n);
      if (!expired &&
          (entitlements.plan == SubscriptionPlan.pro ||
              entitlements.plan == SubscriptionPlan.business)) {
        return _fromPlan(
          entitlements.plan,
          isPro: true,
          isTrialing: false,
          isCanceled: false,
          trialEndsAt: entitlements.grantExpiresAt,
          subscriptionStatus: status,
          reason: 'admin_grant',
        );
      }
      if (expired) {
        return EffectiveAccess.free(reason: 'admin_grant_expirado');
      }
    }

    // Defensa en profundidad: nunca honrar un trialEndsAt más allá de
    // createdAt + trialDays (+1 día de holgura), aunque el doc esté manipulado.
    final effectiveTrialEnd = _clampedTrialEndsAt(entitlements, n);
    final trialActive =
        status == 'trialing' &&
        effectiveTrialEnd != null &&
        effectiveTrialEnd.isAfter(n);

    if (trialActive) {
      return _fromPlan(
        SubscriptionPlan.pro,
        isPro: true,
        isTrialing: true,
        isCanceled: false,
        trialEndsAt: effectiveTrialEnd,
        subscriptionStatus: status,
        reason: 'trial_activo',
      );
    }

    if (status == 'canceled' || status == 'cancelled') {
      final grace =
          entitlements.currentPeriodEnd != null &&
          entitlements.currentPeriodEnd!.isAfter(n);
      if (grace &&
          (entitlements.plan == SubscriptionPlan.pro ||
              entitlements.plan == SubscriptionPlan.business)) {
        return _fromPlan(
          entitlements.plan,
          isPro: true,
          isTrialing: false,
          isCanceled: true,
          trialEndsAt: entitlements.trialEndsAt,
          subscriptionStatus: status,
          reason: 'cancelado_con_gracia',
        );
      }
      return EffectiveAccess.free(reason: 'cancelado');
    }

    if (status == 'past_due') {
      return EffectiveAccess.free(reason: 'past_due');
    }

    if (status == 'expired' || status == 'inactive') {
      return EffectiveAccess.free(reason: status);
    }

    if (status == 'active' || status == 'trialing') {
      final paidPro =
          entitlements.plan == SubscriptionPlan.pro ||
          entitlements.plan == SubscriptionPlan.business;
      if (status == 'active' && paidPro) {
        return _fromPlan(
          entitlements.plan,
          isPro: true,
          isTrialing: false,
          isCanceled: false,
          trialEndsAt: entitlements.trialEndsAt,
          subscriptionStatus: status,
          reason: 'activo',
        );
      }
    }

    return EffectiveAccess.free(reason: 'plan_free');
  }

  /// Acota [Entitlements.trialEndsAt] a `createdAt + trialDays` (+1d skew).
  DateTime? _clampedTrialEndsAt(Entitlements entitlements, DateTime now) {
    final raw = entitlements.trialEndsAt;
    if (raw == null) return null;
    final maxEnd = entitlements.createdAt.toUtc().add(
      Duration(days: SaasConfig.trialDays + 1),
    );
    final end = raw.toUtc();
    if (end.isAfter(maxEnd)) return maxEnd;
    // Rechazar fechas absurdamente en el pasado relativas a createdAt no es
    // necesario para seguridad; el trial simplemente resulta inactivo.
    return end;
  }
}
