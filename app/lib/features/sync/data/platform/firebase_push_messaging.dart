import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/repositories/push_messaging.dart';
import '../../domain/value_objects/push_message.dart';

/// [PushMessaging] with FCM (firebase_messaging), and flutter_local_notifications
/// for notifications that arrive while the app is open (Android doesn't show
/// those itself).
///
/// Push needs a Firebase config (`android/app/google-services.json`). A build
/// without one runs with push off: [start] returns false.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._notifications);

  final FlutterLocalNotificationsPlugin _notifications;

  /// Taps on a notification, whether FCM or this class showed it.
  final _tapped = StreamController<PushMessage>.broadcast();
  var _nextId = 0;

  /// The server sends group notifications in this channel
  /// (server/notifications/delivery.py), so it must exist before any arrive.
  static const _channel = AndroidNotificationChannel(
    'groups',
    'Groups',
    description: 'New shared expenses, new members and settle-up reminders.',
    importance: Importance.high,
  );

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> start() async {
    try {
      await Firebase.initializeApp();
    } on Object {
      return false; // No Firebase config in this build.
    }
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _tapped.add(PushMessage(groupId: response.payload)),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _tapped.add(_toMessage(m)),
    );
    // Android 13+ and iOS ask the user; refusing only hides notifications,
    // data pushes (sync) still arrive.
    await _messaging.requestPermission();
    return true;
  }

  @override
  Stream<String> watchToken() async* {
    final token = await _messaging.getToken();
    if (token != null) yield token;
    yield* _messaging.onTokenRefresh;
  }

  @override
  Stream<PushMessage> messages() => FirebaseMessaging.onMessage.map(_toMessage);

  @override
  Stream<PushMessage> opened() async* {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) yield _toMessage(initial);
    yield* _tapped.stream;
  }

  @override
  Future<void> show(PushMessage message) => _notifications.show(
    id: _nextId++,
    title: message.title,
    body: message.body,
    payload: message.groupId,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );

  static PushMessage _toMessage(RemoteMessage m) => PushMessage(
    groupId: m.data['groupId'] as String?,
    title: m.notification?.title,
    body: m.notification?.body,
  );
}
