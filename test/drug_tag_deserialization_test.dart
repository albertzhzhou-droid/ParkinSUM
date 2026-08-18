import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';

void main() {
  Map<String, dynamic> drugJson(List<Object?> tags) => <String, dynamic>{
    'id': 'drug_test',
    'genericName': 'Test medicine',
    'brandNames': const <String>[],
    'tags': tags,
  };

  test('unknown serialized tag stays unknown and never becomes levodopa', () {
    final drug = DrugDefinition.fromJson(
      drugJson(const <Object?>['future_catalog_tag']),
    );

    expect(drug.tags, const <DrugTag>[DrugTag.unknown]);
    expect(drug.tags, isNot(contains(DrugTag.levodopaLike)));
    expect(drug.toJson()['tags'], const <String>['unknown']);
    expect(
      drug.route,
      'unspecified',
      reason: 'Missing route metadata must never be inferred as oral.',
    );
  });

  test(
    'shared parser preserves known tags and maps every unknown to unknown',
    () {
      expect(
        parseDrugTags(const <Object?>[
          'maoi',
          'not_a_known_tag',
          null,
          'levodopaLike',
        ]),
        const <DrugTag>[
          DrugTag.maoi,
          DrugTag.unknown,
          DrugTag.unknown,
          DrugTag.levodopaLike,
        ],
      );
    },
  );
}
