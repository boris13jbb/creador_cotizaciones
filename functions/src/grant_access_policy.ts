/**
 * Política de ventana temporal para admin_grant (CotiApp).
 * Semántica: grantStartsAt <= now < grantExpiresAt
 */

export type ParsedInstant =
  | {kind: "absent"}
  | {kind: "invalid"}
  | {kind: "ok"; ms: number};

export function parseGrantInstant(value: unknown): ParsedInstant {
  if (value === undefined || value === null) return {kind: "absent"};
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return {kind: "invalid"};
    const ms = Date.parse(trimmed);
    return Number.isFinite(ms) ? {kind: "ok", ms} : {kind: "invalid"};
  }
  if (value instanceof Date) {
    const ms = value.getTime();
    return Number.isFinite(ms) ? {kind: "ok", ms} : {kind: "invalid"};
  }
  if (typeof value === "object") {
    const o = value as Record<string, unknown>;
    const seconds =
      typeof o.seconds === "number"
        ? o.seconds
        : typeof o._seconds === "number"
          ? o._seconds
          : null;
    const nanos =
      typeof o.nanoseconds === "number"
        ? o.nanoseconds
        : typeof o._nanoseconds === "number"
          ? o._nanoseconds
          : 0;
    if (seconds !== null) {
      const ms = seconds * 1000 + Math.floor(nanos / 1e6);
      return Number.isFinite(ms) ? {kind: "ok", ms} : {kind: "invalid"};
    }
  }
  return {kind: "invalid"};
}

function firstInstant(...values: unknown[]): ParsedInstant {
  let sawInvalid = false;
  for (const v of values) {
    if (v === undefined) continue;
    const p = parseGrantInstant(v);
    if (p.kind === "absent") continue;
    if (p.kind === "invalid") {
      sawInvalid = true;
      continue;
    }
    return p;
  }
  return sawInvalid ? {kind: "invalid"} : {kind: "absent"};
}

export function isTemporalAdminGrant(data: {
  grantModality?: string | null;
  grantStartsAt?: unknown;
  grantExpiresAt?: unknown;
  grantStartsAtTs?: unknown;
  grantExpiresAtTs?: unknown;
}): boolean {
  if (data.grantModality === "temporary") return true;
  const start = firstInstant(data.grantStartsAtTs, data.grantStartsAt);
  const end = firstInstant(data.grantExpiresAtTs, data.grantExpiresAt);
  return start.kind !== "absent" || end.kind !== "absent";
}

/** ¿admin_grant autoriza privilegios de pago en `now`? */
export function isAdminGrantActiveInWindow(
  data: {
    source?: string | null;
    plan?: string | null;
    subscriptionStatus?: string | null;
    grantModality?: string | null;
    grantStartsAt?: unknown;
    grantExpiresAt?: unknown;
    grantStartsAtTs?: unknown;
    grantExpiresAtTs?: unknown;
  } | null | undefined,
  now: Date = new Date(),
): boolean {
  if (!data) return false;
  if (String(data.source || "") !== "admin_grant") return false;
  const status = String(data.subscriptionStatus || "").toLowerCase();
  if (status !== "active") return false;
  const plan = String(data.plan || "").toLowerCase();
  if (plan !== "pro" && plan !== "business") return false;

  const nowMs = now.getTime();
  const start = firstInstant(data.grantStartsAtTs, data.grantStartsAt);
  const end = firstInstant(data.grantExpiresAtTs, data.grantExpiresAt);
  const temporal = isTemporalAdminGrant(data);

  if (!temporal) return true;
  if (start.kind === "invalid" || end.kind === "invalid") return false;
  if (end.kind === "absent") return false;
  if (start.kind === "ok" && nowMs < start.ms) return false;
  if (nowMs >= end.ms) return false;
  return true;
}
