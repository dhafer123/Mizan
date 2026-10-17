import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/mascot/domain/usecases/read_penny.dart';

part 'mascot_providers.g.dart';

@Riverpod(keepAlive: true)
ReadPenny readPenny(Ref ref) => const ReadPenny();
