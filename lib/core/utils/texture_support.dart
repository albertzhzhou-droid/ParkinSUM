/// 仅基于显式文本线索生成最小 texture / IDDSI 结构值。
///
/// 重要边界：
/// - 这里不是临床吞咽分级器；
/// - 只在来源文本已经明确表现为“液体/饮品”或“软糊/泥糊”时给出结构值；
/// - 其余情况返回 null，避免把工程默认伪装成权威事实。
String? inferTextureClassFromText({
  required String name,
  required String description,
  required String categoryName,
}) {
  final text = '$name $description $categoryName'.toLowerCase();
  if (_liquidCue.hasMatch(text)) {
    return 'liquid';
  }
  if (_softCue.hasMatch(text)) {
    return 'soft';
  }
  return null;
}

int? inferIddsiLevelFromTextureClass(String? textureClass) {
  switch (textureClass) {
    case 'liquid':
      return 0;
    case 'soft':
      return 4;
    default:
      return null;
  }
}

bool isTextureStructuredSafeForThickener(String? textureClass) {
  return textureClass == 'liquid' || textureClass == 'soft';
}

final RegExp _liquidCue = RegExp(
  r'\b(beverage|drink|drinks|coffee|tea|juice|broth|soup|liquid|ready_to_drink)\b',
);

final RegExp _softCue = RegExp(
  r'\b(puree|pureed|porridge|oatmeal|yogurt|pudding|tofu|mashed|soft)\b',
);
