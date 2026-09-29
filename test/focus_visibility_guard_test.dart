import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/utils/focus_visibility_guard.dart';

void main() {
  testWidgets('focused descendant is revealed with protected viewport space', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'last-action');
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 260,
            child: FocusVisibilityGuard(
              viewportPadding: 24,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var index = 0; index < 8; index++)
                      SizedBox(height: 80, child: Text('Section $index')),
                    Focus(
                      key: const Key('last-action'),
                      focusNode: focusNode,
                      child: const SizedBox(
                        height: 48,
                        child: Center(child: Text('Last action')),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('last-action')).hitTestable(), findsNothing);
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const Key('last-action')));
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.bottom, lessThanOrEqualTo(260 - 24));
  });
}
