import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/core/analysis/catalog_search_index.dart';

void main(List<String> args) {
  if (args.isNotEmpty) {
    throw ArgumentError('This benchmark uses its fixed public plan.');
  }
  const directory = 'build/catalog_search_benchmark';
  Directory(directory).createSync(recursive: true);
  final output = File('$directory/latest.json');
  final sourcePaths = [
    'lib/core/analysis/catalog_search_index.dart',
    'tool/run_catalog_search_benchmark.dart',
  ];
  final sourceHashes = {
    for (final path in sourcePaths)
      path: sha256.convert(File(path).readAsBytesSync()).toString(),
  };
  final planBytes = File(
    'config/catalog_search_benchmark_plan.json',
  ).readAsBytesSync();
  final plan = jsonDecode(utf8.decode(planBytes)) as Map<String, dynamic>;
  final pairs = (plan['raw_canonical_pairs'] as List).cast<List>();
  final report = <String, dynamic>{
    'schema': 'parkinsum.catalog-search-benchmark/1',
    'phase': 'current_fixed_plan',
    'observed_at_utc': DateTime.now().toUtc().toIso8601String(),
    'dart_version': Platform.version,
    'platform': Platform.operatingSystem,
    'plan_sha256': sha256.convert(planBytes).toString(),
    'rows': <Map<String, dynamic>>[],
    'boundary': plan['measurement_scope'],
  };
  for (final size in (plan['sizes'] as List).cast<int>()) {
    final raw = <String>[];
    final canonical = <String>[];
    for (var i = 0; i < size; i++) {
      final pair = pairs[(i + (plan['seed'] as int)) % pairs.length];
      final marker = 'marker${(i % 97).toString().padLeft(3, '0')}';
      raw.add('${pair[0]} $marker id${i.toString().padLeft(6, '0')}');
      canonical.add('${pair[1]} $marker id${i.toString().padLeft(6, '0')}');
    }
    final beforeRss = ProcessInfo.currentRss;
    final buildWatch = Stopwatch()..start();
    final index = CatalogSearchIndex<int>(
      items: List<int>.generate(size, (i) => i),
      searchableText: (i) => raw[i],
    );
    buildWatch.stop();
    final afterRss = ProcessInfo.currentRss;
    final row = <String, dynamic>{
      'size': size,
      'raw_fixture_sha256': sha256
          .convert(utf8.encode(jsonEncode(raw)))
          .toString(),
      'canonical_fixture_sha256': sha256
          .convert(utf8.encode(jsonEncode(canonical)))
          .toString(),
      'construction_us': buildWatch.elapsedMicroseconds,
      'process_rss_before': beforeRss,
      'process_rss_after': afterRss,
      'queries': <Map<String, dynamic>>[],
    };
    for (final query in (plan['queries'] as List).cast<String>()) {
      for (final rawLimit in plan['limits'] as List) {
        final limit = rawLimit as int?;
        List<int> reference() {
          final found = <int>[];
          for (var i = 0; i < canonical.length; i++) {
            if (canonical[i].contains(query.toLowerCase())) {
              found.add(i);
              if (limit != null && found.length >= limit) break;
            }
          }
          return found;
        }

        final expected = reference();
        final actual = index.search(query, limit: limit);
        final exact = jsonEncode(actual) == jsonEncode(expected);
        final indexTimes = <int>[];
        final linearTimes = <int>[];
        final indexWarmups = <int>[];
        final linearWarmups = <int>[];
        for (
          var iteration = 0;
          iteration <
              (plan['warmups'] as int) + (plan['measured_repeats'] as int);
          iteration++
        ) {
          final watch = Stopwatch()..start();
          final observed = index.search(query, limit: limit);
          watch.stop();
          final linearWatch = Stopwatch()..start();
          final linear = reference();
          linearWatch.stop();
          if (jsonEncode(observed) != jsonEncode(actual) ||
              jsonEncode(linear) != jsonEncode(expected)) {
            throw StateError('Nondeterministic search');
          }
          if (iteration >= (plan['warmups'] as int)) {
            indexTimes.add(watch.elapsedMicroseconds);
            linearTimes.add(linearWatch.elapsedMicroseconds);
          } else {
            indexWarmups.add(watch.elapsedMicroseconds);
            linearWarmups.add(linearWatch.elapsedMicroseconds);
          }
        }
        (row['queries'] as List).add({
          'query': query,
          'limit': limit,
          'matches_independent': exact,
          'expected_count': expected.length,
          'actual_count': actual.length,
          'expected_ids_sha256': sha256
              .convert(utf8.encode(jsonEncode(expected)))
              .toString(),
          'actual_ids_sha256': sha256
              .convert(utf8.encode(jsonEncode(actual)))
              .toString(),
          'index_samples_us': indexTimes,
          'linear_samples_us': linearTimes,
          'index_warmup_samples_us': indexWarmups,
          'linear_warmup_samples_us': linearWarmups,
        });
      }
    }
    (report['rows'] as List).add(row);
    stdout.writeln('Completed measured size=$size phase=current_fixed_plan');
  }
  for (final path in sourcePaths) {
    if (sha256.convert(File(path).readAsBytesSync()).toString() !=
        sourceHashes[path]) {
      throw StateError('Benchmark source changed during measurement.');
    }
  }
  report['source_file_sha256'] = sourceHashes;
  report['pass'] = (report['rows'] as List).every(
    (dynamic row) => (row['queries'] as List).every(
      (dynamic q) => q['matches_independent'] == true,
    ),
  );
  if (report['pass'] != true) exitCode = 1;
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(output.path);
}
