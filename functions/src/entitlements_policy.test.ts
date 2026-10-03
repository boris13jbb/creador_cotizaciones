import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  BUSINESS_MAX_SEATS,
  FREE_MAX_SEATS,
  PRO_MAX_SEATS,
  TRIAL_DAYS,
  clampTrialEndsAt,
  isTrialActive,
  resolveMaxSeats,
} from "./entitlements_policy";

describe("clampTrialEndsAt", () => {
  const created = "2026-01-01T00:00:00.000Z";
  const now = new Date("2026-01-01T12:00:00.000Z");

  it("acepta trial dentro de 14 días", () => {
    const ends = "2026-01-10T00:00:00.000Z";
    assert.equal(clampTrialEndsAt(ends, created, now), ends);
  });

  it("acota trial excesivamente futuro", () => {
    const far = "2030-01-01T00:00:00.000Z";
    const clamped = clampTrialEndsAt(far, created, now);
    const expected = new Date(created);
    expected.setUTCDate(expected.getUTCDate() + TRIAL_DAYS);
    assert.equal(clamped, expected.toISOString());
  });

  it("genera trial por defecto si falta fecha", () => {
    const clamped = clampTrialEndsAt(undefined, created, now);
    const expected = new Date(created);
    expected.setUTCDate(expected.getUTCDate() + TRIAL_DAYS);
    assert.equal(clamped, expected.toISOString());
  });
});

describe("isTrialActive / resolveMaxSeats", () => {
  const now = new Date("2026-01-05T00:00:00.000Z");

  it("trial válido otorga asientos Pro", () => {
    const ent = {
      plan: "free",
      subscriptionStatus: "trialing",
      trialEndsAt: "2026-01-14T00:00:00.000Z",
      createdAt: "2026-01-01T00:00:00.000Z",
      source: "signup",
    };
    assert.equal(isTrialActive(ent, now), true);
    assert.equal(resolveMaxSeats(ent, now), PRO_MAX_SEATS);
  });

  it("trial expirado → Free seats", () => {
    const ent = {
      plan: "free",
      subscriptionStatus: "trialing",
      trialEndsAt: "2026-01-02T00:00:00.000Z",
      createdAt: "2025-12-20T00:00:00.000Z",
      source: "signup",
    };
    assert.equal(isTrialActive(ent, now), false);
    assert.equal(resolveMaxSeats(ent, now), FREE_MAX_SEATS);
  });

  it("trialEndsAt manipulado a 2030 no otorga trial infinito", () => {
    const ent = {
      plan: "free",
      subscriptionStatus: "trialing",
      trialEndsAt: "2030-12-31T00:00:00.000Z",
      createdAt: "2026-01-01T00:00:00.000Z",
      source: "signup",
    };
    // Tras clamp, max = 2026-01-15; now=2026-01-05 → aún activo, pero acotado.
    assert.equal(isTrialActive(ent, now), true);
    const later = new Date("2026-01-20T00:00:00.000Z");
    assert.equal(isTrialActive(ent, later), false);
    assert.equal(resolveMaxSeats(ent, later), FREE_MAX_SEATS);
  });

  it("pro active → 3 asientos; business → 10", () => {
    assert.equal(
      resolveMaxSeats(
        {plan: "pro", subscriptionStatus: "active", source: "stripe"},
        now,
      ),
      PRO_MAX_SEATS,
    );
    assert.equal(
      resolveMaxSeats(
        {plan: "business", subscriptionStatus: "active", source: "stripe"},
        now,
      ),
      BUSINESS_MAX_SEATS,
    );
  });

  it("sin entitlements → 1 asiento", () => {
    assert.equal(resolveMaxSeats(null, now), FREE_MAX_SEATS);
  });
});
