import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parkinsum_companion/core/services/pinned_timezone_rules_service.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_date_window_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/pinned_timezone_rules.dart';
import 'package:parkinsum_companion/main_personal_log_view_benchmark.dart'
    as benchmark;

void main() {
  testWidgets(
    'benchmark entry verifies formal timezone rules before mounting',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      expect(PinnedTimezoneRules.active, isNull);
      await tester.runAsync(benchmark.main);
      await tester.pump();

      final active = PinnedTimezoneRules.active!;
      expect(active, same(pinnedTimezoneRulesService.loaded));
      expect(active.snapshot.tzdbRelease, '2026e');
      expect(
        active.snapshot.providerIdentity,
        contains(pinnedTimezoneAssetSha256),
      );
      final resolver = PersonalLogDateWindowResolver();
      expect(
        resolver.displayTime(DateTime.utc(2000), 'Etc/UTC').toUtc(),
        DateTime.utc(2000),
      );
      expect(
        () => resolver.displayTime(DateTime.utc(2100), 'Etc/UTC'),
        throwsFormatException,
      );
      expect(
        find.text('Use the separately built release-Web target.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('benchmark-run')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('benchmark-run-persistent')),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
