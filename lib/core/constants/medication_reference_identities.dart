import '../../domain/entities/rxnorm_reference.dart';
import 'rxnorm_reference_table.dart';

/// Verified RxNorm identities for the default medication catalog.
///
/// Every RxCUI here is present in [rxnormReferenceRows] (verbatim NLM
/// RxNorm 2024-12-02 atoms) and `test/rxnorm_reference_table_test.dart`
/// checks that each one resolves to the expected term type and ingredient
/// name. A catalog entry that could not be verified is listed in
/// [unverifiedMedicationIdentities] with the reason, never given a guessed
/// code. Identity data only; nothing here is a dose or schedule.
const List<MedicationReferenceIdentity> medicationReferenceIdentities = [
  MedicationReferenceIdentity(
    drugId: 'drug_levodopa_carbidopa',
    ingredientRxcuis: [2019, 6375],
    clinicalDrugRxcuis: [197443, 197444, 197445, 308988, 308989],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_entacapone',
    ingredientRxcuis: [60307],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_tolcapone',
    ingredientRxcuis: [72937],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_selegiline',
    ingredientRxcuis: [9639],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_rasagiline',
    ingredientRxcuis: [134748],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_ropinirole',
    ingredientRxcuis: [72302],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_apomorphine',
    ingredientRxcuis: [1043],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_amantadine',
    ingredientRxcuis: [620],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_rivastigmine',
    ingredientRxcuis: [183379],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_midodrine',
    ingredientRxcuis: [6963],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_peg_3350',
    ingredientRxcuis: [221147],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_rotigotine',
    ingredientRxcuis: [616739],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_pramipexole',
    ingredientRxcuis: [746741],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_droxidopa',
    ingredientRxcuis: [1489913],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_pimavanserin',
    ingredientRxcuis: [1791685],
  ),
  MedicationReferenceIdentity(
    drugId: 'drug_istradefylline',
    ingredientRxcuis: [2199015],
  ),
  // The catalog keeps its DailyMed set id as the product code; the
  // ingredient identity is verified separately.
  MedicationReferenceIdentity(
    drugId: 'drug_opicapone',
    ingredientRxcuis: [2362167],
  ),
  // Fixed-dose combination: ingredients verified; the multiple-ingredient
  // and clinical-drug concepts were not.
  MedicationReferenceIdentity(
    drugId: 'drug_levodopa_entacapone',
    ingredientRxcuis: [2019, 6375, 60307],
  ),
];

const List<UnverifiedMedicationIdentity> unverifiedMedicationIdentities = [
  UnverifiedMedicationIdentity(
    'drug_safinamide',
    'No safinamide concept was found in the reviewed release windows, '
        'including those around its 2017 U.S. approval; the existing DailyMed '
        'set id is kept.',
  ),
  UnverifiedMedicationIdentity(
    'drug_iron',
    'Generic class entry ("iron supplement"); it names no single salt, so no '
        'single ingredient identity applies. Ferrous sulfate (RxCUI 24947) '
        'is available in the reference table for salt-specific entries.',
  ),
  UnverifiedMedicationIdentity(
    'drug_levodopa_benserazide',
    'Not marketed in the United States; RxNorm prescribable content does '
        'not cover it. A Health Canada DIN is still required.',
  ),
];

/// Rows of one RxCUI, in source order.
List<RxNormConceptRow> rxnormRowsFor(int rxcui) => [
  for (final row in rxnormReferenceRows)
    if (row.rxcui == rxcui) row,
];

/// Preferred RxNorm name of an ingredient or clinical drug.
String? rxnormNameFor(int rxcui) {
  for (final row in rxnormRowsFor(rxcui)) {
    if (row.sab == 'RXNORM' && (row.tty == 'IN' || row.tty == 'SCD')) {
      return row.str;
    }
  }
  return null;
}

/// FDA UNII of an ingredient, from its `MTHSPL/SU` atoms. Null when NLM
/// lists none or the atoms disagree.
String? uniiForIngredient(int rxcui) {
  final codes = {
    for (final row in rxnormRowsFor(rxcui))
      if (row.sab == 'MTHSPL' && row.tty == 'SU') row.code,
  };
  return codes.length == 1 ? codes.single : null;
}

/// Parsed clinical drug for an SCD RxCUI.
RxNormClinicalDrug? rxnormClinicalDrug(int rxcui) {
  final rows = rxnormRowsFor(rxcui);
  RxNormConceptRow? scd;
  for (final row in rows) {
    if (row.sab == 'RXNORM' && row.tty == 'SCD') scd = row;
  }
  if (scd == null) return null;
  final parsed = parseRxNormClinicalDrugName(scd.str);
  if (parsed == null) return null;
  final ndcs = {
    for (final row in rows)
      if (row.sab == 'MTHSPL' && row.tty == 'DP') row.code,
  }.toList()..sort();
  return RxNormClinicalDrug(
    rxcui: rxcui,
    name: scd.str,
    strengths: parsed.strengths,
    doseForm: parsed.doseForm,
    productNdcs: ndcs,
  );
}

MedicationReferenceIdentity? medicationReferenceIdentityFor(String drugId) {
  for (final identity in medicationReferenceIdentities) {
    if (identity.drugId == drugId) return identity;
  }
  return null;
}
