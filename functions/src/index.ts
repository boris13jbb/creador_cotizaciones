import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import Stripe from "stripe";
import {clampTrialEndsAt} from "./entitlements_policy";

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const stripePricePro = defineSecret("STRIPE_PRICE_PRO");
const stripePriceBusiness = defineSecret("STRIPE_PRICE_BUSINESS");

const db = admin.firestore();

type EntitlementsDoc = {
  uid: string;
  plan: "free" | "pro" | "business";
  subscriptionStatus: string;
  trialEndsAt?: string;
  currentPeriodEnd?: string;
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  source: string;
  createdAt: string;
  updatedAt: string;
};

function nowIso(): string {
  return new Date().toISOString();
}

function trialEndsIso(days = 14): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString();
}

async function ensureEntitlements(uid: string): Promise<EntitlementsDoc> {
  const ref = db.collection("entitlements").doc(uid);
  const snap = await ref.get();
  if (snap.exists) {
    return snap.data() as EntitlementsDoc;
  }

  const userSnap = await db.collection("users").doc(uid).get();
  const legacy = userSnap.data() ?? {};
  const createdAt = (legacy.createdAt as string) || nowIso();
  const created: EntitlementsDoc = {
    uid,
    plan: (legacy.plan as EntitlementsDoc["plan"]) || "free",
    subscriptionStatus: (legacy.subscriptionStatus as string) || "trialing",
    trialEndsAt: clampTrialEndsAt(
      (legacy.trialEndsAt as string) || trialEndsIso(),
      createdAt,
    ),
    source: legacy.plan ? "legacy_migration" : "signup",
    createdAt,
    updatedAt: nowIso(),
  };

  if (created.plan === "pro" && created.subscriptionStatus === "active") {
    created.source = "legacy_migration";
  } else if (!legacy.plan) {
    created.plan = "free";
    created.subscriptionStatus = "trialing";
    created.trialEndsAt = clampTrialEndsAt(trialEndsIso(), createdAt);
    created.source = "signup";
  } else {
    // Legacy: nunca persistir un trialEndsAt fuera de política.
    created.trialEndsAt = clampTrialEndsAt(created.trialEndsAt, createdAt);
  }

  await ref.set(created);
  return created;
}

async function requireAuth(authorizationHeader: unknown): Promise<string> {
  const header = String(authorizationHeader || "");
  if (!header.startsWith("Bearer ")) {
    throw new HttpsError("unauthenticated", "Token requerido.");
  }
  const token = header.slice("Bearer ".length);
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded.uid;
}

export const onUserProfileCreated = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid as string;
    await ensureEntitlements(uid);
  }
);

export const ensureMyEntitlements = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return ensureEntitlements(request.auth.uid);
});

export const createCheckoutSession = onRequest(
  { secrets: [stripeSecret, stripePricePro, stripePriceBusiness], cors: true },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }
      const uid = await requireAuth(req.headers.authorization);
      const secret = stripeSecret.value();
      const body = (req.body ?? {}) as {
        successUrl?: string;
        cancelUrl?: string;
        plan?: string;
      };
      const plan =
        body.plan === "business" ? "business" : "pro";
      const price =
        plan === "business"
          ? stripePriceBusiness.value()
          : stripePricePro.value();
      if (!secret || !price) {
        res.status(503).json({
          error:
            plan === "business"
              ? "Stripe Business no configurado. Define STRIPE_PRICE_BUSINESS."
              : "Stripe no configurado. Define STRIPE_SECRET_KEY y STRIPE_PRICE_PRO.",
        });
        return;
      }

      const stripe = new Stripe(secret);
      const entitlements = await ensureEntitlements(uid);
      let customerId = entitlements.stripeCustomerId;
      if (!customerId) {
        const user = await admin.auth().getUser(uid);
        const customer = await stripe.customers.create({
          email: user.email,
          metadata: { firebaseUid: uid },
        });
        customerId = customer.id;
        await db.collection("entitlements").doc(uid).set(
          {
            stripeCustomerId: customerId,
            updatedAt: nowIso(),
          },
          { merge: true }
        );
      }

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        customer: customerId,
        line_items: [{ price, quantity: 1 }],
        success_url:
          body.successUrl ||
          "https://cotiapp-saas-jb.web.app/billing/success",
        cancel_url:
          body.cancelUrl || "https://cotiapp-saas-jb.web.app/billing/cancel",
        metadata: { firebaseUid: uid, plan },
        subscription_data: {
          metadata: { firebaseUid: uid, plan },
        },
      });

      res.json({ url: session.url, id: session.id, plan });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "No se pudo crear Checkout." });
    }
  }
);

