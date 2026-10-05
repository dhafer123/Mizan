import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

void main() {
  String record(String path, List<int> hits) => [
    'SF:$path',
    for (var i = 0; i < hits.length; i++) 'DA:${i + 1},${hits[i]}',
    'LF:${hits.length}',
    'end_of_record',
  ].join('\n');

  test('counts hit and found lines for core/ and domain/ only', () {
    final lcov = [
      record('lib/core/money/money.dart', [1, 0, 3, 1]),
      record('lib/features/groups/domain/usecases/split.dart', [2, 2]),
      record('lib/features/groups/data/dao.dart', [0, 0]),
      record('lib/app/router/app_router.dart', [1]),
    ].join('\n');

    final files = pureCoverage(lcov);

    expect(files.map((f) => f.path), [
      'core/money/money.dart',
      'features/groups/domain/usecases/split.dart',
    ]);
    expect(files.first.hit, 3);
    expect(files.first.found, 4);
    expect(files.last.hit, 2);
  });

  test('skips generated files and accepts Windows paths', () {
    final lcov = [
      record(r'C:\repo\app\lib\core\money\money.dart', [1]),
      record('lib/core/money/money.freezed.dart', [0, 0]),
      record('lib/features/x/domain/a.g.dart', [0]),
    ].join('\r\n');

    expect(pureCoverage(lcov).map((f) => f.path), ['core/money/money.dart']);
  });
}
