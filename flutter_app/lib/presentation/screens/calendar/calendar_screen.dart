import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/presentation/providers/app_settings_provider.dart";
import "package:nexiva/presentation/providers/calendar_provider.dart";

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(calendarConnectionProvider).value;
    final mode = ref.watch(appSettingsProvider).calendarSyncMode;
    final connected = (connection?["status"] as String?) == "connected";

    return Scaffold(
      appBar: AppBar(title: const Text("Calendar Sync")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: Icon(connected ? Icons.check_circle : Icons.link_off),
                title: Text(connected ? "Google Calendar connected" : "Google Calendar not connected"),
                subtitle: Text(connection?["email"] as String? ?? "Connect your account to sync routine blocks."),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sync),
                title: const Text("Sync mode"),
                subtitle: Text(mode),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: connected ? null : () => ref.read(calendarActionsProvider).connect(),
              icon: const Icon(Icons.link),
              label: const Text("Connect Google Calendar"),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: connected ? () => ref.read(calendarActionsProvider).syncNextWeek() : null,
              icon: const Icon(Icons.upload),
              label: const Text("Queue Next 7 Days Sync"),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: connected ? () => ref.read(calendarActionsProvider).disconnect() : null,
              icon: const Icon(Icons.link_off),
              label: const Text("Disconnect"),
            ),
          ],
        ),
      ),
    );
  }
}
