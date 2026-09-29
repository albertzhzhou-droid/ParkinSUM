import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/source_reference_projection.dart';

SourceDocumentRecord _document(String id) => SourceDocumentRecord(
  sourceDocId: id,
  sourceFamily: 'TEST',
  organization: 'Test registry',
  jurisdiction: 'GLOBAL',
  docType: 'test_record',
  title: 'Title for $id',
  originUrl: 'https://example.org/$id',
  publishedAt: null,
  effectiveAt: null,
  language: 'en',
  licenseNote: 'Synthetic test metadata.',
  checksum: 'test_$id',
  sourceStatus: 'synthetic',
  rawPayload: '{}',
);

void main() {
  test(
    'resolves known references in input order and preserves unknown IDs',
    () {
      final first = _document('known-a');
      final second = _document('known-b');

      final result = SourceReferenceProjection.resolve(
        sourceRefs: const ['known-b', 'unknown-source', 'known-a'],
        sourceDocuments: [first, second],
      );

      expect(result.map((item) => item.sourceRef), [
        'known-b',
        'unknown-source',
        'known-a',
      ]);
      expect(result.map((item) => item.document), [second, null, first]);
      expect(result.map((item) => item.isResolved), [true, false, true]);
    },
  );

  test('preserves repeated references and returns an immutable projection', () {
    final document = _document('known');

    final result = SourceReferenceProjection.resolve(
      sourceRefs: const ['known', 'known'],
      sourceDocuments: [document, _document('known')],
    );

    expect(result, hasLength(2));
    expect(result[0].document, same(document));
    expect(result[1].document, same(document));
    expect(
      () => result.add(
        const SourceReferenceResolution(sourceRef: 'later', document: null),
      ),
      throwsUnsupportedError,
    );
  });

  test('returns an empty immutable projection for no references', () {
    final result = SourceReferenceProjection.resolve(
      sourceRefs: const [],
      sourceDocuments: [_document('unused')],
    );

    expect(result, isEmpty);
    expect(
      () => result.add(
        const SourceReferenceResolution(sourceRef: 'later', document: null),
      ),
      throwsUnsupportedError,
    );
  });
}
