import 'dart:convert';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/domain/repositories/file_exporter.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';

/// A [FileExporter] that keeps what it was asked to save.
class FakeFileExporter implements FileExporter {
  /// False to act as if the user cancelled the picker.
  bool saves = true;

  /// When set, [save] fails with this.
  SettingsFailure? failure;

  String? fileName;
  String? mimeType;
  List<int>? bytes;

  /// The saved bytes as text.
  String? get text => bytes == null ? null : utf8.decode(bytes!);

  @override
  Future<Result<bool, SettingsFailure>> save({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (failure case final failure?) return Err(failure);
    if (!saves) return const Ok(false);
    this.fileName = fileName;
    this.mimeType = mimeType;
    this.bytes = bytes;
    return const Ok(true);
  }
}
