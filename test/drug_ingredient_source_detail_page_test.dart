import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/features/catalog/catalog_detail_pages.dart';

import 'helpers/page_test_harness.dart';

const _originalIngredients = [
  {
    'name': 'CARBIDOPA',
    'class_code': 'ACTIM',
    'classification': 'active',
    'substance_code': 'MNX7R8C5VO',
    'code_system': '2.16.840.1.113883.4.9',
    'numerator_value': '10',
    'numerator_unit': 'mg',
    'denominator_value': '1',
    'denominator_unit': '1',
    'strength_basis': 'active_moiety',
    'active_moieties': [
      {
        'name': 'CARBIDOPA ANHYDROUS',
        'substance_code': 'KR87B45RGH',
        'code_system': '2.16.840.1.113883.4.9',
      },
    ],
  },
  {
    'name': 'MICROCRYSTALLINE CELLULOSE',
    'class_code': 'IACT',
    'classification': 'inactive',
    'substance_code': 'OP1R32D61U',
    'code_system': '2.16.840.1.113883.4.9',
  },
];

void main() {
  testWidgets('source identity, moiety and inactive rows are visible', (
    tester,
  ) async {
    // Independent crop from sinemet.ingredient-fields.xml and its pre-import
    // inventory. No strength normalization or dose is manufactured here.
    final drug = DrugDefinition(
      id: 'synthetic',
      genericName: 'Source fields',
      brandNames: [],
      tags: [],
      notes: 'Synthetic UI using original source fields',
    );
    final document = ProjectedDrugSourceDocument.fromRow(
      {
        'source_doc_id': 'doc',
        'origin_url': 'https://dailymed.nlm.nih.gov/dailymed/',
        'raw_payload': jsonEncode({
          'product_scope_schema': 'spl-product-scope/1',
          'product_scopes': {
            'variant': {
              'identity_status': 'resolved_product_scope',
              'active_ingredient_details': [_originalIngredients.first],
              'ingredient_class_audit': _originalIngredients,
            },
          },
        }),
      },
      variantIds: {'variant'},
    );
    expect(document.activeIngredientDetails, hasLength(1));
    expect(document.ingredientClassEvidence, hasLength(2));
    await pumpFeaturePage(
      tester,
      DrugDetailPage(
        drug: drug,
        future: Future.value(
          ProjectedDrugDetail(
            drug: drug,
            variantIds: ['variant'],
            sections: [],
            packagingDescriptions: [],
            mediaLinks: [],
            labelFacts: [],
            sourceDocuments: [document],
          ),
        ),
      ),
      settle: true,
    );
    for (var index = 0; index < 2; index++) {
      final tile = find.byType(ExpansionTile).at(index);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('MNX7R8C5VO'), findsOneWidget);
    expect(find.textContaining('KR87B45RGH'), findsOneWidget);
    expect(find.textContaining('CARBIDOPA ANHYDROUS'), findsOneWidget);
    expect(find.textContaining('OP1R32D61U'), findsOneWidget);
    expect(find.textContaining('MICROCRYSTALLINE CELLULOSE'), findsOneWidget);
    expect(find.text('CARBIDOPA: 10 mg / 1 1'), findsOneWidget);
    expectNoWidgetErrors();
  });
}
