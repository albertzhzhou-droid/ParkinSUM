import 'dart:convert';

import '../../domain/entities/care_medication_discussion_entry.dart';
import '../../domain/entities/care_medication_discussion_outcome.dart';
import '../../domain/entities/care_medication_list_review.dart';
import '../../domain/entities/decision_support_followup.dart';
import '../../domain/entities/personal_observation.dart';
import 'care_workspace_store.dart';

const careWorkspaceSchemaVersion = 5;
const _legacyCareWorkspaceV1 = 1;
const _legacyCareWorkspaceV2 = 2;
const _legacyCareWorkspaceV3 = 3;
const _legacyCareWorkspaceV4 = 4;
const careWorkspaceMaxBytes = careWorkspaceDocumentMaxBytes;

final class CareDiscussionNote {
  CareDiscussionNote({
    required this.id,
    required this.text,
    required DateTime recordedAt,
    required this.recorderId,
  }) : recordedAt = recordedAt.toUtc() {
    if (!_boundedText(id, 200) ||
        !_boundedText(text, 2000) ||
        !_boundedText(recorderId, 512) ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(id) ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(recorderId) ||
        this.recordedAt.year < 1 ||
        this.recordedAt.year > 9999) {
      throw const FormatException('Invalid discussion note');
    }
  }

  final String id;
  final String text;
  final DateTime recordedAt;
  final String recorderId;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'recorderId': recorderId,
  };

  factory CareDiscussionNote.fromJson(Map<String, dynamic> json) {
    _requireFields(json, const {'id', 'text', 'recordedAt', 'recorderId'});
    return CareDiscussionNote(
      id: _requiredString(json, 'id'),
      text: _requiredString(json, 'text'),
      recordedAt: PersonalObservation.parseExplicitTimestamp(
        _requiredString(json, 'recordedAt'),
      ),
      recorderId: _requiredString(json, 'recorderId'),
    );
  }
}

final class CareWorkspaceSnapshot {
  CareWorkspaceSnapshot({
    required this.ownerScope,
    required this.followups,
    Iterable<PersonalObservation> observations = const [],
    Iterable<CareDiscussionNote> notes = const [],
    Iterable<CareMedicationDiscussionEntry> medicationDiscussionEntries =
        const [],
    Iterable<CareMedicationDiscussionOutcome> medicationDiscussionOutcomes =
        const [],
    Iterable<CareMedicationListReview> medicationListReviews = const [],
  }) : observations = List.unmodifiable(observations),
       notes = List.unmodifiable(notes),
       medicationDiscussionEntries = List.unmodifiable(
         medicationDiscussionEntries,
       ),
       medicationDiscussionOutcomes = List.unmodifiable(
         medicationDiscussionOutcomes,
       ),
       medicationListReviews = List.unmodifiable(medicationListReviews) {
    if (!_boundedText(ownerScope, 512) ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(ownerScope) ||
        this.observations.length > 5000 ||
        this.notes.length > 200 ||
        this.medicationDiscussionEntries.length > 128 ||
        this.medicationDiscussionOutcomes.length > 512 ||
        this.medicationListReviews.length >
            CareMedicationListReviewSection.values.length) {
      throw const FormatException('Care workspace limits exceeded');
    }
    if (this.observations.map((o) => o.id).toSet().length !=
            this.observations.length ||
        this.notes.map((n) => n.id).toSet().length != this.notes.length ||
        this.medicationDiscussionEntries.map((n) => n.id).toSet().length !=
            this.medicationDiscussionEntries.length ||
        this.medicationDiscussionOutcomes.map((n) => n.id).toSet().length !=
            this.medicationDiscussionOutcomes.length ||
        this.medicationListReviews.map((r) => r.section).toSet().length !=
            this.medicationListReviews.length) {
      throw const FormatException(
        'Duplicate care record identity or review section',
      );
    }
    final medicationEntryIds = this.medicationDiscussionEntries
        .map((entry) => entry.id)
        .toSet();
    if (this.observations.any((o) => o.recorderId != ownerScope) ||
        this.notes.any((n) => n.recorderId != ownerScope) ||
        this.medicationDiscussionEntries.any(
          (entry) => entry.recorderId != ownerScope,
        ) ||
        this.medicationDiscussionOutcomes.any(
          (outcome) =>
              outcome.recorderId != ownerScope ||
              !medicationEntryIds.contains(outcome.entryId),
        ) ||
        this.medicationListReviews.any(
          (review) => review.recorderId != ownerScope,
        ) ||
        followups.feedback.any((event) => event.actorId != ownerScope)) {
      throw const FormatException(
        'Care records must belong to the workspace owner',
      );
    }
    // The ledger parser also checks every stored owner binding.
    DecisionSupportFollowupLedger.fromJson(
      followups.toJson(),
      ownerScope: ownerScope,
    );
  }

