import '../value_objects/budget_alert.dart';

/// Shows a budget alert to the user (a local notification).
abstract interface class AlertNotifier {
  /// Asks for permission to notify, where the platform needs it. Does
  /// nothing once answered.
  Future<void> requestPermission();

  /// False if it couldn't be shown (no permission, or the platform failed).
  Future<bool> show(BudgetAlert alert);
}
