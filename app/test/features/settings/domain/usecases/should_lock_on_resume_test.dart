import 'package:glados/glados.dart';
import 'package:mizan/features/settings/domain/usecases/should_lock_on_resume.dart';

const _shouldLock = ShouldLockOnResume();
final _away = DateTime.utc(2026, 10, 6, 9);

bool _after(Duration away, {bool enabled = true}) => _shouldLock(
  lockEnabled: enabled,
  backgroundedAt: _away,
  now: _away.add(away),
);

void main() {
  test('locks after a minute or more away', () {
    expect(_after(const Duration(seconds: 59)), isFalse);
    expect(_after(const Duration(minutes: 1)), isTrue);
    expect(_after(const Duration(hours: 3)), isTrue);
  });

  test('never with the lock off', () {
    expect(_after(const Duration(hours: 3), enabled: false), isFalse);
  });

  test('not without having been away', () {
    expect(
      _shouldLock(lockEnabled: true, backgroundedAt: null, now: _away),
      isFalse,
    );
  });

  test('locks if the clock went backwards', () {
    expect(_after(const Duration(seconds: -5)), isTrue);
  });

  Glados(any.intInRange(0, 7200)).test(
    'locks exactly when away for 60 seconds or more',
    (seconds) {
      expect(_after(Duration(seconds: seconds)), seconds >= 60);
    },
  );
}
