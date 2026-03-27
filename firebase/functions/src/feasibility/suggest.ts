import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { AiAdapter } from "./ai_adapter";
import { validateFeasibilityInput } from "../utils/validators";

function scorePayload(input: ReturnType<typeof validateFeasibilityInput>) {
  const overload = Math.max(0, input.estimatedMinutes - input.availableMinutesToday);
  const timeFitScore = Math.max(0, 100 - Math.round((overload / Math.max(input.estimatedMinutes, 1)) * 100));

  const priorityBoost = input.priority === "high" ? 20 : input.priority === "medium" ? 10 : 0;
  const energyPenalty = input.energyLevel === "high" ? 5 : input.energyLevel === "medium" ? 0 : -5;

  const score = Math.max(0, Math.min(100, timeFitScore + priorityBoost + energyPenalty));

  let recommendation = "Fits today";
  if (overload > 0) {
    recommendation = overload > 60
      ? "Move to tomorrow or split into two sessions"
      : "Shorten duration or move a lower-priority task";
  }

  return {
    score,
    overloadMinutes: overload,
    recommendation,
    suggestedDuration: overload > 0 ? Math.max(15, input.estimatedMinutes - overload) : input.estimatedMinutes,
  };
}

export const suggestFeasibility = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  try {
    const input = validateFeasibilityInput(request.data);
    const result = scorePayload(input);
    const aiEnabled = process.env.AI_PROVIDER === "enabled";
    const ai = new AiAdapter();
    const aiSuggestion = aiEnabled
      ? await ai.suggest({
          title: input.title,
          estimatedMinutes: input.estimatedMinutes,
          availableMinutesToday: input.availableMinutesToday,
        })
      : null;

    logger.info("Feasibility generated", {
      uid: request.auth.uid,
      title: input.title,
      score: result.score,
    });

    return {
      ...result,
      source: aiSuggestion == null ? "deterministic-v1" : "deterministic+ai-v1",
      aiRecommendation: aiSuggestion?.recommendation,
      aiConfidence: aiSuggestion?.confidence,
      generatedAt: new Date().toISOString(),
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invalid request";
    throw new HttpsError("invalid-argument", message);
  }
});
