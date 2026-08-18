import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/app/app.dart';
import 'package:parkinsum_companion/core/services/data_service.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'foreground responses open confirmation-first drafts without writing records',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);

      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      const mealReminder = UserLoggingReminder(
        id: 'meal-route',
        kind: UserLoggingReminderKind.mealLog,
        label: 'Log a meal',
        minuteOfDay: 720,
        weekdays: {1},
        enabled: true,
        activationToken: '11111111111111111111111111111111',
      );
      const intakeReminder = UserLoggingReminder(
        id: 'intake-route',
        kind: UserLoggingReminderKind.intakeLog,
        label: 'Log an intake',
        minuteOfDay: 720,
        weekdays: {1},
        enabled: true,
        activationToken: '22222222222222222222222222222222',
      );
      const secondMealReminder = UserLoggingReminder(
        id: 'second-meal-route',
        kind: UserLoggingReminderKind.mealLog,
        label: 'Log another meal',
        minuteOfDay: 780,
        weekdays: {1},
        enabled: true,
        activationToken: '44444444444444444444444444444444',
      );
      await repository.save('local_user', const [
        mealReminder,
        intakeReminder,
        secondMealReminder,
      ]);
      final source = _FakeResponseSource();
      addTearDown(source.close);
      final activationStore = InMemoryReminderActivationRecordStore();
      final coordinator = ReminderNotificationResponseCoordinator(
        source: source,
        repository: repository,
        activationInbox: ReminderNotificationActivationInbox(
          store: activationStore,
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
      expect(source.started, isTrue);
      expect(await services.userDataService.loadMeals(), isEmpty);
      expect(await services.userDataService.loadIntakes(), isEmpty);

      source.emit(
        ReminderNotificationResponseCoordinator.payloadForReminder(
          mealReminder,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('reminder-meal-draft')),
      );
      expect(await services.userDataService.loadMeals(), isEmpty);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('reminder-meal-draft')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('main-tab-home')),
        findsOneWidget,
      );
      source.emit(
        ReminderNotificationResponseCoordinator.payloadForReminder(
          intakeReminder,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('reminder-intake-draft')),
      );
      expect(
        find.byKey(
          const ValueKey<String>('reminder-intake-medication-selection'),
        ),
        findsOneWidget,
      );
      expect(await services.userDataService.loadIntakes(), isEmpty);

      source.emit(
        ReminderNotificationResponseCoordinator.payloadForReminder(
          secondMealReminder,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('reminder-meal-draft')),
      );
      final state = Provider.of<AppState>(
        tester.element(
          find.byKey(const ValueKey<String>('reminder-meal-draft')),
        ),
        listen: false,
      );
      await state.signOut();
      await tester.pumpAndSettle();

      expect(state.currentUserId, isNull);
      expect(source.cancellationCount, 1);
      expect(
        find.byKey(const ValueKey<String>('reminder-meal-draft')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('reminder-intake-draft')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'cold-start response waits for bootstrap before opening a draft',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      const reminder = UserLoggingReminder(
        id: 'cold-start-meal',
        kind: UserLoggingReminderKind.mealLog,
        label: 'Private cold start label',
        minuteOfDay: 480,
        weekdays: {2},
        enabled: true,
        activationToken: '55555555555555555555555555555555',
      );
      final repository = UserLoggingReminderRepository(
        storage: _MemoryDataService(),
      );
      await repository.save('local_user', const [reminder]);
      final source = _FakeResponseSource(
        startupPayload:
            ReminderNotificationResponseCoordinator.payloadForReminder(
              reminder,
            ),
      );
      addTearDown(source.close);

      await tester.pumpWidget(
        ParkinSUMApp(
          services: services,
          reminderResponseCoordinator: ReminderNotificationResponseCoordinator(
            source: source,
            repository: repository,
            activationInbox: ReminderNotificationActivationInbox(
              store: InMemoryReminderActivationRecordStore(),
            ),
          ),
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('reminder-meal-draft')),
      );

      expect(await services.userDataService.loadMeals(), isEmpty);
    },
  );

  testWidgets(
    'a journaled pre-bootstrap activation is recovered after coordinator restart',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      const reminder = UserLoggingReminder(
        id: 'journaled-meal',
        kind: UserLoggingReminderKind.mealLog,
        label: 'Private journal recovery label',
        minuteOfDay: 600,
        weekdays: {1},
        enabled: true,
        activationToken: '66666666666666666666666666666666',
      );
      final repository = UserLoggingReminderRepository(
        storage: _MemoryDataService(),
      );
      await repository.save('local_user', const [reminder]);
      final activationStore = InMemoryReminderActivationRecordStore();
      await ReminderNotificationActivationInbox(store: activationStore).capture(
        ReminderNotificationResponseEvent(
          payload: ReminderNotificationResponseCoordinator.payloadForReminder(
            reminder,
          ),
          origin: ReminderNotificationResponseOrigin.coldStart,
        ),
      );
      final source = _FakeResponseSource();
      addTearDown(source.close);

      await tester.pumpWidget(
        ParkinSUMApp(
          services: services,
          reminderResponseCoordinator: ReminderNotificationResponseCoordinator(
            source: source,
            repository: repository,
            activationInbox: ReminderNotificationActivationInbox(
              store: activationStore,
            ),
          ),
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('reminder-meal-draft')),
      );

      expect(await services.userDataService.loadMeals(), isEmpty);
      expect(
        activationStore.snapshot.single.disposition,
        ReminderActivationDisposition.claimed,
      );
    },
  );

  testWidgets(
    'account-transition gate discards delayed old capture and preserves new capture',
    (tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      const oldReminder = UserLoggingReminder(
        id: 'old-account-meal',
        kind: UserLoggingReminderKind.mealLog,
        label: 'Old private label',
        minuteOfDay: 600,
        weekdays: {1},
        enabled: true,
        activationToken: '77777777777777777777777777777777',
      );
      const newReminder = UserLoggingReminder(
        id: 'new-account-meal',
        kind: UserLoggingReminderKind.mealLog,
        label: 'New private label',
        minuteOfDay: 660,
        weekdays: {1},
        enabled: true,
        activationToken: '88888888888888888888888888888888',
      );
      final repository = UserLoggingReminderRepository(
        storage: _MemoryDataService(),
      );
      await repository.save('local_user', const [oldReminder]);
      await repository.save('local_b@example.com', const [newReminder]);
      final store = _DelaySecondTransactionStore();
      final source = _FakeResponseSource();
      addTearDown(source.close);

      await tester.pumpWidget(
        ParkinSUMApp(
          services: services,
          reminderResponseCoordinator: ReminderNotificationResponseCoordinator(
            source: source,
            repository: repository,
            activationInbox: ReminderNotificationActivationInbox(store: store),
          ),
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('main-tab-home')),
      );
      source.emit(
        ReminderNotificationResponseCoordinator.payloadForReminder(oldReminder),
      );
      await store.delayedTransactionStarted.future;

      final state = Provider.of<AppState>(
        tester.element(find.byKey(const ValueKey<String>('main-tab-home'))),
        listen: false,
      );
      await state.signOut();
      await state.signInWithEmail(
        email: 'b@example.com',
        password: 'test-password',
      );
      source.emit(
        ReminderNotificationResponseCoordinator.payloadForReminder(newReminder),
      );
      store.releaseDelayedTransaction.complete();

      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('reminder-meal-draft')),
      );
      final byPayload = <String?, ReminderActivationDisposition>{
        for (final entry in store.snapshot) entry.payload: entry.disposition,
      };
      expect(
        byPayload[ReminderNotificationResponseCoordinator.payloadForReminder(
          oldReminder,
        )],
        ReminderActivationDisposition.discarded,
      );
      expect(
        byPayload[ReminderNotificationResponseCoordinator.payloadForReminder(
          newReminder,
        )],
        ReminderActivationDisposition.claimed,
      );
      expect(await services.userDataService.loadMeals(), isEmpty);
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

