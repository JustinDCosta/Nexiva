# Nexiva

Nexiva is a production-focused routine management platform with:

- Dynamic time blocking
- Smart routine builder
- Idea sandbox and feasibility checks
- Gamification and analytics
- Real-time sync across Android and Web

## Monorepo Layout

- `flutter_app/` Flutter app for Android and Web
- `firebase/` Firestore rules, indexes, Firebase Functions
- `scripts/` setup and deploy scripts
- `.github/workflows/` CI pipeline

## Tech Stack

- Frontend: Flutter, Riverpod, go_router
- Backend: Firebase Auth, Firestore, Cloud Functions (TypeScript)
- Hosting: Firebase Hosting
- Local persistence: Drift (offline queue + sync)

## Quick Start

### 1) Prerequisites

Install:

- Flutter SDK (stable)
- Firebase CLI (`npm i -g firebase-tools`)
- Node.js 20+
- Java 17 (Android builds)

### 2) Flutter setup

```bash
cd flutter_app
flutter pub get
```

Generate Firebase options:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This updates `lib/firebase_options.dart` with real values.

### 3) Functions setup

```bash
cd firebase/functions
npm install
npm run build
```

### 4) Local emulators

From repo root:

```bash
firebase emulators:start --config firebase/firebase.json
```

If `flutter` is not recognized after SDK installation on Windows, open a new terminal or restart VS Code so PATH updates are loaded.

### 5) Run app

Android:

```bash
cd flutter_app
flutter run
```

Web:

```bash
cd flutter_app
flutter run -d chrome
```

## Security

- Every user-owned document stores `ownerId`.
- Firestore rules enforce `request.auth.uid == ownerId`.
- Aggregated gamification docs are write-protected and updated by Functions.

## Deployment

Web hosting:

```bash
firebase deploy --only hosting --config firebase/firebase.json
```

Functions + Firestore rules/indexes:

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes --config firebase/firebase.json
```

## Security Rules Tests

```bash
cd firebase/tests
npm install
npm test
```

## Environment Variables

Functions use runtime config/environment values for AI integration and third-party tokens.

- `AI_PROVIDER`
- `AI_API_KEY`
- `AI_MODEL`

Never commit secrets.

## Status

This repository is scaffolded for phased implementation:

- Foundation: complete
- Auth/Data/Security baseline: complete
- Timeline/Ideas/Gamification: starter implementation included
- Advanced AI/calendar production hardening: pending provider credentials and rollout flags
