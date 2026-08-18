import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/security/cdss_identifier_factory.dart';

void main() {
  group('CdssIdentifierFactory', () {
    test('creates unique Firestore-safe identifiers without payload data', () {
      final factory = CdssIdentifierFactory(
        random: Random(7),
        clock: () => DateTime.utc(2026, 8, 17),
      );

      final first = factory.newId('runtime');
      final second = factory.newId('runtime');

      expect(first, isNot(second));
      expect(first, matches(RegExp(r'^[A-Za-z0-9._:-]+$')));
      expect(second, matches(RegExp(r'^[A-Za-z0-9._:-]+$')));
      expect(first.length, lessThanOrEqualTo(160));
    });

    test(
      'digest is canonical, domain-separated, and not reversible base64',
      () {
        final factory = CdssIdentifierFactory(random: Random(1));
        const patientContext = <String, Object?>{
          'patient_id': 'patient_private_123',
          'meal_slot': 'dinner',
        };

        final first = factory.inputDigest('runtime-evaluation', patientContext);
        final reordered = factory.inputDigest('runtime-evaluation', {
          'meal_slot': 'dinner',
          'patient_id': 'patient_private_123',
        });
        final otherDomain = factory.inputDigest(
          'recommendation-audit',
          patientContext,
        );

        expect(first, reordered);
        expect(first, hasLength(64));
        expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(otherDomain, isNot(first));
        expect(first, isNot(contains('patient_private_123')));
        final decodedAsBase64 = utf8.decode(
          base64.decode(first),
          allowMalformed: true,
        );
        expect(decodedAsBase64, isNot(contains('patient_private_123')));
      },
    );

    test('rejects unsafe prefixes and non-JSON payloads', () {
      final factory = CdssIdentifierFactory(random: Random(1));

      expect(() => factory.newId('bad/id'), throwsArgumentError);
      expect(
        () => factory.inputDigest('runtime', DateTime.utc(2026)),
        throwsArgumentError,
      );
    });
  });
}
