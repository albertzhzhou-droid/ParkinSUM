import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/state/app_state_slices.dart';

void main() {
  test('shell slice equality ignores unrelated app state', () {
    const first = ShellStateSlice(
      userId: 'alice',
      userEmail: 'alice@example.test',
      isAuthBusy: false,
    );
    const same = ShellStateSlice(
      userId: 'alice',
      userEmail: 'alice@example.test',
      isAuthBusy: false,
    );
    const busy = ShellStateSlice(
      userId: 'alice',
      userEmail: 'alice@example.test',
      isAuthBusy: true,
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(busy));
  });

  test('catalog slice compares active IDs as a set', () {
    final first = CatalogStateSlice(
      catalogRevision: 4,
      activeDrugIds: {'a', 'b'},
    );
    final reordered = CatalogStateSlice(
      catalogRevision: 4,
      activeDrugIds: {'b', 'a'},
    );
    final changed = CatalogStateSlice(
      catalogRevision: 5,
      activeDrugIds: {'a', 'b'},
    );

    expect(first, reordered);
    expect(first.hashCode, reordered.hashCode);
    expect(first, isNot(changed));
  });
}
