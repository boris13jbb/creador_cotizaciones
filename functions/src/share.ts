import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onRequest} from "firebase-functions/v2/https";

const db = admin.firestore();

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function fieldFromRequest(
  req: {body?: unknown; rawBody?: Buffer; query?: Record<string, unknown>},
  key: string,
): string {
  const body = req.body;
  if (body && typeof body === "object" && key in (body as object)) {
    return String((body as Record<string, unknown>)[key] ?? "").trim();
  }
  if (req.query && key in req.query) {
    return String(req.query[key] ?? "").trim();
  }
  const raw = req.rawBody?.toString("utf8") ?? "";
  if (raw) {
    try {
      const params = new URLSearchParams(raw);
      return (params.get(key) || "").trim();
    } catch {
      /* ignore */
    }
  }
  return "";
}

/**
 * Marca un share como visto y actualiza la cotización a `viewed` si estaba `sent`/`draft`.
 * GET /viewQuoteShare?token=...
 */
export const viewQuoteShare = onRequest({cors: true}, async (req, res) => {
  const token = String(req.query.token || "");
  if (!token) {
    res.status(400).send("token requerido");
    return;
  }

  const ref = db.collection("quoteShares").doc(token);
  const snap = await ref.get();
  if (!snap.exists) {
    res.status(404).send("Enlace no encontrado");
    return;
  }
  const data = snap.data()!;
  const expiresAt = Date.parse(String(data.expiresAt || ""));
  if (Number.isFinite(expiresAt) && Date.now() > expiresAt) {
    res.status(410).send("Enlace expirado");
    return;
  }

  await ref.set(
    {
      viewCount: (Number(data.viewCount) || 0) + 1,
      lastViewedAt: new Date().toISOString(),
    },
    {merge: true},
  );

  const orgId = String(data.organizationId || "");
  const quoteId = String(data.quoteId || "");
  if (orgId && quoteId) {
    const qRef = db
      .collection("organizations")
      .doc(orgId)
      .collection("quotes")
      .doc(quoteId);
    const qSnap = await qRef.get();
    if (qSnap.exists) {
      const status = String(qSnap.data()?.status || "");
      if (status === "sent" || status === "draft") {
        await qRef.set(
          {
            status: "viewed",
            updatedAt: new Date().toISOString(),
          },
          {merge: true},
        );
      }
    }
  }

  const number = escapeHtml(String(data.number || ""));
  const client = escapeHtml(String(data.clientName || ""));
  const totalCents = Number(data.totalCents) || 0;
  const total = (totalCents / 100).toFixed(2);
  const currency = escapeHtml(String(data.currency || "USD"));
  const project =
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    "cotiapp-saas-jb";
  const acceptUrl = `https://us-central1-${project}.cloudfunctions.net/acceptQuoteShare`;

  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.status(200).send(`<!doctype html>
<html lang="es"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Cotización ${number}</title>
<style>
body{font-family:system-ui,sans-serif;max-width:560px;margin:40px auto;padding:0 16px;color:#1a1a2e}
.card{border:1px solid #d8e0dc;border-radius:12px;padding:24px}
h1{font-size:1.25rem;margin:0 0 8px}
.muted{color:#666}
.total{font-size:1.5rem;font-weight:700;color:#2d6a4f;margin-top:16px}
</style></head><body>
<div class="card">
<p class="muted">CotiApp · enlace seguro</p>
<h1>Cotización ${number}</h1>
<p>Cliente: <strong>${client || "—"}</strong></p>
<p class="total">${currency} $${total}</p>
<p class="muted">Este enlace caduca automáticamente. Contacta al emisor para el documento completo.</p>
<form method="POST" action="${acceptUrl}" style="margin-top:20px">
  <input type="hidden" name="token" value="${escapeHtml(token)}"/>
  <label class="muted" for="acceptedByName">Aceptar cotización (escribe tu nombre)</label>
  <input id="acceptedByName" name="acceptedByName" required maxlength="120"
    style="width:100%;margin:8px 0;padding:10px;border:1px solid #d8e0dc;border-radius:8px"/>
  <button type="submit" style="background:#2d6a4f;color:#fff;border:0;padding:10px 16px;border-radius:8px;cursor:pointer">
    Acepto esta cotización
  </button>
</form>
</div>
</body></html>`);
});

