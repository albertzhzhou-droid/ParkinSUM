/// Declarative RxNorm reference rows used to give catalog medications
/// verified identities.
///
/// Rows are copied verbatim from the U.S. National Library of Medicine
/// RxNorm release of 2 December 2024 (Current Prescribable Content,
/// `RXNCONSO.RRF`). Each selected concept is kept as a complete block: every
/// atom NLM lists for that RxCUI, including the FDA UNII codes carried by
/// `MTHSPL/SU` atoms and the NDC product codes carried by `MTHSPL/DP` atoms.
///
/// Identity data only. Nothing here is a dose, schedule or recommendation.
library;

/// One `RXNCONSO.RRF` atom (the fields this app uses, verbatim).
class RxNormConceptRow {
  final int rxcui;
  final int rxaui;

  /// Source abbreviation (`RXNORM`, `MTHSPL`).
  final String sab;

  /// Term type (`IN`, `PIN`, `SCD`, `PSN`, `SY`, `TMSY`, `SU`, `DP`, ...).
  final String tty;

  /// Source code: the RxCUI for RXNORM atoms, the UNII for `MTHSPL/SU`, the
  /// product NDC (labeler-product) for `MTHSPL/DP`.
  final String code;
  final String str;

  const RxNormConceptRow({
    required this.rxcui,
    required this.rxaui,
    required this.sab,
    required this.tty,
    required this.code,
    required this.str,
  });
}

/// One parsed ingredient strength of an RxNorm clinical drug name.
class RxNormStrength {
  final String ingredient;
  final double amount;
  final String unit;

  const RxNormStrength(this.ingredient, this.amount, this.unit);
}

/// An RxNorm semantic clinical drug (SCD): ingredients, strengths and dose
/// form in one normalized name.
class RxNormClinicalDrug {
  final int rxcui;
  final String name;
  final List<RxNormStrength> strengths;
  final String doseForm;

  /// NDC labeler-product codes NLM links to this clinical drug.
  final List<String> productNdcs;

  const RxNormClinicalDrug({
    required this.rxcui,
    required this.name,
    required this.strengths,
    required this.doseForm,
    required this.productNdcs,
  });

  /// Release profile implied by the RxNorm dose form. RxNorm models
  /// extended- and delayed-release forms as distinct dose forms, so a plain
  /// "Oral Tablet" is a conventional (immediate-release) tablet.
  String get releaseType => releaseTypeForRxNormDoseForm(doseForm);

  /// Route and form vocabulary used by the medication catalog.
  String get route => doseForm.contains('Oral') ? 'oral' : 'unspecified';
  String get dosageForm => doseForm.endsWith('Tablet')
      ? 'tablet'
      : doseForm.endsWith('Capsule')
      ? 'capsule'
      : 'unspecified';
}

/// Dose forms whose release profile RxNorm encodes explicitly.
String releaseTypeForRxNormDoseForm(String doseForm) {
  final lower = doseForm.toLowerCase();
  if (lower.contains('extended release')) return 'extended_release';
  if (lower.contains('delayed release')) return 'delayed_release';
  if (lower.contains('disintegrating')) return 'orally_disintegrating';
  if (lower == 'oral tablet' || lower == 'oral capsule') {
    return 'immediate_release';
  }
  return 'unspecified';
}

final RegExp _strengthPattern = RegExp(
  r'^(.+?) ([0-9]+(?:\.[0-9]+)?) (MG|MCG|G|MG/ML|UNT)$',
);

/// Parses an SCD name such as
/// `carbidopa 25 MG / levodopa 100 MG Extended Release Oral Tablet`.
/// Returns null when the name does not follow the SCD pattern.
({List<RxNormStrength> strengths, String doseForm})?
parseRxNormClinicalDrugName(String name) {
  const doseForms = [
    'Extended Release Oral Tablet',
    'Extended Release Oral Capsule',
    'Delayed Release Oral Tablet',
    'Delayed Release Oral Capsule',
    'Disintegrating Oral Tablet',
    'Chewable Tablet',
    'Oral Tablet',
    'Oral Capsule',
  ];
  for (final form in doseForms) {
    if (!name.endsWith(' $form')) continue;
    final body = name.substring(0, name.length - form.length - 1);
    final strengths = <RxNormStrength>[];
    for (final part in body.split(' / ')) {
      final match = _strengthPattern.firstMatch(part.trim());
      if (match == null) return null;
      strengths.add(
        RxNormStrength(
          match.group(1)!,
          double.parse(match.group(2)!),
          match.group(3)!,
        ),
      );
    }
    return (strengths: strengths, doseForm: form);
  }
  return null;
}

/// Verified RxNorm identity of one catalog medication.
class MedicationReferenceIdentity {
  /// `DrugDefinition.id` in the default medication catalog.
  final String drugId;

  /// RxNorm ingredient (IN) concepts of every active moiety.
  final List<int> ingredientRxcuis;

  /// Clinical drugs (SCD) verified for this catalog entry, if any.
  final List<int> clinicalDrugRxcuis;

  const MedicationReferenceIdentity({
    required this.drugId,
    required this.ingredientRxcuis,
    this.clinicalDrugRxcuis = const [],
  });
}

/// A catalog medication whose RxNorm identity was not verified, and why.
class UnverifiedMedicationIdentity {
  final String drugId;
  final String reason;

  const UnverifiedMedicationIdentity(this.drugId, this.reason);
}
