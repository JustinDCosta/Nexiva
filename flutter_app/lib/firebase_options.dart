import "package:firebase_core/firebase_core.dart";
import "package:flutter/foundation.dart" show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError("Firebase options are not configured for this platform.");
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "REPLACE_WEB_API_KEY",
    appId: "REPLACE_WEB_APP_ID",
    messagingSenderId: "REPLACE_SENDER_ID",
    projectId: "REPLACE_PROJECT_ID",
    authDomain: "REPLACE_PROJECT_ID.firebaseapp.com",
    storageBucket: "REPLACE_PROJECT_ID.appspot.com",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "REPLACE_ANDROID_API_KEY",
    appId: "REPLACE_ANDROID_APP_ID",
    messagingSenderId: "REPLACE_SENDER_ID",
    projectId: "REPLACE_PROJECT_ID",
    storageBucket: "REPLACE_PROJECT_ID.appspot.com",
  );
}
