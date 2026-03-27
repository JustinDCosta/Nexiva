import "package:flutter_test/flutter_test.dart";
import "package:nexiva/services/sync_service.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("SyncService", () {
    test("enqueue stores operation in pending queue", () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService();
      await service.init();

      service.enqueue({"type": "set_slot_minutes", "slotMinutes": 15});

      final pending = service.pending();
      expect(pending.length, 1);
      expect(pending.first["type"], "set_slot_minutes");
      expect(pending.first["retryCount"], 0);
      expect(pending.first.containsKey("opId"), isTrue);
      expect(pending.first.containsKey("nextAttemptAt"), isTrue);
    });

    test("moves operation to dead letter after max retries", () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService();
      await service.init();
      service.enqueue({"opId": "failing-op", "type": "set_theme_mode", "themeMode": "dark"});

      Future<void> sender(Map<String, dynamic> _) async {
        throw Exception("network down");
      }

      for (int i = 0; i < 5; i++) {
        await service.drain(sender, forceDrain: true);
      }

      expect(service.pending(), isEmpty);
      expect(service.deadLetter().length, 1);
      expect(service.deadLetter().first["opId"], "failing-op");
      expect(service.deadLetter().first["retryCount"], 5);
    });

    test("retryDeadLetter returns operation to queue", () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService();
      await service.init();
      service.enqueue({"opId": "retry-op", "type": "set_day_window", "startMinute": 420, "endMinute": 1320});

      Future<void> sender(Map<String, dynamic> _) async {
        throw Exception("temporary failure");
      }

      for (int i = 0; i < 5; i++) {
        await service.drain(sender, forceDrain: true);
      }

      await service.retryDeadLetter("retry-op");

      expect(service.deadLetter(), isEmpty);
      final pending = service.pending();
      expect(pending.length, 1);
      expect(pending.first["opId"], "retry-op");
      expect(pending.first["retryCount"], 0);
    });
  });
}
