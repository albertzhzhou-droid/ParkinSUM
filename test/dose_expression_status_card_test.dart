import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/shared/dose_expression_status_card.dart';

void main() {
  Widget app(String input, {Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: DoseExpressionStatusCard(rawText: input, showGrammarIdentity: true),
    ),
  );

  testWidgets('renders an accepted typed quantity and grammar identity', (
    tester,
  ) async {
    await tester.pumpWidget(app('0.5 g'));

    expect(find.byKey(const Key('dose-expression-status')), findsOneWidget);
    expect(find.byKey(const Key('dose-expression-accepted')), findsOneWidget);
    expect(find.textContaining('0.5 g · mass'), findsOneWidget);
    expect(
      find.byKey(const Key('dose-expression-grammar-identity')),
      findsOneWidget,
    );
    expect(
      find.textContaining('does not validate a prescription'),
      findsOneWidget,
    );
  });

  testWidgets('renders a nontechnical held reason and no accepted quantity', (
    tester,
  ) async {
    await tester.pumpWidget(app('100 mg then 50'));

    expect(find.byKey(const Key('dose-expression-held')), findsOneWidget);
    expect(
      find.textContaining('More than one number was found'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dose-expression-accepted')), findsNothing);
  });

  testWidgets('shows a typed held range without an accepted dose summary', (
    tester,
  ) async {
    await tester.pumpWidget(app('50–100 mg'));

    expect(find.byKey(const Key('dose-expression-held')), findsOneWidget);
    expect(
      find.textContaining('Dose ranges require manual confirmation'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dose-expression-held-structure')),
      findsOneWidget,
    );
    expect(find.text('50–100 mg'), findsOneWidget);
    expect(
      find.byKey(const Key('dose-expression-accepted-summary')),
      findsNothing,
    );
    expect(
      find.textContaining('no number from it enters result algorithms'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a typed held comparator without an accepted dose summary',
    (tester) async {
      await tester.pumpWidget(app('<= 0.50 g'));

      expect(find.byKey(const Key('dose-expression-held')), findsOneWidget);
      expect(
        find.textContaining('comparators are not accepted'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dose-expression-held-structure')),
        findsOneWidget,
      );
      expect(find.text('<= 0.50 g'), findsOneWidget);
      expect(
        find.byKey(const Key('dose-expression-accepted-summary')),
        findsNothing,
      );
      expect(
        find.textContaining('no number from it enters result algorithms'),
        findsOneWidget,
      );
    },
  );

  testWidgets('localizes the result boundary for Chinese UI', (tester) async {
    await tester.pumpWidget(app('1,5 mg', locale: const Locale('zh')));

    expect(find.text('剂量数值已暂停进入算法'), findsOneWidget);
    expect(find.textContaining('小数逗号'), findsOneWidget);
    expect(find.textContaining('数字不会进入结果算法'), findsOneWidget);
  });
}
