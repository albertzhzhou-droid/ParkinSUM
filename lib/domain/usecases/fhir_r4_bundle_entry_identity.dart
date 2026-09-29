import 'dart:math';

/// Creates a fresh UUID identity for one entry in a local FHIR collection.
///
/// The value is deliberately independent of the source record ID, so a
/// portable Bundle does not expose a stable local identifier.
String newFhirBundleEntryFullUrl(Set<String> usedFullUrls) {
  final random = Random.secure();
  while (true) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final uuid =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    final fullUrl = 'urn:uuid:$uuid';
    if (usedFullUrls.add(fullUrl)) return fullUrl;
  }
}
