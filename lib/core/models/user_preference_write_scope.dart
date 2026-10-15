import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';

/// Process-local authorization, checked immediately before storage dispatch.
/// A platform write already dispatched cannot be cancelled by this lease.
final class UserPreferenceWriteScope {
  UserPreferenceWriteScope({
    required this.ownerUid,
    required this.sessionEpoch,
    required bool Function() isCurrent,
    this.expectedProfileDigest,
    this.expectedActiveSelectionDigest,
  }) : _isCurrent = isCurrent {
    if (ownerUid.isEmpty || ownerUid.trim() != ownerUid || sessionEpoch < 0) {
      throw ArgumentError(
        'A current preference owner and session are required.',
      );
    }
    for (final digest in [
      expectedProfileDigest,
      expectedActiveSelectionDigest,
    ]) {
      if (digest != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
        throw ArgumentError('Invalid preference source digest.');
      }
    }
  }

  final String ownerUid;
  final int sessionEpoch;
  final String? expectedProfileDigest;
  final String? expectedActiveSelectionDigest;
  final bool Function() _isCurrent;

  bool get isCurrent => _isCurrent();

  void requireCurrent() {
    if (!isCurrent) throw const UserPreferenceWriteScopeChanged();
  }

  void requireProfileOwner(UserProfile profile) {
    requireCurrent();
    if (profile.patientId != ownerUid) {
      throw StateError('Preference profile owner does not match its session.');
    }
  }

  void requireUnchangedProfile(UserProfile current) {
    requireCurrent();
    if (expectedProfileDigest != null &&
        expectedProfileDigest != userPreferenceProfileDigest(current)) {
      throw StateError('preference_profile_snapshot_changed');
    }
  }

  void requireUnchangedActiveSelection(Iterable<String> current) {
    requireCurrent();
    if (expectedActiveSelectionDigest != null &&
        expectedActiveSelectionDigest !=
            userPreferenceSelectionDigest(current)) {
      throw StateError('preference_selection_snapshot_changed');
    }
  }
}

String userPreferenceProfileDigest(UserProfile profile) {
  // AppState binds the actual session owner separately and normalizes legacy
  // local_user to that owner in memory. Do not fabricate persisted ownership
  // merely to compare otherwise identical preferences.
  final value = Map<String, Object?>.from(profile.toJson())
    ..remove('patientId');
  return sha256.convert(utf8.encode(jsonEncode(value))).toString();
}

String userPreferenceSelectionDigest(Iterable<String> ids) {
  final sorted = ids.toSet().toList()..sort();
  return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
}

final class UserPreferenceWriteScopeChanged implements Exception {
  const UserPreferenceWriteScopeChanged();

  @override
  String toString() => 'User preference session changed before write dispatch.';
}

/// Optional capability: production stores recheck after their own waits.
abstract interface class ScopedUserPreferenceStore {
  Future<void> saveUserProfileForSession(
    UserProfile profile, {
    required UserPreferenceWriteScope scope,
  });

  Future<void> saveActiveDrugIdsForSession(
    List<String> ids, {
    required UserPreferenceWriteScope scope,
  });
}
