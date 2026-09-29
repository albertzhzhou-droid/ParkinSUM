@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/portable_data_export_sink.dart';

void main() {
  test(
    'declined authorization leaves no browser download side effect',
    () async {
      const sink = PortableDataExportSink();

      await expectLater(
        sink.save(
          fileName: 'parkinsum-user-data-browser-test.parkinsum.json',
          contents: '{"synthetic":true}',
          authorize: () => false,
        ),
        throwsA(
          isA<PortableDataExportException>().having(
            (error) => error.residualFilePossible,
            'residualFilePossible',
            isFalse,
          ),
        ),
      );
    },
  );

  test('unsafe filename is rejected before browser object creation', () async {
    const sink = PortableDataExportSink();

    await expectLater(
      sink.save(
        fileName: '../unsafe.json',
        contents: '{}',
        authorize: () => true,
      ),
      throwsArgumentError,
    );
  });
}
