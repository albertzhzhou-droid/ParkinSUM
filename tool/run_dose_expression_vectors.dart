import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/dose_expression.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length > 1) {
    stderr.writeln('Expected at most one fixture path or --stdin.');
    exitCode = 64;
    return;
  }
  final fixtureContent = arguments.length == 1 && arguments.single == '--stdin'
      ? await stdin.transform(utf8.decoder).join()
      : File(
          arguments.isEmpty
              ? 'test/fixtures/dose_expression_vectors.json'
              : arguments.single,
        ).readAsStringSync();
  final fixture = jsonDecode(fixtureContent) as Map<String, dynamic>;
  final parser = DosageNoteParser();
  final cases = (fixture['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  final results = <Map<String, Object?>>[
    for (final vector in cases)
      _projection(
        vector['id'] as String,
        parser.inspect(vector['input'] as String),
      ),
  ];
  stdout.write(
    jsonEncode(<String, Object?>{
      'schema': 'parkinsum.dose-expression-runtime-results/2',
      'grammar_id': DosageNoteParser.grammarId,
      'grammar_version': DosageNoteParser.grammarVersion,
      'grammar_digest': DosageNoteParser.grammarDigest,
      'local_unit_system': DosageNoteParser.localUnitSystem,
      'local_unit_version': DosageNoteParser.localUnitVersion,
      'results': results,
    }),
  );
}

Map<String, Object?> _projection(String id, DoseExpressionParseResult result) {
  final expression = result.expression;
  final mapping = expression?.unit.mappingEvidence;
  return <String, Object?>{
    'id': id,
    'status': result.status.name,
    'reason': result.primaryReasonCode,
    'value': expression?.value,
    'unit': expression?.unit.code,
    'dimension': expression?.unit.dimension.name,
    'diagnostic': _diagnosticProjection(result.diagnosticStructure),
    'mapping': mapping == null
        ? null
        : <String, Object?>{
            'sourceCode': mapping.sourceCode,
            'sourceDisplay': mapping.sourceDisplay,
            'canonicalCode': mapping.canonicalCode,
            'baseUnitCode': mapping.baseUnitCode,
            'mappingType': mapping.mappingType.name,
            'conversionNumerator': mapping.conversionNumerator,
            'conversionDenominator': mapping.conversionDenominator,
            'sourceDimension': mapping.sourceDimension.name,
            'targetDimension': mapping.targetDimension.name,
          },
  };
}

Map<String, Object?>? _diagnosticProjection(
  DoseExpressionDiagnosticStructure? structure,
) {
  if (structure == null) return null;
  return <String, Object?>{
    'kind': structure.kind.name,
    'comparator': structure.comparator?.symbol,
    'quantity': _diagnosticQuantityProjection(structure.quantity),
    'lowerBound': _diagnosticQuantityProjection(structure.lowerBound),
    'upperBound': _diagnosticQuantityProjection(structure.upperBound),
    'sourceSpan': <String, int>{
      'start': structure.sourceStart,
      'end': structure.sourceEnd,
    },
    'displayText': structure.displayText,
    'resultEligible': false,
  };
}

Map<String, Object?>? _diagnosticQuantityProjection(
  DoseExpressionDiagnosticQuantity? quantity,
) {
  if (quantity == null) return null;
  return <String, Object?>{
    'lexicalValue': quantity.lexicalValue,
    'value': quantity.value,
    'valueSpan': <String, int>{
      'start': quantity.valueStart,
      'end': quantity.valueEnd,
    },
    'unitSpan': <String, int>{
      'start': quantity.unitStart,
      'end': quantity.unitEnd,
    },
    'unit': <String, Object?>{
      'display': quantity.unit.display,
      'system': quantity.unit.system,
      'code': quantity.unit.code,
      'version': quantity.unit.version,
      'dimension': quantity.unit.dimension.name,
      'mappingEvidence': quantity.unit.mappingEvidence.toJson(),
    },
  };
}
