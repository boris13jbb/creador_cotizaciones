import * as logger from "firebase-functions/logger";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getDb} from "./firebase_admin";

/** Recibe errores de cliente autenticado (además de Firestore errorReports). */
export const reportClientError = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión");
  }
  const message = String(request.data?.message || "").slice(0, 2000);
  if (!message) {
    throw new HttpsError("invalid-argument", "message requerido");
  }
  const organizationId = String(request.data?.organizationId || "");
  const stack = String(request.data?.stack || "").slice(0, 8000);
  const platform = String(request.data?.platform || "");

  logger.error("client_error_report", {
    uid: request.auth.uid,
    organizationId,
    platform,
    message,
    stack: stack.slice(0, 500),
  });

  const id = getDb().collection("errorReports").doc().id;
  await getDb().collection("errorReports").doc(id).set({
    id,
    uid: request.auth.uid,
    organizationId,
    message,
    stack,
    platform,
    createdAt: new Date().toISOString(),
    source: "callable",
  });

  return {ok: true, id};
});
