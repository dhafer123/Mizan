import 'package:flutter/services.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/file_exporter.dart';
import '../../domain/value_objects/settings_error.dart';
import '../../domain/value_objects/settings_failure.dart';

/// [FileExporter] over a platform channel. On Android, `MainActivity`
/// opens the system "save as" picker (Storage Access Framework) and writes
/// the bytes where the user chose: no storage permission needed.
class PlatformFileExporter implements FileExporter {
  const PlatformFileExporter([this._channel = channel]);

  static const channel = MethodChannel('mizan/file_export');

  final MethodChannel _channel;

  @override
  Future<Result<bool, SettingsFailure>> save({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    try {
      final saved = await _channel.invokeMethod<bool>('save', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': Uint8List.fromList(bytes),
      });
      return Ok(saved ?? false);
    } on Object {
      // PlatformException (write failed), or MissingPluginException off
      // Android.
      return const Err(SettingsFailure(SettingsError.exportFailed));
    }
  }
}
