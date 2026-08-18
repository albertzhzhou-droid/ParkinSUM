import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database.dart';
import 'package:parkinsum_companion/core/db/app_database_memory.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/models/atomic_onboarding_commit.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('registered first-day backend conformance', () {
    for (final backend in <(String, AppDatabase Function())>[
      ('memory', InMemoryAppDatabase.new),
      ('web', WebAppDatabase.new),
    ]) {
      test('${backend.$1} publishes one idempotent first-day state', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final services = Services.createEphemeral(appDatabase: backend.$2());
        await services.ready;
        final profile = _profile();
        final intake = _intake();

        final first = await services.userDataService.commitOnboarding(
          profile: profile,
          activeDrugIds: const <String>['drug_levodopa_carbidopa'],
          intakes: <Intake>[intake],
        );
        final retry = await services.userDataService.commitOnboarding(
          profile: profile,
          activeDrugIds: const <String>['drug_levodopa_carbidopa'],
          intakes: <Intake>[intake],
        );

        expect(retry.operationId, first.operationId);
        expect(
          first.operationId,
          matches(RegExp(r'^onboarding_v1_[a-f0-9]{64}$')),
        );
        await _expectCommittedState(services, profile: profile, intake: intake);

        // A late transport retry must not replay the onboarding snapshot over
        // legitimate edits made after the operation was acknowledged.
        final edited = profile.copyWith(displayLocale: 'fr-CA');
        await services.userDataService.saveUserProfile(edited);
        await services.userDataService.commitOnboarding(
          profile: profile,
          activeDrugIds: const <String>['drug_levodopa_carbidopa'],
          intakes: <Intake>[intake],
        );
        expect(
          (await services.userDataService.loadUserProfile()).displayLocale,
          'fr-CA',
        );
      });
    }

    test('web commit uses one completed aggregate envelope', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final database = WebAppDatabase();
      final services = Services.createEphemeral(appDatabase: database);
      await services.ready;
      final commit = await services.userDataService.commitOnboarding(
        profile: _profile(),
        activeDrugIds: const <String>['drug_levodopa_carbidopa'],
        intakes: <Intake>[_intake()],
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('db.user_state.v1');
      expect(raw, isNotNull);
      final envelope = jsonDecode(raw!) as Map<String, dynamic>;
      expect(envelope['onboardingOperationId'], commit.operationId);
      expect(envelope['onboardingStage'], atomicOnboardingCommitStageCommitted);
      expect(envelope['onboarded'], isTrue);
      expect(prefs.getString('db.meta.onboarded'), isNull);
      expect(prefs.getString('db.user_profile'), isNull);
      expect(prefs.getString('db.active_drugs'), isNull);
      expect(prefs.getString('db.intakes'), isNull);
    });
  });

  group('atomic onboarding failure recovery', () {
    test('pre-commit failure leaves no durable or visible fragments', () async {
      final database = _FaultInjectingAppDatabase(beforeCommitFailures: 1);
      final services = Services.createEphemeral(appDatabase: database);
      await services.ready;
      final state = AppState(services: services);
      addTearDown(state.dispose);
      await state.bootstrap();
      final beforeProfile = state.userProfile;

      await expectLater(
        state.completeOnboarding(
          profile: _profile(),
          activeDrugIds: const <String>['drug_levodopa_carbidopa'],
          initialIntake: _intake(),
        ),
        throwsStateError,
      );

      expect(state.isOnboarded, isFalse);
      expect(state.userProfile, same(beforeProfile));
      expect(state.activeDrugIds, isEmpty);
      expect(state.intakes, isEmpty);
      expect(await database.loadOnboarded(), isFalse);
      expect(await database.loadActiveDrugIds(), isEmpty);
      expect(await database.loadIntakes(), isEmpty);
      expect(
        (await database.loadUserProfile()).displayLocale,
        beforeProfile.displayLocale,
      );

      await state.completeOnboarding(
        profile: _profile(),
        activeDrugIds: const <String>['drug_levodopa_carbidopa'],
        initialIntake: _intake(),
      );
      expect(state.isOnboarded, isTrue);
      await _expectCommittedState(
        services,
        profile: _profile().copyWith(patientId: 'local_user'),
        intake: _intake(),
      );
    });

    test(
      'lost acknowledgement recovers the whole commit after restart',
      () async {
        final database = _FaultInjectingAppDatabase(afterCommitFailures: 1);
        final firstServices = Services.createEphemeral(appDatabase: database);
        await firstServices.ready;
        final firstState = AppState(services: firstServices);
        await firstState.bootstrap();

        await expectLater(
          firstState.completeOnboarding(
            profile: _profile(),
            activeDrugIds: const <String>['drug_levodopa_carbidopa'],
            initialIntake: _intake(),
          ),
          throwsStateError,
        );
        expect(firstState.isOnboarded, isFalse);
        firstState.dispose();

        final restartedServices = Services.createEphemeral(
          appDatabase: database,
        );
        await restartedServices.ready;
        final restartedState = AppState(services: restartedServices);
        addTearDown(restartedState.dispose);
        await restartedState.bootstrap();

        expect(restartedState.isOnboarded, isTrue);
        expect(restartedState.userProfile.patientId, 'local_user');
        expect(restartedState.userProfile.displayLocale, 'en-CA');
        expect(restartedState.activeDrugIds, <String>{
          'drug_levodopa_carbidopa',
        });
        expect(restartedState.intakes.map((item) => item.id), <String>[
          'first-day-intake',
        ]);

        // Retrying the exact operation is an acknowledged no-op.
        final retry = await restartedServices.userDataService.commitOnboarding(
          profile: _profile().copyWith(patientId: 'local_user'),
          activeDrugIds: const <String>['drug_levodopa_carbidopa'],
          intakes: <Intake>[_intake()],
        );
        expect(
          retry.operationId,
          matches(RegExp(r'^onboarding_v1_[a-f0-9]{64}$')),
        );
        expect((await database.loadIntakes()).length, 1);
      },
    );

    test('auth transition waits for the atomic publish boundary', () async {
      final gate = Completer<void>();
      final database = _FaultInjectingAppDatabase(beforeCommitGate: gate);
      final services = Services.createEphemeral(appDatabase: database);
      await services.ready;
      final state = AppState(services: services);
      addTearDown(state.dispose);
      await state.bootstrap();

      final commit = state.completeOnboarding(
        profile: _profile(),
        activeDrugIds: const <String>['drug_levodopa_carbidopa'],
        initialIntake: _intake(),
      );
      await database.commitEntered.future;
      var signOutCompleted = false;
      final signOut = state.signOut().then((_) => signOutCompleted = true);
      await Future<void>.delayed(Duration.zero);

      expect(signOutCompleted, isFalse);
      expect(state.currentUserId, 'local_user');

      gate.complete();
      await commit;
      await signOut;
      expect(signOutCompleted, isTrue);
      expect(state.currentUserId, isNull);
      expect(await database.loadOnboarded(), isTrue);
    });
  });

  test('committed envelope rejects digest tampering', () {
    final commit = AtomicOnboardingCommit.create(
      profile: _profile(),
      activeDrugIds: const <String>['drug_levodopa_carbidopa'],
      intakes: <Intake>[_intake()],
    );
    final tampered = Map<String, dynamic>.from(commit.toCommittedJson())
      ..['activeDrugIds'] = <String>['drug_pramipexole'];

    expect(
      () => AtomicOnboardingCommit.fromCommittedJson(tampered),
      throwsFormatException,
    );
  });
}

