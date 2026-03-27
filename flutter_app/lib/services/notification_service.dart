import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_timezone/flutter_timezone.dart";
import "package:intl/intl.dart";
import "package:timezone/data/latest_all.dart" as tz_data;
import "package:timezone/timezone.dart" as tz;

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings("@mipmap/ic_launcher"),
      iOS: DarwinInitializationSettings(),
    );

    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  bool _isWithinQuietHours(DateTime value, int quietStartMinute, int quietEndMinute) {
    final minute = value.hour * 60 + value.minute;
    if (quietStartMinute == quietEndMinute) {
      return false;
    }
    if (quietStartMinute < quietEndMinute) {
      return minute >= quietStartMinute && minute < quietEndMinute;
    }
    return minute >= quietStartMinute || minute < quietEndMinute;
  }

  Future<void> scheduleRoutineReminder({
    required String title,
    required DateTime scheduledAt,
    required bool notificationsEnabled,
    required int reminderLeadMinutes,
    required int quietHoursStartMinute,
    required int quietHoursEndMinute,
  }) async {
    if (!notificationsEnabled) {
      return;
    }

    await initialize();

    final reminderAt = scheduledAt.subtract(Duration(minutes: reminderLeadMinutes));
    if (reminderAt.isBefore(DateTime.now())) {
      return;
    }
    if (_isWithinQuietHours(reminderAt, quietHoursStartMinute, quietHoursEndMinute)) {
      return;
    }

    final formatter = DateFormat("HH:mm");
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        "nexiva_routine_channel",
        "Routine Reminders",
        channelDescription: "Nexiva routine and scheduling reminders",
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      "Nexiva Reminder",
      "$title starts at ${formatter.format(scheduledAt)}",
      tz.TZDateTime.from(reminderAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: "routine",
    );
  }
}
