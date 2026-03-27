import "package:flutter_test/flutter_test.dart";
import "package:nexiva/domain/entities/time_block.dart";
import "package:nexiva/domain/usecases/overlap_usecase.dart";

TimeBlock b({
  required String id,
  required int start,
  required int duration,
}) {
  return TimeBlock(
    id: id,
    ownerId: "u1",
    name: id,
    dateKey: "2026-03-24",
    startMinute: start,
    durationMinutes: duration,
    priority: TaskPriority.medium,
    energy: EnergyLevel.medium,
    category: "Test",
  );
}

void main() {
  final useCase = OverlapUseCase();

  test("overlaps returns true for intersecting ranges", () {
    expect(useCase.overlaps(b(id: "a", start: 60, duration: 30), b(id: "b", start: 80, duration: 45)), isTrue);
  });

  test("overlaps returns false for edge-touching ranges", () {
    expect(useCase.overlaps(b(id: "a", start: 60, duration: 30), b(id: "b", start: 90, duration: 30)), isFalse);
  });

  test("hasConflict respects ignoreId", () {
    final existing = [b(id: "a", start: 120, duration: 60), b(id: "b", start: 300, duration: 30)];
    final candidate = b(id: "a", start: 130, duration: 40);
    expect(useCase.hasConflict(candidate: candidate, existing: existing, ignoreId: "a"), isFalse);
  });

  test("overlappingIds returns both conflicting ids", () {
    final ids = useCase.overlappingIds([
      b(id: "a", start: 120, duration: 60),
      b(id: "b", start: 150, duration: 30),
      b(id: "c", start: 400, duration: 20),
    ]);
    expect(ids.contains("a"), isTrue);
    expect(ids.contains("b"), isTrue);
    expect(ids.contains("c"), isFalse);
  });
}
