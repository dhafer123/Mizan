import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_domain_imports.dart';

void main() {
  late Directory lib;

  setUp(() {
    lib = Directory.systemTemp.createTempSync('mizan_lib_');
  });

  tearDown(() => lib.deleteSync(recursive: true));

  void write(String path, String content) {
    File('${lib.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  List<String> violatingUris() =>
      findViolations(lib).map((v) => v.uri).toList();

  test('the real lib/ has no violations', () {
    expect(findViolations(Directory('lib')), isEmpty);
  });

  test('flags flutter, drift, dio, http and plugins in domain/', () {
    write('features/groups/domain/usecases/bad.dart', '''
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import "package:dio/dio.dart";
import 'package:http/http.dart' as http;
export 'package:speech_to_text/speech_to_text.dart';
''');

    expect(violatingUris(), [
      'package:flutter/material.dart',
      'package:drift/drift.dart',
      'package:dio/dio.dart',
      'package:http/http.dart',
      'package:speech_to_text/speech_to_text.dart',
    ]);
  });

  test('flags platform dart: libraries', () {
    write('features/sync/domain/a.dart', '''
import 'dart:io';
import 'dart:ui' show Color;
''');

    expect(violatingUris(), ['dart:io', 'dart:ui']);
  });

  test('flags imports of data/ and presentation/, absolute or relative', () {
    write('features/groups/domain/usecases/a.dart', '''
import 'package:mizan/features/groups/data/db/groups_dao.dart';
import '../../presentation/group_list/screen.dart';
import '../../../../app/di/providers.dart';
''');

    expect(violatingUris(), [
      'package:mizan/features/groups/data/db/groups_dao.dart',
      '../../presentation/group_list/screen.dart',
      '../../../../app/di/providers.dart',
    ]);
  });

  test('flags every URI of a conditional import', () {
    write('core/clock/a.dart', '''
import 'stub.dart'
    if (dart.library.io) 'package:path_provider/path_provider.dart';
''');

    expect(violatingUris(), ['package:path_provider/path_provider.dart']);
  });

  test('reports the line of the offending directive', () {
    write('core/money/money.dart', '''
// header

import 'package:flutter/foundation.dart';
''');

    final violation = findViolations(lib).single;
    expect(violation.file, 'lib/core/money/money.dart');
    expect(violation.line, 3);
  });

  test('allows pure dart:, allowlisted packages, domain and core', () {
    write('features/groups/domain/usecases/ok.dart', '''
import 'dart:math';
import 'dart:collection';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import '../entities/group.dart';
import '../../../../core/result/result.dart';

part 'ok.freezed.dart';
''');

    expect(violatingUris(), isEmpty);
  });

  test('ignores layers outside domain/ and core/, and generated files', () {
    write('features/groups/data/db/dao.dart',
        "import 'package:drift/drift.dart';");
    write('features/groups/presentation/screen.dart',
        "import 'package:flutter/material.dart';");
    write('app/di/providers.dart',
        "import 'package:flutter_riverpod/flutter_riverpod.dart';");
    write('features/groups/domain/entities/group.g.dart',
        "import 'package:flutter/material.dart';");

    expect(violatingUris(), isEmpty);
  });
}
