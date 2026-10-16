/// Coarse protein source type used by the educational LNAA-competition
/// proxy when a food carries no usable amino-acid profile.
///
/// Each type's load factor is the median competing-LNAA fraction of protein
/// of its calibration foods divided by the all-food median, both measured on
/// the official FoodData Central 2025-04-24 SR Legacy records in
/// `lnaa_protein_fraction_calibration_table.dart`. The factors describe food
/// composition. How a load factor scales competition pressure remains a
/// prototype heuristic, and nothing here describes a person, a dose or a
/// timing choice.
library;

import '../../core/constants/lnaa_protein_fraction_calibration_table.dart';
import '../usecases/model_assumption_registry.dart';
import 'lnaa_protein_fraction_calibration.dart';
import 'reference_food_composition.dart';

enum ProteinSourceType {
  dairy,
  meat,
  fish,
  egg,
  soy,
  legume,
  grain,
  mixed,
  unknown,
}

/// Multiplier applied to the existing `proteinAmplitude` inside the
/// amino-acid competition layer. Unitless.
class LnaaLoadFactor {
  final ProteinSourceType sourceType;
  final double loadFactor;

  /// Load factors at the lower and upper quartile of the type's calibration
  /// patterns, on the same all-food scale. A spread of food composition, not
  /// a confidence interval and not a person-level range.
  final double interquartileLowFactor;
  final double interquartileHighFactor;

  /// Calibration statistics the factor was computed from. For `mixed` and
  /// `unknown` these are the all-food statistics.
  final LnaaFractionStatistics calibration;
  final List<String> sourceRefs;
  final String limitation;

  /// True when the factor is a neutral default rather than a calibrated
  /// group median (`mixed`, `unknown`).
  final bool isPrototypeHeuristic;

  const LnaaLoadFactor({
    required this.sourceType,
    required this.loadFactor,
    required this.interquartileLowFactor,
    required this.interquartileHighFactor,
    required this.calibration,
    required this.sourceRefs,
    required this.limitation,
    required this.isPrototypeHeuristic,
  });

  Map<String, dynamic> toJson() => {
    'source_type': sourceType.name,
    'load_factor': loadFactor,
    'interquartile_low_factor': interquartileLowFactor,
    'interquartile_high_factor': interquartileHighFactor,
    'calibration': calibration.toJson(),
    'source_refs': sourceRefs,
    'limitation': limitation,
    'is_prototype_heuristic': isPrototypeHeuristic,
  };
}

/// Registry mapping `ProteinSourceType` to a load factor calibrated on
/// official amino-acid composition.
///
/// On these records dairy and egg protein carry the most competing LNAA per
/// gram; meat, fish and grain protein sit near the all-food median; and soy
/// and other legume protein sit slightly below it. The cited reviews
/// describe animal protein as generally higher per gram; this calibration
/// supports that for dairy and egg but not for meat or fish against grain.
class ProteinSourceLnaaRegistry {
  static const String calibrationSourceId =
      'src.usda.fdc.full_download.2025_04_24';

  static const List<String> _baseSourceRefs = [
    'src.nutt.lnaa.1989',
    'src.nutt.onoff.1984',
    'src.cereda.protein.2017',
    'src.advances.nutrition.2021',
    'src.npj.peripheral.resistance.2022',
    'src.lnaa.plantvanimal.2023',
    calibrationSourceId,
    'src.internal.prototype.heuristic',
  ];

  /// All-food median competing-LNAA fraction of protein. A food at this
  /// fraction has load factor 1.
  static double get referenceFraction => lnaaFractionOverall.median;

  static final Map<ProteinSourceType, LnaaLoadFactor> _factors = {
    for (final type in ProteinSourceType.values) type: _build(type),
  };

