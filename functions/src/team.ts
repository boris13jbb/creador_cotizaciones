import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const db = admin.firestore();

/**
 * Acepta una invitación por token y crea membresía activa + mirror en users.
 */
export const acceptOrgInvite = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión");
  }
  const token = String(request.data?.token || "").trim();
  if (!token) {
    throw new HttpsError("invalid-argument", "token requerido");
  }

  const email = (request.auth.token.email || "").toLowerCase();
  if (!email) {
    throw new HttpsError(
      "failed-precondition",
      "Tu cuenta no tiene correo verificado asociado",
    );
  }

  const invites = await db
    .collectionGroup("invites")
    .where("token", "==", token)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (invites.empty) {
    throw new HttpsError("not-found", "Invitación no encontrada o usada");
  }

  const inviteDoc = invites.docs[0];
  const invite = inviteDoc.data();
  const orgId = String(invite.organizationId || "");
  const inviteEmail = String(invite.email || "").toLowerCase();
  const expiresAt = Date.parse(String(invite.expiresAt || ""));

  if (inviteEmail !== email) {
    throw new HttpsError(
      "permission-denied",
      "Esta invitación es para otro correo",
    );
  }
  if (Number.isFinite(expiresAt) && Date.now() > expiresAt) {
    await inviteDoc.ref.set({status: "expired"}, {merge: true});
    throw new HttpsError("deadline-exceeded", "Invitación expirada");
  }

  const role = String(invite.role || "sales");
  if (role === "owner") {
    throw new HttpsError("invalid-argument", "Rol inválido");
  }

  const uid = request.auth.uid;
  const now = new Date().toISOString();
  const member = {
    organizationId: orgId,
    uid,
    role,
    status: "active",
    displayName: request.auth.token.name || email,
    email,
    createdAt: now,
    updatedAt: now,
  };

  const batch = db.batch();
  batch.set(
    db.collection("organizations").doc(orgId).collection("members").doc(uid),
    member,
  );
  batch.set(
    db.collection("users").doc(uid).collection("memberships").doc(orgId),
    member,
  );
  batch.set(inviteDoc.ref, {status: "accepted", acceptedAt: now}, {merge: true});
  const activityId = db.collection("organizations").doc(orgId)
    .collection("activities").doc().id;
  batch.set(
    db.collection("organizations").doc(orgId).collection("activities")
      .doc(activityId),
    {
      id: activityId,
      organizationId: orgId,
      type: "member_joined",
      actorUid: uid,
      actorEmail: email,
      entityType: "member",
      entityId: uid,
      message: `${email} aceptó invitación (${role})`,
      metadata: {role},
      createdAt: now,
    },
  );
  await batch.commit();

  logger.info("invite_accepted", {orgId, uid, role, email});
  return {ok: true, organizationId: orgId, role};
});
