import "dart:async";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";
import "package:nexiva/services/sync_service.dart";

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

class SyncQueueSnapshot {
  const SyncQueueSnapshot({
    required this.pendingCount,
    required this.deadLetterCount,
  });

  final int pendingCount;
  final int deadLetterCount;
}

final syncQueueSnapshotProvider = StreamProvider<SyncQueueSnapshot>((ref) async* {
  final sync = ref.watch(syncServiceProvider);
  yield SyncQueueSnapshot(
    pendingCount: sync.pending().length,
    deadLetterCount: sync.deadLetter().length,
  );

  while (true) {
    await Future<void>.delayed(const Duration(seconds: 3));
    yield SyncQueueSnapshot(
      pendingCount: sync.pending().length,
      deadLetterCount: sync.deadLetter().length,
    );
  }
});

final syncQueueActionsProvider = Provider<SyncQueueActions>((ref) {
  return SyncQueueActions(ref);
});

class SyncQueueActions {
  SyncQueueActions(this._ref);

  final Ref _ref;

  Future<void> retryAllDeadLetters() async {
    final service = _ref.read(syncServiceProvider);
    final ids = service.deadLetter().map((e) => e["opId"] as String?).whereType<String>().toList();
    for (final id in ids) {
      await service.retryDeadLetter(id);
    }
  }

  Future<void> clearDeadLetters() async {
    await _ref.read(syncServiceProvider).clearDeadLetter();
  }
}

final syncBootstrapProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return;
  }

  final sync = ref.watch(syncServiceProvider);

  Future<void> process(Map<String, dynamic> op) async {
    final type = op["type"] as String? ?? "";

    switch (type) {
      case "set_day_window":
        await FirebaseFirestore.instance.collection("users").doc(op["uid"] as String).collection("preferences").doc("app_settings").set({
          "dayStartMinute": op["startMinute"],
          "dayEndMinute": op["endMinute"],
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "set_slot_minutes":
        await FirebaseFirestore.instance.collection("users").doc(op["uid"] as String).collection("preferences").doc("app_settings").set({
          "slotMinutes": op["slotMinutes"],
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "set_theme_mode":
        await FirebaseFirestore.instance.collection("users").doc(op["uid"] as String).collection("preferences").doc("app_settings").set({
          "themeMode": op["themeMode"],
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "set_notification_prefs":
        await FirebaseFirestore.instance.collection("users").doc(op["uid"] as String).collection("preferences").doc("app_settings").set({
          "notificationsEnabled": op["notificationsEnabled"],
          "reminderLeadMinutes": op["reminderLeadMinutes"],
          "quietHoursStartMinute": op["quietHoursStartMinute"],
          "quietHoursEndMinute": op["quietHoursEndMinute"],
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "set_calendar_sync_mode":
        await FirebaseFirestore.instance.collection("users").doc(op["uid"] as String).collection("preferences").doc("app_settings").set({
          "calendarSyncMode": op["calendarSyncMode"],
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "mark_idea_scheduled":
        await FirebaseFirestore.instance.collection("ideas").doc(op["ideaId"] as String).set({
          "status": "scheduled",
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "upsert_time_block":
      case "schedule_idea_as_block":
        await FirebaseFirestore.instance.collection("timeBlocks").doc(op["blockId"] as String).set({
          "ownerId": op["ownerId"],
          "name": op["name"],
          "dateKey": op["dateKey"],
          "startMinute": op["startMinute"],
          "durationMinutes": op["durationMinutes"],
          "priority": op["priority"],
          "energy": op["energy"],
          "category": op["category"],
          "status": "planned",
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "move_time_block":
        await FirebaseFirestore.instance.collection("timeBlocks").doc(op["blockId"] as String).set({
          "startMinute": op["startMinute"],
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "resize_time_block":
        await FirebaseFirestore.instance.collection("timeBlocks").doc(op["blockId"] as String).set({
          "durationMinutes": op["durationMinutes"],
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case "duplicate_template":
        final source = await FirebaseFirestore.instance.collection("routines").doc(op["sourceId"] as String).get();
        final data = source.data();
        if (data == null) {
          return;
        }
        await FirebaseFirestore.instance.collection("routines").add({
          "ownerId": op["uid"],
          "name": "${(data["name"] as String?) ?? "Template"} Copy",
          "isTemplate": true,
          "dayStartMinute": (data["dayStartMinute"] as int?) ?? 360,
          "dayEndMinute": (data["dayEndMinute"] as int?) ?? 1320,
          "slotMinutes": (data["slotMinutes"] as int?) ?? 15,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      case "seed_template":
        await FirebaseFirestore.instance.collection("routines").add({
          "ownerId": op["uid"],
          "name": op["name"],
          "isTemplate": true,
          "dayStartMinute": op["dayStartMinute"],
          "dayEndMinute": op["dayEndMinute"],
          "slotMinutes": op["slotMinutes"],
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      case "seed_idea":
        await FirebaseFirestore.instance.collection("ideas").add({
          "ownerId": op["uid"],
          "title": op["title"],
          "description": op["description"],
          "estimatedMinutes": op["estimatedMinutes"],
          "energy": op["energy"],
          "priority": op["priority"],
          "status": "idea",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      default:
        return;
    }
  }

  Future<void> drain() async {
    await sync.drain(process);
  }

  sync.init().then((_) => drain());
  final timer = Timer.periodic(const Duration(seconds: 15), (_) {
    drain();
  });

  ref.onDispose(timer.cancel);
});
