/// P0 官方来源端点常量。
/// 这些 URL 直接来自目前项目设计书与用户提供的官方源清单。
class P0SourceUrls {
  static const ciqualDataset =
      'https://entrepot.recherche.data.gouv.fr/dataset.xhtml?persistentId=doi:10.57745/RDMHWY';
  static const ciqualCompoXml =
      'https://entrepot.recherche.data.gouv.fr/api/access/datafile/:persistentId?persistentId=doi:10.57745/O73GDX';
  static const ciqualAlimXml =
      'https://entrepot.recherche.data.gouv.fr/api/access/datafile/:persistentId?persistentId=doi:10.57745/OH8KXC';
  static const ciqualAlimGrpXml =
      'https://entrepot.recherche.data.gouv.fr/api/access/datafile/:persistentId?persistentId=doi:10.57745/FMNIUZ';
  static const ciqualConstXml =
      'https://entrepot.recherche.data.gouv.fr/api/access/datafile/:persistentId?persistentId=doi:10.57745/FWSPCX';
  static const ciqualSourcesXml =
      'https://entrepot.recherche.data.gouv.fr/api/access/datafile/:persistentId?persistentId=doi:10.57745/3MVEOJ';

  static const fdcApiGuide = 'https://fdc.nal.usda.gov/api-guide';
  static const fdcFoodDetail = 'https://api.nal.usda.gov/fdc/v1/food';
  static const fdcFoodsSearch = 'https://api.nal.usda.gov/fdc/v1/foods/search';
  static const fdcFoodsList = 'https://api.nal.usda.gov/fdc/v1/foods/list';

  static const dailymedSplListJson =
      'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json';
  static const dailymedSplXmlBase =
      'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls';

  static const dpdDrugProduct =
      'https://health-products.canada.ca/api/drug/drugproduct/?lang=en&type=json';
  static const dpdActiveIngredient =
      'https://health-products.canada.ca/api/drug/activeingredient/?lang=en&type=json';
  static const dpdForm =
      'https://health-products.canada.ca/api/drug/form/?lang=en&type=json';
  static const dpdPackaging =
      'https://health-products.canada.ca/api/drug/packaging/?type=json';
  static const dpdRoute =
      'https://health-products.canada.ca/api/drug/route/?lang=en&type=json';
  static const dpdStatus =
      'https://health-products.canada.ca/api/drug/status/?lang=en&type=json';

  // EMA / PMDA P1 官方来源：
  // - EMA: 官方表格和 JSON，适合 direct metadata import；
  // - PMDA: 日文主检索与英文参考页，当前先做元数据层，不伪装成完整结构化标签出口。
  static const emaMedicinesDownloadPage =
      'https://www.ema.europa.eu/en/medicines/download-medicine-data';
  static const emaMedicinesXlsx =
      'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines-report_en.xlsx';
  static const emaPostAuthorisationXlsx =
      'https://www.ema.europa.eu/en/documents/report/medicines-output-post_authorisation-report_en.xlsx';
  static const emaJsonIndex =
      'https://www.ema.europa.eu/en/about-us/about-website/download-website-data-json-data-format';
  static const emaMedicinesJson =
      'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines_json-report_en.json';
  static const emaPostAuthorisationJson =
      'https://www.ema.europa.eu/en/documents/report/medicines-output-post_authorisation_json-report_en.json';

  static const pmdaEnglishEpackInfo =
      'https://www.pmda.go.jp/english/safety/info-services/e-pack-ins/0001.html';
  static const pmdaEnglishPackageInsertIndex =
      'https://www.pmda.go.jp/english/safety/info-services/drugs/package-inserts/0001.html';
  static const pmdaJapaneseMedicalSearch =
      'https://www.pmda.go.jp/PmdaSearch/iyakuSearch/';
  static const pmdaJapaneseOtcSearch =
      'https://www.pmda.go.jp/PmdaSearch/otcSearch/';
  static const pmdaEnglishApprovedProducts =
      'https://www.pmda.go.jp/english/review-services/reviews/approved-information/drugs/0002.html';

  // 中国食品成分 / 饮食指南：
  // 当前能稳定确认的公开官方页面以“标准/网络说明/指南索引”为主，
  // 还没有像 FDC/Ciqual 那样稳定明确的国家级整库公开下载端点。
  static const chinaFoodExpressionStandard =
      'https://www.nhc.gov.cn/wjw/yingyang/201505/3cbe4ecd6e48465899557a25a5ae1be9.shtml';
  static const chinaFoodExpressionStandardInterpretation =
      'https://www.nhc.gov.cn/zwgk/jdjd/201505/3cc87bebca6a4ab8a6b2bb6cc2a9cc8d.shtml';
  static const chinaFoodMonitoringNetwork =
      'https://www.chinacdc.cn/gzdt/zsdw/202509/t20250929_312801.html';
  static const chinaFbdgFao =
      'https://www.fao.org/nutrition/education/food-dietary-guidelines/regions/countries/China/en';
  static const chinaDietaryGuideline2022NhcReply =
      'https://www.nhc.gov.cn/wjw/jiany/202301/bd6c614391274ebd955fc9018f2032a2.shtml';
  static const chinaReduceOilIncreaseBeansMilk =
      'https://www.nhc.gov.cn/sps/c100087/202404/90c64c79708740a1bca0ee31e524caf7.shtml';
  static const chinaFoodCompositionTableAuthorityReference =
      'https://www.nhc.gov.cn/wjw/zcjd/201207/7b021c922308465d94bd2ae5aa32c375.shtml';
  static const chinaFoodQueryPlatform = 'https://nlc.chinanutri.cn/fq/';
  static const chinaFoodInfoBase = 'https://nlc.chinanutri.cn/fq/foodinfo';
  static const chinaFoodTofuAverage = '$chinaFoodInfoBase/333.html';
  static const chinaFoodRiceSteamedAverage = '$chinaFoodInfoBase/287.html';
  static const chinaFoodMantouAverage = '$chinaFoodInfoBase/272.html';
  static const chinaFoodNoodlesAverage = '$chinaFoodInfoBase/264.html';
  static const chinaFoodMilletPorridge = '$chinaFoodInfoBase/303.html';
  static const chinaFoodSoyMilk = '$chinaFoodInfoBase/338.html';
  static const chinaFoodEggAverage = '$chinaFoodInfoBase/978.html';
  static const chinaFoodAppleGuoguang = '$chinaFoodInfoBase/614.html';
  static const chinaFoodBanana = '$chinaFoodInfoBase/726.html';
  static const chinaFoodSpinach = '$chinaFoodInfoBase/473.html';
  static const chinaFoodPorkTenderloin = '$chinaFoodInfoBase/784.html';
  static const chinaFoodXiaoBaiCai = '$chinaFoodInfoBase/452.html';
  static const chinaFoodYouTiao = '$chinaFoodInfoBase/277.html';

  // 中国药品监管：
  // NMPA 公开门户明确存在，但当前项目尚未确认一个与 DailyMed 等价、
  // 可稳定批量自动化抓取的说明书结构化公开端点。
  static const nmpaPortal = 'https://zwfw.nmpa.gov.cn/web/index';
}
