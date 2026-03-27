import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/presentation/providers/analytics_provider.dart";

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyAnalyticsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => WeeklyAnalytics.empty,
        );
    final gamification = ref.watch(gamificationSummaryProvider).maybeWhen(
          data: (value) => value,
          orElse: () => GamificationSummary.empty,
        );

    return Scaffold(
      appBar: AppBar(title: const Text("Analytics")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: "XP",
                    value: "${gamification.xp}",
                    icon: Icons.bolt,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: "Level",
                    value: "${gamification.level}",
                    icon: Icons.stars,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: "Streak",
                    value: "${gamification.streak}",
                    icon: Icons.local_fire_department,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text("Weekly Productivity", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (int i = 0; i < 7; i++) _g(i, weekly.dailyCompleted[i].toDouble()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Completed tasks this week: ${weekly.dailyCompleted.fold<int>(0, (a, b) => a + b)}",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              "Completed minutes: ${weekly.dailyCompletedMinutes.fold<int>(0, (a, b) => a + b)}",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  static BarChartGroupData _g(int x, double y) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y)]);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
