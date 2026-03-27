import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/presentation/providers/app_settings_provider.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";
import "package:nexiva/services/calendar_service.dart";

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService(FirebaseFirestore.instance);
});

final calendarConnectionProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return Stream.value(null);
  }
  return ref.watch(calendarServiceProvider).watchConnection(uid);
});

final calendarActionsProvider = Provider<CalendarActions>((ref) {
  return CalendarActions(ref);
});

class CalendarActions {
  CalendarActions(this._ref);

  final Ref _ref;

  Future<void> connect() async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }
    await _ref.read(calendarServiceProvider).connect(uid);
  }

  Future<void> disconnect() async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }
    await _ref.read(calendarServiceProvider).disconnect(uid);
  }

  Future<void> syncNextWeek() async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    final settings = _ref.read(appSettingsProvider);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 7));

    await _ref.read(calendarServiceProvider).requestSync(
          uid: uid,
          from: from,
          to: to,
          mode: settings.calendarSyncMode,
        );
  }
}
