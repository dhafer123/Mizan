/// Periodic sync while the app is closed (Android WorkManager).
abstract interface class BackgroundSync {
  /// Schedules it (idempotent). Called once an account is signed in.
  Future<void> enable();

  /// Cancels it. Called on sign-out.
  Future<void> disable();
}
