import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/domain/entities/time_block.dart";
import "package:nexiva/domain/usecases/feasibility_usecase.dart";
import "package:nexiva/presentation/providers/app_settings_provider.dart";
import "package:nexiva/presentation/providers/ideas_provider.dart";
import "package:nexiva/presentation/providers/notification_provider.dart";
import "package:nexiva/presentation/providers/timeline_provider.dart";

class IdeasScreen extends ConsumerWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideasAsync = ref.watch(ideasProvider);
    final settings = ref.watch(appSettingsProvider);
    ref.watch(ideasBootstrapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Idea Sandbox"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openIdeaDialog(context, ref),
          ),
        ],
      ),
      body: ideasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text("Failed to load ideas: $error")),
        data: (ideas) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final idea in ideas)
              _IdeaCard(
                id: idea.id,
                title: idea.title,
                duration: idea.estimatedMinutes,
                fit: idea.estimatedMinutes <= (settings.dayEndMinute - settings.dayStartMinute),
                scheduled: idea.status.name == "scheduled",
                suggestion: FeasibilityUseCase()
                    .evaluate(
                      candidate: TimeBlock(
                        id: "preview",
                        ownerId: idea.ownerId,
                        name: idea.title,
                        dateKey: "preview",
                        startMinute: settings.dayStartMinute,
                        durationMinutes: idea.estimatedMinutes,
                        priority: TaskPriority.medium,
                        energy: EnergyLevel.medium,
                        category: "Idea",
                      ),
                      availableMinutes: settings.dayEndMinute - settings.dayStartMinute,
                    )
                    .message,
                onSchedule: () async {
                  await ref.read(timelineControllerProvider).addBlockFromIdea(
                        title: idea.title,
                        durationMinutes: idea.estimatedMinutes,
                      );
                  await ref.read(ideasActionsProvider).markScheduled(idea.id);
                  await ref.read(notificationServiceProvider).scheduleRoutineReminder(
                        title: idea.title,
                        scheduledAt: DateTime.now().add(const Duration(minutes: 1)),
                    notificationsEnabled: settings.notificationsEnabled,
                    reminderLeadMinutes: settings.reminderLeadMinutes,
                    quietHoursStartMinute: settings.quietHoursStartMinute,
                    quietHoursEndMinute: settings.quietHoursEndMinute,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Scheduled '${idea.title}' in your timeline.")),
                    );
                  }
                },
                onEdit: () => _openIdeaDialog(
                  context,
                  ref,
                  id: idea.id,
                  initialTitle: idea.title,
                  initialMinutes: idea.estimatedMinutes,
                ),
                onAskAi: () async {
                  final available = settings.dayEndMinute - settings.dayStartMinute;
                  final req = (
                    title: idea.title,
                    estimatedMinutes: idea.estimatedMinutes,
                    availableMinutesToday: available,
                  );

                  final aiResult = await ref.read(aiSuggestionProvider(req).future);
                  if (!context.mounted) {
                    return;
                  }

                  await showDialog<void>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("AI Feasibility"),
                        content: Text(
                          "Score: ${aiResult.score}\n"
                          "Suggestion: ${aiResult.recommendation}\n"
                          "Source: ${aiResult.source}\n"
                          "AI: ${aiResult.aiRecommendation ?? "N/A"}",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Close"),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openIdeaDialog(
    BuildContext context,
    WidgetRef ref, {
    String? id,
    String? initialTitle,
    int? initialMinutes,
  }) {
    final titleCtrl = TextEditingController(text: initialTitle ?? "");
    final minutesCtrl = TextEditingController(text: (initialMinutes ?? 45).toString());

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(id == null ? "Add Idea" : "Edit Idea"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Estimated minutes"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final minutes = int.tryParse(minutesCtrl.text.trim()) ?? 0;
                if (title.isEmpty || minutes <= 0) {
                  return;
                }

                if (id == null) {
                  await ref.read(ideasActionsProvider).createIdea(
                        title: title,
                        estimatedMinutes: minutes,
                      );
                } else {
                  await ref.read(ideasActionsProvider).updateIdea(
                        id: id,
                        title: title,
                        estimatedMinutes: minutes,
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
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.id,
    required this.title,
    required this.duration,
    required this.fit,
    required this.scheduled,
    required this.suggestion,
    required this.onSchedule,
    required this.onEdit,
    required this.onAskAi,
  });

  final String id;
  final String title;
  final int duration;
  final bool fit;
  final bool scheduled;
  final String suggestion;
  final VoidCallback onSchedule;
  final VoidCallback onEdit;
  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            Text("$duration min • $suggestion"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(fit ? "Fits today" : "Overloaded"),
                  backgroundColor: fit ? Colors.green.shade100 : Colors.orange.shade100,
                ),
                FilledButton.tonal(
                  onPressed: scheduled ? null : onSchedule,
                  child: Text(scheduled ? "Scheduled" : "Schedule"),
                ),
                OutlinedButton(
                  onPressed: onAskAi,
                  child: const Text("Ask AI"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
