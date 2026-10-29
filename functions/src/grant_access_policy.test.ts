import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {isAdminGrantActiveInWindow} from "./grant_access_policy";

const NOW = new Date("2026-01-05T00:00:00.000Z");

describe("isAdminGrantActiveInWindow (CotiApp)", () => {
  it("legado sin fechas permitido", () => {
    assert.equal(
      isAdminGrantActiveInWindow(
        {source: "admin_grant", plan: "pro", subscriptionStatus: "active"},
        NOW,
      ),
      true,
    );
  });

  it("programado / vigente / vencido", () => {
    const data = {
      source: "admin_grant",
      plan: "business",
      subscriptionStatus: "active",
      grantModality: "temporary",
      grantStartsAt: "2026-01-05T00:00:00.000Z",
      grantExpiresAt: "2026-01-12T00:00:00.000Z",
    };
    assert.equal(
      isAdminGrantActiveInWindow(data, new Date("2026-01-04T23:59:59.000Z")),
      false,
    );
    assert.equal(isAdminGrantActiveInWindow(data, NOW), true);
    assert.equal(
      isAdminGrantActiveInWindow(data, new Date("2026-01-12T00:00:00.000Z")),
      false,
    );
  });

  it("temporal inválido denegado", () => {
    assert.equal(
      isAdminGrantActiveInWindow(
        {
          source: "admin_grant",
          plan: "pro",
          subscriptionStatus: "active",
          grantModality: "temporary",
          grantExpiresAt: "x",
        },
        NOW,
      ),
      false,
    );
  });
});
