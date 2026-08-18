import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/main_shell/lazy_indexed_stack.dart';

void main() {
  testWidgets('builds tabs lazily and preserves visited tab state', (
    tester,
  ) async {
    final initCounts = <int>[0, 0, 0];

    await tester.pumpWidget(
      MaterialApp(home: _Harness(initCounts: initCounts)),
    );

    expect(initCounts, <int>[1, 0, 0]);
    await tester.enterText(
      find.byKey(const ValueKey<String>('tab-field-0')),
      'unsaved draft',
    );

    await tester.tap(find.byKey(const ValueKey<String>('show-tab-1')));
    await tester.pump();
    expect(initCounts, <int>[1, 1, 0]);

    await tester.tap(find.byKey(const ValueKey<String>('show-tab-0')));
    await tester.pump();
    expect(initCounts, <int>[1, 1, 0]);
    expect(find.text('unsaved draft'), findsOneWidget);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({required this.initCounts});

  final List<int> initCounts;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              for (var index = 0; index < 3; index++)
                TextButton(
                  key: ValueKey<String>('show-tab-$index'),
                  onPressed: () => setState(() => _index = index),
                  child: Text('Tab $index'),
                ),
            ],
          ),
          Expanded(
            child: LazyIndexedStack(
              index: _index,
              builders: [
                for (var index = 0; index < 3; index++)
                  (_) => _StatefulTab(
                    index: index,
                    onInit: () => widget.initCounts[index] += 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatefulTab extends StatefulWidget {
  const _StatefulTab({required this.index, required this.onInit});

  final int index;
  final VoidCallback onInit;

  @override
  State<_StatefulTab> createState() => _StatefulTabState();
}

class _StatefulTabState extends State<_StatefulTab> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(key: ValueKey<String>('tab-field-${widget.index}'));
  }
}
