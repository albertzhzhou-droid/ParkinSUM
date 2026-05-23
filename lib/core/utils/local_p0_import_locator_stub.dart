import 'local_p0_import_locator.dart';

class _StubLocalP0ImportLocator implements LocalP0ImportLocator {
  @override
  Future<ResolvedP0ImportSelection> resolve({
    String? ciqualPath,
    String? fdcPath,
    String? dailyMedPath,
    String? dpdPath,
  }) async {
    throw UnsupportedError(
      'Local filesystem batch import is not available on this platform.',
    );
  }
}

LocalP0ImportLocator createLocalP0ImportLocatorImpl() =>
    _StubLocalP0ImportLocator();
