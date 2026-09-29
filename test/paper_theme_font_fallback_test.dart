import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/theme/paper_theme.dart';

void main() {
  test(
    'Paper text themes carry ordered script fallbacks before platform fallback',
    () {
      final theme = Paper.themeData();
      final expected = Paper.scriptFontFallback;
      final textTheme = theme.textTheme;

      expect(textTheme.bodyMedium!.fontFamily, Paper.sans);

      final styles = <TextStyle?>[
        textTheme.displayLarge,
        textTheme.displayMedium,
        textTheme.displaySmall,
        textTheme.headlineLarge,
        textTheme.headlineMedium,
        textTheme.headlineSmall,
        textTheme.titleLarge,
        textTheme.titleMedium,
        textTheme.titleSmall,
        textTheme.bodyLarge,
        textTheme.bodyMedium,
        textTheme.bodySmall,
        textTheme.labelLarge,
        textTheme.labelMedium,
        textTheme.labelSmall,
      ];
      for (final style in styles) {
        expect(style!.fontFamilyFallback, orderedEquals(expected));
      }

      expect(expected, contains('Noto Sans Devanagari'));
      expect(expected, contains('Noto Sans Thai'));
      expect(expected, contains('Noto Sans Arabic'));
      expect(expected, contains('Noto Naskh Arabic'));
      expect(expected, contains('Noto Naskh Arabic UI'));
      expect(
        expected.where((family) => family.contains('CJK')),
        isEmpty,
        reason: 'CJK glyphs should reach locale-aware platform fallback.',
      );
    },
  );
}
