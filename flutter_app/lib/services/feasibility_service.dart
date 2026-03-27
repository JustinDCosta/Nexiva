import "package:cloud_functions/cloud_functions.dart";

class FeasibilitySuggestion {
  const FeasibilitySuggestion({
    required this.score,
    required this.recommendation,
    required this.source,
    this.aiRecommendation,
    this.aiConfidence,
  });

  final int score;
  final String recommendation;
  final String source;
  final String? aiRecommendation;
  final double? aiConfidence;
}

class FeasibilityService {
  FeasibilityService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<FeasibilitySuggestion> suggest({
    required String title,
    required int estimatedMinutes,
    required int availableMinutesToday,
    required String energyLevel,
    required String priority,
  }) async {
    final callable = _functions.httpsCallable("suggestFeasibility");
    final result = await callable.call<Map<String, dynamic>>({
      "title": title,
      "estimatedMinutes": estimatedMinutes,
      "availableMinutesToday": availableMinutesToday,
      "energyLevel": energyLevel,
      "priority": priority,
    });

    final data = result.data;
    return FeasibilitySuggestion(
      score: (data["score"] as num?)?.toInt() ?? 0,
      recommendation: (data["recommendation"] as String?) ?? "No recommendation",
      source: (data["source"] as String?) ?? "unknown",
      aiRecommendation: data["aiRecommendation"] as String?,
      aiConfidence: (data["aiConfidence"] as num?)?.toDouble(),
    );
  }
}
