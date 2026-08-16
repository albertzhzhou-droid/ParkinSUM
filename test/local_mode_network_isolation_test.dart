import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_firestore.dart';
import 'package:parkinsum_companion/core/db/cdss_database_firestore.dart';
import 'package:parkinsum_companion/core/services/auth_service.dart';
import 'package:parkinsum_companion/core/services/firebase_backend.dart';
import 'package:parkinsum_companion/core/services/services.dart';

/// Public/local demo mode network isolation.
///
/// Configuration-level proof that the default (public demo) build does not
/// require Firebase or external network access: with `PARKINSUM_BACKEND`
/// unset, the backend gate stays `local`, `Services.createDefault()` wires
/// only local/in-memory/synthetic-seeded services, and the Firebase
/// initializer is a no-op. This is the deterministic check behind the
/// "local-first public demo" promise in docs/PUBLIC_DEMO_BOUNDARY.md.
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default build configuration selects local mode', () {
    // Tests run without --dart-define, so this also pins the DEFAULT value:
    // a plain build is local mode unless Firebase is explicitly requested.
    expect(FirebaseBackend.backendMode, 'local');
    expect(FirebaseBackend.enabled, isFalse);
  });

  test('local mode constructs no Firebase-backed services', () {
    // Service-type selection happens synchronously in createDefault(). The
    // background `ready` future opens the local sqlite database, which has no
    // platform support inside a VM test — that init failure is irrelevant to
    // the network-isolation property under test, so it is captured by a
    // guarded zone instead of failing the test.
    Services? services;
    runZonedGuarded(
      () {
        services = Services.createDefault();
      },
      (_, _) {
        // Local sqlite init is unavailable in VM tests; intentionally ignored.
      },
    );
    expect(services, isNotNull);
    expect(
      services!.authService,
      isA<LocalAuthService>(),
      reason: 'Auth must be the local in-memory service in demo mode.',
    );
    expect(services!.authService, isNot(isA<FirebaseAuthService>()));
    expect(
      services!.appDatabase,
      isNot(isA<FirestoreAppDatabase>()),
      reason: 'App data must stay on the local database in demo mode.',
    );
    expect(
      services!.cdssDatabase,
      isNot(isA<FirestoreCdssDatabase>()),
      reason: 'CDSS data must stay on the local database in demo mode.',
    );
  });

  test(
    'Firebase initialization is a no-op when the backend is local',
    () async {
      // ensureInitialized() returns before touching any Firebase API when the
      // gate is closed; if it tried to initialize Firebase in a plain test
      // environment this would throw (no platform channels available).
      await FirebaseBackend.ensureInitialized();
    },
  );
}
