import 'dart:collection';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../core/models/recoverable_user_event.dart';

const int recoverableEventRestoreImpactSchemaVersion = 1;
const String recoverableEventRestoreRelationshipGraphVersion =
    'parkinsum.restore-relationship-graph/1';

enum RecoverableEventRestoreImpactStatus {
  ready,
  staleRecord,
  blockedAccount,
  blockedRelationships,
  blockedIntegrity,
}

enum RecoverableEventRestoreTargetAction { restorePriorState, removeRecord }

enum RecoverableEventRestoreConfirmationStatus {
  committed,
  committedWithRefreshFailure,
  stalePreview,
  blocked,
  busy,
  persistenceFailed,
}

final class RecoverableEventRestoreConfirmationResult {
  const RecoverableEventRestoreConfirmationResult(this.status);

  final RecoverableEventRestoreConfirmationStatus status;

  bool get wasCommitted =>
      status == RecoverableEventRestoreConfirmationStatus.committed ||
      status ==
          RecoverableEventRestoreConfirmationStatus.committedWithRefreshFailure;

  bool get derivedRefreshComplete =>
      status == RecoverableEventRestoreConfirmationStatus.committed;
}

/// Read-only, content-addressed forecast of a history restore.
///
/// A preview is intentionally not a write token by itself. [AppState] must
/// rebuild it from current authoritative state immediately before committing
/// and require the [previewId] to match. This makes record, account, catalog,
/// relationship-graph, and algorithm-configuration drift fail closed.
final class RecoverableEventRestoreImpactPreview {
  const RecoverableEventRestoreImpactPreview._({
    required this.previewId,
    required this.historyId,
    required this.eventType,
    required this.recordId,
    required this.status,
    required this.targetAction,
    required this.currentRecordDigest,
    required this.expectedCurrentRecordDigest,
    required this.restoredRecordDigest,
    required this.accountBindingDigest,
    required this.relationshipGraphDigest,
    required this.algorithmConfigurationDigest,
    required this.catalogDigest,
    required this.currentRelationships,
    required this.restoredRelationships,
    required this.addedRelationships,
    required this.removedRelationships,
    required this.missingRelationships,
    required this.invalidatedDerivedArtifacts,
  });

  final String previewId;
  final String historyId;
  final RecoverableUserEventType eventType;
  final String recordId;
  final RecoverableEventRestoreImpactStatus status;
  final RecoverableEventRestoreTargetAction targetAction;
  final String currentRecordDigest;
  final String expectedCurrentRecordDigest;
  final String restoredRecordDigest;
  final String accountBindingDigest;
  final String relationshipGraphDigest;
  final String algorithmConfigurationDigest;
  final String catalogDigest;
  final List<String> currentRelationships;
  final List<String> restoredRelationships;
  final List<String> addedRelationships;
  final List<String> removedRelationships;
  final List<String> missingRelationships;
  final List<String> invalidatedDerivedArtifacts;

  bool get isConfirmable => status == RecoverableEventRestoreImpactStatus.ready;

  bool get retainsImmutableHistory => true;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': recoverableEventRestoreImpactSchemaVersion,
    'preview_id': previewId,
    'history_id': historyId,
    'event_type': eventType.name,
    'record_id': recordId,
    'status': status.name,
    'target_action': targetAction.name,
    'current_record_digest': currentRecordDigest,
    'expected_current_record_digest': expectedCurrentRecordDigest,
    'restored_record_digest': restoredRecordDigest,
    'account_binding_digest': accountBindingDigest,
    'relationship_graph_version':
        recoverableEventRestoreRelationshipGraphVersion,
    'relationship_graph_digest': relationshipGraphDigest,
    'algorithm_configuration_digest': algorithmConfigurationDigest,
    'catalog_digest': catalogDigest,
    'current_relationships': currentRelationships,
    'restored_relationships': restoredRelationships,
    'added_relationships': addedRelationships,
    'removed_relationships': removedRelationships,
    'missing_relationships': missingRelationships,
    'invalidated_derived_artifacts': invalidatedDerivedArtifacts,
    'retains_immutable_history': retainsImmutableHistory,
  };
}

final class RecoverableEventRestoreImpactService {
  const RecoverableEventRestoreImpactService();

  static const List<String> _derivedArtifacts = <String>[
    'meal_check',
    'recommendation_explanations',
    'mechanistic_trace',
    'personal_log_handoff',
    'portable_package_relationships',
  ];

