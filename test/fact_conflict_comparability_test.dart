import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';

void main() {
  final engine = FactConflictEngine();

  test(
    'a different entity cannot overwrite, overlap or contradict this food',
    () {
      for (final override in [false, true]) {
        final result = engine.classify(
          observation: observation('10'),
          existingFacts: [fact('1', entity: 'PEAR', override: override)],
        );
        expect(result.type, FactConflictType.variation);
        expect(result.autoResolved, isTrue);
      }
    },
  );

  test(
    'unit mismatch needs explicit conversion rather than numeric comparison',
    () {
      final result = engine.classify(
        observation: observation('1'),
        existingFacts: [fact('1000', unit: 'mg', override: true)],
      );
      expect(result.type, FactConflictType.parsingUncertainty);
      expect(result.autoResolved, isFalse);
      expect(result.needsManualReview, isTrue);
    },
  );

  test(
    'strict less-than excludes its boundary while less-or-equal includes it',
    () {
      // Independent interval reasoning: [0,10) and {10} are disjoint;
      // [0,10] and {10} share exactly one point. No tolerance changes this.
      expect(
        engine
            .classify(
              observation: observation('<10'),
              existingFacts: [fact('10')],
            )
            .type,
        FactConflictType.contradiction,
      );
      expect(
        engine
            .classify(
              observation: observation('<=10'),
              existingFacts: [fact('10')],
            )
            .type,
        FactConflictType.variation,
      );
      expect(
        engine
            .classify(
              observation: observation('10'),
              existingFacts: [fact('<10')],
            )
            .type,
        FactConflictType.contradiction,
      );
    },
  );

  test(
    'missing and malformed values are not numerical zero or contradiction',
    () {
      final missing = engine.classify(
        observation: observation('missing'),
        existingFacts: [fact('0')],
      );
      expect(missing.type, FactConflictType.incompleteInput);
      expect(
        engine
            .classify(observation: observation('0'), existingFacts: [fact('0')])
            .type,
        FactConflictType.variation,
      );
      for (final malformed in ['NaN', 'Infinity', '5-1']) {
        expect(
          engine
              .classify(observation: observation(malformed), existingFacts: [])
              .type,
          FactConflictType.parsingUncertainty,
        );
      }
      expect(
        engine
            .classify(
              observation: observation('0'),
              existingFacts: [fact('missing')],
            )
            .type,
        FactConflictType.incompleteInput,
      );
    },
  );

  test('high authority missing data cannot displace a known zero', () {
    final result = engine.resolveCluster(
      observations: [
        observation('missing', id: 'official', source: 'p0'),
        observation('0', id: 'measured', source: 'p1'),
      ],
      existingFacts: [],
      sourceDocumentsById: {
        'p0': source('p0', KnowledgeDataTier.p0),
        'p1': source('p1', KnowledgeDataTier.p1),
      },
    );
    expect(result.chosenObservation!.observationId, 'measured');
    expect(result.chosenObservation!.value.valueNum, 0);
    expect(result.needsManualReview, isFalse);
    expect(
      result.rejectedRationales.single['rationale'],
      'missing_uncertain_or_invalid_interval',
    );
  });

  test(
    'all missing candidates and absent override targets withhold resolution',
    () {
      final noValues = engine.resolveCluster(
        observations: [observation('missing')],
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(noValues.chosenObservation, isNull);
      expect(noValues.status, 'insufficient_values');
      for (final target in ['absent', 'missing']) {
        final result = engine.resolveCluster(
          observations: [
            observation('1', id: 'valid'),
            observation('missing', id: 'missing'),
          ],
          existingFacts: [],
          sourceDocumentsById: {},
          manualOverrides: {'observation_id': target},
        );
        expect(result.status, 'invalid_manual_override');
        expect(result.chosenObservation, isNull);
        expect(result.needsManualReview, isTrue);
      }
    },
  );

  test('entity, unit and basis boundaries withhold heterogeneous clusters', () {
    final mutations = [
      observation('1', id: 'b', entity: 'PEAR'),
      observation('1', id: 'b', unit: 'mg'),
      observation('1', id: 'b', basis: 1),
    ];
    for (final mutation in mutations) {
      final result = engine.resolveCluster(
        observations: [
          observation('1', id: 'a'),
          mutation,
        ],
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(result.status, 'incompatible_cluster');
      expect(result.chosenObservation, isNull);
    }
  });

  test(
    'unregistered different scope hashes coexist without fabricated contradiction',
    () {
      final result = engine.resolveCluster(
        observations: [
          observation('1', id: 'a', scope: 'oral_ir'),
          observation('10', id: 'b', scope: 'oral_er'),
        ],
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(result.rejectedRationales.single['rationale'], 'scope_mismatch');
      expect(result.rejectedRationales.single['numeric_comparable'], isFalse);
      expect(
        result.rejectedRationales.single['cross_source_contradiction'],
        isFalse,
      );
      expect(result.needsManualReview, isFalse);
    },
  );

  test(
    'same scope cross-source contradiction and duplicate identity remain reviewable',
    () {
      final result = engine.resolveCluster(
        observations: [
          observation('1', id: 'a', source: 'a'),
          observation('10', id: 'b', source: 'b'),
        ],
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(
        result.rejectedRationales.single['cross_source_contradiction'],
        isTrue,
      );
      expect(result.needsManualReview, isTrue);
      final duplicate = engine.resolveCluster(
        observations: [observation('1'), observation('10')],
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(duplicate.status, 'invalid_observation_identity');
      expect(duplicate.chosenObservation, isNull);
    },
  );
}

ObservationRecord observation(
  String value, {
  String id = 'observation',
  String entity = 'APPLE',
  String unit = 'g',
  double basis = 100,
  String scope = 'scope',
  String source = 'source',
}) => ObservationRecord(
  observationId: id,
  domain: 'food',
  entityType: 'food_variant',
  entityKey: entity,
  attributeCode: 'protein_g',
  valueType: 'numeric_interval',
  value: parseQualifiedValue(value),
  unit: unit,
  basisType: 'per_100g_edible_part',
  basisAmount: basis,
  scopeHash: scope,
  sourceDocId: source,
  recordLocator: 'row',
  methodCode: null,
  extractionConfidence: 1,
);

ResolvedFactRecord fact(
  String value, {
  String entity = 'APPLE',
  String unit = 'g',
  bool override = false,
}) => ResolvedFactRecord(
  factId: 'fact',
  entityKey: entity,
  attributeCode: 'protein_g',
  scopeHash: 'scope',
  resolutionStatus: 'resolved',
  chosenObservationId: 'prior',
  resolvedValue: parseQualifiedValue(value),
  resolvedUnit: unit,
  resolutionPolicyId: 'policy',
  snapshotId: 'snapshot',
  factVersion: 'v1',
  manualOverride: override,
);

SourceDocumentRecord source(String id, String tier) => SourceDocumentRecord(
  sourceDocId: id,
  sourceFamily: 'TEST',
  dataTier: tier,
  ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
  organization: 'Synthetic fixture',
  docType: 'test',
  title: id,
  jurisdiction: 'US',
  originUrl: 'https://example.test/$id',
  publishedAt: DateTime.utc(2026),
  effectiveAt: DateTime.utc(2026),
  language: 'en',
  licenseNote: 'test',
  checksum: id,
  sourceStatus: 'active',
  rawPayload: '{}',
);
