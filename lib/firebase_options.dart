import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static const supportedEnvironmentIds = <String>['dev', 'stage', 'prod'];

  static const productionProjectId = 'parkinsum-companion';
  static const developmentProjectId = 'parkinsum-companion-dev';
  static const stagingProjectId = 'parkinsum-companion-stage';

  static const firebaseApiKeyDefine = 'PARKINSUM_FIREBASE_API_KEY';
  static const _apiKey = String.fromEnvironment(
    firebaseApiKeyDefine,
    defaultValue: '',
  );

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

    final FirebaseOptions options;
    if (normalized == 'dev') {
      if (!kIsWeb) {
        throw UnsupportedError(
          'Firebase options for PARKINSUM_ENV=dev are currently generated '
          'for web only. Add Android/iOS/macOS dev app configs before using '
          'dev on this platform.',
        );
      }
      options = devWeb;
    } else if (normalized == 'stage') {
      if (!kIsWeb) {
        throw UnsupportedError(
          'Firebase options for PARKINSUM_ENV=stage are currently generated '
          'for web only. Add Android/iOS/macOS stage app configs before using '
          'stage on this platform.',
        );
      }
      options = stageWeb;
    } else if (kIsWeb) {
      options = web;
    } else {
      options = switch (defaultTargetPlatform) {
        TargetPlatform.android => android,
        TargetPlatform.iOS => ios,
        TargetPlatform.macOS => macos,
        TargetPlatform.windows ||
        TargetPlatform.linux ||
        TargetPlatform.fuchsia => throw UnsupportedError(
          'Firebase is configured for Android, iOS, and macOS only.',
        ),
      };
    }

    return _requireClientApiKey(options, normalized);
  }

  static FirebaseOptions _requireClientApiKey(
    FirebaseOptions options,
    String environment,
  ) {
    if (options.apiKey.trim().isNotEmpty) return options;
    throw UnsupportedError(
      'Firebase mode for PARKINSUM_ENV=$environment requires '
      '--dart-define=$firebaseApiKeyDefine=<restricted-client-key>. '
      'The value remains extractable from a built client, so restrict it in '
      'Google Cloud and never use it as an authorization boundary.',
    );
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
    apiKey: _apiKey,
    appId: '1:429989696553:web:79cbc62531c6861ade3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    authDomain: 'parkinsum-companion.firebaseapp.com',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
    measurementId: 'G-NYFEZH115V',
  );

  static const FirebaseOptions devWeb = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:36630731726:web:d9359715300da8fb13299f',
    messagingSenderId: '36630731726',
    projectId: 'parkinsum-companion-dev',
    authDomain: 'parkinsum-companion-dev.firebaseapp.com',
    storageBucket: 'parkinsum-companion-dev.firebasestorage.app',
  );

  static const FirebaseOptions stageWeb = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:51798948952:web:2f325617db7742aafe1e2d',
    messagingSenderId: '51798948952',
    projectId: 'parkinsum-companion-stage',
    authDomain: 'parkinsum-companion-stage.firebaseapp.com',
    storageBucket: 'parkinsum-companion-stage.firebasestorage.app',
    measurementId: 'G-ZTPXXMK9C5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:429989696553:android:2b43afa49913cccede3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:429989696553:ios:8f5a5d283008a451de3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
    iosBundleId: 'com.parkinsum.companion',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:429989696553:ios:8f5a5d283008a451de3838',
    messagingSenderId: '429989696553',
    projectId: 'parkinsum-companion',
    storageBucket: 'parkinsum-companion.firebasestorage.app',
    iosBundleId: 'com.parkinsum.companion',
  );
}
