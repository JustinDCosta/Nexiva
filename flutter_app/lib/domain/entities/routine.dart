class Routine {
  Routine({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.isFlexible,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String category;
  final bool isFlexible;
  final DateTime createdAt;
}

class RoutineTemplate {
  RoutineTemplate({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.dayStartMinute,
    required this.dayEndMinute,
    required this.slotMinutes,
  });

  final String id;
  final String ownerId;
  final String name;
  final int dayStartMinute;
  final int dayEndMinute;
  final int slotMinutes;
}
