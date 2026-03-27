import "package:cloud_firestore/cloud_firestore.dart";
import "package:google_sign_in/google_sign_in.dart";

class CalendarService {
  CalendarService(this._firestore);

  final FirebaseFirestore _firestore;

  GoogleSignIn _googleSignIn() {
    return GoogleSignIn(
      scopes: const [
        "email",
        "https://www.googleapis.com/auth/calendar.events",
      ],
    );
  }

  Future<void> connect(String uid) async {
    final account = await _googleSignIn().signIn();
    if (account == null) {
      return;
    }

    await _firestore.collection("users").doc(uid).collection("integrations").doc("google_calendar").set({
      "provider": "google",
      "email": account.email,
      "displayName": account.displayName,
      "status": "connected",
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> disconnect(String uid) async {
    await _googleSignIn().disconnect();
    await _firestore.collection("users").doc(uid).collection("integrations").doc("google_calendar").set({
      "status": "disconnected",
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> watchConnection(String uid) {
    return _firestore.collection("users").doc(uid).collection("integrations").doc("google_calendar").snapshots().map((s) => s.data());
  }

  Future<void> requestSync({
    required String uid,
    required DateTime from,
    required DateTime to,
    required String mode,
  }) async {
    await _firestore.collection("calendarSyncJobs").add({
      "ownerId": uid,
      "from": Timestamp.fromDate(from),
      "to": Timestamp.fromDate(to),
      "mode": mode,
      "status": "queued",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
