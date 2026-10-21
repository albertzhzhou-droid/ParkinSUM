import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/candidate_serving_reference_doc.dart';

/// The published per-food serving table must describe what the production
/// resolver actually returns. Regenerate with
/// `dart run tool/generate_candidate_serving_reference_doc.dart`.
void main() {
  test('docs/CANDIDATE_SERVING_REFERENCE.md matches the resolver', () {
    final file = File(candidateServingReferenceDocPath);
    expect(file.existsSync(), isTrue);
    expect(
      file.readAsStringSync(),
      buildCandidateServingReferenceDoc(),
      reason:
          'The serving table is stale. Run '
          'dart run tool/generate_candidate_serving_reference_doc.dart.',
    );
  });
}