  final String ownerScope;
  final DecisionSupportFollowupLedger followups;
  final List<PersonalObservation> observations;
  final List<CareDiscussionNote> notes;
  final List<CareMedicationDiscussionEntry> medicationDiscussionEntries;
  final List<CareMedicationDiscussionOutcome> medicationDiscussionOutcomes;
  final List<CareMedicationListReview> medicationListReviews;

  factory CareWorkspaceSnapshot.empty(String ownerScope) =>
      CareWorkspaceSnapshot(
        ownerScope: ownerScope,
        followups: DecisionSupportFollowupLedger.empty(ownerScope),
      );

  CareWorkspaceSnapshot copyWith({
    DecisionSupportFollowupLedger? followups,
    Iterable<PersonalObservation>? observations,
    Iterable<CareDiscussionNote>? notes,
    Iterable<CareMedicationDiscussionEntry>? medicationDiscussionEntries,
    Iterable<CareMedicationDiscussionOutcome>? medicationDiscussionOutcomes,
    Iterable<CareMedicationListReview>? medicationListReviews,
  }) => CareWorkspaceSnapshot(
    ownerScope: ownerScope,
    followups: followups ?? this.followups,
    observations: observations ?? this.observations,
    notes: notes ?? this.notes,
    medicationDiscussionEntries:
        medicationDiscussionEntries ?? this.medicationDiscussionEntries,
    medicationDiscussionOutcomes:
        medicationDiscussionOutcomes ?? this.medicationDiscussionOutcomes,
    medicationListReviews: medicationListReviews ?? this.medicationListReviews,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': careWorkspaceSchemaVersion,
    'ownerScope': ownerScope,
    'followups': followups.toJson(),
    'observations': observations.map((o) => o.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'medicationDiscussionEntries': medicationDiscussionEntries
        .map((entry) => entry.toJson())
        .toList(),
    'medicationDiscussionOutcomes': medicationDiscussionOutcomes
        .map((outcome) => outcome.toJson())
        .toList(),
    'medicationListReviews': medicationListReviews
        .map((review) => review.toJson())
        .toList(),
  };

  factory CareWorkspaceSnapshot.decode(
    String raw, {
    required String ownerScope,
  }) {
    if (raw.length > careWorkspaceMaxBytes ||
        utf8.encode(raw).length > careWorkspaceMaxBytes) {
      throw const FormatException('Care workspace too large');
    }
    final json = _object(jsonDecode(raw));
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int ||
        json['ownerScope'] != ownerScope ||
        (schemaVersion != _legacyCareWorkspaceV1 &&
            schemaVersion != _legacyCareWorkspaceV2 &&
            schemaVersion != _legacyCareWorkspaceV3 &&
            schemaVersion != _legacyCareWorkspaceV4 &&
            schemaVersion != careWorkspaceSchemaVersion)) {
      throw const FormatException('Care workspace version or owner mismatch');
    }
    _requireFields(json, switch (schemaVersion) {
      _legacyCareWorkspaceV1 => const {
        'schemaVersion',
        'ownerScope',
        'followups',
        'observations',
        'notes',
      },
      _legacyCareWorkspaceV2 || _legacyCareWorkspaceV3 => const {
        'schemaVersion',
        'ownerScope',
        'followups',
        'observations',
        'notes',
        'medicationDiscussionEntries',
      },
      _legacyCareWorkspaceV4 => const {
        'schemaVersion',
        'ownerScope',
        'followups',
        'observations',
        'notes',
        'medicationDiscussionEntries',
        'medicationDiscussionOutcomes',
      },
      _ => const {
        'schemaVersion',
        'ownerScope',
        'followups',
        'observations',
        'notes',
        'medicationDiscussionEntries',
        'medicationDiscussionOutcomes',
        'medicationListReviews',
      },
    });
    return CareWorkspaceSnapshot(
      ownerScope: ownerScope,
      followups: DecisionSupportFollowupLedger.fromJson(
        _object(json['followups']),
        ownerScope: ownerScope,
      ),
      observations: _boundedList(json['observations'], 5000).map((o) {
        final value = _object(o);
        final observation = PersonalObservation.fromJson(value);
        _requireFields(value, observation.toJson().keys.toSet());
        return observation;
      }),
      notes: _boundedList(
        json['notes'],
        200,
      ).map((n) => CareDiscussionNote.fromJson(_object(n))),
      medicationDiscussionEntries: schemaVersion == _legacyCareWorkspaceV1
          ? const <CareMedicationDiscussionEntry>[]
          : _boundedList(json['medicationDiscussionEntries'], 128).map(
              (entry) => CareMedicationDiscussionEntry.fromJson(
                _object(entry),
                legacyV2: schemaVersion == _legacyCareWorkspaceV2,
              ),
            ),
      medicationDiscussionOutcomes:
          schemaVersion == _legacyCareWorkspaceV4 ||
              schemaVersion == careWorkspaceSchemaVersion
          ? _boundedList(json['medicationDiscussionOutcomes'], 512).map(
              (outcome) =>
                  CareMedicationDiscussionOutcome.fromJson(_object(outcome)),
            )
          : const <CareMedicationDiscussionOutcome>[],
      medicationListReviews: schemaVersion == careWorkspaceSchemaVersion
          ? _boundedList(
              json['medicationListReviews'],
              CareMedicationListReviewSection.values.length,
            ).map(
              (review) => CareMedicationListReview.fromJson(_object(review)),
            )
          : const <CareMedicationListReview>[],
    );
  }
}

