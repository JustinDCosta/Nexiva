import "package:cloud_firestore/cloud_firestore.dart";
import "package:nexiva/domain/entities/time_block.dart";

class TimeBlockModel {
  const TimeBlockModel._();

  static Map<String, dynamic> toJson(TimeBlock block) {
    return {
      "ownerId": block.ownerId,
      "name": block.name,
      "dateKey": block.dateKey,
      "startMinute": block.startMinute,
      "durationMinutes": block.durationMinutes,
      "priority": block.priority.name,
      "energy": block.energy.name,
      "category": block.category,
      "status": block.status.name,
      "updatedAt": FieldValue.serverTimestamp(),
    };
  }

  static TimeBlock fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TimeBlock(
      id: doc.id,
      ownerId: (d["ownerId"] as String?) ?? "",
      name: (d["name"] as String?) ?? "Untitled",
      dateKey: (d["dateKey"] as String?) ?? "",
      startMinute: (d["startMinute"] as int?) ?? 540,
      durationMinutes: (d["durationMinutes"] as int?) ?? 30,
      priority: TaskPriority.values.byName((d["priority"] as String?) ?? "medium"),
      energy: EnergyLevel.values.byName((d["energy"] as String?) ?? "medium"),
      category: (d["category"] as String?) ?? "General",
      status: BlockStatus.values.byName((d["status"] as String?) ?? "planned"),
    );
  }
}
