/// When a UUIDv7 id was made: its 48-bit millisecond timestamp, as a local
/// [DateTime]. Null if [id] is not a UUIDv7 (an id from elsewhere).
///
/// Only for counting things by day (the beta's usage counter). Never for
/// ordering changes: that is `serverSeq`.
DateTime? uuidV7Time(String id) {
  final hex = id.replaceAll('-', '');
  // The version is the 13th hex digit.
  if (hex.length != 32 || hex[12] != '7') return null;
  final millis = int.tryParse(hex.substring(0, 12), radix: 16);
  return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
}
