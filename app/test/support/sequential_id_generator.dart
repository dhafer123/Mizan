import 'package:mizan/core/ids/id_generator.dart';

/// Predictable ids for tests: `op-1`, `op-2`, … or the given ones in order.
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'op-', List<String>? ids})
    : _queued = [...?ids];

  final String prefix;
  final List<String> _queued;
  var _next = 1;

  @override
  String newId() =>
      _queued.isNotEmpty ? _queued.removeAt(0) : '$prefix${_next++}';
}
