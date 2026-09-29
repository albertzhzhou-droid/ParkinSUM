import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'amino_acid_profile.dart';
import 'meal_composition.dart';
import 'mechanistic_event_ledger.dart';
import 'medication_entry_validation.dart';
import 'medication_source_metadata.dart';
import 'protein_source.dart';
import 'time_axis_events.dart';

const String mechanisticReplayCapsuleSchema =
    'parkinsum.mechanistic-replay-capsule/1';
const int mechanisticReplayCapsuleSchemaVersion = 1;
const String mechanisticReplayCanonicalizationProfile =
    'parkinsum.jcs-safe-lossless-scalars/1';
const String mechanisticReplayCrossRuntimeVectorsSchema =
    'parkinsum.mechanistic-replay-cross-runtime-vectors/1';
const int mechanisticReplayCrossRuntimeVectorsSchemaVersion = 1;
const String mechanisticReplayCrossRuntimeConformanceSchema =
    'parkinsum.mechanistic-replay-cross-runtime-conformance/1';
const int mechanisticReplayCrossRuntimeConformanceSchemaVersion = 1;

const String _numberMarker = r'$parkinsum_number';
const int _maxSafeInteger = 9007199254740991;

/// A self-contained, byte-stable replay envelope for the exact mechanistic
/// engine input. Numeric values inside the payload are never emitted as JSON
/// numbers: integers use canonical decimal strings and doubles use their exact
/// IEEE-754 binary64 bit pattern. This avoids runtime-specific number spelling
/// while preserving negative zero and every finite binary64 value.
final class MechanisticReplayCapsule {
  MechanisticReplayCapsule._({
    required this.capsuleId,
    required this.generatedAtUtc,
    required this.encodedLedger,
    required this.encodedContext,
    required this.encodedMealCompositions,
  }) {
    _requireSafeId(capsuleId, 'capsule_id');
    final parsedGeneratedAt = DateTime.tryParse(generatedAtUtc);
    if (parsedGeneratedAt == null ||
        !parsedGeneratedAt.isUtc ||
        parsedGeneratedAt.toIso8601String() != generatedAtUtc) {
      throw FormatException(
        'generated_at_utc must be a canonical UTC ISO-8601 timestamp.',
      );
    }
    _assertEncodedPayload(encodedLedger, 'ledger');
    _assertEncodedPayload(encodedContext, 'context');
    _assertEncodedPayload(encodedMealCompositions, 'meal_compositions');
  }

  final String capsuleId;
  final String generatedAtUtc;
  final Map<String, Object?> encodedLedger;
  final Map<String, Object?> encodedContext;
  final List<Object?> encodedMealCompositions;

  static const Map<String, Object?> timezoneContract = <String, Object?>{
    'timestamp_semantic': 'historical_event_instant',
    'engine_time_representation': 'utc_epoch_minute',
    'ledger_time_representation': 'offset_timestamp_plus_utc_instant',
    'iana_zone_id': null,
    'tzdb_version': null,
    'future_civil_time_authorized': false,
    'boundary':
        'The current engine consumes historical UTC minutes. Event-specific '
        'offsets survive in the embedded ledger, but no IANA zone, tzdb '
        'release, DST fold or future civil-time intent is fabricated.',
  };

