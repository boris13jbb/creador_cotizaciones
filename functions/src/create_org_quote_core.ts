import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {EntitlementsLike, PAID_MAX_QUOTES, resolveMaxQuotes} from "./entitlements_policy";
import {
  decideQuoteCreateLimit,
  isCommercialRole,
  quoteLimitMessage,
} from "./quote_limit";

function nowIso(): string {
  return new Date().toISOString();
}

export type CreateOrgQuoteInput = {
  uid: string;
  orgId: string;
  quoteId: string;
  quotePayload: Record<string, unknown>;
};

export type CreateOrgQuoteResult = {
  ok: true;
  alreadyExists: boolean;
  quote: Record<string, unknown>;
  organizationId: string;
  quoteId: string;
  sequence?: number;
  number?: string;
};

/**
 * Núcleo transaccional de createOrgQuote (testeable contra Firestore Emulator).
 */
export async function executeCreateOrgQuote(
  db: Firestore,
  input: CreateOrgQuoteInput,
): Promise<CreateOrgQuoteResult> {
  const {uid, orgId, quoteId, quotePayload} = input;
  const orgRef = db.collection("organizations").doc(orgId);
  const memberRef = orgRef.collection("members").doc(uid);
  const quoteRef = orgRef.collection("quotes").doc(quoteId);
  const counterRef = orgRef.collection("counters").doc("quotes");

  return db.runTransaction(async (tx) => {
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

    if (quoteSnap.exists) {
      return {
        ok: true as const,
        alreadyExists: true,
        quote: (quoteSnap.data() || {}) as Record<string, unknown>,
        organizationId: orgId,
        quoteId,
      };
    }

    const entSnap = await tx.get(db.collection("entitlements").doc(ownerUid));
    const entitlements = (entSnap.data() || null) as EntitlementsLike | null;
    const maxQuotes = resolveMaxQuotes(entitlements);

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
      tx.set(counterRef, {seq: sequence, updatedAt: now}, {merge: true});
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
      alreadyExists: false,
      quote: quoteDoc,
      organizationId: orgId,
      quoteId,
      sequence,
      number,
    };
  });
}