/**
 * POST acceptQuoteShare — aceptación simple con nombre (evidencia en quoteShares + status accepted).
 * También acepta application/x-www-form-urlencoded desde el HTML de viewQuoteShare.
 */
export const acceptQuoteShare = onRequest({cors: true}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  const body = (req.body ?? {}) as Record<string, unknown>;
  const token = fieldFromRequest(req, "token") || String(body.token || "").trim();
  const acceptedByName =
    fieldFromRequest(req, "acceptedByName") ||
    String(body.acceptedByName || "").trim();
  if (!token || acceptedByName.length < 2) {
    res.status(400).send("token y acceptedByName (mín. 2 caracteres) requeridos");
    return;
  }

  const ref = db.collection("quoteShares").doc(token);
  const snap = await ref.get();
  if (!snap.exists) {
    res.status(404).send("Enlace no encontrado");
    return;
  }
  const data = snap.data()!;
  const expiresAt = Date.parse(String(data.expiresAt || ""));
  if (Number.isFinite(expiresAt) && Date.now() > expiresAt) {
    res.status(410).send("Enlace expirado");
    return;
  }

  const now = new Date().toISOString();
  await ref.set(
    {
      acceptedAt: now,
      acceptedByName,
      status: "accepted",
    },
    {merge: true},
  );

  const orgId = String(data.organizationId || "");
  const quoteId = String(data.quoteId || "");
  if (orgId && quoteId) {
    const qRef = db
      .collection("organizations")
      .doc(orgId)
      .collection("quotes")
      .doc(quoteId);
    await qRef.set(
      {
        status: "accepted",
        updatedAt: now,
        legacyFields: {
          acceptedByName,
          acceptedAt: now,
        },
      },
      {merge: true},
    );
    const activityId = db
      .collection("organizations")
      .doc(orgId)
      .collection("activities")
      .doc().id;
    await db
      .collection("organizations")
      .doc(orgId)
      .collection("activities")
      .doc(activityId)
      .set({
        id: activityId,
        organizationId: orgId,
        type: "quote_accepted",
        actorUid: "public",
        message: `Cotización aceptada por ${acceptedByName}`,
        entityType: "quote",
        entityId: quoteId,
        metadata: {acceptedByName, token},
        createdAt: now,
      });
  }

  const number = escapeHtml(String(data.number || ""));
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.status(200).send(`<!doctype html>
<html lang="es"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Aceptada ${number}</title></head>
<body style="font-family:system-ui;max-width:560px;margin:40px auto;padding:0 16px">
<h1>Gracias</h1>
<p>La cotización <strong>${number}</strong> fue registrada como <strong>aceptada</strong>
por ${escapeHtml(acceptedByName)}.</p>
</body></html>`);
});

/** Callable opcional: crea share link (también lo hace el cliente). */
export const createQuoteShareLink = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión");
  }
  const quoteId = String(request.data?.quoteId || "");
  const orgId = String(request.data?.organizationId || "");
  if (!quoteId || !orgId) {
    throw new HttpsError(
      "invalid-argument",
      "quoteId y organizationId requeridos",
    );
  }
  const qSnap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("quotes")
    .doc(quoteId)
    .get();
  if (!qSnap.exists) {
    throw new HttpsError("not-found", "Cotización no encontrada");
  }
  const q = qSnap.data()!;
  const token = cryptoRandom();
  const now = new Date();
  const expires = new Date(now.getTime() + 7 * 24 * 3600 * 1000);
  await db.collection("quoteShares").doc(token).set({
    token,
    organizationId: orgId,
    quoteId,
    number: q.number || "",
    clientName: q.clientName || "",
    totalCents: q.totalCents || 0,
    currency: q.currency || "USD",
    status: q.status || "draft",
    createdByUid: request.auth.uid,
    createdAt: now.toISOString(),
    expiresAt: expires.toISOString(),
    viewCount: 0,
  });
  return {token, urlPath: `/viewQuoteShare?token=${token}`};
});

function cryptoRandom(): string {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let out = "";
  for (let i = 0; i < 20; i++) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
}
