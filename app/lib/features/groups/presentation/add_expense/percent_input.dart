/// Parses a typed percentage into basis points (100% = 10000), without
/// doubles: "33.33" → 3333, "50" → 5000, "12,5" → 1250. At most 2 decimals.
/// Null for anything else.
int? parseBasisPoints(String text) {
  final match = RegExp(
    r'^(\d{1,3})(?:[.,](\d{1,2}))?$',
  ).firstMatch(text.trim());
  if (match == null) return null;
  final whole = int.parse(match[1]!);
  final fraction = int.parse((match[2] ?? '').padRight(2, '0'));
  return whole * 100 + fraction;
}
