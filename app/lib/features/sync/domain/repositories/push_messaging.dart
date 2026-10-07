import '../value_objects/push_message.dart';

/// Push messages on this phone (FCM, ADR 0011). A push is only a hint to
/// sync sooner: the app syncs on its own triggers without it.
abstract interface class PushMessaging {
  /// Sets push up and asks for permission to show notifications. False
  /// when this build has no push (no Firebase config, or the platform has
  /// none); the other members must not be used then.
  Future<bool> start();

  /// This install's push token, then every new one.
  Stream<String> watchToken();

  /// Pushes that arrive while the app is open.
  Stream<PushMessage> messages();

  /// Notifications the user tapped, including one that opened the app.
  Stream<PushMessage> opened();

  /// Shows [message]'s notification. Only needed while the app is open:
  /// otherwise the system shows it.
  Future<void> show(PushMessage message);
}
