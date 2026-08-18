import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:crypto/crypto.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/user_logging_reminder.dart';
import 'data_service.dart';
import 'reminder_activation_inbox.dart';
import 'reminder_activation_store_factory.dart';
import 'reminder_pending_identity_attestation.dart';
import 'reminder_notification_privacy_policy.dart';
import 'reminder_schedule_manifest.dart';

export 'reminder_activation_inbox.dart';
export 'reminder_pending_identity_attestation.dart';
export 'reminder_schedule_manifest.dart';

const reminderSafetyBoundary =
    'Logging reminder only — ParkinSUM does not calculate or prescribe a dose time.';
const reminderNativeOperationTimeout = Duration(seconds: 20);

/// A bounded, process-local witness for repository-acknowledged reminder-store
/// writes whose encoded value passed an immediate read-back check.
///
/// This intentionally does not claim cross-isolate or external storage-change
/// observation. Consumers can bind transient decisions to [read] and listen to
/// [changes] so another repository instance in this Dart process invalidates
/// stale state as soon as its write passes immediate exact read-back.
abstract final class UserLoggingReminderProcessRevision {
  static const int _maxTrackedScopes = 128;
  static final LinkedHashMap<String, int> _scopeRevisions =
      LinkedHashMap<String, int>();
  static final ValueNotifier<int> _changeSignal = ValueNotifier<int>(0);
  static int _nextRevision = 0;
  static int _evictionEpoch = 0;

  static ValueListenable<int> get changes => _changeSignal;

  static String read(String userScope) {
    final scopeDigest = _scopeDigest(userScope);
    final revision = _scopeRevisions[scopeDigest];
    return revision == null ? 'absent-$_evictionEpoch' : 'revision-$revision';
  }

  static void _recordSuccessfulSave(String userScope) {
    final scopeDigest = _scopeDigest(userScope);
    _scopeRevisions.remove(scopeDigest);
    _nextRevision += 1;
    _scopeRevisions[scopeDigest] = _nextRevision;
    if (_scopeRevisions.length > _maxTrackedScopes) {
      _scopeRevisions.remove(_scopeRevisions.keys.first);
      _evictionEpoch += 1;
    }
    _changeSignal.value += 1;
  }

  @visibleForTesting
  static void debugResetForTesting() {
    _scopeRevisions.clear();
    _nextRevision = 0;
    _evictionEpoch += 1;
    _changeSignal.value += 1;
  }

  static String _scopeDigest(String userScope) =>
      sha256.convert(utf8.encode(userScope)).toString();
}

class UserLoggingReminderRepository {
  UserLoggingReminderRepository({DataService? storage})
    : _storage = storage ?? SharedPrefsDataService();

  final DataService _storage;

  Future<List<UserLoggingReminder>> load(String userScope) async {
    final key = _key(userScope);
    var raw = await _storage.getString(key);
    final legacyKey = _legacyKey(userScope);
    final migratedFromV2 = raw == null;
    raw ??= await _storage.getString(legacyKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final reminders = _decode(raw);
    if (migratedFromV2) {
      await save(userScope, reminders);
      await _storage.remove(legacyKey);
    }
    return reminders;
  }

  List<UserLoggingReminder> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Reminder store invalid.');
    }
    return List<UserLoggingReminder>.unmodifiable(
      decoded.map(
        (row) =>
            UserLoggingReminder.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
    );
  }

  Future<void> save(
    String userScope,
    List<UserLoggingReminder> reminders,
  ) async {
    final encoded = jsonEncode(
      reminders.map((reminder) => reminder.toJson()).toList(),
    );
    await _storage.setString(_key(userScope), encoded);
    if (await _storage.getString(_key(userScope)) != encoded) {
      throw StateError('Reminder persistence verification failed.');
    }
    UserLoggingReminderProcessRevision._recordSuccessfulSave(userScope);
  }

  String _key(String scope) {
    final digest = sha256.convert(utf8.encode(scope)).toString();
    return 'parkinsum.user_logging_reminders.v3.$digest';
  }

  String _legacyKey(String scope) {
    final digest = sha256.convert(utf8.encode(scope)).toString();
    // Keep the historical migration key distinct from the single current
    // version marker discovered by the schema catalog checker.
    return 'parkinsum.user_logging_reminders.'
        'v2.$digest';
  }
}

enum ReminderPersistenceMutationStatus { applied, superseded }

class ReminderPersistenceMutationResult {
  const ReminderPersistenceMutationResult(this.status);

  final ReminderPersistenceMutationStatus status;

  bool get wasApplied => status == ReminderPersistenceMutationStatus.applied;
}

class _ReminderPersistenceMutationLease {
  const _ReminderPersistenceMutationLease._(
    this._owner,
    this._scopeDigest,
    this._epoch,
  );

  final _ReminderPersistenceMutationCoordinator _owner;
  final String _scopeDigest;
  final int _epoch;
}

/// Process-wide, scope-keyed compare-and-set gate for reminder persistence.
///
/// Native scheduling is serialized by [ReminderNativeMutationQueue], but two
/// controllers for the same signed-in account can still overlap while a
/// repository write is awaiting storage. A newer scope mutation invalidates
/// the older persistence lease immediately. Writes remain serialized per
/// scope, so if an older write was already in progress, the newer write runs
/// after it and becomes the durable final state. A stale rollback is skipped.
class _ReminderPersistenceMutationCoordinator {
  _ReminderPersistenceMutationCoordinator();

  static final _ReminderPersistenceMutationCoordinator shared =
      _ReminderPersistenceMutationCoordinator();

  final Map<String, int> _epochs = {};
  final Map<String, Future<void>> _tails = {};

