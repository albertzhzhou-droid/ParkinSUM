import 'dart:async';
import 'dart:convert';
import 'dart:math';

const int reminderActivationInboxSchemaVersion = 1;
const int reminderActivationPayloadMaxLength = 256;
const Duration reminderActivationRetention = Duration(hours: 24);
const Duration reminderActivationDedupeWindow = Duration(seconds: 5);
const int reminderActivationInboxMaxEntries = 32;

enum ReminderNotificationResponseOrigin { foreground, coldStart }

class ReminderNotificationResponseEvent {
  const ReminderNotificationResponseEvent({
    required this.payload,
    required this.origin,
  });

  final String? payload;
  final ReminderNotificationResponseOrigin origin;
}

enum ReminderActivationDisposition { pending, claimed, discarded }

String newReminderOpaqueToken() {
  final random = Random.secure();
  return List<String>.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    growable: false,
  ).join();
}

bool isReminderOpaqueTokenValid(String value) =>
    RegExp(r'^[a-f0-9]{32}$').hasMatch(value);

class ReminderNotificationActivation {
  const ReminderNotificationActivation({
    required this.id,
    required this.payload,
    required this.origin,
    required this.receivedAtUtc,
    required this.expiresAtUtc,
    this.disposition = ReminderActivationDisposition.pending,
    this.settledAtUtc,
  });

  final String id;
  final String? payload;
  final ReminderNotificationResponseOrigin origin;
  final DateTime receivedAtUtc;
  final DateTime expiresAtUtc;
  final ReminderActivationDisposition disposition;
  final DateTime? settledAtUtc;

  bool get isPending => disposition == ReminderActivationDisposition.pending;

  ReminderNotificationActivation settle({
    required ReminderActivationDisposition disposition,
    required DateTime atUtc,
  }) => ReminderNotificationActivation(
    id: id,
    payload: payload,
    origin: origin,
    receivedAtUtc: receivedAtUtc,
    expiresAtUtc: expiresAtUtc,
    disposition: disposition,
    settledAtUtc: atUtc.toUtc(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': reminderActivationInboxSchemaVersion,
    'id': id,
    'payload': payload,
    'origin': origin.name,
    'receivedAtUtc': receivedAtUtc.toUtc().toIso8601String(),
    'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
    'disposition': disposition.name,
    'settledAtUtc': settledAtUtc?.toUtc().toIso8601String(),
  };

  factory ReminderNotificationActivation.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != reminderActivationInboxSchemaVersion) {
      throw const FormatException('Activation schema is unsupported.');
    }
    final id = json['id'];
    final payload = json['payload'];
    final originName = json['origin'];
    final receivedRaw = json['receivedAtUtc'];
    final expiresRaw = json['expiresAtUtc'];
    final dispositionName = json['disposition'];
    final settledRaw = json['settledAtUtc'];
    if (id is! String || !isReminderOpaqueTokenValid(id)) {
      throw const FormatException('Activation id is invalid.');
    }
    if (payload != null &&
        (payload is! String ||
            utf8.encode(payload).length > reminderActivationPayloadMaxLength)) {
      throw const FormatException('Activation payload is invalid.');
    }
    final origin = ReminderNotificationResponseOrigin.values
        .where((candidate) => candidate.name == originName)
        .firstOrNull;
    final disposition = ReminderActivationDisposition.values
        .where((candidate) => candidate.name == dispositionName)
        .firstOrNull;
    final received = receivedRaw is String
        ? DateTime.tryParse(receivedRaw)?.toUtc()
        : null;
    final expires = expiresRaw is String
        ? DateTime.tryParse(expiresRaw)?.toUtc()
        : null;
    final settled = settledRaw is String
        ? DateTime.tryParse(settledRaw)?.toUtc()
        : null;
    if (origin == null ||
        disposition == null ||
        received == null ||
        expires == null ||
        !expires.isAfter(received) ||
        (disposition == ReminderActivationDisposition.pending) !=
            (settled == null)) {
      throw const FormatException('Activation record is invalid.');
    }
    return ReminderNotificationActivation(
      id: id,
      payload: payload as String?,
      origin: origin,
      receivedAtUtc: received,
      expiresAtUtc: expires,
      disposition: disposition,
      settledAtUtc: settled,
    );
  }
}

