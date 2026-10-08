import 'package:freezed_annotation/freezed_annotation.dart';

part 'ocr_line.freezed.dart';

/// A line of text found on a photo, with its box in pixels (y grows
/// downwards).
@freezed
abstract class OcrLine with _$OcrLine {
  const factory OcrLine({
    required String text,
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) = _OcrLine;
}
