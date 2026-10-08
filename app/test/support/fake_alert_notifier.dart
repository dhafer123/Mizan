import 'package:mizan/features/budget/domain/repositories/alert_notifier.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';

/// [AlertNotifier] that records what it shows. With [enabled] false it
/// behaves like notifications turned off.
class FakeAlertNotifier implements AlertNotifier {
  bool enabled = true;
  final shown = <BudgetAlert>[];
  var permissionRequests = 0;

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<bool> show(BudgetAlert alert) async {
    // A real notification takes a moment; lets checks overlap in tests.
    await Future<void>.delayed(Duration.zero);
    if (!enabled) return false;
    shown.add(alert);
    return true;
  }
}
