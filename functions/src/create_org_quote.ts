import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {EntitlementsLike, PAID_MAX_QUOTES, resolveMaxQuotes} from "./entitlements_policy";
import {getDb} from "./firebase_admin";
import {
  decideQuoteCreateLimit,
  isCommercialRole,
  quoteLimitMessage,
} from "./quote_limit";

function nowIso(): string {
  return new Date().toISOString();
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

/**
 * Crea una cotización de organización con límite autoritativo.
 *
 * Atomicidad: transacción Firestore que lee un query acotado de quotes
 * (`limit(max+1)`) + contador de numeración. Si otra creación concurrente
 * altera el conjunto leído, Firestore reintenta la transacción.
 *
 * Idempotencia: si `quotes/{quoteId}` ya existe, devuelve éxito sin
 * incrementar el contador ni consumir cupo.
 *
 * El cliente NO puede enviar plan/max/count confiables: se leen entitlements
 * del owner de la org en el servidor.
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

  const orgRef = getDb().collection("organizations").doc(orgId);
  const memberRef = orgRef.collection("members").doc(uid);
  const quoteRef = orgRef.collection("quotes").doc(quoteId);
  const counterRef = orgRef.collection("counters").doc("quotes");

  try {
    const result = await getDb().runTransaction(async (tx) => {
      // Lecturas secuenciales antes de cualquier escritura (contrato de transacciones).
      const memberSnap = await tx.get(memberRef);
      const orgSnap = await tx.get(orgRef);
      const quoteSnap = await tx.get(quoteRef);
      const counterSnap = await tx.get(counterRef);

      if (!memberSnap.exists) {
        throw new HttpsError("permission-denied", "No eres miembro de la organización");
      }
      const member = memberSnap.data() || {};
      if (String(member.status || "") !== "active") {
        throw new HttpsError("permission-denied", "Membresía inactiva");
      }
      if (!isCommercialRole(member.role)) {
        throw new HttpsError(
          "permission-denied",
          "Tu rol no puede crear cotizaciones",
        );
      }

      if (!orgSnap.exists) {
        throw new HttpsError("not-found", "Organización no encontrada");
      }
      const org = orgSnap.data() || {};
      const ownerUid = String(org.ownerUid || "");
      if (!ownerUid) {
        throw new HttpsError("failed-precondition", "Organización sin owner");
      }

      // Idempotencia: creación ya aplicada (reintento / sync offline).
      if (quoteSnap.exists) {
        return {
          ok: true as const,
          alreadyExists: true as const,
          quote: quoteSnap.data() || {},
          organizationId: orgId,
          quoteId,
        };
      }

      const entSnap = await tx.get(
        getDb().collection("entitlements").doc(ownerUid),
      );
      const entitlements = (entSnap.data() || null) as EntitlementsLike | null;
      const maxQuotes = resolveMaxQuotes(entitlements);

      // Lectura acotada para Free; planes pagos omiten el tope práctico.
      let existingIds: string[] = [];
      if (maxQuotes < PAID_MAX_QUOTES) {
        const limited = await tx.get(
          orgRef.collection("quotes").limit(maxQuotes + 1),
        );
        existingIds = limited.docs.map((d) => d.id);
      }

      const decision = decideQuoteCreateLimit({
        quoteId,
        existingQuoteIds: existingIds,
        entitlements,
      });
      if (!decision.ok) {
        throw new HttpsError(
          "resource-exhausted",
          quoteLimitMessage(decision.maxQuotes),
        );
      }

      const prefix = String(org.quotePrefix || "COT");
      const now = nowIso();
      let sequence = Number(quotePayload.sequence || 0);
      let number = String(quotePayload.number || "");
      const needsNumber =
        !Number.isFinite(sequence) ||
        sequence <= 0 ||
        !number ||
        number.startsWith("LOCAL-");

      if (needsNumber) {
        const current = Number(counterSnap.data()?.seq || 0);
        sequence = current + 1;
        number = `${prefix}-${String(sequence).padStart(3, "0")}`;
        tx.set(
          counterRef,
          {seq: sequence, updatedAt: now},
          {merge: true},
        );
      }

      const quoteDoc: Record<string, unknown> = {
        ...quotePayload,
        id: quoteId,
        organizationId: orgId,
        sequence,
        number,
        createdByUid: String(quotePayload.createdByUid || uid),
        updatedByUid: uid,
        createdAt: String(quotePayload.createdAt || now),
        updatedAt: now,
      };

      tx.set(quoteRef, quoteDoc);

      return {
        ok: true as const,
        alreadyExists: false as const,
        quote: quoteDoc,
        organizationId: orgId,
        quoteId,
        sequence,
        number,
      };
    });

    logger.info("createOrgQuote", {
      orgId,
      quoteId,
      uid,
      alreadyExists: result.alreadyExists,
      number: (result as {number?: string}).number,
    });
    return result;
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error("createOrgQuote_failed", e);
    throw new HttpsError("internal", "No se pudo crear la cotización");
  }
});
