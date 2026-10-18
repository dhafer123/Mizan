import 'package:flutter/material.dart';

/// While a screen loads: grey shapes in the layout of what's coming, with a
/// soft shine sweeping across (still with reduced motion). Screen readers
/// hear "Loading".
class Skeleton extends StatefulWidget {
  const Skeleton({required this.child, super.key});

  /// Built from [SkeletonBox]es.
  final Widget child;

  static const shine = Duration(milliseconds: 1400);

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: Skeleton.shine,
  );

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest;
    // Dark's surface tones are too close to show a shine, so it leans
    // towards the text colour there; light's paler surface shows well.
    final shine = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(base, colors.onSurface, 0.12)!
        : colors.surfaceContainerLow;
    final shapes = ExcludeSemantics(child: widget.child);
    return Semantics(
      label: 'Loading',
      container: true,
      child: _still
          ? shapes
          : AnimatedBuilder(
              animation: _shine,
              builder: (context, child) => ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) => LinearGradient(
                  colors: [base, shine, base],
                  stops: const [0.35, 0.5, 0.65],
                  // Sweeps from off the left edge to off the right.
                  begin: Alignment(-3 + 4 * _shine.value, -0.3),
                  end: Alignment(-1 + 4 * _shine.value, 0.3),
                ).createShader(bounds),
                child: child,
              ),
              child: shapes,
            ),
    );
  }
}

/// One grey shape in a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 14,
    this.radius = 6,
    this.circle = false,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: circle ? height : width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

/// A loading list: rows of an avatar, two lines of text and an amount.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 6, super.key});

  final int rows;

  // Varied widths, so the rows read as text.
  static const _widths = [0.7, 0.5, 0.6, 0.45];

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const SkeletonBox(height: 40, circle: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: _widths[i % _widths.length],
                          child: const SkeletonBox(),
                        ),
                        const SizedBox(height: 8),
                        const FractionallySizedBox(
                          widthFactor: 0.3,
                          child: SkeletonBox(height: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const SkeletonBox(width: 56),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A loading page of cards, [heights] tall, like Home or Budget.
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({required this.heights, super.key});

  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (final height in heights)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: height, radius: 20),
            ),
        ],
      ),
    );
  }
}
