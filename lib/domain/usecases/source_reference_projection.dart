import '../entities/cdss_records.dart';

/// One source reference resolved against records already available locally.
/// Unmatched IDs remain present so provenance is never silently discarded.
final class SourceReferenceResolution {
  const SourceReferenceResolution({
    required this.sourceRef,
    required this.document,
  });

  final String sourceRef;
  final SourceDocumentRecord? document;

  bool get isResolved => document != null;
}

/// Projects persisted source IDs into a stable, read-only local registry view.
/// This performs no lookup, fetch, ranking, or evidence-validity assessment.
final class SourceReferenceProjection {
  const SourceReferenceProjection._();

  static List<SourceReferenceResolution> resolve({
    required Iterable<String> sourceRefs,
    required Iterable<SourceDocumentRecord> sourceDocuments,
  }) {
    final documentsById = <String, SourceDocumentRecord>{};
    for (final document in sourceDocuments) {
      documentsById.putIfAbsent(document.sourceDocId, () => document);
    }
    return List<SourceReferenceResolution>.unmodifiable(
      sourceRefs.map(
        (sourceRef) => SourceReferenceResolution(
          sourceRef: sourceRef,
          document: documentsById[sourceRef],
        ),
      ),
    );
  }
}
