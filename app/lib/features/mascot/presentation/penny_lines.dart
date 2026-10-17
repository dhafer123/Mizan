import '../../../core/money/money.dart';
import '../domain/value_objects/penny_mood.dart';
import '../domain/value_objects/penny_reason.dart';

/// Something the user just did that Penny reacts to for a few seconds.
enum PennyMoment {
  /// An expense was saved.
  logged(PennyMood.happy),

  /// The first expense of the month was saved.
  firstOfMonth(PennyMood.excited),

  /// Onboarding was finished.
  setupDone(PennyMood.wink);

  const PennyMoment(this.mood);

  final PennyMood mood;
}

/// What Penny says: silly on purpose, never shaming. Every line keeps the
/// facts of its reason (a date, an amount, a category), so the joke never
/// hides the information. Edit freely; `penny_lines_test.dart` only checks
/// the facts are there.
abstract final class PennyLines {
  /// The lines for [reason]; [day] and [money] format its facts.
  static List<String> forReason(
    PennyReason reason, {
    required String Function(DateTime) day,
    required String Function(Money) money,
  }) => switch (reason) {
    RunningOut(alreadyOut: true, :final payday?) => [
      "This month's money has run out, and payday is ${day(payday)}. "
          "I'll be brave if you will.",
      'We hit zero: the money has run out, and payday is ${day(payday)}. '
          'Pasta and water, gourmet edition?',
    ],
    RunningOut(alreadyOut: true) => [
      "This month's money has run out, and no income is scheduled. "
          'I need a hug. Or a budget.',
    ],
    RunningOut(:final runOut, :final payday?) => [
      'Uh-oh. At this pace the money runs out around ${day(runOut)}, and '
          'payday is ${day(payday)}. Snacks are not a food group.',
      'I did the maths with my tiny mittens: we run dry around '
          '${day(runOut)}. Payday is ${day(payday)}. Pasta night? Again?',
      'Heads up! Money runs out around ${day(runOut)}, payday is '
          "${day(payday)}. I'm hiding the snacks in my hood.",
    ],
    RunningOut(:final runOut) => [
      'At this pace the money runs out around ${day(runOut)}, and no '
          "income is scheduled. I'm nervous-sweating. Do I sweat? "
          'Apparently.',
      "Money runs out around ${day(runOut)}, and I don't see any income "
          'coming. Should we add some?',
    ],
    OverLimit(:final category, :final over) => [
      "$category is over its limit by ${money(over)}. I'm not mad. "
          "I'm just... recalculating.",
      '$category went ${money(over)} over budget. It happens to the best '
          'of us. Mostly to me.',
      'Psst: $category is ${money(over)} past its limit. Give it a little '
          'rest this month?',
    ],
    NearLimit(:final category, :final percent) => [
      '$category is at $percent% of its limit. Easy there, champ.',
      '$percent% of the $category budget is gone. I am guarding the rest '
          'with my life. Or my hood.',
      '$category: $percent% used. Not panicking. Just watching. Closely.',
    ],
    BigExpense(:final category, :final amount) => [
      'Whoa, ${money(amount)} on $category? Way more than usual. Hope it '
          'was worth it!',
      '${money(amount)} on $category! My eyes went round. A treat? You '
          'deserve treats. Sometimes.',
    ],
    Offline() => [
      "No internet. I'm keeping your changes safe in my hood, and they'll "
          "sync when we're back online.",
      'Offline. Everything you log is saved here and syncs later. Zzz.',
    ],
    NeedsIncome() => [
      "Tell me about your income and I'll tell you how long your money "
          'lasts. Deal?',
      "I can't forecast on vibes alone. Add your income and I'll do the "
          'maths.',
    ],
    QuietMonth() => [
      'Nothing spent yet this month. Suspiciously quiet... are you living '
          'on air?',
      "A fresh month, a clean slate! Log your first expense and I'll start "
          'counting.',
    ],
    Learning(:final daysToGo) => [
      "I'm still learning how you spend: ${_days(daysToGo)} more of "
          "logging and I'll forecast for you.",
      "Keep logging! ${_days(daysToGo)} more and I'll know your habits "
          'better than you do.',
    ],
    OnTrack(:final until, untilPayday: true) => [
      'Money lasts past payday (${day(until)}). We are basically financial '
          'wizards.',
      'On track! The money lasts until payday on ${day(until)}. Tiny '
          'victory dance.',
      "All good until payday (${day(until)}). Keep this up and I'll stop "
          'worrying. Mostly.',
    ],
    OnTrack(:final until) => [
      'At this pace the money lasts past ${day(until)}. Are you secretly a '
          'squirrel?',
      "On track: the money lasts past ${day(until)}. I'm so proud I could "
          'glow. Oh wait, I do.',
    ],
  };

  static List<String> forMoment(PennyMoment moment) => switch (moment) {
    PennyMoment.logged => [
      'Logged! Future you says thanks.',
      'Got it. Another one for the books.',
      'Noted! My tiny mittens wrote it down.',
    ],
    PennyMoment.firstOfMonth => [
      "First expense of the month! I'm so proud I could cry. (I can't. "
          'No tear ducts.)',
    ],
    PennyMoment.setupDone => [
      "All set! Let's make this month's money last.",
      'Setup done. You and me against the end of the month.',
    ],
  };

  /// One of [lines], the same one for the same [pick].
  static String pick(List<String> lines, int pick) =>
      lines[pick % lines.length];

  static String _days(int n) => n == 1 ? '1 day' : '$n days';
}
