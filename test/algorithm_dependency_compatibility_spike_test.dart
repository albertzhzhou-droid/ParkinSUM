import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_dependency_compatibility.dart';

import '../tool/algorithm_dependency_compatibility_spike.dart';

void main() {
  test(
    'exact analyzer resolves all roots while transitive closure remains held',
    () async {
      final report = await runAlgorithmDependencyCompatibilitySpike();

      expect(
        report.compatibilityState,
        algorithmDependencyCompatibilityAccepted,
      );
      expect(report.compatibilityAccepted, isTrue);
      expect(report.analysisContextCount, greaterThan(0));
      expect(report.roots, hasLength(65));
      expect(report.acceptedRootCount, 65);
      expect(report.heldAlgorithmIds, isEmpty);
      expect(report.environmentHoldReasons, isEmpty);
      expect(
        report.canonicalPayload['closure_state'],
        algorithmDependencyClosureHeld,
      );
      expect(
        report.canonicalJson,
        isNot(contains(Directory.current.absolute.path)),
      );
      expect(report.canonicalJson, isNot(contains('file:///')));
      expect(report.sha256Digest, matches(RegExp(r'^[a-f0-9]{64}$')));

      final permuted = AlgorithmDependencyCompatibilityReport(
        analyzerVersion: report.analyzerVersion,
        analyzerArchiveSha256: report.analyzerArchiveSha256,
        dartVersion: report.dartVersion,
        flutterVersion: report.flutterVersion,
        rootManifestSha256: report.rootManifestSha256,
        pubspecLockSha256: report.pubspecLockSha256,
        packageConfigSha256: report.packageConfigSha256,
        analysisOptionsSha256: report.analysisOptionsSha256,
        analysisContextCount: report.analysisContextCount,
        environmentHoldReasons: report.environmentHoldReasons.reversed,
        roots: report.roots.reversed,
      );
      expect(permuted.canonicalJson, report.canonicalJson);
      expect(permuted.sha256Digest, report.sha256Digest);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('non-success, session, library, URI and diagnostic mutations hold', () {
    final mutations = [
      acceptedRoot(resultVariant: 'InvalidPathResult'),
      acceptedRoot(sessionConsistent: false),
      acceptedRoot(isLibrary: false),
      acceptedRoot(
        resolvedLibraryUri: 'package:parkinsum_companion/wrong.dart',
      ),
      acceptedRoot(blockingDiagnosticCodes: const ['COMPILE_TIME_ERROR']),
    ];
    for (final mutation in mutations) {
      final report = reportFor(roots: [mutation]);
      expect(
        report.compatibilityAccepted,
        isFalse,
        reason: mutation.holdReasons.join(','),
      );
      expect(report.compatibilityState, algorithmDependencyCompatibilityHeld);
      expect(report.heldAlgorithmIds, ['fixture_algorithm']);
    }
  });

  test('toolchain drift and environmental blockers hold independently', () {
    expect(reportFor(dartVersion: '3.14.0').compatibilityAccepted, isFalse);
    expect(reportFor(flutterVersion: '3.48.0').compatibilityAccepted, isFalse);
    expect(
      reportFor(
        environmentHoldReasons: const ['analysis_options_missing'],
      ).compatibilityAccepted,
      isFalse,
    );
  });
}

AlgorithmRootResolutionObservation acceptedRoot({
  String resultVariant = 'ResolvedUnitResult',
  bool sessionConsistent = true,
  bool isLibrary = true,
  String? resolvedLibraryUri =
      'package:parkinsum_companion/domain/usecases/fixture.dart',
  List<String> blockingDiagnosticCodes = const [],
}) => AlgorithmRootResolutionObservation(
  algorithmId: 'fixture_algorithm',
  logicalRootId: 'algorithm-root/fixture_algorithm',
  resultSinkId: 'algorithm-result-sink/fixture_algorithm',
  canonicalPackageUri:
      'package:parkinsum_companion/domain/usecases/fixture.dart',
  resultVariant: resultVariant,
  sessionConsistent: sessionConsistent,
  isLibrary: isLibrary,
  resolvedLibraryUri: resolvedLibraryUri,
  blockingDiagnosticCodes: blockingDiagnosticCodes,
);

AlgorithmDependencyCompatibilityReport reportFor({
  String dartVersion = algorithmDependencyReviewedDartVersion,
  String flutterVersion = algorithmDependencyReviewedFlutterVersion,
  List<String> environmentHoldReasons = const [],
  List<AlgorithmRootResolutionObservation>? roots,
}) => AlgorithmDependencyCompatibilityReport(
  analyzerVersion: algorithmDependencyAnalyzerVersion,
  analyzerArchiveSha256: algorithmDependencyAnalyzerArchiveSha256,
  dartVersion: dartVersion,
  flutterVersion: flutterVersion,
  rootManifestSha256: List.filled(64, 'a').join(),
  pubspecLockSha256: List.filled(64, 'b').join(),
  packageConfigSha256: List.filled(64, 'c').join(),
  analysisOptionsSha256: List.filled(64, 'd').join(),
  analysisContextCount: 1,
  environmentHoldReasons: environmentHoldReasons,
  roots: roots ?? [acceptedRoot()],
);
