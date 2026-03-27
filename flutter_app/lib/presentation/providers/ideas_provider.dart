import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/domain/entities/idea.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";
import "package:nexiva/presentation/providers/sync_provider.dart";
import "package:nexiva/services/feasibility_service.dart";

final ideasProvider = StreamProvider<List<Idea>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return Stream.value(const <Idea>[]);
  }

  return FirebaseFirestore.instance.collection("ideas").where("ownerId", isEqualTo: uid).snapshots().map((snapshot) {
    final ideas = snapshot.docs.map((doc) {
      final d = doc.data();
      final createdAt = (d["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now();
      return Idea(
        id: doc.id,
        ownerId: (d["ownerId"] as String?) ?? uid,
        title: (d["title"] as String?) ?? "Idea",
        estimatedMinutes: (d["estimatedMinutes"] as int?) ?? 30,
        createdAt: createdAt,
        status: _ideaStatusFromString(d["status"] as String?),
      );
    }).toList();

    ideas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ideas;
  });
});

final feasibilityServiceProvider = Provider<FeasibilityService>((ref) {
  return FeasibilityService();
});

final aiSuggestionProvider = FutureProvider.family<FeasibilitySuggestion, ({String title, int estimatedMinutes, int availableMinutesToday})>((ref, req) async {
  final service = ref.watch(feasibilityServiceProvider);
  return service.suggest(
    title: req.title,
    estimatedMinutes: req.estimatedMinutes,
    availableMinutesToday: req.availableMinutesToday,
    energyLevel: "medium",
    priority: "medium",
  );
});

IdeaStatus _ideaStatusFromString(String? value) {
  switch (value) {
    case "scheduled":
      return IdeaStatus.scheduled;
    case "archived":
      return IdeaStatus.archived;
    default:
      return IdeaStatus.sandbox;
  }
}

final ideasActionsProvider = Provider<IdeasActions>((ref) {
  return IdeasActions(ref);
});

final ideasBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(ideasActionsProvider).ensureSeedIdeas();
});

class IdeasActions {
  IdeasActions(this._ref);

  final Ref _ref;

  Future<void> markScheduled(String id) async {
    try {
      await FirebaseFirestore.instance.collection("ideas").doc(id).set({
        "status": "scheduled",
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "mark_idea_scheduled",
        "ideaId": id,
      });
    }
  }

  Future<void> createIdea({
    required String title,
    required int estimatedMinutes,
  }) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    await FirebaseFirestore.instance.collection("ideas").add({
      "ownerId": uid,
      "title": title,
      "estimatedMinutes": estimatedMinutes,
      "status": "sandbox",
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateIdea({
    required String id,
    required String title,
    required int estimatedMinutes,
  }) async {
    await FirebaseFirestore.instance.collection("ideas").doc(id).set({
      "title": title,
      "estimatedMinutes": estimatedMinutes,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureSeedIdeas() async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    final existing = await FirebaseFirestore.instance.collection("ideas").where("ownerId", isEqualTo: uid).limit(1).get();
    if (existing.docs.isNotEmpty) {
      return;
    }

    final seed = [
      {"title": "Explore async deep-work block", "estimatedMinutes": 90},
      {"title": "Prototype motion refresh", "estimatedMinutes": 120},
      {"title": "Write launch narrative", "estimatedMinutes": 45},
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final item in seed) {
      final doc = FirebaseFirestore.instance.collection("ideas").doc();
      batch.set(doc, {
        "ownerId": uid,
        "title": item["title"],
        "estimatedMinutes": item["estimatedMinutes"],
        "status": "sandbox",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "seed_ideas",
        "uid": uid,
      });
    }
  }
}
