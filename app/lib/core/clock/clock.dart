/// The source of "now". Domain code asks a [Clock] instead of calling
/// `DateTime.now()`, so tests can control time.
///
/// Wall-clock time is for display and for dating expenses only. Sync ordering
/// uses the server's `serverSeq`, never device clocks.
abstract interface class Clock {
  DateTime now();
}
