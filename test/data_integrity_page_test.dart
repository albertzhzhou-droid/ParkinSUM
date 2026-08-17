import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/data_integrity_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('data integrity view renders without fabricating percentages', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const DataIntegrityPage());

    expect(find.byType(DataIntegrityPage), findsOneWidget);
    expect(find.textContaining('0/0 100%'), findsNothing);
    expectNoWidgetErrors(reason: 'data integrity view failed to build cleanly');
  });
}
