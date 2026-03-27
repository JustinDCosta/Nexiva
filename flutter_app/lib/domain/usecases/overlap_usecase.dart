import "package:nexiva/domain/entities/time_block.dart";

class OverlapUseCase {
  bool overlaps(TimeBlock a, TimeBlock b) {
    return a.startMinute < b.endMinute && b.startMinute < a.endMinute;
  }

  bool hasConflict({
    required TimeBlock candidate,
    required List<TimeBlock> existing,
    String? ignoreId,
  }) {
    for (final block in existing) {
      if (ignoreId != null && block.id == ignoreId) {
        continue;
      }
      if (overlaps(candidate, block)) {
        return true;
      }
    }
    return false;
  }

  Set<String> overlappingIds(List<TimeBlock> blocks) {
    final ids = <String>{};
    for (int i = 0; i < blocks.length; i++) {
      for (int j = i + 1; j < blocks.length; j++) {
        if (overlaps(blocks[i], blocks[j])) {
          ids.add(blocks[i].id);
          ids.add(blocks[j].id);
        }
      }
    }
    return ids;
  }
}
