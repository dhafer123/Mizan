/// An in-memory server with the same sync rules as the Django one
/// (server/sync/push.py, pull.py), for the simulation harness.
///
/// One account. Personal entities as the app sends them, plus shared
/// expenses and settlements in one group (pushed by the harness directly,
/// since the app has no group tables yet) so money integrity can be checked
/// on the server. Keep it in step with push.py: the e2e job runs the same
/// scenarios against the real server.
library;

const userId = '1';
const _changedAt = '2026-10-06T09:00:00.000Z';

typedef Json = Map<String, Object?>;

class _Invalid implements Exception {
  const _Invalid(this.reason, [this.field]);
  final String reason;
  final String? field;
}

// --- Field checks (mirror sync/fields.py) ---

typedef _Check = Object? Function(Object? value);

Object? _posInt(Object? v) =>
    v is int && v > 0 ? v : throw const FormatException();
Object? _int0(Object? v) =>
    v is int && v >= 0 ? v : throw const FormatException();
Object? _text(Object? v) =>
    v is String && v.trim().isNotEmpty ? v : throw const FormatException();
Object? _bool(Object? v) => v is bool ? v : throw const FormatException();
Object? _currency(Object? v) =>
    const {'TND', 'EUR', 'USD'}.contains(v) ? v : throw const FormatException();
Object? _day(Object? v) => v is String && v.endsWith('T00:00:00.000Z')
    ? v
    : throw const FormatException();
_Check _choice(Set<String> values) =>
    (v) => values.contains(v) ? v : throw const FormatException();
Object? _month(Object? v) =>
    v is String && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(v)
    ? v
    : throw const FormatException();
Object? _dayOfMonth(Object? v) =>
    v is int && v >= 1 && v <= 31 ? v : throw const FormatException();
Object? _object(Object? v) => v is Map ? v : throw const FormatException();
Object? _shares(Object? v) {
  if (v is! Map || v.isEmpty) throw const FormatException();
  for (final amount in v.values) {
    _int0(amount);
  }
  return v;
}

class _Field {
  const _Field(this.check, {this.required = true, this.nullable = false});
  final _Check check;
  final bool required;
  final bool nullable;
}

class _Spec {
  const _Spec(
    this.fields, {
    this.check,
    this.deletable = true,
    this.insertOnly = false,
    this.builtIns = const {},
  });
  final Map<String, _Field> fields;
  final void Function(Json values, String id, FakeSyncServer server)? check;
  final bool deletable;
  final bool insertOnly;
  final Map<String, Json> builtIns;
}

const builtInCategories = {
  'food': 'Food',
  'transport': 'Transport',
  'rent': 'Rent',
  'study': 'Study',
  'leisure': 'Leisure',
  'other': 'Other',
};

final _specs = <String, _Spec>{
  'expenses': const _Spec({
    'amountMinor': _Field(_posInt),
    'currency': _Field(_currency),
    'categoryId': _Field(_text),
    'date': _Field(_day),
    'note': _Field(_text, required: false, nullable: true),
    'source': _Field(_sourceCheck),
  }),
  'categories': _Spec(
    const {
      'name': _Field(_text),
      'icon': _Field(_text),
      'monthlyLimitMinor': _Field(_posInt, required: false, nullable: true),
      'currency': _Field(_currency),
      'archived': _Field(_bool),
    },
    deletable: false,
    builtIns: {
      for (final MapEntry(key: id, value: name) in builtInCategories.entries)
        id: {
          'name': name,
          'icon': id,
          'monthlyLimitMinor': null,
          'currency': 'TND',
          'archived': false,
        },
    },
  ),
  'income_sources': const _Spec({
    'name': _Field(_text),
    'amountMinor': _Field(_posInt),
    'currency': _Field(_currency),
    'scheduleType': _Field(_scheduleCheck),
    'dayOfMonth': _Field(_dayOfMonth, required: false, nullable: true),
    'date': _Field(_day, required: false, nullable: true),
  }, check: _checkIncome),
  'budgets': const _Spec({
    'month': _Field(_month),
    'totalLimitMinor': _Field(_posInt, required: false, nullable: true),
    'currency': _Field(_currency),
  }, check: _checkBudget),
  'shared_expenses': const _Spec({
    'groupId': _Field(_text),
    'payerId': _Field(_text),
    'amountMinor': _Field(_posInt),
    'currency': _Field(_currency),
    'date': _Field(_day),
    'split': _Field(_object),
    'shares': _Field(_shares),
    'categoryId': _Field(_text, required: false, nullable: true),
  }, check: _checkSharedExpense),
  'settlements': const _Spec(
    {
      'groupId': _Field(_text),
      'fromMemberId': _Field(_text),
      'toMemberId': _Field(_text),
      'amountMinor': _Field(_posInt),
      'currency': _Field(_currency),
      'date': _Field(_day),
      'reversesId': _Field(_text, required: false, nullable: true),
    },
    check: _checkSettlement,
    insertOnly: true,
    deletable: false,
  ),
};

