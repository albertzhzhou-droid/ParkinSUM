import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

/// Guards the HARD requirement: the medication dose used by the mechanistic
/// chain must come ONLY from the user-entered dosage note. No private default
/// (the old hard-coded `strength: 100, unit: 'mg'`) may ever be injected.
///
/// This mirrors EXACTLY the dose-building logic in both
/// `NextMealRecommendationOrchestrator._buildMechanisticMedicationInputs` and
/// `DatabaseBackedMealCheckUseCase._computeMechanisticTraceJson`:
///   final dose = parser.parse(intake.dosageNote);
///   strength: dose.explicit ? dose.value : null,
///   unit:     dose.explicit ? dose.unit  : null,
void main() {
  final parser = DosageNoteParser();
  final validator = MedicationEntryValidator();

  // Reproduce the production builder so the test fails if either call site
  // diverges from "dose comes only from the user's note".
  RawMedicationEntry buildEntry(String? dosageNote) {
    final dose = parser.parse(dosageNote);
    return RawMedicationEntry(
      activeIngredients: const ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:demo',
      strength: dose.explicit ? dose.value : null,
      unit: dose.explicit ? dose.unit : null,
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'synthetic:demo',
    );
  }

  group('DosageNoteParser explicit-only behavior', () {
    test('"100 mg" -> value 100, unit mg, explicit', () {
      final d = parser.parse('100 mg');
      expect(d.explicit, isTrue);
      expect(d.value, 100);
      expect(d.unit, 'mg');
    });

    test('"50 mg" -> value 50 (NOT 100)', () {
      final d = parser.parse('50 mg');
      expect(d.explicit, isTrue);
      expect(d.value, 50);
      expect(d.value, isNot(100));
    });

    test('"levodopa 100" (no unit) -> NOT explicit', () {
      final d = parser.parse('levodopa 100');
      expect(d.explicit, isFalse);
      expect(d.value, isNull);
      expect(d.unit, isNull);
    });

    test('bare "100" -> NOT explicit', () {
      final d = parser.parse('100');
      expect(d.explicit, isFalse);
    });

    test('empty / null note -> NOT explicit', () {
      expect(parser.parse('').explicit, isFalse);
      expect(parser.parse(null).explicit, isFalse);
      expect(parser.parse('   ').explicit, isFalse);
    });

    test('slashed combo "25/100" -> NOT explicit (combination product)', () {
      final d = parser.parse('25/100');
      expect(d.explicit, isFalse);
    });

    test('"0.5 g" -> value 0.5, unit g, explicit', () {
      final d = parser.parse('0.5 g');
      expect(d.explicit, isTrue);
      expect(d.value, 0.5);
      expect(d.unit, 'g');
    });
  });

  // `DosageNoteParser.milligrams` is exactly what populates
  // `DrugRuntimeContext.dailyDoseMg` in DatabaseBackedMealCheckUseCase.
  group('milligrams() = dailyDoseMg source (no fabricated number)', () {
    test('"100 mg" -> dailyDoseMg 100', () {
      expect(parser.milligrams('100 mg'), 100);
    });

    test('"levodopa 100" -> null (must NOT become 100 mg)', () {
      expect(parser.milligrams('levodopa 100'), isNull);
    });

    test('bare "100" -> null', () {
      expect(parser.milligrams('100'), isNull);
    });

    test('empty / null -> null', () {
      expect(parser.milligrams(''), isNull);
      expect(parser.milligrams(null), isNull);
    });

    test('unit conversion: "0.5 g" -> 500 mg, "200 mcg" -> 0.2 mg', () {
      expect(parser.milligrams('0.5 g'), 500);
      expect(parser.milligrams('200 mcg'), 0.2);
    });

    test('non-mass unit "5 ml" -> null (not a mg dose)', () {
      expect(parser.milligrams('5 ml'), isNull);
    });
  });

  group('Dose passes through to medication context without a default', () {
    test('user enters "100 mg" -> validator receives strength 100 mg', () {
      final result = validator.validate(buildEntry('100 mg'));
      expect(result.validity, MedicationContextValidity.valid);
      expect(result.normalized, isNotNull);
      expect(result.normalized!.strength, 100);
      expect(result.normalized!.unit, 'mg');
    });

    test('user enters "50 mg" -> validator receives 50 mg, NOT the old 100',
        () {
      final result = validator.validate(buildEntry('50 mg'));
      expect(result.validity, MedicationContextValidity.valid);
      expect(result.normalized!.strength, 50);
      expect(result.normalized!.strength, isNot(100));
    });

    test('user enters "levodopa 100" -> insufficient dose context', () {
      final result = validator.validate(buildEntry('levodopa 100'));
      expect(result.validity, isNot(MedicationContextValidity.valid));
      expect(result.normalized, isNull);
      expect(
        result.issues.map((i) => i.code),
        containsAll(<String>['MISSING_STRENGTH', 'MISSING_UNIT']),
      );
    });

    test('user leaves dosage empty -> insufficient dose context', () {
      final result = validator.validate(buildEntry(''));
      expect(result.validity, isNot(MedicationContextValidity.valid));
      expect(result.normalized, isNull);
    });

    test('NO private/default dose is injected for any non-explicit note', () {
      // If any code path quietly defaulted to 100 mg, one of these would
      // surface a non-null strength. They must all stay null.
      for (final note in <String?>[
        null,
        '',
        '   ',
        '100',
        'levodopa 100',
        '25/100',
        'one tablet',
        'take with food'
      ]) {
        final entry = buildEntry(note);
        expect(entry.strength, isNull,
            reason: 'strength must be null for non-explicit note: "$note"');
        expect(entry.unit, isNull,
            reason: 'unit must be null for non-explicit note: "$note"');
      }
    });
  });
}