  _ReminderPersistenceMutationLease beginLease({required String userScope}) {
    final scopeDigest = sha256.convert(utf8.encode(userScope)).toString();
    final epoch = (_epochs[scopeDigest] ?? 0) + 1;
    _epochs[scopeDigest] = epoch;
    return _ReminderPersistenceMutationLease._(this, scopeDigest, epoch);
  }

  bool isCurrent(_ReminderPersistenceMutationLease lease) {
    _validateLease(lease);
    return _epochs[lease._scopeDigest] == lease._epoch;
  }

  Future<ReminderPersistenceMutationResult> mutateIfCurrent({
    required _ReminderPersistenceMutationLease lease,
    required Future<void> Function() operation,
  }) {
    _validateLease(lease);
    return _enqueue(lease._scopeDigest, () async {
      if (!isCurrent(lease)) {
        return const ReminderPersistenceMutationResult(
          ReminderPersistenceMutationStatus.superseded,
        );
      }
      await operation();
      return ReminderPersistenceMutationResult(
        isCurrent(lease)
            ? ReminderPersistenceMutationStatus.applied
            : ReminderPersistenceMutationStatus.superseded,
      );
    });
  }

  void _validateLease(_ReminderPersistenceMutationLease lease) {
    if (!identical(lease._owner, this)) {
      throw ArgumentError('Reminder persistence lease is not transferable.');
    }
  }

  Future<T> _enqueue<T>(String scopeDigest, Future<T> Function() operation) {
    final previous = _tails[scopeDigest] ?? Future<void>.value();
    final queued = previous.then((_) => operation());
    late final Future<void> tail;
    void clearTail() {
      if (identical(_tails[scopeDigest], tail)) {
        _tails.remove(scopeDigest);
      }
    }

    tail = queued.then<void>(
      (_) => clearTail(),
      onError: (Object _, StackTrace _) => clearTail(),
    );
    _tails[scopeDigest] = tail;
    return queued;
  }
}

bool isReminderActivationTokenValid(String value) =>
    isReminderOpaqueTokenValid(value);

String newReminderActivationToken() => newReminderOpaqueToken();

abstract class ReminderNotificationGateway {
  bool get supportsScheduledDelivery;
  Future<bool> requestPermission();
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  });
}

enum ReminderNotificationMutationStatus { applied, superseded, unsupported }

class ReminderNotificationMutationResult {
  const ReminderNotificationMutationResult(this.status);

  final ReminderNotificationMutationStatus status;

  bool get wasApplied => status == ReminderNotificationMutationStatus.applied;
}

/// An opaque, queue-owned capability for one account-scoped mutation.
///
/// A lease cannot be reused for another account or another gateway queue. A
/// newer mutation or account cancellation invalidates it synchronously, even
/// when the older native operation is still in flight.
class ReminderNotificationMutationLease {
  const ReminderNotificationMutationLease._(
    this._owner,
    this._epoch,
    this.userScope,
  );

  final ReminderNativeMutationQueue _owner;
  final int _epoch;
  final String userScope;
}

/// Result-bearing extension used by the production gateway. The original
/// [ReminderNotificationGateway] remains source-compatible for simple fakes.
abstract class ReminderNotificationLeaseGateway {
  ReminderNotificationMutationLease beginMutationLease({
    required String userScope,
  });

  bool isMutationLeaseCurrent(
    ReminderNotificationMutationLease lease, {
    required String userScope,
  });

  Future<ReminderNotificationMutationResult> synchronizeWithLease(
    List<UserLoggingReminder> reminders, {
    required String userScope,
    required ReminderNotificationMutationLease lease,
  });
}

abstract class ReminderNotificationResultAccountLifecycle {
  Future<ReminderNotificationMutationResult>
  cancelScheduledRemindersWithResult();
}

class ReminderNotificationMutationSupersededException implements Exception {
  const ReminderNotificationMutationSupersededException();

  @override
  String toString() => 'Reminder notification mutation was superseded.';
}

abstract class ReminderNotificationPreflight {
  ReminderScheduleManifestResult preflightSchedule(
    List<UserLoggingReminder> reminders,
  );
}

const int reminderScheduleProductRequestLimit = 64;

abstract class ReminderNotificationInspector {
  Future<int> pendingReminderCount();
}

/// Identity-level inspection of the plugin-reported pending registry.
///
/// This does not claim independent operating-system verification. It exists so
/// callers can distinguish exact plugin-registry agreement from count-only or
/// wholly uninspected schedule state.
abstract class ReminderNotificationIdentityInspector {
  Future<ReminderPendingIdentityAttestation> attestPendingSchedule(
    List<UserLoggingReminder> reminders,
  );
}

abstract class ReminderNotificationAccountLifecycle {
  Future<void> cancelScheduledReminders();
}

abstract class ReminderNotificationResponseSource {
  Stream<ReminderNotificationResponseEvent> get responses;
  Future<void> startResponseHandling();
}

/// Serializes native notification mutations while letting a newer account or
/// plan invalidate work that is already in flight. Callers may time out while
/// waiting, but the underlying mutation remains in this queue until it really
/// settles, so a later cancellation cannot be overtaken by late native work.
class ReminderNativeMutationQueue {
  Future<void> _tail = Future<void>.value();
  int _epoch = 0;
  String? _latestUserScope;

  ReminderNotificationMutationLease beginLease({required String userScope}) {
    final epoch = ++_epoch;
    _latestUserScope = userScope;
    return ReminderNotificationMutationLease._(this, epoch, userScope);
  }

  bool isCurrent(
    ReminderNotificationMutationLease lease, {
    required String userScope,
  }) {
    _validateLease(lease, userScope: userScope);
    return lease._epoch == _epoch && _latestUserScope == userScope;
  }

  Future<ReminderNotificationMutationResult> synchronize({
    required String userScope,
    required Future<void> Function(bool Function() isCurrent) operation,
  }) => synchronizeWithLease(
    userScope: userScope,
    lease: beginLease(userScope: userScope),
    operation: operation,
  );