Object? _sourceCheck(Object? v) =>
    _choice(const {'manual', 'voice', 'receipt'})(v);
Object? _scheduleCheck(Object? v) =>
    _choice(const {'monthly', 'oneOff', 'irregular'})(v);

void _checkIncome(Json v, String id, FakeSyncServer s) {
  final day = v['dayOfMonth'], date = v['date'];
  final ok = switch (v['scheduleType']) {
    'monthly' => day != null && date == null,
    'oneOff' => day == null && date != null,
    _ => day == null && date == null,
  };
  if (!ok) throw const _Invalid('invalid_schedule', 'scheduleType');
}

void _checkBudget(Json v, String id, FakeSyncServer s) {
  if (id != 'budget-${v['month']}') {
    throw const _Invalid('month_mismatch', 'month');
  }
}

void _checkSharedExpense(Json v, String id, FakeSyncServer s) {
  if (v['currency'] != FakeSyncServer.groupCurrency) {
    throw const _Invalid('currency_mismatch', 'currency');
  }
  final shares = (v['shares']! as Map).cast<String, int>();
  if (!s.members.contains(v['payerId']) ||
      !shares.keys.every(s.members.contains)) {
    throw const _Invalid('unknown_member', 'shares');
  }
  if (shares.values.fold(0, (a, b) => a + b) != v['amountMinor']) {
    throw const _Invalid('shares_mismatch', 'shares');
  }
}

void _checkSettlement(Json v, String id, FakeSyncServer s) {
  final from = v['fromMemberId'], to = v['toMemberId'];
  if (!s.members.contains(from) || !s.members.contains(to)) {
    throw const _Invalid('unknown_member', 'fromMemberId');
  }
  if (from == to) throw const _Invalid('same_member', 'toMemberId');
  final reverses = v['reversesId'];
  if (reverses == null) return;
  final original = s.rows['settlements']?[reverses];
  if (original == null) {
    throw const _Invalid('unknown_settlement', 'reversesId');
  }
  if (original['fromMemberId'] != to ||
      original['toMemberId'] != from ||
      original['amountMinor'] != v['amountMinor']) {
    throw const _Invalid('not_a_mirror', 'reversesId');
  }
  final reversed = s.rows['settlements']!.values.any(
    (r) => r['reversesId'] == reverses,
  );
  if (reversed) throw const _Invalid('already_reversed', 'reversesId');
}