  factory MechanisticReplayCapsule.capture({
    required String capsuleId,
    required DateTime generatedAtUtc,
    required MechanisticEventLedger ledger,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
  }) {
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError('Replay capsule generation time must be UTC.');
    }
    final binding = MechanisticLedgerInputBinding.compute(
      context: context,
      mealCompositionsById: mealCompositionsById,
    );
    if (binding != ledger.inputBindingSha256) {
      throw StateError(
        'Replay capsule input does not match the embedded ledger binding.',
      );
    }
    final ids = mealCompositionsById.keys.toList()..sort();
    return MechanisticReplayCapsule._(
      capsuleId: capsuleId,
      generatedAtUtc: generatedAtUtc.toIso8601String(),
      encodedLedger: _asObjectMap(
        _encodeLosslessScalars(ledger.toJson()),
        'encoded ledger',
      ),
      encodedContext: _asObjectMap(
        _encodeLosslessScalars(context.toJson()),
        'encoded context',
      ),
      encodedMealCompositions: <Object?>[
        for (final id in ids)
          <String, Object?>{
            'map_key': id,
            'composition': _encodeLosslessScalars(
              mealCompositionsById[id]!.toJson(),
            ),
          },
      ],
    );
  }

  factory MechanisticReplayCapsule.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schema',
      'schema_version',
      'canonicalization_profile',
      'capsule_id',
      'generated_at_utc',
      'timezone_contract',
      'ledger',
      'context',
      'meal_compositions',
      'capsule_sha256',
    }, 'replay capsule');
    if (json['schema'] != mechanisticReplayCapsuleSchema ||
        json['schema_version'] != mechanisticReplayCapsuleSchemaVersion) {
      throw const FormatException('Unsupported replay capsule schema.');
    }
    if (json['canonicalization_profile'] !=
        mechanisticReplayCanonicalizationProfile) {
      throw const FormatException(
        'Unsupported replay capsule canonicalization profile.',
      );
    }
    final suppliedTimezoneContract = _asObjectMap(
      json['timezone_contract'],
      'timezone_contract',
    );
    if (_canonicalJson(suppliedTimezoneContract) !=
        _canonicalJson(timezoneContract)) {
      throw const FormatException('Replay timezone contract drifted.');
    }
    final compositions = _asList(
      json['meal_compositions'],
      'meal_compositions',
    );
    final capsule = MechanisticReplayCapsule._(
      capsuleId: _string(json['capsule_id'], 'capsule_id'),
      generatedAtUtc: _string(json['generated_at_utc'], 'generated_at_utc'),
      encodedLedger: Map<String, Object?>.unmodifiable(
        _asObjectMap(json['ledger'], 'ledger'),
      ),
      encodedContext: Map<String, Object?>.unmodifiable(
        _asObjectMap(json['context'], 'context'),
      ),
      encodedMealCompositions: List<Object?>.unmodifiable(compositions),
    );
    if (json['capsule_sha256'] != capsule.capsuleSha256) {
      throw const FormatException('Replay capsule digest mismatch.');
    }
    return capsule;
  }

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'schema': mechanisticReplayCapsuleSchema,
    'schema_version': mechanisticReplayCapsuleSchemaVersion,
    'canonicalization_profile': mechanisticReplayCanonicalizationProfile,
    'capsule_id': capsuleId,
    'generated_at_utc': generatedAtUtc,
    'timezone_contract': timezoneContract,
    'ledger': encodedLedger,
    'context': encodedContext,
    'meal_compositions': encodedMealCompositions,
  };

  late final String capsuleSha256 = sha256
      .convert(utf8.encode(_canonicalJson(_bodyJson())))
      .toString();

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'capsule_sha256': capsuleSha256,
  };

  String get canonicalJson => _canonicalJson(toJson());

  MechanisticReplayRestoredInput restore({
    required String expectedConfigurationSha256,
  }) {
    _requireDigest(expectedConfigurationSha256, 'expected configuration');
    final ledgerJson = _asObjectMap(
      _decodeLosslessScalars(encodedLedger),
      'decoded ledger',
    );
    final contextJson = _asObjectMap(
      _decodeLosslessScalars(encodedContext),
      'decoded context',
    );
    final restoredLedger = MechanisticEventLedger.fromJson(ledgerJson);
    if (restoredLedger.configurationDigest != expectedConfigurationSha256) {
      throw StateError('Replay capsule configuration identity mismatch.');
    }
    final restoredContext = _timeAxisContextFromJson(contextJson);
    final restoredCompositions = <String, MealComposition>{};
    for (final value in encodedMealCompositions) {
      final entry = _asObjectMap(value, 'meal composition entry');
      _requireExactKeys(entry, const <String>{
        'map_key',
        'composition',
      }, 'meal composition entry');
      final mapKey = _string(entry['map_key'], 'meal composition map_key');
      if (restoredCompositions.containsKey(mapKey)) {
        throw FormatException('Duplicate meal composition key: $mapKey');
      }
      final decoded = _asObjectMap(
        _decodeLosslessScalars(entry['composition']),
        'decoded meal composition',
      );
      final composition = _mealCompositionFromJson(decoded);
      if (composition.id != mapKey) {
        throw FormatException(
          'Meal composition key/id mismatch: $mapKey/${composition.id}',
        );
      }
      restoredCompositions[mapKey] = composition;
    }
    final restoredBinding = MechanisticLedgerInputBinding.compute(
      context: restoredContext,
      mealCompositionsById: restoredCompositions,
    );
    if (restoredBinding != restoredLedger.inputBindingSha256) {
      throw StateError('Restored replay input does not match ledger binding.');
    }
    return MechanisticReplayRestoredInput(
      ledger: restoredLedger,
      context: restoredContext,
      mealCompositionsById: restoredCompositions,
      capsuleSha256: capsuleSha256,
    );
  }
}

