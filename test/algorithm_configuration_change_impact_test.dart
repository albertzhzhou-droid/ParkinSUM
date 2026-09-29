import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_configuration_change_impact.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_configuration_change_impact_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';

void main() {
  const service = AlgorithmConfigurationChangeImpactService();

  test('pinned before-after fixture is deterministic and promotion blocked', () {
    final first = service.buildCurrentFixture();
    final second = service.buildCurrentFixture();

    expect(
      first.previousConfigurationSha256,
      isNot(first.currentConfigurationSha256),
    );
    expect(
      first.previousConfigurationSha256,
      AlgorithmConfigurationChangeImpactService.baselineFixtureSha256Pin,
    );
    expect(
      first.currentConfigurationSha256,
      AlgorithmConfigurationChangeImpactService.currentFixtureSha256Pin,
    );
    // The gastric fixture also changes gastric witness coverage plus the
    // absorption dependency and derived witness digests.
    expect(first.changes, hasLength(10));
    expect(
      first.changes
          .singleWhere(
            (change) =>
                change.path ==
                'algorithm_configuration_coverage_manifest.complete_per_field_coverage_count',
          )
          .affectedAlgorithmIds,
      ['gastric_emptying'],
    );
    expect(
      first.changes.expand((change) => change.affectedAlgorithmIds).toSet(),
      {'gastric_emptying', 'levodopa_absorption_opportunity'},
    );
    expect(first.relationships, hasLength(65));
    expect(first.replayDeltas, hasLength(15));
    expect(
      first.replayDeltas.map((delta) => delta.comparison).toSet(),
      containsAll(ImpactReplayComparison.values),
    );
    expect(first.integrityReasons, isEmpty);
    expect(first.obligations, hasLength(ImpactVerificationKind.values.length));
    expect(
      first.obligations.every(
        (obligation) =>
            obligation.disposition == ImpactObligationDisposition.unresolved,
      ),
      isTrue,
    );
    expect(first.canCloseImpact, isFalse);
    expect(first.packageSha256, second.packageSha256);
    expect(first.comparisonBoundary, contains('manufactured'));
  });

  test('pinned digests use a runtime-independent number encoding', () {
    // dart2js cannot distinguish 90.0 from 90, so the VM must hash them alike
    // or web builds reject the pins above.
    expect(
      AlgorithmConfigurationIdentity.digestConfiguration({
        'a': 90.0,
        'b': [0.0, -0.0, 1e18],
      }),
      AlgorithmConfigurationIdentity.digestConfiguration({
        'a': 90,
        'b': [0, 0, 1000000000000000000],
      }),
    );
    expect(
      AlgorithmConfigurationIdentity.digestConfiguration({'a': 90.5}),
      isNot(AlgorithmConfigurationIdentity.digestConfiguration({'a': 90})),
    );
  });

  test('untrusted and circular identity comparisons are rejected', () {
    final identity = AlgorithmConfigurationIdentity.defaults();
    final observatory = AlgorithmObservatoryService();
    final snapshots = {
      for (final scenario in ObservatoryScenario.values)
        scenario: observatory.build(scenario),
    };
    expect(
      () => service.assess(
        previousIdentity: identity,
        currentIdentity: identity,
        expectedPreviousSha256: _sha('0'),
        expectedCurrentSha256: identity.sha256Digest,
        previousSnapshots: snapshots,
        currentSnapshots: snapshots,
      ),
      throwsStateError,
    );
    expect(
      () => service.assess(
        previousIdentity: identity,
        currentIdentity: identity,
        expectedPreviousSha256: identity.sha256Digest,
        expectedCurrentSha256: identity.sha256Digest,
        previousSnapshots: snapshots,
        currentSnapshots: snapshots,
      ),
      throwsArgumentError,
    );
  });

  test('semantic mutations retain values, units, formulas and provenance', () {
    final changes = service.compareCanonicalConfigurations(
      previous: {
        'gastric_emptying': {
          'value': 85,
          'canonical_unit': 'minute',
          'formula_id': 'formula/0',
          'transform_id': 'identity/0',
          'source_ids': ['source.old'],
          'provenance_status': 'prototypeHeuristic',
        },
      },
      current: {
        'gastric_emptying': {
          'value': 90,
          'canonical_unit': 'min',
          'formula_id': 'formula/1',
          'transform_id': 'identity/1',
          'source_ids': ['source.current'],
          'provenance_status': 'literatureDerived',
        },
      },
    );
    expect(
      changes.map((change) => change.aspect).toSet(),
      containsAll({
        ConfigurationChangeAspect.value,
        ConfigurationChangeAspect.unit,
        ConfigurationChangeAspect.formula,
        ConfigurationChangeAspect.transform,
        ConfigurationChangeAspect.source,
        ConfigurationChangeAspect.provenance,
      }),
    );
    expect(
      changes.every((change) => change.previousValue != change.currentValue),
      isTrue,
    );
    expect(
      changes.every(
        (change) => change.affectedAlgorithmIds.contains('gastric_emptying'),
      ),
      isTrue,
    );
  });

  test('unknown, many-to-many and omitted consumers remain blocking', () {
    final hidden = service.compareCanonicalConfigurations(
      previous: const {'hidden_threshold': 1},
      current: const {'hidden_threshold': 2},
    );
    final manyToMany = AlgorithmConfigurationSemanticChange(
      path: 'shared.value',
      kind: ConfigurationChangeKind.changed,
      aspect: ConfigurationChangeAspect.value,
      previousValue: 1,
      currentValue: 2,
      affectedAlgorithmIds: const ['gastric_emptying', 'missing_algorithm'],
    );
    final reasons = service.validateImpactGraph(
      [...hidden, manyToMany],
      const [
        AlgorithmImpactRelationship(
          algorithmId: 'gastric_emptying',
          outputId: 'algorithm-output/gastric_emptying',
          outputDescription: 'curve',
          replayFixtureIds: ['fixture'],
          uiDescriptorId: 'algorithm-card-gastric_emptying',
          sourceBundleOnly: false,
        ),
      ],
    );
    expect(
      reasons.any((reason) => reason.startsWith('impact.unknown_consumer')),
      isTrue,
    );
    expect(
      reasons.any((reason) => reason.startsWith('impact.many_to_many_review')),
      isTrue,
    );
    expect(reasons, contains('impact.orphan_algorithm:missing_algorithm'));
  });

  test('null and every runtime state remain explicit on the wire', () {
    for (final state in ImpactReplayRuntimeState.values) {
      final delta = AlgorithmImpactReplayDelta(
        fixtureId: 'fixture.${state.name}',
        outputId: 'output',
        comparison: ImpactReplayComparison.unchanged,
        runtimeState: state,
        previousValue: null,
        currentValue: null,
        inputSha256: _sha('1'),
        previousConfigurationSha256: _sha('2'),
        currentConfigurationSha256: _sha('3'),
        sourceBundleSha256: _sha('4'),
        platformIdentity: 'test',
        toleranceContract: 'exact-null',
      ).toJson();
      expect(delta['runtime_state'], state.name);
      expect(delta.containsKey('previous_value'), isTrue);
      expect(delta.containsKey('current_value'), isTrue);
      expect(delta['previous_value'], isNull);
      expect(delta['current_value'], isNull);
    }
  });
}

String _sha(String character) => List.filled(64, character).join();