enum ReminderActivationClaimStatus {
  claimed,
  replayed,
  discarded,
  expired,
  missing,
}

class ReminderActivationClaim {
  const ReminderActivationClaim(this.status, [this.activation]);

  final ReminderActivationClaimStatus status;
  final ReminderNotificationActivation? activation;
}

/// Storage backends must run [operation] while holding one exclusive lock and
/// persist the mutated list before completing. The callback is synchronous so
/// no native/plugin work can escape the critical section.
abstract class ReminderActivationRecordStore {
  Future<T> transaction<T>(
    T Function(List<ReminderNotificationActivation> entries) operation,
  );
}

class InMemoryReminderActivationRecordStore
    implements ReminderActivationRecordStore {
  InMemoryReminderActivationRecordStore({
    List<ReminderNotificationActivation> seed = const [],
  }) : _entries = List<ReminderNotificationActivation>.of(seed);

  List<ReminderNotificationActivation> _entries;
  Future<void> _tail = Future<void>.value();

  List<ReminderNotificationActivation> get snapshot =>
      List<ReminderNotificationActivation>.unmodifiable(_entries);

  @override
  Future<T> transaction<T>(
    T Function(List<ReminderNotificationActivation> entries) operation,
  ) {
    final queued = _tail.then((_) {
      final working = List<ReminderNotificationActivation>.of(_entries);
      final result = operation(working);
      _entries = List<ReminderNotificationActivation>.unmodifiable(working);
      return result;
    });
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}

class ReminderNotificationActivationInbox {
  ReminderNotificationActivationInbox({
    required ReminderActivationRecordStore store,
    DateTime Function()? now,
    String Function()? newId,
    this.retention = reminderActivationRetention,
    this.dedupeWindow = reminderActivationDedupeWindow,
    this.maxEntries = reminderActivationInboxMaxEntries,
  }) : _store = store,
       _now = now ?? DateTime.now,
       _newId = newId ?? newReminderOpaqueToken {
    if (retention <= Duration.zero ||
        dedupeWindow < Duration.zero ||
        maxEntries <= 0) {
      throw ArgumentError('Activation inbox limits must be positive.');
    }
  }

  final ReminderActivationRecordStore _store;
  final DateTime Function() _now;
  final String Function() _newId;
  final Duration retention;
  final Duration dedupeWindow;
  final int maxEntries;

  Future<ReminderNotificationActivation> capture(
    ReminderNotificationResponseEvent event,
  ) async {
    final payload = event.payload;
    if (payload != null &&
        utf8.encode(payload).length > reminderActivationPayloadMaxLength) {
      throw const FormatException('Activation payload exceeds the limit.');
    }
    final now = _now().toUtc();
    return await _store.transaction((entries) {
      _prune(entries, now);
      entries.sort((a, b) => a.receivedAtUtc.compareTo(b.receivedAtUtc));
      for (final existing in entries.reversed) {
        if (existing.payload == payload &&
            now.difference(existing.receivedAtUtc).inMilliseconds.abs() <=
                dedupeWindow.inMilliseconds) {
          return existing;
        }
      }
      String? id;
      for (var attempt = 0; attempt < 8; attempt += 1) {
        final candidate = _newId();
        if (!isReminderOpaqueTokenValid(candidate)) {
          throw StateError('Activation id factory returned an invalid token.');
        }
        if (!entries.any((entry) => entry.id == candidate)) {
          id = candidate;
          break;
        }
      }
      if (id == null) {
        throw StateError(
          'Activation id factory could not produce a unique id.',
        );
      }
      final activation = ReminderNotificationActivation(
        id: id,
        payload: payload,
        origin: event.origin,
        receivedAtUtc: now,
        expiresAtUtc: now.add(retention),
      );
      _makeRoomForPendingEntry(entries);
      entries.add(activation);
      _enforceCapacity(entries);
      return activation;
    });
  }

  Future<List<ReminderNotificationActivation>> pending({int limit = 8}) {
    if (limit <= 0 || limit > maxEntries) {
      throw RangeError.range(limit, 1, maxEntries, 'limit');
    }
    final now = _now().toUtc();
    return _store.transaction((entries) {
      _prune(entries, now);
      final pending = entries.where((entry) => entry.isPending).toList()
        ..sort((a, b) => a.receivedAtUtc.compareTo(b.receivedAtUtc));
      return List<ReminderNotificationActivation>.unmodifiable(
        pending.take(limit),
      );
    });
  }

  Future<ReminderActivationClaim> claim(String activationId) {
    final now = _now().toUtc();
    return _store.transaction((entries) {
      final index = entries.indexWhere((entry) => entry.id == activationId);
      if (index < 0) {
        _prune(entries, now);
        return const ReminderActivationClaim(
          ReminderActivationClaimStatus.missing,
        );
      }
      final existing = entries[index];
      if (!existing.expiresAtUtc.isAfter(now)) {
        entries.removeAt(index);
        _prune(entries, now);
        return ReminderActivationClaim(
          ReminderActivationClaimStatus.expired,
          existing,
        );
      }
      if (!existing.isPending) {
        return ReminderActivationClaim(
          existing.disposition == ReminderActivationDisposition.claimed
              ? ReminderActivationClaimStatus.replayed
              : ReminderActivationClaimStatus.discarded,
          existing,
        );
      }
      final claimed = existing.settle(
        disposition: ReminderActivationDisposition.claimed,
        atUtc: now,
      );
      entries[index] = claimed;
      _prune(entries, now);
      return ReminderActivationClaim(
        ReminderActivationClaimStatus.claimed,
        claimed,
      );
    });
  }

  Future<void> discard(String activationId) {
    final now = _now().toUtc();
    return _store.transaction((entries) {
      final index = entries.indexWhere((entry) => entry.id == activationId);
      if (index >= 0 && entries[index].isPending) {
        entries[index] = entries[index].settle(
          disposition: ReminderActivationDisposition.discarded,
          atUtc: now,
        );
      }
      _prune(entries, now);
    });
  }

  Future<void> discardPending() {
    final now = _now().toUtc();
    return _store.transaction((entries) {
      for (var index = 0; index < entries.length; index += 1) {
        if (entries[index].isPending) {
          entries[index] = entries[index].settle(
            disposition: ReminderActivationDisposition.discarded,
            atUtc: now,
          );
        }
      }
      _prune(entries, now);
    });
  }

  void _prune(List<ReminderNotificationActivation> entries, DateTime now) {
    entries.removeWhere((entry) => !entry.expiresAtUtc.isAfter(now));
    _enforceCapacity(entries);
  }

  void _enforceCapacity(List<ReminderNotificationActivation> entries) {
    entries.sort((a, b) => a.receivedAtUtc.compareTo(b.receivedAtUtc));
    while (entries.length > maxEntries) {
      final settledIndex = entries.indexWhere((entry) => !entry.isPending);
      if (settledIndex < 0) {
        throw StateError('Activation inbox has no capacity for a new event.');
      }
      entries.removeAt(settledIndex);
    }
  }

  void _makeRoomForPendingEntry(List<ReminderNotificationActivation> entries) {
    while (entries.length >= maxEntries) {
      final settledIndex = entries.indexWhere((entry) => !entry.isPending);
      if (settledIndex < 0) {
        throw StateError('Activation inbox has no capacity for a new event.');
      }
      entries.removeAt(settledIndex);
    }
  }
}
