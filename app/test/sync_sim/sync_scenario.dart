import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DataClass;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/failure.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/groups/domain/entities/settlement.dart';
import 'package:mizan/features/groups/domain/entities/shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/compute_balances.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';
import 'package:mizan/features/sync/data/db/outbox_status.dart';
import 'package:mizan/features/sync/data/db/sync_payload.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';

import 'fake_sync_server.dart';
import 'sim_device.dart';
import 'sim_network.dart';

const _account = 'sim-account';

/// What the scenarios exercised, summed over a run (printed at the end), so
/// a green run can't hide a harness that never hits the hard paths.
abstract final class SimStats {
  static var scenarios = 0;
  static var ops = 0;
  static var lostResponses = 0;
  static final statuses = <String, int>{};
  static final historyKinds = <String, int>{};

  static String summary() =>
      '$scenarios scenarios, $ops ops, $lostResponses lost push responses\n'
      '  results: $statuses\n'
      '  history: $historyKinds';
}

const _personal = {'expenses', 'categories', 'income_sources', 'budgets'};

/// One random scenario: 2–3 phones of one account make random edits, push
/// and pull in random order, go offline at random and lose push responses;
/// then everyone syncs until quiet, and the four invariants of §6 are
/// checked:
///
/// 1. Convergence: every phone holds the same rows and history, equal to
///    the server's.
/// 2. No lost writes: every op the phones ever queued is applied, merged, or
///    rejected with a reason (and a rejected edit of a deleted row is kept in
///    history as `discarded`).
/// 3. Money integrity: on every phone after every step, money values are
///    whole minor units in TND, positive where required; after sync, each
///    phone's total equals the server's. On the fake server, group balances
///    (shared expenses and settlements, pushed by a group actor) sum to 0
///    after every step.
/// 4. Idempotency: pushing every op again changes nothing on the server and
///    returns the same results.
///
/// The checks only use what a client can see (pull, push results), so the
/// same scenario runs against the fake server or the real one.
class SyncScenario {
  SyncScenario(
    this.seed, {
    required this.backend,
    this.baseUrl = 'http://sim',
    this.headers = const {},
    this.fake,
  }) : random = Random(seed);

  final int seed;
  final SimBackend backend;
  final String baseUrl;
  final Map<String, String> headers;

  /// Set when running against the in-memory server (enables the group actor).
  final FakeSyncServer? fake;

  final Random random;
  final log = <String>[];
  late final List<SimDevice> devices;

  Future<void> run() async {
    final count = 2 + random.nextInt(2);
    devices = [
      for (var i = 0; i < count; i++)
        SimDevice(
          'd$i',
          backend,
          Random(random.nextInt(1 << 32)),
          baseUrl: baseUrl,
          headers: headers,
        ),
    ];
    try {
      for (final d in devices) {
        expect((await d.sync.claimFor(_account)).isOk, isTrue);
      }
      final steps = 15 + random.nextInt(46);
      for (var step = 0; step < steps; step++) {
        await _step();
      }
      await _quiesce();
      await _checkConvergence();
      await _checkNoLostWritesAndIdempotency();
      SimStats.scenarios++;
    } on TestFailure catch (e) {
      fail(
        '${e.message}\n\nReproduce: SYNC_SIM_SEED=$seed SYNC_SIM_SCENARIOS=1\n'
        'Last steps:\n  ${log.skip(max(0, log.length - 40)).join('\n  ')}\n'
        '${await _dump()}',
      );
    } finally {
      for (final d in devices) {
        await d.close();
      }
    }
  }

  /// Outboxes and (fake) server history, to see what happened.
  Future<String> _dump() async {
    final out = StringBuffer('Outboxes:\n');
    for (final d in devices) {
      for (final o in d.queued.values) {
        final now = await (d.db.select(
          d.db.outbox,
        )..where((x) => x.opId.equals(o.opId))).getSingleOrNull();
        final fate = now == null
            ? 'acked'
            : '${now.status.name} ${now.rejectReason ?? ''}';
        out.writeln(
          '  ${d.name} #${o.seq} ${o.opType.name} ${o.entity}/${o.entityId} '
          'base ${o.baseVersion} ${o.changedFields} -> $fate',
        );
      }
    }
    if (fake case final server?) {
      out.writeln('Server history:');
      for (final h in server.history) {
        out.writeln(
          '  #${h['serverSeq']} ${h['entity']}/${h['entityId']} ${h['kind']} '
          '${h['field']} ${h['oldValue']} -> ${h['newValue']} '
          'v${h['_version']} by ${h['_device']}',
        );
      }
    }
    return out.toString();
  }

