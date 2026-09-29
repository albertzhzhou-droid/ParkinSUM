import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/entities/evidence_synthesis.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/algorithm_observatory_page.dart';

void main() {
  testWidgets('shows source-linked dependent findings in the observatory panel', (
    tester,
  ) async {
    final currency = EvidenceCurrencyRegistry.current;
    final firstBody = EvidenceSynthesisRegistry.current.bodies.first;
    final firstFinding = firstBody.findings.first;
    final secondCurrency = currency.records[1];
    const secondFindingId = 'finding.synthetic.panel.second';
    final secondFinding = EvidenceStudyFinding(
      findingId: secondFindingId,
      evidenceCurrencyClaimId: secondCurrency.claimId,
      sourceRevision: secondCurrency.sourceRevision,
      independenceGroupId: 'cohort.synthetic.panel.second',
      studyDesign: firstFinding.studyDesign,
      population: 'Synthetic widget-test population.',
      interventionOrExposure: 'Synthetic widget-test exposure.',
      comparator: 'Synthetic widget-test comparator.',
      outcomeId: firstFinding.outcomeId,
      measureId: firstFinding.measureId,
      direction: firstFinding.direction,
      effectEstimate: null,
      lowerBound: null,
      upperBound: null,
      effectUnit: null,
      riskOfBias: EvidenceRiskOfBias.low,
      applicability: EvidenceApplicability.direct,
      precision: EvidencePrecision.precise,
      reportingBias: EvidenceReportingBias.unlikely,
      limitation: 'Synthetic widget-test finding only.',
    );
    final linkedBody = firstBody.copyWith(
      findings: [firstFinding, secondFinding],
      dependencies: [
        EvidenceFindingDependency(
          firstFindingId: firstFinding.findingId,
          secondFindingId: secondFindingId,
          relation: EvidenceDependencyRelation.sameCohort,
          reviewState: EvidenceDependencyReviewState.confirmed,
          sourceEvidenceIds: const ['source.synthetic.study-overlap-review'],
          rationale: 'Synthetic fixture links both findings to one cohort.',
        ),
      ],
    );
    final registry = EvidenceSynthesisRegistry(
      bodies: [linkedBody, ...EvidenceSynthesisRegistry.current.bodies.skip(1)],
    );
    final asOfUtc = DateTime.parse('2026-08-19T00:00:00Z');
    final assessment = registry.assess(
      asOfUtc: asOfUtc,
      currencyAssessment: currency.assess(asOfUtc: asOfUtc),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [EvidenceSynthesisPanel(assessment: assessment)],
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(Key('evidence-synthesis-${linkedBody.claimId}')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Dependent finding components: ${firstFinding.findingId} + $secondFindingId',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Dependency links: ${firstFinding.findingId} ↔ $secondFindingId · sameCohort · confirmed · source.synthetic.study-overlap-review',
      ),
      findsOneWidget,
    );
  });
}
