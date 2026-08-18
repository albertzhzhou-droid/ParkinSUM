class PortableDataExportResult {
  const PortableDataExportResult({
    required this.delivery,
    required this.location,
    required this.userVisible,
  });

  final String delivery;
  final String? location;
  final bool userVisible;
}

class PortableDataExportException implements Exception {
  const PortableDataExportException({required this.residualFilePossible});

  final bool residualFilePossible;
}

class PortableDataExportSink {
  const PortableDataExportSink();

  Future<PortableDataExportResult> save({
    required String fileName,
    required String contents,
    required bool Function() authorize,
  }) async => const PortableDataExportResult(
    delivery: 'unsupported',
    location: null,
    userVisible: false,
  );
}