  Future<void> _step() async {
    final d = devices[random.nextInt(devices.length)];
    final roll = random.nextInt(100);
    String what;
    if (roll < 45) {
      what = await d.randomEdit();
      await d.rememberOutbox();
    } else if (roll < 58) {
      await d.rememberOutbox();
      what = 'push ${_short(await d.sync.push())}';
    } else if (roll < 71) {
      what = 'pull ${_short(await d.sync.pull(accountId: _account))}';
    } else if (roll < 82) {
      await d.rememberOutbox();
      final pushed = await d.sync.push();
      final pulled = await d.sync.pull(accountId: _account);
      what = 'sync ${_short(pushed)} ${_short(pulled)}';
    } else if (roll < 93) {
      d.link.online = !d.link.online;
      what = d.link.online ? 'online' : 'OFFLINE';
    } else if (fake != null) {
      what = 'group ${_groupOp(fake!)}';
    } else {
      what = 'idle';
    }
    log.add('${d.name}: $what');
    await _checkMoney(d);
    if (fake != null) _checkGroupBalances(fake!);
  }

  static String _short(Result<Object?, Failure> r) =>
      r.isOk ? 'ok' : '${r.failureOrNull}';

  /// Everyone online, no lost responses, push and pull until no op waits.
  Future<void> _quiesce() async {
    for (final d in devices) {
      d.link
        ..online = true
        ..loseResponses = 0;
    }
    for (var round = 0; ; round++) {
      expect(round, lessThan(10), reason: 'sync never settled');
      for (final d in devices) {
        await d.rememberOutbox();
        expect((await d.sync.push()).isOk, isTrue, reason: '${d.name} push');
      }
      for (final d in devices) {
        final pulled = await d.sync.pull(accountId: _account);
        expect(pulled.isOk, isTrue, reason: '${d.name} pull: $pulled');
      }
      var waiting = 0;
      for (final d in devices) {
        waiting += (await d.db.outboxDao.pending()).length;
      }
      if (waiting == 0) break;
    }
    log.add('-- quiet --');
  }

  // --- 1. Convergence ---

  Future<Map<String, List<String>>> _deviceState(SimDevice d) async {
    String canon(DataClass row) =>
        _canonical(row.toJson(serializer: syncSerializer));
    return {
      'expenses': [
        for (final r in await d.db.select(d.db.expenses).get()) canon(r),
      ]..sort(),
      'categories': [
        for (final r in await d.db.select(d.db.categories).get()) canon(r),
      ]..sort(),
      'income_sources': [
        for (final r in await d.db.select(d.db.incomeSources).get()) canon(r),
      ]..sort(),
      'budgets': [
        for (final r in await d.db.select(d.db.budgets).get()) canon(r),
      ]..sort(),
      'entity_history': [
        for (final r in await d.db.select(d.db.entityHistory).get()) canon(r),
      ]..sort(),
    };
  }

  /// Everything the server has for this account, via pull from 0.
  Future<List<Map<String, Object?>>> _serverChanges() async {
    final api = _verifierApi();
    final changes = <Map<String, Object?>>[];
    var since = 0;
    while (true) {
      final page = await api.pull(since: since, limit: 500);
      changes.addAll([
        for (final c in page.changes)
          {'entity': c.entity, 'serverSeq': c.serverSeq, 'state': c.state},
      ]);
      since = page.cursor;
      if (!page.hasMore) return changes;
    }
  }

  SyncApi _verifierApi() => SyncApi(
    Dio(BaseOptions(baseUrl: baseUrl, headers: headers))
      ..httpClientAdapter = SimLink(backend, Random(0), loseResponses: 0),
  );

