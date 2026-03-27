class Idea {
  Idea({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.estimatedMinutes,
    required this.createdAt,
    this.status = IdeaStatus.sandbox,
  });

  final String id;
  final String ownerId;
  final String title;
  final int estimatedMinutes;
  final DateTime createdAt;
  final IdeaStatus status;
}

enum IdeaStatus { sandbox, scheduled, archived }
