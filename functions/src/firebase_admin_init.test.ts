/**
 * Regresión: getDb debe inicializar/reutilizar Admin [DEFAULT] sin app/no-app
 * ni duplicate-app, incluso tras el auto-init nombrado de firebase-functions.
 *
 * No inicializa Admin manualmente antes de la primera getDb: eso ocultaría
 * el bug de orden de carga que fallaba en Gen2.
 */
import assert from "node:assert/strict";
import {describe, it, before, after} from "node:test";
import {deleteApp, getApps, initializeApp} from "firebase-admin/app";

async function deleteAllApps(): Promise<void> {
  const apps = [...getApps()];
  await Promise.all(apps.map((a) => deleteApp(a)));
}

function loadAdminMod(): typeof import("./firebase_admin") {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require.resolve("./firebase_admin");
  delete require.cache[path];
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const mod = require("./firebase_admin") as typeof import("./firebase_admin");
  mod.__resetAdminLoaderForTests();
  return mod;
}

describe("firebase_admin lazy init", () => {
  before(async () => {
    await deleteAllApps();
  });

  after(async () => {
    // Dejar el proceso usable para otros tests del mismo npm test.
  });

  it("getDb inicializa la app y una segunda llamada reutiliza sin duplicate-app", async () => {
    await deleteAllApps();
    assert.equal(getApps().length, 0, "precondición: sin apps");

    const mod = loadAdminMod();

    const db1 = mod.getDb();
    assert.ok(db1, "getDb #1 debe devolver Firestore");
    assert.equal(getApps().length, 1, "debe existir exactamente 1 app");

    const db2 = mod.getDb();
    assert.ok(db2, "getDb #2 debe reutilizar");
    assert.equal(getApps().length, 1, "no debe crear segunda app");

    const app = mod.ensureAdminApp();
    assert.equal(app.name, "[DEFAULT]");
  });

  it("con app nombrada del Functions SDK aún obtiene [DEFAULT] sin no-app", async () => {
    await deleteAllApps();

    // Replica firebase-functions/lib/common/app.js: crea solo la app nombrada.
    const named = initializeApp(
      {projectId: "cotiapp-saas-jb"},
      "__FIREBASE_FUNCTIONS_SDK__",
    );
    assert.equal(named.name, "__FIREBASE_FUNCTIONS_SDK__");
    assert.equal(getApps().length, 1, "solo existe la app del SDK");

    const mod = loadAdminMod();

    assert.doesNotThrow(() => {
      const app = mod.ensureAdminApp();
      assert.equal(app.name, "[DEFAULT]");
      const db = mod.getDb();
      assert.ok(db);
    });

    const names = getApps().map((a) => a.name).sort();
    assert.deepEqual(names, ["[DEFAULT]", "__FIREBASE_FUNCTIONS_SDK__"]);
  });

  it("orden de importación estilo index → create_org_quote no provoca no-app", async () => {
    await deleteAllApps();

    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const adminPath = require.resolve("./firebase_admin");
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const quotePath = require.resolve("./create_org_quote");
    delete require.cache[adminPath];
    delete require.cache[quotePath];

    // Mismo orden que lib/index.js: firebase_admin luego create_org_quote.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const admin = require("./firebase_admin") as typeof import("./firebase_admin");
    admin.__resetAdminLoaderForTests();
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("./create_org_quote");

    assert.doesNotThrow(() => {
      const db = admin.getDb();
      assert.ok(db);
    });
    assert.ok(getApps().some((a) => a.name === "[DEFAULT]"));
  });
});

describe("extractSafeErrorCode", () => {
  it("lee errorInfo.code y code de FirebaseAppError-like", async () => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const {extractSafeErrorCode} = require("./create_org_quote") as typeof import("./create_org_quote");

    assert.equal(
      extractSafeErrorCode({errorInfo: {code: "app/no-app"}}),
      "app/no-app",
    );
    assert.equal(
      extractSafeErrorCode({code: "app/duplicate-app"}),
      "app/duplicate-app",
    );
    assert.equal(extractSafeErrorCode(null), "");
    assert.equal(extractSafeErrorCode({name: "FirebaseAppError"}), "FirebaseAppError");
  });
});
