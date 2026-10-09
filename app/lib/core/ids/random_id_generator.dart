import 'package:uuid/uuid.dart';

import 'id_generator.dart';

/// Random UUIDv4 ids, for ids that must not reveal when they were made (the
/// anonymous install id of the beta's usage counter). Entities use
/// `UuidV7Generator`.
final class RandomIdGenerator implements IdGenerator {
  const RandomIdGenerator();

  static const _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}
