import '../config/saas_config.dart';

/// Entitlements de servidor en `entitlements/{uid}`.
/// Escritura exclusiva de Admin SDK / Cloud Functions (salvo bootstrap inicial permitido por reglas).
class Entitlements {
  final String uid;
  final SubscriptionPlan plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Entitlements({
    required this.uid,
    required this.plan,
    required this.subscriptionStatus,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.source = 'signup',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Entitlements.initialTrial(String uid, {DateTime? now}) {
    final n = now ?? DateTime.now().toUtc();
    return Entitlements(
      uid: uid,
      plan: SubscriptionPlan.free,
      subscriptionStatus: 'trialing',
      trialEndsAt: n.add(const Duration(days: SaasConfig.trialDays)),
      source: 'signup',
      createdAt: n,
      updatedAt: n,
    );
  }

  factory Entitlements.fromLegacyProfile({
    required String uid,
    required SubscriptionPlan plan,
    required String subscriptionStatus,
    DateTime? trialEndsAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Entitlements(
      uid: uid,
      plan: plan,
      subscriptionStatus: subscriptionStatus,
      trialEndsAt: trialEndsAt,
      source: 'legacy',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'plan': plan.id,
      'subscriptionStatus': subscriptionStatus,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    if (trialEndsAt != null) {
      map['trialEndsAt'] = trialEndsAt!.toIso8601String();
    }
    if (currentPeriodEnd != null) {
      map['currentPeriodEnd'] = currentPeriodEnd!.toIso8601String();
    }
    if (stripeCustomerId != null) {
      map['stripeCustomerId'] = stripeCustomerId;
    }
    if (stripeSubscriptionId != null) {
      map['stripeSubscriptionId'] = stripeSubscriptionId;
    }
    return map;
  }

  factory Entitlements.fromMap(Map<String, dynamic> map) {
    return Entitlements(
      uid: map['uid'] as String? ?? '',
      plan: SubscriptionPlan.fromId(map['plan'] as String?),
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'active',
      trialEndsAt: _parseDate(map['trialEndsAt']),
      currentPeriodEnd: _parseDate(map['currentPeriodEnd']),
      stripeCustomerId: map['stripeCustomerId'] as String?,
      stripeSubscriptionId: map['stripeSubscriptionId'] as String?,
      source: map['source'] as String? ?? 'signup',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

/// Resultado evaluado de permisos (única fuente de verdad para la UI y casos de uso).
class EffectiveAccess {
  final SubscriptionPlan effectivePlan;
  final bool isPro;
  final bool canExportDocx;
  final bool canCustomBranding;
  final bool canManageTeam;
  final bool canViewReports;
  final bool canExportReportsCsv;
  final int maxCotizaciones;
  final int maxSeats;
  final bool isTrialing;
  final bool isCanceled;
  final DateTime? trialEndsAt;
  final String subscriptionStatus;
  final String reason;

  const EffectiveAccess({
    required this.effectivePlan,
    required this.isPro,
    required this.canExportDocx,
    required this.canCustomBranding,
    required this.canManageTeam,
    required this.canViewReports,
    required this.canExportReportsCsv,
    required this.maxCotizaciones,
    required this.maxSeats,
    required this.isTrialing,
    required this.isCanceled,
    required this.trialEndsAt,
    required this.subscriptionStatus,
    required this.reason,
  });

  factory EffectiveAccess.free({String reason = 'free'}) {
    return EffectiveAccess(
      effectivePlan: SubscriptionPlan.free,
      isPro: false,
      canExportDocx: false,
      canCustomBranding: false,
      canManageTeam: false,
      canViewReports: true,
      canExportReportsCsv: false,
      maxCotizaciones: SaasConfig.freeMaxCotizaciones,
      maxSeats: SubscriptionPlan.free.maxSeats,
      isTrialing: false,
      isCanceled: false,
      trialEndsAt: null,
      subscriptionStatus: 'active',
      reason: reason,
    );
  }
}