final class MechanisticReplayRestoredInput {
  MechanisticReplayRestoredInput({
    required this.ledger,
    required this.context,
    required Map<String, MealComposition> mealCompositionsById,
    required this.capsuleSha256,
  }) : mealCompositionsById = Map<String, MealComposition>.unmodifiable(
         mealCompositionsById,
       );

  final MechanisticEventLedger ledger;
  final TimeAxisConflictContext context;
  final Map<String, MealComposition> mealCompositionsById;
  final String capsuleSha256;
}

Object? _encodeLosslessScalars(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is int) {
    if (value < -_maxSafeInteger || value > _maxSafeInteger) {
      throw ArgumentError('Integer exceeds the cross-runtime safe range.');
    }
    return <String, Object?>{_numberMarker: 'i64', 'value': value.toString()};
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError('Replay capsule values must be finite.');
    }
    final bytes = ByteData(8)..setFloat64(0, value, Endian.big);
    final hex = StringBuffer();
    for (var index = 0; index < 8; index++) {
      hex.write(bytes.getUint8(index).toRadixString(16).padLeft(2, '0'));
    }
    return <String, Object?>{_numberMarker: 'f64', 'value': hex.toString()};
  }
  if (value is List) {
    return <Object?>[for (final item in value) _encodeLosslessScalars(item)];
  }
  if (value is Map) {
    final output = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError('Replay capsule maps require string keys.');
      }
      final key = entry.key as String;
      if (key == _numberMarker) {
        throw ArgumentError('Source payload uses a reserved replay key.');
      }
      output[key] = _encodeLosslessScalars(entry.value);
    }
    return output;
  }
  throw ArgumentError('Unsupported replay value: ${value.runtimeType}');
}

Object? _decodeLosslessScalars(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) {
    throw const FormatException(
      'Native JSON numbers are forbidden inside the replay payload.',
    );
  }
  if (value is List) {
    return <Object?>[for (final item in value) _decodeLosslessScalars(item)];
  }
  if (value is Map) {
    final map = _asObjectMap(value, 'encoded payload object');
    if (map.containsKey(_numberMarker)) {
      _requireExactKeys(map, <String>{
        _numberMarker,
        'value',
      }, 'encoded number');
      final kind = _string(map[_numberMarker], _numberMarker);
      final encoded = _string(map['value'], 'encoded number value');
      if (kind == 'i64') {
        if (!RegExp(r'^-?(0|[1-9][0-9]*)$').hasMatch(encoded)) {
          throw const FormatException('Non-canonical integer encoding.');
        }
        final parsed = int.tryParse(encoded);
        if (parsed == null ||
            parsed < -_maxSafeInteger ||
            parsed > _maxSafeInteger) {
          throw const FormatException('Encoded integer is out of range.');
        }
        return parsed;
      }
      if (kind == 'f64') {
        if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(encoded)) {
          throw const FormatException('Non-canonical binary64 encoding.');
        }
        final bytes = ByteData(8);
        for (var index = 0; index < 8; index++) {
          bytes.setUint8(
            index,
            int.parse(encoded.substring(index * 2, index * 2 + 2), radix: 16),
          );
        }
        final parsed = bytes.getFloat64(0, Endian.big);
        if (!parsed.isFinite) {
          throw const FormatException('Non-finite binary64 is forbidden.');
        }
        return parsed;
      }
      throw FormatException('Unknown encoded number kind: $kind');
    }
    return <String, Object?>{
      for (final entry in map.entries)
        entry.key: _decodeLosslessScalars(entry.value),
    };
  }
  throw FormatException('Unsupported encoded value: ${value.runtimeType}');
}

void _assertEncodedPayload(Object? value, String label) {
  _decodeLosslessScalars(value);
  if (value is! Map && value is! List) {
    throw FormatException('$label must be an encoded object or array.');
  }
}

