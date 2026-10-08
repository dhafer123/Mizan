import '../value_objects/ocr_line.dart';

/// Puts OCR lines back into the receipt's printed rows, top to bottom.
///
/// Text recognition returns blocks, and a receipt's "TOTAL" and its amount
/// often land in different ones (left and right columns). Lines whose
/// vertical middles fall inside each other's height are one row, read left
/// to right and joined with two spaces.
class GroupReceiptRows {
  const GroupReceiptRows();

  List<String> call(List<OcrLine> lines) {
    final sorted = [
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line,
    ]..sort((a, b) => (a.top + a.bottom).compareTo(b.top + b.bottom));

    final rows = <List<OcrLine>>[];
    for (final line in sorted) {
      final middle = (line.top + line.bottom) / 2;
      final row = rows.isEmpty ? null : rows.last;
      final joins =
          row != null &&
          row.any((other) {
            final otherMiddle = (other.top + other.bottom) / 2;
            return (middle >= other.top && middle <= other.bottom) ||
                (otherMiddle >= line.top && otherMiddle <= line.bottom);
          });
      if (joins) {
        row.add(line);
      } else {
        rows.add([line]);
      }
    }
    return [
      for (final row in rows)
        ([...row]..sort((a, b) => a.left.compareTo(b.left)))
            .map((l) => l.text.trim())
            .join('  '),
    ];
  }
}
