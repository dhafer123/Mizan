import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/device_preferences_repository.dart';
import '../../domain/value_objects/settings_error.dart';
import '../../domain/value_objects/settings_failure.dart';
import '../../domain/value_objects/theme_choice.dart';

/// [DevicePreferencesRepository] in the platform's secure storage, next to
/// the app lock: neither is secret, but it saves adding a preferences
/// plugin. Not in drift: both are per device and never synced.
class SecureDevicePreferencesRepository implements DevicePreferencesRepository {
  const SecureDevicePreferencesRepository(this._storage);

  final FlutterSecureStorage _storage;

  static const themeKey = 'prefs.theme';
  static const onboardedKey = 'prefs.onboarded';
  static const reduceMotionKey = 'prefs.reduceMotion';
  static const voiceHintSeenKey = 'prefs.voiceHintSeen';

  static const _failure = SettingsFailure(SettingsError.storage);

  @override
  Future<Result<ThemeChoice, SettingsFailure>> loadThemeChoice() async {
    try {
      final name = await _storage.read(key: themeKey);
      return Ok(ThemeChoice.values.asNameMap()[name] ?? ThemeChoice.system);
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<void, SettingsFailure>> saveThemeChoice(
    ThemeChoice choice,
  ) async {
    try {
      await _storage.write(key: themeKey, value: choice.name);
      return const Ok(null);
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<bool, SettingsFailure>> loadReduceMotion() async {
    try {
      return Ok(await _storage.read(key: reduceMotionKey) == 'true');
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<void, SettingsFailure>> saveReduceMotion({
    required bool on,
  }) async {
    try {
      await _storage.write(key: reduceMotionKey, value: '$on');
      return const Ok(null);
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<bool, SettingsFailure>> loadOnboarded() async {
    try {
      return Ok(await _storage.read(key: onboardedKey) == 'true');
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<void, SettingsFailure>> saveOnboarded() async {
    try {
      await _storage.write(key: onboardedKey, value: 'true');
      return const Ok(null);
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<bool, SettingsFailure>> loadVoiceHintSeen() async {
    try {
      return Ok(await _storage.read(key: voiceHintSeenKey) == 'true');
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<void, SettingsFailure>> saveVoiceHintSeen() async {
    try {
      await _storage.write(key: voiceHintSeenKey, value: 'true');
      return const Ok(null);
    } on Object {
      return const Err(_failure);
    }
  }
}
