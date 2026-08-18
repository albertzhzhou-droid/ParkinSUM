import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_i18n_context.dart';
import '../core/services/services.dart';
import '../core/services/user_logging_reminder_service.dart';
import '../core/state/app_state.dart';
import '../core/theme/liquid_glass_theme.dart';

// ⚠️ 修复：目录是 features 不是 feature
import '../features/auth/auth_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/main_shell/main_shell.dart';
import '../features/main_shell/main_tab_route.dart';
import '../features/entry/entry_page.dart';
import '../features/reminders/reminder_center_page.dart';
import '../features/timeline/timeline_page.dart';
import 'account_owned_route_registry.dart';
import 'bootstrap_attempt_controller.dart';
import 'bootstrap_gate.dart';

class ParkinSUMApp extends StatelessWidget {
  const ParkinSUMApp({
    super.key,
    this.services,
    this.reminderResponseCoordinator,
  });

  /// Optional complete service graph for deterministic demos/device tests.
  /// Normal app startup leaves this null and receives the production graph.
  final Services? services;

  /// Optional notification-response graph for deterministic routing tests.
  final ReminderNotificationResponseCoordinator? reminderResponseCoordinator;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Services>(create: (_) => services ?? Services.createDefault()),
        ChangeNotifierProxyProvider<Services, AppState>(
          create: (context) => AppState(services: context.read<Services>()),
          update: (context, services, prev) =>
              prev ?? AppState(services: services),
        ),
      ],
      child: _ParkinSUMMaterialApp(
        reminderResponseCoordinator: reminderResponseCoordinator,
      ),
    );
  }
}

class _ParkinSUMMaterialApp extends StatefulWidget {
  const _ParkinSUMMaterialApp({this.reminderResponseCoordinator});

  final ReminderNotificationResponseCoordinator? reminderResponseCoordinator;

  @override
  State<_ParkinSUMMaterialApp> createState() => _ParkinSUMMaterialAppState();
}

