/**
 * Acceso único y lazy a Firebase Admin / Firestore.
 *
 * No importar `firebase-admin` en el top-level del barrel: el discovery del CLI
 * (~10s) se degrada si Admin se carga al importar `index.js`.
 *
 * Causa de `app/no-app` en Gen2 (demostrada en producción):
 * `firebase-functions` verifica Auth/App Check con `lib/common/app.js`, que
 * si no hay app [DEFAULT] crea una app *nombrada* `__FIREBASE_FUNCTIONS_SDK__`.
 * Tras eso `getApps().length > 0` pero `getApp()` (DEFAULT) sigue fallando.
 * No usar `getApps().length === 0` como proxy de «existe DEFAULT».
 *
 * Contrato: `ensureAdminApp()` siempre devuelve la app [DEFAULT] (inicializa
 * si falta) y `getDb()` / `getAuth()` pasan esa App a los getters modulares.
 */

import type {App} from "firebase-admin/app";
import type {Auth} from "firebase-admin/auth";
import type {Firestore} from "firebase-admin/firestore";

type AppMod = typeof import("firebase-admin/app");
type FsMod = typeof import("firebase-admin/firestore");
type AuthMod = typeof import("firebase-admin/auth");

/** Nombre que usa firebase-functions al auto-inicializar (no es [DEFAULT]). */
export const FIREBASE_FUNCTIONS_SDK_APP_NAME = "__FIREBASE_FUNCTIONS_SDK__";

let appMod: AppMod | null = null;
let fsMod: FsMod | null = null;
let authMod: AuthMod | null = null;

function loadAppMod(): AppMod {
  if (!appMod) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    appMod = require("firebase-admin/app") as AppMod;
  }
  return appMod;
}

function loadFsMod(): FsMod {
  if (!fsMod) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    fsMod = require("firebase-admin/firestore") as FsMod;
  }
  return fsMod;
}

function loadAuthMod(): AuthMod {
  if (!authMod) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    authMod = require("firebase-admin/auth") as AuthMod;
  }
  return authMod;
}

/**
 * Inicializa o reutiliza la app predeterminada [DEFAULT].
 * Idempotente aunque ya exista la app nombrada del Functions SDK.
 */
export function ensureAdminApp(): App {
  const {getApp, initializeApp} = loadAppMod();
  try {
    return getApp();
  } catch (e) {
    const code =
      e && typeof e === "object" && "code" in e
        ? String((e as {code?: unknown}).code || "")
        : "";
    // Solo recuperar no-app; re-lanzar duplicate-app u otros.
    if (code !== "app/no-app") {
      throw e;
    }
    // Credenciales ADC / FIREBASE_CONFIG del runtime Gen2.
    return initializeApp();
  }
}

/** Firestore ligado a la App [DEFAULT] (nunca lookup ciego ni app del SDK). */
export function getDb(): Firestore {
  const app = ensureAdminApp();
  return loadFsMod().getFirestore(app);
}

/** Auth Admin ligado a la misma App [DEFAULT]. */
export function getAuth(): Auth {
  const app = ensureAdminApp();
  return loadAuthMod().getAuth(app);
}

/**
 * Solo tests: limpia el caché de requires del helper para simular cold start.
 * No usar en handlers de producción.
 */
export function __resetAdminLoaderForTests(): void {
  appMod = null;
  fsMod = null;
  authMod = null;
}
