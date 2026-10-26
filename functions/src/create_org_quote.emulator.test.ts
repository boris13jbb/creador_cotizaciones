/**
 * Integración contra Firestore Emulator (transacciones reales).
 *
 * Ejecutar:
 *   firebase emulators:exec --only firestore --project cotiapp-rules-test ^
 *     "npm --prefix functions run test:emulator"
 *
 * Sin FIRESTORE_EMULATOR_HOST los tests se omiten (no fallan).
 */
import assert from "node:assert/strict";
import {describe, it, before, after, beforeEach} from "node:test";
import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";
import {executeCreateOrgQuote} from "./create_org_quote_core";
import {FREE_MAX_QUOTES} from "./entitlements_policy";

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const run = emulatorHost ? describe : describe.skip;

function nowIso(): string {
  return new Date().toISOString();
}

function quotePayload(id: string, orgId: string): Record<string, unknown> {
  return {
    id,
    organizationId: orgId,
    number: "LOCAL-TEST",
    sequence: 0,
    status: "draft",
    clientName: "Cliente",
    issueDate: nowIso(),
    currency: "USD",
    items: [],
    totalCents: 1000,
    createdByUid: "owner1",
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };
}

run("createOrgQuote emulator (Firestore transactions)", () => {
  let db: FirebaseFirestore.Firestore;

  before(() => {
    if (admin.apps.length === 0) {
      admin.initializeApp({projectId: "cotiapp-rules-test"});
    }
    db = admin.firestore();
  });

  after(async () => {
    // No deleteApp: otros tests del mismo proceso pueden reusar.
  });

  beforeEach(async () => {
    // Limpieza acotada del org de prueba.
    const orgId = "org-free-limit";
    const quotes = await db.collection(`organizations/${orgId}/quotes`).get();
    const batch = db.batch();
    for (const d of quotes.docs) batch.delete(d.ref);
    batch.delete(db.doc(`organizations/${orgId}/counters/quotes`));
    batch.delete(db.doc(`organizations/${orgId}/members/owner1`));
    batch.delete(db.doc(`organizations/${orgId}/members/outsider`));
    batch.delete(db.doc(`organizations/${orgId}`));
    batch.delete(db.doc("entitlements/owner1"));
    await batch.commit().catch(() => undefined);

    await db.doc(`organizations/${orgId}`).set({
      id: orgId,
      name: "Free Org",
      ownerUid: "owner1",
      quotePrefix: "COT",
      currency: "USD",
      createdAt: nowIso(),
      updatedAt: nowIso(),
    });
    await db.doc(`organizations/${orgId}/members/owner1`).set({
      organizationId: orgId,
      uid: "owner1",
      role: "owner",
      status: "active",
      createdAt: nowIso(),
      updatedAt: nowIso(),
    });
    await db.doc("entitlements/owner1").set({
      uid: "owner1",
      plan: "free",
      subscriptionStatus: "active",
      source: "signup",
      createdAt: nowIso(),
      updatedAt: nowIso(),
    });
    await db.doc(`organizations/${orgId}/counters/quotes`).set({
      seq: 0,
      updatedAt: nowIso(),
    });
  });

  it("permite 5 creaciones Free y rechaza la 6.ª", async () => {
    const orgId = "org-free-limit";
    for (let i = 1; i <= FREE_MAX_QUOTES; i++) {
      const id = `q${i}`;
      const r = await executeCreateOrgQuote(db, {
        uid: "owner1",
        orgId,
        quoteId: id,
        quotePayload: quotePayload(id, orgId),
      });
      assert.equal(r.ok, true);
      assert.equal(r.alreadyExists, false);
      assert.ok(r.number && !String(r.number).startsWith("LOCAL-"));
    }
    await assert.rejects(
      () =>
        executeCreateOrgQuote(db, {
          uid: "owner1",
          orgId,
          quoteId: "q6",
          quotePayload: quotePayload("q6", orgId),
        }),
      (e: unknown) =>
        e instanceof HttpsError && e.code === "resource-exhausted",
    );
    const snap = await db.collection(`organizations/${orgId}/quotes`).get();
    assert.equal(snap.size, FREE_MAX_QUOTES);
  });

  it("concurrencia: un solo cupo → solo una de dos creaciones paralelas gana", async () => {
    const orgId = "org-free-limit";
    for (let i = 1; i <= FREE_MAX_QUOTES - 1; i++) {
      const id = `pre${i}`;
      await executeCreateOrgQuote(db, {
        uid: "owner1",
        orgId,
        quoteId: id,
        quotePayload: quotePayload(id, orgId),
      });
    }

    const results = await Promise.allSettled([
      executeCreateOrgQuote(db, {
        uid: "owner1",
        orgId,
        quoteId: "race-a",
        quotePayload: quotePayload("race-a", orgId),
      }),
      executeCreateOrgQuote(db, {
        uid: "owner1",
        orgId,
        quoteId: "race-b",
        quotePayload: quotePayload("race-b", orgId),
      }),
    ]);

    const fulfilled = results.filter((r) => r.status === "fulfilled");
    const rejected = results.filter((r) => r.status === "rejected");
    assert.equal(fulfilled.length, 1);
    assert.equal(rejected.length, 1);
    const err = (rejected[0] as PromiseRejectedResult).reason;
    assert.ok(err instanceof HttpsError && err.code === "resource-exhausted");

    const snap = await db.collection(`organizations/${orgId}/quotes`).get();
    assert.equal(snap.size, FREE_MAX_QUOTES);

    const counter = await db.doc(`organizations/${orgId}/counters/quotes`).get();
    // Numeración: 4 previas + 1 ganadora = seq 5 (no 6 por el rechazo).
    assert.equal(Number(counter.data()?.seq || 0), FREE_MAX_QUOTES);
  });

  it("reintento con mismo quoteId es idempotente y no consume cupo extra", async () => {
    const orgId = "org-free-limit";
    const first = await executeCreateOrgQuote(db, {
      uid: "owner1",
      orgId,
      quoteId: "same-id",
      quotePayload: quotePayload("same-id", orgId),
    });
    const second = await executeCreateOrgQuote(db, {
      uid: "owner1",
      orgId,
      quoteId: "same-id",
      quotePayload: quotePayload("same-id", orgId),
    });
    assert.equal(first.alreadyExists, false);
    assert.equal(second.alreadyExists, true);
    assert.equal(first.number, second.quote.number);
    const snap = await db.collection(`organizations/${orgId}/quotes`).get();
    assert.equal(snap.size, 1);
    const counter = await db.doc(`organizations/${orgId}/counters/quotes`).get();
    assert.equal(Number(counter.data()?.seq || 0), 1);
  });

  it("usuario ajeno no puede crear", async () => {
    const orgId = "org-free-limit";
    await assert.rejects(
      () =>
        executeCreateOrgQuote(db, {
          uid: "outsider",
          orgId,
          quoteId: "x1",
          quotePayload: quotePayload("x1", orgId),
        }),
      (e: unknown) =>
        e instanceof HttpsError && e.code === "permission-denied",
    );
  });

  it("con cupo lleno, update de existente no pasa por createOrgQuote (doc ya existe)", async () => {
    const orgId = "org-free-limit";
    for (let i = 1; i <= FREE_MAX_QUOTES; i++) {
      const id = `full${i}`;
      await executeCreateOrgQuote(db, {
        uid: "owner1",
        orgId,
        quoteId: id,
        quotePayload: quotePayload(id, orgId),
      });
    }
    // Idempotencia = camino de "ya existe" (equivalente a no bloquear edición).
    const again = await executeCreateOrgQuote(db, {
      uid: "owner1",
      orgId,
      quoteId: "full1",
      quotePayload: {
        ...quotePayload("full1", orgId),
        clientName: "Actualizado",
      },
    });
    assert.equal(again.alreadyExists, true);
    // El núcleo no reescribe en alreadyExists; la edición real es update cliente.
    const doc = await db.doc(`organizations/${orgId}/quotes/full1`).get();
    assert.equal(doc.data()?.clientName, "Cliente");
  });
});