export const createCustomerPortal = onRequest(
  { secrets: [stripeSecret], cors: true },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }
      const uid = await requireAuth(req.headers.authorization);
      const secret = stripeSecret.value();
      if (!secret) {
        res.status(503).json({ error: "Stripe no configurado." });
        return;
      }
      const entitlements = await ensureEntitlements(uid);
      if (!entitlements.stripeCustomerId) {
        res.status(400).json({ error: "No hay cliente Stripe asociado." });
        return;
      }
      const stripe = new Stripe(secret);
      const portal = await stripe.billingPortal.sessions.create({
        customer: entitlements.stripeCustomerId,
        return_url: "https://cotiapp-saas-jb.web.app/account",
      });
      res.json({ url: portal.url });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "No se pudo abrir el portal." });
    }
  }
);

export const stripeWebhook = onRequest(
  { secrets: [stripeSecret, stripeWebhookSecret], cors: false },
  async (req, res) => {
    const secret = stripeSecret.value();
    const whSecret = stripeWebhookSecret.value();
    if (!secret || !whSecret) {
      res.status(503).send("Stripe webhook no configurado");
      return;
    }

    const stripe = new Stripe(secret);
    const sig = req.headers["stripe-signature"];
    if (!sig || Array.isArray(sig)) {
      res.status(400).send("Firma ausente");
      return;
    }

    let event: Stripe.Event;
    try {
      const raw = (req as unknown as { rawBody: Buffer }).rawBody;
      event = stripe.webhooks.constructEvent(raw, sig, whSecret);
    } catch (err) {
      console.error("Webhook signature failed", err);
      res.status(400).send("Firma inválida");
      return;
    }

    try {
      switch (event.type) {
        case "checkout.session.completed": {
          const session = event.data.object as Stripe.Checkout.Session;
          const uid = session.metadata?.firebaseUid;
          const planMeta = session.metadata?.plan === "business" ? "business" : "pro";
          if (uid) {
            // Checkout pagado reemplaza un grant admin (el cliente pagó).
            await db.collection("entitlements").doc(uid).set(
              {
                plan: planMeta,
                subscriptionStatus: "active",
                stripeCustomerId: String(session.customer || ""),
                stripeSubscriptionId: String(session.subscription || ""),
                source: "stripe",
                grantExpiresAt: null,
                grantReason: null,
                grantedByUid: null,
                grantId: null,
                updatedAt: nowIso(),
              },
              { merge: true }
            );
          }
          break;
        }
        case "customer.subscription.updated":
        case "customer.subscription.deleted": {
          const sub = event.data.object as Stripe.Subscription;
          const uid = sub.metadata?.firebaseUid;
          if (uid) {
            const existingSnap = await db.collection("entitlements").doc(uid).get();
            const existing = existingSnap.data() ?? {};
            // No pisar acceso gratis otorgado por super admin si Stripe deja de estar activo.
            if (
              existing.source === "admin_grant" &&
              existing.subscriptionStatus === "active" &&
              sub.status !== "active"
            ) {
              await db.collection("entitlements").doc(uid).set(
                {
                  stripeSubscriptionId: sub.id,
                  updatedAt: nowIso(),
                },
                { merge: true }
              );
              break;
            }
            const status = sub.status;
            const periodEnd = new Date(
              (
                sub as unknown as { current_period_end: number }
              ).current_period_end * 1000
            ).toISOString();
            const mapped =
              status === "active"
                ? "active"
                : status === "canceled"
                  ? "canceled"
                  : status === "past_due"
                    ? "past_due"
                    : status;
            const planMeta =
              sub.metadata?.plan === "business" ? "business" : "pro";
            await db.collection("entitlements").doc(uid).set(
              {
                plan: mapped === "active" ? planMeta : "free",
                subscriptionStatus: mapped,
                currentPeriodEnd: periodEnd,
                stripeSubscriptionId: sub.id,
                source: "stripe",
                updatedAt: nowIso(),
              },
              { merge: true }
            );
          }
          break;
        }
        default:
          break;
      }
      res.json({ received: true });
    } catch (e) {
      console.error(e);
      res.status(500).send("Error procesando webhook");
    }
  }
);

export const deleteAccount = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const cots = await userRef.collection("cotizaciones").listDocuments();
  const batch = db.batch();
  for (const doc of cots) {
    batch.delete(doc);
  }
  batch.delete(userRef);
  batch.delete(db.collection("entitlements").doc(uid));
  await batch.commit();
  await admin.auth().deleteUser(uid);
  return { ok: true };
});

export {
  migrateUserToOrganization,
  allocateQuoteNumber,
} from "./migrate";

export {viewQuoteShare, createQuoteShareLink, acceptQuoteShare} from "./share";

export {acceptOrgInvite} from "./team";

export {reportClientError} from "./observability";

export {
  bootstrapPlatformAdmin,
  adminSetPlatformAdmin,
  adminLookupUser,
  adminGrantEntitlement,
  adminRevokeGrant,
  adminListGrants,
  adminGetPlatformStats,
} from "./admin";