Future<void> _expectCommittedState(
  Services services, {
  required UserProfile profile,
  required Intake intake,
}) async {
  expect(await services.userDataService.loadOnboarded(), isTrue);
  final loadedProfile = await services.userDataService.loadUserProfile();
  expect(loadedProfile.patientId, profile.patientId);
  expect(loadedProfile.registrationRegion, profile.registrationRegion);
  expect(loadedProfile.displayLocale, profile.displayLocale);
  expect(await services.userDataService.loadActiveDrugIds(), <String>[
    'drug_levodopa_carbidopa',
  ]);
  final loadedIntakes = await services.userDataService.loadIntakes();
  expect(loadedIntakes.map((item) => item.toJson()), <Map<String, dynamic>>[
    intake.toJson(),
  ]);
}

UserProfile _profile() => UserProfile.defaults().copyWith(
  patientId: 'registered-user',
  registrationRegion: 'CA',
  displayLocale: 'en-CA',
  dietProfileRegion: 'CA',
);

Intake _intake() => Intake(
  id: 'first-day-intake',
  drugId: 'drug_levodopa_carbidopa',
  takenAt: DateTime.utc(2026, 8, 17, 12),
  dosageNote: '100/25 mg',
);

class _FaultInjectingAppDatabase extends InMemoryAppDatabase {
  _FaultInjectingAppDatabase({
    this.beforeCommitFailures = 0,
    this.afterCommitFailures = 0,
    this.beforeCommitGate,
  });

  int beforeCommitFailures;
  int afterCommitFailures;
  final Completer<void>? beforeCommitGate;
  final Completer<void> commitEntered = Completer<void>();

  @override
  Future<void> commitOnboarding(AtomicOnboardingCommit commit) async {
    if (!commitEntered.isCompleted) commitEntered.complete();
    await beforeCommitGate?.future;
    if (beforeCommitFailures > 0) {
      beforeCommitFailures -= 1;
      throw StateError('Injected failure before atomic publish.');
    }
    await super.commitOnboarding(commit);
    if (afterCommitFailures > 0) {
      afterCommitFailures -= 1;
      throw StateError('Injected lost acknowledgement after atomic publish.');
    }
  }
}
