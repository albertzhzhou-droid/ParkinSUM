import 'dart:io';

import 'candidate_serving_reference_doc.dart';

/// Regenerates `docs/CANDIDATE_SERVING_REFERENCE.md`.
///
/// Usage: `dart run tool/generate_candidate_serving_reference_doc.dart`
void main() {
  File(
    candidateServingReferenceDocPath,
  ).writeAsStringSync(buildCandidateServingReferenceDoc());
  stdout.writeln('Wrote $candidateServingReferenceDocPath');
}