/// Serializes read-modify-write transactions across the whole local service.
/// Failed writes never publish a new snapshot. Corrupt/newer payloads surface
/// an error and remain untouched instead of being replaced with empty data.
final class CareWorkspaceService {
  CareWorkspaceService({required this.store});
  final CareWorkspaceStore store;
  Future<void> _tail = Future<void>.value();

  Future<CareWorkspaceSnapshot> _read(String owner) async {
    final raw = await store.read(owner);
    return raw == null
        ? CareWorkspaceSnapshot.empty(owner)
        : CareWorkspaceSnapshot.decode(raw, ownerScope: owner);
  }

  Future<CareWorkspaceSnapshot> load(
    String owner, {
    bool Function()? authorize,
  }) => _enqueue(() async {
    _requireAuthorization(authorize);
    final snapshot = await _read(owner);
    _requireAuthorization(authorize);
    return snapshot;
  });

  Future<CareWorkspaceSnapshot> mutate(
    String owner,
    CareWorkspaceSnapshot Function(CareWorkspaceSnapshot) transform, {
    required bool Function() authorize,
  }) {
    return _enqueue(() async {
      if (!authorize()) throw StateError('care_workspace_session_changed');
      final current = await _read(owner);
      if (!authorize()) throw StateError('care_workspace_session_changed');
      final next = transform(current);
      if (next.ownerScope != owner) {
        throw StateError('care_workspace_owner_changed');
      }
      final raw = jsonEncode(next.toJson());
      if (utf8.encode(raw).length > careWorkspaceMaxBytes) {
        throw StateError('care_workspace_capacity_reached');
      }
      if (!authorize()) throw StateError('care_workspace_session_changed');
      if (raw == jsonEncode(current.toJson())) return current;
      await store.write(owner, raw, authorize: authorize);
      if (!authorize()) throw StateError('care_workspace_session_changed');
      return next;
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}

void _requireAuthorization(bool Function()? authorize) {
  if (authorize != null && !authorize()) {
    throw StateError('care_workspace_session_changed');
  }
}

bool _boundedText(String value, int max) =>
    value.trim().isNotEmpty &&
    value.length <= max &&
    !RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(value);

Map<String, dynamic> _object(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected care workspace object');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid care field: $key');
  return value;
}

List<dynamic> _boundedList(Object? value, int max) {
  if (value is! List || value.length > max) {
    throw const FormatException('Invalid care record list');
  }
  return value;
}

void _requireFields(Map<String, dynamic> json, Set<String> fields) {
  if (json.length != fields.length || !fields.containsAll(json.keys)) {
    throw const FormatException('Unexpected care workspace fields');
  }
}
