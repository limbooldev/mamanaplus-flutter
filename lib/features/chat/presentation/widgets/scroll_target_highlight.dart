import 'package:flutter/material.dart';

import '../../../../shared/ui/ui.dart';

/// Brief glow around a message after scrolling to it (e.g. reply-quote tap).
class ScrollTargetHighlight extends StatefulWidget {
  const ScrollTargetHighlight({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<ScrollTargetHighlight> createState() => _ScrollTargetHighlightState();
}

class _ScrollTargetHighlightState extends State<ScrollTargetHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glow = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.active) {
      _runPulse();
    }
  }

  @override
  void didUpdateWidget(ScrollTargetHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _runPulse();
    }
  }

  void _runPulse() {
    _controller.forward(from: 0).then((_) {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = _glow.value;
        if (t <= 0.01) {
          return child!;
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppShapes.bubbleRadius + 6),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5 * t),
                blurRadius: 16 * t,
                spreadRadius: 4 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
