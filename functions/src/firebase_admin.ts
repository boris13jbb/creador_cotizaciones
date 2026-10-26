/**
 * Acceso único y lazy a Firebase Admin / Firestore.
 *
 * No importar `firebase-admin` en el top-level: durante Functions discovery el CLI
 * carga el codebase completo y un require eager de admin (o su cadena de auth)
 * puede atrasar /__/functions.yaml más allá del timeout por defecto (10s).
 */
type AdminModule = typeof import("firebase-admin");

let adminModule: AdminModule | null = null;
let appReady = false;

function loadAdmin(): AdminModule {
  if (!adminModule) {
    // require diferido: solo cuando un handler necesita Auth/Firestore.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    adminModule = require("firebase-admin") as AdminModule;
  }
  return adminModule;
}

export function ensureAdminApp(): AdminModule {
  const admin = loadAdmin();
  if (!appReady) {
    if (admin.apps.length === 0) {
      admin.initializeApp();
    }
    appReady = true;
  }
  return admin;
}

export function getDb(): FirebaseFirestore.Firestore {
  return ensureAdminApp().firestore();
}

export function getAuth(): import("firebase-admin").auth.Auth {
  return ensureAdminApp().auth();
}