  Future<ReminderNotificationMutationResult> synchronizeWithLease({
    required String userScope,
    required ReminderNotificationMutationLease lease,
    required Future<void> Function(bool Function() isCurrent) operation,
  }) {
    _validateLease(lease, userScope: userScope);
    bool leaseIsCurrent() => isCurrent(lease, userScope: userScope);
    return _enqueue(() async {
      if (!leaseIsCurrent()) {
        return const ReminderNotificationMutationResult(
          ReminderNotificationMutationStatus.superseded,
        );
      }
      await operation(leaseIsCurrent);
      return ReminderNotificationMutationResult(
        leaseIsCurrent()
            ? ReminderNotificationMutationStatus.applied
            : ReminderNotificationMutationStatus.superseded,
      );
    });
  }

  Future<ReminderNotificationMutationResult> cancel({
    required Future<void> Function() operation,
  }) {
    _epoch += 1;
    _latestUserScope = null;
    return _enqueue(() async {
      await operation();
      return const ReminderNotificationMutationResult(
        ReminderNotificationMutationStatus.applied,
      );
    });
  }

  void _validateLease(
    ReminderNotificationMutationLease lease, {
    required String userScope,
  }) {
    if (!identical(lease._owner, this) || lease.userScope != userScope) {
      throw ArgumentError('Reminder mutation lease is not transferable.');
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}

enum ReminderResponseResolutionStatus {
  openMealDraft,
  openIntakeDraft,
  unavailable,
  malformed,
  replayed,
}

class ReminderResponseResolution {
  const ReminderResponseResolution(this.status);

  final ReminderResponseResolutionStatus status;

  bool get opensDraft =>
      status == ReminderResponseResolutionStatus.openMealDraft ||
      status == ReminderResponseResolutionStatus.openIntakeDraft;
}

/// Resolves an opaque notification response against the currently signed-in
/// user's durable reminder plan. The payload contains no label, medication,
/// dose, meal, email, or patient identifier. A response never writes a meal or
/// intake; UI code may only use a successful resolution to open a blank draft.
class ReminderNotificationResponseCoordinator {
  ReminderNotificationResponseCoordinator({
    ReminderNotificationResponseSource? source,
    UserLoggingReminderRepository? repository,
    ReminderNotificationActivationInbox? activationInbox,
    DateTime Function()? now,
  }) : source = source ?? LocalReminderNotificationGateway.shared,
       _repository = repository ?? UserLoggingReminderRepository(),
       _activationInbox =
           activationInbox ??
           ReminderNotificationActivationInbox(
             store: createReminderActivationRecordStore(),
             now: now,
           );

  final ReminderNotificationResponseSource source;
  final UserLoggingReminderRepository _repository;
  final ReminderNotificationActivationInbox _activationInbox;

  Future<void> reconcileScheduleForUser(String userScope) async {
    final candidate = source;
    if (candidate is! ReminderNotificationGateway) return;
    final gateway = candidate as ReminderNotificationGateway;
    final controller = UserLoggingReminderController(
      userScope: userScope,
      repository: _repository,
      gateway: gateway,
    );
    try {
      await controller.load();
    } finally {
      controller.dispose();
    }
  }

  Future<void> cancelScheduledReminders() async {
    final candidate = source;
    if (candidate is ReminderNotificationAccountLifecycle) {
      await (candidate as ReminderNotificationAccountLifecycle)
          .cancelScheduledReminders();
    }
  }

  static final RegExp _payloadPattern = RegExp(
    r'^parkinsum-reminder:v2:([a-f0-9]{32}):([A-Za-z0-9_-]{1,80})$',
  );

  static String payloadForReminder(UserLoggingReminder reminder) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(reminder.id)) {
      throw const FormatException('Reminder id is not notification-safe.');
    }
    if (!isReminderActivationTokenValid(reminder.activationToken)) {
      throw const FormatException('Reminder activation token is invalid.');
    }
    return 'parkinsum-reminder:v2:${reminder.activationToken}:${reminder.id}';
  }

  Future<ReminderResponseResolution> resolve({
    required ReminderNotificationResponseEvent event,
    required String userScope,
  }) async {
    try {
      final activation = await capture(event);
      return await resolveActivation(
        activation: activation,
        userScope: userScope,
      );
    } catch (_) {
      return const ReminderResponseResolution(
        ReminderResponseResolutionStatus.unavailable,
      );
    }
  }

  Future<ReminderNotificationActivation> capture(
    ReminderNotificationResponseEvent event,
  ) => _activationInbox.capture(event);

  Future<List<ReminderNotificationActivation>> pendingActivations({
    int limit = 8,
  }) => _activationInbox.pending(limit: limit);

  Future<void> discardActivation(String activationId) =>
      _activationInbox.discard(activationId);

  Future<void> discardPendingActivations() => _activationInbox.discardPending();

  Future<ReminderResponseResolution> resolveActivation({
    required ReminderNotificationActivation activation,
    required String userScope,
  }) async {
    final ReminderActivationClaim claim;
    try {
      claim = await _activationInbox.claim(activation.id);
    } catch (_) {
      return const ReminderResponseResolution(
        ReminderResponseResolutionStatus.unavailable,
      );
    }
    switch (claim.status) {
      case ReminderActivationClaimStatus.claimed:
        break;
      case ReminderActivationClaimStatus.replayed:
        return const ReminderResponseResolution(
          ReminderResponseResolutionStatus.replayed,
        );
      case ReminderActivationClaimStatus.discarded:
      case ReminderActivationClaimStatus.expired:
      case ReminderActivationClaimStatus.missing:
        return const ReminderResponseResolution(
          ReminderResponseResolutionStatus.unavailable,
        );
    }

    final payload = claim.activation?.payload;
    if (payload == null) {
      return const ReminderResponseResolution(
        ReminderResponseResolutionStatus.malformed,
      );
    }
    final match = _payloadPattern.firstMatch(payload);
    if (match == null) {
      return const ReminderResponseResolution(
        ReminderResponseResolutionStatus.malformed,
      );
    }

    try {
      final reminders = await _repository.load(userScope);
      final reminder = reminders
          .where((candidate) => candidate.id == match.group(2))
          .firstOrNull;
      if (reminder == null ||
          !reminder.enabled ||
          reminder.activationToken != match.group(1)) {
        return const ReminderResponseResolution(
          ReminderResponseResolutionStatus.unavailable,
        );
      }
      return ReminderResponseResolution(
        reminder.kind == UserLoggingReminderKind.mealLog
            ? ReminderResponseResolutionStatus.openMealDraft
            : ReminderResponseResolutionStatus.openIntakeDraft,
      );
    } catch (_) {
      return const ReminderResponseResolution(
        ReminderResponseResolutionStatus.unavailable,
      );
    }
  }
}

