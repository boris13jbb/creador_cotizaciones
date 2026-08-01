import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = admin.firestore();

function nowIso(): string {
  return new Date().toISOString();
}

function toCents(value: unknown): number {
  if (typeof value === "number") return Math.round(value * 100);
  if (typeof value === "string") {
    const n = Number(value);
    return Number.isFinite(n) ? Math.round(n * 100) : 0;
  }
  return 0;
}

/**
 * Migración admin/usuario autenticado: legacy cotizaciones → org quotes.
 * body: { dryRun?: boolean, uid?: string }  (uid solo si caller es admin futuro)
 */
export const migrateUserToOrganization = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }

  const dryRun = request.data?.dryRun !== false && request.data?.apply !== true;
  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const user = userSnap.data() ?? {};

  let orgId = (user.defaultOrganizationId as string) || "";
  const created: string[] = [];
  const skipped: string[] = [];

  if (!orgId) {
    orgId = db.collection("organizations").doc().id;
    if (!dryRun) {
      const now = nowIso();
      await db.collection("organizations").doc(orgId).set({
        id: orgId,
        name: `${user.displayName || "Usuario"} — Empresa`,
        currency: "USD",
        quotePrefix: "COT",
        ownerUid: uid,
        createdAt: now,
        updatedAt: now,
      });
      await db
        .collection("organizations")
        .doc(orgId)
        .collection("members")
        .doc(uid)
        .set({
          organizationId: orgId,
          uid,
          role: "owner",
          status: "active",
          displayName: user.displayName || "",
          email: user.email || "",
          createdAt: now,
          updatedAt: now,
        });
      await db
        .collection("organizations")
        .doc(orgId)
        .collection("counters")
        .doc("quotes")
        .set({ seq: 0, updatedAt: now });
      await userRef.set(
        { defaultOrganizationId: orgId, updatedAt: now },
        { merge: true }
      );
      await userRef.collection("memberships").doc(orgId).set({
        organizationId: orgId,
        uid,
        role: "owner",
        status: "active",
        createdAt: now,
        updatedAt: now,
      });
    }
    created.push(`organization:${orgId}`);
  }

  const legacy = await userRef.collection("cotizaciones").get();
  let seq =
    (
      await db
        .collection("organizations")
        .doc(orgId)
        .collection("counters")
        .doc("quotes")
        .get()
    ).data()?.seq || 0;

  for (const doc of legacy.docs) {
    const data = doc.data();
    const quoteRef = db
      .collection("organizations")
      .doc(orgId)
      .collection("quotes")
      .doc(doc.id);
    const exists = await quoteRef.get();
    if (exists.exists) {
      skipped.push(doc.id);
      continue;
    }
    seq += 1;
    const servicios = (data.servicios as Array<Record<string, unknown>>) || [];
    const items = servicios.map((s, index) => ({
      id: `${doc.id}_${index}`,
      name: String(s.nombre || ""),
      description: String(s.descripcion || ""),
      unit: "und",
      quantityMillis: 1000,
      unitPriceCents: toCents(s.precio),
      discountBps: 0,
      taxBps: 0,
      sortOrder: index,
    }));

    const quote = {
      id: doc.id,
      organizationId: orgId,
      number: String(data.numero || `COT-${String(seq).padStart(3, "0")}`),
      sequence: seq,
      status: "draft",
      clientName: String(data.cliente || ""),
      issueDate: String(data.fecha || nowIso()),
      currency: "USD",
      items,
      globalDiscountBps: 0,
      globalDiscountFixedCents: 0,
      chargesCents: 0,
      totalCents: toCents(data.total),
      includes: String(data.incluye || "")
        .split("|")
        .filter(Boolean),
      excludes: String(data.noIncluye || "")
        .split("|")
        .filter(Boolean),
      notes: String(data.notas || "")
        .split("|")
        .filter(Boolean),
      payments: [],
      logoPath: data.logoPath || null,
      colorsJson: data.coloresJson || null,
      subtitle: data.subtitulo || null,
      footerText: data.footerText || null,
      extraFields: data.camposExtra || null,
      version: 1,
      createdByUid: uid,
      legacyUserPath: `users/${uid}/cotizaciones/${doc.id}`,
      legacyFields: {
        ubicacion: data.ubicacion || "",
        tipoServicio: data.tipoServicio || "",
        cantidadEquipos: data.cantidadEquipos || "",
        tiempoEstimado: data.tiempoEstimado || "",
        descripcion: data.descripcion || "",
        firmaTecnicoLabel: data.firmaTecnicoLabel || null,
        firmaClienteLabel: data.firmaClienteLabel || null,
        validezDias: data.validezDias || null,
      },
      createdAt: nowIso(),
      updatedAt: String(data.updatedAt || nowIso()),
    };

    if (!dryRun) {
      await quoteRef.set(quote);
    }
    created.push(`quote:${doc.id}`);
  }

  if (!dryRun) {
    await db
      .collection("organizations")
      .doc(orgId)
      .collection("counters")
      .doc("quotes")
      .set({ seq, updatedAt: nowIso() }, { merge: true });
  }

  return {
    dryRun,
    uid,
    organizationId: orgId,
    legacyCount: legacy.size,
    created,
    skipped,
  };
});

/** Numeración atómica vía Admin (útil desde REST Windows). */
export const allocateQuoteNumber = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const orgId = String(request.data?.organizationId || "");
  const prefix = String(request.data?.prefix || "COT");
  if (!orgId) {
    throw new HttpsError("invalid-argument", "organizationId requerido");
  }

  const member = await db
    .collection("organizations")
    .doc(orgId)
    .collection("members")
    .doc(request.auth.uid)
    .get();
  if (!member.exists || member.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "No eres miembro activo");
  }

  const counterRef = db
    .collection("organizations")
    .doc(orgId)
    .collection("counters")
    .doc("quotes");

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const current = (snap.data()?.seq as number) || 0;
    const next = current + 1;
    tx.set(
      counterRef,
      { seq: next, updatedAt: nowIso() },
      { merge: true }
    );
    return {
      sequence: next,
      number: `${prefix}-${String(next).padStart(3, "0")}`,
    };
  });

  return result;
});
