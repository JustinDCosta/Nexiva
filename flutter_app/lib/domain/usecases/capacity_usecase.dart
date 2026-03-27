import "package:nexiva/domain/entities/time_block.dart";

class CapacityResult {
  CapacityResult({
    required this.availableMinutes,
    required this.plannedMinutes,
    required this.overloadMinutes,
  });

  final int availableMinutes;
  final int plannedMinutes;
  final int overloadMinutes;
}

class CapacityUseCase {
  CapacityResult evaluate({
    required int dayStartMinute,
    required int dayEndMinute,
    required List<TimeBlock> blocks,
  }) {
    final available = dayEndMinute - dayStartMinute;
    final planned = blocks.fold<int>(0, (sum, b) => sum + b.durationMinutes);
    return CapacityResult(
      availableMinutes: available,
      plannedMinutes: planned,
      overloadMinutes: planned > available ? planned - available : 0,
    );
  }
}
