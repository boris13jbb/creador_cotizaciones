import * as admin from "firebase-admin";

/**
 * Acceso único y lazy a Firebase Admin / Firestore.
 * Evita ejecutar firestore() en cada módulo durante Functions discovery.
 */
let appReady = false;

export function ensureAdminApp(): typeof admin {
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

export function getAuth(): admin.auth.Auth {
  return ensureAdminApp().auth();
}
