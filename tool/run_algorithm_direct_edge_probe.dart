import 'dart:convert';
import 'dart:io';

import 'algorithm_direct_edge_probe.dart';

Future<void> main() async {
  try {
    final report = await runAlgorithmDirectEdgeProbe();
    final output = File('build/algorithm_direct_edge_probe/latest.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n',
    );
    stdout.writeln(
      'Algorithm direct-edge probe: '
      '${report.compatibilityAccepted ? 'ROOTS_RESOLVED' : 'HOLD'} '
      '(${report.acceptedRootCount}/${report.roots.length} roots; '
      '${report.acceptedSourceUnitCount}/${report.sourceFileCount} lib units; '
      '${report.edges.length} root direct edges; '
      '${report.declarationEdges.length} declaration edges; '
      '${report.namespaceEdges.length} namespace branches; '
      '${report.supportedCallReachability.length} root reachability previews; '
      '${report.supportedCallReachability.fold(0, (sum, item) => sum + item.reachableEdgeCount)} reachable edges; '
      '${report.supportedCallReachability.fold(0, (sum, item) => sum + item.reachableSourceUnitCount)} reachable source-unit visits; '
      '${report.supportedCallReachability.fold(0, (sum, item) => sum + item.reachableNamespaceBranchCount)} reachable namespace branches; '
      '${report.supportedCallReachability.fold(0, (sum, item) => sum + item.cyclicComponents.length)} bounded cycle components; '
      '${report.supportedCallReverseReachability.length} reverse-ownership rows; '
      '${report.supportedCallReverseReachability.fold(0, (sum, item) => sum + item.algorithmIds.length)} declaration-owner pairs; '
      '${report.supportedCallReverseSourceOwnership.length} reverse source-ownership rows; '
      '${report.supportedCallReverseSourceOwnership.fold(0, (sum, item) => sum + item.algorithmIds.length)} source-owner pairs; '
      '${report.unresolved.length} unresolved groups; '
      '${report.sourceUnresolved.length} source unresolved groups; '
      '${report.reachabilityHolds.length} reachability hold groups; '
      'inventory reconciled=${report.sourceInventoryReconciled}; '
      'closure remains held; ${report.sha256Digest})',
    );
    stdout.writeln(output.path);
    if (!report.compatibilityAccepted) exitCode = 1;
  } on Object catch (error, stackTrace) {
    stderr.writeln('Algorithm direct-edge probe failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