class LocalReminderNotificationGateway
    implements
        ReminderNotificationGateway,
        ReminderNotificationLeaseGateway,
        ReminderNotificationPreflight,
        ReminderNotificationInspector,
        ReminderNotificationIdentityInspector,
        ReminderNotificationAccountLifecycle,
        ReminderNotificationResultAccountLifecycle,
        ReminderNotificationResponseSource {
  LocalReminderNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final LocalReminderNotificationGateway shared =
      LocalReminderNotificationGateway();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<ReminderNotificationResponseEvent>
  _responseController =
      StreamController<ReminderNotificationResponseEvent>.broadcast();
  bool _initialized = false;
  bool _responseHandlingStarted = false;
  Future<void>? _initializationFuture;
  Future<void>? _responseStartFuture;
  final ReminderNativeMutationQueue _mutationQueue =
      ReminderNativeMutationQueue();

  @override
  Stream<ReminderNotificationResponseEvent> get responses =>
      _responseController.stream;

  @override
  bool get supportsScheduledDelivery {
    if (kIsWeb) return false;
    return const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
  }

  Future<void> _initialize() {
    if (_initialized) return Future<void>.value();
    var active = _initializationFuture;
    if (active == null) {
      late final Future<void> operation;
      operation = _performInitialization().whenComplete(() {
        if (identical(_initializationFuture, operation)) {
          _initializationFuture = null;
        }
      });
      _initializationFuture = operation;
      active = operation;
    }
    return active.timeout(reminderNativeOperationTimeout);
  }

  Future<void> _performInitialization() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open ParkinSUM'),
        windows: WindowsInitializationSettings(
          appName: 'ParkinSUM Companion',
          appUserModelId: 'ParkinSUM.Companion.Reminders.1',
          guid: '5f9b6db1-7841-47a0-899a-d32bf8de4c38',
        ),
        web: WebInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        _responseController.add(
          ReminderNotificationResponseEvent(
            payload: response.payload,
            origin: ReminderNotificationResponseOrigin.foreground,
          ),
        );
      },
    );
    _initialized = true;
  }

  @override
  Future<void> startResponseHandling() {
    if (_responseHandlingStarted) return Future<void>.value();
    var active = _responseStartFuture;
    if (active == null) {
      late final Future<void> operation;
      operation = _performResponseStart().whenComplete(() {
        if (identical(_responseStartFuture, operation)) {
          _responseStartFuture = null;
        }
      });
      _responseStartFuture = operation;
      active = operation;
    }
    return active.timeout(reminderNativeOperationTimeout);
  }

  Future<void> _performResponseStart() async {
    try {
      await _initialize();
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _responseController.add(
          ReminderNotificationResponseEvent(
            payload: launch?.notificationResponse?.payload,
            origin: ReminderNotificationResponseOrigin.coldStart,
          ),
        );
      }
      _responseHandlingStarted = true;
    } catch (_) {
      _responseHandlingStarted = false;
      rethrow;
    }
  }

  @override
  Future<bool> requestPermission() async {
    await _initialize();
    if (kIsWeb) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                WebFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    return true;
  }

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {
    final result = await synchronizeWithLease(
      reminders,
      userScope: userScope,
      lease: beginMutationLease(userScope: userScope),
    );
    if (result.status == ReminderNotificationMutationStatus.superseded) {
      throw const ReminderNotificationMutationSupersededException();
    }
  }

  @override
  ReminderNotificationMutationLease beginMutationLease({
    required String userScope,
  }) => _mutationQueue.beginLease(userScope: userScope);

  @override
  bool isMutationLeaseCurrent(
    ReminderNotificationMutationLease lease, {
    required String userScope,
  }) => _mutationQueue.isCurrent(lease, userScope: userScope);

  @override
  Future<ReminderNotificationMutationResult> synchronizeWithLease(
    List<UserLoggingReminder> reminders, {
    required String userScope,
    required ReminderNotificationMutationLease lease,
  }) {
    if (!supportsScheduledDelivery) {
      _mutationQueue.isCurrent(lease, userScope: userScope);
      return Future.value(
        const ReminderNotificationMutationResult(
          ReminderNotificationMutationStatus.unsupported,
        ),
      );
    }
    return _mutationQueue
        .synchronizeWithLease(
          userScope: userScope,
          lease: lease,
          operation: (isCurrent) =>
              _performSynchronization(reminders, isCurrent: isCurrent),
        )
        .timeout(reminderNativeOperationTimeout);
  }

  Future<void> _performSynchronization(
    List<UserLoggingReminder> reminders, {
    required bool Function() isCurrent,
  }) async {
    if (!supportsScheduledDelivery || !isCurrent()) return;
    final preflight = preflightSchedule(reminders);
    if (!preflight.accepted) {
      throw ReminderSchedulePreflightException(preflight);
    }
    final manifest = preflight.manifest!;
    final remindersById = <String, UserLoggingReminder>{
      for (final reminder in reminders) reminder.id: reminder,
    };
    await _initialize();
    if (!isCurrent()) return;
    // Refresh the IANA zone on every reconciliation. A plugin instance can
    // outlive a device timezone change, while the reminder stores a local
    // weekday/time pattern rather than a fixed UTC instant.
    final zone = await FlutterTimezone.getLocalTimezone();
    if (!isCurrent()) return;
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _cancelPendingLoggingReminders();
    if (!isCurrent()) return;
    for (final entry in manifest.entries) {
      if (!isCurrent()) return;
      final reminder = remindersById[entry.reminderId]!;
      final scheduled = _nextWeekday(reminder, entry.weekday);
      final presentation = ReminderNotificationPrivacyPolicy.resolve(
        mode: reminder.notificationPrivacyMode,
        localeName: reminder.notificationLocaleCode,
      );
      await _plugin.zonedSchedule(
        id: entry.notificationId,
        title: presentation.title,
        body: presentation.body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'parkinsum_logging_reminders',
            'Logging reminders',
            channelDescription:
                'User-authored reminders to log meals or medication intake.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            visibility: presentation.hideFromSecureAndroidLockScreen
                ? NotificationVisibility.secret
                : NotificationVisibility.private,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
          linux: const LinuxNotificationDetails(),
          windows: const WindowsNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: ReminderNotificationResponseCoordinator.payloadForReminder(
          reminder,
        ),
      );
      if (!isCurrent()) return;
    }
  }

  @override
  ReminderScheduleManifestResult preflightSchedule(
    List<UserLoggingReminder> reminders,
  ) => const ReminderScheduleManifestPreflight().evaluate(
    reminders,
    budget: supportsScheduledDelivery
        ? const ReminderScheduleBudget(
            requestLimit: reminderScheduleProductRequestLimit,
          )
        : null,
  );

  @override
  Future<void> cancelScheduledReminders() =>
      cancelScheduledRemindersWithResult().then<void>((_) {});

  @override
  Future<ReminderNotificationMutationResult>
  cancelScheduledRemindersWithResult() {
    final supported = supportsScheduledDelivery;
    return _mutationQueue
        .cancel(
          operation: supported
              ? _performScheduledReminderCancellation
              : () async {},
        )
        .then(
          (result) => supported
              ? result
              : const ReminderNotificationMutationResult(
                  ReminderNotificationMutationStatus.unsupported,
                ),
        )
        .timeout(reminderNativeOperationTimeout);
  }

  Future<void> _performScheduledReminderCancellation() async {
    if (!supportsScheduledDelivery) return;
    await _initialize();
    await _cancelPendingLoggingReminders();
  }

  Future<void> _cancelPendingLoggingReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if ((request.payload ?? '').startsWith('parkinsum-reminder:')) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  @override
  Future<int> pendingReminderCount() =>
      _readPendingReminderCount().timeout(reminderNativeOperationTimeout);

  Future<int> _readPendingReminderCount() async {
    if (!supportsScheduledDelivery) return 0;
    await _initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .where(
          (request) =>
              (request.payload ?? '').startsWith('parkinsum-reminder:'),
        )
        .length;
  }

  @override
  Future<ReminderPendingIdentityAttestation> attestPendingSchedule(
    List<UserLoggingReminder> reminders,
  ) =>
      _attestPendingSchedule(reminders).timeout(reminderNativeOperationTimeout);

  Future<ReminderPendingIdentityAttestation> _attestPendingSchedule(
    List<UserLoggingReminder> reminders,
  ) async {
    if (!supportsScheduledDelivery) {
      return const ReminderPendingIdentityAttestation.unsupported();
    }
    final preflight = preflightSchedule(reminders);
    final manifest = preflight.manifest;
    if (!preflight.accepted || manifest == null) {
      return ReminderPendingIdentityAttestation.uninspectable(
        plannedCount: preflight.projected,
      );
    }
    final remindersById = <String, UserLoggingReminder>{
      for (final reminder in reminders) reminder.id: reminder,
    };
    final planned = <ReminderPendingRequestIdentity>[];
    try {
      for (final entry in manifest.entries) {
        final reminder = remindersById[entry.reminderId];
        if (reminder == null) {
          return ReminderPendingIdentityAttestation.uninspectable(
            plannedCount: manifest.entries.length,
          );
        }
        planned.add(
          ReminderPendingRequestIdentity.fromPayload(
            notificationId: entry.notificationId,
            payload: ReminderNotificationResponseCoordinator.payloadForReminder(
              reminder,
            ),
          ),
        );
      }
    } catch (_) {
      return ReminderPendingIdentityAttestation.uninspectable(
        plannedCount: manifest.entries.length,
      );
    }

    await _initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return const ReminderPendingIdentityAttestor().evaluatePluginRegistry(
      planned: planned,
      pending: [
        for (final request in pending)
          ReminderPendingRequestSnapshot(
            notificationId: request.id,
            payload: request.payload,
          ),
      ],
    );
  }

  tz.TZDateTime _nextWeekday(UserLoggingReminder reminder, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.hour,
      reminder.minute,
    );
    while (candidate.weekday != weekday || !candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}

