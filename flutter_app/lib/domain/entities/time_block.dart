enum TaskPriority { low, medium, high }
enum EnergyLevel { low, medium, high }
enum BlockStatus { planned, inProgress, completed, skipped }

class TimeBlock {
  TimeBlock({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.dateKey,
    required this.startMinute,
    required this.durationMinutes,
    required this.priority,
    required this.energy,
    required this.category,
    this.status = BlockStatus.planned,
  });

  final String id;
  final String ownerId;
  final String name;
  final String dateKey;
  final int startMinute;
  final int durationMinutes;
  final TaskPriority priority;
  final EnergyLevel energy;
  final String category;
  final BlockStatus status;

  int get endMinute => startMinute + durationMinutes;

  TimeBlock copyWith({
    int? startMinute,
    int? durationMinutes,
    BlockStatus? status,
  }) {
    return TimeBlock(
      id: id,
      ownerId: ownerId,
      name: name,
      dateKey: dateKey,
      startMinute: startMinute ?? this.startMinute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priority: priority,
      energy: energy,
      category: category,
      status: status ?? this.status,
    );
  }
}