  RecoverableEventRestoreImpactPreview build({
    required RecoverableUserEventRevision revision,
    required Map<String, Object?>? currentPayload,
    required String? accountScope,
    required String algorithmConfigurationDigest,
    required Map<String, Map<String, Object?>> foodsById,
    required Map<String, Map<String, Object?>> drugsById,
  }) {
    try {
      revision.validate();
      _requireDigest(algorithmConfigurationDigest);
      final normalizedCurrent = normalizeRecoverableUserEventPayload(
        revision.eventType,
        currentPayload,
        expectedRecordId: revision.recordId,
      );
      final currentDigest = recoverableUserEventPayloadDigest(
        normalizedCurrent,
      );
      final currentRelationships = _relationships(
        revision.eventType,
        normalizedCurrent,
      );
      final restoredRelationships = _relationships(
        revision.eventType,
        revision.beforePayload,
      );
      final currentSet = currentRelationships.toSet();
      final restoredSet = restoredRelationships.toSet();
      final allRelationships = <String>{...currentSet, ...restoredSet}.toList()
        ..sort();
      final missingRelationships = restoredRelationships
          .where(
            (relationship) => !_catalogContains(
              relationship,
              foodsById: foodsById,
              drugsById: drugsById,
            ),
          )
          .toList(growable: false);
      final normalizedScope = accountScope?.trim() ?? '';
      final accountBindingDigest = normalizedScope.isEmpty
          ? recoverableUserEventAbsentDigest
          : AlgorithmConfigurationIdentity.digestConfiguration(
              <String, Object?>{
                'domain': 'parkinsum.restore-impact-account/1',
                'scope': normalizedScope,
              },
            );
      final catalogDigest = AlgorithmConfigurationIdentity.digestConfiguration(
        <String, Object?>{
          'relationships': <Object?>[
            for (final relationship in allRelationships)
              <String, Object?>{
                'relationship': relationship,
                'catalog_entry': _catalogEntry(
                  relationship,
                  foodsById: foodsById,
                  drugsById: drugsById,
                ),
              },
          ],
        },
      );
      final addedRelationships = restoredSet.difference(currentSet).toList()
        ..sort();
      final removedRelationships = currentSet.difference(restoredSet).toList()
        ..sort();
      final relationshipGraphDigest =
          AlgorithmConfigurationIdentity.digestConfiguration(<String, Object?>{
            'version': recoverableEventRestoreRelationshipGraphVersion,
            'event_type': revision.eventType.name,
            'record_id': revision.recordId,
            'current': currentRelationships,
            'restored': restoredRelationships,
            'missing': missingRelationships,
            'invalidated_derived_artifacts': _derivedArtifacts,
          });
      final status = normalizedScope.isEmpty
          ? RecoverableEventRestoreImpactStatus.blockedAccount
          : currentDigest != revision.afterDigest
          ? RecoverableEventRestoreImpactStatus.staleRecord
          : missingRelationships.isNotEmpty
          ? RecoverableEventRestoreImpactStatus.blockedRelationships
          : RecoverableEventRestoreImpactStatus.ready;
      final targetAction = revision.beforePayload == null
          ? RecoverableEventRestoreTargetAction.removeRecord
          : RecoverableEventRestoreTargetAction.restorePriorState;
      final identity = <String, Object?>{
        'schema_version': recoverableEventRestoreImpactSchemaVersion,
        'history_id': revision.historyId,
        'event_type': revision.eventType.name,
        'record_id': revision.recordId,
        'status': status.name,
        'target_action': targetAction.name,
        'current_record_digest': currentDigest,
        'expected_current_record_digest': revision.afterDigest,
        'restored_record_digest': revision.beforeDigest,
        'account_binding_digest': accountBindingDigest,
        'relationship_graph_digest': relationshipGraphDigest,
        'algorithm_configuration_digest': algorithmConfigurationDigest,
        'catalog_digest': catalogDigest,
        'current_relationships': currentRelationships,
        'restored_relationships': restoredRelationships,
        'added_relationships': addedRelationships,
        'removed_relationships': removedRelationships,
        'missing_relationships': missingRelationships,
        'invalidated_derived_artifacts': _derivedArtifacts,
      };
      return RecoverableEventRestoreImpactPreview._(
        previewId:
            'restore_preview_${AlgorithmConfigurationIdentity.digestConfiguration(identity)}',
        historyId: revision.historyId,
        eventType: revision.eventType,
        recordId: revision.recordId,
        status: status,
        targetAction: targetAction,
        currentRecordDigest: currentDigest,
        expectedCurrentRecordDigest: revision.afterDigest,
        restoredRecordDigest: revision.beforeDigest,
        accountBindingDigest: accountBindingDigest,
        relationshipGraphDigest: relationshipGraphDigest,
        algorithmConfigurationDigest: algorithmConfigurationDigest,
        catalogDigest: catalogDigest,
        currentRelationships: UnmodifiableListView(currentRelationships),
        restoredRelationships: UnmodifiableListView(restoredRelationships),
        addedRelationships: UnmodifiableListView(addedRelationships),
        removedRelationships: UnmodifiableListView(removedRelationships),
        missingRelationships: UnmodifiableListView(missingRelationships),
        invalidatedDerivedArtifacts: UnmodifiableListView(_derivedArtifacts),
      );
    } on Object {
      return _blockedIntegrity(
        revision: revision,
        currentPayload: currentPayload,
        algorithmConfigurationDigest: algorithmConfigurationDigest,
      );
    }
  }