class ReminderSchedulePreflightException implements Exception {
  const ReminderSchedulePreflightException(this.result);

  final ReminderScheduleManifestResult result;

  @override
  String toString() =>
      'ReminderSchedulePreflightException(${result.failure?.kind.name})';
}

enum ReminderScheduleSystemState {
  unverified,
  verified,
  unsupported,
  recoveryRequired,
}

class UserLoggingReminderController extends ChangeNotifier {
  UserLoggingReminderController({
    required this.userScope,
    UserLoggingReminderRepository? repository,
    ReminderNotificationGateway? gateway,
  }) : _repository = repository ?? UserLoggingReminderRepository(),
       _gateway = gateway ?? LocalReminderNotificationGateway.shared,
       _persistenceCoordinator =
           _ReminderPersistenceMutationCoordinator.shared {
    if (!_gateway.supportsScheduledDelivery) {
      _scheduleSystemState = ReminderScheduleSystemState.unsupported;
    }
  }

  final String userScope;
  final UserLoggingReminderRepository _repository;
  final ReminderNotificationGateway _gateway;
  final _ReminderPersistenceMutationCoordinator _persistenceCoordinator;
  List<UserLoggingReminder> _reminders = const [];
  bool _busy = false;
  String? _error;
  DateTime? _lastSynchronizedAt;
  ReminderScheduleManifestResult? _scheduleManifest;
  ReminderNotificationMutationResult? _lastMutationResult;
  ReminderNotificationMutationResult? _lastRollbackResult;
  ReminderPersistenceMutationResult? _lastPersistenceMutationResult;
  ReminderPersistenceMutationResult? _lastPersistenceRollbackResult;
  ReminderPendingIdentityAttestation? _pendingIdentityAttestation;
  ReminderScheduleSystemState _scheduleSystemState =
      ReminderScheduleSystemState.unverified;

