import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/quick_input/domain/usecases/group_receipt_rows.dart';
import 'package:mizan/features/quick_input/domain/value_objects/ocr_line.dart';

OcrLine _at(
  String text, {
  required int left,
  required int top,
  int height = 30,
}) => OcrLine(
  text: text,
  left: left,
  top: top,
  right: left + 100,
  bottom: top + height,
);

void main() {
  const group = GroupReceiptRows();

  test('a label and its amount in separate blocks make one row', () {
    final rows = group([
      // ML Kit order: the right column comes after the left one.
      _at('MONOPRIX', left: 50, top: 0),
      _at('TOTAL TTC', left: 10, top: 200),
      _at('PAIN', left: 10, top: 100),
      _at('1,900', left: 300, top: 102),
      _at('5,250', left: 300, top: 205),
    ]);
    expect(rows, ['MONOPRIX', 'PAIN  1,900', 'TOTAL TTC  5,250']);
  });

  test('a slightly skewed amount still joins its row', () {
    final rows = group([
      _at('TOTAL', left: 10, top: 100),
      _at('7,950', left: 300, top: 112),
      _at('MERCI', left: 10, top: 160),
    ]);
    expect(rows, ['TOTAL  7,950', 'MERCI']);
  });

  test('blank lines are dropped; no lines, no rows', () {
    expect(group([_at('  ', left: 0, top: 0)]), isEmpty);
    expect(group(const []), isEmpty);
  });
}
