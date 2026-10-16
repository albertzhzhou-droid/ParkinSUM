import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:timezone/src/tools.dart' show tzfileLocationToNativeLocation;
import 'package:timezone/src/tzdb.dart' show tzdbSerialize;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/tzdata.dart' as tzfile;

/// Build tool only; the codec is coupled to the locked timezone package.
void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError('Expected compiled TZIF directory and output asset.');
  }
  final directory = Directory(args[0]).absolute;
  final files = directory.listSync(recursive: true).whereType<File>().toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  final database = tz.LocationDatabase();
  final sourceHashes = <String, String>{};
  for (final file in files) {
    final zone = file.path.substring(directory.path.length + 1);
    final bytes = file.readAsBytesSync();
    sourceHashes[zone] = sha256.convert(bytes).toString();
    database.add(
      tzfileLocationToNativeLocation(tzfile.Location.fromBytes(zone, bytes)),
    );
  }
  final bytes = tzdbSerialize(database);
  final output = File(args[1]);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(bytes, flush: true);
  File('build/timezone_rules_compiler/codec_receipt.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'schema': 'parkinsum.timezone-codec-receipt/1', 'tzdb_release': '2026e', 'timezone_package': '0.11.1', 'zone_count': files.length, 'asset_bytes': bytes.length, 'asset_sha256': sha256.convert(bytes).toString(), 'compiled_tzif_sha256': sourceHashes, 'boundary': 'Actual compiled source identity; all-zone scientific/OS qualification is not inferred.'})}\n',
  );
}
