/**
 * Pruebas de aislamiento de reglas Firestore.
 * Requiere emuladores: firebase emulators:exec --only firestore "npm test" (desde test/rules)
 */
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "../..");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "cotiapp-rules-test",
    firestore: {
      rules: readFileSync(resolve(root, "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe("users/{uid} perfil editable", () => {
  test("owner puede crear perfil solo con campos editables", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertSucceeds(
      setDoc(doc(alice.firestore(), "users/alice"), {
        uid: "alice",
        email: "a@b.com",
        displayName: "Alice",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
    );
  });

  test("owner NO puede crear perfil con plan pro", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "users/alice"), {
        uid: "alice",
        email: "a@b.com",
        displayName: "Alice",
        plan: "pro",
        subscriptionStatus: "active",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
    );
  });

  test("owner NO puede autoasignarse Pro en update", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), {
        uid: "alice",
        email: "a@b.com",
        displayName: "Alice",
        plan: "free",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
    });

    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      updateDoc(doc(alice.firestore(), "users/alice"), {
        plan: "pro",
        subscriptionStatus: "active",
      })
    );
  });

  test("otro usuario no lee el perfil", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), {
        uid: "alice",
        email: "a@b.com",
        displayName: "Alice",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
    });
    const bob = testEnv.authenticatedContext("bob");
    await assertFails(getDoc(doc(bob.firestore(), "users/alice")));
  });
});

describe("entitlements/{uid}", () => {
  test("C02: owner NO puede crear entitlements (solo backend)", async () => {
    const alice = testEnv.authenticatedContext("alice");
    const trialEnds = new Date(
      Date.now() + 14 * 24 * 60 * 60 * 1000
    ).toISOString();
    await assertFails(
      setDoc(doc(alice.firestore(), "entitlements/alice"), {
        uid: "alice",
        plan: "free",
        subscriptionStatus: "trialing",
        trialEndsAt: trialEnds,
        source: "signup",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
    );
  });

  test("owner NO puede crear entitlements pro", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "entitlements/alice"), {
        uid: "alice",
        plan: "pro",
        subscriptionStatus: "active",
        source: "signup",
        trialEndsAt: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
    );
  });

  test("owner NO puede actualizar entitlements a Pro", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "entitlements/alice"), {
        uid: "alice",
        plan: "free",
        subscriptionStatus: "trialing",
        trialEndsAt: new Date().toISOString(),
        source: "signup",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
    });
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      updateDoc(doc(alice.firestore(), "entitlements/alice"), {
        plan: "pro",
        subscriptionStatus: "active",
      })
    );
  });

  test("C02: owner NO puede crear trialEndsAt en 2030", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "entitlements/alice"), {
        uid: "alice",
        plan: "free",
        subscriptionStatus: "trialing",
        trialEndsAt: "2030-01-01T00:00:00.000Z",
        source: "signup",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
    );
  });

  test("C02: owner NO puede borrar entitlements", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "entitlements/alice"), {
        uid: "alice",
        plan: "free",
        subscriptionStatus: "trialing",
        trialEndsAt: new Date(Date.now() + 7 * 864e5).toISOString(),
        source: "signup",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
    });
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(deleteDoc(doc(alice.firestore(), "entitlements/alice")));
  });
});

