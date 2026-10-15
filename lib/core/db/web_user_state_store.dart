import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Only these original personal-record keys participate in migration. Catalogue,
/// account, Care, drafts and unrelated origin data keep their existing stores.
const webUserStateLegacyKeys = <String>[
  'db.active_drugs',
  'db.intakes',
  'db.meals',
  'db.meta.onboarded',
  'db.user_profile',
  'db.user_state.v1',
];

final class WebUserStateLegacySnapshot {
  WebUserStateLegacySnapshot(Map<String, String?> values)
    : values = Map<String, String?>.unmodifiable(values) {
    if (values.length != webUserStateLegacyKeys.length ||
        !webUserStateLegacyKeys.every(values.containsKey)) {
      throw ArgumentError('Invalid personal-record migration key set.');
    }
  }

  final Map<String, String?> values;
  String get canonicalJson =>
      jsonEncode({for (final key in webUserStateLegacyKeys) key: values[key]});
  String get digest => sha256.convert(utf8.encode(canonicalJson)).toString();
}

/// The caller holds the existing user_state.v1 Web Lock for the complete
/// read/validate/write operation. No implementation may fall back after a
/// persistence failure or mirror an enlarged document into localStorage.
abstract interface class WebUserStateStore {
  String get backendId;

  /// A first read may preserve the exact legacy aggregate and migration witness
  /// atomically. Later reads refuse legacy writes instead of choosing a winner.
  Future<String?> read(WebUserStateLegacySnapshot legacy);

  /// Completion means that the transaction completed and the complete value
  /// was read back. An expired authorization may leave an already committed
  /// original-owner value, but must not be reported as a successful session.
  Future<void> write(
    String document, {
    required String? expectedDocument,
    required WebUserStateLegacySnapshot legacy,
    required bool Function() authorize,
  });
}
