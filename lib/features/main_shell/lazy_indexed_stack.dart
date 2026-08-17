import 'package:flutter/widgets.dart';

/// Builds each tab only on first visit, then keeps its element tree alive.
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

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<Widget?> _children;

  @override
  void initState() {
    super.initState();
    _children = List<Widget?>.filled(widget.builders.length, null);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      children: List<Widget>.generate(
        widget.builders.length,
        (index) => TickerMode(
          enabled: index == widget.index,
          child: _children[index] ?? const SizedBox.shrink(),
        ),
        growable: false,
      ),
    );
  }
}
