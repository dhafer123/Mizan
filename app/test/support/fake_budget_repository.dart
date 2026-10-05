import 'dart:async';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/repositories/budget_repository.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';

/// An in-memory [BudgetRepository] for use case and widget tests.
class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository([Iterable<Budget> budgets = const []])
    : _byId = {for (final b in budgets) b.id: b};

  final Map<String, Budget> _byId;
  final _changes = StreamController<void>.broadcast();

  /// When set, [watchAll] emits this instead.
  BudgetFailure? watchFailure;

  /// When set, every write fails with this.
  BudgetFailure? writeFailure;

  List<Budget> get budgets => _byId.values.toList();

  @override
  Stream<Result<List<Budget>, BudgetFailure>> watchAll() async* {
    yield _current();
    await for (final _ in _changes.stream) {
      yield _current();
    }
  }

  Result<List<Budget>, BudgetFailure> _current() => switch (watchFailure) {
    final failure? => Err(failure),
    null => Ok(_byId.values.toList()),
  };

  @override
  Future<Result<void, BudgetFailure>> save(Budget budget) async {
    if (writeFailure case final failure?) return Err(failure);
    _byId[budget.id] = budget;
    _changes.add(null);
    return const Ok(null);
  }
}
