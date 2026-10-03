import type {auth} from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {getAuth, getDb} from "./firebase_admin";

const bootstrapSecret = defineSecret("PLATFORM_ADMIN_BOOTSTRAP_SECRET");

type PlanId = "pro" | "business";

function nowIso(): string {
  return new Date().toISOString();
}

function assertPlatformAdmin(auth: {uid: string; token: Record<string, unknown>} | undefined): string {
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  if (auth.token.platformAdmin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Se requiere rol de super administrador de plataforma."
    );
  }
  return auth.uid;
}

async function writeAudit(entry: Record<string, unknown>): Promise<void> {
  await getDb().collection("adminAuditLogs").add({
    ...entry,
    createdAt: nowIso(),
  });
}

/**
 * Primer super admin: solo si aún no hay ninguno y el secreto coincide.
 * Luego los admins se gestionan con adminSetPlatformAdmin.
 */
export const bootstrapPlatformAdmin = onCall(
  {secrets: [bootstrapSecret]},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const secret = String(request.data?.secret ?? "");
    const expected = bootstrapSecret.value();
    if (!expected || secret !== expected) {
      throw new HttpsError("permission-denied", "Secreto de bootstrap inválido.");
    }

    const existing = await getDb().collection("platformAdmins").limit(1).get();
    if (!existing.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Ya existe al menos un super admin. Usa adminSetPlatformAdmin."
      );
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email ?? null;
    await getAuth().setCustomUserClaims(uid, {platformAdmin: true});
    await getDb().collection("platformAdmins").doc(uid).set({
      uid,
      email,
      createdAt: nowIso(),
      updatedAt: nowIso(),
      createdBy: "bootstrap",
    });
    await writeAudit({
      action: "bootstrap_platform_admin",
      actorUid: uid,
      targetUid: uid,
    });
    return {ok: true, uid, message: "Cierra sesión y vuelve a entrar para refrescar el token."};
  }
);

/** Promueve o quita super admin (solo otro platformAdmin). */
export const adminSetPlatformAdmin = onCall(async (request) => {
  const actorUid = assertPlatformAdmin(request.auth);
  const targetUid = String(request.data?.uid ?? "").trim();
  const enabled = request.data?.enabled === true;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "uid requerido.");
  }

  const user = await getAuth().getUser(targetUid);
  const claims = {...(user.customClaims ?? {})};
  if (enabled) {
    claims.platformAdmin = true;
  } else {
    delete claims.platformAdmin;
  }
  await getAuth().setCustomUserClaims(targetUid, claims);

  if (enabled) {
    await getDb().collection("platformAdmins").doc(targetUid).set({
      uid: targetUid,
      email: user.email ?? null,
      createdAt: nowIso(),
      updatedAt: nowIso(),
      createdBy: actorUid,
    }, {merge: true});
  } else {
    await getDb().collection("platformAdmins").doc(targetUid).delete();
  }

  await writeAudit({
    action: enabled ? "set_platform_admin" : "revoke_platform_admin",
    actorUid,
    targetUid,
  });
  return {ok: true, uid: targetUid, enabled};
});

/** Busca usuario por email o uid y devuelve perfil + entitlements. */
export const adminLookupUser = onCall(async (request) => {
  assertPlatformAdmin(request.auth);
  const email = String(request.data?.email ?? "").trim().toLowerCase();
  const uidArg = String(request.data?.uid ?? "").trim();
  if (!email && !uidArg) {
    throw new HttpsError("invalid-argument", "email o uid requerido.");
  }

  let user: auth.UserRecord;
  try {
    user = uidArg
      ? await getAuth().getUser(uidArg)
      : await getAuth().getUserByEmail(email);
  } catch {
    throw new HttpsError("not-found", "Usuario no encontrado.");
  }

  const [profileSnap, entSnap, membershipsSnap] = await Promise.all([
    getDb().collection("users").doc(user.uid).get(),
    getDb().collection("entitlements").doc(user.uid).get(),
    getDb().collection("users").doc(user.uid).collection("memberships").limit(20).get(),
  ]);

  return {
    uid: user.uid,
    email: user.email ?? null,
    displayName: user.displayName ?? profileSnap.data()?.displayName ?? null,
    disabled: user.disabled,
    platformAdmin: user.customClaims?.platformAdmin === true,
    profile: profileSnap.exists ? profileSnap.data() : null,
    entitlements: entSnap.exists ? entSnap.data() : null,
    memberships: membershipsSnap.docs.map((d) => d.data()),
  };
});

/**
 * Otorga acceso gratis completo (Pro o Business) a un cliente.
 * Escribe entitlements + platformGrants (auditoría).
 */
