import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_trace_node.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';

Iterable<AlgorithmTraceNode> _traceNodes(AlgorithmTraceNode root) sync* {
  yield root;
  for (final child in root.children) {
    yield* _traceNodes(child);
  }
}

void main() {
  test('every registered algorithm has a unique UI representation', () {
    final ids = AlgorithmRegistry.all.map((entry) => entry.id).toList();
    expect(ids.toSet().length, ids.length);
    final uiDescriptorIds = AlgorithmRegistry.all
        .map((entry) => entry.uiDescriptorId)
        .toSet();
    final staticVisualIds = AlgorithmRegistry.all
        .map((entry) => entry.staticVisual.contractId)
        .toSet();
    expect(uiDescriptorIds, hasLength(AlgorithmRegistry.all.length));
    expect(staticVisualIds, hasLength(AlgorithmRegistry.all.length));
    for (final entry in AlgorithmRegistry.all) {
      expect(entry.id, isNotEmpty, reason: 'empty algorithm id');
      expect(entry.name, isNotEmpty, reason: entry.id);
      expect(entry.userVisibleImpact, isNotEmpty, reason: entry.id);
      expect(entry.inputs, isNotEmpty, reason: entry.id);
      expect(entry.outputs, isNotEmpty, reason: entry.id);
      expect(entry.limitation, isNotEmpty, reason: entry.id);
      expect(entry.staticVisual.inputLabel, entry.inputs, reason: entry.id);
      expect(entry.staticVisual.transformLabel, entry.name, reason: entry.id);
      expect(entry.staticVisual.outputLabel, entry.outputs, reason: entry.id);
      expect(
        entry.hasLiveTrace,
        entry.traceProviderId != null,
        reason: '${entry.id} has an inconsistent provider declaration',
      );
      for (final path in entry.sourcePaths) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '${entry.id} points to missing $path',
        );
      }
    }
  });

  test(
    'every lib source is registered or exactly allowlisted with a reason',
    () {
      final registered = AlgorithmRegistry.all
          .expand((entry) => entry.sourcePaths)
          .toSet();
      final excluded = AlgorithmRegistry.excludedSourcePaths;
      final allowlistJson =
          jsonDecode(
                File(
                  'config/algorithm_surface_allowlist.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        allowlistJson[r'$schema'],
        'parkinsum.algorithm-surface-allowlist/1',
      );
      final categories = allowlistJson['categories'] as List<dynamic>;
      final allowlisted = <String>{};
      for (final raw in categories) {
        final category = raw as Map<String, dynamic>;
        final reason = category['reason'] as String;
        expect(reason.trim().length, greaterThan(40), reason: category['id']);
        for (final path
            in (category['paths'] as List<dynamic>).cast<String>()) {
          expect(
            allowlisted.add(path),
            isTrue,
            reason: '$path appears in more than one allowlist category',
          );
        }
      }
      final sourceFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.path)
          .toSet();

      for (final path in sourceFiles) {
        expect(
          registered.contains(path) ||
              excluded.containsKey(path) ||
              allowlisted.contains(path),
          isTrue,
          reason:
              '$path is new or unreviewed: declare its algorithm id and UI '
              'contract, or add an exact reviewed non-algorithm disposition.',
        );
      }
      expect(
        registered.intersection(excluded.keys.toSet()),
        isEmpty,
        reason: 'A source cannot be both algorithm-owned and excluded.',
      );
      expect(
        registered.intersection(allowlisted),
        isEmpty,
        reason: 'A source cannot be both algorithm-owned and allowlisted.',
      );
      expect(
        excluded.keys.toSet().intersection(allowlisted),
        isEmpty,
        reason: 'Use only one exclusion mechanism per source.',
      );
      for (final entry in excluded.entries) {
        expect(File(entry.key).existsSync(), isTrue, reason: entry.key);
        expect(entry.value.trim().length, greaterThan(20), reason: entry.key);
        expect(registered.contains(entry.key), isFalse, reason: entry.key);
      }
      for (final path in allowlisted) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      expect(
        {...registered, ...excluded.keys, ...allowlisted},
        sourceFiles,
        reason: 'The manifest must not retain deleted or renamed lib sources.',
      );
    },
  );

  test('live flags exactly match production-engine fixed-scenario trace ids', () {
    final registeredIds = AlgorithmRegistry.all
        .map((entry) => entry.id)
        .toSet();
    final liveIds = AlgorithmRegistry.all
        .where((entry) => entry.hasLiveTrace)
        .map((entry) => entry.id)
        .toSet();
    final providerContract = AlgorithmObservatoryService.traceProviderContract;

    expect(liveIds, equals(providerContract.algorithmIds.toSet()));
    expect(
      AlgorithmRegistry.all
          .where((entry) => entry.hasLiveTrace)
          .map((entry) => entry.traceProviderId)
          .toSet(),
      {providerContract.providerId},
    );

    final service = AlgorithmObservatoryService();
    final observedLiveIds = <String>{};
    for (final scenario in ObservatoryScenario.values) {
      final snapshot = service.build(scenario);
      final nodes = _traceNodes(
        snapshot.explanationTree,
      ).toList(growable: false);
      final providerNodes = nodes
          .where((node) => node.algorithmId != null)
          .toList(growable: false);
      final traceIds = providerNodes.map((node) => node.algorithmId!).toSet();
      observedLiveIds.addAll(traceIds);
      expect(
        traceIds.where(registeredIds.contains),
        everyElement(isIn(liveIds)),
        reason:
            '${scenario.name} emitted a registered trace that is not advertised as live',
      );
      if (snapshot.conflict.hasModeledOutput) {
        expect(
          traceIds,
          containsAll(liveIds),
          reason:
              '${scenario.name} produced modeled output and must expose every live layer',
        );
      }
      for (final node in providerNodes) {
        final descriptor = AlgorithmRegistry.byId(node.algorithmId!);
        expect(descriptor, isNotNull, reason: node.id);
        expect(descriptor!.hasLiveTrace, isTrue, reason: node.id);
        expect(node.providerId, descriptor.traceProviderId, reason: node.id);
      }
      for (final node in nodes.where(
        (node) => registeredIds.contains(node.id),
      )) {
        expect(
          node.algorithmId,
          node.id,
          reason:
              '${node.id} resembles a registered algorithm trace but lacks '
              'an executable provider binding',
        );
      }
    }

    expect(
      observedLiveIds,
      equals(liveIds),
      reason:
          'The production scenario union must exercise every algorithm advertised as live; an abstained scenario need not fabricate downstream nodes.',
    );

    expect(
      AlgorithmRegistry.byId('protein_distribution')?.hasLiveTrace,
      isFalse,
      reason:
          'A static score contract is not live until the snapshot provider emits its trace id.',
    );
  });
}
