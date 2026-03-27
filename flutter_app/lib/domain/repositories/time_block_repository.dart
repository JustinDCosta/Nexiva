import "package:nexiva/domain/entities/time_block.dart";

abstract class TimeBlockRepository {
  Stream<List<TimeBlock>> watchByDate(String ownerId, String dateKey);
  Future<void> upsert(TimeBlock block);
  Future<void> delete(String id);
}
