import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {
  EntitlementsLike,
  resolveMaxSeats,
} from "./entitlements_policy";
import {getDb} from "./firebase_admin";

const ALLOWED_INVITE_ROLES = new Set(["admin", "sales", "readonly"]);

/**
 * Acepta una invitación por token con:
 * - autenticación obligatoria;
 * - email de la invitación = email del auth token;
 * - orgId derivado del documento (no del cliente);
 * - rol derivado de la invitación;
 * - cupo de asientos según entitlements del owner;
 * - transacción (idempotente ante repetición / carrera).
 */
export const acceptOrgInvite = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión");
  }
  const token = String(request.data?.token || "").trim();
  if (!token) {
    throw new HttpsError("invalid-argument", "token requerido");
  }

  // orgId/role/seatCount del cliente se ignoran deliberadamente.
  const email = (request.auth.token.email || "").toLowerCase();
  if (!email) {
    throw new HttpsError(
      "failed-precondition",
      "Tu cuenta no tiene correo asociado",
    );
  }

  const invites = await getDb()
    .collectionGroup("invites")
    .where("token", "==", token)
    .limit(1)
    .get();

  if (invites.empty) {
    throw new HttpsError("not-found", "Invitación no encontrada o usada");
  }

  const inviteDoc = invites.docs[0];
  const pathOrgId = inviteDoc.ref.parent.parent?.id;
  if (!pathOrgId) {
    throw new HttpsError("internal", "Invitación con ruta inválida");
  }

  const uid = request.auth.uid;
  const displayName = String(request.auth.token.name || email);

  try {
    const result = await getDb().runTransaction(async (tx) => {
      const inviteSnap = await tx.get(inviteDoc.ref);
      if (!inviteSnap.exists) {
        throw new HttpsError("not-found", "Invitación no encontrada o usada");
      }
      const invite = inviteSnap.data() || {};
      const orgId = String(invite.organizationId || pathOrgId);
      if (orgId !== pathOrgId) {
        throw new HttpsError(
          "failed-precondition",
          "Invitación inconsistente con la organización",
        );
      }

      const orgRef = getDb().collection("organizations").doc(orgId);
      const memberRef = orgRef.collection("members").doc(uid);
      const membershipRef = getDb()
        .collection("users")
        .doc(uid)
        .collection("memberships")
        .doc(orgId);

      const orgSnap = await tx.get(orgRef);
      const memberSnap = await tx.get(memberRef);
      const membersSnap = await tx.get(orgRef.collection("members"));

      if (!orgSnap.exists) {
        throw new HttpsError("not-found", "Organización no encontrada");
      }

      const ownerUid = String(orgSnap.data()?.ownerUid || "");
      if (!ownerUid) {
        throw new HttpsError("failed-precondition", "Organización sin owner");
      }

      const entSnap = await tx.get(getDb().collection("entitlements").doc(ownerUid));
      const entitlements = (entSnap.data() || null) as EntitlementsLike | null;
      const maxSeats = resolveMaxSeats(entitlements);

      const inviteEmail = String(invite.email || "").toLowerCase();
      if (inviteEmail !== email) {
        throw new HttpsError(
          "permission-denied",
          "Esta invitación es para otro correo",
        );
      }

      const status = String(invite.status || "");
      const role = String(invite.role || "sales");
      if (!ALLOWED_INVITE_ROLES.has(role)) {
        throw new HttpsError("invalid-argument", "Rol de invitación inválido");
      }

      const expiresAt = Date.parse(String(invite.expiresAt || ""));
      const now = new Date();
      const nowIso = now.toISOString();

      const alreadyActive =
        memberSnap.exists &&
        String(memberSnap.data()?.status || "") === "active";

      // Idempotencia: ya es miembro activo → éxito sin consumir otro asiento.
      if (alreadyActive) {
        if (status === "pending") {
          tx.set(
            inviteDoc.ref,
            {status: "accepted", acceptedAt: nowIso, acceptedByUid: uid},
            {merge: true},
          );
        }
        return {
          ok: true as const,
          organizationId: orgId,
          role: String(memberSnap.data()?.role || role),
          alreadyMember: true,
        };
      }

      if (status === "accepted") {
        throw new HttpsError(
          "already-exists",
          "Invitación ya utilizada",
        );
      }
      if (status === "expired" || status === "declined") {
        throw new HttpsError("failed-precondition", `Invitación ${status}`);
      }
      if (status !== "pending") {
        throw new HttpsError("not-found", "Invitación no encontrada o usada");
      }

      if (Number.isFinite(expiresAt) && now.getTime() > expiresAt) {
        // No escribir aquí: un throw aborta la transacción.
        throw new HttpsError("deadline-exceeded", "Invitación expirada");
      }

      const activeCount = membersSnap.docs.filter(
        (d) => String(d.data()?.status || "") === "active",
      ).length;

      if (activeCount >= maxSeats) {
        throw new HttpsError(
          "resource-exhausted",
          `Sin asientos disponibles (máximo ${maxSeats} en el plan actual)`,
        );
      }

      const member = {
        organizationId: orgId,
        uid,
        role,
        status: "active",
        displayName,
        email,
        createdAt: nowIso,
        updatedAt: nowIso,
      };

      tx.set(memberRef, member);
      tx.set(membershipRef, member);
      tx.set(
        inviteDoc.ref,
        {status: "accepted", acceptedAt: nowIso, acceptedByUid: uid},
        {merge: true},
      );

      const activityRef = orgRef.collection("activities").doc();
      tx.set(activityRef, {
        id: activityRef.id,
        organizationId: orgId,
        type: "member_joined",
        actorUid: uid,
        actorEmail: email,
        entityType: "member",
        entityId: uid,
        message: `${email} aceptó invitación (${role})`,
        metadata: {role, maxSeats, activeBefore: activeCount},
        createdAt: nowIso,
      });

      return {
        ok: true as const,
        organizationId: orgId,
        role,
        alreadyMember: false,
      };
    });

    logger.info("invite_accepted", {
      orgId: result.organizationId,
      uid,
      role: result.role,
      email,
      alreadyMember: result.alreadyMember,
    });
    return result;
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error("acceptOrgInvite_failed", e);
    throw new HttpsError("internal", "No se pudo aceptar la invitación");
  }
});
