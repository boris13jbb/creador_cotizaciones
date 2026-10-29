import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {FREE_MAX_QUOTES, PAID_MAX_QUOTES} from "./entitlements_policy";
import {
  decideQuoteCreateLimit,
  isCommercialRole,
  quoteLimitMessage,
} from "./quote_limit";

describe("decideQuoteCreateLimit", () => {
  const freeEnt = {
    plan: "free",
    subscriptionStatus: "active",
    source: "signup",
  };
  const proEnt = {
    plan: "pro",
    subscriptionStatus: "active",
    source: "stripe",
  };

  it("Free permite crear hasta el límite", () => {
    const existing = Array.from({length: FREE_MAX_QUOTES - 1}, (_, i) => `q${i}`);
    const d = decideQuoteCreateLimit({
      quoteId: "q-new",
      existingQuoteIds: existing,
      entitlements: freeEnt,
    });
    assert.equal(d.ok, true);
    if (d.ok) assert.equal(d.alreadyExists, false);
  });

  it("Free rechaza la siguiente creación al superar el límite", () => {
    const existing = Array.from({length: FREE_MAX_QUOTES}, (_, i) => `q${i}`);
    const d = decideQuoteCreateLimit({
      quoteId: "q-over",
      existingQuoteIds: existing,
      entitlements: freeEnt,
    });
    assert.equal(d.ok, false);
    if (!d.ok) {
      assert.equal(d.code, "resource-exhausted");
      assert.equal(d.maxQuotes, FREE_MAX_QUOTES);
      assert.equal(d.currentCount, FREE_MAX_QUOTES);
    }
  });

  it("Pro no aplica tope Free", () => {
    const existing = Array.from({length: 50}, (_, i) => `q${i}`);
    const d = decideQuoteCreateLimit({
      quoteId: "q-pro",
      existingQuoteIds: existing,
      entitlements: proEnt,
    });
    assert.equal(d.ok, true);
  });

  it("reintento con mismo id es idempotente aunque el cupo esté lleno", () => {
    const existing = Array.from({length: FREE_MAX_QUOTES}, (_, i) => `q${i}`);
    existing[0] = "q-same";
    const d = decideQuoteCreateLimit({
      quoteId: "q-same",
      existingQuoteIds: existing,
      entitlements: freeEnt,
    });
    assert.equal(d.ok, true);
    if (d.ok) assert.equal(d.alreadyExists, true);
  });

  it("sin entitlements usa Free", () => {
    const d = decideQuoteCreateLimit({
      quoteId: "q-new",
      existingQuoteIds: Array.from({length: FREE_MAX_QUOTES}, (_, i) => `q${i}`),
      entitlements: null,
    });
    assert.equal(d.ok, false);
  });

  it("simulación concurrente: sin serialización se puede superar; con serialización no", () => {
    // Riesgo sin transacción: dos lectores ven count=4 y ambos incrementan.
    let racedCount = FREE_MAX_QUOTES - 1;
    const snapA = racedCount;
    const snapB = racedCount;
    const racedCreates = [snapA, snapB].map((snap) => {
      if (snap >= FREE_MAX_QUOTES) return false;
      racedCount += 1;
      return true;
    });
    assert.deepEqual(racedCreates, [true, true]);
    assert.equal(racedCount, FREE_MAX_QUOTES + 1);

    // Con serialización (transacción): la 2.ª decisión ve el cupo ya lleno.
    let serialCount = FREE_MAX_QUOTES - 1;
    const serialCreates = [0, 1].map(() => {
      const existing = Array.from({length: serialCount}, (_, i) => `q${i}`);
      const d = decideQuoteCreateLimit({
        quoteId: `new-${serialCount}`,
        existingQuoteIds: existing,
        entitlements: freeEnt,
      });
      if (!d.ok) return false;
      serialCount += 1;
      return true;
    });
    assert.deepEqual(serialCreates, [true, false]);
    assert.equal(serialCount, FREE_MAX_QUOTES);
  });

  it("mensaje de error es estable para el cliente", () => {
    assert.match(quoteLimitMessage(FREE_MAX_QUOTES), /Límite del plan Free/);
    assert.match(quoteLimitMessage(FREE_MAX_QUOTES), new RegExp(String(FREE_MAX_QUOTES)));
  });

  it("roles comerciales vs readonly", () => {
    assert.equal(isCommercialRole("owner"), true);
    assert.equal(isCommercialRole("admin"), true);
    assert.equal(isCommercialRole("sales"), true);
    assert.equal(isCommercialRole("readonly"), false);
    assert.equal(isCommercialRole("viewer"), false);
  });

  it("PAID_MAX_QUOTES es el umbral de omisión", () => {
    assert.ok(PAID_MAX_QUOTES > FREE_MAX_QUOTES);
  });
});