  Future<void> _checkConvergence() async {
    final first = await _deviceState(devices.first);
    for (final d in devices.skip(1)) {
      final state = await _deviceState(d);
      for (final table in first.keys) {
        expect(
          state[table],
          first[table],
          reason: 'convergence: ${d.name}.$table differs from d0.$table',
        );
      }
    }

    final server = await _serverChanges();
    for (final table in _personal) {
      final serverRows = [
        for (final c in server)
          if (c['entity'] == table)
            _canonical(c['state']! as Map<String, Object?>),
      ]..sort();
      expect(first[table], serverRows, reason: 'convergence: $table vs server');
    }
    final serverHistory = server
        .where((c) => c['entity'] == 'entity_history')
        .length;
    expect(
      first['entity_history']!.length,
      serverHistory,
      reason: 'history vs server',
    );

    // Money integrity after sync: the same total on every phone and server.
    int total(Iterable<Map<String, Object?>> rows) => rows
        .where((r) => r['deleted'] == false)
        .fold(0, (sum, r) => sum + (r['amountMinor']! as int));
    final serverTotal = total([
      for (final c in server)
        if (c['entity'] == 'expenses') c['state']! as Map<String, Object?>,
    ]);
    for (final d in devices) {
      final rows = await d.db.select(d.db.expenses).get();
      expect(
        total([for (final r in rows) r.toJson(serializer: syncSerializer)]),
        serverTotal,
        reason: 'money: ${d.name} total vs server',
      );
    }
  }

  // --- 2. No lost writes, and 4. idempotency ---

  Future<void> _checkNoLostWritesAndIdempotency() async {
    for (final d in devices) {
      final stuck = (await d.db.select(d.db.outbox).get()).where(
        (o) => o.status != OutboxStatus.rejected,
      );
      expect(
        stuck,
        isEmpty,
        reason: 'lost write: ${d.name} still has ops waiting',
      );
    }

    final before = await _serverChanges();
    final first = await _replayEverything();
    final afterFirst = await _serverChanges();
    final second = await _replayEverything();
    final afterSecond = await _serverChanges();

    expect(
      _canonicalList(afterFirst),
      _canonicalList(before),
      reason:
          'idempotency: re-pushing ops changed the server '
          '(or an op had never reached it)',
    );
    expect(
      _canonicalList(afterSecond),
      _canonicalList(before),
      reason: 'idempotency',
    );
    String outcome(_Replay r) => _canonical({
      'status': r.result.status,
      'reason': r.result.reason,
      'state': r.result.state,
    });
    expect(
      {
        for (final MapEntry(:key, :value) in second.entries)
          key: outcome(value),
      },
      {for (final MapEntry(:key, :value) in first.entries) key: outcome(value)},
      reason: 'idempotency: different results the second time',
    );

    final history = [
      for (final c in before)
        if (c['entity'] == 'entity_history')
          c['state']! as Map<String, Object?>,
    ];
    bool inHistory(String entityId, Set<String> kinds) => history.any(
      (h) => h['entityId'] == entityId && kinds.contains(h['kind']),
    );

    SimStats.ops += second.length;
    for (final d in devices) {
      SimStats.lostResponses += d.link.lost;
    }
    for (final h in history) {
      final kind = h['kind']! as String;
      SimStats.historyKinds[kind] = (SimStats.historyKinds[kind] ?? 0) + 1;
    }
    for (final MapEntry(key: opId, value: replay) in second.entries) {
      final (:device, :op, :result) = replay;
      final status = result.status;
      final key = result.reason == null ? status : '$status:${result.reason}';
      SimStats.statuses[key] = (SimStats.statuses[key] ?? 0) + 1;
      expect(
        ['applied', 'merged', 'rejected'],
        contains(status),
        reason: 'op $opId: $status',
      );
      if (status == 'rejected') {
        expect(
          result.reason,
          isNotEmpty,
          reason: 'rejected op $opId has no reason',
        );
        if (result.reason == 'deleted') {
          expect(
            inHistory(op.entityId, {'discarded'}),
            isTrue,
            reason: 'lost write: edit of deleted ${op.entityId} not in history',
          );
        }
        // The phone shows the same refusal.
        final local = await (device.db.select(
          device.db.outbox,
        )..where((o) => o.opId.equals(opId))).getSingleOrNull();
        expect(
          local?.rejectReason,
          result.reason,
          reason: 'op $opId rejected locally',
        );
      } else if (op.opType.name == 'create' && op.entity == 'expenses') {
        expect(
          inHistory(op.entityId, {'created', 'restored'}),
          isTrue,
          reason: 'lost write: create of ${op.entityId} not in history',
        );
      }
    }
  }