  static LnaaLoadFactor _build(ProteinSourceType type) {
    final reference = lnaaFractionOverall.median;
    final calibrated = lnaaFractionBySource[type];
    if (calibrated == null) {
      return LnaaLoadFactor(
        sourceType: type,
        loadFactor: 1.0,
        interquartileLowFactor: lnaaFractionOverall.lowerQuartile / reference,
        interquartileHighFactor: lnaaFractionOverall.upperQuartile / reference,
        calibration: lnaaFractionOverall,
        sourceRefs: _baseSourceRefs,
        limitation: type == ProteinSourceType.mixed
            ? 'Mixed protein sources use the all-food median (factor 1) and '
                  'widen uncertainty; ${_describe(lnaaFractionOverall)}.'
            : 'Unknown protein source; the model uses the all-food median '
                  '(factor 1), neither favoring nor penalizing a source, and '
                  'widens the competition uncertainty band; '
                  '${_describe(lnaaFractionOverall)}.',
        isPrototypeHeuristic: true,
      );
    }
    return LnaaLoadFactor(
      sourceType: type,
      loadFactor: calibrated.median / reference,
      interquartileLowFactor: calibrated.lowerQuartile / reference,
      interquartileHighFactor: calibrated.upperQuartile / reference,
      calibration: calibrated,
      sourceRefs: _baseSourceRefs,
      limitation:
          'Median competing-LNAA fraction of ${type.name} protein divided by '
          'the all-food median ${reference.toStringAsFixed(4)}; '
          '${_describe(calibrated)}. Describes food composition only; how '
          'load scales competition pressure is a prototype heuristic.',
      isPrototypeHeuristic: false,
    );
  }

  static String _describe(LnaaFractionStatistics stats) {
    final tiers = stats.weakestTierCounts.entries
        .map((entry) => '${entry.value} ${entry.key}')
        .join(', ');
    return '${stats.foodCount} official FDC 2025-04-24 SR Legacy records in '
        '${stats.independentPatternCount} independent amino-acid patterns, '
        'fraction IQR ${stats.lowerQuartile.toStringAsFixed(4)}-'
        '${stats.upperQuartile.toStringAsFixed(4)}, weakest amino-acid '
        'derivation tiers: $tiers';
  }

  static LnaaLoadFactor factorFor(ProteinSourceType sourceType) {
    return _factors[sourceType] ?? _factors[ProteinSourceType.unknown]!;
  }

  static List<LnaaLoadFactor> all() => _factors.values.toList(growable: false);

  static ModelEvidenceLevel evidenceLevelFor(ProteinSourceType sourceType) =>
      ModelEvidenceLevel.prototypeHeuristic;
}

/// Protein source of a curated reference food, from its catalog group and
/// official description. The LNAA calibration generator groups its records
/// with this function, so each type is calibrated on exactly the foods that
/// carry it. Legume records whose description names a soy food are soy.
/// Groups the proxy has no calibrated type for (fruit, vegetable, nut and
/// seed, fat and oil, sweetener, alcoholic beverage) are `unknown`, so
/// uncertainty widens instead of borrowing another group's factor. Beverage,
/// condiment and protein-supplement records are read from their description
/// (soymilk, miso, whey).
ProteinSourceType proteinSourceForReferenceGroup(
  ReferenceFoodGroup group,
  String officialDescription,
) {
  switch (group) {
    case ReferenceFoodGroup.dairy:
      return ProteinSourceType.dairy;
    case ReferenceFoodGroup.egg:
      return ProteinSourceType.egg;
    case ReferenceFoodGroup.meat:
    case ReferenceFoodGroup.poultry:
      return ProteinSourceType.meat;
    case ReferenceFoodGroup.fishSeafood:
      return ProteinSourceType.fish;
    case ReferenceFoodGroup.grain:
      return ProteinSourceType.grain;
    case ReferenceFoodGroup.legume:
      return soyFoodDescriptionPattern.hasMatch(officialDescription)
          ? ProteinSourceType.soy
          : ProteinSourceType.legume;
    case ReferenceFoodGroup.beverage:
    case ReferenceFoodGroup.condiment:
    case ReferenceFoodGroup.proteinSupplement:
      final inferred = inferProteinSourceFromNameAndCategory(
        name: officialDescription,
      );
      return inferred == ProteinSourceType.mixed
          ? ProteinSourceType.unknown
          : inferred;
    case ReferenceFoodGroup.fruit:
    case ReferenceFoodGroup.vegetable:
    case ReferenceFoodGroup.nutSeed:
    case ReferenceFoodGroup.fatOil:
    case ReferenceFoodGroup.alcoholicBeverage:
    case ReferenceFoodGroup.sweetenerConfection:
      return ProteinSourceType.unknown;
  }
}

