import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:parkinsum_companion/domain/entities/mechanistic_replay_capsule.dart';

void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError('Expected declared input file and actual output file.');
  }
  final inputBytes = File(args[0]).readAsBytesSync();
  final input = jsonDecode(utf8.decode(inputBytes)) as Map<String, dynamic>;
  if (input['schema'] != 'parkinsum.replay-capsule-fuzz-inputs/1') {
    throw const FormatException('Unsupported fuzz input schema.');
  }
  final cases = input['cases'] as List<dynamic>;
  if (cases.length > 72) {
    throw const FormatException('Campaign budget exceeded.');
  }
  final observations = <Map<String, Object?>>[];
  for (final rawCase in cases) {
    final item = rawCase as Map<String, dynamic>;
    final raw = item['raw_json'] as String;
    final rawSha = sha256.convert(utf8.encode(raw)).toString();
    if (rawSha != item['raw_sha256']) {
      throw const FormatException('Raw input identity mismatch.');
    }
    try {
      final capsule = MechanisticReplayCapsule.fromJsonString(raw);
      observations.add(<String, Object?>{
        'id': item['id'],
        'raw_sha256': rawSha,
        'accepted': true,
        'canonical_sha256': sha256
            .convert(utf8.encode(capsule.canonicalJson))
            .toString(),
        'capsule_sha256': capsule.capsuleSha256,
      });
    } on Object catch (error) {
      observations.add(<String, Object?>{
        'id': item['id'],
        'raw_sha256': rawSha,
        'accepted': false,
        'reason': error.toString(),
      });
    }
  }
  final output = <String, Object?>{
    'schema': 'parkinsum.replay-capsule-fuzz-dart-vectors/1',
    'input_raw_sha256': sha256.convert(inputBytes).toString(),
    'producer_source_sha256': sha256
        .convert(
          File(
            'lib/domain/entities/mechanistic_replay_capsule.dart',
          ).readAsBytesSync(),
        )
        .toString(),
    'cases': observations,
    'scope': 'Raw envelope acceptance only; typed restoration is not executed.',
  };
  File(args[1])
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    );
}
