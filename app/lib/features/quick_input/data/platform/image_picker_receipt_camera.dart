import 'package:image_picker/image_picker.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/receipt_camera.dart';
import '../../domain/value_objects/quick_input_error.dart';
import '../../domain/value_objects/quick_input_failure.dart';

/// [ReceiptCamera] on image_picker 1.2.3: the system camera or photo
/// picker, so Mizan needs no camera permission of its own. The photo is
/// scaled to at most [maxSide] pixels, plenty for text recognition.
class ImagePickerReceiptCamera implements ReceiptCamera {
  ImagePickerReceiptCamera([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const maxSide = 2000.0;

  @override
  Future<Result<String?, QuickInputFailure>> take({
    required bool fromGallery,
  }) async {
    try {
      final photo = await _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      return Ok(photo?.path);
    } on Object {
      return const Err(QuickInputFailure(QuickInputError.cameraUnavailable));
    }
  }
}