describe("organizations/{orgId} aislamiento", () => {
  const now = () => new Date().toISOString();

  async function seedOrgWithMember(orgId, uid, role = "owner") {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `organizations/${orgId}`), {
        id: orgId,
        name: "Org",
        ownerUid: uid,
        currency: "USD",
        quotePrefix: "COT",
        createdAt: now(),
        updatedAt: now(),
      });
      await setDoc(doc(db, `organizations/${orgId}/members/${uid}`), {
        organizationId: orgId,
        uid,
        role,
        status: "active",
        email: `${uid}@test.com`,
        createdAt: now(),
        updatedAt: now(),
      });
    });
  }

  test("miembro activo lee la org; externo no", async () => {
    await seedOrgWithMember("org1", "alice");
    const alice = testEnv.authenticatedContext("alice");
    const bob = testEnv.authenticatedContext("bob");
    await assertSucceeds(getDoc(doc(alice.firestore(), "organizations/org1")));
    await assertFails(getDoc(doc(bob.firestore(), "organizations/org1")));
  });

  test("sales escribe quote; readonly no", async () => {
    await seedOrgWithMember("org2", "alice", "owner");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "organizations/org2/members/carol"), {
        organizationId: "org2",
        uid: "carol",
        role: "readonly",
        status: "active",
        createdAt: now(),
        updatedAt: now(),
      });
      await setDoc(doc(ctx.firestore(), "organizations/org2/members/dave"), {
        organizationId: "org2",
        uid: "dave",
        role: "sales",
        status: "active",
        createdAt: now(),
        updatedAt: now(),
      });
    });

    const dave = testEnv.authenticatedContext("dave");
    const carol = testEnv.authenticatedContext("carol");
    const quote = {
      organizationId: "org2",
      number: "COT-1",
      status: "draft",
      totalCents: 100,
      createdAt: now(),
      updatedAt: now(),
    };
    await assertSucceeds(
      setDoc(doc(dave.firestore(), "organizations/org2/quotes/q1"), quote)
    );
    await assertFails(
      setDoc(doc(carol.firestore(), "organizations/org2/quotes/q2"), quote)
    );
  });

  test("activities son append-only", async () => {
    await seedOrgWithMember("org3", "alice");
    const alice = testEnv.authenticatedContext("alice");
    const activity = {
      id: "a1",
      organizationId: "org3",
      type: "quote_created",
      actorUid: "alice",
      message: "test",
      createdAt: now(),
    };
    await assertSucceeds(
      setDoc(doc(alice.firestore(), "organizations/org3/activities/a1"), activity)
    );
    await assertFails(
      updateDoc(doc(alice.firestore(), "organizations/org3/activities/a1"), {
        message: "hack",
      })
    );
  });

  test("C04: admin NO puede crear miembro ajeno (solo acceptOrgInvite)", async () => {
    await seedOrgWithMember("org4", "alice", "owner");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "organizations/org4/members/alice"), {
        organizationId: "org4",
        uid: "alice",
        role: "admin",
        status: "active",
        createdAt: now(),
        updatedAt: now(),
      });
    });
    // Re-seed alice as admin for write attempt
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "organizations/org4/members/alice"), {
        organizationId: "org4",
        uid: "alice",
        role: "admin",
        status: "active",
        email: "alice@test.com",
        createdAt: now(),
        updatedAt: now(),
      });
    });
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "organizations/org4/members/bob"), {
        organizationId: "org4",
        uid: "bob",
        role: "sales",
        status: "active",
        createdAt: now(),
        updatedAt: now(),
      })
    );
  });

  test("C04: invitee NO puede marcar invitación como accepted", async () => {
    await seedOrgWithMember("org5", "alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "organizations/org5/invites/inv1"), {
        organizationId: "org5",
        email: "bob@test.com",
        role: "sales",
        invitedByUid: "alice",
        token: "tokensecretvalue12",
        status: "pending",
        expiresAt: new Date(Date.now() + 864e5).toISOString(),
        createdAt: now(),
      });
    });
    const bob = testEnv.authenticatedContext("bob", {
      email: "bob@test.com",
    });
    await assertFails(
      updateDoc(doc(bob.firestore(), "organizations/org5/invites/inv1"), {
        status: "accepted",
      })
    );
  });

  test("C04: owner NO puede cambiar ownerUid de la org", async () => {
    await seedOrgWithMember("org6", "alice");
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      updateDoc(doc(alice.firestore(), "organizations/org6"), {
        ownerUid: "bob",
      })
    );
  });
});
