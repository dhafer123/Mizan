import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../app/notifications/local_notifications.dart';
import '../../domain/repositories/alert_notifier.dart';
import '../../domain/value_objects/budget_alert.dart';
import 'alert_messages.dart';

/// [AlertNotifier] with local notifications, in their own Android channel
/// so users can turn budget alerts off apart from group notifications.
/// Works from the background isolate too.
class LocalAlertNotifier implements AlertNotifier {
  LocalAlertNotifier(this._notifications);

  final LocalNotifications _notifications;

  static const _channel = AndroidNotificationChannel(
    'budget_alerts',
    'Budget alerts',
    description: 'Category limits, run-out warnings and unusual spending.',
    importance: Importance.high,
  );

  /// Tapping opens the app; push ignores taps with this payload.
  static const payload = 'local:alert';

  /// One notification per alert type: a newer one replaces the last.
  static const _firstId = 1 << 30;

  @override
  Future<void> requestPermission() async {
    try {
      if (await _notifications.start()) {
        await _notifications.requestPermission();
      }
    } on Object {
      // Nothing to do: alerts just won't show.
    }
  }

  @override
  Future<bool> show(BudgetAlert alert) async {
    try {
      if (!await _notifications.start()) return false;
      await _notifications.createChannel(_channel);
      if (!await _notifications.enabled()) return false;
      final (title, body) = AlertMessages.of(alert);
      await _notifications.show(
        id: _firstId + alert.type.index,
        channel: _channel,
        title: title,
        body: body,
        payload: payload,
      );
      return true;
    } on Object {
      return false;
    }
  }
}
