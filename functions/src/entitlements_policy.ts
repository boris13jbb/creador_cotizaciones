/** Política de trial y asientos (espejo de SaasConfig / EntitlementsService). */

export const TRIAL_DAYS = 14;
/** Holgura de reloj/red al validar trialEndsAt en bootstrap. */
export const TRIAL_SKEW_DAYS = 1;
export const FREE_MAX_SEATS = 1;
export const PRO_MAX_SEATS = 3;
export const BUSINESS_MAX_SEATS = 10;

export type EntitlementsLike = {
  plan?: string;
  subscriptionStatus?: string;
  trialEndsAt?: string;
  grantExpiresAt?: string;
  currentPeriodEnd?: string;
  source?: string;
  createdAt?: string;
};

/**
 * Acota trialEndsAt a createdAt + TRIAL_DAYS (con skew).
 * Evita trials arbitrariamente largos aunque el documento esté corrupto.
 */
export function clampTrialEndsAt(
  trialEndsAt: string | undefined,
  createdAtIso: string | undefined,
  now: Date = new Date(),
): string {
  const created = createdAtIso ? new Date(createdAtIso) : now;
  const createdMs = Number.isFinite(created.getTime())
    ? created.getTime()
    : now.getTime();
  const maxEnd = new Date(createdMs);
  maxEnd.setUTCDate(maxEnd.getUTCDate() + TRIAL_DAYS);

  const maxWithSkew = new Date(maxEnd.getTime());
  maxWithSkew.setUTCDate(maxWithSkew.getUTCDate() + TRIAL_SKEW_DAYS);

  if (!trialEndsAt) {
    return maxEnd.toISOString();
  }
  const parsed = Date.parse(trialEndsAt);
  if (!Number.isFinite(parsed)) {
    return maxEnd.toISOString();
  }
  if (parsed > maxWithSkew.getTime()) {
    return maxEnd.toISOString();
  }
  return new Date(parsed).toISOString();
}

/** True si el trial de signup está activo (tras clamp). */
export function isTrialActive(
  entitlements: EntitlementsLike | null | undefined,
  now: Date = new Date(),
): boolean {
  if (!entitlements) return false;
  const status = String(entitlements.subscriptionStatus || "").toLowerCase();
  if (status !== "trialing") return false;
  const clamped = clampTrialEndsAt(
    entitlements.trialEndsAt,
    entitlements.createdAt,
    now,
  );
  return Date.parse(clamped) > now.getTime();
}

/**
 * Asientos máximos según entitlements del owner de la org.
 * Free=1, Pro/trial=3, Business=10.
 */
export function resolveMaxSeats(
  entitlements: EntitlementsLike | null | undefined,
  now: Date = new Date(),
): number {
  if (!entitlements) return FREE_MAX_SEATS;

  const status = String(entitlements.subscriptionStatus || "").toLowerCase();
  const plan = String(entitlements.plan || "free").toLowerCase();
  const source = String(entitlements.source || "");

  if (source === "admin_grant" && status === "active") {
    const exp = entitlements.grantExpiresAt
      ? Date.parse(entitlements.grantExpiresAt)
      : NaN;
    const expired = Number.isFinite(exp) && exp <= now.getTime();
    if (!expired) {
      if (plan === "business") return BUSINESS_MAX_SEATS;
      if (plan === "pro") return PRO_MAX_SEATS;
    }
  }

  if (isTrialActive(entitlements, now)) {
    return PRO_MAX_SEATS;
  }

  if (status === "canceled" || status === "cancelled") {
    const grace = entitlements.currentPeriodEnd
      ? Date.parse(String(entitlements.currentPeriodEnd))
      : NaN;
    if (Number.isFinite(grace) && grace > now.getTime()) {
      if (plan === "business") return BUSINESS_MAX_SEATS;
      if (plan === "pro") return PRO_MAX_SEATS;
    }
    return FREE_MAX_SEATS;
  }

  if (status === "past_due" || status === "expired" || status === "inactive") {
    return FREE_MAX_SEATS;
  }

  if (status === "active") {
    if (plan === "business") return BUSINESS_MAX_SEATS;
    if (plan === "pro") return PRO_MAX_SEATS;
  }

  return FREE_MAX_SEATS;
}