  /// Pushes every op every phone ever queued again, as that phone.
  Future<Map<String, _Replay>> _replayEverything() async {
    final api = _verifierApi();
    final replays = <String, _Replay>{};
    for (final d in devices) {
      final ops = d.queued.values.toList()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      for (var i = 0; i < ops.length; i += SyncApi.maxOps) {
        final batch = ops.sublist(i, min(i + SyncApi.maxOps, ops.length));
        final pushed = await api.push(d.deviceId, batch);
        for (final (j, result) in pushed.indexed) {
          replays[batch[j].opId] = (device: d, op: batch[j], result: result);
        }
      }
    }
    return replays;
  }

  // --- 3. Money integrity at every step ---

  Future<void> _checkMoney(SimDevice d) async {
    for (final e in await d.db.select(d.db.expenses).get()) {
      expect(e.amountMinor, greaterThan(0), reason: 'money: ${d.name} ${e.id}');
      expect(e.currency, Currency.tnd.code, reason: 'money: ${d.name} ${e.id}');
    }
    for (final c in await d.db.select(d.db.categories).get()) {
      expect(
        c.monthlyLimitMinor == null || c.monthlyLimitMinor! > 0,
        isTrue,
        reason: 'money: category ${c.id} limit',
      );
    }
    for (final b in await d.db.select(d.db.budgets).get()) {
      expect(
        b.totalLimitMinor == null || b.totalLimitMinor! > 0,
        isTrue,
        reason: 'money: budget ${b.id} limit',
      );
    }
  }

  // --- Group actor (fake server only) ---

  var _groupOps = 0;

  String _groupOp(FakeSyncServer server) {
    final id = 'grp-${seed.toRadixString(36)}-${_groupOps++}';
    final members = server.members.toList()..sort();
    final live = [
      for (final MapEntry(key: k, value: v)
          in (server.rows['shared_expenses'] ?? {}).entries)
        if (v['deleted'] == false) (k, v),
    ];
    final settlements = (server.rows['settlements'] ?? {}).entries.toList();
    Map<String, Object?> push(Map<String, Object?> op) =>
        (server.push({
                      'deviceId': 'group-actor',
                      'ops': [op],
                    })['results']!
                    as List)
                .single
            as Map<String, Object?>;
    Map<String, int> split(int amount, List<String> who) => {
      for (final (i, m) in who.indexed)
        m: amount ~/ who.length + (i == 0 ? amount % who.length : 0),
    };
    Map<String, Object?> op(
      String entity,
      String entityId,
      String type,
      int base,
      Map<String, Object?> fields,
    ) => {
      'opId': '$id-op',
      'entity': entity,
      'entityId': entityId,
      'opType': type,
      'baseVersion': base,
      'changedFields': fields,
    };

    final roll = random.nextInt(6);
    Map<String, Object?> result;
    if (roll == 0 || live.isEmpty) {
      final amount = 300 + random.nextInt(90000);
      final who = (members..shuffle(random))
          .take(1 + random.nextInt(3))
          .toList();
      result = push(
        op('shared_expenses', id, 'create', 0, {
          'id': id,
          'groupId': FakeSyncServer.groupId,
          'payerId': members[random.nextInt(3)],
          'amountMinor': amount,
          'currency': 'TND',
          'date': '2026-10-01T00:00:00.000Z',
          'split': {'type': 'equal'},
          'shares': split(amount, who),
          'categoryId': null,
        }),
      );
    } else if (roll == 1) {
      // Amount alone, from a stale base: the merged shares no longer add up.
      final (eid, row) = live[random.nextInt(live.length)];
      result = push(
        op(
          'shared_expenses',
          eid,
          'update',
          max(0, (row['version']! as int) - 1),
          {
            'amountMinor':
                (row['amountMinor']! as int) + 1 + random.nextInt(500),
          },
        ),
      );
    } else if (roll == 2) {
      final (eid, row) = live[random.nextInt(live.length)];
      final amount = 300 + random.nextInt(90000);
      result = push(
        op('shared_expenses', eid, 'update', row['version']! as int, {
          'amountMinor': amount,
          'shares': split(
            amount,
            (row['shares']! as Map).keys.cast<String>().toList(),
          ),
        }),
      );
    } else if (roll == 3) {
      final (eid, row) = live[random.nextInt(live.length)];
      result = push(
        op('shared_expenses', eid, 'delete', row['version']! as int, {}),
      );
    } else if (roll == 4 || settlements.isEmpty) {
      final pair = (members..shuffle(random)).take(2).toList();
      result = push(
        op('settlements', id, 'create', 0, {
          'id': id,
          'groupId': FakeSyncServer.groupId,
          'fromMemberId': pair[0],
          'toMemberId': pair[1],
          'amountMinor': 100 + random.nextInt(20000),
          'currency': 'TND',
          'date': '2026-10-02T00:00:00.000Z',
          'reversesId': null,
        }),
      );
    } else {
      final MapEntry(key: sid, value: s) =
          settlements[random.nextInt(settlements.length)];
      final wrong = random.nextInt(4) == 0;
      result = push(
        op('settlements', id, 'create', 0, {
          'id': id,
          'groupId': FakeSyncServer.groupId,
          'fromMemberId': s['toMemberId'],
          'toMemberId': s['fromMemberId'],
          'amountMinor': (s['amountMinor']! as int) + (wrong ? 1 : 0),
          'currency': 'TND',
          'date': '2026-10-03T00:00:00.000Z',
          'reversesId': sid,
        }),
      );
    }
    return '${result['status']} ${result['reason'] ?? ''}';
  }