  RecoverableEventRestoreImpactPreview _blockedIntegrity({
    required RecoverableUserEventRevision revision,
    required Map<String, Object?>? currentPayload,
    required String algorithmConfigurationDigest,
  }) {
    final safeAlgorithmDigest =
        RegExp(r'^[a-f0-9]{64}$').hasMatch(algorithmConfigurationDigest)
        ? algorithmConfigurationDigest
        : recoverableUserEventAbsentDigest;
    final currentDigest = recoverableUserEventPayloadDigest(currentPayload);
    final identity = <String, Object?>{
      'schema_version': recoverableEventRestoreImpactSchemaVersion,
      'status': RecoverableEventRestoreImpactStatus.blockedIntegrity.name,
      'history_id': revision.historyId,
      'current_record_digest': currentDigest,
      'algorithm_configuration_digest': safeAlgorithmDigest,
    };
    return RecoverableEventRestoreImpactPreview._(
      previewId:
          'restore_preview_${AlgorithmConfigurationIdentity.digestConfiguration(identity)}',
      historyId: revision.historyId,
      eventType: revision.eventType,
      recordId: revision.recordId,
      status: RecoverableEventRestoreImpactStatus.blockedIntegrity,
      targetAction: revision.beforePayload == null
          ? RecoverableEventRestoreTargetAction.removeRecord
          : RecoverableEventRestoreTargetAction.restorePriorState,
      currentRecordDigest: currentDigest,
      expectedCurrentRecordDigest: revision.afterDigest,
      restoredRecordDigest: revision.beforeDigest,
      accountBindingDigest: recoverableUserEventAbsentDigest,
      relationshipGraphDigest: recoverableUserEventAbsentDigest,
      algorithmConfigurationDigest: safeAlgorithmDigest,
      catalogDigest: recoverableUserEventAbsentDigest,
      currentRelationships: const <String>[],
      restoredRelationships: const <String>[],
      addedRelationships: const <String>[],
      removedRelationships: const <String>[],
      missingRelationships: const <String>[],
      invalidatedDerivedArtifacts: const <String>[],
    );
  }

  static List<String> _relationships(
    RecoverableUserEventType eventType,
    Map<String, Object?>? payload,
  ) {
    if (payload == null) return const <String>[];
    final relationships = <String>{};
    switch (eventType) {
      case RecoverableUserEventType.meal:
        final items = payload['items'];
        if (items is! List) {
          throw const FormatException('Meal items are not a list.');
        }
        for (final item in items) {
          if (item is! Map) {
            throw const FormatException('Meal item is not an object.');
          }
          final rawId = item['foodId'];
          if (rawId is! String || rawId.trim().isEmpty) {
            throw const FormatException('Meal food relationship is invalid.');
          }
          relationships.add('food:${rawId.trim()}');
        }
      case RecoverableUserEventType.intake:
        final rawId = payload['drugId'];
        if (rawId is! String || rawId.trim().isEmpty) {
          throw const FormatException('Intake drug relationship is invalid.');
        }
        relationships.add('drug:${rawId.trim()}');
    }
    final sorted = relationships.toList()..sort();
    return List<String>.unmodifiable(sorted);
  }

  static bool _catalogContains(
    String relationship, {
    required Map<String, Map<String, Object?>> foodsById,
    required Map<String, Map<String, Object?>> drugsById,
  }) =>
      _catalogEntry(relationship, foodsById: foodsById, drugsById: drugsById) !=
      null;

  static Map<String, Object?>? _catalogEntry(
    String relationship, {
    required Map<String, Map<String, Object?>> foodsById,
    required Map<String, Map<String, Object?>> drugsById,
  }) {
    if (relationship.startsWith('food:')) {
      return foodsById[relationship.substring('food:'.length)];
    }
    if (relationship.startsWith('drug:')) {
      return drugsById[relationship.substring('drug:'.length)];
    }
    throw const FormatException('Relationship kind is invalid.');
  }

  static void _requireDigest(String value) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw const FormatException('Algorithm configuration digest is invalid.');
    }
  }
}
