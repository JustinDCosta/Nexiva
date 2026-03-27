import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";

class WeeklyAnalytics {
  const WeeklyAnalytics({
    required this.dailyCompleted,
    required this.dailyPlannedMinutes,
    required this.dailyCompletedMinutes,
  });

  final List<int> dailyCompleted;
  final List<int> dailyPlannedMinutes;
  final List<int> dailyCompletedMinutes;

  static const empty = WeeklyAnalytics(
    dailyCompleted: [0, 0, 0, 0, 0, 0, 0],
    dailyPlannedMinutes: [0, 0, 0, 0, 0, 0, 0],
    dailyCompletedMinutes: [0, 0, 0, 0, 0, 0, 0],
  );

  factory WeeklyAnalytics.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return empty;
    }

    List<int> toIntList(dynamic value) {
      if (value is! List) {
        return [0, 0, 0, 0, 0, 0, 0];
      }
      return value.take(7).map((e) => (e as num?)?.toInt() ?? 0).toList(growable: false)
        ..addAll(List<int>.filled(7 - value.take(7).length, 0));
    }

    return WeeklyAnalytics(
      dailyCompleted: toIntList(json["dailyCompleted"]),
      dailyPlannedMinutes: toIntList(json["dailyPlannedMinutes"]),
      dailyCompletedMinutes: toIntList(json["dailyCompletedMinutes"]),
    );
  }
}

class GamificationSummary {
  const GamificationSummary({
    required this.xp,
    required this.level,
    required this.completedTasks,
    required this.streak,
  });

  final int xp;
  final int level;
  final int completedTasks;
  final int streak;

  static const empty = GamificationSummary(xp: 0, level: 1, completedTasks: 0, streak: 0);

  factory GamificationSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return empty;
    }
    return GamificationSummary(
      xp: (json["xp"] as num?)?.toInt() ?? 0,
      level: (json["level"] as num?)?.toInt() ?? 1,
      completedTasks: (json["completedTasks"] as num?)?.toInt() ?? 0,
      streak: (json["streak"] as num?)?.toInt() ?? 0,
    );
  }
}

final weeklyAnalyticsProvider = StreamProvider<WeeklyAnalytics>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return Stream.value(WeeklyAnalytics.empty);
  }

  return FirebaseFirestore.instance.collection("users").doc(uid).collection("analytics").doc("weekly_current").snapshots().map(
        (snapshot) => WeeklyAnalytics.fromJson(snapshot.data()),
      );
});

final gamificationSummaryProvider = StreamProvider<GamificationSummary>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return Stream.value(GamificationSummary.empty);
  }

  return FirebaseFirestore.instance.collection("users").doc(uid).collection("gamification").doc("summary").snapshots().map(
        (snapshot) => GamificationSummary.fromJson(snapshot.data()),
      );
});
