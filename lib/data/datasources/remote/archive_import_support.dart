import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

/// 批量导入辅助：
/// - 统一解 ZIP；
/// - 统一把 txt/csv/tsv/pipe-delimited 文件转成行映射。
///
/// 说明：
/// - 这里追求“可重复 ETL 的实用兼容性”，不是通用压缩包框架；
/// - 对未知列名保持宽松解析，尽量不因上游列顺序变化而整体失败。
class ArchiveImportSupport {
  const ArchiveImportSupport._();

  static Map<String, List<int>> unzipFiles(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final files = <String, List<int>>{};
    for (final item in archive.files) {
      if (!item.isFile) continue;
      files[item.name] = item.content is List<int>
          ? List<int>.from(item.content as List<int>)
          : utf8.encode('${item.content}');
    }
    return files;
  }

  static Map<String, String> unzipTextFiles(List<int> zipBytes) {
    final files = unzipFiles(zipBytes);
    return {
      for (final entry in files.entries) entry.key: utf8.decode(entry.value),
    };
  }

  static List<Map<String, String>> parseDelimitedRows(
    String text, {
    String? delimiter,
  }) {
    final normalized = text.trim();
    if (normalized.isEmpty) return const <Map<String, String>>[];
    final lines = const LineSplitter().convert(normalized);
    if (lines.isEmpty) return const <Map<String, String>>[];
    final firstLine = lines.first;
    final effectiveDelimiter = delimiter ?? _detectDelimiter(firstLine) ?? ',';
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(
      normalized,
      fieldDelimiter: effectiveDelimiter,
    );
    if (rows.isEmpty) return const <Map<String, String>>[];
    final headers = rows.first
        .map((cell) => '${cell ?? ''}'.trim())
        .toList(growable: false);
    return rows
        .skip(1)
        .map((row) {
          final map = <String, String>{};
          for (var index = 0;
              index < headers.length && index < row.length;
              index++) {
            final header = headers[index];
            if (header.isEmpty) continue;
            map[header] = '${row[index] ?? ''}'.trim();
          }
          return map;
        })
        .where((row) => row.isNotEmpty)
        .toList(growable: false);
  }

  static String? _detectDelimiter(String line) {
    if (line.contains('|')) return '|';
    if (line.contains('\t')) return '\t';
    if (line.contains(';')) return ';';
    if (line.contains(',')) return ',';
    return null;
  }
}
