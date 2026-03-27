import "dart:math";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/data/repositories/time_block_repository_impl.dart";
import "package:nexiva/domain/entities/routine.dart";
import "package:nexiva/domain/entities/time_block.dart";
import "package:nexiva/domain/usecases/overlap_usecase.dart";
import "package:nexiva/presentation/providers/app_settings_provider.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";
import "package:nexiva/presentation/providers/sync_provider.dart";

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

String _toDateKey(DateTime date) {
  return "${date.year.toString().padLeft(4, "0")}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
}

final timelineBlocksProvider = StreamProvider<List<TimeBlock>>((ref) {
  final date = ref.watch(selectedDateProvider);
  final dateKey = _toDateKey(date);
  final ownerId = ref.watch(currentUserIdProvider);
  if (ownerId == null) {
    return Stream.value(const <TimeBlock>[]);
  }

  return ref.watch(timeBlockRepositoryProvider).watchByDate(ownerId, dateKey);
});

final timelineControllerProvider = Provider<TimelineController>((ref) {
  return TimelineController(ref);
});

class TimelineController {
  TimelineController(this._ref);

  final Ref _ref;
  final OverlapUseCase _overlap = OverlapUseCase();

  Future<void> addSampleBlock() async {
    final ownerId = _ref.read(currentUserIdProvider);
    if (ownerId == null) {
      return;
    }

    final date = _ref.read(selectedDateProvider);
    final settings = _ref.read(appSettingsProvider);
    final dateKey = _toDateKey(date);

    final block = TimeBlock(
      id: "tb-${DateTime.now().millisecondsSinceEpoch}",
      ownerId: ownerId,
      name: "Focus Sprint",
      dateKey: dateKey,
      startMinute: settings.dayStartMinute + 90,
      durationMinutes: 60,
      priority: TaskPriority.high,
      energy: EnergyLevel.high,
      category: "Deep Work",
    );

    try {
      await _ref.read(timeBlockRepositoryProvider).upsert(block);
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "upsert_time_block",
        "blockId": block.id,
        "ownerId": block.ownerId,
        "name": block.name,
        "dateKey": block.dateKey,
        "startMinute": block.startMinute,
        "durationMinutes": block.durationMinutes,
        "priority": block.priority.name,
        "energy": block.energy.name,
        "category": block.category,
      });
    }
  }

  Future<void> moveBlock(TimeBlock block, int deltaMinutes) async {
    final ownerId = _ref.read(currentUserIdProvider);
    if (ownerId == null) {
      return;
    }

    final settings = _ref.read(appSettingsProvider);
    final date = _ref.read(selectedDateProvider);
    final dateKey = _toDateKey(date);
    final blocks = await _ref.read(timeBlockRepositoryProvider).watchByDate(ownerId, dateKey).first;

    final slot = settings.slotMinutes;
    final maxStart = settings.dayEndMinute - block.durationMinutes;
    final snapped = ((block.startMinute + deltaMinutes) / slot).round() * slot;
    final nextStartRaw = max(settings.dayStartMinute, min(maxStart, snapped));

    int nextStart = nextStartRaw;
    TimeBlock updated = block.copyWith(startMinute: nextStart);
    while (_overlap.hasConflict(candidate: updated, existing: blocks, ignoreId: block.id) && nextStart + block.durationMinutes <= settings.dayEndMinute) {
      nextStart += slot;
      updated = block.copyWith(startMinute: nextStart);
    }

    if (_overlap.hasConflict(candidate: updated, existing: blocks, ignoreId: block.id)) {
      return;
    }

    try {
      await _ref.read(timeBlockRepositoryProvider).upsert(updated);
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "move_time_block",
        "blockId": updated.id,
        "startMinute": updated.startMinute,
      });
    }
  }

  Future<void> resizeBlock(TimeBlock block, int deltaMinutes) async {
    final ownerId = _ref.read(currentUserIdProvider);
    if (ownerId == null) {
      return;
    }

    final settings = _ref.read(appSettingsProvider);
    final date = _ref.read(selectedDateProvider);
    final dateKey = _toDateKey(date);
    final blocks = await _ref.read(timeBlockRepositoryProvider).watchByDate(ownerId, dateKey).first;

    final slot = settings.slotMinutes;
    final snappedDelta = (deltaMinutes / slot).round() * slot;
    final minDuration = max(15, slot);
    int nextDuration = max(minDuration, block.durationMinutes + snappedDelta);
    final maxDuration = settings.dayEndMinute - block.startMinute;
    nextDuration = min(nextDuration, maxDuration);

    TimeBlock updated = block.copyWith(durationMinutes: nextDuration);
    while (_overlap.hasConflict(candidate: updated, existing: blocks, ignoreId: block.id) && nextDuration - slot >= minDuration) {
      nextDuration -= slot;
      updated = block.copyWith(durationMinutes: nextDuration);
    }

    if (_overlap.hasConflict(candidate: updated, existing: blocks, ignoreId: block.id)) {
      return;
    }

    try {
      await _ref.read(timeBlockRepositoryProvider).upsert(updated);
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "resize_time_block",
        "blockId": updated.id,
        "durationMinutes": updated.durationMinutes,
      });
    }
  }

  Future<void> addBlockFromIdea({
    required String title,
    required int durationMinutes,
    TaskPriority priority = TaskPriority.medium,
    EnergyLevel energy = EnergyLevel.medium,
    String category = "Idea",
  }) async {
    final ownerId = _ref.read(currentUserIdProvider);
    if (ownerId == null) {
      return;
    }

    final date = _ref.read(selectedDateProvider);
    final settings = _ref.read(appSettingsProvider);
    final dateKey = _toDateKey(date);
    final blocks = await _ref.read(timeBlockRepositoryProvider).watchByDate(ownerId, dateKey).first;

    int startMinute = settings.dayStartMinute;
    for (final block in blocks) {
      if (block.endMinute <= startMinute) {
        continue;
      }
      if (block.startMinute - startMinute >= durationMinutes) {
        break;
      }
      startMinute = block.endMinute;
    }

    if (startMinute + durationMinutes > settings.dayEndMinute) {
      startMinute = max(settings.dayStartMinute, settings.dayEndMinute - durationMinutes);
    }

    final block = TimeBlock(
      id: "tb-${DateTime.now().millisecondsSinceEpoch}",
      ownerId: ownerId,
      name: title,
      dateKey: dateKey,
      startMinute: startMinute,
      durationMinutes: durationMinutes,
      priority: priority,
      energy: energy,
      category: category,
    );

    try {
      await _ref.read(timeBlockRepositoryProvider).upsert(block);
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "schedule_idea_as_block",
        "blockId": block.id,
        "ownerId": block.ownerId,
        "name": block.name,
        "dateKey": block.dateKey,
        "startMinute": block.startMinute,
        "durationMinutes": block.durationMinutes,
        "priority": block.priority.name,
        "energy": block.energy.name,
        "category": block.category,
      });
    }
  }

  Future<int?> addBlockFromIdeaAtMinute({
    required String title,
    required int durationMinutes,
    required int startMinute,
    TaskPriority priority = TaskPriority.medium,
    EnergyLevel energy = EnergyLevel.medium,
    String category = "Idea",
  }) async {
    final ownerId = _ref.read(currentUserIdProvider);
    if (ownerId == null) {
      return null;
    }

    final date = _ref.read(selectedDateProvider);
    final settings = _ref.read(appSettingsProvider);
    final dateKey = _toDateKey(date);
    final blocks = await _ref.read(timeBlockRepositoryProvider).watchByDate(ownerId, dateKey).first;
    final slot = settings.slotMinutes;
    final snapped = (startMinute / slot).round() * slot;
    int boundedStart = max(settings.dayStartMinute, min(settings.dayEndMinute - durationMinutes, snapped));

    TimeBlock block = TimeBlock(
      id: "tb-${DateTime.now().millisecondsSinceEpoch}",
      ownerId: ownerId,
      name: title,
      dateKey: dateKey,
      startMinute: boundedStart,
      durationMinutes: durationMinutes,
      priority: priority,
      energy: energy,
      category: category,
    );

    while (_overlap.hasConflict(candidate: block, existing: blocks) && boundedStart + durationMinutes <= settings.dayEndMinute) {
      boundedStart += slot;
      block = block.copyWith(startMinute: boundedStart);
    }

    if (_overlap.hasConflict(candidate: block, existing: blocks)) {
      return null;
    }

    try {
      await _ref.read(timeBlockRepositoryProvider).upsert(block);
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "schedule_idea_as_block",
        "blockId": block.id,
        "ownerId": block.ownerId,
        "name": block.name,
        "dateKey": block.dateKey,
        "startMinute": block.startMinute,
        "durationMinutes": block.durationMinutes,
        "priority": block.priority.name,
        "energy": block.energy.name,
        "category": block.category,
      });
    }

    return boundedStart;
  }

  Future<void> applyTemplate(RoutineTemplate template) async {
    await _ref.read(appSettingsActionsProvider).setDayWindow(
          startMinute: template.dayStartMinute,
          endMinute: template.dayEndMinute,
        );
    await _ref.read(appSettingsActionsProvider).setSlotMinutes(template.slotMinutes);
  }
}
