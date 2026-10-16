import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/services/services.dart';
import 'core/state/app_state.dart';
import 'core/theme/paper_theme.dart';
import 'features/entry/synthetic_meal_journey_page.dart';

/// Standalone release-Web entry point for the same product journey, using only
/// disposable in-memory services. No account setup or persistent data loader.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = Services.createEphemeral();
  await services.ready;
  final state = AppState(services: services);
  await state.bootstrap();
  const requestedLocale = String.fromEnvironment(
    'PARKINSUM_DEMO_LOCALE',
    defaultValue: 'en-US',
  );
  final localeTag = requestedLocale.startsWith('zh') ? 'zh-CN' : 'en-US';
  await state.saveUserProfile(
    state.userProfile.copyWith(displayLocale: localeTag),
  );
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        title: 'ParkinSUM synthetic meal journey',
        theme: Paper.themeData(),
        locale: localeTag.startsWith('zh')
            ? const Locale('zh', 'CN')
            : const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SyntheticMealJourneyPage(),
      ),
    ),
  );
}
