import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock/clock.dart';
import '../../core/clock/system_clock.dart';
import '../../core/ids/id_generator.dart';
import '../../core/ids/uuid_v7_generator.dart';

part 'core_providers.g.dart';

/// Override with a `FakeClock` in tests.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => UuidV7Generator(ref.watch(clockProvider));
