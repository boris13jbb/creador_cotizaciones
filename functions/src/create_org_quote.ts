import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {ensureAdminApp, getDb} from "./firebase_admin";
import {executeCreateOrgQuote} from "./create_org_quote_core";

function asRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

/** Extrae código Admin/Firestore seguro (sin tokens ni payloads). */
export function extractSafeErrorCode(error: unknown): string {
  if (!error || typeof error !== "object") return "";
  const e = error as {
    code?: unknown;
    errorInfo?: {code?: unknown};
    name?: unknown;
  };
  const raw = e.errorInfo?.code ?? e.code ?? "";
  const code = String(raw || "").trim().slice(0, 80);
  if (code) return code;
  const name = String(e.name || "");
  if (name === "FirebaseAppError" || name === "FirebaseError") {
    return name;
  }
  return "";
}

/**
 * Crea una cotización de organización con límite autoritativo.
 *
 * Atomicidad / idempotencia: ver `executeCreateOrgQuote` en create_org_quote_core.ts.
 */
export const createOrgQuote = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión");
  }
  const uid = request.auth.uid;
  const data = asRecord(request.data);
  const orgId = String(data.organizationId || "").trim();
  const quotePayload = asRecord(data.quote);
  const quoteId = String(
    data.quoteId || quotePayload.id || "",
  ).trim();

  if (!orgId) {
    throw new HttpsError("invalid-argument", "organizationId requerido");
  }
  if (!quoteId) {
    throw new HttpsError("invalid-argument", "quoteId / quote.id requerido");
  }
  if (String(quotePayload.organizationId || orgId) !== orgId) {
    throw new HttpsError(
      "invalid-argument",
      "organizationId de la cotización no coincide",
    );
  }

  try {
    // App concreta primero; getDb(app) evita getFirestore() ciego → app/no-app.
    const app = ensureAdminApp();
    const db = getDb();
    logger.info("createOrgQuote_admin_ready", {
      appName: app.name,
      // No loguear uid completo en claro si se prefiere redactar; se usa para
      // correlación de miembro/org ya autenticado por callable.
      hasUid: Boolean(uid),
      orgIdLength: orgId.length,
      quoteIdLength: quoteId.length,
    });

    const result = await executeCreateOrgQuote(db, {
      uid,
      orgId,
      quoteId,
      quotePayload,
    });
    logger.info("createOrgQuote", {
      orgId,
      quoteId,
      alreadyExists: result.alreadyExists,
      number: result.number,
    });
    return result;
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    const code = extractSafeErrorCode(e);
    // Campos planos (no anidar `message` como Error): el logger de FF
    // sobrescribe `message` si el primer arg parece Error.
    logger.error("createOrgQuote_failed", {
      code: code || "unknown",
      errMessage: e instanceof Error ? e.message.slice(0, 200) : "non-error",
    });
    const detail = code ? ` (${code})` : "";
    throw new HttpsError(
      "internal",
      `No se pudo crear la cotización${detail}`,
    );
  }
});
