// Code generator for lib/core/constants/rxnorm_reference_table.dart.
//
// Input (committed):
// - tool/data/rxnorm_2024-12-02/RXNCONSO_parkinson_reference_subset.RRF:
//   complete concept blocks copied byte-for-byte from the NLM RxNorm release
//   of 2 December 2024 (Current Prescribable Content, RXNCONSO.RRF), read
//   through the Hugging Face mirror OnDeviceMedNotes/nih-rxnorm-dec-2-2024.
//
// The generator never edits a field. test/rxnorm_reference_table_test.dart
// re-parses the input and fails if any generated field differs.

const rxnormSubsetPath =
    'tool/data/rxnorm_2024-12-02/RXNCONSO_parkinson_reference_subset.RRF';
const rxnormTableDartPath = 'lib/core/constants/rxnorm_reference_table.dart';

/// RXNCONSO.RRF has 18 pipe-terminated columns.
const int rxnconsoColumnCount = 18;

class RxnconsoLine {
  final int rxcui;
  final int rxaui;
  final String sab;
  final String tty;
  final String code;
  final String str;

  const RxnconsoLine({
    required this.rxcui,
    required this.rxaui,
    required this.sab,
    required this.tty,
    required this.code,
    required this.str,
  });
}

/// Parses RXNCONSO.RRF text. Columns: RXCUI|LAT|TS|LUI|STT|SUI|ISPREF|RXAUI|
/// SAUI|SCUI|SDUI|SAB|TTY|CODE|STR|SRL|SUPPRESS|CVF|
List<RxnconsoLine> parseRxnconso(String text) {
  final rows = <RxnconsoLine>[];
  for (final line in text.split('\n')) {
    if (line.isEmpty) continue;
    final cells = line.split('|');
    if (cells.length != rxnconsoColumnCount + 1 || cells.last.isNotEmpty) {
      throw FormatException('Not an RXNCONSO.RRF line: $line');
    }
    rows.add(
      RxnconsoLine(
        rxcui: int.parse(cells[0]),
        rxaui: int.parse(cells[7]),
        sab: cells[11],
        tty: cells[12],
        code: cells[13],
        str: cells[14],
      ),
    );
  }
  return rows;
}

String _dartString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String renderRxnormTable(String rrfText) {
  final rows = parseRxnconso(rrfText);
  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE - DO NOT EDIT BY HAND.')
    ..writeln('// Source: $rxnormSubsetPath')
    ..writeln(
      '// Regenerate: dart run tool/generate_rxnorm_reference_table.dart',
    )
    ..writeln()
    ..writeln("import '../../domain/entities/rxnorm_reference.dart';")
    ..writeln()
    ..writeln('/// RxNorm release the rows were copied from.')
    ..writeln(
      "const String rxnormReferenceRelease = "
      "'RxNorm 2024-12-02, Current Prescribable Content (NLM)';",
    )
    ..writeln()
    ..writeln('const List<RxNormConceptRow> rxnormReferenceRows = [');
  for (final row in rows) {
    buffer
      ..writeln('  RxNormConceptRow(')
      ..writeln('    rxcui: ${row.rxcui},')
      ..writeln('    rxaui: ${row.rxaui},')
      ..writeln('    sab: ${_dartString(row.sab)},')
      ..writeln('    tty: ${_dartString(row.tty)},')
      ..writeln('    code: ${_dartString(row.code)},')
      ..writeln('    str: ${_dartString(row.str)},')
      ..writeln('  ),');
  }
  buffer.writeln('];');
  return buffer.toString();
}
