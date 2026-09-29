import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/features/observations/observation_editor.dart';

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('observation-save')));
  await tester.tap(find.byKey(const Key('observation-save')));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'blank symptom is rejected and optional severity stays null on save',
    (tester) async {
      PersonalObservation? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ObservationEditor(
            recorderId: 'demo-owner',
            now: () => DateTime.utc(2026, 9, 22, 10),
            idFactory: () => 'new-1',
            onSave: (value) async {
              saved = value;
              return true;
            },
          ),
        ),
      );
      await _save(tester);
      expect(saved, isNull);
      expect(find.text('Please fill in this field.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('observation-label')));
      await tester.enterText(
        find.byKey(const Key('observation-label')),
        'Morning stiffness',
      );
      await _save(tester);
      expect(saved!.symptomLabel, 'Morning stiffness');
      expect(saved!.severity, isNull);
      expect(saved!.id, 'new-1');
      expect(saved!.recordedAt, DateTime.utc(2026, 9, 22, 10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('BP requires both measured values and stores the UCUM unit', (
    tester,
  ) async {
    PersonalObservation? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: ObservationEditor(
          recorderId: 'demo-owner',
          onSave: (value) async {
            saved = value;
            return true;
          },
        ),
      ),
    );
    await _select(tester, 'observation-kind', 'Blood pressure');
    await tester.enterText(
      find.byKey(const Key('observation-systolic')),
      '121',
    );
    await _save(tester);
    expect(saved, isNull);
    await tester.ensureVisible(find.byKey(const Key('observation-diastolic')));
    await tester.enterText(
      find.byKey(const Key('observation-diastolic')),
      '79',
    );
    await _save(tester);
    expect(saved!.systolic, 121);
    expect(saved!.diastolic, 79);
    expect(saved!.unit, 'mm[Hg]');
    expect(saved!.posture, BloodPressurePosture.unknown);
  });

  testWidgets('not measured BP preserves nulls instead of zeros', (
    tester,
  ) async {
    PersonalObservation? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: ObservationEditor(
          recorderId: 'demo-owner',
          onSave: (value) async {
            saved = value;
            return true;
          },
        ),
      ),
    );
    await _select(tester, 'observation-kind', 'Blood pressure');
    await _select(tester, 'observation-status', 'Not measured');
    await _save(tester);
    expect(saved!.status, PersonalObservationStatus.notMeasured);
    expect(saved!.systolic, isNull);
    expect(saved!.diastolic, isNull);
  });

  testWidgets(
    'editing preserves original identity, recorder and recorded timestamp',
    (tester) async {
      final original = PersonalObservation.create(
        id: 'existing-1',
        kind: PersonalObservationKind.symptom,
        occurredAt: DateTime.utc(2026, 9, 20, 12),
        recordedAt: DateTime.utc(2026, 9, 21, 10),
        originalTimezone: 'America/Toronto',
        source: PersonalObservationSource.caregiverReported,
        recorderId: 'original-recorder',
        status: PersonalObservationStatus.recorded,
        symptomLabel: 'Stiffness',
        severity: 3,
      );
      PersonalObservation? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ObservationEditor(
            recorderId: 'current-recorder',
            initialObservation: original,
            now: () => DateTime.utc(2026, 9, 22, 10),
            onSave: (value) async {
              saved = value;
              return true;
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('observation-severity')),
        '4',
      );
      await _save(tester);
      expect(saved!.severity, 4);
      expect(saved!.id, original.id);
      expect(saved!.recordedAt, original.recordedAt);
      expect(saved!.occurredAt, original.occurredAt);
      expect(saved!.recorderId, original.recorderId);
      expect(saved!.originalTimezone, original.originalTimezone);
    },
  );

  testWidgets(
    'Chinese form remains usable at narrow width and reports failed persistence',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ObservationEditor(
            recorderId: 'demo-owner',
            localeTag: 'zh-CN',
            onSave: (_) async => false,
          ),
        ),
      );
      expect(find.text('添加观察记录'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('observation-label')),
        '手部僵硬',
      );
      await _save(tester);
      expect(find.byKey(const Key('observation-save-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
