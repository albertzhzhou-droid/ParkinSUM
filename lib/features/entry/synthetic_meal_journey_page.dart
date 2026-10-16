import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/synthetic_meal_journey.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/services/services.dart';
import '../../core/state/app_state.dart';
import '../meals/meal_page.dart';

/// A nested navigator inherits only the fresh in-memory graph, so ordinary
/// entry / history routes exercise the product without touching user storage.
class SyntheticMealJourneyPage extends StatefulWidget {
  const SyntheticMealJourneyPage({super.key});
  @override
  State<SyntheticMealJourneyPage> createState() =>
      _SyntheticMealJourneyPageState();
}

class _SyntheticMealJourneyPageState extends State<SyntheticMealJourneyPage> {
  AppState? _state;
  bool _started = false;
  late Future<AppState> _ready;
  int _generation = 0;
  late String _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _locale = context.appI18n.localeTag;
      _ready = _createState();
    }
  }

  Future<AppState> _createState() async {
    final generation = _generation;
    final state = AppState(services: Services.createEphemeral());
    try {
      await state.services.ready;
      await state.bootstrap();
      await state.saveUserProfile(
        state.userProfile.copyWith(displayLocale: _locale),
      );
      final foods = syntheticMealJourneyFoods();
      state.services.foodRepository.replaceAll(foods);
      await state.addMeal(syntheticMealJourneyHistory(foods.first));
      if (!mounted || generation != _generation) {
        throw StateError('synthetic_meal_session_superseded');
      }
      _state = state;
      return state;
    } catch (_) {
      state.dispose();
      rethrow;
    }
  }

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = context.appI18n.languageFamily == 'zh';
    return Scaffold(
      appBar: AppBar(
        title: Text(zh ? '餐食流程合成试用' : 'Synthetic meal journey'),
        actions: [
          IconButton(
            key: const Key('synthetic-meal-reset'),
            tooltip: zh ? '重置合成试用' : 'Reset synthetic trial',
            icon: const Icon(Icons.restart_alt),
            onPressed: () {
              _state?.dispose();
              _state = null;
              setState(() {
                _generation += 1;
                _ready = _createState();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              zh
                  ? '合成数据，独立内存环境。复用历史餐 → 确认时间/份量 → 来源预览 → 保存/依据。离开页面可恢复草稿；重置会清除本试用全部状态。'
                  : 'Synthetic data in isolated memory. Reuse history → confirm time/grams → source preview → save/evidence. Leave entry and reopen to restore its draft. Reset clears this trial.',
            ),
          ),
          Expanded(
            child: FutureBuilder<AppState>(
              key: ValueKey('synthetic-meal-state-$_generation'),
              future: _ready,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      zh
                          ? '合成试用初始化失败。请重置重试。'
                          : 'Synthetic trial could not start. Reset to retry.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ChangeNotifierProvider<AppState>.value(
                  value: snapshot.data!,
                  child: Navigator(
                    key: ValueKey('synthetic-meal-navigator-$_generation'),
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => const MealPage(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
