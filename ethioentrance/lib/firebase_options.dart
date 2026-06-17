import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC9wQzd-Q6MrOlqHGZEoHzZE0Zadpz9xLQ',
    appId: '1:856852356425:web:cb17a87463fbe062fece98',
    messagingSenderId: '856852356425',
    projectId: 'ethioentrance-e72b6',
    authDomain: 'ethioentrance-e72b6.firebaseapp.com',
    storageBucket: 'ethioentrance-e72b6.firebasestorage.app',
    measurementId: 'G-7JSW429E6V',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDwhy4y-X6nZZV2DIs49J1uSYzDVVvxrfs',
    appId: '1:856852356425:android:4e79fa6db143f02cfece98',
    messagingSenderId: '856852356425',
    projectId: 'ethioentrance-e72b6',
    storageBucket: 'ethioentrance-e72b6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDwhy4y-X6nZZV2DIs49J1uSYzDVVvxrfs',
    appId: '1:856852356425:ios:cb17a87463fbe062fece98', // Placeholder, update if iOS config available
    messagingSenderId: '856852356425',
    projectId: 'ethioentrance-e72b6',
    storageBucket: 'ethioentrance-e72b6.firebasestorage.app',
    iosBundleId: 'Abdi_Alemu.com.EthioEntrance', // From Android package, adjust if different
  );
}