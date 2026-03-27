import "package:cloud_firestore/cloud_firestore.dart";
import "package:nexiva/data/models/time_block_model.dart";
import "package:nexiva/domain/entities/time_block.dart";

class FirestoreTimeBlockDataSource {
  FirestoreTimeBlockDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection("timeBlocks");

  Stream<List<TimeBlock>> watchByDate(String ownerId, String dateKey) {
    return _col
        .where("ownerId", isEqualTo: ownerId)
        .where("dateKey", isEqualTo: dateKey)
        .orderBy("startMinute")
        .snapshots()
        .map((s) => s.docs.map(TimeBlockModel.fromDoc).toList());
  }

  Future<void> upsert(TimeBlock block) async {
    await _col.doc(block.id).set(TimeBlockModel.toJson(block), SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
