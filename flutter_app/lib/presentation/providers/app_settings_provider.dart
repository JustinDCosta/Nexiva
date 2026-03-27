import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/core/constants/app_constants.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";
import "package:nexiva/presentation/providers/sync_provider.dart";

class AppSettings {
  const AppSettings({
    required this.dayStartMinute,
    required this.dayEndMinute,
    required this.slotMinutes,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.reminderLeadMinutes,
    required this.quietHoursStartMinute,
    required this.quietHoursEndMinute,
    required this.calendarSyncMode,
  });

  final int dayStartMinute;
  final int dayEndMinute;
  final int slotMinutes;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int reminderLeadMinutes;
  final int quietHoursStartMinute;
  final int quietHoursEndMinute;
  final String calendarSyncMode;

  AppSettings copyWith({
    int? dayStartMinute,
    int? dayEndMinute,
    int? slotMinutes,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? reminderLeadMinutes,
    int? quietHoursStartMinute,
    int? quietHoursEndMinute,
    String? calendarSyncMode,
  }) {
    return AppSettings(
      dayStartMinute: dayStartMinute ?? this.dayStartMinute,
      dayEndMinute: dayEndMinute ?? this.dayEndMinute,
      slotMinutes: slotMinutes ?? this.slotMinutes,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      quietHoursStartMinute: quietHoursStartMinute ?? this.quietHoursStartMinute,
      quietHoursEndMinute: quietHoursEndMinute ?? this.quietHoursEndMinute,
      calendarSyncMode: calendarSyncMode ?? this.calendarSyncMode,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      dayStartMinute: (json["dayStartMinute"] as int?) ?? AppConstants.defaultDayStartMinute,
      dayEndMinute: (json["dayEndMinute"] as int?) ?? AppConstants.defaultDayEndMinute,
      slotMinutes: (json["slotMinutes"] as int?) ?? AppConstants.defaultSlotMinutes,
      themeMode: _themeModeFromString(json["themeMode"] as String?),
      notificationsEnabled: (json["notificationsEnabled"] as bool?) ?? true,
      reminderLeadMinutes: (json["reminderLeadMinutes"] as int?) ?? 10,
      quietHoursStartMinute: (json["quietHoursStartMinute"] as int?) ?? 22 * 60,
      quietHoursEndMinute: (json["quietHoursEndMinute"] as int?) ?? 7 * 60,
      calendarSyncMode: (json["calendarSyncMode"] as String?) ?? "off",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "dayStartMinute": dayStartMinute,
      "dayEndMinute": dayEndMinute,
      "slotMinutes": slotMinutes,
      "themeMode": _themeModeToString(themeMode),
      "notificationsEnabled": notificationsEnabled,
      "reminderLeadMinutes": reminderLeadMinutes,
      "quietHoursStartMinute": quietHoursStartMinute,
      "quietHoursEndMinute": quietHoursEndMinute,
      "calendarSyncMode": calendarSyncMode,
      "updatedAt": FieldValue.serverTimestamp(),
    };
  }
}

const _defaultSettings = AppSettings(
  dayStartMinute: AppConstants.defaultDayStartMinute,
  dayEndMinute: AppConstants.defaultDayEndMinute,
  slotMinutes: AppConstants.defaultSlotMinutes,
  themeMode: ThemeMode.system,
  notificationsEnabled: true,
  reminderLeadMinutes: 10,
  quietHoursStartMinute: 22 * 60,
  quietHoursEndMinute: 7 * 60,
  calendarSyncMode: "off",
);

String _themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return "light";
    case ThemeMode.dark:
      return "dark";
    case ThemeMode.system:
      return "system";
  }
}

ThemeMode _themeModeFromString(String? value) {
  switch (value) {
    case "light":
      return ThemeMode.light;
    case "dark":
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

final appSettingsStreamProvider = StreamProvider<AppSettings>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return Stream.value(_defaultSettings);
  }

  final doc = FirebaseFirestore.instance.collection("users").doc(uid).collection("preferences").doc("app_settings");
  return doc.snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null) {
      return _defaultSettings;
    }
    return AppSettings.fromJson(data);
  });
});

final appSettingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(appSettingsStreamProvider).maybeWhen(
        data: (settings) => settings,
        orElse: () => _defaultSettings,
      );
});

final appSettingsActionsProvider = Provider<AppSettingsActions>((ref) {
  return AppSettingsActions(ref);
});

class AppSettingsActions {
  AppSettingsActions(this._ref);

  final Ref _ref;

  Future<void> setDayWindow({required int startMinute, required int endMinute}) async {
    if (startMinute >= endMinute) {
      return;
    }

    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).collection("preferences").doc("app_settings").set({
        "dayStartMinute": startMinute,
        "dayEndMinute": endMinute,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "set_day_window",
        "uid": uid,
        "startMinute": startMinute,
        "endMinute": endMinute,
      });
    }
  }

  Future<void> setSlotMinutes(int slotMinutes) async {
    if (slotMinutes <= 0 || slotMinutes > 60) {
      return;
    }

    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).collection("preferences").doc("app_settings").set({
        "slotMinutes": slotMinutes,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "set_slot_minutes",
        "uid": uid,
        "slotMinutes": slotMinutes,
      });
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).collection("preferences").doc("app_settings").set({
        "themeMode": _themeModeToString(themeMode),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "set_theme_mode",
        "uid": uid,
        "themeMode": _themeModeToString(themeMode),
      });
    }
  }

  Future<void> setNotificationPreferences({
    required bool enabled,
    required int leadMinutes,
    required int quietStartMinute,
    required int quietEndMinute,
  }) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    final boundedLead = leadMinutes.clamp(0, 180);
    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).collection("preferences").doc("app_settings").set({
        "notificationsEnabled": enabled,
        "reminderLeadMinutes": boundedLead,
        "quietHoursStartMinute": quietStartMinute,
        "quietHoursEndMinute": quietEndMinute,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "set_notification_prefs",
        "uid": uid,
        "notificationsEnabled": enabled,
        "reminderLeadMinutes": boundedLead,
        "quietHoursStartMinute": quietStartMinute,
        "quietHoursEndMinute": quietEndMinute,
      });
    }
  }

  Future<void> setCalendarSyncMode(String mode) async {
    if (mode != "off" && mode != "nexiva_to_google" && mode != "two_way") {
      return;
    }

    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).collection("preferences").doc("app_settings").set({
        "calendarSyncMode": mode,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      _ref.read(syncServiceProvider).enqueue({
        "type": "set_calendar_sync_mode",
        "uid": uid,
        "calendarSyncMode": mode,
      });
    }
  }
}
