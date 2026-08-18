import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_runner.dart';

void main() {
  final runner = MechanisticReplayRunner();

  test('all default scenarios pass', () {
    final report = runner.run();
    expect(
      report.allPassed,
      isTrue,
      reason: report.cases
          .where((c) => !c.pass)
          .map((c) => '${c.scenarioId}: ${c.failureReason}')
          .join('\n'),
    );
  });

  test('report binds replay to configuration without claiming validity', () {
    final report = runner.run();
    final configuration =
        report.toJson()['algorithm_configuration'] as Map<String, dynamic>;

    expect(
      configuration['manifest_schema'],
      'parkinsum.algorithm-configuration/2',
    );
    expect(configuration['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(
      configuration['reproducibility_scope'],
      'engineering_replay_identity_not_biological_validation',
    );
    expect(
      configuration['biological_validity_status'],
      'not_clinically_calibrated',
    );
    expect(report.toMarkdown(), contains('does **not** establish biological'));
  });

  test('every case has zero banned-phrase hits', () {
    final report = runner.run();
    for (final c in report.cases) {
      expect(
        c.bannedPhraseHits,
        isEmpty,
        reason: '${c.scenarioId} leaked: ${c.bannedPhraseHits}',
      );
    }
  });

  test('insufficient-context scenarios serialize a typed null abstention', () {
    final report = runner.run();
    for (final c in report.cases.where(
      (c) =>
          c.scenarioId.startsWith('s08') ||
          c.scenarioId.startsWith('s09') ||
          c.scenarioId.startsWith('s10'),
    )) {
      expect(c.resultAvailability, 'insufficient');
      expect(c.hasModeledOutput, isFalse);
      expect(c.interactionScore, isNull);
      expect(c.severityBand, isNull);
      expect(c.confidenceBand, isNull);
      expect(c.aminoAcidCompetitionBand, isNull);
      expect(c.abstentionReasons, isNotEmpty);
      expect(c.blockedMechanisms, isNotEmpty);
    }
  });

  test('a missing meal record abstains without an absorption window', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
      (c) => c.scenarioId == 's07_missing_meal_time',
    );

    expect(c.pass, isTrue, reason: c.failureReason);
    expect(c.mealContextCompleteness, 0.0);
    expect(c.resultAvailability, 'insufficient');
    expect(c.hasModeledOutput, isFalse);
    expect(c.interactionScore, isNull);
    expect(c.severityBand, isNull);
    expect(c.confidenceBand, isNull);
    expect(c.aminoAcidCompetitionBand, isNull);
    expect(c.absorptionOpportunityWindow, isNull);
    expect(c.absorptionOpennessSampleCount, 0);
    expect(c.abstentionReasons, isNotEmpty);
    expect(c.blockedMechanisms, isNotEmpty);
  });

  test('an ER medication replay abstains outside the executable domain', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
      (c) => c.scenarioId == 's40_spl_er_section_provenance',
    );

    expect(c.pass, isTrue, reason: c.failureReason);
    // The release is known unsupported, while the composite dosage-form token
    // remains outside the governed vocabulary; unknown evidence takes the
    // more conservative insufficient state over notApplicable.
    expect(c.resultAvailability, 'insufficient');
    expect(c.hasModeledOutput, isFalse);
    expect(c.interactionScore, isNull);
    expect(c.severityBand, isNull);
    expect(c.confidenceBand, isNull);
    expect(c.aminoAcidCompetitionBand, isNull);
    expect(c.absorptionOpportunityWindow, isNull);
    expect(c.absorptionOpennessSampleCount, 0);
    expect(c.abstentionReasons, isNotEmpty);
  });

  test('abstentions never leak legacy zero/band or candidate rank values', () {
    final report = runner.run();
    final abstentions = report.cases.where((c) => !c.hasModeledOutput).toList();

    expect(abstentions, isNotEmpty);
    for (final c in abstentions) {
      final json = c.toJson();
      expect(json['result_availability'], isNot('available'));
      expect(json['has_modeled_output'], isFalse);
      expect(json['interaction_score'], isNull);
      expect(json['severity_band'], isNull);
      expect(json['confidence_band'], isNull);
      expect(json['amino_acid_competition_band'], isNull);
      expect(json['abstention_reasons'], isNotEmpty);
      expect(c.rankerUsed, 'none_model_abstained');
      expect(c.sampledWindowOffsets, isEmpty);
      expect(c.topFinalCandidateScore, isNull);
      expect(c.topProteinRedistributionScore, isNull);
      expect(c.topNutritionAdequacyContribution, isNull);
      expect(c.topSourceAuthorityScore, isNull);
      expect(c.topJurisdictionMatchScore, isNull);
      for (final candidate in c.nextMealRecommendationResult ?? const []) {
        final candidateJson = candidate.toJson();
        expect(candidateJson['has_modeled_output'], isFalse);
        expect(candidateJson['final_candidate_score'], isNull);
        expect(candidateJson['sample_count'], isNull);
        expect(candidateJson['sampled_window_summary'], isEmpty);
      }
    }
  });

  test('user-window scenarios produce non-empty recommendations', () {
    final report = runner.run();
    final s13 = report.cases.firstWhere(
      (c) => c.scenarioId == 's13_user_window_candidates',
    );
    expect(s13.nextMealRecommendationResult, isNotNull);
    expect(s13.nextMealRecommendationResult!, isNotEmpty);
  });

  test(
    'multi-dose scenario reports per-event count and user-entered dosage',
    () {
      final report = runner.run();
      final md = report.cases.firstWhere(
        (c) => c.scenarioId == 's04b_multidose_ir',
      );
      expect(md.perEventCount, 2);
      // The user-entered dose is surfaced exactly (100 mg), never a default.
      expect(md.userEnteredDosage, '100 mg');
      expect(md.dosageContextComplete, isTrue);
    },
  );

  test('ambiguous/empty dosage scenarios report incomplete dose context', () {
    final report = runner.run();
    for (final c in report.cases.where(
      (c) =>
          c.scenarioId.startsWith('s08') ||
          c.scenarioId.startsWith('s09') ||
          c.scenarioId.startsWith('s10'),
    )) {
      // No private default dose may be injected: these stay incomplete.
      expect(
        c.dosageContextComplete,
        isFalse,
        reason: '${c.scenarioId} must not claim a complete dose context',
      );
    }
  });

  test('candidate-only AA abstention does not leak LNAA totals', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
      (c) => c.scenarioId == 's22_amino_acid_actual_fields_mode',
    );
    expect(c.hasModeledOutput, isFalse);
    expect(c.resultAvailability, 'insufficient');
    expect(c.aminoAcidDataMode, isNull);
    expect(c.competingLnaaGrams, isNull);
    expect(c.partialAminoAcidData, isFalse);
    expect(c.scoringParameterSetId, 'none');
  });

  test(
    'candidate-only partial AA abstention does not project model fields',
    () {
      final report = runner.run();
      final c = report.cases.firstWhere(
        (c) => c.scenarioId == 's32_partial_amino_acid_profile',
      );
      expect(c.hasModeledOutput, isFalse);
      expect(c.resultAvailability, 'insufficient');
      expect(c.aminoAcidDataMode, isNull);
      expect(c.competingLnaaGrams, isNull);
      expect(c.partialAminoAcidData, isFalse);
    },
  );

  test('high-calorie meal scenario widens gastric uncertainty', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
      (c) => c.scenarioId == 's33_high_calorie_high_fat_meal',
    );
    expect(
      c.gastricEmptyingAssumptions.any(
        (a) => a.contains('ge.highcal.uncertainty_boost'),
      ),
      isTrue,
    );
    expect(c.mealComponentCount, greaterThanOrEqualTo(1));
    // Absorption openness profile was produced for the dose.
    expect(c.absorptionOpennessSampleCount, greaterThan(0));
    expect(c.absorptionPeakOpenness, isNotNull);
  });

  test('explicit-dose + actual-AA meal exposes dose-relative LNAA proxy', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
      (c) => c.scenarioId == 's34_explicit_dose_dose_relative_lnaa',
    );
    expect(c.doseRelativeLnaaAvailable, isTrue);
    expect(c.doseRelativeLnaaRatio, isNotNull);
  });

  test(
    'FDC analytical provenance surfaces confidence tier in the report (B1)',
    () {
      final report = runner.run();
      final c = report.cases.firstWhere(
        (c) => c.scenarioId == 's34_explicit_dose_dose_relative_lnaa',
      );
      // The amino-acid meal carries FDC analytical derivations → tier surfaced,
      // and analytical provenance does not widen uncertainty.
      expect(c.aminoAcidConfidenceTier, 'analytical');
      final encoded = encodeReplayReport(report);
      expect(encoded, contains('"amino_acid_confidence_tier"'));
    },
  );

  test('serialized report is valid JSON and contains no banned phrases', () {
    final report = runner.run();
    final encoded = encodeReplayReport(report);
    expect(encoded, contains('"scenario_id"'));
    expect(encoded, contains('"competing_lnaa_grams"'));
    expect(encoded, contains('"scoring_parameter_set_id"'));
    expect(findBannedSubstrings(encoded), isEmpty);
  });

  // D2 — missingness stress suite. Proves missing ≠ zero end-to-end: missing
  // nutrient inputs lower composition completeness and confidence rather than
  // being silently treated as 0.
  test(
    'missing calories/portion lowers completeness, never fabricated (D2)',
    () {
      final report = runner.run();
      final c = report.cases.firstWhere(
        (c) => c.scenarioId == 's35_missing_calories_and_portion',
      );
      expect(c.mealContextCompleteness, lessThan(1.0));
      expect(c.confidenceBand, isNot('high'));
    },
  );

  test('all-macros-missing → typed insufficient with null outputs (D2)', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
      (c) => c.scenarioId == 's36_missing_all_macros_unknown_competition',
    );
    expect(c.resultAvailability, 'insufficient');
    expect(c.hasModeledOutput, isFalse);
    expect(c.interactionScore, isNull);
    expect(c.severityBand, isNull);
    expect(c.confidenceBand, isNull);
    expect(c.aminoAcidCompetitionBand, isNull);
  });

  // C1 — enteral feeding educational scenarios stay non-prescriptive.
  test('enteral scenarios run and stay non-prescriptive (C1)', () {
    final report = runner.run();
    final enteral = report.cases
        .where(
          (c) =>
              c.scenarioId.startsWith('s37') || c.scenarioId.startsWith('s38'),
        )
        .toList();
    expect(enteral.length, 2);
    for (final c in enteral) {
      expect(c.pass, isTrue, reason: '${c.scenarioId}: ${c.failureReason}');
      expect(c.bannedPhraseHits, isEmpty);
    }
  });

  // A1/A2 — medication section provenance reaches the replay report.
  test('SPL IR scenario exposes section provenance + components (A1/A2)', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
      (c) => c.scenarioId == 's39_spl_ir_section_provenance',
    );
    expect(c.medicationSourceSystem, 'DailyMed');
    expect(c.medicationLabelSectionRefCount, greaterThan(0));
    expect(c.medicationReleaseType, 'immediate');
    expect(c.medicationReleaseTypeSource, 'structured_variant_metadata');
    expect(
      c.medicationCombinationComponents,
      containsAll(['carbidopa', 'levodopa']),
    );
    // Dose still came from the user/variant strength, never fabricated.
    expect(c.dosageSource, 'user_or_variant_strength');
    expect(c.dosageContextComplete, isTrue);
  });

  test(
    'SPL ER scenario records extended release from source metadata (A1/A2)',
    () {
      final report = runner.run();
      final c = report.cases.firstWhere(
        (c) => c.scenarioId == 's40_spl_er_section_provenance',
      );
      expect(c.medicationReleaseType, 'extended');
      expect(c.medicationReleaseTypeSource, 'structured_variant_metadata');
      expect(c.medicationLabelSectionRefCount, greaterThan(0));
    },
  );

  // Clinical-calibration guardrail regression (OPP-D4 / backlog #12). Locks in
  // the non-device educational boundary: every replay case must report it is
  // not clinically calibrated, must not enable live fetch by default, and must
  // not claim mechanism evidence it cannot support. If any case regresses this,
  // the boundary has been crossed and this test fails.
  test('every replay case preserves the clinical-calibration guardrail', () {
    final report = runner.run();
    expect(report.cases, isNotEmpty);
    for (final c in report.cases) {
      expect(
        c.clinicalCalibrationStatus,
        'not_clinically_calibrated',
        reason: '${c.scenarioId} must not claim clinical calibration',
      );
      expect(
        c.liveFetchEnabled,
        isFalse,
        reason: '${c.scenarioId} must not enable live fetch by default',
      );
      expect(
        c.canSupportMechanismEvidenceAlone,
        isFalse,
        reason:
            '${c.scenarioId} must not assert standalone mechanism '
            'evidence in the educational build',
      );
      expect(
        c.licenseReviewStatus,
        'future_work',
        reason: '${c.scenarioId} source license review remains future work',
      );
      expect(
        c.sourceImplementationStatus,
        'fixture_tested',
        reason:
            '${c.scenarioId} must remain fixture-tested (no production '
            'ingestion)',
      );
    }
  });
}
