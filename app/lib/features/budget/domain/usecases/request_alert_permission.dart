import '../repositories/alert_notifier.dart';

/// Asks once for permission to show budget alerts (Android 13+ asks the
/// user; elsewhere it does nothing).
class RequestAlertPermission {
  const RequestAlertPermission(this._notifier);

  final AlertNotifier _notifier;

  Future<void> call() => _notifier.requestPermission();
}