TimeAxisConflictContext _timeAxisContextFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'reference_minute',
    'medication_events',
    'meal_events',
    'food_component_events',
    'user_defined_window',
    'missing_fields',
  }, 'time-axis context');
  final context = TimeAxisConflictContext(
    referenceMinute: _integer(json['reference_minute'], 'reference_minute'),
    medicationEvents: <MedicationTimelineEvent>[
      for (final value in _asList(
        json['medication_events'],
        'medication_events',
      ))
        _medicationEventFromJson(_asObjectMap(value, 'medication event')),
    ],
    mealEvents: <MealTimelineEvent>[
      for (final value in _asList(json['meal_events'], 'meal_events'))
        _mealEventFromJson(_asObjectMap(value, 'meal event')),
    ],
    foodComponentEvents: <FoodComponentTimelineEvent>[
      for (final value in _asList(
        json['food_component_events'],
        'food_component_events',
      ))
        _foodComponentEventFromJson(
          _asObjectMap(value, 'food component event'),
        ),
    ],
    userDefinedWindow: json['user_defined_window'] == null
        ? null
        : _mealWindowFromJson(
            _asObjectMap(json['user_defined_window'], 'user_defined_window'),
          ),
    missingFields: _stringList(
      json['missing_fields'],
      'missing_fields',
    ).toSet(),
  );
  _assertJsonRoundTrip(json, context.toJson(), 'time-axis context');
  return context;
}

MedicationTimelineEvent _medicationEventFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'id',
    'minute',
    'kind',
    'context',
  }, 'medication event');
  if (json['kind'] != TimelineEventKind.medication.name) {
    throw const FormatException('Medication event kind mismatch.');
  }
  final event = MedicationTimelineEvent(
    id: _string(json['id'], 'medication event id'),
    minute: _integer(json['minute'], 'medication event minute'),
    context: _medicationContextFromJson(
      _asObjectMap(json['context'], 'medication context'),
    ),
  );
  _assertJsonRoundTrip(json, event.toJson(), 'medication event');
  return event;
}

NormalizedMedicationContext _medicationContextFromJson(
  Map<String, Object?> json,
) {
  _requireExactKeys(json, const <String>{
    'drug_product_variant',
    'active_ingredients',
    'form',
    'route',
    'release_type',
    'strength',
    'unit',
    'jurisdiction',
    'source_doc_id',
    'label_section',
    'extraction_confidence',
    'limitation_text',
    'metadata',
  }, 'medication context');
  final context = NormalizedMedicationContext(
    drugProductVariant: _string(
      json['drug_product_variant'],
      'drug_product_variant',
    ),
    activeIngredients: _stringList(
      json['active_ingredients'],
      'active_ingredients',
    ),
    form: _string(json['form'], 'form'),
    route: _string(json['route'], 'route'),
    releaseType: _string(json['release_type'], 'release_type'),
    strength: _number(json['strength'], 'strength'),
    unit: _string(json['unit'], 'unit'),
    jurisdiction: _string(json['jurisdiction'], 'jurisdiction'),
    sourceDocId: _string(json['source_doc_id'], 'source_doc_id'),
    labelSection: _nullableString(json['label_section'], 'label_section'),
    extractionConfidence: _nullableNumber(
      json['extraction_confidence'],
      'extraction_confidence',
    ),
    limitationText: _string(json['limitation_text'], 'limitation_text'),
    metadata: json['metadata'] == null
        ? null
        : _medicationMetadataFromJson(
            _asObjectMap(json['metadata'], 'medication metadata'),
          ),
  );
  _assertJsonRoundTrip(json, context.toJson(), 'medication context');
  return context;
}

