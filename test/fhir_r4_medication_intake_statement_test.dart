import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_medication_intake_statement_mapper.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';

Intake _intake({
  DateTime? takenAt,
  String dosageNote = 'one tablet, as I recorded it',
  String id = 'private-intake-id',
}) => Intake(
  id: id,
  drugId: 'local-catalog-id',
  takenAt: takenAt ?? DateTime.utc(2026, 9, 26, 13, 15),
  dosageNote: dosageNote,
  doseAmount: 1,
  doseUnit: 'tablet',
);

void main() {
  const mapper = FhirR4MedicationIntakeStatementMapper();

  group('FHIR R4 MedicationStatement intake mapper', () {
    test('preserves a UTC event and only textual medication/dosage fields', () {
      final resource = mapper.fromIntake(
        _intake(),
        medicationDisplayName: 'Catalog display name',
        patientReference: 'Patient/patient-123',
      );

      expect(resource['resourceType'], 'MedicationStatement');
      expect(resource['status'], 'unknown');
      expect(resource['effectiveDateTime'], '2026-09-26T13:15:00.000Z');
      expect(resource['medicationCodeableConcept'], {
        'text': 'Catalog display name',
      });
      expect(resource['subject'], {'reference': 'Patient/patient-123'});
      expect(resource['dosage'], [
        {'text': 'one tablet, as I recorded it'},
      ]);
      expect(resource['note'], hasLength(1));
      final serialized = jsonEncode(resource);
      for (final omitted in [
        'private-intake-id',
        'local-catalog-id',
        'doseAmount',
        'doseUnit',
        'coding',
        'dateAsserted',
        'informationSource',
      ]) {
        expect(serialized, isNot(contains(omitted)));
      }
    });

    test(
      'reduces local time to date precision when no offset was retained',
      () {
        final resource = mapper.fromIntake(
          _intake(takenAt: DateTime(2026, 9, 26, 9, 15)),
          medicationDisplayName: 'Medication',
          patientReference: 'Patient/patient-123',
        );

        expect(resource['effectiveDateTime'], '2026-09-26');
        expect(
          ((resource['note'] as List).single as Map)['text'],
          contains('effectiveDateTime is date-only'),
        );
      },
    );

    test('validates references and bounds free-text projection', () {
      expect(
        () => mapper.fromIntake(
          _intake(),
          medicationDisplayName: 'Medication',
          patientReference: 'http://ehr.example/Patient/patient-123',
        ),
        throwsFormatException,
      );
      expect(
        () => mapper.fromIntake(
          _intake(),
          medicationDisplayName: '  ',
          patientReference: 'Patient/patient-123',
        ),
        throwsFormatException,
      );
      expect(
        () => mapper.fromIntake(
          _intake(dosageNote: List<String>.filled(4097, 'x').join()),
          medicationDisplayName: 'Medication',
          patientReference: 'Patient/patient-123',
        ),
        throwsFormatException,
      );
    });

    test('returns a deeply immutable FHIR resource', () {
      final resource = mapper.fromIntake(
        _intake(),
        medicationDisplayName: 'Medication',
        patientReference: 'Patient/patient-123',
      );

      expect(() => resource['status'] = 'active', throwsUnsupportedError);
      expect(
        () => (resource['subject'] as Map)['reference'] = 'Patient/other',
        throwsUnsupportedError,
      );
      expect(
        () => (resource['dosage'] as List).clear(),
        throwsUnsupportedError,
      );
    });
  });

  testWidgets('timeline previews locally and copies only after review', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = _MedicationTimelineState(services);
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    final medication = state.medRepo.allDrugs.first;
    final intake = _intake(
      takenAt: DateTime(2026, 9, 26, 9, 15),
    ).copyWith(drugId: medication.id);
    state.seed(intake);
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

    await _tap(tester, 'fhir-r4-intake-export-private-intake-id');
    await tester.enterText(
      find.byKey(
        const ValueKey('fhir-r4-intake-patient-reference-private-intake-id'),
      ),
      'Patient/patient-123',
    );
    await _tap(tester, 'fhir-r4-intake-export-preview');
    final previewText = tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('fhir-r4-intake-export-preview-json')),
        )
        .data!;
    final preview = jsonDecode(previewText) as Map<String, dynamic>;

    expect(preview['resourceType'], 'MedicationStatement');
    expect(preview['status'], 'unknown');
    expect(preview['effectiveDateTime'], '2026-09-26');
    expect(
      (preview['medicationCodeableConcept'] as Map)['text'],
      medication.displayName,
    );
    expect(previewText, contains('one tablet, as I recorded it'));
    expect(previewText, isNot(contains('private-intake-id')));
    expect(previewText, isNot(contains('local-catalog-id')));
    expect(clipboardText, isNull);
    expect(state.intakes.single.toJson(), intake.toJson());

    await _tap(tester, 'fhir-r4-intake-export-copy');
    expect(jsonDecode(clipboardText!)['resourceType'], 'MedicationStatement');
    expect(state.intakes.single.toJson(), intake.toJson());
    expect(find.text('FHIR JSON copied to the clipboard.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing the intake expires its open FHIR preview', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = _MedicationTimelineState(services);
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    final medication = state.medRepo.allDrugs.first;
    final intake = _intake(
      id: 'revision-intake',
    ).copyWith(drugId: medication.id);
    state.seed(intake);
    await tester.pumpAndSettle();

    await _tap(tester, 'fhir-r4-intake-export-revision-intake');
    await tester.enterText(
      find.byKey(
        const ValueKey('fhir-r4-intake-patient-reference-revision-intake'),
      ),
      'Patient/patient-123',
    );
    await _tap(tester, 'fhir-r4-intake-export-preview');
    expect(
      find.byKey(const ValueKey('fhir-r4-intake-export-preview-json')),
      findsOneWidget,
    );

    state.seed(intake.copyWith(dosageNote: 'edited after preview'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fhir-r4-intake-export-preview-json')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fhir-r4-intake-export-copy')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('account switch expires its open FHIR preview', (tester) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = _MedicationTimelineState(services);
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    final medication = state.medRepo.allDrugs.first;
    final intake = _intake(
      id: 'account-intake',
    ).copyWith(drugId: medication.id);
    state.seed(intake);
    await tester.pumpAndSettle();

    await _tap(tester, 'fhir-r4-intake-export-account-intake');
    await tester.enterText(
      find.byKey(
        const ValueKey('fhir-r4-intake-patient-reference-account-intake'),
      ),
      'Patient/patient-123',
    );
    await _tap(tester, 'fhir-r4-intake-export-preview');
    expect(
      find.byKey(const ValueKey('fhir-r4-intake-export-preview-json')),
      findsOneWidget,
    );

    state.switchOwner('owner-b');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fhir-r4-intake-export-preview-json')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fhir-r4-intake-export-copy')),
      findsNothing,
    );
    expect(find.textContaining('account changed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

class _MedicationTimelineState extends AppState {
  _MedicationTimelineState(Services services) : super(services: services);

  String _owner = 'owner-a';
  List<Intake> _records = const <Intake>[];

  @override
  String? get currentUserId => _owner;

  @override
  UserProfile get userProfile => UserProfile.defaults();

  @override
  List<Intake> get intakes => List<Intake>.unmodifiable(_records);

  @override
  List<TimelineEvent> get timeline => [
    for (final intake in _records)
      TimelineEvent.fromIntake(
        intake: intake,
        label: medRepo.getById(intake.drugId)?.displayName ?? intake.drugId,
      ),
  ];

  void seed(Intake intake) {
    _records = [intake];
    notifyListeners();
  }

  void switchOwner(String owner) {
    _owner = owner;
    notifyListeners();
  }
}
