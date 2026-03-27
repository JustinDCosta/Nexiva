# flutter_app

Flutter client for Nexiva (Android + Web parity target).

## Run

```bash
flutter pub get
flutter run
```

## Configure Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This writes real values to `lib/firebase_options.dart`.

## Key Modules

- `lib/presentation/screens/timeline/` dynamic planner timeline
- `lib/presentation/screens/ideas/` idea sandbox
- `lib/presentation/screens/analytics/` stats and charts
- `lib/services/` sync, notifications, calendar integrations
