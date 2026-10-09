import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/usage_sharing.dart';
import '../../domain/repositories/usage_sharing_repository.dart';
import '../../domain/value_objects/beta_error.dart';
import '../../domain/value_objects/beta_failure.dart';

/// [UsageSharingRepository] in the platform's secure storage, next to the
/// app lock. Not in drift: it is per device and never synced. Days are
/// stored as `YYYY-MM-DD`.
class SecureUsageSharingRepository implements UsageSharingRepository {
  const SecureUsageSharingRepository(this._storage);

  final FlutterSecureStorage _storage;

  static const installIdKey = 'usage.installId';
  static const sinceKey = 'usage.since';
  static const lastSentKey = 'usage.lastSentDay';

  static const _failure = BetaFailure(BetaError.storage);

  @override
  Future<Result<UsageSharing?, BetaFailure>> load() async {
    try {
      final installId = await _storage.read(key: installIdKey);
      final since = _day(await _storage.read(key: sinceKey));
      if (installId == null || since == null) return const Ok(null);
      return Ok(
        UsageSharing(
          installId: installId,
          since: since,
          lastSentDay: _day(await _storage.read(key: lastSentKey)),
        ),
      );
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<void, BetaFailure>> save(UsageSharing? sharing) async {
    try {
      if (sharing == null) {
        // The id goes first: without it sharing is off either way.
        await _storage.delete(key: installIdKey);
        await _storage.delete(key: sinceKey);
        await _storage.delete(key: lastSentKey);
        return const Ok(null);
      }
      await _storage.write(key: sinceKey, value: _text(sharing.since));
      final lastSent = sharing.lastSentDay;
      if (lastSent == null) {
        await _storage.delete(key: lastSentKey);
      } else {
        await _storage.write(key: lastSentKey, value: _text(lastSent));
      }
      await _storage.write(key: installIdKey, value: sharing.installId);
      return const Ok(null);
    } on Object {
      return const Err(_failure);
    }
  }

  static String _text(DateTime day) => day.toIso8601String().substring(0, 10);

  static DateTime? _day(String? text) =>
      text == null ? null : DateTime.tryParse('${text}T00:00:00Z');
}
