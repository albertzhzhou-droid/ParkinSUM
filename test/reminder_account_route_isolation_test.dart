import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/app/app.dart';
import 'package:parkinsum_companion/core/services/data_service.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/features/onboarding/onboarding_page.dart';
import 'package:parkinsum_companion/features/reminders/reminder_center_page.dart';
import 'package:parkinsum_companion/features/settings/settings_capability_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'ordinary settings reminder route is removed with its owning account',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);

      await tester.pumpWidget(ParkinSUMApp(services: services));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('main-tab-home')),
      );
      final state = Provider.of<AppState>(
        tester.element(find.byKey(const ValueKey<String>('main-tab-home'))),
        listen: false,
      );

      await tester.tap(find.byKey(const ValueKey<String>('main-settings')));
      await _pumpUi(tester);
      expect(find.byType(SettingsCapabilityPage), findsOneWidget);

      final reminderTile = find.ancestor(
        of: find.byIcon(Icons.notifications_active_outlined),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(reminderTile);
      await tester.tap(reminderTile);
      await _pumpUi(tester);
      expect(find.byType(ReminderCenterPage), findsOneWidget);

      await state.signOut();
      await _pumpUi(tester);

      expect(state.currentUserId, isNull);
      expect(find.byType(ReminderCenterPage), findsNothing);
      expect(find.byType(SettingsCapabilityPage), findsNothing);
      expect(find.byType(OnboardingPage), findsOneWidget);
    },
  );

  testWidgets(
    'firebase lifecycle fails closed then rebinds a fresh UID controller',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      final state = AppState(services: services);
      addTearDown(state.dispose);
      await state.bootstrap();

      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      const accountAReminder = UserLoggingReminder(
        id: 'account-a-reminder',
        kind: UserLoggingReminderKind.intakeLog,
        label: 'Account A private reminder',
        minuteOfDay: 540,
        weekdays: {1},
        enabled: true,
        activationToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      const accountBReminder = UserLoggingReminder(
        id: 'account-b-reminder',
        kind: UserLoggingReminderKind.mealLog,
        label: 'Account B private reminder',
        minuteOfDay: 720,
        weekdays: {2},
        enabled: true,
        activationToken: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      await repository.save('local_user', const [accountAReminder]);
      await repository.save('local_b@example.com', const [accountBReminder]);
      final gateway = _RecordingGateway();
      final createdScopes = <String>[];

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            home: ReminderCenterPage(
              requireAuthenticatedAccount: true,
              controllerFactory: (userScope) {
                createdScopes.add(userScope);
                return UserLoggingReminderController(
                  userScope: userScope,
                  repository: repository,
                  gateway: gateway,
                );
              },
            ),
          ),
        ),
      );
      await _pumpUi(tester);
      expect(find.text(accountAReminder.label), findsOneWidget);
      expect(createdScopes, <String>['local_user']);
      expect(gateway.synchronizedScopes, <String>['local_user']);

      await tester.tap(find.byKey(const ValueKey<String>('reminder-add')));
      await _pumpUi(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('reminder-label')),
        'Must not cross accounts',
      );

      await state.signOut();
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('reminder-account-unavailable'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.text(accountAReminder.label), findsNothing);
      expect(gateway.synchronizedScopes, <String>['local_user']);

      await state.signInWithEmail(
        email: 'b@example.com',
        password: 'test-password',
      );
      await _pumpUi(tester);
      expect(state.currentUserId, 'local_b@example.com');
      expect(createdScopes, <String>['local_user', 'local_b@example.com']);
      expect(gateway.synchronizedScopes, <String>[
        'local_user',
        'local_b@example.com',
      ]);

      // Completing a dialog that was opened under A must not dispatch its
      // result through the fresh B controller.
      await tester.tap(find.byKey(const ValueKey<String>('reminder-save')));
      await _pumpUi(tester);
      expect(
        (await repository.load('local_user')).map((item) => item.label),
        <String>[accountAReminder.label],
      );
      expect(find.text(accountAReminder.label), findsNothing);
      expect(find.text(accountBReminder.label), findsOneWidget);
      expect(
        (await repository.load(
          'local_b@example.com',
        )).map((item) => item.label),
        <String>[accountBReminder.label],
      );
    },
  );

  testWidgets(
    'failed sign-out cancellation retries on resume while signed out',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      final source = _ScriptedLifecycleGateway(cancelFailuresRemaining: 1);
      addTearDown(source.close);
      final coordinator = ReminderNotificationResponseCoordinator(
        source: source,
        repository: UserLoggingReminderRepository(
          storage: _MemoryDataService(),
        ),
        activationInbox: ReminderNotificationActivationInbox(
          store: InMemoryReminderActivationRecordStore(),
        ),
      );

      await tester.pumpWidget(
        ParkinSUMApp(
          services: services,
          reminderResponseCoordinator: coordinator,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('main-tab-home')),
      );
      await _pumpUntilCondition(
        tester,
        () => source.events.contains('reconcile:local_user'),
      );
      source.events.clear();
      final state = Provider.of<AppState>(
        tester.element(find.byKey(const ValueKey<String>('main-tab-home'))),
        listen: false,
      );

      await state.signOut();
      await _pumpUntilCondition(
        tester,
        () => source.events.contains('cancel:1:failed'),
      );

      expect(state.currentUserId, isNull);
      expect(source.events, <String>['cancel:1:start', 'cancel:1:failed']);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpUntilCondition(
        tester,
        () => source.events.contains('cancel:2:applied'),
      );

      expect(source.events, <String>[
        'cancel:1:start',
        'cancel:1:failed',
        'cancel:2:start',
        'cancel:2:applied',
      ]);
      expect(
        source.events.where((event) => event.startsWith('reconcile:')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'new account waits for unverified old-account cancellation recovery',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      final source = _ScriptedLifecycleGateway(
        cancelFailuresRemaining: 0,
        cancelSupersededRemaining: 1,
      );
      addTearDown(source.close);
      final coordinator = ReminderNotificationResponseCoordinator(
        source: source,
        repository: UserLoggingReminderRepository(
          storage: _MemoryDataService(),
        ),
        activationInbox: ReminderNotificationActivationInbox(
          store: InMemoryReminderActivationRecordStore(),
        ),
      );

      await tester.pumpWidget(
        ParkinSUMApp(
          services: services,
          reminderResponseCoordinator: coordinator,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('main-tab-home')),
      );
      await _pumpUntilCondition(
        tester,
        () => source.events.contains('reconcile:local_user'),
      );
      source.events.clear();
      final state = Provider.of<AppState>(
        tester.element(find.byKey(const ValueKey<String>('main-tab-home'))),
        listen: false,
      );

      await state.signOut();
      await _pumpUntilCondition(
        tester,
        () => source.events.contains('cancel:1:superseded'),
      );
      await state.signInWithEmail(
        email: 'b@example.com',
        password: 'test-password',
      );
      await _pumpUntilCondition(
        tester,
        () => source.events.contains('reconcile:local_b@example.com'),
      );

      expect(state.currentUserId, 'local_b@example.com');
      expect(source.events, <String>[
        'cancel:1:start',
        'cancel:1:superseded',
        'cancel:2:start',
        'cancel:2:applied',
        'reconcile:local_b@example.com',
      ]);
      expect(source.events, isNot(contains('reconcile:local_user')));
    },
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> _pumpUi(WidgetTester tester) async {
  for (var index = 0; index < 8; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

class _MemoryDataService extends DataService {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _RecordingGateway implements ReminderNotificationGateway {
  final List<String> synchronizedScopes = <String>[];

  @override
  bool get supportsScheduledDelivery => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {
    synchronizedScopes.add(userScope);
  }
}

class _ScriptedLifecycleGateway
    implements
        ReminderNotificationGateway,
        ReminderNotificationAccountLifecycle,
        ReminderNotificationResultAccountLifecycle,
        ReminderNotificationResponseSource {
  _ScriptedLifecycleGateway({
    required this.cancelFailuresRemaining,
    this.cancelSupersededRemaining = 0,
  });

  final StreamController<ReminderNotificationResponseEvent> _responses =
      StreamController<ReminderNotificationResponseEvent>.broadcast();
  final List<String> events = <String>[];
  int cancelFailuresRemaining;
  int cancelSupersededRemaining;
  int _cancellationAttempts = 0;

  @override
  Stream<ReminderNotificationResponseEvent> get responses => _responses.stream;

  @override
  bool get supportsScheduledDelivery => true;

  @override
  Future<void> startResponseHandling() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> cancelScheduledReminders() async {
    final result = await cancelScheduledRemindersWithResult();
    if (result.status == ReminderNotificationMutationStatus.superseded) {
      throw const ReminderNotificationMutationSupersededException();
    }
  }

  @override
  Future<ReminderNotificationMutationResult>
  cancelScheduledRemindersWithResult() async {
    _cancellationAttempts += 1;
    events.add('cancel:$_cancellationAttempts:start');
    if (cancelFailuresRemaining > 0) {
      cancelFailuresRemaining -= 1;
      events.add('cancel:$_cancellationAttempts:failed');
      throw StateError('Synthetic cancellation failure.');
    }
    if (cancelSupersededRemaining > 0) {
      cancelSupersededRemaining -= 1;
      events.add('cancel:$_cancellationAttempts:superseded');
      return const ReminderNotificationMutationResult(
        ReminderNotificationMutationStatus.superseded,
      );
    }
    events.add('cancel:$_cancellationAttempts:applied');
    return const ReminderNotificationMutationResult(
      ReminderNotificationMutationStatus.applied,
    );
  }

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {
    events.add('reconcile:$userScope');
  }

  Future<void> close() => _responses.close();
}
