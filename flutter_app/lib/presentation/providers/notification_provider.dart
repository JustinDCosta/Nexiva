import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/services/notification_service.dart";

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(notificationServiceProvider).initialize();
});