MechanisticMedicationMetadata _medicationMetadataFromJson(
  Map<String, Object?> json,
) {
  _requireExactKeys(json, const <String>{
    'source_system',
    'source_doc_id',
    'source_doc_version',
    'effective_date',
    'jurisdiction',
    'language',
    'drug_product_variant_id',
    'dose_form',
    'route',
    'release_type',
    'release_type_source',
    'components',
    'label_section_refs',
    'source_refs',
    'limitation_text',
    'metadata_completeness',
    'missing_fields',
  }, 'medication metadata');
  final metadata = MechanisticMedicationMetadata(
    sourceSystem: _string(json['source_system'], 'source_system'),
    sourceDocId: _string(json['source_doc_id'], 'source_doc_id'),
    sourceDocVersion: _nullableString(
      json['source_doc_version'],
      'source_doc_version',
    ),
    effectiveDate: _nullableString(json['effective_date'], 'effective_date'),
    jurisdiction: _string(json['jurisdiction'], 'jurisdiction'),
    language: _string(json['language'], 'language'),
    drugProductVariantId: _nullableString(
      json['drug_product_variant_id'],
      'drug_product_variant_id',
    ),
    doseForm: _string(json['dose_form'], 'dose_form'),
    route: _string(json['route'], 'route'),
    releaseType: _string(json['release_type'], 'release_type'),
    releaseTypeSource: _string(
      json['release_type_source'],
      'release_type_source',
    ),
    components: <MedicationComponent>[
      for (final value in _asList(json['components'], 'components'))
        _medicationComponentFromJson(
          _asObjectMap(value, 'medication component'),
        ),
    ],
    labelSectionRefs: <LabelSectionRef>[
      for (final value in _asList(
        json['label_section_refs'],
        'label_section_refs',
      ))
        _labelSectionFromJson(_asObjectMap(value, 'label section')),
    ],
    sourceRefs: _stringList(json['source_refs'], 'source_refs'),
    limitationText: _string(json['limitation_text'], 'limitation_text'),
    metadataCompleteness: _string(
      json['metadata_completeness'],
      'metadata_completeness',
    ),
  );
  _assertJsonRoundTrip(json, metadata.toJson(), 'medication metadata');
  return metadata;
}

MedicationComponent _medicationComponentFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'ingredient_name',
    'role',
    'strength_value',
    'strength_unit',
    'source_refs',
    'extraction_confidence',
  }, 'medication component');
  final component = MedicationComponent(
    ingredientName: _string(json['ingredient_name'], 'ingredient_name'),
    role: _string(json['role'], 'role'),
    strengthValue: _nullableNumber(json['strength_value'], 'strength_value'),
    strengthUnit: _nullableString(json['strength_unit'], 'strength_unit'),
    sourceRefs: _stringList(json['source_refs'], 'source_refs'),
    extractionConfidence: _nullableNumber(
      json['extraction_confidence'],
      'extraction_confidence',
    ),
  );
  _assertJsonRoundTrip(json, component.toJson(), 'medication component');
  return component;
}

LabelSectionRef _labelSectionFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'source_system',
    'source_doc_id',
    'source_doc_version',
    'jurisdiction',
    'language',
    'section_id',
    'section_key',
    'section_title',
    'section_path',
    'effective_date',
    'extracted_field',
    'extracted_value',
    'extraction_confidence',
    'parser_name',
    'source_refs',
    'limitation_text',
  }, 'label section');
  final section = LabelSectionRef(
    sourceSystem: _string(json['source_system'], 'source_system'),
    sourceDocId: _string(json['source_doc_id'], 'source_doc_id'),
    sourceDocVersion: _nullableString(
      json['source_doc_version'],
      'source_doc_version',
    ),
    jurisdiction: _string(json['jurisdiction'], 'jurisdiction'),
    language: _string(json['language'], 'language'),
    sectionId: _string(json['section_id'], 'section_id'),
    sectionKey: _string(json['section_key'], 'section_key'),
    sectionTitle: _string(json['section_title'], 'section_title'),
    sectionPath: _nullableString(json['section_path'], 'section_path'),
    effectiveDate: _nullableString(json['effective_date'], 'effective_date'),
    extractedField: _nullableString(json['extracted_field'], 'extracted_field'),
    extractedValue: _nullableString(json['extracted_value'], 'extracted_value'),
    extractionConfidence: _nullableNumber(
      json['extraction_confidence'],
      'extraction_confidence',
    ),
    parserName: _nullableString(json['parser_name'], 'parser_name'),
    sourceRefs: _stringList(json['source_refs'], 'source_refs'),
    limitationText: _nullableString(json['limitation_text'], 'limitation_text'),
  );
  _assertJsonRoundTrip(json, section.toJson(), 'label section');
  return section;
}

MealTimelineEvent _mealEventFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'id',
    'minute',
    'kind',
    'composition_id',
    'duration_minutes',
    'physical_form',
  }, 'meal event');
  if (json['kind'] != TimelineEventKind.meal.name) {
    throw const FormatException('Meal event kind mismatch.');
  }
  final event = MealTimelineEvent(
    id: _string(json['id'], 'meal event id'),
    minute: _integer(json['minute'], 'meal event minute'),
    compositionId: _string(json['composition_id'], 'composition_id'),
    durationMinutes: _integer(json['duration_minutes'], 'duration_minutes'),
    physicalForm: _enumByName(
      MealPhysicalForm.values,
      json['physical_form'],
      'physical_form',
    ),
  );
  _assertJsonRoundTrip(json, event.toJson(), 'meal event');
  return event;
}