/// Soy foods named in an official English description.
final RegExp soyFoodDescriptionPattern = RegExp(
  r'\b(soy|soybeans?|tofu|tempeh|edamame|natto|miso)\b',
  caseSensitive: false,
);

/// Best-effort inference of a `ProteinSourceType` from a food's name, its
/// [aliases] and category. Deterministic and side-effect-free.
///
/// The name, then each alias, is read in turn and the first text that names
/// a protein source decides. English text is matched on whole words (so
/// "eggplant" is not egg and "goat" is not oat); Chinese text is matched on
/// specific food words (so 土豆 potato is not a legume and 牛油果 avocado is
/// not beef). Plant drinks are not dairy: oat milk reads as grain, soy milk
/// as soy, almond and coconut milk as nothing. Soy outranks legume. When a
/// text names more than one non-grain source the result is `mixed`; grain
/// counts only when nothing else is named. Unknown inputs return
/// `ProteinSourceType.unknown` (never an arbitrary guess) so the model widens
/// uncertainty rather than faking precision.
ProteinSourceType inferProteinSourceFromNameAndCategory({
  required String name,
  String? category,
  List<String> aliases = const [],
}) {
  for (final text in [name, ...aliases]) {
    final resolved = _resolveProteinFamilies(_proteinFamiliesIn(text));
    if (resolved != null) return resolved;
  }
  if (category != null && category.toLowerCase() == 'protein') {
    // Category says protein but no text named a source — treat as mixed
    // rather than unknown to reflect "we know it's a protein food but not
    // its kind".
    return ProteinSourceType.mixed;
  }
  return ProteinSourceType.unknown;
}

ProteinSourceType? _resolveProteinFamilies(Set<ProteinSourceType> families) {
  if (families.contains(ProteinSourceType.soy)) {
    families.remove(ProteinSourceType.legume);
  }
  final named = families.difference(const {ProteinSourceType.grain});
  if (named.length == 1) return named.single;
  if (named.length > 1) return ProteinSourceType.mixed;
  if (families.contains(ProteinSourceType.grain)) {
    return ProteinSourceType.grain;
  }
  return null;
}

Set<ProteinSourceType> _proteinFamiliesIn(String text) {
  final families = <ProteinSourceType>{};
  final tokens = text
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  for (var i = 0; i < tokens.length; i++) {
    final family = _englishFamily(tokens, i);
    if (family != null) families.add(family);
  }
  for (var i = 0; i + 1 < tokens.length; i++) {
    if (_englishDairyPhrases.contains('${tokens[i]} ${tokens[i + 1]}')) {
      families.add(ProteinSourceType.dairy);
    }
  }

  var cjk = text;
  for (final phrase in _chineseExclusions) {
    cjk = cjk.replaceAll(phrase, ' ');
  }
  for (final entry in _chineseKeywords.entries) {
    if (entry.value.any(cjk.contains)) families.add(entry.key);
  }
  return families;
}

ProteinSourceType? _englishFamily(List<String> tokens, int index) {
  final token = tokens[index];
  final previous = index > 0 ? tokens[index - 1] : null;
  for (final entry in _englishKeywords.entries) {
    if (!_matchesWord(entry.value, token)) continue;
    if (previous != null && _qualifierCancels(entry.key, token, previous)) {
      return null;
    }
    return entry.key;
  }
  return null;
}

/// A preceding word that means the keyword does not name that source:
/// plant drinks ("oat milk", "almond yogurt"), non-food beans ("coffee
/// bean", "jelly beans"), non-animal meat ("crab meat", "coconut meat") and
/// starch noodles ("glass noodles").
bool _qualifierCancels(
  ProteinSourceType family,
  String token,
  String previous,
) {
  switch (family) {
    case ProteinSourceType.dairy:
      return _plantQualifiers.contains(previous);
    case ProteinSourceType.legume:
      return _nonFoodBeanQualifiers.contains(previous);
    case ProteinSourceType.grain:
      return previous == 'glass' || previous == 'cellophane';
    case ProteinSourceType.meat:
      return token == 'meat' &&
          (_meatQualifierExclusions.contains(previous) ||
              _matchesWord(
                _englishKeywords[ProteinSourceType.fish]!,
                previous,
              ));
    default:
      return false;
  }
}

