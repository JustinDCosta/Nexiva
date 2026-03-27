import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

const db = getFirestore();

function parseDateKey(dateKey?: string): Date | null {
  if (!dateKey) {
    return null;
  }
  const [y, m, d] = dateKey.split("-").map((value) => Number(value));
  if (!y || !m || !d) {
    return null;
  }
  return new Date(y, m - 1, d);
}

function dayDifference(from: Date, to: Date): number {
  const fromUtc = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
  const toUtc = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((toUtc - fromUtc) / msPerDay);
}

export const onTaskCompleted = onDocumentUpdated("timeBlocks/{blockId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();

  if (!before || !after) {
    return;
  }

  if (before.status === "completed" || after.status !== "completed") {
    return;
  }

  const ownerId = after.ownerId as string | undefined;
  if (!ownerId) {
    logger.warn("Missing ownerId on time block", { blockId: event.params.blockId });
    return;
  }

  const gamificationRef = db.collection("users").doc(ownerId).collection("gamification").doc("summary");

  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(gamificationRef);
    const current = snapshot.exists ? snapshot.data() ?? {} : {};

    const xp = Number(current.xp ?? 0) + 10;
    const completedTasks = Number(current.completedTasks ?? 0) + 1;
    const currentStreak = Number(current.streak ?? 0);
    const level = Math.floor(xp / 500) + 1;
    const completionDateKey = String(after.dateKey ?? "");
    const completionDate = parseDateKey(completionDateKey);
    const lastDate = parseDateKey(String(current.lastCompletedDateKey ?? ""));

    let streak = currentStreak;
    if (completionDate != null) {
      if (lastDate == null) {
        streak = 1;
      } else {
        const delta = dayDifference(lastDate, completionDate);
        if (delta == 0) {
          streak = currentStreak;
        } else if (delta == 1) {
          streak = currentStreak + 1;
        } else {
          streak = 1;
        }
      }
    }

    tx.set(gamificationRef, {
      xp,
      level,
      streak,
      completedTasks,
      lastCompletedDateKey: completionDateKey,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  logger.info("Gamification summary updated", { ownerId, blockId: event.params.blockId });
});
