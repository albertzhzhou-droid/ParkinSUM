import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_descriptor.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';

void main() {
  AlgorithmTraceSurfaceManifest current() => AlgorithmTraceSurfaceManifest(
    algorithms: AlgorithmRegistry.all,
    providers: const [AlgorithmObservatoryService.traceProviderContract],
  );

  test(
    'reviewed trace manifest exactly matches compiled production ownership',
    () {
      final manifest = current();
      final reviewed = jsonDecode(
        File('config/algorithm_trace_surface_manifest.json').readAsStringSync(),
      );

      expect(reviewed, manifest.toJson());
      expect(manifest.algorithms, hasLength(65));
      expect(manifest.liveCount, 14);
      expect(manifest.staticOnlyCount, 51);
      expect(manifest.sha256Digest, matches(RegExp(r'^[a-f0-9]{64}$')));
      final provider = manifest.providers.single;
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
