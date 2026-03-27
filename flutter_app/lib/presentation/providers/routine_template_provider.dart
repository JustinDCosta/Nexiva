import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/domain/entities/routine.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";
import "package:nexiva/presentation/providers/sync_provider.dart";

final routineTemplatesProvider = StreamProvider<List<RoutineTemplate>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return Stream.value(const <RoutineTemplate>[]);
  }

  return FirebaseFirestore.instance
      .collection("routines")
      .where("ownerId", isEqualTo: uid)
      .where("isTemplate", isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return RoutineTemplate(
        id: doc.id,
        ownerId: (d["ownerId"] as String?) ?? uid,
        name: (d["name"] as String?) ?? "Template",
        dayStartMinute: (d["dayStartMinute"] as int?) ?? 6 * 60,
        dayEndMinute: (d["dayEndMinute"] as int?) ?? 22 * 60,
        slotMinutes: (d["slotMinutes"] as int?) ?? 15,
      );
    }).toList();
  });
});

final routineTemplateActionsProvider = Provider<RoutineTemplateActions>((ref) {
  return RoutineTemplateActions(ref);
});

final routineTemplatesBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(routineTemplateActionsProvider).ensureSeedTemplates();
});

class RoutineTemplateActions {
  RoutineTemplateActions(this._ref);

  final Ref _ref;

  Future<void> duplicateTemplate(String id) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    final sourceDoc = await FirebaseFirestore.instance.collection("routines").doc(id).get();
    final source = sourceDoc.data();
    if (source == null) {
      return;
    }

    final payload = {
      "ownerId": uid,
      "name": "${(source["name"] as String?) ?? "Template"} Copy",
      "isTemplate": true,
      "dayStartMinute": (source["dayStartMinute"] as int?) ?? 6 * 60,
      "dayEndMinute": (source["dayEndMinute"] as int?) ?? 22 * 60,
      "slotMinutes": (source["slotMinutes"] as int?) ?? 15,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection("routines").add(payload);
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "duplicate_template",
        "uid": uid,
        "sourceId": id,
      });
    }
  }

  Future<void> createTemplate({
    required String name,
    required int dayStartMinute,
    required int dayEndMinute,
    required int slotMinutes,
  }) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    await FirebaseFirestore.instance.collection("routines").add({
      "ownerId": uid,
      "name": name,
      "isTemplate": true,
      "dayStartMinute": dayStartMinute,
      "dayEndMinute": dayEndMinute,
      "slotMinutes": slotMinutes,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTemplate({
    required String id,
    required String name,
    required int dayStartMinute,
    required int dayEndMinute,
    required int slotMinutes,
  }) async {
    await FirebaseFirestore.instance.collection("routines").doc(id).set({
      "name": name,
      "dayStartMinute": dayStartMinute,
      "dayEndMinute": dayEndMinute,
      "slotMinutes": slotMinutes,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureSeedTemplates() async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection("routines")
        .where("ownerId", isEqualTo: uid)
        .where("isTemplate", isEqualTo: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final templates = [
      {
        "name": "Morning Deep Work",
        "dayStartMinute": 7 * 60,
        "dayEndMinute": 11 * 60,
        "slotMinutes": 30,
      },
      {
        "name": "Balanced Day",
        "dayStartMinute": 6 * 60,
        "dayEndMinute": 21 * 60,
        "slotMinutes": 15,
      },
      {
        "name": "Evening Creative",
        "dayStartMinute": 10 * 60,
        "dayEndMinute": 23 * 60,
        "slotMinutes": 20,
      },
    ];

    for (final template in templates) {
      final doc = FirebaseFirestore.instance.collection("routines").doc();
      batch.set(doc, {
        "ownerId": uid,
        "isTemplate": true,
        ...template,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "seed_templates",
        "uid": uid,
      });
    }
  }
}
