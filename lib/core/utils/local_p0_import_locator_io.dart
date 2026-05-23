import 'dart:io';

import 'package:archive/archive.dart';

import 'local_p0_import_locator.dart';

class _IoLocalP0ImportLocator implements LocalP0ImportLocator {
  @override
  Future<ResolvedP0ImportSelection> resolve({
    String? ciqualPath,
    String? fdcPath,
    String? dailyMedPath,
    String? dpdPath,
  }) async {
    final resolvedPaths = <String, String>{};
    final ciqualBytes = await _resolveCiqual(ciqualPath, resolvedPaths);
    final fdcBytes = await _resolveZipLike(
      fdcPath,
      resolvedPaths,
      key: 'fdc',
      patterns: const ['foundation', 'fdc', 'fooddata_central'],
    );
    final dailyMedBytes = await _resolveZipLike(
      dailyMedPath,
      resolvedPaths,
      key: 'dailymed',
      patterns: const ['dm_spl', 'dailymed', 'human_rx'],
    );
    final dpdBytes = await _resolveZipLike(
      dpdPath,
      resolvedPaths,
      key: 'dpd',
      patterns: const ['allfiles', 'drug', 'dpd', 'package'],
    );
    return ResolvedP0ImportSelection(
      ciqualArchiveBytes: ciqualBytes,
      fdcZipBytes: fdcBytes,
      dailyMedZipBytes: dailyMedBytes,
      dpdZipBytes: dpdBytes,
      resolvedPaths: resolvedPaths,
    );
  }

  Future<List<int>?> _resolveCiqual(
    String? path,
    Map<String, String> resolvedPaths,
  ) async {
    if (path == null || path.trim().isEmpty) return null;
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.notFound) {
      throw FileSystemException('Ciqual path not found', path);
    }
    if (entity == FileSystemEntityType.file &&
        path.toLowerCase().endsWith('.zip')) {
      resolvedPaths['ciqual'] = path;
      return File(path).readAsBytes();
    }
    final directory = entity == FileSystemEntityType.directory
        ? Directory(path)
        : File(path).parent;
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.xml'))
        .toList(growable: false);
    final compo = _findFirst(files, const ['compo_']);
    final alim = _findFirst(files, const ['alim_']);
    final alimGrp = _findFirst(files, const ['alim_grp']);
    final constFile = _findFirst(files, const ['const_']);
    final sources = _findFirst(files, const ['sources_']);
    final requiredFiles = [compo, alim, alimGrp, constFile, sources];
    if (requiredFiles.any((file) => file == null)) {
      throw FileSystemException(
        'Ciqual directory must contain compo/alim/alim_grp/const/sources XML files',
        directory.path,
      );
    }
    final archive = Archive();
    for (final file in requiredFiles.cast<File>()) {
      final bytes = await file.readAsBytes();
      archive.addFile(
          ArchiveFile(file.uri.pathSegments.last, bytes.length, bytes));
    }
    resolvedPaths['ciqual'] = directory.path;
    return ZipEncoder().encode(archive);
  }

  Future<List<int>?> _resolveZipLike(
    String? path,
    Map<String, String> resolvedPaths, {
    required String key,
    required List<String> patterns,
  }) async {
    if (path == null || path.trim().isEmpty) return null;
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.notFound) {
      throw FileSystemException('$key path not found', path);
    }
    if (entity == FileSystemEntityType.file) {
      resolvedPaths[key] = path;
      return File(path).readAsBytes();
    }
    final directory = Directory(path);
    final candidate = _findFirst(
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.zip'))
          .toList(growable: false),
      patterns,
    );
    if (candidate == null) {
      throw FileSystemException(
        'No matching ZIP file found for $key in directory',
        directory.path,
      );
    }
    resolvedPaths[key] = candidate.path;
    return candidate.readAsBytes();
  }

  File? _findFirst(List<File> files, List<String> patterns) {
    for (final file in files) {
      final lower = file.uri.pathSegments.last.toLowerCase();
      if (patterns.any(lower.contains)) return file;
    }
    return null;
  }
}

LocalP0ImportLocator createLocalP0ImportLocatorImpl() =>
    _IoLocalP0ImportLocator();
