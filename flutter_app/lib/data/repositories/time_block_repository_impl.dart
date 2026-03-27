import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/data/datasources/remote/firestore_time_block_datasource.dart";
import "package:nexiva/domain/entities/time_block.dart";
import "package:nexiva/domain/repositories/time_block_repository.dart";

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final timeBlockRepositoryProvider = Provider<TimeBlockRepository>((ref) {
  final ds = FirestoreTimeBlockDataSource(ref.watch(firestoreProvider));
  return TimeBlockRepositoryImpl(ds);
});

class TimeBlockRepositoryImpl implements TimeBlockRepository {
  TimeBlockRepositoryImpl(this._ds);

  final FirestoreTimeBlockDataSource _ds;

  @override
  Stream<List<TimeBlock>> watchByDate(String ownerId, String dateKey) {
    return _ds.watchByDate(ownerId, dateKey);
  }

  @override
  Future<void> upsert(TimeBlock block) {
    return _ds.upsert(block);
  }

  @override
  Future<void> delete(String id) {
    return _ds.delete(id);
  }
}
