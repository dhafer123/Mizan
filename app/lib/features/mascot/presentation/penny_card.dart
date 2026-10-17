import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/core_providers.dart';
import '../../../core/money/money_formatter.dart';
import '../domain/value_objects/penny_mood.dart';
import 'penny_head.dart';
import 'penny_lines.dart';
import 'penny_providers.dart';

/// Penny at the top of Home: her face for how the month is going, and what
/// she has to say about it in a speech bubble. Tap her for another line.
///
/// She reacts to what was just done (an expense saved, setup finished) for a
/// few seconds. If her mood can't be worked out she simply isn't shown: she
/// never stands between the user and their numbers.
class PennyCard extends ConsumerStatefulWidget {
  const PennyCard({super.key});

  @override
  ConsumerState<PennyCard> createState() => _PennyCardState();
}

class _PennyCardState extends ConsumerState<PennyCard> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) {
    final reaction = ref.watch(pennyReactionProvider);
    final home = ref.watch(pennyHomeProvider).value;
    // The same line all day, until she's tapped.
    final today = ref.watch(clockProvider).now();
    final pick = today.difference(DateTime.utc(today.year)).inDays + _taps;

    final PennyMood mood;
    final String line;
    if (reaction != null) {
      mood = reaction.mood;
      line = PennyLines.pick(PennyLines.forMoment(reaction), pick);
    } else if (home != null) {
      mood = home.mood;
      line = PennyLines.pick(
        PennyLines.forReason(
          home.reason,
          day: (d) => MaterialLocalizations.of(
            context,
          ).formatShortMonthDay(DateTime(d.year, d.month, d.day)),
          money: const MoneyFormatter().format,
        ),
        pick,
      );
    } else {
      return const SizedBox.shrink();
    }

    return Semantics(
      button: true,
      onTapHint: 'hear something else',
      child: InkWell(
        key: const ValueKey('pennyCard'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _taps++),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              PennyHead(mood: mood, size: 72, pokes: _taps),
              const SizedBox(width: 4),
              Expanded(child: _Bubble(text: line)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A speech bubble with a little tail pointing at Penny.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.surfaceContainerHigh;
    final still = MediaQuery.disableAnimationsOf(context);
    return CustomPaint(
      painter: _TailPainter(color),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 250),
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [...previous, ?current],
          ),
          child: Semantics(
            key: ValueKey(text),
            label: 'Penny says',
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(0, y)
        ..lineTo(10, y - 7)
        ..lineTo(10, y + 7)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
