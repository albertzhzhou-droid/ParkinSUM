import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

typedef CdssClock = DateTime Function();

/// Creates privacy-preserving identifiers for CDSS persistence artifacts.
///
/// Identity and idempotency are deliberately separate:
/// - [newId] returns an unpredictable Firestore-safe primary key;
/// - [inputDigest] returns a domain-separated digest of canonical JSON.
///
/// Neither method places raw or reversibly encoded patient context in an ID.
class CdssIdentifierFactory {
  static final RegExp _safePrefix = RegExp(r'^[A-Za-z][A-Za-z0-9._:-]*$');

  final Random _random;
  final CdssClock _clock;

  CdssIdentifierFactory({Random? random, CdssClock? clock})
    : _random = random ?? Random.secure(),
      _clock = clock ?? DateTime.now;

  String newId(String prefix) {
    if (!_safePrefix.hasMatch(prefix)) {
      throw ArgumentError.value(prefix, 'prefix', 'must be Firestore-safe');
    }
    final entropy = List<int>.generate(16, (_) => _random.nextInt(256));
    final randomHex = entropy
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${prefix}_${_clock().toUtc().microsecondsSinceEpoch}_$randomHex';
  }

  String inputDigest(String domain, Object? payload) {
    if (domain.trim().isEmpty) {
      throw ArgumentError.value(domain, 'domain', 'must not be empty');
    }
    final envelope = <String, Object?>{
      'domain': domain,
      'version': 1,
      'payload': _canonicalize(payload),
    };
    return sha256.convert(utf8.encode(jsonEncode(envelope))).toString();
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted['${entry.key}'] = _canonicalize(entry.value);
      }
      return sorted;
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw ArgumentError.value(
      value,
      'payload',
      'must contain only JSON-compatible values',
    );
  }
}
