import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getDb} from "./firebase_admin";
import {executeCreateOrgQuote} from "./create_org_quote_core";

function asRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
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
    const result = await executeCreateOrgQuote(getDb(), {
      uid,
      orgId,
      quoteId,
      quotePayload,
    });
    logger.info("createOrgQuote", {
      orgId,
      quoteId,
      uid,
      alreadyExists: result.alreadyExists,
      number: result.number,
    });
    return result;
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error("createOrgQuote_failed", e);
    throw new HttpsError("internal", "No se pudo crear la cotización");
  }
});
