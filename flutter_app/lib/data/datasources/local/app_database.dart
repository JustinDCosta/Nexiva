class SyncQueueItem {
  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  final String id;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
}

class LocalSyncStore {
  final List<SyncQueueItem> _queue = [];

  Future<void> enqueue(SyncQueueItem item) async {
    _queue.add(item);
  }

  Future<List<SyncQueueItem>> pending() async {
    return List<SyncQueueItem>.from(_queue);
  }

  Future<void> removeById(String id) async {
    _queue.removeWhere((e) => e.id == id);
  }
}
