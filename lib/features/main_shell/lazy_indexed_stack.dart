import 'package:flutter/widgets.dart';

import '../../core/theme/paper_theme.dart';

/// Builds each tab only on first visit, then keeps its element tree alive.
///
/// Switching tabs fades the incoming tab up into place (a short "turn of the
/// page"); every child keeps the same wrapper shape so state is preserved,
/// and the motion is skipped under the platform's reduced-motion setting.
///
/// Unlike a plain `pages[index]`, previously visited tabs retain local state.
/// Unlike an eager [IndexedStack], tabs that have never been opened do not pay
/// their build cost. Inactive tabs also have tickers disabled.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  }) : assert(builders.length > 0),
       assert(index >= 0 && index < builders.length);

  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack>
    with SingleTickerProviderStateMixin {
  late List<Widget?> _children;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Paper.motionMedium,
    value: 1,
  );
  late final Animation<double> _entranceCurve = CurvedAnimation(
    parent: _entrance,
    curve: Paper.motionCurve,
  );
  late final Animation<Offset> _entranceOffset = Tween<Offset>(
    begin: const Offset(0, 0.012),
    end: Offset.zero,
  ).animate(_entranceCurve);

  @override
  void initState() {
    super.initState();
    _children = List<Widget?>.filled(widget.builders.length, null);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (Paper.motion(context, Paper.motionMedium) == Duration.zero) {
        _entrance.value = 1;
      } else {
        _entrance.forward(from: 0);
      }
    }
    if (oldWidget.builders.length == widget.builders.length) return;
    final previous = _children;
    _children = List<Widget?>.filled(widget.builders.length, null);
    for (
      var index = 0;
      index < previous.length && index < _children.length;
      index++
    ) {
      _children[index] = previous[index];
    }
  }

  Widget _childAt(int index) {
    return _children[index] ??= KeyedSubtree(
      key: ValueKey<String>('lazy-indexed-stack-child-$index'),
      child: Builder(builder: widget.builders[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    _childAt(widget.index);
    return IndexedStack(
      index: widget.index,
      children: List<Widget>.generate(widget.builders.length, (index) {
        final active = index == widget.index;
        return TickerMode(
          enabled: active,
          child: FadeTransition(
            opacity: active ? _entranceCurve : kAlwaysCompleteAnimation,
            child: SlideTransition(
              position: active
                  ? _entranceOffset
                  : const AlwaysStoppedAnimation<Offset>(Offset.zero),
              child: _children[index] ?? const SizedBox.shrink(),
            ),
          ),
        );
      }, growable: false),
    );
  }
}
