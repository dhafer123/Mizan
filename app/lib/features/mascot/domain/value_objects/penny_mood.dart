/// Penny's expression. Each has a face; what she says comes from the
/// `PennyReason` behind it.
enum PennyMood {
  /// On track, or nothing to say: soft eyes, blinking.
  calm,

  /// Under budget, or something was just logged.
  happy,

  /// Big moments: a first expense, everyone settled up.
  excited,

  /// The money runs out before payday, or a category is near or over its
  /// limit.
  worried,

  /// An unusually big expense.
  surprised,

  /// Little moments, like finishing setup.
  wink,

  /// Voice input is listening.
  listening,

  /// Offline: changes wait on the phone to sync.
  sleepy,
}
