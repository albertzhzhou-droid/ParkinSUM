import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/constants/medication_reference_identities.dart';
import 'package:parkinsum_companion/core/constants/rxnorm_reference_table.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';

import '../tool/rxnorm_reference_codegen.dart';

/// Medication identities must come from NLM RxNorm verbatim. Identity data
/// only; nothing here is a dose, schedule or recommendation.
void main() {
  final rrfText = File(rxnormSubsetPath).readAsStringSync();
  final sourceRows = parseRxnconso(rrfText);

  test('the committed RxNorm subset keeps its verified bytes', () {
    expect(
      sha256.convert(File(rxnormSubsetPath).readAsBytesSync()).toString(),
      '7b8eb0a92a4991badd222ff52e40c2653dd95e2d01082cc79d600b5e051228a3',
    );
  });

  test('generated table reproduces every source atom exactly', () {
    expect(rxnormReferenceRows, hasLength(sourceRows.length));
    for (var i = 0; i < sourceRows.length; i++) {
      final source = sourceRows[i];
      final row = rxnormReferenceRows[i];
      expect(row.rxcui, source.rxcui);
      expect(row.rxaui, source.rxaui);
      expect(row.sab, source.sab);
      expect(row.tty, source.tty);
      expect(row.code, source.code);
      expect(row.str, source.str);
    }
  });

  test('catalog ingredients resolve to RxNorm ingredients with one UNII', () {
    const expectedNames = {
      'drug_levodopa_carbidopa': ['carbidopa', 'levodopa'],
      'drug_entacapone': ['entacapone'],
      'drug_tolcapone': ['tolcapone'],
      'drug_selegiline': ['selegiline'],
      'drug_rasagiline': ['rasagiline'],
      'drug_ropinirole': ['ropinirole'],
      'drug_apomorphine': ['apomorphine'],
      'drug_amantadine': ['amantadine'],
      'drug_rivastigmine': ['rivastigmine'],
      'drug_midodrine': ['midodrine'],
      'drug_peg_3350': ['polyethylene glycol 3350'],
      'drug_rotigotine': ['rotigotine'],
      'drug_pramipexole': ['pramipexole'],
      'drug_droxidopa': ['droxidopa'],
      'drug_pimavanserin': ['pimavanserin'],
      'drug_istradefylline': ['istradefylline'],
      'drug_opicapone': ['opicapone'],
      'drug_levodopa_entacapone': ['carbidopa', 'levodopa', 'entacapone'],
    };
    for (final identity in medicationReferenceIdentities) {
      final names = [
        for (final rxcui in identity.ingredientRxcuis) rxnormNameFor(rxcui),
      ];
      expect(names, expectedNames[identity.drugId], reason: identity.drugId);
      for (final rxcui in identity.ingredientRxcuis) {
        expect(
          rxnormRowsFor(
            rxcui,
          ).where((row) => row.sab == 'RXNORM' && row.tty == 'IN'),
          hasLength(1),
          reason: '$rxcui',
        );
        expect(uniiForIngredient(rxcui), isNotNull, reason: '$rxcui');
      }
    }
    // Spot checks against the FDA UNII atoms in the source.
    expect(uniiForIngredient(6375), '46627O600J');
    expect(uniiForIngredient(2019), 'MNX7R8C5VO');
    expect(uniiForIngredient(60307), '4975G9NM6T');
    expect(uniiForIngredient(134748), '003N66TS6T');
    expect(uniiForIngredient(746741), '83619PEU5T');
    expect(uniiForIngredient(616739), '87T4T8BO2E');
    expect(uniiForIngredient(1489913), 'J7A92W69L7');
    expect(uniiForIngredient(1791685), 'JZ963P0DIK');
    expect(uniiForIngredient(2199015), '2GZ0LIK7T4');
    expect(uniiForIngredient(2362167), 'Y5929UIJ5N');
  });

  test('clinical drugs parse into strengths, dose form and release type', () {
    final ir = rxnormClinicalDrug(197444)!;
    expect(ir.name, 'carbidopa 25 MG / levodopa 100 MG Oral Tablet');
    expect(ir.strengths.map((s) => '${s.ingredient} ${s.amount} ${s.unit}'), [
      'carbidopa 25.0 MG',
      'levodopa 100.0 MG',
    ]);
    expect(ir.doseForm, 'Oral Tablet');
    expect(ir.releaseType, 'immediate_release');
    expect(ir.productNdcs, contains('0378-0085'));

    final er = rxnormClinicalDrug(308989)!;
    expect(er.doseForm, 'Extended Release Oral Tablet');
    expect(er.releaseType, 'extended_release');
    expect(er.strengths.last.amount, 200.0);

    // Every verified clinical drug contains each of its parent's ingredients.
    for (final identity in medicationReferenceIdentities) {
      final ingredients = {
        for (final rxcui in identity.ingredientRxcuis) rxnormNameFor(rxcui),
      };
      for (final rxcui in identity.clinicalDrugRxcuis) {
        final drug = rxnormClinicalDrug(rxcui);
        expect(drug, isNotNull, reason: '$rxcui');
        expect(
          drug!.strengths.map((s) => s.ingredient).toSet(),
          ingredients,
          reason: '$rxcui',
        );
      }
    }
  });

  test('every catalog medication is verified or explicitly unverified', () {
    final repository = MedicationRepository.createDefault();
    final verified = {for (final i in medicationReferenceIdentities) i.drugId};
    final unverified = {
      for (final u in unverifiedMedicationIdentities) u.drugId,
    };
    expect(verified.intersection(unverified), isEmpty);
    for (final drug in repository.allDrugs) {
      if (drug.id.startsWith('drug_rxnorm_scd_')) continue;
      expect(
        verified.contains(drug.id) || unverified.contains(drug.id),
        isTrue,
        reason: drug.id,
      );
      final identity = medicationReferenceIdentityFor(drug.id);
      if (identity != null && drug.sourceSystem == 'RXNORM') {
        final expectedCode =
            'RXCUI_IN:${([...identity.ingredientRxcuis]..sort()).join('+')}';
        expect(drug.sourceProductCode, expectedCode, reason: drug.id);
      }
    }
  });

  test('product entries carry the RxNorm formulation, never a guess', () {
    final repository = MedicationRepository.createDefault();
    final products = repository.allDrugs
        .where((d) => d.id.startsWith('drug_rxnorm_scd_'))
        .toList();
    expect(products.map((d) => d.sourceProductCode), [
      '197443',
      '197444',
      '197445',
      '308988',
      '308989',
    ]);
    for (final product in products) {
      final drug = rxnormClinicalDrug(int.parse(product.sourceProductCode!))!;
      expect(product.genericName, drug.name);
      expect(product.releaseType, drug.releaseType);
      expect(product.route, 'oral');
      expect(product.dosageForm, 'tablet');
      expect(product.tags, contains(DrugTag.levodopaLike));
    }
    expect(
      products.where((d) => d.releaseType == 'extended_release'),
      hasLength(2),
    );
    // The generic parent stays formulation-unspecified.
    expect(
      repository.getById('drug_levodopa_carbidopa')!.releaseType,
      'unspecified',
    );
  });
}
