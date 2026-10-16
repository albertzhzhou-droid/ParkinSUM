import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'food_source_sensitivity_study.dart';

void main() {
  const fixture = 'test/fixtures/food_research';
  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final domain = read('$fixture/joint_source_domain.json');
  final source = File('$fixture/six_original_foundation_foods.json');
  if (sha256.convert(source.readAsBytesSync()).toString() !=
      domain['subset_raw_sha256']) {
    throw StateError('source-content-mismatch');
  }
  final joint = jointSourceStudy(domain, read(source.path));
  final heuristic = fixedHeuristicStudy(read('$fixture/heuristic_domain.json'));
  final fingerprints = {
    for (final p in [
      'tool/food_source_sensitivity_study.dart',
      'lib/data/datasources/remote/fdc_p0_importer.dart',
      'lib/domain/usecases/mechanistic_next_meal_scorer.dart',
      'lib/domain/usecases/get_food_recommendations_usecase.dart',
    ])
      p: sha256.convert(File(p).readAsBytesSync()).toString(),
  };
  final output = Directory('build/food_source_sensitivity')
    ..createSync(recursive: true);
  File('${output.path}/actual_vectors.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'schema': 'parkinsum.food-source-sensitivity-vectors/1', 'joint': joint, 'heuristic': heuristic, 'producer_source_file_sha256': fingerprints})}\n',
  );
  stdout.writeln(
    jsonEncode({
      'joint_scenarios': (joint['scenarios'] as List).length,
      'heuristic_cases': (heuristic['cases'] as List).length,
    }),
  );
}
