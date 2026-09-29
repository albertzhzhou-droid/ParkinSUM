import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/features/shared/administration_dose_confirmation_panel.dart';

void main() {
  testWidgets('accepted dose requires an explicit accessible confirmation', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Localizations.override(
          context: context,
          locale: const Locale('zh', 'CN'),
          child: child,
        ),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: AdministrationDoseConfirmationPanel(
              rawText: '100 mg',
              confirmationRequested: confirmed,
              onChanged: (value) => setState(() => confirmed = value),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dose-confirmation-panel')), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byKey(const Key('dose-confirmation-panel')),
    );
    expect(semantics.label, contains('剂量尚未确认'));
    await tester.tap(find.byKey(const Key('dose-confirmation-checkbox')));
    await tester.pump();
    expect(confirmed, isTrue);
    expect(
      tester
          .getSemantics(find.byKey(const Key('dose-confirmation-panel')))
          .label,
      contains('剂量确认已选择'),
    );
    expect(find.byKey(const Key('dose-confirmation-boundary')), findsOneWidget);
  });

  testWidgets('held expression cannot be confirmed', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdministrationDoseConfirmationPanel(
            rawText: '100 mg then 50 mg',
            confirmationRequested: false,
            onChanged: (_) => changed = true,
          ),
        ),
      ),
    );
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const Key('dose-confirmation-checkbox')),
    );
    expect(checkbox.onChanged, isNull);
    await tester.tap(find.byKey(const Key('dose-confirmation-checkbox')));
    await tester.pump();
    expect(changed, isFalse);
  });

  testWidgets('timeline badge distinguishes confirmed from review required', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AdministrationDoseConfirmationBadge(
                evaluation: AdministrationDoseEvaluation(
                  status: AdministrationDoseEvaluationStatus.confirmed,
                  reasonCode: 'dose_confirmation.confirmed',
                  value: 100,
                  unit: 'mg',
                ),
              ),
              AdministrationDoseConfirmationBadge(
                evaluation: AdministrationDoseEvaluation(
                  status: AdministrationDoseEvaluationStatus.absent,
                  reasonCode: 'dose_confirmation.absent',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('dose-confirmation-badge-confirmed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dose-confirmation-badge-review')),
      findsOneWidget,
    );
  });
}
