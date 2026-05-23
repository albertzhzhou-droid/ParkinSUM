import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static const supportedEnvironmentIds = <String>[
    'dev',
    'stage',
    'prod',
  ];

  static const productionProjectId = 'parkinsum-companion';
  static const developmentProjectId = 'parkinsum-companion-dev';
  static const stagingProjectId = 'parkinsum-companion-stage';

  static FirebaseOptions get currentPlatform {
    return currentPlatformForEnvironment('prod');
  }

  static FirebaseOptions currentPlatformForEnvironment(String environment) {
    final normalized = environment.trim().toLowerCase();
    if (!supportedEnvironmentIds.contains(normalized)) {
      throw UnsupportedError(
        'Unsupported PARKINSUM_ENV "$environment". '
        'Use dev, stage, or prod.',
      );
    }
    if (normalized == 'dev') {
      if (kIsWeb) {
        return devWeb;
      }
      throw UnsupportedError(
        'Firebase options for PARKINSUM_ENV=dev are currently generated '
        'for web only. Add Android/iOS/macOS dev app configs before using '
        'dev on this platform.',
      );
    }

    if (normalized == 'stage') {
      if (kIsWeb) {
        return stageWeb;
      }
      throw UnsupportedError(
        'Firebase options for PARKINSUM_ENV=stage are currently generated '
        'for web only. Add Android/iOS/macOS stage app configs before using '
        'stage on this platform.',
      );
    }

    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase is configured for Android, iOS, and macOS only.',
        );
    }
  }

  static String projectIdForEnvironment(String environment) {
    switch (environment.trim().toLowerCase()) {
      case 'dev':
        return developmentProjectId;
      case 'stage':
        return stagingProjectId;
      case 'prod':
        return productionProjectId;
      default:
        throw UnsupportedError(
          'Unsupported PARKINSUM_ENV "$environment". '
          'Use dev, stage, or prod.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA9D5gYkxGIWjT3al8DbLgY8vNPello3YA',
    appId: '1:429989696553:web:79cbc62531c6861ade3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    authDomain: 'parkinsum-companion.firebaseapp.com',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
    measurementId: 'G-NYFEZH115V',
  );

  static const FirebaseOptions devWeb = FirebaseOptions(
    apiKey: 'AIzaSyDOVDle3i6f8sixoamxF-XtmT3Dkf82nNI',
    appId: '1:36630731726:web:d9359715300da8fb13299f',
    messagingSenderId: '36630731726',
    projectId: 'parkinsum-companion-dev',
    authDomain: 'parkinsum-companion-dev.firebaseapp.com',
    storageBucket: 'parkinsum-companion-dev.firebasestorage.app',
  );

  static const FirebaseOptions stageWeb = FirebaseOptions(
    apiKey: 'AIzaSyDvBdbU4cUhOSRkK4CgtvrJ8W1cSuWjS5A',
    appId: '1:51798948952:web:2f325617db7742aafe1e2d',
    messagingSenderId: '51798948952',
    projectId: 'parkinsum-companion-stage',
    authDomain: 'parkinsum-companion-stage.firebaseapp.com',
    storageBucket: 'parkinsum-companion-stage.firebasestorage.app',
    measurementId: 'G-ZTPXXMK9C5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwg7e1bCiB0j8wjflI9mjPl7n8CS3luAA',
    appId: '1:429989696553:android:2b43afa49913cccede3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDrfrZIoByQcYALdguirc5Q-Vi1o874-Gc',
    appId: '1:429989696553:ios:8f5a5d283008a451de3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
    iosBundleId: 'com.parkinsum.companion',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDrfrZIoByQcYALdguirc5Q-Vi1o874-Gc',
    appId: '1:429989696553:ios:8f5a5d283008a451de3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
    iosBundleId: 'com.parkinsum.companion',
  );
}