bool _matchesWord(Set<String> words, String token) {
  if (words.contains(token)) return true;
  if (token.endsWith('es') &&
      words.contains(token.substring(0, token.length - 2))) {
    return true;
  }
  return token.endsWith('s') &&
      words.contains(token.substring(0, token.length - 1));
}

// No word is listed under two families.
const Map<ProteinSourceType, Set<String>> _englishKeywords = {
  ProteinSourceType.soy: {
    'soy', 'soya', 'soybean', 'soymilk', 'tofu', 'tempeh', 'edamame', //
    'natto', 'miso', 'doenjang', 'yuba', 'okara', 'shoyu', 'tamari',
  },
  ProteinSourceType.legume: {
    'lentil', 'chickpea', 'bean', 'pea', 'pulse', 'fava', 'dal', 'dhal', //
    'daal', 'hummus', 'falafel', 'chana', 'garbanzo', 'peanut', 'legume',
    'mung', 'adzuki', 'azuki', 'lupin', 'lupini', 'broadbean',
  },
  ProteinSourceType.fish: {
    'fish', 'codfish', 'salmon', 'tuna', 'cod', 'sardine', 'mackerel', //
    'tilapia', 'trout', 'herring', 'pollock', 'carp', 'catfish', 'anchovy',
    'anchovies', 'bream', 'yellowtail', 'hamachi', 'halibut', 'haddock',
    'snapper', 'eel', 'shrimp', 'prawn', 'crab', 'lobster', 'crayfish',
    'crawfish', 'scallop', 'clam', 'mussel', 'oyster', 'squid', 'octopus',
    'calamari', 'seafood', 'roe', 'caviar', 'saba', 'buri', 'kipper',
    'swordfish', 'sashimi', 'surimi', 'crustacean', 'mollusk',
  },
  ProteinSourceType.egg: {'egg', 'omelet', 'omelette', 'frittata', 'shakshuka'},
  ProteinSourceType.dairy: {
    'milk', 'yogurt', 'yoghurt', 'cheese', 'kefir', 'whey', 'paneer', //
    'lassi', 'raita', 'tzatziki', 'curd', 'casein', 'skyr', 'quark',
    'ricotta', 'mozzarella', 'cheddar', 'parmesan', 'feta', 'brie',
    'camembert', 'gouda', 'edam', 'roquefort', 'gruyere', 'mascarpone',
    'labneh', 'buttermilk', 'milkfat',
  },
  ProteinSourceType.meat: {
    'beef', 'pork', 'lamb', 'mutton', 'veal', 'venison', 'chicken', //
    'turkey', 'duck', 'goose', 'meat', 'steak', 'ham', 'bacon', 'sausage',
    'salami', 'pepperoni', 'prosciutto', 'chorizo', 'jerky', 'pastrami',
    'meatball', 'brisket', 'sirloin', 'tenderloin', 'kebab', 'poultry',
    'broiler', 'fryer',
  },
  ProteinSourceType.grain: {
    'oat', 'oatmeal', 'wheat', 'rice', 'barley', 'rye', 'quinoa', 'corn', //
    'cornmeal', 'maize', 'bread', 'pasta', 'noodle', 'spaghetti', 'macaroni',
    'couscous', 'bulgur', 'bulghur', 'millet', 'sorghum', 'spelt', 'teff',
    'buckwheat', 'soba', 'udon', 'ramen', 'chapati', 'roti', 'naan', 'pita',
    'tortilla', 'cereal', 'flour', 'congee', 'porridge', 'mochi', 'tteok',
    'idli', 'bagel', 'granola', 'muesli', 'farro', 'amaranth', 'polenta',
    'grits', 'semolina', 'gluten', 'seitan', 'bran', 'kasha', 'pilaf',
    'risotto', 'biryani', 'wildrice',
  },
};

const Set<String> _englishDairyPhrases = {'ice cream', 'sour cream'};

