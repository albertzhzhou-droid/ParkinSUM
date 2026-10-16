import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'intake.dart';
import 'meal.dart';
import 'user_profile.dart';

String portableRestoreCanonicalJson(Object? value) {
  Object? canonical(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: canonical(item[key]),
      };
    }
    if (item is List) return item.map(canonical).toList(growable: false);
    return item;
  }

  return jsonEncode(canonical(value));
}

String portableRestoreDigest(Object? value) =>
    sha256.convert(utf8.encode(portableRestoreCanonicalJson(value))).toString();

String portableRestoreBytesDigest(String value) =>
    sha256.convert(utf8.encode(value)).toString();

/// Complete local user-state witness; the last restore receipt is metadata,
/// excluded to avoid making its own after-digest recursively depend on itself.
class PortableDataRestoreState {
  PortableDataRestoreState(Map<String, Object?> state)
    : canonicalJson = portableRestoreCanonicalJson(
        Map<String, Object?>.from(state)..remove('portableRestoreReceipt'),
      );

  final String canonicalJson;
  Map<String, Object?> get json =>
      Map<String, Object?>.from(jsonDecode(canonicalJson) as Map);
  // The snapshot already owns canonical bytes. Re-decoding and sorting them
  // again adds a full-state allocation without changing the witness.
  late final String digest = portableRestoreBytesDigest(canonicalJson);
  UserProfile get profile =>
      UserProfile.fromJson(Map<String, dynamic>.from(json['profile'] as Map));
  Map<String, Set<String>> get recordIds {
    final state = json;
    return <String, Set<String>>{
      'medication_selections.json': <String>{
        ...(state['activeDrugIds'] as List).cast<String>(),
        for (final row in state['intakes'] as List)
          (row as Map)['drugId'] as String,
      },
      'intakes.json': {
        for (final row in state['intakes'] as List)
          (row as Map)['id'] as String,
        for (final row in state['eventHistory'] as List)
          if ((row as Map)['event_type'] == 'intake')
            row['record_id'] as String,
      },
      'meals.json': {
        for (final row in state['meals'] as List) (row as Map)['id'] as String,
        for (final row in state['eventHistory'] as List)
          if ((row as Map)['event_type'] == 'meal') row['record_id'] as String,
      },
    };
  }
}

class PortableDataRestorePayload {
  PortableDataRestorePayload({
    required UserProfile profile,
    required Iterable<String> activeDrugIds,
    required Iterable<Intake> intakes,
    required Iterable<Meal> meals,
  }) : canonicalJson = portableRestoreCanonicalJson({
         'profile': profile.toJson(),
         'activeDrugIds': activeDrugIds.toList(),
         'intakes': intakes.map((item) => item.toJson()).toList(),
         'meals': meals.map((item) => item.toJson()).toList(),
       });

  final String canonicalJson;
  Map<String, Object?> get json =>
      Map<String, Object?>.from(jsonDecode(canonicalJson) as Map);
}

class PortableDataRestoreRequest {
  PortableDataRestoreRequest({
    required this.ownerScope,
    required this.sourcePackageJson,
    required this.packageJsonSha256,
    required this.expectedStateDigest,
    required this.payload,
  }) : operationId = portableRestoreDigest({
         'owner': ownerScope,
         'package': packageJsonSha256,
         'before': expectedStateDigest,
         'payload': payload.json,
       });

  final String ownerScope;
  final String sourcePackageJson;
  final String packageJsonSha256;
  final String expectedStateDigest;
  final PortableDataRestorePayload payload;
  final String operationId;
}

class PortableDataRestoreReceipt {
  PortableDataRestoreReceipt(Map<String, Object?> value)
    : canonicalJson = portableRestoreCanonicalJson(value);
  final String canonicalJson;
  Map<String, Object?> get json =>
      Map<String, Object?>.from(jsonDecode(canonicalJson) as Map);
  String get operationId => json['operationId'] as String;
  String get beforeDigest => json['beforeDigest'] as String;
  String get afterDigest => json['afterDigest'] as String;
}
