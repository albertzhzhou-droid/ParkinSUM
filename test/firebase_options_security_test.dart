import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tracked Firebase options default to no client API key', () {
    final options = [
      DefaultFirebaseOptions.web,
      DefaultFirebaseOptions.devWeb,
      DefaultFirebaseOptions.stageWeb,
      DefaultFirebaseOptions.android,
      DefaultFirebaseOptions.ios,
      DefaultFirebaseOptions.macos,
    ];

    expect(
      options.map((value) => value.apiKey),
      everyElement(isEmpty),
      reason:
          'CI tests run without PARKINSUM_FIREBASE_API_KEY; a non-empty '
          'default would reintroduce a public repository key.',
    );
  });

  test('Firebase mode fails closed when the client key is omitted', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(
      () => DefaultFirebaseOptions.currentPlatformForEnvironment('prod'),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message.toString(),
          'message',
          contains(DefaultFirebaseOptions.firebaseApiKeyDefine),
        ),
      ),
    );
  });
}
