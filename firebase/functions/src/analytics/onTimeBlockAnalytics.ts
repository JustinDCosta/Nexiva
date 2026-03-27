import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

const db = getFirestore();

function parseDateKey(dateKey: string): Date {
  const [y, m, d] = dateKey.split("-").map((value) => Number(value));
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

function formatDateKey(date: Date): string {
  const y = date.getFullYear().toString().padStart(4, "0");
  const m = (date.getMonth() + 1).toString().padStart(2, "0");
  const d = date.getDate().toString().padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function startOfWeekMonday(input: Date): Date {
  const normalized = new Date(input.getFullYear(), input.getMonth(), input.getDate());
  const mondayOffset = (normalized.getDay() + 6) % 7;
  normalized.setDate(normalized.getDate() - mondayOffset);
  return normalized;
}

export const onTimeBlockAnalytics = onDocumentWritten("timeBlocks/{blockId}", async (event) => {
  const after = event.data?.after.data();
  const before = event.data?.before.data();

  const ownerId = (after?.ownerId as string | undefined) ?? (before?.ownerId as string | undefined);
  const dateKey = (after?.dateKey as string | undefined) ?? (before?.dateKey as string | undefined);

  if (!ownerId || !dateKey) {
    return;
  }

  const weekStart = startOfWeekMonday(parseDateKey(dateKey));
  const dailyCompleted: number[] = [];
  const dailyPlannedMinutes: number[] = [];
  const dailyCompletedMinutes: number[] = [];

  for (let i = 0; i < 7; i += 1) {
    const day = new Date(weekStart);
    day.setDate(weekStart.getDate() + i);
    const key = formatDateKey(day);

    const daySnapshot = await db
      .collection("timeBlocks")
      .where("ownerId", "==", ownerId)
      .where("dateKey", "==", key)
      .get();

    let plannedMinutes = 0;
    let completedMinutes = 0;
    let completedCount = 0;

    daySnapshot.forEach((doc) => {
      const data = doc.data();
      const duration = Number(data.durationMinutes ?? 0);
      const status = String(data.status ?? "planned");
      plannedMinutes += duration;
      if (status === "completed") {
        completedCount += 1;
        completedMinutes += duration;
      }
    });

    dailyCompleted.push(completedCount);
    dailyPlannedMinutes.push(plannedMinutes);
    dailyCompletedMinutes.push(completedMinutes);
  }

  await db.collection("users").doc(ownerId).collection("analytics").doc("weekly_current").set(
    {
      weekStartDateKey: formatDateKey(weekStart),
      dailyCompleted,
      dailyPlannedMinutes,
      dailyCompletedMinutes,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  logger.info("Weekly analytics summary updated", { ownerId, blockId: event.params.blockId });
});