FoodComponentTimelineEvent _foodComponentEventFromJson(
  Map<String, Object?> json,
) {
  _requireExactKeys(json, const <String>{
    'id',
    'minute',
    'kind',
    'parent_meal_id',
    'food_component_id',
    'physical_form',
  }, 'food component event');
  if (json['kind'] != TimelineEventKind.foodComponent.name) {
    throw const FormatException('Food-component event kind mismatch.');
  }
  final event = FoodComponentTimelineEvent(
    id: _string(json['id'], 'food component event id'),
    minute: _integer(json['minute'], 'food component event minute'),
    parentMealId: _string(json['parent_meal_id'], 'parent_meal_id'),
    foodComponentId: _string(json['food_component_id'], 'food_component_id'),
    physicalForm: _enumByName(
      MealPhysicalForm.values,
      json['physical_form'],
      'physical_form',
    ),
  );
  _assertJsonRoundTrip(json, event.toJson(), 'food component event');
  return event;
}

UserDefinedMealWindow _mealWindowFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'window',
    'source',
  }, 'user-defined window');
  final windowJson = _asObjectMap(json['window'], 'window');
  _requireExactKeys(windowJson, const <String>{
    'start_minute',
    'end_minute',
  }, 'timeline window');
  final window = UserDefinedMealWindow(
    window: TimelineWindow(
      startMinute: _integer(windowJson['start_minute'], 'start_minute'),
      endMinute: _integer(windowJson['end_minute'], 'end_minute'),
    ),
    source: _string(json['source'], 'window source'),
  );
  _assertJsonRoundTrip(json, window.toJson(), 'user-defined window');
  return window;
}

MealComposition _mealCompositionFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'id',
    'total_calories',
    'protein_grams',
    'fat_grams',
    'fiber_grams',
    'carbohydrate_grams',
    'liquid_fraction',
    'meal_physical_form',
    'portion_size_band',
    'protein_amount_band',
    'fat_amount_band',
    'fiber_amount_band',
    'calorie_band',
    'composition_completeness',
    'missing_fields',
    'food_components',
  }, 'meal composition');
  final composition = MealComposition(
    id: _string(json['id'], 'meal composition id'),
    totalCalories: _nullableNumber(json['total_calories'], 'total_calories'),
    proteinGrams: _nullableNumber(json['protein_grams'], 'protein_grams'),
    fatGrams: _nullableNumber(json['fat_grams'], 'fat_grams'),
    fiberGrams: _nullableNumber(json['fiber_grams'], 'fiber_grams'),
    carbohydrateGrams: _nullableNumber(
      json['carbohydrate_grams'],
      'carbohydrate_grams',
    ),
    liquidFraction: _nullableNumber(json['liquid_fraction'], 'liquid_fraction'),
    mealPhysicalForm: _enumByName(
      MealPhysicalForm.values,
      json['meal_physical_form'],
      'meal_physical_form',
    ),
    portionSizeBand: _enumByName(
      PortionSizeBand.values,
      json['portion_size_band'],
      'portion_size_band',
    ),
    proteinAmountBand: _enumByName(
      AmountBand.values,
      json['protein_amount_band'],
      'protein_amount_band',
    ),
    fatAmountBand: _enumByName(
      AmountBand.values,
      json['fat_amount_band'],
      'fat_amount_band',
    ),
    fiberAmountBand: _enumByName(
      AmountBand.values,
      json['fiber_amount_band'],
      'fiber_amount_band',
    ),
    calorieBand: _enumByName(
      AmountBand.values,
      json['calorie_band'],
      'calorie_band',
    ),
    compositionCompleteness: _number(
      json['composition_completeness'],
      'composition_completeness',
    ),
    missingFields: _stringList(json['missing_fields'], 'missing_fields'),
    foodComponents: <FoodComponent>[
      for (final value in _asList(json['food_components'], 'food_components'))
        _foodComponentFromJson(_asObjectMap(value, 'food component')),
    ],
  );
  _assertJsonRoundTrip(json, composition.toJson(), 'meal composition');
  return composition;
}

