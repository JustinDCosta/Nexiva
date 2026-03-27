import "package:nexiva/domain/entities/time_block.dart";

class FeasibilityResult {
  FeasibilityResult({
    required this.score,
    required this.message,
  });

  final int score;
  final String message;
}

class FeasibilityUseCase {
  FeasibilityResult evaluate({
    required TimeBlock candidate,
    required int availableMinutes,
  }) {
    final overload = candidate.durationMinutes - availableMinutes;
    if (overload <= 0) {
      return FeasibilityResult(score: 90, message: "Fits today");
    }

    if (overload <= 30) {
      return FeasibilityResult(score: 65, message: "Shorten task by $overload min");
    }

    return FeasibilityResult(score: 40, message: "Move to tomorrow or split into sessions");
  }
}
