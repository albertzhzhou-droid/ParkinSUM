import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';

void main() {
  final engine = FactConflictEngine();

  test('classifies contradiction for non-overlapping facts in same scope', () {
    final observation = ObservationRecord(
      observationId: 'obs_1',
      domain: 'food',
      entityType: 'food_variant',
      entityKey: 'APPLE_RAW_WITH_SKIN#US#FDC#1',
      attributeCode: 'protein_g',
      valueType: 'numeric_interval',
      value: parseQualifiedValue('10'),
      unit: 'g',
      basisType: 'per_100g_edible_part',
      basisAmount: 100,
      scopeHash: 'scope_us_raw',
      sourceDocId: 'doc_1',
      recordLocator: 'row_1',
      methodCode: null,
      extractionConfidence: 1,
    );
    final fact = ResolvedFactRecord(
      factId: 'fact_1',
      entityKey: 'APPLE_RAW_WITH_SKIN#US#FDC#1',
      attributeCode: 'protein_g',
      scopeHash: 'scope_us_raw',
      resolutionStatus: 'resolved',
      chosenObservationId: 'obs_old',
      resolvedValue: parseQualifiedValue('1'),
      resolvedUnit: 'g',
      resolutionPolicyId: 'policy_1',
      snapshotId: 'snapshot_1',
      factVersion: 'facts_v1',
      manualOverride: false,
    );

    final result = engine.classify(
      observation: observation,
      existingFacts: [fact],
    );

    expect(result.type, FactConflictType.contradiction);
  });

  test('classifies co-existing variant when scope differs', () {
    final observation = ObservationRecord(
      observationId: 'obs_2',
      domain: 'food',
      entityType: 'food_variant',
      entityKey: 'APPLE_RAW_WITH_SKIN#FR#CIQUAL#2',
      attributeCode: 'protein_g',
      valueType: 'numeric_interval',
      value: parseQualifiedValue('0.25'),
      unit: 'g',
      basisType: 'per_100g_edible_part',
      basisAmount: 100,
      scopeHash: 'scope_fr_raw',
      sourceDocId: 'doc_2',
      recordLocator: 'row_2',
      methodCode: null,
      extractionConfidence: 1,
    );
    final fact = ResolvedFactRecord(
      factId: 'fact_2',
      entityKey: 'APPLE_RAW_WITH_SKIN#US#FDC#1',
      attributeCode: 'protein_g',
      scopeHash: 'scope_us_raw',
      resolutionStatus: 'resolved',
      chosenObservationId: 'obs_old',
      resolvedValue: parseQualifiedValue('0.34'),
      resolvedUnit: 'g',
      resolutionPolicyId: 'policy_1',
      snapshotId: 'snapshot_1',
      factVersion: 'facts_v1',
      manualOverride: false,
    );

    final result = engine.classify(
      observation: observation,
      existingFacts: [fact],
    );

    expect(result.type, FactConflictType.coexistVariant);
  });

  test('unrelated fact permutation cannot hide a same-scope contradiction', () {
    final observation = ObservationRecord(
      observationId: 'obs_order',
      domain: 'food',
      entityType: 'food_variant',
      entityKey: 'APPLE_RAW_WITH_SKIN#US#FDC#1',
      attributeCode: 'protein_g',
      valueType: 'numeric_interval',
      value: parseQualifiedValue('10'),
      unit: 'g',
      basisType: 'per_100g_edible_part',
      basisAmount: 100,
      scopeHash: 'scope_us_raw',
      sourceDocId: 'doc_order',
      recordLocator: 'row_order',
      methodCode: null,
      extractionConfidence: 1,
    );
    final contradiction = ResolvedFactRecord(
      factId: 'fact_contradiction',
      entityKey: observation.entityKey,
      attributeCode: observation.attributeCode,
      scopeHash: observation.scopeHash,
      resolutionStatus: 'resolved',
      chosenObservationId: 'obs_old',
      resolvedValue: parseQualifiedValue('1'),
      resolvedUnit: 'g',
      resolutionPolicyId: 'policy_1',
      snapshotId: 'snapshot_1',
      factVersion: 'facts_v1',
      manualOverride: false,
    );
    final unrelated = ResolvedFactRecord(
      factId: 'fact_unrelated',
      entityKey: 'PEAR#US#FDC#2',
      attributeCode: 'fiber_g',
      scopeHash: 'scope_other',
      resolutionStatus: 'resolved',
      chosenObservationId: 'obs_other',
      resolvedValue: parseQualifiedValue('3'),
      resolvedUnit: 'g',
      resolutionPolicyId: 'policy_1',
      snapshotId: 'snapshot_1',
      factVersion: 'facts_v1',
      manualOverride: false,
    );

    final forward = engine.classify(
      observation: observation,
      existingFacts: [unrelated, contradiction],
    );
    final reversed = engine.classify(
      observation: observation,
      existingFacts: [contradiction, unrelated],
    );

    expect(forward.type, FactConflictType.contradiction);
    expect(reversed.type, FactConflictType.contradiction);
    expect(forward.needsManualReview, isTrue);
    expect(reversed.needsManualReview, isTrue);
  });
}
