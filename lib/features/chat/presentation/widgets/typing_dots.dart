import 'package:flutter/material.dart';

/// Three animated dots for typing indicators (AppBar subtitle, composer area).
class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    this.size = 6,
    this.color,
    this.spacing = 3,
  });

  final double size;
  final Color? color;
  final double spacing;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _animations = _controllers
        .map(
          (c) => Tween<double>(begin: 0.35, end: 1.0).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut),
          ),
        )
        .toList();
    for (var i = 0; i < 3; i++) {
      Future<void>.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : widget.spacing),
          child: AnimatedBuilder(
            animation: _animations[i],
            builder: (context, child) {
              return Opacity(
                opacity: _animations[i].value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
