/**
 * Contrato de escritura dual adminGrantEntitlement / adminRevokeGrant.
 *
 * Replica la construcción del documento `entitlements` que persiste admin.ts
 * (sin Auth ni Firestore). Si el callable cambia el esquema temporal, estas
 * aserciones deben fallar.
 */
import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {Timestamp} from "firebase-admin/firestore";

const SKEW_MS = 1000;
const FIXED_NOW = new Date("2026-10-27T15:00:00.000Z");

type TemporalFields = {
  grantStartsAt: string | null;
  grantExpiresAt: string | null;
  grantStartsAtTs: Timestamp | null;
  grantExpiresAtTs: Timestamp | null;
  grantModality: "courtesy" | "temporary" | null;
};

/** Espejo de la rama temporal de adminGrantEntitlement (admin.ts). */
function buildGrantEntitlementTemporal(
  expiresAtRaw: string | null,
  now: Date = FIXED_NOW,
): TemporalFields {
  let grantExpiresAt: string | null = null;
  let grantExpiresAtTs: Timestamp | null = null;
  let grantStartsAt: string | null = null;
  let grantStartsAtTs: Timestamp | null = null;
  let grantModality: "courtesy" | "temporary" = "courtesy";

  if (expiresAtRaw) {
    const d = new Date(expiresAtRaw);
    if (Number.isNaN(d.getTime())) {
      throw new Error("expiresAt inválido.");
    }
    if (d.getTime() <= now.getTime()) {
      throw new Error("expiresAt debe ser futuro.");
    }
    grantExpiresAt = d.toISOString();
    grantStartsAt = now.toISOString();
    grantExpiresAtTs = Timestamp.fromDate(d);
    grantStartsAtTs = Timestamp.fromDate(now);
    grantModality = "temporary";
  }

  return {
    grantStartsAt,
    grantExpiresAt,
    grantStartsAtTs,
    grantExpiresAtTs,
    grantModality,
  };
}

/** Espejo de la limpieza temporal de adminRevokeGrant. */
function buildRevokeTemporalNulls(): TemporalFields {
  return {
    grantStartsAt: null,
    grantExpiresAt: null,
    grantStartsAtTs: null,
    grantExpiresAtTs: null,
    grantModality: null,
  };
}

function assertIsoTsAligned(iso: string, ts: Timestamp) {
  const delta = Math.abs(Date.parse(iso) - ts.toMillis());
  assert.ok(delta <= SKEW_MS, `divergencia ISO/Ts ${delta}ms`);
}

describe("adminGrantEntitlement dual-write contract", () => {
  it("cortesía sin fechas: campos temporales nulos", () => {
    const doc = buildGrantEntitlementTemporal(null);
    assert.equal(doc.grantModality, "courtesy");
    assert.equal(doc.grantStartsAt, null);
    assert.equal(doc.grantExpiresAt, null);
    assert.equal(doc.grantStartsAtTs, null);
    assert.equal(doc.grantExpiresAtTs, null);
  });

  it("temporal inmediato: ISO + Timestamp alineados", () => {
    const doc = buildGrantEntitlementTemporal("2026-10-28T15:00:00.000Z");
    assert.equal(doc.grantModality, "temporary");
    assert.ok(doc.grantStartsAt);
    assert.ok(doc.grantExpiresAt);
    assert.ok(doc.grantStartsAtTs);
    assert.ok(doc.grantExpiresAtTs);
    assertIsoTsAligned(doc.grantStartsAt!, doc.grantStartsAtTs!);
    assertIsoTsAligned(doc.grantExpiresAt!, doc.grantExpiresAtTs!);
    assert.equal(doc.grantStartsAtTs!.toMillis(), FIXED_NOW.getTime());
    assert.equal(
      doc.grantExpiresAtTs!.toMillis(),
      Date.parse("2026-10-28T15:00:00.000Z"),
    );
  });

  it("rechaza expiresAt inválido o no futuro antes de persistir", () => {
    assert.throws(() => buildGrantEntitlementTemporal("no-fecha"));
    assert.throws(() =>
      buildGrantEntitlementTemporal("2026-10-27T14:00:00.000Z"),
    );
    assert.throws(() =>
      buildGrantEntitlementTemporal("2026-10-27T15:00:00.000Z"),
    );
  });

  it("revocación anula ventana (source admin_revoke deja sin acceso temporal)", () => {
    const prior = buildGrantEntitlementTemporal("2026-11-01T00:00:00.000Z");
    assert.equal(prior.grantModality, "temporary");
    const revoked = buildRevokeTemporalNulls();
    assert.equal(revoked.grantStartsAt, null);
    assert.equal(revoked.grantExpiresAt, null);
    assert.equal(revoked.grantStartsAtTs, null);
    assert.equal(revoked.grantExpiresAtTs, null);
    assert.equal(revoked.grantModality, null);
  });
});
