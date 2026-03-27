export type FeasibilityInput = {
  title: string;
  estimatedMinutes: number;
  energyLevel: "low" | "medium" | "high";
  priority: "low" | "medium" | "high";
  availableMinutesToday: number;
};

export function validateFeasibilityInput(raw: unknown): FeasibilityInput {
  if (typeof raw !== "object" || raw === null) {
    throw new Error("Invalid payload");
  }

  const data = raw as Record<string, unknown>;
  const title = String(data.title ?? "").trim();
  const estimatedMinutes = Number(data.estimatedMinutes ?? 0);
  const availableMinutesToday = Number(data.availableMinutesToday ?? 0);
  const energyLevel = String(data.energyLevel ?? "").toLowerCase() as FeasibilityInput["energyLevel"];
  const priority = String(data.priority ?? "").toLowerCase() as FeasibilityInput["priority"];

  if (title.length < 1 || title.length > 160) {
    throw new Error("Title must be between 1 and 160 chars");
  }
  if (!Number.isInteger(estimatedMinutes) || estimatedMinutes < 5 || estimatedMinutes > 720) {
    throw new Error("estimatedMinutes must be an integer between 5 and 720");
  }
  if (!Number.isInteger(availableMinutesToday) || availableMinutesToday < 0 || availableMinutesToday > 1440) {
    throw new Error("availableMinutesToday must be an integer between 0 and 1440");
  }
  if (!["low", "medium", "high"].includes(energyLevel)) {
    throw new Error("energyLevel must be low, medium, or high");
  }
  if (!["low", "medium", "high"].includes(priority)) {
    throw new Error("priority must be low, medium, or high");
  }

  return {
    title,
    estimatedMinutes,
    availableMinutesToday,
    energyLevel,
    priority,
  };
}
