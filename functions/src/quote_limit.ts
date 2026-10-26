import {PAID_MAX_QUOTES, resolveMaxQuotes, EntitlementsLike} from "./entitlements_policy";

/** Roles que pueden crear cotizaciones (espejo firestore.rules canWriteCommercial). */
export const QUOTE_WRITE_ROLES = new Set(["owner", "admin", "sales"]);

export type QuoteLimitDecision =
  | {ok: true; alreadyExists: true}
  | {ok: true; alreadyExists: false}
  | {ok: false; code: "resource-exhausted"; maxQuotes: number; currentCount: number};

/**
 * Decisión pura de límite de creación (sin I/O).
 * - Idempotencia: si el id ya existe, siempre ok (no consume cupo extra).
 * - Planes sin tope práctico (PAID_MAX_QUOTES): siempre ok.
 * - Free / restringido: rechaza si currentCount >= maxQuotes.
 */
export function decideQuoteCreateLimit(input: {
  quoteId: string;
  existingQuoteIds: Iterable<string>;
  entitlements: EntitlementsLike | null | undefined;
  now?: Date;
}): QuoteLimitDecision {
  const ids = new Set(
    [...input.existingQuoteIds].map((id) => String(id || "").trim()).filter(Boolean),
  );
  const quoteId = String(input.quoteId || "").trim();
  if (quoteId && ids.has(quoteId)) {
    return {ok: true, alreadyExists: true};
  }

  const maxQuotes = resolveMaxQuotes(input.entitlements, input.now);
  if (maxQuotes >= PAID_MAX_QUOTES) {
    return {ok: true, alreadyExists: false};
  }

  const currentCount = ids.size;
  if (currentCount >= maxQuotes) {
    return {
      ok: false,
      code: "resource-exhausted",
      maxQuotes,
      currentCount,
    };
  }
  return {ok: true, alreadyExists: false};
}

/** Mensaje estable para cliente Flutter / sync offline. */
export function quoteLimitMessage(maxQuotes: number): string {
  return (
    `Límite del plan Free: máximo ${maxQuotes} cotizaciones. ` +
    "Actualiza a Pro para continuar."
  );
}

export function isCommercialRole(role: unknown): boolean {
  return QUOTE_WRITE_ROLES.has(String(role || "").toLowerCase());
}
