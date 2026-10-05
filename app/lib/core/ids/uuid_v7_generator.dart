import 'dart:math';

import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import '../clock/clock.dart';
import 'id_generator.dart';

/// UUIDv7 IDs (RFC 9562): a 48-bit millisecond timestamp from [Clock], then
/// random bits. They sort roughly by creation time, which keeps database
/// indexes compact, but they are never used to order changes (that is
/// `serverSeq`).
final class UuidV7Generator implements IdGenerator {
  /// Pass [random] only in tests, for reproducible IDs. By default the random
  /// part comes from a cryptographically secure source.
  UuidV7Generator(this._clock, {Random? random}) : _random = random;

  final Clock _clock;
  final Random? _random;

  static const _uuid = Uuid();

  @override
  String newId() {
    final random = _random;
    final bytes = random == null
        ? null
        : List.generate(10, (_) => random.nextInt(256));
    return _uuid.v7(
      config: V7Options(_clock.now().millisecondsSinceEpoch, bytes),
    );
  }
}
