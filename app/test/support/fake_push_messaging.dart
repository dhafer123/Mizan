import 'dart:async';

import 'package:mizan/features/sync/domain/repositories/push_messaging.dart';
import 'package:mizan/features/sync/domain/value_objects/push_message.dart';

/// [PushMessaging] driven by the test. With [available] false it behaves
/// like a build without a Firebase config (the default in widget tests).
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.available = false});

  final bool available;
  final tokens = StreamController<String>.broadcast();
  final incoming = StreamController<PushMessage>.broadcast();
  final taps = StreamController<PushMessage>.broadcast();
  final shown = <PushMessage>[];

  @override
  Future<bool> start() async => available;

  @override
  Stream<String> watchToken() => tokens.stream;

  @override
  Stream<PushMessage> messages() => incoming.stream;

  @override
  Stream<PushMessage> opened() => taps.stream;

  @override
  Future<void> show(PushMessage message) async => shown.add(message);

  Future<void> close() async {
    await tokens.close();
    await incoming.close();
    await taps.close();
  }
}
