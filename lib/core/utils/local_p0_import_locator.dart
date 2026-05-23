import 'local_p0_import_locator_stub.dart'
    if (dart.library.io) 'local_p0_import_locator_io.dart';

abstract class LocalP0ImportLocator {
  Future<ResolvedP0ImportSelection> resolve({
    String? ciqualPath,
    String? fdcPath,
    String? dailyMedPath,
    String? dpdPath,
  });
}

class ResolvedP0ImportSelection {
  final List<int>? ciqualArchiveBytes;
  final List<int>? fdcZipBytes;
  final List<int>? dailyMedZipBytes;
  final List<int>? dpdZipBytes;
  final Map<String, String> resolvedPaths;

  const ResolvedP0ImportSelection({
    this.ciqualArchiveBytes,
    this.fdcZipBytes,
    this.dailyMedZipBytes,
    this.dpdZipBytes,
    this.resolvedPaths = const <String, String>{},
  });

  bool get isEmpty =>
      ciqualArchiveBytes == null &&
      fdcZipBytes == null &&
      dailyMedZipBytes == null &&
      dpdZipBytes == null;
}

LocalP0ImportLocator createLocalP0ImportLocator() =>
    createLocalP0ImportLocatorImpl();