bool jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && jsonEquals(a[k], b[k]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

class _Rejected implements Exception {
  const _Rejected(this.reason, {this.field, this.state});
  final String reason;
  final String? field;
  final Json? state;
}

class FakeSyncServer {
  FakeSyncServer({this.pageSize = 200});

  /// Max changes per pull page, whatever the client asks for (pages small
  /// enough to make the client follow `hasMore`).
  final int pageSize;

  static const groupId = 'g1';
  static const groupCurrency = 'TND';
  final members = {'m1', 'm2', 'm3'};

  var seq = 0;

  /// entity → id → state (fields + version, deleted, updatedBy, serverSeq).
  final rows = <String, Map<String, Json>>{};
  final history = <Json>[];

  /// The applied-op log: opId → the result first returned.
  final applied = <String, Json>{};

  // --- /sync/push ---

  Json push(Json body) {
    final deviceId = body['deviceId']! as String;
    final ops = (body['ops']! as List).cast<Json>();
    return {
      'results': [for (final op in ops) _process(deviceId, op)],
    };
  }

  Json _process(String device, Json op) {
    final opId = op['opId']! as String;
    if (applied[opId] case final stored?) return stored;
    Json result;
    try {
      final (status, state) = _apply(device, op);
      result = _result(op, status, state: state);
    } on _Rejected catch (e) {
      result = _result(
        op,
        'rejected',
        reason: e.reason,
        field: e.field,
        state: e.state,
      );
    }
    applied[opId] = result;
    return result;
  }

  Json _result(
    Json op,
    String status, {
    String? reason,
    String? field,
    Json? state,
  }) => {
    'opId': op['opId'],
    'entity': op['entity'],
    'entityId': op['entityId'],
    'status': status,
    'state': state,
    'reason': ?reason,
    'field': ?field,
  };

  (String, Json?) _apply(String device, Json op) {
    final entity = op['entity']! as String;
    final id = op['entityId']! as String;
    final type = op['opType']! as String;
    final base = op['baseVersion']! as int;
    final spec = _specs[entity];
    if (spec == null) throw const _Rejected('unknown_entity');
    final table = rows.putIfAbsent(entity, () => {});
    final row = table[id];

    final incoming = <String, Object?>{};
    if (type != 'delete') {
      for (final MapEntry(:key, :value)
          in (op['changedFields']! as Map).cast<String, Object?>().entries) {
        if (key == 'id') {
          if (value != id) throw const _Rejected('invalid_field', field: 'id');
          continue;
        }
        final f = spec.fields[key];
        if (f == null) throw _Rejected('unknown_field', field: key);
        if (value == null) {
          if (!f.nullable) throw _Rejected('invalid_field', field: key);
        } else {
          try {
            f.check(value);
          } on FormatException {
            throw _Rejected('invalid_field', field: key);
          }
        }
        incoming[key] = value;
      }
    }

    final ctx = (device: device, entity: entity, id: id, op: op);
    if (type == 'delete') return _delete(ctx, spec, row, base);
    if (spec.insertOnly) {
      if (type == 'update') {
        throw _Rejected('insert_only', state: row == null ? null : _state(row));
      }
      if (row != null) {
        final values = _requireAll(spec, {...incoming});
        final same = spec.fields.keys.every(
          (k) => jsonEquals(row[k], values[k]),
        );
        if (same) return ('applied', _state(row));
        throw _Rejected('already_exists', state: _state(row));
      }
    }
    if (type == 'create' && row == null) {
      final values = _requireAll(spec, {...incoming});
      _check(spec, values, id);
      final created = {...values, 'id': id, 'deleted': false};
      _write(ctx, table, created, version: 1);
      _history(ctx, created, 'created');
      return ('applied', _state(created));
    }
    if (type == 'create' && row!['deleted'] == true) {
      final values = {..._values(spec, row), ...incoming};
      _check(spec, values, id);
      final restored = {...row, ...values, 'deleted': false};
      _write(ctx, table, restored, version: (row['version']! as int) + 1);
      _history(ctx, restored, 'restored');
      return ('applied', _state(restored));
    }
    return _update(ctx, spec, table, row, base, incoming);
  }

  (String, Json?) _update(
    _Ctx ctx,
    _Spec spec,
    Map<String, Json> table,
    Json? row,
    int base,
    Json incoming,
  ) {
    final Json current;
    final int version;
    if (row == null) {
      final builtIn = spec.builtIns[ctx.id];
      if (builtIn == null) throw const _Rejected('not_found');
      (current, version) = (builtIn, 0);
    } else {
      (current, version) = (_values(spec, row), row['version']! as int);
    }

    if (row != null && row['deleted'] == true) {
      for (final MapEntry(:key, :value) in incoming.entries) {
        _history(
          ctx,
          row,
          'discarded',
          field: key,
          oldValue: current[key],
          newValue: value,
        );
      }
      throw _Rejected('deleted', state: _state(row));
    }
    if (base > version) {
      throw _Rejected(
        'bad_base_version',
        state: row == null ? null : _state(row),
      );
    }

    final (concurrent, others) = base < version
        ? _concurrent(ctx, spec, base)
        : (<String>{}, false);
    final changes = {
      for (final MapEntry(:key, :value) in incoming.entries)
        if (!jsonEquals(current[key], value)) key: value,
    };
    final values = {...current, ...incoming};
    _check(spec, values, ctx.id);
    final status = others ? 'merged' : 'applied';
    if (changes.isEmpty) return (status, row == null ? null : _state(row));

    final updated = {...?row, ...values, 'id': ctx.id, 'deleted': false};
    _write(ctx, table, updated, version: version + 1);
    for (final MapEntry(:key, :value) in changes.entries) {
      _history(
        ctx,
        updated,
        concurrent.contains(key) ? 'overwritten' : 'changed',
        field: key,
        oldValue: current[key],
        newValue: value,
      );
    }
    return (status, _state(updated));
  }

  (String, Json?) _delete(_Ctx ctx, _Spec spec, Json? row, int base) {
    if (spec.insertOnly) {
      throw _Rejected('insert_only', state: row == null ? null : _state(row));
    }
    if (!spec.deletable) {
      throw _Rejected('not_deletable', state: row == null ? null : _state(row));
    }
    if (row == null) throw const _Rejected('not_found');
    final version = row['version']! as int;
    if (base > version) {
      throw _Rejected('bad_base_version', state: _state(row));
    }
    if (row['deleted'] == true) return ('applied', _state(row));
    final (_, others) = base < version
        ? _concurrent(ctx, spec, base)
        : (<String>{}, false);
    final deleted = {...row, 'deleted': true};
    _write(ctx, rows[ctx.entity]!, deleted, version: version + 1);
    _history(ctx, deleted, 'deleted');
    return (others ? 'merged' : 'applied', _state(deleted));
  }

  (Set<String>, bool) _concurrent(_Ctx ctx, _Spec spec, int base) {
    final mine = history.where(
      (h) =>
          h['entity'] == ctx.entity &&
          h['entityId'] == ctx.id &&
          (h['_version']! as int) > base &&
          h['_device'] != ctx.device,
    );
    final fields = <String>{};
    var any = false;
    for (final h in mine) {
      any = true;
      switch (h['kind']) {
        case 'changed' || 'overwritten':
          fields.add(h['field']! as String);
        case 'created' || 'restored':
          fields.addAll(spec.fields.keys);
      }
    }
    return (fields, any);
  }

  Json _requireAll(_Spec spec, Json values) {
    for (final MapEntry(:key, value: f) in spec.fields.entries) {
      if (!values.containsKey(key)) {
        if (f.required) throw _Rejected('missing_field', field: key);
        values[key] = null;
      }
    }
    return values;
  }

  void _check(_Spec spec, Json values, String id) {
    try {
      spec.check?.call(values, id, this);
    } on _Invalid catch (e) {
      throw _Rejected(e.reason, field: e.field);
    }
  }

  Json _values(_Spec spec, Json row) => {
    for (final k in spec.fields.keys) k: row[k],
  };

  void _write(
    _Ctx ctx,
    Map<String, Json> table,
    Json row, {
    required int version,
  }) {
    row
      ..['version'] = version
      ..['updatedBy'] = userId
      ..['serverSeq'] = ++seq;
    table[ctx.id] = row;
  }

  void _history(
    _Ctx ctx,
    Json row,
    String kind, {
    String field = '',
    Object? oldValue,
    Object? newValue,
  }) {
    final s = ++seq;
    history.add({
      'id': '$s',
      'entity': ctx.entity,
      'entityId': ctx.id,
      'kind': kind,
      'field': field,
      'oldValue': oldValue,
      'newValue': newValue,
      'changedBy': userId,
      'serverSeq': s,
      'changedAt': _changedAt,
      '_version': row['version'],
      '_device': ctx.device,
    });
  }

  Json _state(Json row) => {...row};

  // --- /sync/pull ---

  Json pull(int since, int limit) {
    final changes =
        <Json>[
          for (final MapEntry(key: entity, value: table) in rows.entries)
            for (final row in table.values)
              if ((row['serverSeq']! as int) > since)
                {
                  'entity': entity,
                  'serverSeq': row['serverSeq'],
                  'state': {...row},
                },
          for (final h in history)
            if ((h['serverSeq']! as int) > since)
              {
                'entity': 'entity_history',
                'serverSeq': h['serverSeq'],
                'state': {
                  for (final MapEntry(:key, :value) in h.entries)
                    if (!key.startsWith('_')) key: value,
                },
              },
        ]..sort(
          (a, b) => (a['serverSeq']! as int).compareTo(b['serverSeq']! as int),
        );
    final size = limit < pageSize ? limit : pageSize;
    final page = changes.take(size).toList();
    return {
      'changes': page,
      'cursor': page.isEmpty ? since : page.last['serverSeq'],
      'hasMore': changes.length > size,
    };
  }
}

typedef _Ctx = ({String device, String entity, String id, Json op});
