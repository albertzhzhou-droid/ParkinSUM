import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/fhir_r4_encounter_copy.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_encounter_import_page.dart';

void main() {
  const localeTags = [
    'en-US',
    'zh-CN',
    'fr-CA',
    'ja-JP',
    'ko-KR',
    'hi-IN',
    'es-MX',
    'vi-VN',
    'th-TH',
    'id-ID',
    'ru-RU',
    'pl-PL',
    'ar-SA',
  ];

  test(
    'every shipped language family has complete copy and matching tokens',
    () {
      expect(
        kFhirR4EncounterCopy.keys.toSet(),
        localeTags.map((tag) => tag.split('-').first).toSet(),
      );
      final referenceKeys = kFhirR4EncounterCopy['en']!.keys.toSet();
      final tokenPattern = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

      for (final family in kFhirR4EncounterCopy.entries) {
        expect(family.value.keys.toSet(), referenceKeys, reason: family.key);
        for (final key in referenceKeys) {
          final value = family.value[key]!;
          expect(value.trim(), isNotEmpty, reason: '${family.key}/$key');
          final tokens = tokenPattern
              .allMatches(value)
              .map((match) => match.group(1))
              .toSet();
          final referenceTokens = tokenPattern
              .allMatches(kFhirR4EncounterCopy['en']![key]!)
              .map((match) => match.group(1))
              .toSet();
          expect(tokens, referenceTokens, reason: '${family.key}/$key');
        }
      }
    },
  );

  test('locale family normalization and safe English fallback are stable', () {
    expect(
      fhirR4EncounterCopy('action.preview', localeTag: 'fr_CA'),
      kFhirR4EncounterCopy['fr']!['action.preview'],
    );
    expect(
      fhirR4EncounterCopy('action.preview', localeTag: 'xx-YY'),
      kFhirR4EncounterCopy['en']!['action.preview'],
    );
    expect(
      fhirR4EncounterCopy(
        'entry.title',
        localeTag: 'en-US',
        params: {'index': '3', 'state': 'held'},
      ),
      'Entry 3: held',
    );
  });

  testWidgets('Encounter preview shell renders each shipped language family', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final localeTag in localeTags) {
      await tester.pumpWidget(
        MaterialApp(home: FhirR4EncounterImportPage(localeTag: localeTag)),
      );
      await tester.pumpAndSettle();
      final family = localeTag.split('-').first;
      expect(
        find.text(kFhirR4EncounterCopy[family]!['title']!),
        findsOneWidget,
        reason: localeTag,
      );
      expect(
        find.text(kFhirR4EncounterCopy[family]!['boundary']!),
        findsOneWidget,
        reason: localeTag,
      );
      await tester.tap(find.byKey(const Key('fhir-encounter-run-preview')));
      await tester.pumpAndSettle();
      expect(
        find.text(kFhirR4EncounterCopy[family]!['error.empty']!),
        findsOneWidget,
        reason: localeTag,
      );
    }
  });
}
