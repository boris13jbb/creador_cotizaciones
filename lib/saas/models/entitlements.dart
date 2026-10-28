import '../config/saas_config.dart';

enum GrantInstantKind { absent, invalid, ok }

class GrantInstant {
  const GrantInstant._(this.kind, this.value);
  const GrantInstant.absent() : this._(GrantInstantKind.absent, null);
  const GrantInstant.invalid() : this._(GrantInstantKind.invalid, null);
  GrantInstant.ok(DateTime value) : this._(GrantInstantKind.ok, value.toUtc());

  final GrantInstantKind kind;
  final DateTime? value;
}

GrantInstant parseGrantInstant(dynamic value) {
  if (value == null) return const GrantInstant.absent();
  if (value is DateTime) return GrantInstant.ok(value);
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty) return const GrantInstant.invalid();
    final p = DateTime.tryParse(t);
    return p == null ? const GrantInstant.invalid() : GrantInstant.ok(p);
  }
  try {
    final dynamic maybe = value;
    if (maybe.toDate is Function) {
      return GrantInstant.ok(maybe.toDate() as DateTime);
    }
  } catch (_) {
    return const GrantInstant.invalid();
  }
  return const GrantInstant.invalid();
}

/// Entitlements de servidor en `entitlements/{uid}`.
/// Escritura exclusiva de Admin SDK / Cloud Functions.
class Entitlements {
  final String uid;
  final SubscriptionPlan plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String source;
  final DateTime? grantStartsAt;
  final DateTime? grantExpiresAt;
  final String? grantModality;
  final String? grantReason;
  final String? grantedByUid;
  final String? grantId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool grantWindowInvalid;

  const Entitlements({
    required this.uid,
    required this.plan,
    required this.subscriptionStatus,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.source = 'signup',
    this.grantStartsAt,
    this.grantExpiresAt,
    this.grantModality,
    this.grantReason,
    this.grantedByUid,
    this.grantId,
    required this.createdAt,
    required this.updatedAt,
    this.grantWindowInvalid = false,
  });

  bool get isAdminGrant => source == 'admin_grant';

  bool get hasTemporalSignal {
    if (grantModality == 'temporary') return true;
    if (grantStartsAt != null || grantExpiresAt != null) return true;
    if (grantWindowInvalid) return true;
    return false;
  }

  /// Ventana: grantStartsAt <= now < grantExpiresAt
  bool isAdminGrantActiveInWindow({DateTime? now}) {
    if (!isAdminGrant) return false;
    if (subscriptionStatus.toLowerCase() != 'active') return false;
    if (plan != SubscriptionPlan.pro && plan != SubscriptionPlan.business) {
      return false;
    }
    final n = (now ?? DateTime.now()).toUtc();
    if (!hasTemporalSignal) return true;
    if (grantWindowInvalid) return false;
    if (grantExpiresAt == null) return false;
    if (grantStartsAt != null && n.isBefore(grantStartsAt!.toUtc())) {
      return false;
    }
    if (!n.isBefore(grantExpiresAt!.toUtc())) return false;
    return true;
  }

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
    if (grantStartsAt != null) {
      map['grantStartsAt'] = grantStartsAt!.toIso8601String();
    }
    if (grantExpiresAt != null) {
      map['grantExpiresAt'] = grantExpiresAt!.toIso8601String();
    }
    if (grantModality != null) {
      map['grantModality'] = grantModality;
    }
    if (grantReason != null) {
      map['grantReason'] = grantReason;
    }
    if (grantedByUid != null) {
      map['grantedByUid'] = grantedByUid;
    }
    if (grantId != null) {
      map['grantId'] = grantId;
    }
    return map;
  }

  factory Entitlements.fromMap(Map<String, dynamic> map) {
    final start = _prefer(map['grantStartsAtTs'], map['grantStartsAt']);
    final end = _prefer(map['grantExpiresAtTs'], map['grantExpiresAt']);
    final modality = map['grantModality'] as String?;
    final temporal = modality == 'temporary' ||
        start.kind != GrantInstantKind.absent ||
        end.kind != GrantInstantKind.absent;
    final invalid = temporal &&
        (start.kind == GrantInstantKind.invalid ||
            end.kind == GrantInstantKind.invalid ||
            end.kind == GrantInstantKind.absent);

    return Entitlements(
      uid: map['uid'] as String? ?? '',
      plan: SubscriptionPlan.fromId(map['plan'] as String?),
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'active',
      trialEndsAt: parseGrantInstant(map['trialEndsAt']).value,
      currentPeriodEnd: parseGrantInstant(map['currentPeriodEnd']).value,
      stripeCustomerId: map['stripeCustomerId'] as String?,
      stripeSubscriptionId: map['stripeSubscriptionId'] as String?,
      source: map['source'] as String? ?? 'signup',
      grantStartsAt: start.value,
      grantExpiresAt: end.value,
      grantModality: modality,
      grantReason: map['grantReason'] as String?,
      grantedByUid: map['grantedByUid'] as String?,
      grantId: map['grantId'] as String?,
      createdAt: parseGrantInstant(map['createdAt']).value ??
          DateTime.now().toUtc(),
      updatedAt: parseGrantInstant(map['updatedAt']).value ??
          DateTime.now().toUtc(),
      grantWindowInvalid: invalid,
    );
  }

  static GrantInstant _prefer(dynamic a, dynamic b) {
    final first = parseGrantInstant(a);
    if (first.kind != GrantInstantKind.absent) return first;
    return parseGrantInstant(b);
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
