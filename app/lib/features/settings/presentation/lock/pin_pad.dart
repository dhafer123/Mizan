import 'package:flutter/material.dart';

/// A number pad for PINs: 1-9, then [extra] (or a gap), 0 and delete.
///
/// It uses no tooltips, so it works above the app's navigator (the lock
/// screen), where there is no overlay.
class PinPad extends StatelessWidget {
  const PinPad({
    required this.onDigit,
    required this.onDelete,
    this.extra,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  /// The bottom-left key, e.g. the fingerprint button.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _Key(
      onPressed: () => onDigit(d),
      child: Text(d, style: Theme.of(context).textTheme.headlineSmall),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) digit(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(dimension: _Key.size, child: extra),
            digit('0'),
            _Key(
              onPressed: onDelete,
              child: const Icon(
                Icons.backspace_outlined,
                semanticLabel: 'Delete',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onPressed, required this.child});

  static const size = 76.0;

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(shape: const CircleBorder()),
          child: child,
        ),
      ),
    );
  }
}

/// One dot per digit typed. Shows only how many, never which.
class PinDots extends StatelessWidget {
  const PinDots({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$count digits entered',
      child: SizedBox(
        height: 16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
