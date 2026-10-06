import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app/background/background_sync_task.dart';
import 'app/mizan_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
  } on Object {
    // No background sync on this platform; foreground sync still works.
  }
  runApp(const ProviderScope(child: MizanApp()));
}
