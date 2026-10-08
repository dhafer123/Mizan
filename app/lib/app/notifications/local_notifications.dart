import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The app's one flutter_local_notifications setup, shared by push (group
/// notifications) and budget alerts. The plugin is a singleton, and a
/// second `initialize` replaces the first one's tap handler, so it is
/// initialized here once and taps are handed out by payload.
class LocalNotifications {
  LocalNotifications(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String?>.broadcast();
  Future<bool>? _started;

  /// Initializes the plugin once (per isolate). False if the platform
  /// refused.
  Future<bool> start() => _started ??= _initialize();

  Future<bool> _initialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _taps.add(response.payload),
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// The payload of each notification the user taps while the app runs.
  Stream<String?> get taps => _taps.stream;

  Future<void> createChannel(AndroidNotificationChannel channel) async =>
      _android?.createNotificationChannel(channel);

  /// Asks for permission where the platform needs it (Android 13+). Asking
  /// again after a refusal shows nothing.
  Future<void> requestPermission() async {
    await _android?.requestNotificationsPermission();
  }

  /// Whether notifications would be shown. True where it can't be told.
  Future<bool> enabled() async =>
      await _android?.areNotificationsEnabled() ?? true;

  Future<void> show({
    required int id,
    required AndroidNotificationChannel channel,
    String? title,
    String? body,
    String? payload,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    payload: payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
      ),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
}