  List<UserLoggingReminder> get reminders => List.unmodifiable(_reminders);
  bool get busy => _busy;
  String? get error => _error;
  DateTime? get lastSynchronizedAt => _lastSynchronizedAt;
  ReminderScheduleManifestResult? get scheduleManifest => _scheduleManifest;
  ReminderNotificationMutationResult? get lastMutationResult =>
      _lastMutationResult;
  ReminderNotificationMutationResult? get lastRollbackResult =>
      _lastRollbackResult;
  ReminderPersistenceMutationResult? get lastPersistenceMutationResult =>
      _lastPersistenceMutationResult;
  ReminderPersistenceMutationResult? get lastPersistenceRollbackResult =>
      _lastPersistenceRollbackResult;
  ReminderPendingIdentityAttestation? get pendingIdentityAttestation =>
      _pendingIdentityAttestation;
  ReminderScheduleSystemState get scheduleSystemState => _scheduleSystemState;
  bool get recoveryRequired =>
      _scheduleSystemState == ReminderScheduleSystemState.recoveryRequired;
  bool get systemStateUnverified =>
      _scheduleSystemState == ReminderScheduleSystemState.unverified ||
      recoveryRequired;
  bool get supportsScheduledDelivery => _gateway.supportsScheduledDelivery;

  Future<void> load() async {
    _busy = true;
    _lastMutationResult = null;
    _lastRollbackResult = null;
    _lastPersistenceMutationResult = null;
    _lastPersistenceRollbackResult = null;
    _pendingIdentityAttestation = null;
    final lease = _beginMutationLease();
    notifyListeners();
    try {
      final loaded = await _repository.load(userScope);
      final normalized = loaded
          .map(
            (reminder) =>
                isReminderActivationTokenValid(reminder.activationToken)
                ? reminder
                : reminder.copyWith(
                    activationToken: newReminderActivationToken(),
                  ),
          )
          .toList(growable: false);
      _reminders = List.unmodifiable(normalized);
      if (!_refreshScheduleManifest(_reminders)) {
        _error = 'schedule_invalid';
        return;
      }
      if (loaded.asMap().entries.any(
        (entry) =>
            entry.value.activationToken !=
            normalized[entry.key].activationToken,
      )) {
        await _repository.save(userScope, _reminders);
      }
      _error = null;
      if (_gateway.supportsScheduledDelivery) {
        try {
          final result = await _synchronize(_reminders, lease: lease);
          _recordPrimaryResult(result);
          if (result.wasApplied && _isLeaseCurrent(lease)) {
            _lastSynchronizedAt = DateTime.now();
            final matched = await _attestSchedule(_reminders, lease: lease);
            if (!_isLeaseCurrent(lease)) {
              _markSystemUnverified();
              _error = 'schedule_failed';
            } else if (!matched) {
              _error = 'schedule_identity_unverified';
            }
          } else {
            _markSystemUnverified();
            _error = 'schedule_failed';
          }
        } catch (_) {
          _markSystemUnverified();
          _error = 'schedule_failed';
        }
      }
    } catch (_) {
      _error = 'load_failed';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> save(UserLoggingReminder reminder) async {
    final securedReminder = reminder.copyWith(
      activationToken: newReminderActivationToken(),
    );
    final next = [
      securedReminder,
      ..._reminders.where((item) => item.id != securedReminder.id),
    ];
    return _commit(next, requestPermission: securedReminder.enabled);
  }

  Future<bool> toggle(UserLoggingReminder reminder, bool enabled) => _commit(
    _reminders
        .map(
          (item) => item.id == reminder.id
              ? item.copyWith(
                  enabled: enabled,
                  activationToken: newReminderActivationToken(),
                )
              : item,
        )
        .toList(),
    requestPermission: enabled,
  );

  Future<bool> remove(String id) =>
      _commit(_reminders.where((item) => item.id != id).toList());

  /// Reconciles the persisted local-time patterns with the operating-system
  /// scheduler. Called after load and when the app resumes so timezone,
  /// reboot, and externally-cancelled pending requests can recover without
  /// changing the user's authored plan.
  Future<bool> resynchronize() async {
    if (_busy || !_gateway.supportsScheduledDelivery) return false;
    _busy = true;
    _error = null;
    _lastMutationResult = null;
    _lastRollbackResult = null;
    _lastPersistenceMutationResult = null;
    _lastPersistenceRollbackResult = null;
    _pendingIdentityAttestation = null;
    final lease = _beginMutationLease();
    notifyListeners();
    try {
      if (!_refreshScheduleManifest(_reminders)) {
        _error = 'schedule_invalid';
        return false;
      }
      final result = await _synchronize(_reminders, lease: lease);
      _recordPrimaryResult(result);
      if (!result.wasApplied || !_isLeaseCurrent(lease)) {
        _markSystemUnverified();
        _error = 'schedule_failed';
        return false;
      }
      _lastSynchronizedAt = DateTime.now();
      final matched = await _attestSchedule(_reminders, lease: lease);
      if (!_isLeaseCurrent(lease)) {
        _markSystemUnverified();
        _error = 'schedule_failed';
        return false;
      }
      if (!matched) {
        _error = 'schedule_identity_unverified';
        return false;
      }
      return true;
    } catch (_) {
      _markSystemUnverified();
      _error = 'schedule_failed';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _commit(
    List<UserLoggingReminder> next, {
    bool requestPermission = false,
  }) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    _lastMutationResult = null;
    _lastRollbackResult = null;
    _lastPersistenceMutationResult = null;
    _lastPersistenceRollbackResult = null;
    _pendingIdentityAttestation = null;
    notifyListeners();
    try {
      if (!_refreshScheduleManifest(next)) {
        _error = 'schedule_invalid';
        return false;
      }
      if (requestPermission && _gateway.supportsScheduledDelivery) {
        final granted = await _gateway.requestPermission();
        if (!granted) {
          _refreshScheduleManifest(_reminders);
          _error = 'permission_denied';
          return false;
        }
      }
      // Acquire both capabilities without an await between them so every
      // controller observes the same latest-mutation order in native and
      // durable state.
      final notificationLease = _beginMutationLease();
      final persistenceLease = _persistenceCoordinator.beginLease(
        userScope: userScope,
      );
      final previous = _reminders;
      if (_gateway.supportsScheduledDelivery) {
        try {
          final result = await _synchronize(next, lease: notificationLease);
          _recordPrimaryResult(result);
          if (!result.wasApplied ||
              !_isLeaseCurrent(notificationLease) ||
              !_persistenceCoordinator.isCurrent(persistenceLease)) {
            _markSystemUnverified();
            _refreshScheduleManifest(previous);
            _error = 'schedule_failed';
            return false;
          }
        } catch (_) {
          await _rollbackSchedule(previous, lease: notificationLease);
          _refreshScheduleManifest(previous);
          _error = recoveryRequired ? 'recovery_required' : 'schedule_failed';
          return false;
        }
      }
      if (!_isLeaseCurrent(notificationLease) ||
          !_persistenceCoordinator.isCurrent(persistenceLease)) {
        if (!_persistenceCoordinator.isCurrent(persistenceLease)) {
          _lastPersistenceMutationResult =
              const ReminderPersistenceMutationResult(
                ReminderPersistenceMutationStatus.superseded,
              );
        }
        _markSystemUnverified();
        _refreshScheduleManifest(previous);
        _error = 'schedule_failed';
        return false;
      }
      try {
        final result = await _persistWithLease(next, lease: persistenceLease);
        _lastPersistenceMutationResult = result;
        if (!result.wasApplied) {
          _markSystemUnverified();
          _refreshScheduleManifest(previous);
          _error = 'schedule_failed';
          return false;
        }
      } catch (_) {
        if (!_persistenceCoordinator.isCurrent(persistenceLease)) {
          _lastPersistenceMutationResult =
              const ReminderPersistenceMutationResult(
                ReminderPersistenceMutationStatus.superseded,
              );
        }
        await _rollbackSchedule(previous, lease: notificationLease);
        _refreshScheduleManifest(previous);
        _error = recoveryRequired ? 'recovery_required' : 'save_failed';
        return false;
      }
      if (!_persistenceCoordinator.isCurrent(persistenceLease)) {
        _lastPersistenceMutationResult =
            const ReminderPersistenceMutationResult(
              ReminderPersistenceMutationStatus.superseded,
            );
        _markSystemUnverified();
        _refreshScheduleManifest(previous);
        _error = 'schedule_failed';
        return false;
      }
      if (!_isLeaseCurrent(notificationLease)) {
        try {
          final rollbackResult = await _persistWithLease(
            previous,
            lease: persistenceLease,
          );
          _lastPersistenceRollbackResult = rollbackResult;
          if (!rollbackResult.wasApplied) {
            _markSystemUnverified();
            _refreshScheduleManifest(previous);
            _error = 'schedule_failed';
            return false;
          }
        } catch (_) {
          if (_persistenceCoordinator.isCurrent(persistenceLease)) {
            _scheduleSystemState = ReminderScheduleSystemState.recoveryRequired;
          } else {
            _lastPersistenceRollbackResult =
                const ReminderPersistenceMutationResult(
                  ReminderPersistenceMutationStatus.superseded,
                );
            _markSystemUnverified();
          }
          _refreshScheduleManifest(previous);
          _error = recoveryRequired ? 'recovery_required' : 'schedule_failed';
          return false;
        }
        _markSystemUnverified();
        _refreshScheduleManifest(previous);
        _error = 'schedule_failed';
        return false;
      }
      if (_gateway.supportsScheduledDelivery) {
        _lastSynchronizedAt = DateTime.now();
        final matched = await _attestSchedule(next, lease: notificationLease);
        if (!_isLeaseCurrent(notificationLease) ||
            !_persistenceCoordinator.isCurrent(persistenceLease)) {
          _markSystemUnverified();
          _refreshScheduleManifest(previous);
          _error = 'schedule_failed';
          return false;
        }
        if (!matched) {
          _error = 'schedule_identity_unverified';
        }
      }
      _reminders = List.unmodifiable(next);
      return true;
    } catch (_) {
      _refreshScheduleManifest(_reminders);
      _error = 'save_failed';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  bool _refreshScheduleManifest(List<UserLoggingReminder> reminders) {
    if (!_gateway.supportsScheduledDelivery) {
      _scheduleManifest = null;
      return _isLocallyValidPlan(reminders);
    }
    final gateway = _gateway;
    if (gateway is! ReminderNotificationPreflight) {
      _scheduleManifest = null;
      return true;
    }
    final result = (gateway as ReminderNotificationPreflight).preflightSchedule(
      reminders,
    );
    _scheduleManifest = result;
    return result.accepted;
  }

  bool _isLocallyValidPlan(List<UserLoggingReminder> reminders) {
    final ids = <String>{};
    try {
      for (final reminder in reminders) {
        if (!ids.add(reminder.id)) return false;
        final decoded = UserLoggingReminder.fromJson(reminder.toJson());
        if (jsonEncode(decoded.toJson()) != jsonEncode(reminder.toJson())) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  ReminderNotificationMutationLease? _beginMutationLease() {
    final gateway = _gateway;
    if (!gateway.supportsScheduledDelivery ||
        gateway is! ReminderNotificationLeaseGateway) {
      return null;
    }
    return (gateway as ReminderNotificationLeaseGateway).beginMutationLease(
      userScope: userScope,
    );
  }

  bool _isLeaseCurrent(ReminderNotificationMutationLease? lease) {
    if (lease == null) return true;
    final gateway = _gateway;
    if (gateway is! ReminderNotificationLeaseGateway) return false;
    return (gateway as ReminderNotificationLeaseGateway).isMutationLeaseCurrent(
      lease,
      userScope: userScope,
    );
  }

  Future<ReminderPersistenceMutationResult> _persistWithLease(
    List<UserLoggingReminder> reminders, {
    required _ReminderPersistenceMutationLease lease,
  }) => _persistenceCoordinator.mutateIfCurrent(
    lease: lease,
    operation: () => _repository.save(userScope, reminders),
  );

  Future<ReminderNotificationMutationResult> _synchronize(
    List<UserLoggingReminder> reminders, {
    required ReminderNotificationMutationLease? lease,
  }) async {
    final gateway = _gateway;
    if (!gateway.supportsScheduledDelivery) {
      return const ReminderNotificationMutationResult(
        ReminderNotificationMutationStatus.unsupported,
      );
    }
    if (gateway is ReminderNotificationLeaseGateway) {
      if (lease == null) {
        throw StateError('A result-bearing gateway requires a mutation lease.');
      }
      return (gateway as ReminderNotificationLeaseGateway).synchronizeWithLease(
        reminders,
        userScope: userScope,
        lease: lease,
      );
    }
    await gateway.synchronize(reminders, userScope: userScope);
    return const ReminderNotificationMutationResult(
      ReminderNotificationMutationStatus.applied,
    );
  }

  Future<bool> _attestSchedule(
    List<UserLoggingReminder> reminders, {
    required ReminderNotificationMutationLease? lease,
  }) async {
    final gateway = _gateway;
    if (!gateway.supportsScheduledDelivery) {
      _pendingIdentityAttestation =
          const ReminderPendingIdentityAttestation.unsupported();
      _scheduleSystemState = ReminderScheduleSystemState.unsupported;
      return true;
    }
    if (gateway is! ReminderNotificationIdentityInspector) {
      // Compatibility boundary for test/custom gateways that can apply a
      // schedule but expose no pending-request inspection API.
      return true;
    }
    if (!_isLeaseCurrent(lease)) {
      _markSystemUnverified();
      return false;
    }
    ReminderPendingIdentityAttestation attestation;
    try {
      attestation = await (gateway as ReminderNotificationIdentityInspector)
          .attestPendingSchedule(reminders);
    } catch (_) {
      attestation = ReminderPendingIdentityAttestation.uninspectable(
        plannedCount: _scheduleManifest?.projected ?? 0,
      );
    }
    if (!_isLeaseCurrent(lease)) {
      _markSystemUnverified();
      return false;
    }
    _pendingIdentityAttestation = attestation;
    switch (attestation.status) {
      case ReminderPendingIdentityAttestationStatus.matched:
        _scheduleSystemState = ReminderScheduleSystemState.verified;
        return true;
      case ReminderPendingIdentityAttestationStatus.unsupported:
        _scheduleSystemState = ReminderScheduleSystemState.unsupported;
        return true;
      case ReminderPendingIdentityAttestationStatus.drift:
      case ReminderPendingIdentityAttestationStatus.uninspectable:
        _markSystemUnverified();
        return false;
    }
  }

  void _recordPrimaryResult(ReminderNotificationMutationResult result) {
    _lastMutationResult = result;
    _recordSystemResult(result);
  }

  void _recordSystemResult(ReminderNotificationMutationResult result) {
    switch (result.status) {
      case ReminderNotificationMutationStatus.applied:
        _scheduleSystemState = ReminderScheduleSystemState.verified;
        return;
      case ReminderNotificationMutationStatus.superseded:
        _markSystemUnverified();
        return;
      case ReminderNotificationMutationStatus.unsupported:
        _scheduleSystemState = ReminderScheduleSystemState.unsupported;
        return;
    }
  }

  void _markSystemUnverified() {
    _lastSynchronizedAt = null;
    if (_scheduleSystemState != ReminderScheduleSystemState.recoveryRequired) {
      _scheduleSystemState = ReminderScheduleSystemState.unverified;
    }
  }

  Future<void> _rollbackSchedule(
    List<UserLoggingReminder> previous, {
    required ReminderNotificationMutationLease? lease,
  }) async {
    if (!_gateway.supportsScheduledDelivery) {
      _scheduleSystemState = ReminderScheduleSystemState.unsupported;
      return;
    }
    try {
      final result = await _synchronize(previous, lease: lease);
      _lastRollbackResult = result;
      _recordSystemResult(result);
    } catch (_) {
      _lastSynchronizedAt = null;
      _scheduleSystemState = ReminderScheduleSystemState.recoveryRequired;
    }
  }
}
