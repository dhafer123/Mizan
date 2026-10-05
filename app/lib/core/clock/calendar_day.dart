/// Expenses are dated by calendar day, not by instant. A day is held as UTC
/// midnight of that date, so "6 October" is the same day on every device and
/// in every time zone.
extension CalendarDay on DateTime {
  /// The calendar day of this moment as read in its own time zone: a local
  /// 23:30 on 6 October is 6 October.
  DateTime get calendarDay => DateTime.utc(year, month, day);

  bool get isCalendarDay =>
      isUtc &&
      hour == 0 &&
      minute == 0 &&
      second == 0 &&
      millisecond == 0 &&
      microsecond == 0;
}
