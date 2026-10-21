import '../../data/datasources/remote/amino_acid_extractor.dart';
import '../../data/datasources/remote/fdc_nutrient_definitions.dart';
import '../../domain/entities/amino_acid_profile.dart';
import '../../domain/entities/reference_food_nutrient_profile.dart';
import '../models/food_item.dart';
import 'reference_food_nutrient_profile_table.dart';

/// Lookups over the official FoodData Central 2025-04-24 records of the SR
/// Legacy reference and seed foods.
///
/// Every value comes from [referenceNutrientRecords] or
/// [referencePortionRecords] unchanged. Nothing is estimated: a nutrient the
/// source does not report is absent from every map returned here.

const String referenceNutrientSourceDocId =
    'src.usda.fdc.full_download.2025_04_24';

final Map<int, List<ReferenceNutrientRecord>> _nutrientsByFood = () {
  final byFood = <int, List<ReferenceNutrientRecord>>{};
  for (final record in referenceNutrientRecords) {
    byFood.putIfAbsent(record.fdcId, () => []).add(record);
  }
  return {
    for (final entry in byFood.entries)
      entry.key: List<ReferenceNutrientRecord>.unmodifiable(entry.value),
  };
}();

final Map<int, List<ReferencePortionRecord>> _portionsByFood = () {
  final byFood = <int, List<ReferencePortionRecord>>{};
  for (final record in referencePortionRecords) {
    byFood.putIfAbsent(record.fdcId, () => []).add(record);
  }
  return byFood;
}();

final Map<int, FdcDerivationCode> _derivationsById = {
  for (final code in fdcDerivationCodes) code.id: code,
};

final Map<int, FdcNutrientDefinition> _definitionsById = {
  for (final definition in fdcNutrientDefinitions) definition.id: definition,
};

/// SR Legacy foods that carry official FDC 2025 nutrient records.
Iterable<int> get referenceNutrientProfileFoods => _nutrientsByFood.keys;

/// Official nutrient records of one food, in source order. Empty when the
/// food is not in the reference set.
List<ReferenceNutrientRecord> referenceNutrientRecordsFor(int fdcId) =>
    _nutrientsByFood[fdcId] ?? const [];

/// Official portion records of one food, in source order.
List<ReferencePortionRecord> referencePortionRecordsFor(int fdcId) =>
    _portionsByFood[fdcId] ?? const [];

FdcDerivationCode? fdcDerivationCodeFor(int? derivationId) =>
    derivationId == null ? null : _derivationsById[derivationId];

/// Values keyed by the app's nutrient attribute codes (see
/// `fdc_nutrient_definitions.dart`), in each definition's own unit.
Map<String, double> referenceAttributeValues(int fdcId) => {
  for (final record in referenceNutrientRecordsFor(fdcId))
    if (_definitionsById[record.nutrientId] case final definition?)
      definition.attributeCode: record.amount,
};

/// FDC derivation code per attribute code, for values whose source row
/// names one (for example `NC` "Calculated", `Z` "Assumed zero").
Map<String, String> referenceAttributeDerivationCodes(int fdcId) => {
  for (final record in referenceNutrientRecordsFor(fdcId))
    if (_definitionsById[record.nutrientId] case final definition?)
      if (fdcDerivationCodeFor(record.derivationId) case final derivation?)
        definition.attributeCode: derivation.code,
};

/// Water in g per 100 g, when the source reports it.
double? referenceWaterG(int fdcId) =>
    referenceAttributeValues(fdcId)['water_g'];

/// Amino-acid profile built from the official rows by the same extractor the
/// FDC importer uses, including per-nutrient derivation provenance.
AminoAcidProfile? referenceAminoAcidProfile(int fdcId) {
  final records = referenceNutrientRecordsFor(fdcId);
  if (records.isEmpty) return null;
  final foodNutrients = <Map<String, Object?>>[];
  for (final record in records) {
    final number = _aminoAcidNumbers[record.nutrientId];
    if (number == null) continue;
    final derivation = fdcDerivationCodeFor(record.derivationId);
    foodNutrients.add({
      'nutrient': {
        'id': record.nutrientId,
        'number': number,
        'name': _aminoAcidNames[record.nutrientId],
        'unitName': 'G',
      },
      'amount': record.amount,
      'dataPoints': ?record.dataPoints,
      'min': ?record.min,
      'max': ?record.max,
      'median': ?record.median,
      if (derivation != null)
        'foodNutrientDerivation': {
          'code': derivation.code,
          'description': derivation.description,
        },
    });
  }
  if (foodNutrients.isEmpty) return null;
  return AminoAcidExtractor().extractFromFdcStyle(
    {
      'dataType': 'SR Legacy',
      'basisType': 'per_100g',
      'foodNutrients': foodNutrients,
    },
    sourceRefs: const [referenceNutrientSourceDocId],
  );
}

/// Official portion records as catalog evidence. The next-meal serving rule
/// may select one as a candidate's reference serving; a portion never
/// changes the stored per-100 g nutrient values.
List<FoodPortionEvidence> referencePortionEvidence(int fdcId) => [
  for (final record in referencePortionRecordsFor(fdcId))
    FoodPortionEvidence(
      sourceDocId: referenceNutrientSourceDocId,
      sourceFoodId: '$fdcId',
      recordLocator: 'food_portion.csv:${record.rowId}',
      sequenceNumber: record.sequenceNumber,
      amount: record.amount,
      measureUnitId: record.measureUnitId,
      // FDC measure unit 9999 is "undetermined"; the unit lives in the
      // modifier text, so no unit name is invented here.
      measureUnitName: null,
      measureUnitAbbreviation: null,
      portionDescription: record.portionDescription.isEmpty
          ? null
          : record.portionDescription,
      modifier: record.modifier.isEmpty ? null : record.modifier,
      gramWeight: record.gramWeight,
      dataPoints: record.dataPoints,
      footnote: null,
      minYearAcquired: record.minYearAcquired,
      sourceFields: {
        'id': record.rowId,
        'fdc_id': record.fdcId,
        'seq_num': record.sequenceNumber,
        'amount': record.amount,
        'measure_unit_id': record.measureUnitId,
        'portion_description': record.portionDescription,
        'modifier': record.modifier,
        'gram_weight': record.gramWeight,
        'data_points': record.dataPoints,
        'min_year_acquired': record.minYearAcquired,
      },
    ),
];

/// FDC legacy numbers of the amino acids (`nutrient.csv`, release
/// 2025-04-24). The extractor maps numbers to profile fields.
const Map<int, String> _aminoAcidNumbers = {
  1210: '501',
  1211: '502',
  1212: '503',
  1213: '504',
  1214: '505',
  1215: '506',
  1216: '507',
  1217: '508',
  1218: '509',
  1219: '510',
  1220: '511',
  1221: '512',
  1222: '513',
  1223: '514',
  1224: '515',
  1225: '516',
  1226: '517',
  1227: '518',
};

const Map<int, String> _aminoAcidNames = {
  1210: 'Tryptophan',
  1211: 'Threonine',
  1212: 'Isoleucine',
  1213: 'Leucine',
  1214: 'Lysine',
  1215: 'Methionine',
  1216: 'Cystine',
  1217: 'Phenylalanine',
  1218: 'Tyrosine',
  1219: 'Valine',
  1220: 'Arginine',
  1221: 'Histidine',
  1222: 'Alanine',
  1223: 'Aspartic acid',
  1224: 'Glutamic acid',
  1225: 'Glycine',
  1226: 'Proline',
  1227: 'Serine',
};
