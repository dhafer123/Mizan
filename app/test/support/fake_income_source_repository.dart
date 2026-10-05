import 'dart:async';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/repositories/income_source_repository.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';

/// An in-memory [IncomeSourceRepository] for use case and widget tests.
class FakeIncomeSourceRepository implements IncomeSourceRepository {
  FakeIncomeSourceRepository([Iterable<IncomeSource> sources = const []])
    : _live = {for (final s in sources) s.id: s};

  final Map<String, IncomeSource> _live;
  final _changes = StreamController<void>.broadcast();

  /// When set, [watchAll] emits this instead.
  BudgetFailure? watchFailure;

  /// When set, every write fails with this.
  BudgetFailure? writeFailure;

  List<IncomeSource> get live => _live.values.toList();

  @override
  Stream<Result<List<IncomeSource>, BudgetFailure>> watchAll() async* {
    yield _current();
    await for (final _ in _changes.stream) {
      yield _current();
    }
  }

  Result<List<IncomeSource>, BudgetFailure> _current() =>
      switch (watchFailure) {
        final failure? => Err(failure),
        null => Ok(_live.values.toList()),
      };

  @override
  Future<Result<void, BudgetFailure>> add(IncomeSource source) async {
    if (writeFailure case final failure?) return Err(failure);
    _live[source.id] = source;
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void, BudgetFailure>> update(IncomeSource source) async {
    if (writeFailure case final failure?) return Err(failure);
    if (!_live.containsKey(source.id)) return _notFound;
    _live[source.id] = source;
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void, BudgetFailure>> delete(String id) async {
    if (writeFailure case final failure?) return Err(failure);
    if (_live.remove(id) == null) return _notFound;
    _changes.add(null);
    return const Ok(null);
  }

  static const _notFound = Err<void, BudgetFailure>(
    BudgetFailure(BudgetError.notFound),
  );
}
