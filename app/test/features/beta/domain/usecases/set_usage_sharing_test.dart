import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/beta/domain/entities/usage_sharing.dart';
import 'package:mizan/features/beta/domain/usecases/get_usage_sharing.dart';
import 'package:mizan/features/beta/domain/usecases/set_usage_sharing.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_error.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_usage_sharing_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  late FakeUsageSharingRepository repository;
  late SetUsageSharing set;
  late GetUsageSharing get;

  setUp(() {
    repository = FakeUsageSharingRepository();
    set = SetUsageSharing(
      repository,
      SequentialIdGenerator(prefix: 'install-'),
      FakeClock(DateTime.utc(2026, 10, 9, 15)),
    );
    get = GetUsageSharing(repository);
  });

  test('off by default', () async {
    expect(await get(), const Ok<bool, BetaFailure>(false));
  });

  test('turning it on makes an install id and starts from today', () async {
    await set(enabled: true);

    expect(
      repository.sharing,
      UsageSharing(installId: 'install-1', since: DateTime.utc(2026, 10, 9)),
    );
    expect(await get(), const Ok<bool, BetaFailure>(true));
  });

  test('turning it on again keeps the same id', () async {
    await set(enabled: true);
    await set(enabled: true);

    expect(repository.sharing!.installId, 'install-1');
  });

  test('turning it off forgets the id; on again is a new install', () async {
    await set(enabled: true);

    await set(enabled: false);
    expect(repository.sharing, isNull);

    await set(enabled: true);
    expect(repository.sharing!.installId, 'install-2');
  });

  test('storage failures are returned', () async {
    repository.loadFailure = const BetaFailure(BetaError.storage);

    expect(
      await set(enabled: true),
      const Err<void, BetaFailure>(BetaFailure(BetaError.storage)),
    );
    expect(
      await get(),
      const Err<bool, BetaFailure>(BetaFailure(BetaError.storage)),
    );
  });
}
