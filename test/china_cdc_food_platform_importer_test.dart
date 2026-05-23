import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/china_cdc_food_platform_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

void main() {
  test('china CDC food platform importer builds food variant and observations',
      () async {
    const url = 'https://nlc.chinanutri.cn/fq/foodinfo/333.html';
    const html = '''
      <h1>豆腐(均值)</h1>
      <div>食物类：干豆类及制品 亚 类：大豆</div>
      <div>营养成分（每100克）</div>
      <div>食部(Edible) 100%</div>
      <div>能量(Energy) 342kJ</div>
      <div>蛋白质(Protein) 8.1g</div>
      <div>脂肪(Fat) 3.7g</div>
      <div>碳水化合物(CHO) 4.2g</div>
      <div>总膳食纤维(Dietary fiber) Tr</div>
      <div>钠(Na) 7.2mg</div>
      <div>钙(Ca) 138mg</div>
      <div>铁(Fe) 1.5mg</div>
      <div>维生素C(Vitamin C) —</div>
    ''';
    const importer = ChinaCdcFoodPlatformImporter(
      fetchClient: FakeSourceFetchClient(
        textByUrl: <String, String>{url: html},
      ),
    );

    final bundle = importer.importFoodPage(url: url, html: html);

    expect(bundle.foodVariants.single.jurisdiction, 'CN');
    expect(bundle.projectedFoods.single.name, '豆腐(均值)');
    expect(bundle.projectedFoods.single.proteinG, 8.1);
    expect(bundle.observations.any((item) => item.attributeCode == 'protein_g'),
        isTrue);
    expect(
        bundle.observations.any(
          (item) =>
              item.attributeCode == 'fiber_g' &&
              item.value.qualifierKind.wireValue == 'trace',
        ),
        isTrue);
  });
}
