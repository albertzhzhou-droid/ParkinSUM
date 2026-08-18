import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/services.dart';

void main() {
  test(
    'ephemeral services preserve repository writes without external I/O',
    () async {
      final services = Services.createEphemeral();
      await services.ready;

      expect(await services.userDataService.loadOnboarded(), isFalse);
      expect(await services.appRepository.loadFoods(), isNotEmpty);
      expect(await services.appRepository.loadMedications(), isNotEmpty);

      final profile = UserProfile.defaults().copyWith(
        registrationRegion: 'CA',
        displayLocale: 'fr-CA',
      );
      await services.userDataService.saveUserProfile(profile);
      await services.userDataService.saveActiveDrugIds(<String>[
        'drug_levodopa_carbidopa',
      ]);
      await services.userDataService.saveOnboarded(true);

      expect(
        (await services.userDataService.loadUserProfile()).displayLocale,
        'fr-CA',
      );
      final loadedIds = await services.userDataService.loadActiveDrugIds();
      expect(loadedIds, <String>['drug_levodopa_carbidopa']);
      loadedIds.clear();
      expect(await services.userDataService.loadActiveDrugIds(), <String>[
        'drug_levodopa_carbidopa',
      ], reason: 'reads must not expose the retained list by reference');
      expect(await services.userDataService.loadOnboarded(), isTrue);
    },
  );
}
