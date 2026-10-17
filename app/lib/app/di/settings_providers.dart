import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/settings/data/export/platform_file_exporter.dart';
import '../../features/settings/data/lock/local_auth_biometric_authenticator.dart';
import '../../features/settings/data/lock/secure_lock_settings_repository.dart';
import '../../features/settings/data/preferences/secure_device_preferences_repository.dart';
import '../../features/settings/domain/repositories/biometric_authenticator.dart';
import '../../features/settings/domain/repositories/device_preferences_repository.dart';
import '../../features/settings/domain/repositories/file_exporter.dart';
import '../../features/settings/domain/repositories/lock_settings_repository.dart';
import '../../features/settings/domain/usecases/disable_lock.dart';
import '../../features/settings/domain/usecases/export_expenses_csv.dart';
import '../../features/settings/domain/usecases/finish_onboarding.dart';
import '../../features/settings/domain/usecases/get_lock_status.dart';
import '../../features/settings/domain/usecases/get_theme_choice.dart';
import '../../features/settings/domain/usecases/needs_onboarding.dart';
import '../../features/settings/domain/usecases/set_biometric_unlock.dart';
import '../../features/settings/domain/usecases/set_pin.dart';
import '../../features/settings/domain/usecases/set_theme_choice.dart';
import '../../features/settings/domain/usecases/should_lock_on_resume.dart';
import '../../features/settings/domain/usecases/unlock_with_biometrics.dart';
import '../../features/settings/domain/usecases/unlock_with_pin.dart';
import '../../features/settings/domain/usecases/validate_pin.dart';
import 'budget_providers.dart';
import 'core_providers.dart';
import 'expenses_providers.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
LockSettingsRepository lockSettingsRepository(Ref ref) =>
    const SecureLockSettingsRepository(FlutterSecureStorage());

@Riverpod(keepAlive: true)
BiometricAuthenticator biometricAuthenticator(Ref ref) =>
    LocalAuthBiometricAuthenticator(LocalAuthentication());

@Riverpod(keepAlive: true)
FileExporter fileExporter(Ref ref) => const PlatformFileExporter();

@Riverpod(keepAlive: true)
GetLockStatus getLockStatus(Ref ref) => GetLockStatus(
  ref.watch(lockSettingsRepositoryProvider),
  ref.watch(biometricAuthenticatorProvider),
);

@Riverpod(keepAlive: true)
SetPin setPin(Ref ref) =>
    SetPin(ref.watch(lockSettingsRepositoryProvider), const ValidatePin());

@Riverpod(keepAlive: true)
DisableLock disableLock(Ref ref) =>
    DisableLock(ref.watch(lockSettingsRepositoryProvider));

@Riverpod(keepAlive: true)
SetBiometricUnlock setBiometricUnlock(Ref ref) => SetBiometricUnlock(
  ref.watch(lockSettingsRepositoryProvider),
  ref.watch(biometricAuthenticatorProvider),
);

/// Keeps the wrong-PIN count for the app run.
@Riverpod(keepAlive: true)
UnlockWithPin unlockWithPin(Ref ref) => UnlockWithPin(
  ref.watch(lockSettingsRepositoryProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
UnlockWithBiometrics unlockWithBiometrics(Ref ref) => UnlockWithBiometrics(
  ref.watch(lockSettingsRepositoryProvider),
  ref.watch(biometricAuthenticatorProvider),
);

@Riverpod(keepAlive: true)
ShouldLockOnResume shouldLockOnResume(Ref ref) => const ShouldLockOnResume();

@Riverpod(keepAlive: true)
ExportExpensesCsv exportExpensesCsv(Ref ref) => ExportExpensesCsv(
  ref.watch(expenseRepositoryProvider),
  ref.watch(categoryRepositoryProvider),
  ref.watch(fileExporterProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
DevicePreferencesRepository devicePreferencesRepository(Ref ref) =>
    const SecureDevicePreferencesRepository(FlutterSecureStorage());

@Riverpod(keepAlive: true)
GetThemeChoice getThemeChoice(Ref ref) =>
    GetThemeChoice(ref.watch(devicePreferencesRepositoryProvider));

@Riverpod(keepAlive: true)
SetThemeChoice setThemeChoice(Ref ref) =>
    SetThemeChoice(ref.watch(devicePreferencesRepositoryProvider));

@Riverpod(keepAlive: true)
NeedsOnboarding needsOnboarding(Ref ref) => NeedsOnboarding(
  ref.watch(devicePreferencesRepositoryProvider),
  ref.watch(expenseRepositoryProvider),
  ref.watch(incomeSourceRepositoryProvider),
  ref.watch(budgetRepositoryProvider),
);

@Riverpod(keepAlive: true)
FinishOnboarding finishOnboarding(Ref ref) =>
    FinishOnboarding(ref.watch(devicePreferencesRepositoryProvider));