const Set<String> _plantQualifiers = {
  'almond', 'oat', 'rice', 'coconut', 'soy', 'soya', 'cashew', 'hemp', //
  'pea', 'plant', 'nut', 'vegan', 'macadamia', 'hazelnut', 'flax',
  'quinoa', 'peanut',
};

const Set<String> _nonFoodBeanQualifiers = {
  'coffee',
  'jelly',
  'vanilla',
  'cocoa',
  'cacao',
};

const Set<String> _meatQualifierExclusions = {'coconut', 'imitation'};

/// Phrases removed before Chinese keyword matching because they contain a
/// keyword without naming that food.
const List<String> _chineseExclusions = [
  '鱼香', // fish-fragrant sauce, no fish
  '蛋白粉', // protein powder; the named source decides
  '蛋白质', // "protein"
  '蛋糕', // cake
  '奶油南瓜', // butternut squash
  '牛油果', // avocado
];

const Map<ProteinSourceType, List<String>> _chineseKeywords = {
  ProteinSourceType.soy: [
    '豆腐', '豆浆', '豆奶', '黄豆', '大豆', '毛豆', '纳豆', '味噌', '腐竹', //
    '豆干', '豆皮', '腐乳', '天贝', '丹贝', '酱油', '黄豆芽',
  ],
  ProteinSourceType.legume: [
    '扁豆', '鹰嘴豆', '芸豆', '蚕豆', '豌豆', '绿豆', '红豆', '赤小豆', //
    '黑豆', '白豆', '豆类', '豆芽', '花生', '豆瓣',
  ],
  ProteinSourceType.fish: [
    '鱼', '鲑', '鳕', '鲭', '鲱', '鲤', '鲈', '鲷', '鳗', '鲣', '鲫', '鳟', //
    '鮰', '鳀', '鲶', '鲳', '鳜', '鲅', '鲢', '鳙', '鲍', '虾', '蟹', '扇贝',
    '干贝', '贝类', '蛤', '蚌', '牡蛎', '生蚝', '蚝', '鱿', '海参', '海鲜',
  ],
  ProteinSourceType.egg: [
    '鸡蛋', '鸭蛋', '鹅蛋', '鹌鹑蛋', '皮蛋', '咸蛋', '松花蛋', '蛋清', //
    '蛋白', '蛋黄', '代蛋', '炒蛋', '煎蛋', '蒸蛋', '荷包蛋', '蛋花', '蛋羹',
    '茶叶蛋', '全蛋', '液蛋',
  ],
  ProteinSourceType.dairy: [
    '牛奶', '羊奶', '牛乳', '羊乳', '酸奶', '酸乳', '奶酪', '干酪', '乳酪', //
    '芝士', '奶粉', '乳清', '炼乳', '奶油', '鲜奶', '母乳', '脱脂奶', '全脂奶',
    '奶昔', '酪乳',
  ],
  ProteinSourceType.meat: [
    '牛肉', '猪肉', '羊肉', '鸡肉', '鸭肉', '鹅肉', '兔肉', '驴肉', '鹿肉', //
    '火鸡', '鸡胸', '鸡腿', '鸡翅', '鸡块', '鸭腿', '牛排', '猪排', '羊排',
    '排骨', '里脊', '火腿', '培根', '香肠', '腊肠', '腊肉', '熏肉', '烤肉',
    '肉末', '肉馅', '肉丸', '肉松', '肉饼', '肉包', '肉丝', '肉片', '瘦肉',
    '肥肉', '五花肉', '牛腩', '牛腱', '肉类', '鸡汤',
  ],
  ProteinSourceType.grain: [
    '米饭', '大米', '糙米', '白米', '黑米', '糯米', '米粉', '米线', '河粉', //
    '粥', '燕麦', '小麦', '面粉', '面包', '面条', '面筋', '拉面', '挂面',
    '方便面', '意大利面', '意面', '乌冬', '馒头', '花卷', '饺子', '包子',
    '馄饨', '玉米', '荞麦', '黑麦', '大麦', '小米', '高粱', '藜麦', '古斯米',
    '布格麦', '斯佩尔特', '苔麸', '菰米', '谷朊粉', '麦片', '谷物', '年糕',
    '粽子', '烧饼', '饼干', '炒饭', '蒸谷米',
  ],
};
