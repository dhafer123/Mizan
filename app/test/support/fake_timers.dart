import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Timers that only fire when the test calls [elapse]: pass [start] as a
/// `StartTimer`. Keeps scheduler tests instant and exact.
class FakeTimers {
  var _now = Duration.zero;
  final _timers = <_FakeTimer>[];

  Duration get now => _now;

  /// Timers waiting to fire, soonest first.
  List<Duration> get pending =>
      [for (final t in _timers.where((t) => t.isActive)) t.due - _now]..sort();

  Timer start(Duration delay, void Function() callback) {
    final timer = _FakeTimer(_now + delay, callback);
    _timers.add(timer);
    return timer;
  }

  /// Moves time forward by [by], firing due timers in order and letting
  /// the async work they start run between them.
  Future<void> elapse(Duration by) async {
    final target = _now + by;
    while (true) {
      final due = _timers.where((t) => t.isActive && t.due <= target).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.due;
      next.fire();
      await pumpEventQueue();
    }
    _now = target;
    await pumpEventQueue();
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.due, this._callback);

  final Duration due;
  final void Function() _callback;
  var _active = true;

  void fire() {
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
