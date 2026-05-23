import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_i18n.dart';
import '../core/services/services.dart';
import '../core/state/app_state.dart';
import '../core/theme/liquid_glass_theme.dart';

// ⚠️ 修复：目录是 features 不是 feature
import '../features/auth/auth_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/main_shell/main_shell.dart';

class ParkinSUMApp extends StatelessWidget {
  const ParkinSUMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Services>(create: (_) => Services.createDefault()),
        ChangeNotifierProxyProvider<Services, AppState>(
          create: (context) => AppState(services: context.read<Services>()),
          update: (context, services, prev) =>
              prev ?? AppState(services: services),
        ),
      ],
      // 让 MaterialApp 直接跟随用户在 onboarding 中选择的 displayLocale。
      // 这样后续页面不会再停留在固定语言。
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          key: ValueKey<String>(state.userProfile.displayLocale),
          debugShowCheckedModeBanner: false,
          locale: AppI18n.toLocale(state.userProfile.displayLocale),
          supportedLocales: const [
            // Originally supported.
            Locale('zh', 'CN'),
            Locale('en', 'US'),
            Locale('en', 'CA'),
            Locale('fr', 'CA'),
            Locale('fr', 'FR'),
            Locale('ja', 'JP'),
            // Newly registered locales (paired with secondary_source_registry
            // and locale_resource_seed_importer).
            Locale('ko', 'KR'),
            Locale('hi', 'IN'),
            Locale('es', 'ES'),
            Locale('es', 'MX'),
            Locale('vi', 'VN'),
            Locale('th', 'TH'),
            Locale('id', 'ID'),
            Locale('ru', 'RU'),
            Locale('pl', 'PL'),
            Locale('ar', 'SA'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: LiquidGlass.themeData(),
          builder: (context, child) {
            return LiquidGlassBackground(
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _Bootstrapper(),
        ),
      ),
    );
  }
}

class _Bootstrapper extends StatefulWidget {
  const _Bootstrapper();

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<_Bootstrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, __) {
        if (state.isBootstrapping) {
          final i18n = context.appI18n;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2.6),
                    const SizedBox(height: 14),
                    Text(
                      i18n.tr('app.loading'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: LiquidGlass.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state.requiresFirebaseSignIn) {
          return const AuthPage();
        } else if (!state.isOnboarded) {
          return const OnboardingPage();
        }

        return const MainShell();
      },
    );
  }
}
