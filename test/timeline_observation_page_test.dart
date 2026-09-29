import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/features/observations/observation_editor.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';

/// Creation moved out of the timeline page to the shell's single "New entry"
/// action, which calls the same [openObservationEditor] entry point.
Future<void> _openObservationEditor(WidgetTester tester) async {
  unawaited(openObservationEditor(tester.element(find.byType(TimelinePage))));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<_ObservationState> _pump(
  WidgetTester tester, {
  bool chinese = false,
}) async {
  final services = Services.createEphemeral();
  await services.ready;
  final state = _ObservationState(services, chinese: chinese);
  addTearDown(state.dispose);
  await tester.binding.setSurfaceSize(const Size(360, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: TimelinePage()),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

PersonalObservation _record({bool chinese = false}) =>
    PersonalObservation.create(
      id: 'demo-observation',
      kind: PersonalObservationKind.selfReportedMotorState,
      occurredAt: DateTime.utc(2026, 9, 22, 12, 30),
      recordedAt: DateTime.utc(2026, 9, 22, 13),
      originalTimezone: 'UTC-04:00',
      source: PersonalObservationSource.selfReported,
      recorderId: 'owner-a',
      status: PersonalObservationStatus.recorded,
      motorState: SelfReportedMotorState.uncertain,
      notes: chinese ? '个人记录。' : 'Personal notes.',
    );

PersonalObservation _bloodPressureRecord() => PersonalObservation.create(
  id: 'demo-blood-pressure',
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.utc(2026, 9, 22, 12, 30),
  recordedAt: DateTime.utc(2026, 9, 22, 13),
  originalTimezone: 'UTC-04:00',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'owner-a',
  status: PersonalObservationStatus.recorded,
  systolic: 120,
  diastolic: 80,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
  notes: 'private note that must not be exported',
);

PersonalObservation _bloodPressureAt(
  String id,
  int minute, {
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
  double? systolic = 120,
  double? diastolic = 80,
  String recorderId = 'owner-a',
  String? notes,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.utc(2026, 9, 22, 12, minute),
  recordedAt: DateTime.utc(2026, 9, 22, 13, minute),
  originalTimezone: 'UTC-04:00',
  source: PersonalObservationSource.deviceManual,
  recorderId: recorderId,
  status: status,
  systolic: status == PersonalObservationStatus.recorded ? systolic : null,
  diastolic: status == PersonalObservationStatus.recorded ? diastolic : null,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
  notes: notes,
);

PersonalObservation _symptomAt(
  String id,
  int minute, {
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
  int? severity = 4,
  PersonalObservationSource source = PersonalObservationSource.selfReported,
  String recorderId = 'owner-a',
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.utc(2026, 9, 22, 12, minute),
  recordedAt: DateTime.utc(2026, 9, 22, 13, minute),
  originalTimezone: 'UTC-04:00',
  source: source,
  recorderId: recorderId,
  status: status,
  symptomLabel: 'Stiffness',
  severity: status == PersonalObservationStatus.recorded ? severity : null,
  notes: 'Private symptom note',
);

PersonalObservation _motorAt(
  String id,
  int minute, {
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
  SelfReportedMotorState motorState = SelfReportedMotorState.off,
  PersonalObservationSource source = PersonalObservationSource.selfReported,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: DateTime.utc(2026, 9, 22, 12, minute),
  recordedAt: DateTime.utc(2026, 9, 22, 13, minute),
  originalTimezone: 'UTC-04:00',
  source: source,
  recorderId: 'owner-a',
  status: status,
  motorState: status == PersonalObservationStatus.recorded ? motorState : null,
  notes: 'Private motor-state note',
);

void main() {
  testWidgets('timeline shows a bounded in-memory observation audit ledger', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.seedMany([
      _symptomAt('audit-ledger-private-id', 1, severity: 0),
      _motorAt('audit-ledger-motor', 2, motorState: SelfReportedMotorState.on),
    ]);
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('personal-observation-event-ledger-card'),
    );
    await tester.scrollUntilVisible(
      card,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(card, findsOneWidget);
    final cardCopy = tester
        .widgetList<Text>(
          find.descendant(of: card, matching: find.byType(Text)),
        )
        .map((widget) => widget.data ?? '')
        .join('\n');
    expect(cardCopy, contains('not checked against a timezone database'));
    expect(cardCopy, contains('no clinical interpretation'));
    expect(cardCopy, isNot(contains('Stiffness')));
    expect(cardCopy, isNot(contains('Private symptom note')));
    expect(cardCopy, isNot(contains('audit-ledger-private-id')));
    expect(
      find.byKey(const ValueKey('personal-observation-ledger-digest')),
      findsOneWidget,
    );

    await _tap(tester, 'personal-observation-ledger-events');
    expect(find.textContaining('Symptom entry · Recorded'), findsOneWidget);
    expect(find.textContaining('Reported severity · 0/10'), findsOneWidget);
    expect(find.textContaining('Symptom label omitted'), findsOneWidget);
    expect(state.saveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English narrow timeline adds, edits and deletes observations', (
    tester,
  ) async {
    final state = await _pump(tester);
    expect(
      find.byKey(const ValueKey('export-fhir-bp-demo-observation')),
      findsNothing,
    );
    await _openObservationEditor(tester);
    expect(find.byType(ObservationEditor), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('observation-label')),
      'Stiffness',
    );
    await _tap(tester, 'observation-save');
    expect(state.observations, hasLength(1));
    final original = state.observations.single;
    expect(find.text('Observation · Self-reported'), findsOneWidget);
    expect(find.text('Stiffness'), findsNWidgets(2));
    await _tap(tester, 'edit-observation-${original.id}');
    await tester.enterText(
      find.byKey(const ValueKey('observation-severity')),
      '0',
    );
    await _tap(tester, 'observation-save');
    expect(state.observations.single.recordedAt, original.recordedAt);
    expect(find.text('Stiffness · 0/10'), findsOneWidget);
    await _tap(tester, 'delete-observation-${original.id}');
    expect(state.observations, isEmpty);
    expect(find.text('Observation deleted.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timeline charts only entered readings and retains gaps and details',
    (tester) async {
      final state = await _pump(tester);
      state.seedMany([
        _bloodPressureAt('bp-latest', 4, systolic: 132, diastolic: 84),
        _bloodPressureAt(
          'bp-unknown',
          3,
          status: PersonalObservationStatus.unknown,
        ),
        _bloodPressureAt(
          'bp-not-measured',
          2,
          status: PersonalObservationStatus.notMeasured,
        ),
        _bloodPressureAt('bp-earlier', 1, systolic: 120, diastolic: 80),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('blood-pressure-trend-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('blood-pressure-trend-painter')),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 measured, 1 unknown, 1 not measured'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No clinical thresholds or interpretation'),
        findsOneWidget,
      );
      expect(find.textContaining('normal'), findsNothing);

      final chartSemantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('blood-pressure-trend-chart')),
      );
      expect(chartSemantics.properties.label, contains('120 / 80 mmHg'));
      expect(chartSemantics.properties.label, contains('132 / 84 mmHg'));
      expect(chartSemantics.properties.label, contains('Unknown'));
      expect(chartSemantics.properties.label, contains('Not measured'));

      await _tap(tester, 'blood-pressure-trend-details');
      expect(
        find.byKey(const ValueKey('bp-trend-record-bp-earlier')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bp-trend-record-bp-unknown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bp-trend-record-bp-not-measured')),
        findsOneWidget,
      );
      expect(find.text('120 / 80 mmHg'), findsOneWidget);
      expect(find.text('132 / 84 mmHg'), findsOneWidget);
      expect(find.text('Unknown'), findsWidgets);
      expect(find.text('Not measured'), findsWidgets);
      expect(state.saveCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'symptom and motor-state sequence preserves missingness and exports only on request',
    (tester) async {
      final state = await _pump(tester);
      state.seedMany([
        _symptomAt('symptom-recorded', 0, severity: 0),
        _motorAt('motor-recorded', 1, motorState: SelfReportedMotorState.off),
        _symptomAt(
          'symptom-unknown',
          2,
          status: PersonalObservationStatus.unknown,
        ),
        _motorAt(
          'motor-not-measured',
          3,
          status: PersonalObservationStatus.notMeasured,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('symptom-motor-observation-sequence-card')),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 recorded, 1 unknown, 1 not measured'),
        findsOneWidget,
      );
      for (final id in [
        'symptom-recorded',
        'motor-recorded',
        'symptom-unknown',
        'motor-not-measured',
      ]) {
        expect(
          find.byKey(ValueKey('symptom-motor-sequence-record-$id')),
          findsOneWidget,
        );
      }
      expect(
        find.textContaining('does not represent measurement intervals'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey('fhir-symptom-motor-export-collection'),
              ),
            )
            .onPressed,
        isNotNull,
      );

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _tap(tester, 'fhir-symptom-motor-export-collection');
      await tester.enterText(
        find.byKey(const ValueKey('fhir-sm-patient-reference')),
        'Patient/patient-123',
      );
      await tester.tap(find.byKey(const ValueKey('fhir-sm-export-preview')));
      await tester.pumpAndSettle();
      final previewText = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('fhir-sm-export-preview-json')),
          )
          .data!;
      final preview = jsonDecode(previewText) as Map<String, dynamic>;
      final resources = (preview['entry'] as List)
          .cast<Map<String, dynamic>>()
          .map((entry) => entry['resource'] as Map<String, dynamic>)
          .toList();
      expect(preview['resourceType'], 'Bundle');
      expect(preview['type'], 'collection');
      expect(resources, hasLength(4));
      expect(
        resources.map((resource) => resource['dataAbsentReason'] == null),
        [true, true, false, false],
      );
      expect(previewText, contains('Patient/patient-123'));
      expect(previewText, contains('parkinsum-personal-observation'));
      expect(previewText, contains('2026-09-22T12:00:00.000Z'));
      expect(previewText, isNot(contains('owner-a')));
      expect(previewText, isNot(contains('symptom-recorded')));
      expect(previewText, isNot(contains('Private symptom note')));
      expect(previewText, isNot(contains('Private motor-state note')));
      expect(clipboardText, isNull);
      expect(state.saveCalls, 0);

      await tester.tap(find.byKey(const ValueKey('fhir-sm-export-copy')));
      await tester.pumpAndSettle();
      expect(jsonDecode(clipboardText!)['type'], 'collection');
      expect(state.saveCalls, 0);
      expect(find.text('FHIR JSON copied to the clipboard.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FHIR blood-pressure export previews locally and copies only after confirmation',
    (tester) async {
      final state = await _pump(tester);
      state.seed(_bloodPressureRecord());
      await tester.pumpAndSettle();
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _tap(tester, 'export-fhir-bp-demo-blood-pressure');
      expect(
        find.byKey(const ValueKey('fhir-bp-patient-reference')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('fhir-bp-export-copy')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('fhir-bp-patient-reference')),
        'Patient/',
      );
      await tester.tap(find.byKey(const ValueKey('fhir-bp-export-preview')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fhir-bp-export-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('fhir-bp-export-preview-json')),
        findsNothing,
      );
      expect(clipboardText, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('fhir-bp-patient-reference')),
        'Patient/patient-123',
      );
      await tester.tap(find.byKey(const ValueKey('fhir-bp-export-preview')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fhir-bp-export-preview-json')),
        findsOneWidget,
      );
      expect(find.textContaining('85354-9'), findsOneWidget);
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('fhir-bp-export-preview-json')),
            )
            .data,
        contains('Patient/patient-123'),
      );
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('fhir-bp-export-preview-json')),
            )
            .data,
        contains('"version": "2.83"'),
      );
      expect(clipboardText, isNull);
      expect(state.saveCalls, 0);

      await tester.tap(find.byKey(const ValueKey('fhir-bp-export-copy')));
      await tester.pumpAndSettle();
      final resource = jsonDecode(clipboardText!) as Map<String, dynamic>;
      expect(resource['resourceType'], 'Observation');
      expect((resource['subject'] as Map)['reference'], 'Patient/patient-123');
      expect(clipboardText, contains('"version": "2.83"'));
      expect(
        clipboardText,
        isNot(contains('private note that must not be exported')),
      );
      expect(clipboardText, isNot(contains('owner-a')));
      expect(clipboardText, contains('originalTimezone=UTC-04:00'));
      expect(state.saveCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('FHIR JSON copied to the clipboard.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FHIR collection export preserves the trend window and copies only on request',
    (tester) async {
      final state = await _pump(tester);
      state.seedMany([
        _bloodPressureAt(
          'bp-latest',
          3,
          systolic: 132,
          diastolic: 84,
          notes: 'private note',
        ),
        _bloodPressureAt(
          'bp-unknown',
          2,
          status: PersonalObservationStatus.unknown,
        ),
        _bloodPressureAt(
          'bp-not-measured',
          1,
          status: PersonalObservationStatus.notMeasured,
        ),
      ]);
      await tester.pumpAndSettle();
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _tap(tester, 'fhir-bp-export-collection');
      await tester.enterText(
        find.byKey(const ValueKey('fhir-bp-patient-reference')),
        'Patient/patient-123',
      );
      await tester.tap(find.byKey(const ValueKey('fhir-bp-export-preview')));
      await tester.pumpAndSettle();
      final previewText = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('fhir-bp-export-preview-json')),
          )
          .data!;
      final preview = jsonDecode(previewText) as Map<String, dynamic>;
      expect(previewText, contains('"version": "2.83"'));
      final previewEntries = (preview['entry'] as List)
          .cast<Map<String, dynamic>>();
      final previewResources = previewEntries
          .map((entry) => entry['resource'] as Map<String, dynamic>)
          .toList();

      expect(preview['resourceType'], 'Bundle');
      expect(preview['type'], 'collection');
      expect(previewResources.map((item) => item['effectiveDateTime']), [
        DateTime.utc(2026, 9, 22, 12, 1).toIso8601String(),
        DateTime.utc(2026, 9, 22, 12, 2).toIso8601String(),
        DateTime.utc(2026, 9, 22, 12, 3).toIso8601String(),
      ]);
      final fullUrls = previewEntries
          .map((entry) => entry['fullUrl'] as String)
          .toList();
      expect(fullUrls.toSet().length, previewEntries.length);
      for (var index = 0; index < previewEntries.length; index++) {
        expect(fullUrls[index].split(':').last, previewResources[index]['id']);
      }
      expect(
        previewResources.map(
          (item) =>
              (((item['dataAbsentReason'] as Map?)?['coding'] as List?)?.first
                  as Map?)?['code'],
        ),
        ['not-performed', 'unknown', null],
      );
      expect(previewText, contains('Patient/patient-123'));
      expect(previewText, isNot(contains('bp-not-measured')));
      expect(previewText, isNot(contains('bp-unknown')));
      expect(previewText, isNot(contains('bp-latest')));
      expect(previewText, isNot(contains('private note')));
      expect(previewText, isNot(contains('owner-a')));
      expect(clipboardText, isNull);
      expect(state.saveCalls, 0);

      await tester.tap(find.byKey(const ValueKey('fhir-bp-export-copy')));
      await tester.pumpAndSettle();
      final copied = jsonDecode(clipboardText!) as Map<String, dynamic>;
      expect(copied['resourceType'], 'Bundle');
      expect(copied['type'], 'collection');
      expect((copied['entry'] as List), hasLength(3));
      expect(state.saveCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('FHIR JSON copied to the clipboard.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FHIR collection export is disabled across recorder owners', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.seedMany([
      _bloodPressureAt('bp-owner-a', 1),
      _bloodPressureAt('bp-owner-b', 2, recorderId: 'owner-b'),
    ]);
    await tester.pumpAndSettle();

    final exportButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('fhir-bp-export-collection')),
    );
    expect(exportButton.onPressed, isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'combined FHIR export shares one Patient reference and copies only on request',
    (tester) async {
      final state = await _pump(tester);
      state.seedMany([
        _bloodPressureAt('local-bp-record', 2, notes: 'private BP note'),
        _symptomAt('local-symptom-record', 1),
        _motorAt('local-motor-record', 3),
      ]);
      await tester.pumpAndSettle();
      final exportButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('fhir-personal-observation-export')),
      );
      expect(exportButton.onPressed, isNotNull);

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _tap(tester, 'fhir-personal-observation-export');
      await tester.enterText(
        find.byKey(const ValueKey('fhir-all-patient-reference')),
        'Patient/patient-123',
      );
      await tester.tap(find.byKey(const ValueKey('fhir-all-export-preview')));
      await tester.pumpAndSettle();
      final previewText = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('fhir-all-export-preview-json')),
          )
          .data!;
      final preview = jsonDecode(previewText) as Map<String, dynamic>;
      final entries = (preview['entry'] as List).cast<Map<String, dynamic>>();
      final resources = entries
          .map((entry) => entry['resource'] as Map<String, dynamic>)
          .toList();

      expect(preview['resourceType'], 'Bundle');
      expect(preview['type'], 'collection');
      expect(resources, hasLength(3));
      expect(resources.map((item) => item['effectiveDateTime']), [
        DateTime.utc(2026, 9, 22, 12, 1).toIso8601String(),
        DateTime.utc(2026, 9, 22, 12, 2).toIso8601String(),
        DateTime.utc(2026, 9, 22, 12, 3).toIso8601String(),
      ]);
      expect(
        resources.map((item) => (item['subject'] as Map)['reference']),
        everyElement('Patient/patient-123'),
      );
      expect(previewText, contains('85354-9'));
      expect(previewText, contains('parkinsum-personal-observation'));
      expect(previewText, isNot(contains('local-bp-record')));
      expect(previewText, isNot(contains('local-symptom-record')));
      expect(previewText, isNot(contains('local-motor-record')));
      expect(previewText, isNot(contains('private BP note')));
      expect(previewText, isNot(contains('Private symptom note')));
      expect(previewText, isNot(contains('Private motor-state note')));
      expect(previewText, isNot(contains('owner-a')));
      expect(clipboardText, isNull);
      expect(state.saveCalls, 0);

      await tester.tap(find.byKey(const ValueKey('fhir-all-export-copy')));
      await tester.pumpAndSettle();
      expect(jsonDecode(clipboardText!)['type'], 'collection');
      expect((jsonDecode(clipboardText!)['entry'] as List), hasLength(3));
      expect(state.saveCalls, 0);
      expect(find.text('FHIR JSON copied to the clipboard.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('combined FHIR export is disabled for mixed recorder owners', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.seedMany([
      _bloodPressureAt('local-bp-record', 1),
      _symptomAt('other-owner-symptom', 2, recorderId: 'owner-b'),
    ]);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('fhir-personal-observation-export')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(state.saveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FHIR export expires when the account changes before copy', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.seed(_bloodPressureRecord());
    await tester.pumpAndSettle();
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _tap(tester, 'export-fhir-bp-demo-blood-pressure');
    await tester.enterText(
      find.byKey(const ValueKey('fhir-bp-patient-reference')),
      'Patient/patient-123',
    );
    await tester.tap(find.byKey(const ValueKey('fhir-bp-export-preview')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fhir-bp-export-preview-json')),
      findsOneWidget,
    );

    state.switchOwner('owner-b');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fhir-bp-export-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fhir-bp-export-preview-json')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('fhir-bp-export-copy')),
          )
          .onPressed,
      isNull,
    );
    expect(clipboardText, isNull);
    expect(state.saveCalls, 0);
    await tester.tap(find.byKey(const ValueKey('fhir-bp-export-cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Chinese narrow timeline labels self-report and actual occurrence time',
    (tester) async {
      final state = await _pump(tester, chinese: true);
      state.seed(_record(chinese: true));
      await tester.pumpAndSettle();
      expect(find.text('观察记录 · 本人自报'), findsOneWidget);
      expect(find.text('自报运动状态 · 不确定'), findsNWidgets(2));
      expect(find.text('发生时间: 09/22 12:30 UTC'), findsOneWidget);
      expect(find.text('个人描述，未经临床核实。'), findsOneWidget);
      await _tap(tester, 'edit-observation-demo-observation');
      expect(find.text('编辑观察记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save and delete failures retain records and show explicit feedback',
    (tester) async {
      final state = await _pump(tester);
      state.seed(_record());
      state.failSave = true;
      await tester.pumpAndSettle();
      await _tap(tester, 'edit-observation-demo-observation');
      await _tap(tester, 'observation-save');
      expect(
        find.byKey(const ValueKey('observation-save-error')),
        findsOneWidget,
      );
      expect(find.byType(ObservationEditor), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      state.failDelete = true;
      await _tap(tester, 'delete-observation-demo-observation');
      expect(state.observations, hasLength(1));
      expect(
        find.text(
          'Deletion failed. The observation is still saved. Please try again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account switch expires the open editor callback before new-owner writes',
    (tester) async {
      final state = await _pump(tester);
      await _openObservationEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('observation-label')),
        'Old account note',
      );
      state.switchOwner('owner-b');
      await tester.pumpAndSettle();
      await _tap(tester, 'observation-save');
      expect(state.saveCalls, 0);
      expect(state.observations, isEmpty);
      expect(
        find.byKey(const ValueKey('observation-save-error')),
        findsOneWidget,
      );
      // Returning to the same account does not revive a stale editor lease.
      state.switchOwner('owner-a');
      await tester.pumpAndSettle();
      await _tap(tester, 'observation-save');
      expect(state.saveCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ObservationState extends AppState {
  _ObservationState(Services services, {required this.chinese})
    : super(services: services);
  final bool chinese;
  String _owner = 'owner-a';
  List<PersonalObservation> _records = [];
  bool failSave = false;
  bool failDelete = false;
  int saveCalls = 0;

  @override
  String? get currentUserId => _owner;
  @override
  UserProfile get userProfile => UserProfile.defaults().copyWith(
    displayLocale: chinese ? 'zh-CN' : 'en-US',
  );
  @override
  List<PersonalObservation> get observations => List.unmodifiable(_records);
  void seed(PersonalObservation value) {
    _records = [value];
    notifyListeners();
  }

  void seedMany(List<PersonalObservation> values) {
    _records = List.of(values);
    notifyListeners();
  }

  void switchOwner(String owner) {
    _owner = owner;
    _records = [];
    notifyListeners();
  }

  @override
  Future<bool> saveObservation(PersonalObservation observation) async {
    saveCalls++;
    if (failSave || observation.recorderId != _owner) return false;
    _records = [
      ..._records.where((item) => item.id != observation.id),
      observation,
    ];
    notifyListeners();
    return true;
  }

  @override
  Future<bool> deleteObservation(String id) async {
    if (failDelete) return false;
    _records = _records.where((item) => item.id != id).toList();
    notifyListeners();
    return true;
  }
}
