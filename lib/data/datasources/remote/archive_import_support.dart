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

  static const defaultLimits = ArchiveImportLimits();

  static void validateCompressedInputLength(
    int length, {
    ArchiveImportLimits limits = defaultLimits,
  }) {
    if (length > limits.maxCompressedArchiveBytes) {
      throw FormatException(
        'Archive exceeds compressed-size limit '
        '(${limits.maxCompressedArchiveBytes} bytes).',
      );
    }
  }

  static Map<String, List<int>> unzipFiles(
    List<int> zipBytes, {
    ArchiveImportLimits limits = defaultLimits,
  }) {
    validateCompressedInputLength(zipBytes.length, limits: limits);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final archiveFiles = archive.files.where((item) => item.isFile).toList();
    if (archiveFiles.length > limits.maxFileCount) {
      throw FormatException(
        'Archive exceeds file-count limit (${limits.maxFileCount}).',
      );
    }
    final files = <String, List<int>>{};
    var totalExpandedBytes = 0;
    for (final item in archiveFiles) {
      final name = _validatedEntryName(item.name);
      if (item.isSymbolicLink) {
        throw FormatException(
          'Archive symbolic links are not supported: $name',
        );
      }
      if (files.containsKey(name)) {
        throw FormatException('Archive contains duplicate file name: $name');
      }
      if (item.size > limits.maxEntryUncompressedBytes) {
        throw FormatException(
          'Archive entry exceeds expanded-size limit: $name.',
        );
      }
      totalExpandedBytes += item.size;
      if (totalExpandedBytes > limits.maxTotalUncompressedBytes) {
        throw FormatException(
          'Archive exceeds total expanded-size limit '
          '(${limits.maxTotalUncompressedBytes} bytes).',
        );
      }
      files[name] = item.content is List<int>
          ? List<int>.from(item.content as List<int>)
          : utf8.encode('${item.content}');
    }
    return files;
  }

  static Map<String, String> unzipTextFiles(
    List<int> zipBytes, {
    ArchiveImportLimits limits = defaultLimits,
  }) {
    final files = unzipFiles(zipBytes, limits: limits);
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
    ).convert(normalized, fieldDelimiter: effectiveDelimiter);
    if (rows.isEmpty) return const <Map<String, String>>[];
    final headers = rows.first
        .map((cell) => '${cell ?? ''}'.trim())
        .toList(growable: false);
    return rows
        .skip(1)
        .map((row) {
          final map = <String, String>{};
          for (
            var index = 0;
            index < headers.length && index < row.length;
            index++
          ) {
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

  static String _validatedEntryName(String rawName) {
    final name = rawName.replaceAll('\\', '/');
    final segments = name.split('/');
    if (name.isEmpty ||
        name.startsWith('/') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(name) ||
        segments.any((segment) => segment == '..')) {
      throw FormatException('Archive contains unsafe file name: $rawName');
    }
    return name;
  }
}

class ArchiveImportLimits {
  final int maxCompressedArchiveBytes;
  final int maxFileCount;
  final int maxEntryUncompressedBytes;
  final int maxTotalUncompressedBytes;

  const ArchiveImportLimits({
    this.maxCompressedArchiveBytes = 16 * 1024 * 1024,
    this.maxFileCount = 128,
    this.maxEntryUncompressedBytes = 16 * 1024 * 1024,
    this.maxTotalUncompressedBytes = 64 * 1024 * 1024,
  });
}
