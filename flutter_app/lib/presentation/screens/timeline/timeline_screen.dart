import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:nexiva/domain/entities/idea.dart";
import "package:nexiva/domain/entities/routine.dart";
import "package:nexiva/domain/entities/time_block.dart";
import "package:nexiva/domain/usecases/capacity_usecase.dart";
import "package:nexiva/domain/usecases/overlap_usecase.dart";
import "package:nexiva/presentation/providers/app_settings_provider.dart";
import "package:nexiva/presentation/providers/ideas_provider.dart";
import "package:nexiva/presentation/providers/notification_provider.dart";
import "package:nexiva/presentation/providers/routine_template_provider.dart";
import "package:nexiva/presentation/providers/sync_provider.dart";
import "package:nexiva/presentation/providers/timeline_provider.dart";
import "package:nexiva/presentation/widgets/timeline/timeline_day_view.dart";

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(timelineBlocksProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final settings = ref.watch(appSettingsProvider);
    final templates = ref.watch(routineTemplatesProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <RoutineTemplate>[],
        );
    final ideas = ref.watch(ideasProvider).maybeWhen(
          data: (items) => items.where((e) => e.status.name != "scheduled").toList(),
          orElse: () => const <Idea>[],
        );
    final syncSnapshot = ref.watch(syncQueueSnapshotProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const SyncQueueSnapshot(pendingCount: 0, deadLetterCount: 0),
        );
    ref.watch(routineTemplatesBootstrapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Timeline - ${DateFormat("EEE, MMM d").format(selectedDate)}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state = selectedDate.subtract(const Duration(days: 1));
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state = DateTime.now();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state = selectedDate.add(const Duration(days: 1));
            },
          ),
          IconButton(
            icon: const Icon(Icons.view_list_outlined),
            onPressed: () => _openTemplateManager(context, ref, templates),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _openSettingsSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => ref.read(timelineControllerProvider).addSampleBlock(),
          ),
        ],
      ),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Failed to load timeline: $e")),
        data: (blocks) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const _WeekStrip(),
              const SizedBox(height: 8),
              _SyncHealthBanner(snapshot: syncSnapshot),
              const SizedBox(height: 8),
              _TemplateStrip(templates: templates),
              const SizedBox(height: 8),
              _IdeaInboxStrip(ideas: ideas),
              const SizedBox(height: 12),
              Expanded(
                child: _TimelineBody(
                  blocks: blocks,
                  dayStart: settings.dayStartMinute,
                  dayEnd: settings.dayEndMinute,
                  onMove: (block, delta) => ref.read(timelineControllerProvider).moveBlock(block, delta),
                  onResize: (block, delta) => ref.read(timelineControllerProvider).resizeBlock(block, delta),
                  onIdeaDrop: (data, minuteOfDay) async {
                    final scheduledMinute = await ref.read(timelineControllerProvider).addBlockFromIdeaAtMinute(
                          title: data["title"] as String,
                          durationMinutes: data["duration"] as int,
                          startMinute: minuteOfDay,
                        );
                    await ref.read(ideasActionsProvider).markScheduled(data["id"] as String);

                    if (scheduledMinute != null) {
                      final scheduledAt = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        scheduledMinute ~/ 60,
                        scheduledMinute % 60,
                      );
                      await ref.read(notificationServiceProvider).scheduleRoutineReminder(
                            title: data["title"] as String,
                            scheduledAt: scheduledAt,
                            notificationsEnabled: settings.notificationsEnabled,
                            reminderLeadMinutes: settings.reminderLeadMinutes,
                            quietHoursStartMinute: settings.quietHoursStartMinute,
                            quietHoursEndMinute: settings.quietHoursEndMinute,
                          );
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Scheduled '${data["title"]}' from inbox.")),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettingsSheet(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    int start = settings.dayStartMinute;
    int end = settings.dayEndMinute;
    int slot = settings.slotMinutes;
    ThemeMode themeMode = settings.themeMode;
    bool notificationsEnabled = settings.notificationsEnabled;
    int reminderLeadMinutes = settings.reminderLeadMinutes;
    int quietStart = settings.quietHoursStartMinute;
    int quietEnd = settings.quietHoursEndMinute;
    String calendarSyncMode = settings.calendarSyncMode;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Planner Settings", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text("Day start: ${(start ~/ 60).toString().padLeft(2, "0")}:00"),
                  Slider(
                    value: start.toDouble(),
                    min: 0,
                    max: (end - 60).toDouble(),
                    divisions: (end - 60) ~/ 15,
                    onChanged: (value) => setModalState(() => start = value.round()),
                  ),
                  Text("Day end: ${(end ~/ 60).toString().padLeft(2, "0")}:00"),
                  Slider(
                    value: end.toDouble(),
                    min: (start + 60).toDouble(),
                    max: 24 * 60,
                    divisions: (24 * 60 - start - 60) ~/ 15,
                    onChanged: (value) => setModalState(() => end = value.round()),
                  ),
                  DropdownMenu<int>(
                    initialSelection: slot,
                    label: const Text("Time slot size"),
                    dropdownMenuEntries: const [10, 15, 20, 30, 60]
                        .map((e) => DropdownMenuEntry<int>(value: e, label: "$e minutes"))
                        .toList(),
                    onSelected: (value) => setModalState(() => slot = value ?? 15),
                  ),
                  const SizedBox(height: 12),
                  DropdownMenu<ThemeMode>(
                    initialSelection: themeMode,
                    label: const Text("Theme"),
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: ThemeMode.system, label: "System"),
                      DropdownMenuEntry(value: ThemeMode.light, label: "Light"),
                      DropdownMenuEntry(value: ThemeMode.dark, label: "Dark"),
                    ],
                    onSelected: (value) => setModalState(() => themeMode = value ?? ThemeMode.system),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Enable reminders"),
                    value: notificationsEnabled,
                    onChanged: (value) => setModalState(() => notificationsEnabled = value),
                  ),
                  Text("Reminder lead time: $reminderLeadMinutes min"),
                  Slider(
                    value: reminderLeadMinutes.toDouble(),
                    min: 0,
                    max: 120,
                    divisions: 24,
                    onChanged: notificationsEnabled
                        ? (value) => setModalState(() => reminderLeadMinutes = value.round())
                        : null,
                  ),
                  Text("Quiet hours start: ${(quietStart ~/ 60).toString().padLeft(2, "0")}:00"),
                  Slider(
                    value: quietStart.toDouble(),
                    min: 0,
                    max: (24 * 60).toDouble(),
                    divisions: 24,
                    onChanged: notificationsEnabled ? (value) => setModalState(() => quietStart = value.round()) : null,
                  ),
                  Text("Quiet hours end: ${(quietEnd ~/ 60).toString().padLeft(2, "0")}:00"),
                  Slider(
                    value: quietEnd.toDouble(),
                    min: 0,
                    max: (24 * 60).toDouble(),
                    divisions: 24,
                    onChanged: notificationsEnabled ? (value) => setModalState(() => quietEnd = value.round()) : null,
                  ),
                  DropdownMenu<String>(
                    initialSelection: calendarSyncMode,
                    label: const Text("Calendar sync mode"),
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: "off", label: "Off"),
                      DropdownMenuEntry(value: "nexiva_to_google", label: "Nexiva to Google"),
                      DropdownMenuEntry(value: "two_way", label: "Two-way (beta)"),
                    ],
                    onSelected: (value) => setModalState(() => calendarSyncMode = value ?? "off"),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final actions = ref.read(appSettingsActionsProvider);
                      await actions.setDayWindow(startMinute: start, endMinute: end);
                      await actions.setSlotMinutes(slot);
                      await actions.setThemeMode(themeMode);
                      await actions.setNotificationPreferences(
                        enabled: notificationsEnabled,
                        leadMinutes: reminderLeadMinutes,
                        quietStartMinute: quietStart,
                        quietEndMinute: quietEnd,
                      );
                      await actions.setCalendarSyncMode(calendarSyncMode);
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text("Apply"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openTemplateManager(BuildContext context, WidgetRef ref, List<RoutineTemplate> templates) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text("Templates", style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _openTemplateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text("New"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return Card(
                      child: ListTile(
                        title: Text(template.name),
                        subtitle: Text(
                          "${(template.dayStartMinute ~/ 60).toString().padLeft(2, "0")}:00 - "
                          "${(template.dayEndMinute ~/ 60).toString().padLeft(2, "0")}:00 • ${template.slotMinutes}m",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openTemplateDialog(context, ref, existing: template),
                        ),
                        onTap: () => ref.read(timelineControllerProvider).applyTemplate(template),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTemplateDialog(BuildContext context, WidgetRef ref, {RoutineTemplate? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? "");
    int start = existing?.dayStartMinute ?? 6 * 60;
    int end = existing?.dayEndMinute ?? 22 * 60;
    int slot = existing?.slotMinutes ?? 15;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(existing == null ? "Create Template" : "Edit Template"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: "Template name"),
                    ),
                    const SizedBox(height: 12),
                    Text("Day start: ${(start ~/ 60).toString().padLeft(2, "0")}:00"),
                    Slider(
                      value: start.toDouble(),
                      min: 0,
                      max: (end - 60).toDouble(),
                      divisions: (end - 60) ~/ 15,
                      onChanged: (v) => setModalState(() => start = v.round()),
                    ),
                    Text("Day end: ${(end ~/ 60).toString().padLeft(2, "0")}:00"),
                    Slider(
                      value: end.toDouble(),
                      min: (start + 60).toDouble(),
                      max: 24 * 60,
                      divisions: (24 * 60 - start - 60) ~/ 15,
                      onChanged: (v) => setModalState(() => end = v.round()),
                    ),
                    DropdownMenu<int>(
                      initialSelection: slot,
                      label: const Text("Time slot"),
                      dropdownMenuEntries: const [10, 15, 20, 30, 60]
                          .map((e) => DropdownMenuEntry<int>(value: e, label: "$e minutes"))
                          .toList(),
                      onSelected: (v) => setModalState(() => slot = v ?? 15),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      return;
                    }
                    final actions = ref.read(routineTemplateActionsProvider);
                    if (existing == null) {
                      await actions.createTemplate(
                        name: name,
                        dayStartMinute: start,
                        dayEndMinute: end,
                        slotMinutes: slot,
                      );
                    } else {
                      await actions.updateTemplate(
                        id: existing.id,
                        name: name,
                        dayStartMinute: start,
                        dayEndMinute: end,
                        slotMinutes: slot,
                      );
                    }
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SyncHealthBanner extends ConsumerWidget {
  const _SyncHealthBanner({required this.snapshot});

  final SyncQueueSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (snapshot.pendingCount == 0 && snapshot.deadLetterCount == 0) {
      return const SizedBox.shrink();
    }

    final hasDeadLetters = snapshot.deadLetterCount > 0;
    final color = hasDeadLetters ? Colors.red.shade100 : Colors.amber.shade100;
    final title = hasDeadLetters ? "Sync attention needed" : "Sync in progress";
    final subtitle = hasDeadLetters
        ? "${snapshot.deadLetterCount} operation(s) failed repeatedly. ${snapshot.pendingCount} pending."
        : "${snapshot.pendingCount} operation(s) queued for background sync.";

    return Card(
      color: color,
      child: ListTile(
        dense: true,
        leading: Icon(hasDeadLetters ? Icons.sync_problem : Icons.sync),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (hasDeadLetters)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => ref.read(syncQueueActionsProvider).retryAllDeadLetters(),
                    child: const Text("Retry Failed Ops"),
                  ),
                  TextButton(
                    onPressed: () => ref.read(syncQueueActionsProvider).clearDeadLetters(),
                    child: const Text("Dismiss Failures"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final days = List<DateTime>.generate(7, (index) => startOfWeek.add(Duration(days: index)));

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == selectedDate.year && day.month == selectedDate.month && day.day == selectedDate.day;

          return ChoiceChip(
            label: Text("${DateFormat("E").format(day)} ${day.day}"),
            selected: isSelected,
            onSelected: (_) {
              ref.read(selectedDateProvider.notifier).state = day;
            },
          );
        },
      ),
    );
  }
}

class _IdeaInboxStrip extends StatelessWidget {
  const _IdeaInboxStrip({required this.ideas});

  final List<Idea> ideas;

  @override
  Widget build(BuildContext context) {
    if (ideas.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ideas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final idea = ideas[index];
          return LongPressDraggable<Map<String, dynamic>>(
            data: {
              "id": idea.id,
              "title": idea.title,
              "duration": idea.estimatedMinutes,
            },
            feedback: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text("${idea.title} (${idea.estimatedMinutes}m)"),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: Chip(label: Text(idea.title)),
            ),
            child: Chip(
              avatar: const Icon(Icons.drag_indicator),
              label: Text("${idea.title} (${idea.estimatedMinutes}m)"),
            ),
          );
        },
      ),
    );
  }
}

class _TimelineBody extends StatelessWidget {
  const _TimelineBody({
    required this.blocks,
    required this.dayStart,
    required this.dayEnd,
    required this.onMove,
    required this.onResize,
    required this.onIdeaDrop,
  });

  final List<TimeBlock> blocks;
  final int dayStart;
  final int dayEnd;
  final void Function(TimeBlock block, int deltaMinutes) onMove;
  final void Function(TimeBlock block, int deltaMinutes) onResize;
  final Future<void> Function(Map<String, dynamic> data, int minuteOfDay) onIdeaDrop;

  @override
  Widget build(BuildContext context) {
    final capacity = CapacityUseCase().evaluate(
      dayStartMinute: dayStart,
      dayEndMinute: dayEnd,
      blocks: blocks,
    );
    final overlaps = OverlapUseCase().overlappingIds(blocks);

    return Column(
      children: [
        _CapacityBanner(capacity: capacity),
        if (overlaps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Card(
              color: Colors.red.shade100,
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: Text("Conflicting time blocks detected"),
                subtitle: Text("Move or resize overlapping items to keep your plan realistic."),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: TimelineDayView(
            blocks: blocks,
            dayStart: dayStart,
            dayEnd: dayEnd,
            onBlockDrag: onMove,
            onBlockResize: onResize,
            overlappingBlockIds: overlaps,
            onIdeaDrop: onIdeaDrop,
          ),
        ),
      ],
    );
  }
}

class _TemplateStrip extends ConsumerWidget {
  const _TemplateStrip({required this.templates});

  final List<RoutineTemplate> templates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final template = templates[index];
          return InputChip(
            label: Text(template.name),
            avatar: const Icon(Icons.auto_awesome_motion),
            onPressed: () => ref.read(timelineControllerProvider).applyTemplate(template),
            onDeleted: () => ref.read(routineTemplateActionsProvider).duplicateTemplate(template.id),
            deleteIcon: const Icon(Icons.copy_all),
          );
        },
      ),
    );
  }
}

class _CapacityBanner extends StatelessWidget {
  const _CapacityBanner({required this.capacity});

  final CapacityResult capacity;

  @override
  Widget build(BuildContext context) {
    final overloaded = capacity.overloadMinutes > 0;

    return Card(
      color: overloaded ? Colors.orange.shade100 : Colors.green.shade100,
      child: ListTile(
        title: Text("Planned ${capacity.plannedMinutes} / ${capacity.availableMinutes} min"),
        subtitle: Text(
          overloaded
              ? "Overloaded by ${capacity.overloadMinutes} min. Consider moving tasks."
              : "You still have ${capacity.availableMinutes - capacity.plannedMinutes} min available.",
        ),
      ),
    );
  }
}
