import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock/clock.dart';
import '../../core/clock/system_clock.dart';
import '../../core/ids/id_generator.dart';
import '../../core/ids/uuid_v7_generator.dart';
import '../../core/money/currency.dart';
import '../notifications/local_notifications.dart';

part 'core_providers.g.dart';

/// Override with a `FakeClock` in tests.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => UuidV7Generator(ref.watch(clockProvider));

/// The currency personal amounts are entered in. A setting later; one
/// currency per user in v1.
@Riverpod(keepAlive: true)
Currency appCurrency(Ref ref) => Currency.tnd;

/// Local notifications, shared by push and budget alerts.
@Riverpod(keepAlive: true)
LocalNotifications localNotifications(Ref ref) =>
    LocalNotifications(FlutterLocalNotificationsPlugin());
