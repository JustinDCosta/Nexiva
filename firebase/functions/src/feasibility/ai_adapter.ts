export type AiSuggestionInput = {
  title: string;
  estimatedMinutes: number;
  availableMinutesToday: number;
};

export type AiSuggestion = {
  recommendation: string;
  confidence: number;
};

export class AiAdapter {
  FutureEnabled = false;

  async suggest(input: AiSuggestionInput): Promise<AiSuggestion> {
    const overload = Math.max(0, input.estimatedMinutes - input.availableMinutesToday);
    if (overload <= 0) {
      return {
        recommendation: "Great fit today. Place it in your next focus window.",
        confidence: 0.85,
      };
    }

    return {
      recommendation: "Split into two smaller sessions or move lower-priority work.",
      confidence: 0.74,
    };
  }
}
