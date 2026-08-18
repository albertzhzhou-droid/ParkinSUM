import 'dart:convert';

import 'package:crypto/crypto.dart';

/// What the notification plugin's pending-request registry says about the
/// schedule ParkinSUM most recently asked it to install.
///
/// `matched` is intentionally narrower than "operating-system verified": the
/// plugin registry is not an independent AlarmManager/UserNotifications probe
/// and it does not prove visible delivery.
enum ReminderPendingIdentityAttestationStatus {
  matched,
  drift,
  uninspectable,
  unsupported,
}

/// Privacy-bounded identity for one pending notification request.
///
/// The raw payload can contain an activation capability and is therefore
/// never retained. Only its SHA-256 digest is compared or exposed.
class ReminderPendingRequestIdentity {
  const ReminderPendingRequestIdentity({
    required this.notificationId,
    required this.payloadDigest,
  });

  factory ReminderPendingRequestIdentity.fromPayload({
    required int notificationId,
    required String payload,
  }) => ReminderPendingRequestIdentity(
    notificationId: notificationId,
    payloadDigest: sha256.convert(utf8.encode(payload)).toString(),
  );

  final int notificationId;
  final String payloadDigest;
}

/// Minimal adapter-neutral view of a plugin pending request.
class ReminderPendingRequestSnapshot {
  const ReminderPendingRequestSnapshot({
    required this.notificationId,
    required this.payload,
  });

  final int notificationId;
  final String? payload;
}

/// Count-only attestation result safe to render in diagnostics.
///
/// Request ids, payloads, reminder labels, account identifiers, and activation
/// capabilities are deliberately absent.
class ReminderPendingIdentityAttestation {
  const ReminderPendingIdentityAttestation({
    required this.status,
    required this.plannedCount,
    required this.installedCount,
    required this.missingCount,
    required this.extraCount,
    required this.replacedCount,
  });

  const ReminderPendingIdentityAttestation.unsupported()
    : status = ReminderPendingIdentityAttestationStatus.unsupported,
      plannedCount = 0,
      installedCount = 0,
      missingCount = 0,
      extraCount = 0,
      replacedCount = 0;

  const ReminderPendingIdentityAttestation.uninspectable({
    this.plannedCount = 0,
    this.installedCount = 0,
  }) : status = ReminderPendingIdentityAttestationStatus.uninspectable,
       missingCount = 0,
       extraCount = 0,
       replacedCount = 0;

  final ReminderPendingIdentityAttestationStatus status;
  final int plannedCount;
  final int installedCount;
  final int missingCount;
  final int extraCount;
  final int replacedCount;

  bool get matched =>
      status == ReminderPendingIdentityAttestationStatus.matched;
}

/// Compares the complete planned and plugin-reported identity sets.
///
/// Count equality is insufficient: a stale request can replace a planned one
/// under the same integer id. This comparison therefore keys by notification
/// id and also compares a digest of the privacy-sensitive payload.
class ReminderPendingIdentityAttestor {
  const ReminderPendingIdentityAttestor();

  static final RegExp _digestPattern = RegExp(r'^[a-f0-9]{64}$');

  /// Filters a complete plugin registry without accidentally treating other
  /// app notification categories as ParkinSUM reminder drift.
  ///
  /// A request with a planned integer id is always retained, even when its
  /// payload is null or has another prefix, because that is precisely the
  /// replacement/collision case the attestation must surface.
  ReminderPendingIdentityAttestation evaluatePluginRegistry({
    required Iterable<ReminderPendingRequestIdentity> planned,
    required Iterable<ReminderPendingRequestSnapshot> pending,
    String ownedPayloadPrefix = 'parkinsum-reminder:',
  }) {
    if (ownedPayloadPrefix.isEmpty) {
      return const ReminderPendingIdentityAttestation.uninspectable();
    }
    final plannedList = planned.toList(growable: false);
    final plannedIds = plannedList
        .map((identity) => identity.notificationId)
        .toSet();
    final installed = <ReminderPendingRequestIdentity>[];
    for (final request in pending) {
      final payload = request.payload ?? '';
      if (!plannedIds.contains(request.notificationId) &&
          !payload.startsWith(ownedPayloadPrefix)) {
        continue;
      }
      installed.add(
        ReminderPendingRequestIdentity.fromPayload(
          notificationId: request.notificationId,
          payload: payload,
        ),
      );
    }
    return evaluate(planned: plannedList, installed: installed);
  }

  ReminderPendingIdentityAttestation evaluate({
    required Iterable<ReminderPendingRequestIdentity> planned,
    required Iterable<ReminderPendingRequestIdentity> installed,
  }) {
    final plannedList = planned.toList(growable: false);
    final installedList = installed.toList(growable: false);
    final plannedById = _index(plannedList);
    final installedById = _index(installedList);
    if (plannedById == null || installedById == null) {
      return ReminderPendingIdentityAttestation.uninspectable(
        plannedCount: plannedList.length,
        installedCount: installedList.length,
      );
    }

    var missing = 0;
    var replaced = 0;
    for (final entry in plannedById.entries) {
      final installedDigest = installedById[entry.key];
      if (installedDigest == null) {
        missing += 1;
      } else if (installedDigest != entry.value) {
        replaced += 1;
      }
    }
    final extra = installedById.keys
        .where((id) => !plannedById.containsKey(id))
        .length;
    final exact = missing == 0 && extra == 0 && replaced == 0;
    return ReminderPendingIdentityAttestation(
      status: exact
          ? ReminderPendingIdentityAttestationStatus.matched
          : ReminderPendingIdentityAttestationStatus.drift,
      plannedCount: plannedById.length,
      installedCount: installedById.length,
      missingCount: missing,
      extraCount: extra,
      replacedCount: replaced,
    );
  }

  Map<int, String>? _index(List<ReminderPendingRequestIdentity> identities) {
    final indexed = <int, String>{};
    for (final identity in identities) {
      if (identity.notificationId < 0 ||
          identity.notificationId > 0x7fffffff ||
          !_digestPattern.hasMatch(identity.payloadDigest) ||
          indexed.containsKey(identity.notificationId)) {
        return null;
      }
      indexed[identity.notificationId] = identity.payloadDigest;
    }
    return indexed;
  }
}