class _MemoryDataService extends DataService {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FakeResponseSource
    implements
        ReminderNotificationResponseSource,
        ReminderNotificationAccountLifecycle {
  _FakeResponseSource({this.startupPayload});

  final String? startupPayload;
  final StreamController<ReminderNotificationResponseEvent> _controller =
      StreamController<ReminderNotificationResponseEvent>.broadcast();
  bool started = false;
  int cancellationCount = 0;

  @override
  Future<void> cancelScheduledReminders() async {
    cancellationCount += 1;
  }

  @override
  Stream<ReminderNotificationResponseEvent> get responses => _controller.stream;

  @override
  Future<void> startResponseHandling() async {
    started = true;
    final payload = startupPayload;
    if (payload != null) {
      _controller.add(
        ReminderNotificationResponseEvent(
          payload: payload,
          origin: ReminderNotificationResponseOrigin.coldStart,
        ),
      );
    }
  }

  void emit(String payload) {
    _controller.add(
      ReminderNotificationResponseEvent(
        payload: payload,
        origin: ReminderNotificationResponseOrigin.foreground,
      ),
    );
  }

  Future<void> close() => _controller.close();
}

class _DelaySecondTransactionStore implements ReminderActivationRecordStore {
  List<ReminderNotificationActivation> _entries =
      <ReminderNotificationActivation>[];
  Future<void> _tail = Future<void>.value();
  int _transactionCount = 0;
  final Completer<void> delayedTransactionStarted = Completer<void>();
  final Completer<void> releaseDelayedTransaction = Completer<void>();

  List<ReminderNotificationActivation> get snapshot =>
      List<ReminderNotificationActivation>.unmodifiable(_entries);

  @override
  Future<T> transaction<T>(
    T Function(List<ReminderNotificationActivation> entries) operation,
  ) {
    final transactionNumber = ++_transactionCount;
    final queued = _tail.then((_) async {
      if (transactionNumber == 2) {
        delayedTransactionStarted.complete();
        await releaseDelayedTransaction.future;
      }
      final working = List<ReminderNotificationActivation>.of(_entries);
      final result = operation(working);
      _entries = List<ReminderNotificationActivation>.unmodifiable(working);
      return result;
    });
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}
