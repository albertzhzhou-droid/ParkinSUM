import 'dart:convert';

import '../../data/datasources/remote/amino_acid_extractor.dart';
import '../entities/amino_acid_profile.dart';

/// Black-box observations from the production FDC amino-acid extractor.
///
/// Expected values deliberately live in the independent verification gate,
/// not here. This probe executes manufactured FDC-shaped payloads through the
/// production extractor and records primitive outputs. No network or file I/O
/// is performed.
final class AminoAcidExtractionInvariantProbe {
  static const int probeVersion = 1;
  static const String probeId = 'amino-acid-extraction.black-box-production/1';

  AminoAcidExtractionInvariantProbe._({
    required Map<String, Object?> observations,
  }) : observations = Map<String, Object?>.unmodifiable(observations);

  factory AminoAcidExtractionInvariantProbe.capture({
    AminoAcidExtractor? extractor,
  }) {
    final production = extractor ?? AminoAcidExtractor();
    var invocationCount = 0;

    AminoAcidProfile? run(Map<String, dynamic> payload) {
      invocationCount++;
      return production.extractFromFdcStyle(payload);
    }

    Map<String, Object?> nutrient({
      String? number,
      String? name,
      String? unitName,
      required Object? amount,
    }) => <String, Object?>{
      'nutrient': <String, Object?>{
        'number': ?number,
        'name': ?name,
        'unitName': ?unitName,
      },
      'amount': amount,
    };

    final grams = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', unitName: 'G', amount: 2.1),
      ],
    });
    final milligrams = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', unitName: 'MG', amount: 2100),
      ],
    });
    final zero = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', unitName: 'G', amount: 0),
      ],
    });
    final missing = run(<String, dynamic>{
      'foodNutrients': const <Map<String, Object?>>[],
    });
    final missingUnit = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', name: 'Leucine', amount: 2.1),
        nutrient(number: '501', unitName: 'G', amount: 0.3),
      ],
    });
    final unknownUnit = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', unitName: 'lb', amount: 2.1),
        nutrient(number: '501', unitName: 'G', amount: 0.3),
      ],
    });
    final invalidAmounts = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', unitName: 'G', amount: -2.1),
        nutrient(number: '503', unitName: 'G', amount: double.nan),
        nutrient(number: '510', unitName: 'G', amount: double.infinity),
        nutrient(number: '508', unitName: 'G', amount: 'not-a-number'),
        nutrient(number: '501', unitName: 'G', amount: 0.3),
      ],
    });
    final heldOnly = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', amount: 2.1),
      ],
    });
    final duplicateRows = <Map<String, Object?>>[
      nutrient(number: '501', unitName: 'G', amount: 0.3),
      nutrient(number: '504', unitName: 'G', amount: 2.0),
      nutrient(number: '504', unitName: 'G', amount: 2.1),
    ];
    final duplicateForward = run(<String, dynamic>{
      'foodNutrients': duplicateRows,
    });
    final duplicateReverse = run(<String, dynamic>{
      'foodNutrients': duplicateRows.reversed.toList(growable: false),
    });
    final numberPriority = run(<String, dynamic>{
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '504', name: 'Valine', unitName: 'G', amount: 2.0),
      ],
    });
    final canonical = run(<String, dynamic>{
      'basisType': '  per_100g  ',
      'dataType': '  Foundation  ',
      'foodNutrients': <Map<String, Object?>>[
        nutrient(number: '501', unitName: 'G', amount: 0.3),
        nutrient(number: '509', unitName: 'G', amount: 0.9),
        nutrient(number: '508', unitName: 'G', amount: 1.0),
        nutrient(number: '510', unitName: 'G', amount: 1.3),
        nutrient(number: '503', unitName: 'G', amount: 1.2),
        nutrient(number: '504', unitName: 'G', amount: 2.1),
      ],
    });

    return AminoAcidExtractionInvariantProbe._(
      observations: <String, Object?>{
        'probe.version': probeVersion,
        'probe.invocation_count': invocationCount,
        'units.grams.leucine_g': grams?.leucine,
        'units.milligrams.leucine_g': milligrams?.leucine,
        'units.equivalent':
            grams?.leucine != null && grams!.leucine == milligrams?.leucine,
        'units.canonical_unit': milligrams?.unit,
        'zero.profile_present': zero != null,
        'zero.leucine_g': zero?.leucine,
        'missing.profile_absent': missing == null,
        'unit.missing.held': missingUnit?.leucine == null,
        'unit.missing.partial': missingUnit?.partial,
        'unit.missing.competing_g': missingUnit?.competingLnaaGrams,
        'unit.unknown.held': unknownUnit?.leucine == null,
        'unit.unknown.partial': unknownUnit?.partial,
        'unit.unknown.competing_g': unknownUnit?.competingLnaaGrams,
        'invalid.profile_partial': invalidAmounts?.partial,
        'invalid.negative.held': invalidAmounts?.leucine == null,
        'invalid.nan.held': invalidAmounts?.isoleucine == null,
        'invalid.infinity.held': invalidAmounts?.valine == null,
        'invalid.non_numeric.held': invalidAmounts?.phenylalanine == null,
        'invalid.competing_g': invalidAmounts?.competingLnaaGrams,
        'held_only.profile_present': heldOnly != null,
        'held_only.field_null': heldOnly?.leucine == null,
        'held_only.partial': heldOnly?.partial,
        'held_only.competing_g': heldOnly?.competingLnaaGrams,
        'duplicate.forward.held': duplicateForward?.leucine == null,
        'duplicate.reverse.held': duplicateReverse?.leucine == null,
        'duplicate.profile_partial': duplicateForward?.partial,
        'duplicate.permutation_stable':
            jsonEncode(duplicateForward?.toJson()) ==
            jsonEncode(duplicateReverse?.toJson()),
        'identity.number_priority.leucine_g': numberPriority?.leucine,
        'identity.number_priority.valine_missing':
            numberPriority?.valine == null,
        'ordering.nutrient_ids': canonical?.nutrientIds,
        'metadata.basis': canonical?.basis,
        'metadata.data_type': canonical?.fdcDataType,
      },
    );
  }

  final Map<String, Object?> observations;

  AminoAcidExtractionInvariantProbe withObservation(
    String key,
    Object? value,
  ) => AminoAcidExtractionInvariantProbe._(
    observations: <String, Object?>{...observations, key: value},
  );

  AminoAcidExtractionInvariantProbe withoutObservation(String key) =>
      AminoAcidExtractionInvariantProbe._(
        observations: <String, Object?>{...observations}..remove(key),
      );
}
