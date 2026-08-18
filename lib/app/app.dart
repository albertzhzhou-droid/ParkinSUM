import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_i18n_context.dart';
import '../core/services/services.dart';
import '../core/state/app_state.dart';
import '../core/theme/liquid_glass_theme.dart';

// ⚠️ 修复：目录是 features 不是 feature
import '../features/auth/auth_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/main_shell/main_shell.dart';
import '../features/main_shell/main_tab_route.dart';
import 'bootstrap_attempt_controller.dart';
import 'bootstrap_gate.dart';

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
      child: const _ParkinSUMMaterialApp(),
    );
  }
}

class _ParkinSUMMaterialApp extends StatefulWidget {
  const _ParkinSUMMaterialApp();

  @override
  State<_ParkinSUMMaterialApp> createState() => _ParkinSUMMaterialAppState();
}

class _ParkinSUMMaterialAppState extends State<_ParkinSUMMaterialApp> {
  late final BootstrapAttemptController _bootstrapController;
  late final _ParkinSUMRouterDelegate _routerDelegate;
  late final RootBackButtonDispatcher _backButtonDispatcher;

  @override
  void initState() {
    super.initState();
    _bootstrapController = BootstrapAttemptController(
      bootstrap: () => context.read<AppState>().bootstrap(),
    );
    _routerDelegate = _ParkinSUMRouterDelegate(_bootstrapController);
    _backButtonDispatcher = RootBackButtonDispatcher();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      // 让 MaterialApp 直接跟随用户在 onboarding 中选择的 displayLocale。
      // Navigator key 由这个 locale 无关的 State 持有，因此语言变化只更新
      // 本地化配置，不会重建导航栈或丢失页面中的未保存状态。
      builder: (context, state, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerDelegate: _routerDelegate,
        routeInformationParser: const MainTabRouteInformationParser(),
        backButtonDispatcher: _backButtonDispatcher,
        locale: appI18nLocaleFor(state.userProfile.displayLocale),
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
          return LiquidGlassBackground(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}

class _ParkinSUMRouterDelegate extends RouterDelegate<MainTabRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<MainTabRoute> {
  _ParkinSUMRouterDelegate(this.bootstrapController);

  final BootstrapAttemptController bootstrapController;
  MainTabRoute _route = MainTabRoute.home;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'parkinsum-root-navigator',
  );

  @override
  MainTabRoute get currentConfiguration => _route;

  void selectTab(String tabId) {
    final next = MainTabRoute.fromId(tabId);
    if (next.id == _route.id) return;
    _route = next;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(MainTabRoute configuration) async {
    if (configuration.id == _route.id) return;
    _route = configuration;
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop() && await navigator.maybePop()) {
      return true;
    }
    if (_route.id != MainTabRoute.home.id) {
      selectTab(MainTabRoute.home.id);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[
        MaterialPage<void>(
          key: const ValueKey<String>('parkinsum-root-page'),
          child: BootstrapGate(
            controller: bootstrapController,
            loadingLabel: context.appI18n.tr('app.loading'),
            failureLabel: context.appI18n.tr('common.error'),
            retryLabel: context.appI18n.tr('import.retry'),
            successBuilder: (_) =>
                _AppRouter(selectedTabId: _route.id, onTabSelected: selectTab),
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter({required this.selectedTabId, required this.onTabSelected});

  final String selectedTabId;
  final ValueChanged<String> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, _) {
        if (state.requiresFirebaseSignIn) {
          return const AuthPage();
        } else if (!state.isOnboarded) {
          return const OnboardingPage();
        }

        return MainShell(
          selectedTabId: selectedTabId,
          onTabSelected: onTabSelected,
        );
      },
    );
  }
}
