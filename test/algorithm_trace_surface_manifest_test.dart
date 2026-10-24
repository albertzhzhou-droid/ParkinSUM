import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_descriptor.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';

void main() {
  AlgorithmTraceSurfaceManifest current() => AlgorithmTraceSurfaceManifest(
    algorithms: AlgorithmRegistry.all,
    providers: AlgorithmObservatoryService.routeTraceProviders,
  );

  test(
    'reviewed trace manifest exactly matches compiled production ownership',
    () {
      final manifest = current();
      final reviewed = jsonDecode(
        File('config/algorithm_trace_surface_manifest.json').readAsStringSync(),
      );

      expect(reviewed, manifest.toJson());
      expect(manifest.algorithms, hasLength(67));
      expect(manifest.liveCount, 15);
      expect(manifest.staticOnlyCount, 52);
      expect(manifest.sha256Digest, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(manifest.providers, hasLength(2));
      final provider = manifest.providers.singleWhere(
        (entry) =>
            entry.providerId ==
            AlgorithmTraceProviderIds.productionObservatorySnapshot,
      );
      final physiology = manifest.providers.singleWhere(
        (entry) =>
            entry.providerId ==
            AlgorithmTraceProviderIds.physiologyReferenceTimingComparison,
      );
      expect(physiology.routeId, provider.routeId);
      expect(
        physiology.uiSurfaceKeysByAlgorithm['physiology_reference_model'],
        'chart-panel-physiology-reference',
      );
      expect(
        manifest.dispositionFor('physiology_reference_model'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(provider.routeId, 'app-tools.observatory');
      expect(
        provider.routeSourcePath,
        'lib/features/main_shell/app_destinations.dart',
      );
      expect(
        manifest.dispositionFor('gastric_emptying'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        manifest.dispositionFor('protein_distribution'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        manifest.dispositionFor('time_axis_builder'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        manifest.dispositionFor('medication_entry_validator'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        manifest.dispositionFor('input_quality_gate'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        manifest.dispositionFor('protein_trend'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        manifest.dispositionFor('dosage_note_parser'),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        manifest.dispositionFor(
          'gastric_structural_uncertainty_shadow_ensemble',
        ),
        AlgorithmTraceSurfaceDisposition.productionTrace,
      );
      expect(
        provider
            .uiSurfaceKeysByAlgorithm['gastric_structural_uncertainty_shadow_ensemble'],
        'chart-panel-gastric-structural-uncertainty',
      );
      expect(provider.fixtureRevision, 'synthetic-observatory-v5');
    },
  );

  test('provider ownership fails closed on missing UI binding', () {
    final provider = AlgorithmObservatoryService.traceProviderContract;
    expect(
      () => AlgorithmTraceSurfaceManifest(
        algorithms: AlgorithmRegistry.all,
        providers: [
          AlgorithmTraceProviderContract(
            providerId: provider.providerId,
            algorithmIds: provider.algorithmIds,
            fixtureSchema: provider.fixtureSchema,
            fixtureRevision: provider.fixtureRevision,
            lifecycle: provider.lifecycle,
            routeId: provider.routeId,
            routeSourcePath: provider.routeSourcePath,
            providerSourcePath: provider.providerSourcePath,
            uiSurfaceKeysByAlgorithm: const {},
            executableTestPaths: provider.executableTestPaths,
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test('provider ownership fails closed on an unknown algorithm', () {
    final provider = AlgorithmObservatoryService.traceProviderContract;
    expect(
      () => AlgorithmTraceSurfaceManifest(
        algorithms: AlgorithmRegistry.all,
        providers: [
          AlgorithmTraceProviderContract(
            providerId: provider.providerId,
            algorithmIds: const ['not_registered'],
            fixtureSchema: provider.fixtureSchema,
            fixtureRevision: provider.fixtureRevision,
            lifecycle: provider.lifecycle,
            routeId: provider.routeId,
            routeSourcePath: provider.routeSourcePath,
            providerSourcePath: provider.providerSourcePath,
            uiSurfaceKeysByAlgorithm: const {
              'not_registered': 'missing-surface',
            },
            executableTestPaths: provider.executableTestPaths,
          ),
        ],
      ),
      throwsStateError,
    );
  });
}