export const adminGrantEntitlement = onCall(async (request) => {
  const actorUid = assertPlatformAdmin(request.auth);
  const uid = String(request.data?.uid ?? "").trim();
  const plan = String(request.data?.plan ?? "business").trim() as PlanId;
  const reason = String(request.data?.reason ?? "").trim();
  const expiresAtRaw = request.data?.expiresAt
    ? String(request.data.expiresAt)
    : null;

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid requerido.");
  }
  if (plan !== "pro" && plan !== "business") {
    throw new HttpsError("invalid-argument", "plan debe ser pro o business.");
  }
  if (!reason) {
    throw new HttpsError("invalid-argument", "reason (motivo) requerido.");
  }

  let expiresAt: string | null = null;
  if (expiresAtRaw) {
    const d = new Date(expiresAtRaw);
    if (Number.isNaN(d.getTime())) {
      throw new HttpsError("invalid-argument", "expiresAt inválido.");
    }
    expiresAt = d.toISOString();
  }

  await getAuth().getUser(uid);
  const now = nowIso();
  const grantRef = getDb().collection("platformGrants").doc();
  const entRef = getDb().collection("entitlements").doc(uid);
  const existing = await entRef.get();
  const createdAt = (existing.data()?.createdAt as string) || now;

  const entitlements = {
    uid,
    plan,
    subscriptionStatus: "active",
    source: "admin_grant",
    grantExpiresAt: expiresAt,
    grantReason: reason,
    grantedByUid: actorUid,
    grantId: grantRef.id,
    createdAt,
    updatedAt: now,
  };

  const grant = {
    id: grantRef.id,
    targetUid: uid,
    plan,
    reason,
    grantedByUid: actorUid,
    expiresAt,
    revokedAt: null,
    createdAt: now,
    updatedAt: now,
  };

  const batch = getDb().batch();
  batch.set(entRef, entitlements, {merge: true});
  batch.set(grantRef, grant);
  await batch.commit();

  await writeAudit({
    action: "grant_entitlement",
    actorUid,
    targetUid: uid,
    plan,
    reason,
    grantId: grantRef.id,
    expiresAt,
  });

  return {ok: true, grantId: grantRef.id, entitlements};
});

/** Revoca grant admin y deja al usuario en free (conserva ids Stripe si existen). */
export const adminRevokeGrant = onCall(async (request) => {
  const actorUid = assertPlatformAdmin(request.auth);
  const uid = String(request.data?.uid ?? "").trim();
  const grantId = String(request.data?.grantId ?? "").trim();
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid requerido.");
  }

  const now = nowIso();
  const entRef = getDb().collection("entitlements").doc(uid);
  const entSnap = await entRef.get();
  const prev = entSnap.data() ?? {};

  await entRef.set(
    {
      uid,
      plan: "free",
      subscriptionStatus: "active",
      source: "admin_revoke",
      grantExpiresAt: null,
      grantReason: null,
      grantedByUid: null,
      grantId: null,
      updatedAt: now,
      createdAt: (prev.createdAt as string) || now,
      stripeCustomerId: prev.stripeCustomerId ?? null,
      stripeSubscriptionId: prev.stripeSubscriptionId ?? null,
    },
    {merge: true}
  );

  if (grantId) {
    await getDb().collection("platformGrants").doc(grantId).set(
      {revokedAt: now, updatedAt: now, revokedByUid: actorUid},
      {merge: true}
    );
  } else if (prev.grantId) {
    await getDb().collection("platformGrants").doc(String(prev.grantId)).set(
      {revokedAt: now, updatedAt: now, revokedByUid: actorUid},
      {merge: true}
    );
  }

  await writeAudit({
    action: "revoke_grant",
    actorUid,
    targetUid: uid,
    grantId: grantId || prev.grantId || null,
  });

  return {ok: true};
});

/** Listado reciente de grants para la consola. */
export const adminListGrants = onCall(async (request) => {
  assertPlatformAdmin(request.auth);
  const limit = Math.min(Number(request.data?.limit ?? 50), 100);
  const snap = await getDb()
    .collection("platformGrants")
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  return {grants: snap.docs.map((d) => d.data())};
});

/** Métricas básicas de monitoreo. */
export const adminGetPlatformStats = onCall(async (request) => {
  assertPlatformAdmin(request.auth);

  const [usersCount, orgsCount, grantsActive, errorReports] = await Promise.all([
    getDb().collection("users").count().get(),
    getDb().collection("organizations").count().get(),
    getDb()
      .collection("platformGrants")
      .where("revokedAt", "==", null)
      .count()
      .get(),
    getDb().collection("errorReports").orderBy("createdAt", "desc").limit(20).get(),
  ]);

  const entitlementsSnap = await getDb()
    .collection("entitlements")
    .where("source", "==", "admin_grant")
    .limit(200)
    .get();

  return {
    users: usersCount.data().count,
    organizations: orgsCount.data().count,
    activeGrants: grantsActive.data().count,
    adminGrantEntitlements: entitlementsSnap.size,
    recentErrors: errorReports.docs.map((d) => ({id: d.id, ...d.data()})),
  };
});
