import { initializeApp } from "firebase-admin/app";
import { suggestFeasibility } from "./feasibility/suggest";
import { onTaskCompleted } from "./gamification/onTaskCompleted";
import { onTimeBlockAnalytics } from "./analytics/onTimeBlockAnalytics";

initializeApp();

export {
  suggestFeasibility,
  onTaskCompleted,
  onTimeBlockAnalytics,
};
