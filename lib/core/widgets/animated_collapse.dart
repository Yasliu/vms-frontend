import 'package:material_ui/material_ui.dart';

/// Smoothly expands or collapses its child's height (with a fade), so
/// neighbouring widgets glide into the gap instead of jumping.
///
/// Set [animateIn] when the widget is added after the screen is already
/// visible, so it grows into place instead of appearing instantly.
class AnimatedCollapse extends StatefulWidget {
  const AnimatedCollapse({
    super.key,
    required this.visible,
    required this.child,
    this.animateIn = false,
    this.duration = const Duration(milliseconds: 380),
  });

  final bool visible;
  final Widget child;
  final bool animateIn;
  final Duration duration;

  @override
  State<AnimatedCollapse> createState() => _AnimatedCollapseState();
}

class _AnimatedCollapseState extends State<AnimatedCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.visible && !widget.animateIn ? 1 : 0,
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    if (widget.visible && widget.animateIn) _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: SizeTransition(
        sizeFactor: _curved,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: _curved, child: widget.child),
      ),
    );
  }
}