FoodComponent _foodComponentFromJson(Map<String, Object?> json) {
  _requireExactKeys(json, const <String>{
    'id',
    'name',
    'physical_form',
    'protein_grams',
    'fat_grams',
    'fiber_grams',
    'carbohydrate_grams',
    'calories',
    'portion_grams',
    'source_doc_id',
    'protein_source',
    'amino_acid_profile',
  }, 'food component');
  final profileJson = json['amino_acid_profile'];
  final component = FoodComponent(
    id: _string(json['id'], 'food component id'),
    name: _string(json['name'], 'food component name'),
    physicalForm: _enumByName(
      MealPhysicalForm.values,
      json['physical_form'],
      'physical_form',
    ),
    proteinGrams: _nullableNumber(json['protein_grams'], 'protein_grams'),
    fatGrams: _nullableNumber(json['fat_grams'], 'fat_grams'),
    fiberGrams: _nullableNumber(json['fiber_grams'], 'fiber_grams'),
    carbohydrateGrams: _nullableNumber(
      json['carbohydrate_grams'],
      'carbohydrate_grams',
    ),
    calories: _nullableNumber(json['calories'], 'calories'),
    portionGrams: _nullableNumber(json['portion_grams'], 'portion_grams'),
    sourceDocId: _nullableString(json['source_doc_id'], 'source_doc_id'),
    proteinSource: _enumByName(
      ProteinSourceType.values,
      json['protein_source'],
      'protein_source',
    ),
    aminoAcidProfile: profileJson == null
        ? null
        : AminoAcidProfile.fromJson(
            _asDynamicMap(profileJson, 'amino_acid_profile'),
          ),
  );
  _assertJsonRoundTrip(json, component.toJson(), 'food component');
  return component;
}

void _assertJsonRoundTrip(
  Map<String, Object?> supplied,
  Map<String, dynamic> restored,
  String label,
) {
  if (_canonicalJson(supplied) != _canonicalJson(restored)) {
    throw FormatException('$label is not a lossless schema round trip.');
  }
}

Map<String, Object?> _asObjectMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  final output = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$label contains a non-string key.');
    }
    output[entry.key as String] = entry.value;
  }
  return output;
}

Map<String, dynamic> _asDynamicMap(Object? value, String label) =>
    _asObjectMap(value, label).cast<String, dynamic>();

List<Object?> _asList(Object? value, String label) {
  if (value is! List) throw FormatException('$label must be an array.');
  return value.cast<Object?>();
}

String _string(Object? value, String label) {
  if (value is! String) throw FormatException('$label must be a string.');
  return value;
}

String? _nullableString(Object? value, String label) =>
    value == null ? null : _string(value, label);

int _integer(Object? value, String label) {
  if (value is! int) throw FormatException('$label must be an integer.');
  return value;
}

double _number(Object? value, String label) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$label must be a finite number.');
  }
  return value.toDouble();
}

double? _nullableNumber(Object? value, String label) =>
    value == null ? null : _number(value, label);

List<String> _stringList(Object? value, String label) => <String>[
  for (final item in _asList(value, label)) _string(item, '$label item'),
];

T _enumByName<T extends Enum>(List<T> values, Object? value, String label) {
  final name = _string(value, label);
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  throw FormatException('$label has unsupported value: $name');
}

void _requireExactKeys(
  Map<String, Object?> json,
  Set<String> expected,
  String label,
) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length ||
      !actual.containsAll(expected) ||
      !expected.containsAll(actual)) {
    final missing = expected.difference(actual).toList()..sort();
    final extra = actual.difference(expected).toList()..sort();
    throw FormatException(
      '$label keys mismatch; missing=${missing.join(',')}; '
      'extra=${extra.join(',')}',
    );
  }
}

void _requireSafeId(String value, String label) {
  if (!RegExp(r'^[A-Za-z0-9._:-]{1,160}$').hasMatch(value)) {
    throw ArgumentError('$label is not a safe stable identifier.');
  }
}

void _requireDigest(String value, String label) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw ArgumentError('$label must be a lowercase SHA-256 digest.');
  }
}

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw ArgumentError('Canonical JSON object keys must be strings.');
      }
      return key;
    }).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value == null || value is String || value is bool || value is num) {
    return jsonEncode(value);
  }
  throw ArgumentError('Unsupported canonical JSON value: ${value.runtimeType}');
}
