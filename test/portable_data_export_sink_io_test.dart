import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/portable_data_export_sink_io.dart';
import 'package:path/path.dart' as p;

void main() {
  const fileName = 'parkinsum-user-data-20260817-150000-test.parkinsum.json';
  const contents = '{"private":"portable"}';

  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('portable-sink-test-');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('missing target fails closed without creating any file', () async {
    final sink = PortableDataExportSink(downloadsDirectory: directory);

    final result = await sink.save(
      fileName: fileName,
      contents: contents,
      authorize: () => true,
    );

    expect(result.delivery, 'unsupported');
    expect(result.userVisible, isFalse);
    expect(await directory.list().toList(), isEmpty);
  });

  test('existing same content succeeds without a new write', () async {
    final target = File(p.join(directory.path, fileName));
    await target.writeAsString(contents, flush: true);
    final before = await target.lastModified();
    final sink = PortableDataExportSink(downloadsDirectory: directory);

    final result = await sink.save(
      fileName: fileName,
      contents: contents,
      authorize: () => true,
    );

    expect(result.delivery, 'existing_verified');
    expect(result.userVisible, isTrue);
    expect(await target.readAsString(), contents);
    expect(await target.lastModified(), before);
  });

  test('support-bundle filename uses the same no-overwrite boundary', () async {
    const supportFileName =
        'parkinsum-support-2026-08-18-abcdef123456.support.json';
    final target = File(p.join(directory.path, supportFileName));
    await target.writeAsString(contents, flush: true);
    final sink = PortableDataExportSink(downloadsDirectory: directory);

    final result = await sink.save(
      fileName: supportFileName,
      contents: contents,
      authorize: () => true,
    );

    expect(result.delivery, 'existing_verified');
    expect(await target.readAsString(), contents);
  });

  test('existing different content is never overwritten', () async {
    final target = File(p.join(directory.path, fileName));
    await target.writeAsString('existing-private-data', flush: true);
    final sink = PortableDataExportSink(downloadsDirectory: directory);

    await expectLater(
      sink.save(fileName: fileName, contents: contents, authorize: () => true),
      throwsA(
        isA<PortableDataExportException>().having(
          (error) => error.residualFilePossible,
          'residualFilePossible',
          isFalse,
        ),
      ),
    );
    expect(await target.readAsString(), 'existing-private-data');
  });

  test(
    'large existing target is rejected from handle length without unbounded read',
    () async {
      final target = File(p.join(directory.path, fileName));
      final handle = await target.open(mode: FileMode.write);
      try {
        await handle.truncate(128 * 1024 * 1024);
      } finally {
        await handle.close();
      }
      final sink = PortableDataExportSink(downloadsDirectory: directory);

      await expectLater(
        sink.save(
          fileName: fileName,
          contents: contents,
          authorize: () => true,
        ),
        throwsA(isA<PortableDataExportException>()),
      ).timeout(const Duration(seconds: 2));

      expect(await target.length(), 128 * 1024 * 1024);
    },
  );

  test(
    'target introduced after absence check is never overwritten or deleted',
    () async {
      final target = File(p.join(directory.path, fileName));
      final sink = PortableDataExportSink(
        downloadsDirectory: directory,
        beforeUnsupportedReturn: (racedTarget) async {
          await racedTarget.writeAsString(
            'competitor-private-data',
            flush: true,
          );
        },
      );

      final result = await sink.save(
        fileName: fileName,
        contents: contents,
        authorize: () => true,
      );

      expect(result.delivery, 'unsupported');
      expect(await target.readAsString(), 'competitor-private-data');
      expect(await _temporaryFiles(directory), isEmpty);
    },
  );

  test(
    'failure after competitor appears leaves competitor and all paths untouched',
    () async {
      final target = File(p.join(directory.path, fileName));
      final sink = PortableDataExportSink(
        downloadsDirectory: directory,
        beforeUnsupportedReturn: (racedTarget) async {
          await racedTarget.writeAsString(
            'competitor-private-data',
            flush: true,
          );
          throw StateError('injected post-check failure');
        },
      );

      await expectLater(
        sink.save(
          fileName: fileName,
          contents: contents,
          authorize: () => true,
        ),
        throwsA(
          isA<PortableDataExportException>().having(
            (error) => error.residualFilePossible,
            'residualFilePossible',
            isFalse,
          ),
        ),
      );

      expect(await target.readAsString(), 'competitor-private-data');
      expect(await _temporaryFiles(directory), isEmpty);
    },
  );

  test('expired lease causes no target or cleanup side effect', () async {
    final sink = PortableDataExportSink(downloadsDirectory: directory);
    await expectLater(
      sink.save(fileName: fileName, contents: contents, authorize: () => false),
      throwsA(
        isA<PortableDataExportException>().having(
          (error) => error.residualFilePossible,
          'residualFilePossible',
          isFalse,
        ),
      ),
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test(
    'missing Downloads directory is unsupported without authorization',
    () async {
      final missing = Directory(p.join(directory.path, 'missing'));
      final sink = PortableDataExportSink(downloadsDirectory: directory);

      final result = await PortableDataExportSink(
        downloadsDirectory: missing,
      ).save(fileName: fileName, contents: contents, authorize: () => false);

      expect(result.delivery, 'unsupported');
      expect(await missing.exists(), isFalse);
      expect(sink.downloadsDirectory, directory);
    },
  );

  test('unsafe filename is rejected before filesystem access', () async {
    final sink = PortableDataExportSink(downloadsDirectory: directory);
    await expectLater(
      sink.save(
        fileName: '../private.json',
        contents: contents,
        authorize: () => true,
      ),
      throwsArgumentError,
    );
    expect(await directory.list().toList(), isEmpty);
  });
}

Future<List<FileSystemEntity>> _temporaryFiles(Directory directory) async =>
    directory
        .list()
        .where((entry) => p.basename(entry.path).startsWith('.'))
        .toList();
