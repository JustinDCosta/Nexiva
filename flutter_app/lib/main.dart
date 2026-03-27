import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/core/theme/app_theme.dart";
import "package:nexiva/firebase_options.dart";
import "package:nexiva/presentation/providers/app_settings_provider.dart";
import "package:nexiva/presentation/providers/notification_provider.dart";
import "package:nexiva/presentation/providers/sync_provider.dart";
import "package:nexiva/router/app_router.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: NexivaApp()));
}

class NexivaApp extends ConsumerWidget {
  const NexivaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsProvider);
    ref.watch(syncBootstrapProvider);
    ref.watch(notificationBootstrapProvider);

    return MaterialApp.router(
      title: "Nexiva",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}
