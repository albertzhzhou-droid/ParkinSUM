import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/synthetic_meal_journey.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'ephemeral graph seeds and checks without backend initialization or audit persistence',
    () async {
      SharedPreferences.setMockInitialValues({});
      final services = Services.createEphemeral();
      expect(services.isEphemeral, isTrue);
      expect(services.userClinicalAuditService.allowPersistence, isFalse);
      await services.ready;
      final state = AppState(services: services);
      await state.bootstrap();
      expect(state.currentUserId, 'local_user');
      expect(services.foodRepository.allFoods, isNotEmpty);
      final foods = syntheticMealJourneyFoods();
      services.foodRepository.replaceAll(foods);
      final meal = syntheticMealJourneyHistory(foods.first);
      expect((await state.addMeal(meal)).wasCommitted, isTrue);
      expect((await state.checkMeal(meal)).score, 0);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      state.dispose();
    },
  );
}
