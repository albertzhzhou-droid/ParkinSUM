// Compiles + validates every SafeCopyTemplate in the registry with deterministic
// sample bindings, writing a report under build/explanation_copy/.
//
// Usage:
//   dart run tool/run_explanation_copy_compile.dart
//
// Educational/research prototype. Deterministic copy compilation + validation
// only. It adds no medical advice, no dose/timing/diet guidance, and no
// clinical-calibration claim, and it is NOT wired into the UI or scoring. No
// network. Exits non-zero iff a BLOCKER finding exists.

import 'dart:io';

import 'package:parkinsum_companion/domain/entities/explanation_copy.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

void main() {
  const registry = SafeCopyTemplateRegistry();
  const compiler = ExplanationCopyCompiler();

  // Deterministic sample bindings (only where a template declares placeholders).
  const bindings = <String, Map<String, String>>{
    'mechanistic_explanation_boundary': {'overlap_percent': '42'},
  };

  // Every template is compiled with a sample context that supplies the
  // structural requirements (sourceRefs / limitation / not-advice) it declares.
  const sampleContext = CopyCompileContext(
    sourceRefs: ['src.demo'],
    hasLimitationText: true,
    hasNotAdviceText: true,
  );
  final contexts = <String, CopyCompileContext>{
    for (final t in registry.templates) t.templateId: sampleContext,
  };

  final report = compiler.compileAll(
    registry,
    bindingsByTemplate: bindings,
    contextByTemplate: contexts,
  );

  final outDir = Directory('build/explanation_copy');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeCopyCompileReport(report));
  File('${outDir.path}/latest.md')
      .writeAsStringSync(renderCopyCompileMarkdown(report));

  stdout
    ..writeln('Explanation copy compile: ${report.compiledCount}/'
        '${report.templateCount} templates compiled — '
        'info=${report.counts['info'] ?? 0} '
        'warn=${report.counts['warn'] ?? 0} '
        'blocker=${report.blockerCount} (pass=${report.pass}).')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  if (!report.pass) {
    stderr.writeln('BLOCKER findings:');
    for (final f in report.findings
        .where((x) => x.severity == CopyCompileSeverity.blocker)) {
      stderr.writeln('  - ${f.findingType} @ ${f.templateId} (${f.message})');
    }
  }
  exitCode = report.pass ? 0 : 1;
}