  void _checkGroupBalances(FakeSyncServer server) {
    const tnd = Currency.tnd;
    final expenses = [
      for (final r in (server.rows['shared_expenses'] ?? {}).values)
        if (r['deleted'] == false)
          SharedExpense(
            id: r['id']! as String,
            groupId: FakeSyncServer.groupId,
            payerId: r['payerId']! as String,
            amount: Money(r['amountMinor']! as int, tnd),
            date: DateTime.parse(r['date']! as String),
            split: Split.exact({
              for (final MapEntry(:key, :value)
                  in (r['shares']! as Map).entries)
                key as String: Money(value as int, tnd),
            }),
            shares: {
              for (final MapEntry(:key, :value)
                  in (r['shares']! as Map).entries)
                key as String: Money(value as int, tnd),
            },
          ),
    ];
    final settlements = [
      for (final r in (server.rows['settlements'] ?? {}).values)
        Settlement(
          id: r['id']! as String,
          groupId: FakeSyncServer.groupId,
          fromMemberId: r['fromMemberId']! as String,
          toMemberId: r['toMemberId']! as String,
          amount: Money(r['amountMinor']! as int, tnd),
          date: DateTime.parse(r['date']! as String),
          reversesId: r['reversesId'] as String?,
        ),
    ];
    final balances = const ComputeBalances()(
      currency: tnd,
      expenses: expenses,
      settlements: settlements,
      memberIds: server.members,
    );
    expect(balances.isOk, isTrue, reason: 'money: group balances $balances');
    final sum = balances.valueOrNull!.values.fold(
      0,
      (s, m) => s + m.minorUnits,
    );
    expect(sum, 0, reason: 'money: group balances sum to $sum');
  }
}

String _canonical(Map<String, Object?> row) {
  Object? sort(Object? v) => v is Map
      ? {
          for (final k in (v.keys.cast<String>().toList()..sort()))
            k: sort(v[k]),
        }
      : v;
  return jsonEncode(sort(row));
}

List<String> _canonicalList(List<Map<String, Object?>> changes) =>
    [for (final c in changes) _canonical(c)]..sort();

typedef _Replay = ({SimDevice device, OutboxEntry op, PushResult result});