class _ParkinSUMMaterialAppState extends State<_ParkinSUMMaterialApp>
    with WidgetsBindingObserver {
  late final BootstrapAttemptController _bootstrapController;
  late final _ParkinSUMRouterDelegate _routerDelegate;
  late final RootBackButtonDispatcher _backButtonDispatcher;
  late final ReminderNotificationResponseCoordinator
  _reminderResponseCoordinator;
  StreamSubscription<ReminderNotificationResponseEvent>?
  _reminderResponseSubscription;
  final List<ReminderNotificationActivation> _pendingReminderResponses = [];
  final Set<String> _queuedReminderActivationIds = <String>{};
  bool _responseHandlingInitialized = false;
  bool _activationRecoveryInProgress = false;
  bool _isRoutingReminderResponse = false;
  bool _responseDrainScheduled = false;
  int _reminderAccountEpoch = 0;
  AppState? _observedAppState;
  String? _lastObservedUserScope;
  final AccountOwnedRouteRegistry _accountOwnedRoutes =
      AccountOwnedRouteRegistry();
  String? _lastReconciledUserScope;
  Future<void> _reminderLifecycleSerial = Future<void>.value();
  Future<void> _reminderActivationAccountGate = Future<void>.value();
  int _requestedReminderCancellationGeneration = 0;
  int _completedReminderCancellationGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapController = BootstrapAttemptController(
      bootstrap: () => context.read<AppState>().bootstrap(),
    );
    _routerDelegate = _ParkinSUMRouterDelegate(
      _bootstrapController,
      _accountOwnedRoutes,
    );
    _backButtonDispatcher = RootBackButtonDispatcher();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_responseHandlingInitialized) return;
    _responseHandlingInitialized = true;
    _reminderResponseCoordinator =
        widget.reminderResponseCoordinator ??
        ReminderNotificationResponseCoordinator();
    _reminderResponseSubscription = _reminderResponseCoordinator
        .source
        .responses
        .listen(_captureReminderResponse);
    _observedAppState = context.read<AppState>();
    _lastObservedUserScope = _observedAppState!.currentUserId;
    _accountOwnedRoutes.activeUserScope = _lastObservedUserScope;
    _observedAppState!.addListener(_handleAppStateChanged);
    _recoverPendingReminderActivations();
    _startReminderResponseHandling();
  }

  @override
  void dispose() {
    _reminderResponseSubscription?.cancel();
    _observedAppState?.removeListener(_handleAppStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _startReminderResponseHandling();
    _recoverPendingReminderActivations();
    final userScope = _observedAppState?.currentUserId;
    if (_hasPendingReminderCancellation ||
        (userScope != null && _observedAppState?.isAuthBusy != true)) {
      _enqueueReminderRecoveryAndReconciliation(userScope);
    }
  }

  void _startReminderResponseHandling() {
    unawaited(
      _reminderResponseCoordinator.source.startResponseHandling().catchError((
        Object error,
      ) {
        debugPrint('[ReminderResponse] initialization unavailable');
      }),
    );
  }

  void _enqueueReminderLifecycle(Future<void> Function() operation) {
    _reminderLifecycleSerial = _reminderLifecycleSerial
        .then((_) => operation())
        .catchError((Object error) {
          debugPrint('[ReminderResponse] schedule reconciliation unavailable');
        });
  }

  bool get _hasPendingReminderCancellation =>
      _completedReminderCancellationGeneration <
      _requestedReminderCancellationGeneration;

  void _requestReminderCancellation() {
    _requestedReminderCancellationGeneration += 1;
  }

  Future<void> _recoverPendingReminderCancellation() async {
    while (_hasPendingReminderCancellation) {
      final targetGeneration = _requestedReminderCancellationGeneration;
      await _cancelScheduledRemindersForRecovery();
      if (targetGeneration > _completedReminderCancellationGeneration) {
        _completedReminderCancellationGeneration = targetGeneration;
      }
    }
  }

  Future<void> _cancelScheduledRemindersForRecovery() async {
    final source = _reminderResponseCoordinator.source;
    if (source is ReminderNotificationResultAccountLifecycle) {
      final lifecycle = source as ReminderNotificationResultAccountLifecycle;
      final result = await lifecycle.cancelScheduledRemindersWithResult();
      if (result.status == ReminderNotificationMutationStatus.superseded) {
        throw const ReminderNotificationMutationSupersededException();
      }
      return;
    }
    await _reminderResponseCoordinator.cancelScheduledReminders();
  }

  void _enqueueReminderRecoveryAndReconciliation(String? expectedUserScope) {
    _enqueueReminderLifecycle(() async {
      // A successful global cancellation is the account-transition barrier.
      // It must settle before a newer account can replay its durable plan.
      await _recoverPendingReminderCancellation();
      if (expectedUserScope == null || !mounted) return;
      final currentState = _observedAppState;
      if (currentState?.currentUserId != expectedUserScope ||
          currentState?.isAuthBusy == true) {
        return;
      }
      await _reminderResponseCoordinator.reconcileScheduleForUser(
        expectedUserScope,
      );
    });
  }

  void _handleAppStateChanged() {
    final state = _observedAppState;
    final currentScope = _observedAppState?.currentUserId;
    final previousScope = _lastObservedUserScope;
    if (previousScope != null && currentScope != previousScope) {
      _reminderAccountEpoch += 1;
      _pendingReminderResponses.clear();
      _queuedReminderActivationIds.clear();
      final navigator = _routerDelegate.navigatorKey.currentState;
      _accountOwnedRoutes.removeRoutesOwnedBy(previousScope, navigator);
      debugPrint('[ReminderResponse] pending_cleared_for_account_change');
      _lastReconciledUserScope = null;
      _reminderActivationAccountGate = _reminderActivationAccountGate
          .then((_) => _reminderResponseCoordinator.discardPendingActivations())
          .catchError((Object error) {
            debugPrint('[ReminderResponse] activation discard unavailable');
          });
      _requestReminderCancellation();
      _enqueueReminderRecoveryAndReconciliation(null);
    }
    _lastObservedUserScope = currentScope;
    _accountOwnedRoutes.activeUserScope = currentScope;
    if (currentScope != null &&
        state?.isAuthBusy != true &&
        _lastReconciledUserScope != currentScope) {
      _lastReconciledUserScope = currentScope;
      _enqueueReminderRecoveryAndReconciliation(currentScope);
    }
    if (currentScope != null && _pendingReminderResponses.isNotEmpty) {
      _scheduleReminderResponseDrain();
    }
  }

  void _captureReminderResponse(ReminderNotificationResponseEvent event) {
    final accountEpoch = _reminderAccountEpoch;
    unawaited(_persistAndQueueReminderResponse(event, accountEpoch));
  }

  Future<void> _persistAndQueueReminderResponse(
    ReminderNotificationResponseEvent event,
    int accountEpoch,
  ) async {
    await _reminderActivationAccountGate;
    if (!mounted || accountEpoch != _reminderAccountEpoch) return;
    final ReminderNotificationActivation activation;
    try {
      activation = await _reminderResponseCoordinator.capture(event);
    } catch (_) {
      debugPrint('[ReminderResponse] activation persistence unavailable');
      return;
    }
    if (!mounted) return;
    if (accountEpoch != _reminderAccountEpoch) {
      await _reminderResponseCoordinator.discardActivation(activation.id);
      return;
    }
    _queueReminderActivation(activation);
  }

  void _recoverPendingReminderActivations() {
    if (_activationRecoveryInProgress) return;
    _activationRecoveryInProgress = true;
    final accountEpoch = _reminderAccountEpoch;
    unawaited(() async {
      try {
        await _reminderActivationAccountGate;
        if (!mounted || accountEpoch != _reminderAccountEpoch) return;
        final pending = await _reminderResponseCoordinator.pendingActivations();
        if (!mounted || accountEpoch != _reminderAccountEpoch) return;
        for (final activation in pending) {
          _queueReminderActivation(activation);
        }
      } catch (_) {
        debugPrint('[ReminderResponse] activation recovery unavailable');
      } finally {
        _activationRecoveryInProgress = false;
      }
    }());
  }

  void _queueReminderActivation(ReminderNotificationActivation activation) {
    if (!mounted) return;
    if (_queuedReminderActivationIds.contains(activation.id) ||
        _pendingReminderResponses.length >= 8) {
      return;
    }
    _queuedReminderActivationIds.add(activation.id);
    _pendingReminderResponses.add(activation);
    debugPrint(
      '[ReminderResponse] queued origin=${activation.origin.name} '
      'pending=${_pendingReminderResponses.length}',
    );
    _scheduleReminderResponseDrain();
  }

  void _scheduleReminderResponseDrain() {
    if (_responseDrainScheduled || !mounted) return;
    _responseDrainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _responseDrainScheduled = false;
      unawaited(_drainReminderResponse());
    });
    // A notification can arrive while the widget tree is completely idle.
    // addPostFrameCallback alone does not request a frame, so explicitly wake
    // the pipeline or the response could remain queued until an unrelated tap.
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _drainReminderResponse() async {
    if (_isRoutingReminderResponse || _pendingReminderResponses.isEmpty) return;
    final state = context.read<AppState>();
    if (state.isBootstrapping ||
        state.isAuthBusy ||
        !state.isOnboarded ||
        state.requiresFirebaseSignIn ||
        state.currentUserId == null) {
      return;
    }
    final navigator = _routerDelegate.navigatorKey.currentState;
    if (navigator == null) return;

    _isRoutingReminderResponse = true;
    final responseUserScope = state.currentUserId!;
    final activation = _pendingReminderResponses.removeAt(0);
    try {
      final resolution = await _reminderResponseCoordinator.resolveActivation(
        activation: activation,
        userScope: responseUserScope,
      );
      debugPrint('[ReminderResponse] resolved=${resolution.status.name}');
      if (!mounted) return;
      final currentState = context.read<AppState>();
      if (currentState.currentUserId != responseUserScope ||
          currentState.isAuthBusy ||
          !currentState.isOnboarded ||
          currentState.requiresFirebaseSignIn) {
        debugPrint('[ReminderResponse] discarded_after_account_change');
        return;
      }
      switch (resolution.status) {
        case ReminderResponseResolutionStatus.openMealDraft:
          _pushNotificationOwnedRoute(
            navigator,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const EntryPage(key: ValueKey<String>('reminder-meal-draft')),
            ),
          );
          break;
        case ReminderResponseResolutionStatus.openIntakeDraft:
          _pushNotificationOwnedRoute(
            navigator,
            MaterialPageRoute<void>(
              builder: (_) => const IntakeEditorPage(
                key: ValueKey<String>('reminder-intake-draft'),
                requireExplicitMedicationSelection: true,
              ),
            ),
          );
          break;
        case ReminderResponseResolutionStatus.replayed:
          _showReminderResponseMessage('reminders.response_replayed');
          break;
        case ReminderResponseResolutionStatus.unavailable:
        case ReminderResponseResolutionStatus.malformed:
          _pushNotificationOwnedRoute(
            navigator,
            MaterialPageRoute<void>(builder: (_) => const ReminderCenterPage()),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showReminderResponseMessage('reminders.response_unavailable');
          });
          break;
      }
    } finally {
      _isRoutingReminderResponse = false;
      _queuedReminderActivationIds.remove(activation.id);
      if (_pendingReminderResponses.isNotEmpty) {
        _scheduleReminderResponseDrain();
      } else {
        _recoverPendingReminderActivations();
      }
    }
  }

  void _pushNotificationOwnedRoute(
    NavigatorState navigator,
    Route<void> route,
  ) {
    // The root navigator observer assigns every imperative patient-data route
    // to the exact UID that opened it, including notification draft routes and
    // ordinary Settings -> Reminder Center navigation.
    unawaited(navigator.push<void>(route));
  }

  void _showReminderResponseMessage(String key) {
    final messengerContext = _routerDelegate.navigatorKey.currentContext;
    if (messengerContext == null) return;
    ScaffoldMessenger.maybeOf(
      messengerContext,
    )?.showSnackBar(SnackBar(content: Text(messengerContext.appI18n.tr(key))));
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingReminderResponses.isNotEmpty) {
      _scheduleReminderResponseDrain();
    }
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
  _ParkinSUMRouterDelegate(this.bootstrapController, this._accountOwnedRoutes);

  final BootstrapAttemptController bootstrapController;
  final AccountOwnedRouteRegistry _accountOwnedRoutes;
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
      observers: <NavigatorObserver>[_accountOwnedRoutes.observer],
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
