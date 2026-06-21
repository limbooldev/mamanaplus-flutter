import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

/// Visual style for [LikeButton].
enum LikeButtonStyle {
  /// Compact heart icon with adjacent count (feed cards).
  icon,

  /// Tonal filled button with icon + count (post detail).
  tonal,
}

/// Like button that shows the standard heart icon always, and overlays
/// a Lottie burst animation (playing once) whenever the post is liked.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
    this.iconSize = 26,
    this.style = LikeButtonStyle.icon,
  });

  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;

  /// Size of the underlying heart icon (the Lottie overlay is 3× this).
  final double iconSize;
  final LikeButtonStyle style;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _lottieCtrl;
  bool _animating = false;

  @override
  void dispose() {
    _lottieCtrl?.dispose();
    super.dispose();
  }

  void _onLottieLoaded(LottieComposition composition) {
    final ctrl = AnimationController(vsync: this, duration: composition.duration);
    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _animating = false);
        ctrl.reset();
      }
    });
    // setState is required so the Lottie widget rebuilds with the real
    // controller. Without it the widget stays wired to the original null
    // controller and never plays even when ctrl.forward() is called.
    setState(() => _lottieCtrl = ctrl);
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      final ctrl = _lottieCtrl;
      if (ctrl != null) {
        setState(() => _animating = true);
        ctrl.forward(from: 0);
      }
    }
  }

  // The Lottie widget is kept in the tree (invisible) so the composition
  // loads before the user ever taps, making the first-like animation instant.
  Widget _lottiePreloader(double size) {
    return Opacity(
      opacity: _animating ? 1.0 : 0.0,
      child: IgnorePointer(
        child: Lottie.asset(
          'assets/lottie/like_animated.json',
          controller: _lottieCtrl,
          onLoaded: _onLottieLoaded,
          width: size,
          height: size,
          fit: BoxFit.contain,
          // Never auto-play — we drive it entirely via the controller.
          animate: false,
        ),
      ),
    );
  }

  /// Wraps [child] in a Stack where the Lottie plays centered and overlaid.
  /// The Stack is sized by [child] so the layout footprint is unchanged;
  /// [Positioned.fill] + [OverflowBox] let the Lottie render larger than the
  /// button area without displacing adjacent widgets.
  Widget _withOverlay({required Widget child, required double iconSize}) {
    final overlaySize = iconSize * 3.2;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: OverflowBox(
            minWidth: 0,
            maxWidth: overlaySize,
            minHeight: 0,
            maxHeight: overlaySize,
            child: _lottiePreloader(overlaySize),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final heartColor =
        widget.isLiked ? Colors.redAccent : onSurface;

    final heartIcon = Icon(
      widget.isLiked ? Icons.favorite : Icons.favorite_border,
      color: heartColor,
      size: widget.iconSize,
    );

    switch (widget.style) {
      case LikeButtonStyle.icon:
        final button = _withOverlay(
          iconSize: widget.iconSize,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.onTap,
            icon: heartIcon,
          ),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button,
            Text(
              '${widget.likeCount}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onSurface,
              ),
            ),
          ],
        );

      case LikeButtonStyle.tonal:
        return FilledButton.tonalIcon(
          onPressed: widget.onTap,
          icon: _withOverlay(
            iconSize: widget.iconSize,
            child: heartIcon,
          ),
          label: Text('${widget.likeCount}'),
        );
    }
  }
}

/// Wraps post media with double-tap-to-like and a large floating heart overlay.
class DoubleTapLikeOverlay extends StatefulWidget {
  const DoubleTapLikeOverlay({
    super.key,
    required this.child,
    required this.isLiked,
    required this.onLike,
  });

  final Widget child;
  final bool isLiked;
  final VoidCallback onLike;

  @override
  State<DoubleTapLikeOverlay> createState() => _DoubleTapLikeOverlayState();
}

class _DoubleTapLikeOverlayState extends State<DoubleTapLikeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _showHeart = false;

  static const _duration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);

    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showHeart = false);
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (!widget.isLiked) {
      widget.onLike();
    }
    setState(() => _showHeart = true);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTap: _handleDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: widget.child,
        ),
        if (_showHeart)
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 90,
                      shadows: [
                        Shadow(blurRadius: 16, color: Colors.black38),
                        Shadow(blurRadius: 4, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
