import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

import 'clinical_decision_support_service_test.dart' show RecordingCdssDatabase;

ObservationRecord evidence(
  String id,
  String value, {
  String source = 'source',
  String? method = 'analytical',
  String? locator,
  String basisType = 'per_100g_edible_part',
  double basisAmount = 100,
}) => ObservationRecord(
  observationId: id,
  domain: 'food',
  entityType: 'food_variant',
  entityKey: 'same-food',
  attributeCode: 'protein_g',
  valueType: 'numeric_interval',
  value: parseQualifiedValue(value),
  unit: 'g',
  basisType: basisType,
  basisAmount: basisAmount,
  scopeHash: 'same-scope',
  sourceDocId: source,
  recordLocator: locator ?? 'row-$id',
  methodCode: method,
  extractionConfidence: 1,
);

void main() {
  final engine = FactConflictEngine();

  test('actual import persists the complete graph and opens review', () async {
    final database = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: database,
      factConflictEngine: engine,
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await expectLater(
      service.importBundle(
        P0ImportBundle(
          observations: [
            evidence('a', '1-10', source: 'wide'),
            evidence('b', '1-2', source: 'left'),
            evidence('c', '8-9', source: 'right'),
          ],
        ),
      ),
      throwsA(isA<CdssImportHeldException>()),
    );
    final row = (await database.queryTable(
      'conflict_audit_log',
    )).where((row) => row['audit_type'] == 'FACT_CLUSTER_RESOLUTION').single;
    final saved = jsonDecode(row['decision_reason'] as String) as Map;
    expect('${row['snapshot_id']}', startsWith('staging_'));
    expect(await service.latestPromotedSnapshot(), isNull);
    expect(row['decision'], 'review_required');
    expect(saved['needs_human_review'], isTrue);
    final graph = saved['comparison_edges'] as List;
    expect(graph, hasLength(3));
    expect(
      graph.where((edge) => edge['relation'] == 'contradiction').single,
      containsPair('left_observation_id', 'b'),
    );
    final actions = jsonDecode(row['machine_actions_json'] as String) as List;
    expect(actions.single['type'], 'open_manual_conflict_review');
    expect((await database.queryTable('observation')), isEmpty);
    expect((await database.queryTable('staging_observation')), hasLength(3));
  });

  test('a broad winner cannot conceal disjoint alternative evidence', () {
    final rows = [
      evidence('a', '1-10', source: 'wide'),
      evidence('b', '1-2', source: 'left'),
      evidence('c', '8-9', source: 'right'),
    ];
    for (final ordered in [
      rows,
      rows.reversed.toList(),
      [rows[1], rows[0], rows[2]],
    ]) {
      final result = engine.resolveCluster(
        observations: ordered,
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(result.needsManualReview, isTrue);
      expect(result.status, 'review_required');
      expect(result.comparisonEdges, hasLength(3));
      expect(
        result.comparisonEdges
            .where((edge) => edge['relation'] == 'contradiction')
            .single['left_observation_id'],
        'b',
      );
      expect(
        result.comparisonEdges
            .where((edge) => edge['relation'] == 'contradiction')
            .single['right_observation_id'],
        'c',
      );
    }
  });

  test(
    'same document does not make two inconsistent source rows duplicates',
    () {
      final result = engine.resolveCluster(
        observations: [evidence('a', '1'), evidence('b', '10')],
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(result.needsManualReview, isTrue);
      expect(
        result.rejectedRationales.single['same_source_duplicate'],
        isFalse,
      );
    },
  );

  test('different measurement methods coexist rather than contradict', () {
    final result = engine.resolveCluster(
      observations: [
        evidence('a', '1', source: 'one', method: 'analytical'),
        evidence('b', '10', source: 'two', method: 'imputed'),
      ],
      existingFacts: [],
      sourceDocumentsById: {},
    );
    expect(result.needsManualReview, isFalse);
    expect(result.rejectedRationales.single['numeric_comparable'], isFalse);
    expect(result.rejectedRationales.single['rationale'], 'method_mismatch');
    expect(result.comparisonEdges.single['relation'], 'coexisting_method');
  });

  test(
    'only a complete shared source locator and content prove duplication',
    () {
      final result = engine.resolveCluster(
        observations: [
          evidence('a', '1', locator: 'source-row'),
          evidence('b', '1', locator: 'source-row'),
        ],
        existingFacts: [],
        sourceDocumentsById: {},
      );
      expect(
        result.comparisonEdges.single['relation'],
        'proven_source_duplicate',
      );
      expect(result.rejectedRationales.single['same_source_duplicate'], isTrue);
      expect(result.needsManualReview, isFalse);
    },
  );

  test(
    'all six unordered pairs retain stable identities under input permutations',
    () {
      final rows = [
        evidence('d', '3'),
        evidence('b', '2'),
        evidence('c', '1-4'),
        evidence('a', '1'),
      ];
      String graph(List<ObservationRecord> input) => jsonEncode(
        engine
            .resolveCluster(
              observations: input,
              existingFacts: [],
              sourceDocumentsById: {},
            )
            .comparisonEdges,
      );
      final first = graph(rows);
      expect(jsonDecode(first), hasLength(6));
      expect(graph(rows.reversed.toList()), first);
      expect(graph([rows[1], rows[3], rows[2], rows[0]]), first);
    },
  );
}
