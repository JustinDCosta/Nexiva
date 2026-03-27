import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { beforeAll, afterAll, beforeEach, describe, it } from "vitest";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc, getDoc } from "firebase/firestore";

describe("Firestore security rules", () => {
  let testEnv;

  beforeAll(async () => {
    const thisDir = dirname(fileURLToPath(import.meta.url));
    const rules = readFileSync(resolve(thisDir, "..", "firestore.rules"), "utf8");
    testEnv = await initializeTestEnvironment({
      projectId: "nexiva-test",
      firestore: { rules },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  it("allows a user to read/write own profile", async () => {
    const ctx = testEnv.authenticatedContext("u1");
    const db = ctx.firestore();

    await assertSucceeds(setDoc(doc(db, "users/u1"), { name: "Ada" }));
    await assertSucceeds(getDoc(doc(db, "users/u1")));
  });

  it("denies cross-user profile read", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users/u1"), { name: "Owner" });
    });

    const attacker = testEnv.authenticatedContext("u2");
    const db = attacker.firestore();

    await assertFails(getDoc(doc(db, "users/u1")));
  });

  it("denies writing protected gamification summary", async () => {
    const ctx = testEnv.authenticatedContext("u1");
    const db = ctx.firestore();

    await assertFails(setDoc(doc(db, "users/u1/gamification/summary"), { xp: 999999 }));
  });

  it("enforces ownerId on routine create", async () => {
    const ctx = testEnv.authenticatedContext("u1");
    const db = ctx.firestore();

    await assertSucceeds(
      setDoc(doc(db, "routines/r1"), {
        ownerId: "u1",
        name: "Morning routine",
      }),
    );

    await assertFails(
      setDoc(doc(db, "routines/r2"), {
        ownerId: "u2",
        name: "Forged owner",
      }),
    );
  });

  it("enforces ideas ownership", async () => {
    const ctx = testEnv.authenticatedContext("u1");
    const db = ctx.firestore();

    await assertSucceeds(
      setDoc(doc(db, "ideas/i1"), {
        ownerId: "u1",
        title: "Idea ok",
      }),
    );

    await assertFails(
      setDoc(doc(db, "ideas/i2"), {
        ownerId: "u2",
        title: "Should fail",
      }),
    );
  });

  it("enforces timeBlocks duration constraints", async () => {
    const ctx = testEnv.authenticatedContext("u1");
    const db = ctx.firestore();

    await assertSucceeds(
      setDoc(doc(db, "timeBlocks/tb1"), {
        ownerId: "u1",
        durationMinutes: 30,
      }),
    );

    await assertFails(
      setDoc(doc(db, "timeBlocks/tb2"), {
        ownerId: "u1",
        durationMinutes: 0,
      }),
    );
  });

  it("allows users to manage their own calendar integration", async () => {
    const ctx = testEnv.authenticatedContext("u1");
    const db = ctx.firestore();

    await assertSucceeds(
      setDoc(doc(db, "users/u1/integrations/google_calendar"), {
        provider: "google",
        status: "connected",
      }),
    );

    await assertFails(
      setDoc(doc(db, "users/u2/integrations/google_calendar"), {
        provider: "google",
        status: "connected",
      }),
    );
  });

  it("enforces calendar sync job ownership", async () => {
    const owner = testEnv.authenticatedContext("u1");
    const ownerDb = owner.firestore();

    await assertSucceeds(
      setDoc(doc(ownerDb, "calendarSyncJobs/job1"), {
        ownerId: "u1",
        mode: "nexiva_to_google",
      }),
    );

    await assertFails(
      setDoc(doc(ownerDb, "calendarSyncJobs/job2"), {
        ownerId: "u2",
        mode: "nexiva_to_google",
      }),
    );
  });
});
