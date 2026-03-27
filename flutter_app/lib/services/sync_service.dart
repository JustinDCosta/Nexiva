import "dart:async";
import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

class SyncService {
  static const String _queueKey = "nexiva_sync_queue_v1";
  static const String _deadLetterKey = "nexiva_sync_dead_letter_v1";
  static const int _maxRetries = 5;
  static const int _baseBackoffSeconds = 2;
  static const int _maxBackoffSeconds = 300;
  final List<Map<String, dynamic>> _queue = [];
  final List<Map<String, dynamic>> _deadLetter = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _queue
      ..clear()
      ..addAll(_decodeList(prefs.getString(_queueKey)));
    _deadLetter
      ..clear()
      ..addAll(_decodeList(prefs.getString(_deadLetterKey)));
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }

    return decoded.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(_queue));
    await prefs.setString(_deadLetterKey, jsonEncode(_deadLetter));
  }

  void enqueue(Map<String, dynamic> operation) {
    _queue.add({
      ...operation,
      "opId": operation["opId"] ?? "op-${DateTime.now().microsecondsSinceEpoch}",
      "retryCount": 0,
      "queuedAt": DateTime.now().toIso8601String(),
      "nextAttemptAt": DateTime.now().toIso8601String(),
    });
    unawaited(_persist());
  }

  List<Map<String, dynamic>> pending() {
    return List<Map<String, dynamic>>.from(_queue);
  }

  List<Map<String, dynamic>> deadLetter() {
    return List<Map<String, dynamic>>.from(_deadLetter);
  }

  Future<void> retryDeadLetter(String opId) async {
    final index = _deadLetter.indexWhere((op) => op["opId"] == opId);
    if (index == -1) {
      return;
    }

    final op = Map<String, dynamic>.from(_deadLetter.removeAt(index));
    op["retryCount"] = 0;
    op.remove("lastError");
    op.remove("deadLetterAt");
    op["nextAttemptAt"] = DateTime.now().toIso8601String();
    _queue.add(op);
    await _persist();
  }

  Future<void> discardDeadLetter(String opId) async {
    _deadLetter.removeWhere((op) => op["opId"] == opId);
    await _persist();
  }

  Future<void> clearDeadLetter() async {
    _deadLetter.clear();
    await _persist();
  }

  DateTime _nextAttemptTime(int retryCount) {
    final exponent = retryCount - 1;
    final seconds = (_baseBackoffSeconds * (1 << exponent)).clamp(_baseBackoffSeconds, _maxBackoffSeconds);
    return DateTime.now().add(Duration(seconds: seconds));
  }

  bool _isReadyToRun(Map<String, dynamic> op) {
    final raw = op["nextAttemptAt"] as String?;
    if (raw == null) {
      return true;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return true;
    }
    return !parsed.isAfter(DateTime.now());
  }

  Future<void> drain(
    Future<void> Function(Map<String, dynamic>) sender, {
    bool forceDrain = false,
  }) async {
    final copy = List<Map<String, dynamic>>.from(_queue);
    for (final op in copy) {
      if (!forceDrain && !_isReadyToRun(op)) {
        continue;
      }

      final opId = op["opId"] as String?;
      try {
        await sender(op);
        if (opId != null) {
          _queue.removeWhere((item) => item["opId"] == opId);
        } else {
          _queue.remove(op);
        }
        await _persist();
      } catch (error) {
        final retry = ((op["retryCount"] as num?) ?? 0).toInt() + 1;
        op["retryCount"] = retry;
        op["lastError"] = error.toString();
        op["lastAttemptAt"] = DateTime.now().toIso8601String();
        op["nextAttemptAt"] = _nextAttemptTime(retry).toIso8601String();

        if (retry >= _maxRetries) {
          if (opId != null) {
            _queue.removeWhere((item) => item["opId"] == opId);
          } else {
            _queue.remove(op);
          }
          op["deadLetterAt"] = DateTime.now().toIso8601String();
          _deadLetter.add(op);
        }

        await _persist();
      }
    }
  }
}
